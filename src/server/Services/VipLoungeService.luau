--!strict
-- Accès au salon VIP (plan semaine 5, section 9). La porte (WorldService) est dans un groupe de
-- collision que seuls les personnages VIP traversent : ce service range les parties du personnage de
-- chaque VIP dans le groupe des membres. C'est du statut visible, pas un avantage de jeu.
--
-- Garde-fou : la physique du personnage est simulée par son client, donc un client modifié pourrait
-- traverser la porte. Le serveur vérifie régulièrement qu'aucun joueur non VIP n'est dans le salon et
-- le replace devant la porte. La vente au Marchand VIP est de toute façon revalidée (EconomyService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local PurchaseService = require(script.Parent.PurchaseService)
local WorldService = require(script.Parent.WorldService)

local VipLoungeService = {}

local characterConnections: { [Player]: { RBXScriptConnection } } = {}

-- Vrai si la position est dans la boîte (centre et taille), toutes faces comprises.
function VipLoungeService.isInside(position: Vector3, box: CFrame, size: Vector3): boolean
	local localPosition = box:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= size.X / 2
		and math.abs(localPosition.Y) <= size.Y / 2
		and math.abs(localPosition.Z) <= size.Z / 2
end

local function setGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = WorldConfig.VIP_MEMBER_COLLISION_GROUP
	end
end

-- Range toutes les parties du personnage (et celles ajoutées ensuite : apparence de l'avatar,
-- accessoires) dans le groupe des membres.
local function admitCharacter(player: Player, character: Model)
	for _, descendant in character:GetDescendants() do
		setGroup(descendant)
	end
	local connections = characterConnections[player] or {}
	characterConnections[player] = connections
	table.insert(connections, character.DescendantAdded:Connect(setGroup))
end

local function admit(player: Player)
	if characterConnections[player] ~= nil then
		return -- déjà admis
	end
	characterConnections[player] = {}
	if player.Character ~= nil then
		admitCharacter(player, player.Character)
	end
	table.insert(
		characterConnections[player],
		player.CharacterAdded:Connect(function(character)
			admitCharacter(player, character)
		end)
	)
	print("[VipLoungeService] Accès au salon VIP pour " .. player.Name)
end

-- Replace devant la porte tout joueur non VIP trouvé dans le salon.
local function evictIntruders()
	local box, size = WorldService.getVipLoungeBox()
	local exit = WorldService.getVipLoungeExit()
	for _, player in Players:GetPlayers() do
		if PurchaseService.ownsPass(player, "VIP") then
			continue
		end
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") and VipLoungeService.isInside(root.Position, box, size) then
			(character :: Model):PivotTo(CFrame.lookAt(exit, exit + Vector3.new(1, 0, 0)))
			warn("[VipLoungeService] " .. player.Name .. " (non VIP) replacé hors du salon")
		end
	end
end

function VipLoungeService.init() end

function VipLoungeService.start()
	PurchaseService.onPassOwned(function(player: Player, key)
		if key == "VIP" then
			admit(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, connection in characterConnections[player] or {} do
			connection:Disconnect()
		end
		characterConnections[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(WorldConfig.VIP_EVICT_CHECK_INTERVAL)
			evictIntruders()
		end
	end)
end

return VipLoungeService
