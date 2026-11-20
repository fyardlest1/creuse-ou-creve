--!strict
-- Pelle visible dans la main droite du personnage : un modèle en Parts (manche et lame), soudé à la
-- main, créé par le serveur pour que tous les joueurs le voient. Pas de Tool (pas de barre
-- d'inventaire sur mobile, pas de pelle rangée par erreur). Remplacée tout de suite à l'achat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Shovels = require(Shared.Config.Shovels)
local PlayerDataService = require(script.Parent.PlayerDataService)

local HAND_NAMES = { "RightHand", "Right Arm" } -- R15, puis R6

local ShovelVisualService = {}

local function createPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function weld(part0: BasePart, part1: BasePart, c0: CFrame)
	local joint = Instance.new("Weld")
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = c0
	joint.Parent = part1
end

local function findHand(character: Model): BasePart?
	for _, name in HAND_NAMES do
		local hand = character:FindFirstChild(name)
		if hand ~= nil and hand:IsA("BasePart") then
			return hand
		end
	end
	return nil
end

local function buildShovel(shovel: Types.ShovelDef, hand: BasePart): Model
	local model = Instance.new("Model")
	model.Name = Shovels.MODEL.MODEL_NAME
	model:SetAttribute("ShovelId", shovel.id)
	local look = shovel.appearance

	local handleSize = Shovels.MODEL.HANDLE_SIZE
	local handle = createPart("Handle", handleSize, look.handleColor, look.handleMaterial)
	handle.CFrame = hand.CFrame * Shovels.MODEL.GRIP
	handle.Parent = model
	weld(hand, handle, Shovels.MODEL.GRIP)

	local bladeSize = Shovels.MODEL.BLADE_SIZE
	local blade = createPart("Blade", bladeSize, look.bladeColor, look.bladeMaterial)
	blade.Reflectance = look.bladeReflectance
	-- Au bout du manche (vers l'avant), légèrement inclinée vers le sol.
	local bladeOffset = CFrame.new(0, 0, -(handleSize.Z / 2 + bladeSize.Z / 2 - bladeSize.Y))
		* CFrame.Angles(Shovels.MODEL.BLADE_TILT, 0, 0)
	blade.CFrame = handle.CFrame * bladeOffset
	blade.Parent = model
	weld(handle, blade, bladeOffset)

	model.PrimaryPart = handle
	return model
end

local function getEquippedShovel(player: Player): Types.ShovelDef
	local data = PlayerDataService.getData(player)
	local shovel = if data ~= nil then Shovels.byId[data.equippedShovel] else nil
	return shovel or Shovels.byId[Shovels.DEFAULT_ID]
end

-- (Re)crée la pelle dans la main du personnage actuel, selon la pelle équipée.
function ShovelVisualService.refresh(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local hand = findHand(character)
	if hand == nil then
		return
	end
	local existing = character:FindFirstChild(Shovels.MODEL.MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	buildShovel(getEquippedShovel(player), hand).Parent = character
end

-- L'apparence de l'avatar est appliquée après CharacterAdded et remplace les parties du corps,
-- main comprise : on recrée la pelle à chaque nouvelle main, en plus de l'apparition.
local function onCharacterAdded(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		if table.find(HAND_NAMES, child.Name) ~= nil and player.Character == character then
			ShovelVisualService.refresh(player)
		end
	end)
	if player.Character == character then
		ShovelVisualService.refresh(player)
	end
end

function ShovelVisualService.init() end

function ShovelVisualService.start()
	PlayerDataService.onLoaded(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character ~= nil then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end)
	-- Rien à nettoyer : la pelle disparaît avec le personnage, les connexions avec le joueur.
end

return ShovelVisualService
