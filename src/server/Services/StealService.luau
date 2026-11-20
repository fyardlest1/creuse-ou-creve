--!strict
-- Vol la nuit : règles, garde-fous anti-frustration, transfert atomique, compteurs par nuit,
-- bannissements de coffre, Points de Voleur et mémoire du dernier voleur.
--
-- Le cœur des règles (NightState, transferItem) est pur : il travaille sur des identifiants et des
-- listes d'objets, sans vrais joueurs, pour être testé par Tests/StealRules.luau.

local AnalyticsService = game:GetService("AnalyticsService")
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
local WorldConfig = require(Shared.Config.WorldConfig)

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
local lastEjectTime: { [Player]: number } = {}
local stunToken: { [Player]: number } = {}
local rng = Random.new()
local remotes: {
	stealStarted: RemoteEvent,
	stealCancelled: RemoteEvent,
	stealSucceeded: RemoteEvent,
	ejected: RemoteEvent,
}

local function log(message: string)
	print("[StealService] " .. message)
end

-- L'analytique ne doit jamais bloquer le vol.
local function logEvent(player: Player, eventName: string, value: number?, reason: string?)
	local ok, err = pcall(function()
		local fields = if reason ~= nil then { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = reason } else nil
		AnalyticsService:LogCustomEvent(player, eventName, value or 1, fields)
	end)
	if not ok then
		warn("[StealService] Analytique en échec : " .. tostring(err))
	end
end

local function reject(thief: Player, reason: string)
	if IS_STUDIO then
		log(string.format("Refusé (%s) : %s", thief.Name, reason))
	end
end

-- Le coffre clignote pour tout le monde tant qu'au moins un voleur le crochète.
local function setBeingPicked(victim: Player)
	local picked = false
	for _, pick in activePicks do
		picked = picked or pick.victim == victim
	end
	local chest = WorldService.getChest(victim)
	if chest ~= nil then
		chest:SetAttribute(WorldConfig.ATTRIBUTE_BEING_PICKED, picked)
	end
end

-- Attributs d'affichage du vol, lus par les clients pour les messages des prompts.
local function publishNightAttributes(player: Player)
	player:SetAttribute("RobbedTonight", night:isRobbed(player.UserId))
	player:SetAttribute("StealsTonight", night:countSteals(player.UserId))
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
	setBeingPicked(victim)
	local thiefData = PlayerDataService.getData(thief)
	if thiefData ~= nil then
		thiefData.stats.stealsAttempted += 1
	end
	remotes.stealStarted:FireClient(victim, thief.Name, thief.UserId)
	logEvent(thief, StealConfig.ANALYTICS_EVENTS.Attempt)
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
	setBeingPicked(pick.victim)
	if thief.Parent == Players then
		logEvent(thief, StealConfig.ANALYTICS_EVENTS.Cancel, 1, reason)
	end
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
	setBeingPicked(victim)
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
	publishNightAttributes(thief)
	publishNightAttributes(victim)
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
	logEvent(thief, StealConfig.ANALYTICS_EVENTS.Success, item.value, item.rarity)
	log(string.format("%s a volé %s (%s) à %s", thief.Name, name, item.rarity, victim.Name))
	return item
end

-- Éjection : bannit le voleur de ce coffre pour la nuit et annule son crochetage.
function StealService.banFromChest(thief: Player, victim: Player)
	night:ban(thief.UserId, victim.UserId)
	StealService.cancelPick(thief, "éjecté")
end

-- Étourdit le voleur : ni marche ni saut pendant STUN_SECONDS (appliqué par le serveur).
function StealService.stun(thief: Player)
	local character = thief.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	local token = (stunToken[thief] or 0) + 1
	stunToken[thief] = token
	local walkSpeed = humanoid:GetAttribute("StunWalkSpeed") or humanoid.WalkSpeed
	local jumpHeight = humanoid:GetAttribute("StunJumpHeight") or humanoid.JumpHeight
	local jumpPower = humanoid:GetAttribute("StunJumpPower") or humanoid.JumpPower
	humanoid:SetAttribute("StunWalkSpeed", walkSpeed)
	humanoid:SetAttribute("StunJumpHeight", jumpHeight)
	humanoid:SetAttribute("StunJumpPower", jumpPower)
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	task.delay(StealConfig.STUN_SECONDS, function()
		if stunToken[thief] ~= token or humanoid.Parent == nil then
			return
		end
		humanoid.WalkSpeed = walkSpeed
		humanoid.JumpHeight = jumpHeight
		humanoid.JumpPower = jumpPower
		humanoid:SetAttribute("StunWalkSpeed", nil)
		humanoid:SetAttribute("StunJumpHeight", nil)
		humanoid:SetAttribute("StunJumpPower", nil)
	end)
