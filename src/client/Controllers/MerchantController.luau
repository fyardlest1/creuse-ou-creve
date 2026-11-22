--!strict
-- Marchand : le ProximityPrompt ouvre le coffre en mode vente. Le client n'envoie que des intentions
-- (vendre ces uids, tout vendre) ; le serveur décide et répond par SellResult.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local UiConfig = require(Shared.Config.UiConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Remotes = require(Shared.Remotes)
local ChestController = require(script.Parent.ChestController)
local HudLayout = require(script.Parent.Parent.HudLayout)

local COIN_COLOR = Color3.fromRGB(255, 200, 40)
local COIN_STROKE_COLOR = Color3.fromRGB(180, 120, 20)

local player = Players.LocalPlayer

local MerchantController = {}

local sellRequestRemote: RemoteEvent
local sellSound: Sound
local effectsGui: ScreenGui
local merchantPosition: Vector3? = nil
local awaitingResult = false

local function sendSell(payload: Types.SellRequestPayload)
	-- Une requête à la fois : le serveur applique de toute façon sa propre cadence.
	if awaitingResult then
		return
	end
	awaitingResult = true
	sellRequestRemote:FireServer(payload)
	task.delay(EconomyConfig.SELL_COOLDOWN, function()
		awaitingResult = false
	end)
end

local callbacks: ChestController.SellCallbacks = {
	sellOne = function(uid: string)
		sendSell({ uids = { uid } })
	end,
	sellAll = function()
		sendSell({ all = true })
	end,
}

local function getCharacterPosition(): Vector3?
	local character = player.Character
	local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if rootPart ~= nil and rootPart:IsA("BasePart") then rootPart.Position else nil
end

-- Ferme le mode vente quand le joueur s'éloigne (le serveur refuserait de toute façon).
local function watchDistance()
	while ChestController.isOpen() and ChestController.getMode() == "sell" and merchantPosition ~= nil do
		local position = getCharacterPosition()
		if position == nil or (position - merchantPosition).Magnitude > EconomyConfig.MERCHANT_MAX_DISTANCE then
			ChestController.close()
			break
		end
		task.wait(UiConfig.MERCHANT_CLOSE_CHECK_INTERVAL)
	end
end

local function onPromptTriggered(prompt: ProximityPrompt)
	if prompt:GetAttribute(WorldConfig.INTERACTION_ATTRIBUTE) ~= WorldConfig.INTERACTIONS.Merchant then
		return
	end
	local anchor = prompt.Parent
	merchantPosition = if anchor ~= nil and anchor:IsA("Attachment") then anchor.WorldPosition else nil
	ChestController.open("sell", callbacks)
	task.spawn(watchDistance)
end

-- Pièces qui volent du centre de l'écran vers le compteur de Pièces.
local function playCoinAnimation()
	for index = 1, UiConfig.SELL_COIN_COUNT do
		task.delay((index - 1) * UiConfig.SELL_COIN_STAGGER, function()
			-- Pièce dessinée (les emojis ne s'affichent pas partout).
			local coin = Instance.new("Frame")
			coin.BackgroundColor3 = COIN_COLOR
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = coin
			local stroke = Instance.new("UIStroke")
			stroke.Color = COIN_STROKE_COLOR
			stroke.Thickness = 2
			stroke.Parent = coin
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			coin.Size = UDim2.fromOffset(UiConfig.SELL_COIN_SIZE, UiConfig.SELL_COIN_SIZE)
			local spread = UiConfig.SELL_COIN_SPREAD
			coin.Position = UDim2.new(0.5, math.random(-spread.X, spread.X), 0.5, math.random(-spread.Y, spread.Y))
			coin.Parent = effectsGui
			local tween = TweenService:Create(
				coin,
				TweenInfo.new(UiConfig.SELL_COIN_FLIGHT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = HudLayout.coinsCenter(), BackgroundTransparency = 0.3 }
			)
			tween.Completed:Connect(function()
				coin:Destroy()
			end)
			tween:Play()
		end)
	end
end

local function onSellResult(result: unknown)
	awaitingResult = false
	if typeof(result) ~= "table" then
		return
	end
	local payload = result :: Types.SellResultPayload
	if typeof(payload.count) == "number" and payload.count > 0 then
		sellSound:Play()
		playCoinAnimation()
	end
end

function MerchantController.init()
	sellRequestRemote = Remotes.get(Remotes.Names.SellRequest)

	sellSound = Instance.new("Sound")
	sellSound.Name = "Sell"
	sellSound.SoundId = UiConfig.SOUND_SELL
	sellSound.PlaybackSpeed = UiConfig.PITCH_SELL
	sellSound.Volume = UiConfig.VOLUME_SELL
	sellSound.Parent = SoundService

	effectsGui = Instance.new("ScreenGui")
	effectsGui.Name = "SellEffectsGui"
	effectsGui.ResetOnSpawn = false
	effectsGui.DisplayOrder = 20
	effectsGui.IgnoreGuiInset = false -- même repère que le HUD, pour viser le compteur de Pièces
	effectsGui.Parent = player:WaitForChild("PlayerGui")
end

function MerchantController.start()
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	Remotes.get(Remotes.Names.SellResult).OnClientEvent:Connect(onSellResult)
end

return MerchantController
