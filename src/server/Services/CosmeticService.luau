--!strict
-- Cosmétiques de voleur (plan semaine 5, section 9) : achat en Points de Voleur au Repaire des Voleurs,
-- choix du masque et du sac, et affichage sur le personnage la nuit seulement (visible par tous, créé
-- par le serveur). Purement visuel : aucun effet sur le jeu.
-- Le client envoie des intentions (acheter tel id, porter tel id) ; le serveur valide tout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local CosmeticShop = require(Shared.CosmeticShop)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local DayNightService = require(script.Parent.DayNightService)
local WorldService = require(script.Parent.WorldService)

local CosmeticService = {}

local lastAction: { [Player]: number } = {}

local function log(message: string)
	print("[CosmeticService] " .. message)
end

local function reject(player: Player, reason: string)
	warn(string.format("[CosmeticService] Refusé (%s) : %s", player.Name, reason))
end

-- Anti-spam : une action toutes les ACTION_COOLDOWN secondes.
local function passCooldown(player: Player): boolean
	local now = os.clock()
	if now - (lastAction[player] or -math.huge) < Cosmetics.ACTION_COOLDOWN then
		return false
	end
	lastAction[player] = now
	return true
end

local function findAnchor(character: Model, slot: Cosmetics.Slot): BasePart?
	for _, name in Cosmetics.ANCHORS[slot] do
		local part = character:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function buildPart(spec: Cosmetics.PartSpec, anchor: BasePart, parent: Instance)
	local anchorSize = anchor.Size
	local part = Instance.new("Part")
	part.Name = spec.name
	if spec.shape == Enum.PartType.Ball then
		part.Shape = Enum.PartType.Ball
		local diameter = spec.size.X * anchorSize.X
		part.Size = Vector3.new(diameter, diameter, diameter)
	else
		part.Size = spec.size * anchorSize
	end
	part.Color = spec.color
	part.Material = spec.material
	part.Reflectance = spec.reflectance or 0
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local rotation = spec.rotation or Vector3.zero
	local offset = CFrame.new(spec.offset * anchorSize)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = parent
end

-- (Re)crée les cosmétiques portés sur le personnage actuel : rien le jour, le masque et le sac
-- choisis la nuit.
function CosmeticService.refresh(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local existing = character:FindFirstChild(Cosmetics.MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local data = PlayerDataService.getData(player)
	if data == nil or not DayNightService.isNight() then
		return
	end
	local model = Instance.new("Model")
	model.Name = Cosmetics.MODEL_NAME
	for _, slot in Cosmetics.SLOTS do
		local id = if slot == "mask" then data.cosmetics.mask else data.cosmetics.bag
		local def = if id ~= nil then Cosmetics.byId[id] else nil
		local anchor = findAnchor(character, slot)
		if def ~= nil and anchor ~= nil then
			for _, spec in def.parts do
				buildPart(spec, anchor, model)
			end
		end
	end
	if #model:GetChildren() > 0 then
		model.Parent = character
	else
		model:Destroy()
	end
end

local function onBuy(player: Player, id: unknown)
	if not passCooldown(player) then
		return
	end
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if
		root == nil
		or not root:IsA("BasePart")
		or (root.Position - WorldService.getThiefShopPosition()).Magnitude > Cosmetics.SHOP_MAX_DISTANCE
	then
		reject(player, "trop loin du Repaire des Voleurs")
		return
	end
	local def, reason = CosmeticShop.checkBuy(data.cosmetics, data.thiefPoints, id)
	if def == nil then
		reject(player, "achat " .. tostring(id) .. " : " .. tostring(reason))
		return
	end
	-- Retrait des points et ajout dans la même opération, sans yield.
	data.thiefPoints = CosmeticShop.applyBuy(data.cosmetics, data.thiefPoints, def)
	PlayerDataService.refreshAttributes(player)
	CosmeticService.refresh(player)
	log(
		string.format("%s achète %s (%d Points de Voleur, reste %d)", player.Name, def.id, def.price, data.thiefPoints)
	)
end

local function onEquip(player: Player, slot: unknown, id: unknown)
	if not passCooldown(player) then
		return
	end
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	local ok, equipped, reason = CosmeticShop.checkEquip(data.cosmetics, slot, id)
	if not ok then
		reject(player, "porter " .. tostring(slot) .. "/" .. tostring(id) .. " : " .. tostring(reason))
		return
	end
	if slot == "mask" then
		data.cosmetics.mask = equipped
	else
		data.cosmetics.bag = equipped
	end
	PlayerDataService.refreshAttributes(player)
	CosmeticService.refresh(player)
end

-- L'apparence de l'avatar remplace la tête et le torse après l'apparition : on recrée les
-- cosmétiques à chaque nouvelle pièce d'ancrage, comme la pelle.
local function onCharacterAdded(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		if player.Character ~= character then
			return
		end
		for _, names in Cosmetics.ANCHORS do
			if table.find(names, child.Name) ~= nil then
				CosmeticService.refresh(player)
				return
			end
		end
	end)
	CosmeticService.refresh(player)
end

function CosmeticService.init() end

function CosmeticService.start()
	Remotes.get(Remotes.Names.BuyCosmetic).OnServerEvent:Connect(onBuy)
	Remotes.get(Remotes.Names.EquipCosmetic).OnServerEvent:Connect(onEquip)
	PlayerDataService.onLoaded(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character ~= nil then
			onCharacterAdded(player, player.Character)
		end
	end)
	DayNightService.onPhaseChanged(function()
		for _, player in Players:GetPlayers() do
			CosmeticService.refresh(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return CosmeticService
