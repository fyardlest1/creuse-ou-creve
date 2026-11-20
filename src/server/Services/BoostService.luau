--!strict
-- Bonus : réserve (potions et boucliers gagnés en jouant, activés quand le joueur veut), effets actifs
-- (potion, bouclier), Événement chance du serveur, et multiplicateur de chance de chaque joueur.
-- La formule elle-même vit dans LootService.computeLuckMultiplier ; ce service n'en fournit que les
-- ingrédients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ShopService = require(script.Parent.ShopService)
local DayNightService = require(script.Parent.DayNightService)
local PurchaseService = require(script.Parent.PurchaseService)
local LootService = require(script.Parent.LootService)

export type BoostKind = "luckPotion" | "shield"

local IS_STUDIO = RunService:IsStudio()
local ATTRIBUTE_EVENT_ENDS_AT = "LuckEventEndsAt" -- sur ReplicatedStorage, os.time() de fin (0 si aucun)
local ATTRIBUTE_EVENT_BUYER = "LuckEventBuyer"
local USE_BOOST_COOLDOWN = 0.5 -- secondes entre deux activations depuis la réserve
local REFRESH_INTERVAL = 1 -- secondes entre deux mises à jour du multiplicateur affiché

local BoostService = {}

local serverEventEndsAt = 0
local groupMembers: { [Player]: boolean } = {}
local lastUse: { [Player]: number } = {}
local eventStartedRemote: RemoteEvent
local addVipTag: (character: Model?) -> ()

local function log(message: string)
	print("[BoostService] " .. message)
end

local function now(): number
	return os.time()
end

function BoostService.isServerEventActive(): boolean
	return serverEventEndsAt > now()
end

function BoostService.isPotionActive(player: Player): boolean
	local data = PlayerDataService.getData(player)
	return data ~= nil and data.effects.luckUntil > now()
end

-- Le coffre de ce joueur est-il protégé par un Bouclier pour la nuit en cours ?
function BoostService.isShieldActive(player: Player): boolean
	local data = PlayerDataService.getData(player)
	local nightId = DayNightService.getCurrentNightId()
	return data ~= nil and nightId ~= 0 and data.effects.shieldNightId == nightId
end

-- Multiplicateur de chance de ce joueur, par la formule unique de LootService (plafonnée à x10).
function BoostService.getLuckMultiplier(player: Player): number
	return LootService.computeLuckMultiplier({
		shovelBonus = ShopService.getEquippedShovel(player).luckBonus,
		luckPass = PurchaseService.ownsPass(player, "LuckX2"),
		potion = BoostService.isPotionActive(player),
		serverEvent = BoostService.isServerEventActive(),
		groupMember = groupMembers[player] == true,
	})
end

local function publish(player: Player)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	player:SetAttribute("ReserveLuckPotion", data.boosts.luckPotion)
	player:SetAttribute("ReserveShield", data.boosts.shield)
	player:SetAttribute("LuckUntil", data.effects.luckUntil)
	player:SetAttribute("ShieldNightId", data.effects.shieldNightId)
	player:SetAttribute("ShieldTonight", BoostService.isShieldActive(player))
	player:SetAttribute("LuckMultiplier", BoostService.getLuckMultiplier(player))
end

function BoostService.refresh(player: Player)
	publish(player)
end

-- Potion de chance : x3 pendant POTION_DURATION ; si une potion est active, la durée s'additionne.
function BoostService.activatePotion(player: Player, data: any): boolean
	local start = math.max(data.effects.luckUntil, now())
	data.effects.luckUntil = start + MonetizationConfig.POTION_DURATION
	publish(player)
	log(
		string.format(
			"%s : potion de chance jusqu'à %d (+%d s)",
			player.Name,
			data.effects.luckUntil,
			MonetizationConfig.POTION_DURATION
		)
	)
	return true
end

-- Bouclier : la nuit en cours si c'est la nuit, sinon la prochaine. Les crochetages en cours sont annulés
-- par StealService (onShieldActivated).
local shieldCallbacks: { (player: Player) -> () } = {}
function BoostService.onShieldActivated(callback: (player: Player) -> ())
	table.insert(shieldCallbacks, callback)
end

-- Un Bouclier déjà prévu pour cette nuit ne peut pas être doublé (ce serait payer pour rien).
function BoostService.canActivateShield(player: Player): boolean
	local data = PlayerDataService.getData(player)
	return data ~= nil and data.effects.shieldNightId ~= DayNightService.getTargetNightId()
end

function BoostService.activateShield(player: Player, data: any): boolean
	data.effects.shieldNightId = DayNightService.getTargetNightId()
	publish(player)
	for _, callback in shieldCallbacks do
		task.spawn(callback, player)
	end
	log(string.format("%s : bouclier pour la nuit %d", player.Name, data.effects.shieldNightId))
	return true
end

