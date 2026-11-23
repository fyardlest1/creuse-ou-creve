--!strict
-- Geste de creusage. Si UiConfig.DIG_ANIMATION_ID est renseigné et que l'animation charge, chaque
-- client la joue sur son propre personnage (l'Animator la réplique aux autres joueurs). Sinon, repli :
-- geste procédural, l'épaule droite lève la pelle puis frappe.
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

-- Animation de creusage : piste chargée pour le personnage actuel du joueur local, ou nil (repli).
local digTrack: AnimationTrack? = nil
local animationEnabled = UiConfig.DIG_ANIMATION_ID ~= ""

-- Charge l'animation sur le personnage. En cas d'échec, on reste sur le geste procédural.
local function loadDigAnimation(character: Model)
	digTrack = nil
	if not animationEnabled then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", UiConfig.DIG_ANIMATION_LOAD_TIMEOUT)
	local animator = if humanoid ~= nil
		then humanoid:WaitForChild("Animator", UiConfig.DIG_ANIMATION_LOAD_TIMEOUT)
		else nil
	if animator == nil or not animator:IsA("Animator") then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = UiConfig.DIG_ANIMATION_ID
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok or track == nil then
		warn("[ShovelController] Animation de creusage impossible à charger, geste de repli : " .. tostring(track))
		return
	end
	-- La durée reste à 0 tant que l'animation n'est pas téléchargée.
	local deadline = os.clock() + UiConfig.DIG_ANIMATION_LOAD_TIMEOUT
	while track.Length == 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if track.Length == 0 then
		warn("[ShovelController] Animation de creusage introuvable (identifiant ou propriétaire ?), geste de repli")
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	if player.Character == character then
		digTrack = track
	end
end

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

-- Vrai si le joueur local creuse avec l'animation (sinon le geste procédural).
function ShovelController.usesAnimation(): boolean
	return digTrack ~= nil
end

-- Geste du joueur local ; onImpact est appelé quand la lame touche la case (particules, son).
function ShovelController.swingLocal(onImpact: () -> ())
	local track = digTrack
	if track ~= nil then
		track:Play(0)
		task.delay(UiConfig.DIG_ANIMATION_IMPACT_TIME, onImpact)
		return
	end
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

	player.CharacterAdded:Connect(function(character)
		task.spawn(loadDigAnimation, character)
	end)
	if player.Character ~= nil then
		task.spawn(loadDigAnimation, player.Character)
	end

	Remotes.get(Remotes.Names.DigSwing).OnClientEvent:Connect(function(digger: unknown)
		if typeof(digger) ~= "Instance" or not digger:IsA("Player") or digger == player then
			return
		end
		-- Avec l'animation, le client du joueur qui creuse la joue et l'Animator la réplique : rien à faire.
		if animationEnabled then
			return
		end
		local character = digger.Character
		if character ~= nil then
			ShovelController.playSwing(character)
		end
	end)
end

return ShovelController