end

-- EjectRequest : seul le propriétaire du coffre en cours de crochetage peut éjecter, à
-- EJECT_MAX_DISTANCE au plus du voleur, et seulement pendant un crochetage actif.
local function onEjectRequest(owner: Player, thiefUserId: unknown)
	if typeof(thiefUserId) ~= "number" or thiefUserId ~= thiefUserId or thiefUserId % 1 ~= 0 then
		reject(owner, "éjection : identifiant invalide")
		return
	end
	local now = os.clock()
	local last = lastEjectTime[owner]
	if last ~= nil and now - last < StealConfig.EJECT_COOLDOWN then
		reject(owner, "éjection : cadence trop rapide")
		return
	end
	lastEjectTime[owner] = now

	local thief = Players:GetPlayerByUserId(thiefUserId)
	if thief == nil or not StealService.isPicking(thief, owner) then
		reject(owner, "éjection : aucun crochetage de ce joueur sur ton coffre")
		return
	end
	local ownerPosition = getCharacterPosition(owner)
	local thiefPosition = getCharacterPosition(thief)
	if
		ownerPosition == nil
		or thiefPosition == nil
		or (ownerPosition - thiefPosition).Magnitude > StealConfig.EJECT_MAX_DISTANCE
	then
		reject(owner, "éjection : trop loin du voleur")
		return
	end

	StealService.banFromChest(thief, owner)
	local character = thief.Character
	if character ~= nil then
		character:PivotTo(CFrame.new(StealConfig.EJECT_DESTINATION))
	end
	StealService.stun(thief)
	local ownerData = PlayerDataService.getData(owner)
	if ownerData ~= nil then
		ownerData.stats.ejections += 1
	end
	remotes.ejected:FireClient(thief, owner.Name, StealConfig.STUN_SECONDS)
	logEvent(owner, StealConfig.ANALYTICS_EVENTS.Ejection)
	log(string.format("%s éjecte %s de son coffre", owner.Name, thief.Name))
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
		ejected = Remotes.get(Remotes.Names.Ejected),
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
			for _, player in Players:GetPlayers() do
				publishNightAttributes(player)
			end
			log("Lever du jour : compteurs de la nuit remis à zéro")
		end
	end)

	-- Prompts "Crocheter" : écoutés côté serveur. La victime est le propriétaire de la parcelle.
	for _, entry in WorldService.getPickPrompts() do
		local plot, prompt = entry.plot, entry.prompt
		local function getOwner(): Player?
			local ownerId = plot:GetAttribute("OwnerUserId")
			if typeof(ownerId) ~= "number" or ownerId == 0 then
				return nil
			end
			return Players:GetPlayerByUserId(ownerId)
		end
		prompt.PromptButtonHoldBegan:Connect(function(thief: Player)
			local victim = getOwner()
			if victim == nil then
				reject(thief, "parcelle libre")
				return
			end
			StealService.beginPick(thief, victim)
		end)
		prompt.Triggered:Connect(function(thief: Player)
			local victim = getOwner()
			if victim ~= nil then
				StealService.finishPick(thief, victim)
			end
		end)
		-- Relâché avant la fin. À la fin d'un maintien, HoldEnded peut arriver avant Triggered :
		-- on laisse une courte marge à Triggered avant d'annuler.
		prompt.PromptButtonHoldEnded:Connect(function(thief: Player)
			local pick = activePicks[thief]
			if pick == nil then
				return
			end
			task.delay(StealConfig.RELEASE_GRACE, function()
				if activePicks[thief] == pick then
					StealService.cancelPick(thief, "relâché")
				end
			end)
		end)
	end

	PlayerDataService.onLoaded(function(player: Player)
		publishNightAttributes(player)
	end)

	Remotes.get(Remotes.Names.EjectRequest).OnServerEvent:Connect(onEjectRequest)

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
		lastEjectTime[player] = nil
		stunToken[player] = nil
		StealService.cancelPick(player, "départ")
		for thief, pick in activePicks do
			if pick.victim == player then
				StealService.cancelPick(thief, "départ")
			end
		end
	end)
end

return StealService
