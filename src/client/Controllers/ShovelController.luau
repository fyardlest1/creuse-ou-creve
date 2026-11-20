--!strict
-- Geste de creusage procédural : l'épaule droite lève la pelle puis frappe.
-- À chaque image, juste après l'Animator (PreSimulation), on ajoute une rotation au Transform de
-- l'articulation d'épaule (Motor6D ou AnimationConstraint) : le geste se combine aux animations
-- de marche et d'attente. Le Transform n'est pas répliqué, donc chaque client anime lui-même
-- les personnages : le joueur qui creuse joue son geste tout de suite, les autres le jouent à la
-- réception de DigSwing.
-- Désactive aussi le Backpack : la pelle est soudée à la main, il n'y a rien à ranger.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiConfig = require(Shared.Config.UiConfig)
local Remotes = require(Shared.Remotes)

type Joint = Motor6D | AnimationConstraint

-- Épaule droite : R15 puis R6.
local SHOULDERS = {
	{ part = "RightUpperArm", joint = "RightShoulder" },
	{ part = "Torso", joint = "Right Shoulder" },
}
local CORE_GUI_RETRY_DELAY = 0.5
local CORE_GUI_MAX_TRIES = 10

local player = Players.LocalPlayer

local ShovelController = {}

-- Gestes en cours : instant de départ, par articulation.
local activeSwings: { [Joint]: number } = {}

local function findShoulder(character: Model): Joint?
	for _, entry in SHOULDERS do
		local part = character:FindFirstChild(entry.part)
		local joint = if part ~= nil then part:FindFirstChild(entry.joint) else nil
		if joint ~= nil and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			return joint :: Joint
		end
	end
	return nil
end

local function ease(alpha: number, style: Enum.EasingStyle): number
	return TweenService:GetValue(math.clamp(alpha, 0, 1), style, Enum.EasingDirection.Out)
end

-- Angle de l'épaule (degrés) au temps t du geste, ou nil si le geste est terminé.
local function getSwingAngle(t: number): number?
	local raiseEnd = UiConfig.SWING_RAISE_TIME
	local strikeEnd = raiseEnd + UiConfig.SWING_STRIKE_TIME
	local recoverEnd = strikeEnd + UiConfig.SWING_RECOVER_TIME
	local raise, strike = UiConfig.SWING_RAISE_ANGLE, UiConfig.SWING_STRIKE_ANGLE
	if t < raiseEnd then
		return raise * ease(t / UiConfig.SWING_RAISE_TIME, Enum.EasingStyle.Quad)
	elseif t < strikeEnd then
		return raise + (strike - raise) * ease((t - raiseEnd) / UiConfig.SWING_STRIKE_TIME, Enum.EasingStyle.Quad)
	elseif t < recoverEnd then
		return strike * (1 - ease((t - strikeEnd) / UiConfig.SWING_RECOVER_TIME, Enum.EasingStyle.Sine))
	end
	return nil
end

local function applySwings()
	local now = os.clock()
	for joint, startTime in activeSwings do
		local angle = getSwingAngle(now - startTime)
		if angle == nil or joint.Parent == nil then
			activeSwings[joint] = nil
		else
			joint.Transform = joint.Transform * CFrame.fromAxisAngle(UiConfig.SWING_AXIS, math.rad(angle))
		end
	end
end

-- Joue le geste sur un personnage : lever, frapper, revenir. Un nouveau geste remplace le précédent.
function ShovelController.playSwing(character: Model)
	local joint = findShoulder(character)
	if joint ~= nil then
		activeSwings[joint] = os.clock()
	end
end

-- Geste du joueur local ; onImpact est appelé quand la lame touche la case (particules, son).
function ShovelController.swingLocal(onImpact: () -> ())
	local character = player.Character
	if character ~= nil then
		ShovelController.playSwing(character)
	end
	task.delay(UiConfig.SWING_RAISE_TIME + UiConfig.SWING_STRIKE_TIME, onImpact)
end

-- SetCoreGuiEnabled peut échouer tant que les scripts du CoreGui ne sont pas prêts : on réessaie.
local function disableBackpack()
	for _ = 1, CORE_GUI_MAX_TRIES do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			return
		end
		task.wait(CORE_GUI_RETRY_DELAY)
	end
	warn("[ShovelController] Impossible de désactiver le Backpack")
end

function ShovelController.init()
	task.spawn(disableBackpack)
end

function ShovelController.start()
	-- PreSimulation passe après l'Animator : notre rotation s'ajoute à la pose animée de l'image.
	RunService.PreSimulation:Connect(applySwings)

	Remotes.get(Remotes.Names.DigSwing).OnClientEvent:Connect(function(digger: unknown)
		if typeof(digger) ~= "Instance" or not digger:IsA("Player") or digger == player then
			return
		end
		local character = digger.Character
		if character ~= nil then
			ShovelController.playSwing(character)
		end
	end)
end

return ShovelController