-- Événement chance : x2 pour tout le serveur pendant SERVER_EVENT_DURATION. Un seul à la fois.
function BoostService.startServerEvent(buyer: Player): boolean
	if BoostService.isServerEventActive() then
		return false
	end
	serverEventEndsAt = now() + MonetizationConfig.SERVER_EVENT_DURATION
	ReplicatedStorage:SetAttribute(ATTRIBUTE_EVENT_ENDS_AT, serverEventEndsAt)
	ReplicatedStorage:SetAttribute(ATTRIBUTE_EVENT_BUYER, buyer.DisplayName)
	eventStartedRemote:FireAllClients(buyer.DisplayName, serverEventEndsAt)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	log(string.format("Événement chance offert par %s jusqu'à %d", buyer.Name, serverEventEndsAt))
	return true
end

-- Ajoute des bonus à la réserve (récompenses quotidiennes, quêtes, Index, compensations).
function BoostService.addToReserve(player: Player, data: any, kind: BoostKind, count: number)
	data.boosts[kind] += count
	publish(player)
end

-- Le joueur active un bonus de sa réserve (UseBoost).
local function onUseBoost(player: Player, kind: unknown)
	if kind ~= "luckPotion" and kind ~= "shield" then
		return
	end
	local current = os.clock()
	local last = lastUse[player]
	if last ~= nil and current - last < USE_BOOST_COOLDOWN then
		return
	end
	lastUse[player] = current
	local data = PlayerDataService.getData(player)
	if data == nil or data.boosts[kind] <= 0 then
		if IS_STUDIO then
			log(string.format("Réserve vide (%s, %s)", player.Name, tostring(kind)))
		end
		return
	end
	if kind == "shield" and not BoostService.canActivateShield(player) then
		if IS_STUDIO then
			log(string.format("Bouclier déjà prévu pour cette nuit (%s)", player.Name))
		end
		return
	end
	data.boosts[kind] -= 1
	if kind == "luckPotion" then
		BoostService.activatePotion(player, data)
	else
		BoostService.activateShield(player, data)
	end
end

-- Étiquette VIP dorée au-dessus du personnage (créée par le serveur : visible par tous).
addVipTag = function(character: Model?)
	local head = if character ~= nil then character:WaitForChild("Head", 5) else nil
	if head == nil or head:FindFirstChild("VipTag") ~= nil then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.fromOffset(MonetizationConfig.VIP_TAG_SIZE.X, MonetizationConfig.VIP_TAG_SIZE.Y)
	tag.StudsOffset = Vector3.new(0, MonetizationConfig.VIP_TAG_HEIGHT, 0)
	tag.MaxDistance = MonetizationConfig.VIP_TAG_MAX_DISTANCE
	tag.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = MonetizationConfig.VIP_TAG_TEXT
	label.TextColor3 = MonetizationConfig.VIP_TAG_COLOR
	label.TextStrokeTransparency = 0.2
	label.Parent = tag
	tag.Parent = head
end

local function checkGroup(player: Player)
	if MonetizationConfig.GROUP_ID == 0 then
		return
	end
	local ok, member = pcall(function()
		return player:IsInGroupAsync(MonetizationConfig.GROUP_ID)
	end)
	groupMembers[player] = ok and member == true
	publish(player)
end

function BoostService.init()
	eventStartedRemote = Remotes.get(Remotes.Names.LuckEventStarted)
	ReplicatedStorage:SetAttribute(ATTRIBUTE_EVENT_ENDS_AT, 0)
	ReplicatedStorage:SetAttribute(ATTRIBUTE_EVENT_BUYER, "")
end

function BoostService.start()
	Remotes.get(Remotes.Names.UseBoost).OnServerEvent:Connect(onUseBoost)
	PlayerDataService.onLoaded(function(player: Player)
		publish(player)
		task.spawn(checkGroup, player)
	end)
	PurchaseService.onPassOwned(function(player: Player, key)
		if key == "BiggerChest" then
			PlayerDataService.setInventoryLimit(player, MonetizationConfig.BIGGER_CHEST_LIMIT)
		elseif key == "VIP" then
			player:SetAttribute("VIP", true) -- lu par les clients pour l'étiquette du chat
			addVipTag(player.Character)
			player.CharacterAdded:Connect(addVipTag)
		end
		publish(player)
	end)
	DayNightService.onPhaseChanged(function()
		for _, player in Players:GetPlayers() do
			publish(player)
		end
	end)
	-- Fin des potions et de l'événement : le multiplicateur affiché suit.
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			if serverEventEndsAt ~= 0 and not BoostService.isServerEventActive() then
				serverEventEndsAt = 0
				ReplicatedStorage:SetAttribute(ATTRIBUTE_EVENT_ENDS_AT, 0)
				ReplicatedStorage:SetAttribute(ATTRIBUTE_EVENT_BUYER, "")
			end
			for _, player in Players:GetPlayers() do
				local value = BoostService.getLuckMultiplier(player)
				if player:GetAttribute("LuckMultiplier") ~= value then
					player:SetAttribute("LuckMultiplier", value)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		groupMembers[player] = nil
		lastUse[player] = nil
	end)
end

return BoostService
