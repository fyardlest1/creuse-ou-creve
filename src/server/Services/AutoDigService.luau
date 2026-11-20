--!strict
-- Game pass Creusage auto : quand le joueur l'active, le serveur donne 1 coup toutes les 0,8 s sur une
-- case intacte de sa parcelle, où qu'il soit, tant que son coffre n'est pas plein (le creusage reprend
-- tout seul après une vente). Plus lent que le creusage à la main (0,2 s), pour que jouer reste rentable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PurchaseService = require(script.Parent.PurchaseService)
local DigService = require(script.Parent.DigService)

local TOGGLE_COOLDOWN = 0.3 -- secondes entre deux bascules

local AutoDigService = {}

local enabled: { [Player]: boolean } = {}
local lastToggle: { [Player]: number } = {}

local function setEnabled(player: Player, on: boolean)
	enabled[player] = if on then true else nil
	player:SetAttribute("AutoDig", on)
	if not on then
		player:SetAttribute("AutoDigPaused", false)
	end
end

local function onToggle(player: Player, on: unknown)
	if typeof(on) ~= "boolean" then
		return
	end
	local now = os.clock()
	local last = lastToggle[player]
	if last ~= nil and now - last < TOGGLE_COOLDOWN then
		return
	end
	lastToggle[player] = now
	if on and not PurchaseService.ownsPass(player, "AutoDig") then
		print(string.format("[AutoDigService] Refusé (%s) : pass Creusage auto non possédé", player.Name))
		return
	end
	setEnabled(player, on)
end

function AutoDigService.isEnabled(player: Player): boolean
	return enabled[player] == true
end

function AutoDigService.init() end

function AutoDigService.start()
	Remotes.get(Remotes.Names.AutoDigToggle).OnServerEvent:Connect(onToggle)
	Players.PlayerRemoving:Connect(function(player)
		enabled[player] = nil
		lastToggle[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(MonetizationConfig.AUTO_DIG_INTERVAL)
			for player in enabled do
				if player.Parent == Players and PlayerDataService.getData(player) ~= nil then
					local dug = DigService.autoHit(player)
					local paused = not dug
					if player:GetAttribute("AutoDigPaused") ~= paused then
						player:SetAttribute("AutoDigPaused", paused)
					end
				end
			end
		end
	end)
end

return AutoDigService
