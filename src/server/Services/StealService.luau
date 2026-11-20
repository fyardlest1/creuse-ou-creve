--!strict
-- Vol la nuit : règles, garde-fous anti-frustration, transfert atomique, compteurs par nuit,
-- bannissements de coffre, Points de Voleur et mémoire du dernier voleur.
--
-- Le cœur des règles (NightState, transferItem) est pur : il travaille sur des identifiants et des
-- listes d'objets, sans vrais joueurs, pour être testé par Tests/StealRules.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local StealConfig = require(Shared.Config.StealConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local Items = require(Shared.Config.Items)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local DayNightService = require(script.Parent.DayNightService)
local ProtectionService = require(script.Parent.ProtectionService)
local WorldService = require(script.Parent.WorldService)

local IS_STUDIO = RunService:IsStudio()

-- Raisons d'un refus (codes internes ; les textes affichés vivent côté client).
export type Reason =
	"day"
	| "own_chest"
	| "thief_protected"
	| "victim_protected"
	| "victim_offline"
	| "already_robbed"
	| "thief_limit"
	| "thief_chest_full"
	| "banned"
	| "too_far"
	| "nothing_to_steal"
	| "hold_too_short"
	| "busy"

-- Ce qu'il faut savoir d'une tentative pour décider. Rempli par le service (ou par les tests).
export type AttemptContext = {
	isNight: boolean,
	thiefId: number,
	victimId: number,
	thiefProtected: boolean,
	victimProtected: boolean,
	victimOnline: boolean,
	distance: number,
	thiefInventoryCount: number,
	victimInventory: { Types.ItemInstance },
}

local StealService = {}

------------------------------------------------------------------------------------------------
-- Cœur pur
------------------------------------------------------------------------------------------------

-- Un objet peut-il être volé ? Les Secrets, jamais (garde-fou 3). Les favoris, oui.
function StealService.isStealable(item: Types.ItemInstance): boolean
	return StealConfig.NON_STEALABLE_RARITIES[item.rarity] ~= true
end

local function hasStealable(inventory: { Types.ItemInstance }): boolean
	for _, item in inventory do
		if StealService.isStealable(item) then
			return true
		end
	end
	return false
end

-- État d'une nuit : pertes par victime, vols par voleur, bannissements de coffre.
local NightState = {}
NightState.__index = NightState

export type NightState = typeof(setmetatable(
	{} :: {
		losses: { [number]: number },
		steals: { [number]: { [number]: boolean } },
		bans: { [number]: { [number]: boolean } },
	},
	NightState
))

function NightState.new(): NightState
	return setmetatable({ losses = {}, steals = {}, bans = {} }, NightState)
end

-- Au lever du jour : tout repart à zéro.
function NightState.reset(self: NightState)
	self.losses = {}
	self.steals = {}
	self.bans = {}
end

function NightState.countSteals(self: NightState, thiefId: number): number
	local count = 0
	for _ in self.steals[thiefId] or {} do
		count += 1
	end
	return count
end

function NightState.isRobbed(self: NightState, victimId: number): boolean
	return (self.losses[victimId] or 0) >= StealConfig.MAX_LOSSES_PER_NIGHT
end

function NightState.isBanned(self: NightState, thiefId: number, victimId: number): boolean
	local bans = self.bans[victimId]
	return bans ~= nil and bans[thiefId] == true
end

function NightState.ban(self: NightState, thiefId: number, victimId: number)
	self.bans[victimId] = self.bans[victimId] or {}
	self.bans[victimId][thiefId] = true
end

function NightState.recordSuccess(self: NightState, thiefId: number, victimId: number)
	self.losses[victimId] = (self.losses[victimId] or 0) + 1
	self.steals[thiefId] = self.steals[thiefId] or {}
	self.steals[thiefId][victimId] = true
end

-- Peut-on commencer (ou continuer) à crocheter ? Toutes les règles sauf la durée de maintien.
function NightState.checkStart(self: NightState, context: AttemptContext): (boolean, Reason?)
	if not context.isNight then
		return false, "day"
	end
	if context.thiefId == context.victimId then
		return false, "own_chest"
	end
	if not context.victimOnline then
		return false, "victim_offline" -- garde-fou 5
	end
	if context.thiefProtected then
		return false, "thief_protected" -- garde-fou 4 (symétrique)
	end
	if context.victimProtected then
		return false, "victim_protected" -- garde-fou 4
	end
	if self:isRobbed(context.victimId) then
		return false, "already_robbed" -- garde-fou 1
	end
	local thiefSteals = self.steals[context.thiefId]
	if thiefSteals ~= nil and thiefSteals[context.victimId] then
		return false, "already_robbed" -- garde-fou 2 : victimes différentes
	end
	if self:countSteals(context.thiefId) >= StealConfig.MAX_STEALS_PER_NIGHT then
		return false, "thief_limit" -- garde-fou 2
	end
	if self:isBanned(context.thiefId, context.victimId) then
		return false, "banned"
	end
	if context.thiefInventoryCount >= PlayerConfig.INVENTORY_LIMIT then
		return false, "thief_chest_full"
	end
	if context.distance > StealConfig.PICK_MAX_DISTANCE then
		return false, "too_far"
	end
	if not hasStealable(context.victimInventory) then
		return false, "nothing_to_steal" -- garde-fou 3 : que des Secrets (ou rien)
	end
	return true, nil
