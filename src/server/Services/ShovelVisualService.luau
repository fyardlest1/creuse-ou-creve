--!strict
-- Pelle visible dans la main droite du personnage, soudée à la main, créée par le serveur pour que
-- tous les joueurs la voient. Pas de Tool (pas de barre d'inventaire sur mobile, pas de pelle rangée
-- par erreur). Remplacée tout de suite à l'achat.
-- Pelle 3D si son modèle importé existe dans ServerStorage.ShovelModels (et ne contient aucun
-- script, règle 8), sinon le modèle en Parts (manche et lame) sert de repli.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

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

-- Modèles 3D déjà refusés (avertissement une seule fois).
local refusedTemplates: { [Instance]: boolean } = {}

-- Modèle 3D importé de cette pelle, ou nil (repli en Parts). Un modèle qui contient un script est
-- refusé et signalé (règle 8 de CLAUDE.md), un modèle sans MeshPart aussi.
local function findMeshTemplate(shovel: Types.ShovelDef): Model?
	local folder = ServerStorage:FindFirstChild(Shovels.MODEL.MESH_FOLDER)
	local template = if folder ~= nil then folder:FindFirstChild(Shovels.MODEL.MESH_PREFIX .. shovel.id) else nil
	if template == nil or not template:IsA("Model") or refusedTemplates[template] then
		return nil
	end
	local meshCount = 0
	for _, descendant in template:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			refusedTemplates[template] = true
			warn("[ShovelVisualService] Modèle refusé (contient un script) : " .. template:GetFullName())
			return nil
		end
		if descendant:IsA("MeshPart") then
			meshCount += 1
		end
	end
	if meshCount == 0 then
		refusedTemplates[template] = true
		warn("[ShovelVisualService] Modèle refusé (aucune MeshPart) : " .. template:GetFullName())
		return nil
	end
	return template
end

-- Pelle 3D : copie du modèle importé, colorée selon la pelle, mise à l'échelle et soudée à la main.
local function buildMeshShovel(shovel: Types.ShovelDef, hand: BasePart, template: Model): Model
	local look = shovel.appearance
	local model = template:Clone()
	model.Name = Shovels.MODEL.MODEL_NAME
	model:SetAttribute("ShovelId", shovel.id)
	model:SetAttribute("Mesh", true)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("SurfaceAppearance") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant:Destroy() -- le jeu colore lui-même (une seule apparence par pelle)
		elseif descendant:IsA("BasePart") then
			local isHandle = string.find(string.lower(descendant.Name), "handle", 1, true) ~= nil
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Color = if isHandle then look.handleColor else look.bladeColor
			descendant.Material = if isHandle then look.handleMaterial else look.bladeMaterial
			descendant.Reflectance = if isHandle then 0 else look.bladeReflectance
			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		end
	end
	-- Axes du monde autour du centre : le modèle importé est debout, lame en bas.
	local center, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(center.Position)
	local length = math.max(size.X, size.Y, size.Z)
	if length > 0 then
		model:ScaleTo(model:GetScale() * Shovels.MODEL.MESH_LENGTH / length)
	end
	-- Le centre est avancé d'une demi-longueur, moins la distance poignée-haut : la main tient le D.
	local forward = Shovels.MODEL.MESH_LENGTH / 2 - Shovels.MODEL.MESH_HAND_FROM_TOP
	model:PivotTo(hand.CFrame * Shovels.MODEL.MESH_GRIP * CFrame.new(0, 0, -forward) * Shovels.MODEL.MESH_ROTATION)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local joint = Instance.new("WeldConstraint")
			joint.Part0 = hand
			joint.Part1 = descendant
			joint.Parent = descendant
		end
	end
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
	local shovel = getEquippedShovel(player)
	local template = findMeshTemplate(shovel)
	local model = if template ~= nil then buildMeshShovel(shovel, hand, template) else buildShovel(shovel, hand)
	model.Parent = character
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
