--!strict
-- Indice de premier lancement : « Clique sur une case pour creuser » (PC) ou « Touche une case pour
-- creuser » (mobile), avec une main animée au-dessus d'une case intacte, près du centre de la parcelle
-- (le bord avant est caché par le panneau de la parcelle).
-- Affiché tant que l'attribut ShowDigHint est vrai ; le serveur l'éteint pour toujours après les
-- premiers objets trouvés (sauvegardé dans le profil).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)

local TEXT_PC = "Clique sur une case pour creuser"
local TEXT_MOBILE = "Touche une case pour creuser"
local TEXT_HAND = "👇"
local WHITE = Color3.new(1, 1, 1)
local LABEL_BACKGROUND = Color3.fromRGB(28, 26, 34)

local player = Players.LocalPlayer

local DigHintController = {}

local gui: ScreenGui
local hand: Frame
local target: BasePart? = nil
local running = false

local function isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function findOwnedPlot(): Model?
	local folder = Workspace:FindFirstChild("Plots")
	if folder == nil then
		return nil
	end
	for _, plot in folder:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- Case intacte la plus proche du centre de ma parcelle.
local function findTargetCell(): BasePart?
	local plot = findOwnedPlot()
	local cells = if plot ~= nil then plot:FindFirstChild("Cells") else nil
	local base = if plot ~= nil then plot.PrimaryPart else nil
	if cells == nil or base == nil then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, cell in cells:GetChildren() do
		local hitsLeft = cell:GetAttribute("HitsLeft")
		if cell:IsA("BasePart") and typeof(hitsLeft) == "number" and hitsLeft > 0 then
			local distance = (cell.Position - base.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = cell, distance
			end
		end
	end
	return best
end

local function buildUi()
	gui = Instance.new("ScreenGui")
	gui.Name = "DigHintGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	gui.IgnoreGuiInset = true -- même repère que WorldToViewportPoint, pour placer la main

	local label = Instance.new("TextLabel")
	label.Name = "Hint"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, UiConfig.DIG_HINT_LABEL_Y)
	label.Size = UDim2.fromScale(0.5, 0.07)
	label.BackgroundColor3 = LABEL_BACKGROUND
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Text = if isMobile() then TEXT_MOBILE else TEXT_PC
	label.Parent = gui

	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(260, 32)
	limit.MaxSize = Vector2.new(480, 46)
	limit.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = label

	-- Main dessinée à l'écran au-dessus de la case visée (toujours au premier plan, taille fixe),
	-- qui monte et descend pour « pointer ». Sa position est recalculée à chaque image.
	local size = UiConfig.DIG_HINT_HAND_SIZE
	hand = Instance.new("Frame")
	hand.Name = "Hand"
	hand.AnchorPoint = Vector2.new(0.5, 1)
	hand.Size = UDim2.fromOffset(size, size)
	hand.BackgroundTransparency = 1
	hand.Visible = false
	hand.Parent = gui

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.TextScaled = true
	icon.Text = TEXT_HAND
	icon.Parent = hand

	TweenService:Create(
		icon,
		TweenInfo.new(UiConfig.DIG_HINT_BOB_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromScale(0, UiConfig.DIG_HINT_BOB_DISTANCE) }
	):Play()

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function shouldShow(): boolean
	return player:GetAttribute("ShowDigHint") == true
end

-- Place la main au-dessus de la case visée ; cachée si la case est hors de l'écran.
local function updateHand()
	local camera = Workspace.CurrentCamera
	local cell = target
	if not gui.Enabled or camera == nil or cell == nil or cell.Parent == nil then
		hand.Visible = false
		return
	end
	local top = cell.Position + Vector3.new(0, cell.Size.Y / 2, 0)
	local point, onScreen = camera:WorldToViewportPoint(top)
	hand.Visible = onScreen
	hand.Position = UDim2.fromOffset(point.X, point.Y)
end

-- Tant que l'indice est actif, la main suit la case intacte la plus proche du centre de la parcelle.
local function run()
	if running then
		return
	end
	running = true
	while shouldShow() do
		target = findTargetCell()
		gui.Enabled = true
		task.wait(UiConfig.DIG_HINT_RETARGET_INTERVAL)
	end
	gui.Enabled = false
	target = nil
	running = false
end

function DigHintController.init()
	buildUi()
end

function DigHintController.start()
	RunService.RenderStepped:Connect(updateHand)
	player:GetAttributeChangedSignal("ShowDigHint"):Connect(function()
		if shouldShow() then
			task.spawn(run)
		end
	end)
	if shouldShow() then
		task.spawn(run)
	end
end

return DigHintController