end

-- Peut-on voler maintenant ? Toutes les règles, plus 5 secondes réellement maintenues (horloge serveur).
function NightState.checkFinish(self: NightState, context: AttemptContext, heldSeconds: number): (boolean, Reason?)
	local ok, reason = self:checkStart(context)
	if not ok then
		return false, reason
	end
	if heldSeconds < StealConfig.PICK_DURATION - StealConfig.PICK_TIME_TOLERANCE then
		return false, "hold_too_short"
	end
	return true, nil
end

StealService.NightState = NightState

-- Transfert atomique (garde-fou 6) : retire un objet volable au hasard de la victime et l'ajoute au
-- voleur dans la même opération, sans yield. Si le voleur n'a pas de place, rien n'est retiré.
-- L'objet garde son uid et reçoit stolenFrom. Retourne l'objet volé, ou nil.
function StealService.transferItem(
	victimInventory: { Types.ItemInstance },
	thiefInventory: { Types.ItemInstance },
	victimName: string,
	rng: Random
): Types.ItemInstance?
	if #thiefInventory >= PlayerConfig.INVENTORY_LIMIT then
		return nil
	end
	local candidates: { number } = {}
	for index, item in victimInventory do
		if StealService.isStealable(item) then
			table.insert(candidates, index)
		end
	end
	if #candidates == 0 then
		return nil
	end
	local index = candidates[rng:NextInteger(1, #candidates)]
	local item = table.remove(victimInventory, index) :: Types.ItemInstance
	item.stolenFrom = victimName
	table.insert(thiefInventory, item)
	return item
end

------------------------------------------------------------------------------------------------
-- Partie vivante (vrais joueurs)
------------------------------------------------------------------------------------------------

type ActivePick = { victim: Player, startedAt: number }

local night = NightState.new()
local activePicks: { [Player]: ActivePick } = {}
local lastThiefByVictim: { [number]: number } = {} -- mémoire serveur seulement (Revanche, semaine 4)
local rng = Random.new()
local remotes: {
	stealStarted: RemoteEvent,
	stealCancelled: RemoteEvent,
	stealSucceeded: RemoteEvent,
}

local function log(message: string)
	print("[StealService] " .. message)
end

local function reject(thief: Player, reason: string)
	if IS_STUDIO then
		log(string.format("Crochetage refusé (%s) : %s", thief.Name, reason))
	end
end

local function getCharacterPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

-- Contexte réel d'une tentative ; nil si un des deux joueurs n'est pas chargé.
local function buildContext(thief: Player, victim: Player): AttemptContext?
	local thiefData = PlayerDataService.getData(thief)
	local victimData = PlayerDataService.getData(victim)
	local chest = WorldService.getChest(victim)
	local position = getCharacterPosition(thief)
	if thiefData == nil or victimData == nil or chest == nil or position == nil then
		return nil
	end
	local body = chest.PrimaryPart
	return {
		isNight = DayNightService.isNight(),
		thiefId = thief.UserId,
		victimId = victim.UserId,
		thiefProtected = ProtectionService.isProtected(thief),
		victimProtected = ProtectionService.isProtected(victim),
		victimOnline = victim.Parent == Players,
		distance = if body ~= nil then (body.Position - position).Magnitude else math.huge,
		thiefInventoryCount = #thiefData.inventory,
		victimInventory = victimData.inventory,
	}
end

-- Raison pour laquelle ce voleur ne peut pas viser ce coffre maintenant (nil si possible).
function StealService.getBlockReason(thief: Player, victim: Player): Reason?
	local context = buildContext(thief, victim)
	if context == nil then
		return "victim_offline"
	end
	local ok, reason = night:checkStart(context)
	return if ok then nil else reason
end

-- Le voleur commence à maintenir "Crocheter" sur le coffre de la victime.
function StealService.beginPick(thief: Player, victim: Player): boolean
	if activePicks[thief] ~= nil then
		reject(thief, "crochetage déjà en cours")
		return false
	end
	local context = buildContext(thief, victim)
	if context == nil then
		reject(thief, "joueur non chargé")
		return false
	end
	local ok, reason = night:checkStart(context)
	if not ok then
		reject(thief, reason or "?")
		return false
	end
	activePicks[thief] = { victim = victim, startedAt = os.clock() }
	local thiefData = PlayerDataService.getData(thief)
	if thiefData ~= nil then
		thiefData.stats.stealsAttempted += 1
	end
	remotes.stealStarted:FireClient(victim, thief.Name, thief.UserId)
	log(string.format("%s commence à crocheter le coffre de %s", thief.Name, victim.Name))
	return true
end

-- Annule le crochetage en cours d'un voleur (relâché, éjecté, trop loin, jour, départ).
function StealService.cancelPick(thief: Player, reason: string)
	local pick = activePicks[thief]
	if pick == nil then
		return
	end
	activePicks[thief] = nil
	if pick.victim.Parent == Players then
		remotes.stealCancelled:FireClient(pick.victim, reason, thief.Name)
	end
	if thief.Parent == Players then
		remotes.stealCancelled:FireClient(thief, reason, pick.victim.Name)
	end
	log(string.format("Crochetage de %s annulé (%s)", thief.Name, reason))
end

-- Le prompt est arrivé au bout : on revalide tout, puis transfert atomique.
function StealService.finishPick(thief: Player, victim: Player): Types.ItemInstance?
	local pick = activePicks[thief]
	if pick == nil or pick.victim ~= victim then
		reject(thief, "aucun crochetage en cours sur ce coffre")
		return nil
	end
	activePicks[thief] = nil
	local context = buildContext(thief, victim)
	local held = os.clock() - pick.startedAt
	local ok, reason = if context ~= nil then night:checkFinish(context, held) else false, "victim_offline"
	if not ok then
		reject(thief, (reason or "?") .. string.format(" (maintenu %.2f s)", held))
		StealService.cancelPick(thief, "relâché")
		return nil
	end

	-- Transfert atomique : pas de yield entre le retrait chez la victime et l'ajout chez le voleur.
	local thiefData = PlayerDataService.getData(thief)
	local victimData = PlayerDataService.getData(victim)
	if thiefData == nil or victimData == nil then
		return nil
	end
	local item = StealService.transferItem(victimData.inventory, thiefData.inventory, victim.Name, rng)
	if item == nil then
		reject(thief, "rien à transférer")
		return nil
	end
	night:recordSuccess(thief.UserId, victim.UserId)
	thiefData.stats.stealsSucceeded += 1
	thiefData.thiefPoints += StealConfig.THIEF_POINTS_PER_STEAL
	victimData.stats.timesRobbed += 1
	lastThiefByVictim[victim.UserId] = thief.UserId

	PlayerDataService.refreshAttributes(thief)
	PlayerDataService.refreshAttributes(victim)
	PlayerDataService.pushInventory(thief)
	PlayerDataService.pushInventory(victim)

	local name = Items.byId[item.itemId] and Items.byId[item.itemId].name or item.itemId
	for _, player in { thief, victim } do
		remotes.stealSucceeded:FireClient(player, name, item.rarity, thief.Name, victim.Name)
	end
	log(string.format("%s a volé %s (%s) à %s", thief.Name, name, item.rarity, victim.Name))
	return item
end

-- Éjection : bannit le voleur de ce coffre pour la nuit et annule son crochetage.
function StealService.banFromChest(thief: Player, victim: Player)
	night:ban(thief.UserId, victim.UserId)
	StealService.cancelPick(thief, "éjecté")
end

-- Ce voleur est-il en train de crocheter le coffre de cette victime ?
function StealService.isPicking(thief: Player, victim: Player): boolean
	local pick = activePicks[thief]
	return pick ~= nil and pick.victim == victim
end

function StealService.isRobbedTonight(victim: Player): boolean
	return night:isRobbed(victim.UserId)
end

function StealService.getLastThiefUserId(victim: Player): number?
	return lastThiefByVictim[victim.UserId]
end

function StealService.init()
	remotes = {
		stealStarted = Remotes.get(Remotes.Names.StealStarted),
		stealCancelled = Remotes.get(Remotes.Names.StealCancelled),
		stealSucceeded = Remotes.get(Remotes.Names.StealSucceeded),
	}
end

function StealService.start()
	-- Lever du jour : annule les crochetages en cours et remet à zéro les compteurs de la nuit.
	DayNightService.onPhaseChanged(function(phase)
		if phase == "Day" then
			for thief in activePicks do
				StealService.cancelPick(thief, "jour")
			end
			night:reset()
			log("Lever du jour : compteurs de la nuit remis à zéro")
		end
	end)

	-- Le voleur s'éloigne du coffre pendant le maintien : annulé.
	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		sinceCheck += deltaTime
		if sinceCheck < StealConfig.PICK_DISTANCE_CHECK_INTERVAL then
			return
		end
		sinceCheck = 0
		for thief, pick in activePicks do
			local chest = WorldService.getChest(pick.victim)
			local body = if chest ~= nil then chest.PrimaryPart else nil
			local position = getCharacterPosition(thief)
			if
				body == nil
				or position == nil
				or (body.Position - position).Magnitude > StealConfig.PICK_MAX_DISTANCE
			then
				StealService.cancelPick(thief, "trop loin")
			end
		end
	end)

	-- Un joueur part en plein crochetage (voleur ou victime) : on annule, rien n'est transféré.
	Players.PlayerRemoving:Connect(function(player)
		StealService.cancelPick(player, "départ")
		for thief, pick in activePicks do
			if pick.victim == player then
				StealService.cancelPick(thief, "départ")
			end
		end
	end)
end

return StealService
