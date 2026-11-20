--!strict
-- Rétention (plan semaine 4, sections 6 et 7) : récompenses quotidiennes, 3 quêtes par jour, Index de
-- collection et ses paliers, badges Roblox, entonnoir d'accueil. Suit le jeu par GameEvents.
-- Le jour est le jour UTC : floor(os.time() / 86400).

local AnalyticsService = game:GetService("AnalyticsService")
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local RetentionConfig = require(Shared.Config.RetentionConfig)
local Items = require(Shared.Config.Items)
local Strata = require(Shared.Config.Strata)
local Remotes = require(Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local BoostService = require(script.Parent.BoostService)
local ProtectionService = require(script.Parent.ProtectionService)
local DayNightService = require(script.Parent.DayNightService)
local GameEvents = require(script.Parent.Parent.GameEvents)

type Reward = RetentionConfig.Reward
type QuestKind = RetentionConfig.QuestKind
type BadgeKey = RetentionConfig.BadgeKey

local TEXT_INDEX_TIER = "Index de %s : %d %% trouvés !"
local TEXT_TITLE_EARNED = "Nouveau titre : %s"
local TEXT_QUEST_DONE = "Quête réussie : %s"
local TEXT_ALL_QUESTS = "Les 3 quêtes du jour sont faites : +1 Potion de chance"
local DAILY_CLAIM_COOLDOWN = 1 -- secondes
local STATE_REQUEST_COOLDOWN = 0.5
local RARE_OR_BETTER = { Rare = true, Epic = true, Legendary = true, Secret = true }

local RetentionService = {}

local remotes: {
	state: RemoteEvent,
	notice: RemoteEvent,
}
local lastClaim: { [Player]: number } = {}
local lastStateRequest: { [Player]: number } = {}
local badgesAwarded: { [Player]: { [string]: boolean } } = {}

local function log(message: string)
	print("[RetentionService] " .. message)
end

-- Jour UTC courant. Surchargeable par les tests (Studio) pour simuler un changement de jour.
local dayOffset = 0
function RetentionService.today(): number
	return math.floor(os.time() / RetentionConfig.SECONDS_PER_DAY) + dayOffset
end

local function layerOf(data: any): number
	return Strata.fromDepth(data.depth).layer
end

------------------------------------------------------------------------------------------------
-- Récompenses
------------------------------------------------------------------------------------------------

local function grantReward(player: Player, data: any, reward: Reward, reason: Types.EconomyReason, sku: string)
	if reward.coins ~= nil and reward.coins > 0 then
		EconomyService.addCoins(player, reward.coins, reason, sku)
	end
	if reward.luckPotion ~= nil and reward.luckPotion > 0 then
		BoostService.addToReserve(player, data, "luckPotion", reward.luckPotion)
	end
	if reward.shield ~= nil and reward.shield > 0 then
		BoostService.addToReserve(player, data, "shield", reward.shield)
	end
end

local function notify(player: Player, text: string)
	remotes.notice:FireClient(player, text)
end

------------------------------------------------------------------------------------------------
-- Badges et entonnoir
------------------------------------------------------------------------------------------------

local function awardBadge(player: Player, key: BadgeKey)
	local badgeId = RetentionConfig.BADGES[key]
	local awarded = badgesAwarded[player]
	if badgeId == nil or badgeId == 0 or awarded == nil or awarded[key] then
		return
	end
	awarded[key] = true
	task.spawn(function()
		local ok, err = pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if not ok then
			awarded[key] = nil -- on réessaiera au prochain événement
			warn(string.format("[RetentionService] Badge %s non décerné à %s : %s", key, player.Name, tostring(err)))
		end
	end)
end

local function funnelStep(player: Player, data: any, stepName: string)
	if data.funnelSteps[stepName] then
		return
	end
	local index = table.find(RetentionConfig.FUNNEL_STEPS, stepName)
	if index == nil then
		return
	end
	data.funnelSteps[stepName] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, stepName)
	end)
end

------------------------------------------------------------------------------------------------
-- Quêtes
------------------------------------------------------------------------------------------------

local function questText(kind: string, target: number): string
	for _, template in RetentionConfig.QUEST_TEMPLATES do
		if template.kind == kind then
			return string.format(template.text, tostring(target))
		end
	end
	return kind
end

-- Tire 3 quêtes distinctes pour le jour, adaptées à la couche ; jamais de quête de vol si le joueur est protégé.
function RetentionService.rollQuests(layer: number, isProtected: boolean, rng: Random): { Types.QuestState }
	local pool = {}
	for _, template in RetentionConfig.QUEST_TEMPLATES do
		if not (template.stealRelated and isProtected) then
			table.insert(pool, template)
		end
	end
	local quests: { Types.QuestState } = {}
	local base = RetentionConfig.QUEST_BASE_COINS_BY_LAYER[layer] or RetentionConfig.QUEST_BASE_COINS_BY_LAYER[1]
	for _ = 1, math.min(RetentionConfig.QUESTS_PER_DAY, #pool) do
		local template = table.remove(pool, rng:NextInteger(1, #pool)) :: any
		table.insert(quests, {
			id = template.kind,
			target = template.targetByLayer[layer] or template.targetByLayer[1],
			progress = 0,
			claimed = false,
			reward = math.floor(base * template.rewardFactor / 50 + 0.5) * 50,
		})
	end
	return quests
end

local function ensureQuests(player: Player, data: any)
	local today = RetentionService.today()
	if data.quests.day == today then
		return
	end
	data.quests = {
		day = today,
		list = RetentionService.rollQuests(layerOf(data), ProtectionService.isProtected(player), Random.new()),
		bonusClaimed = false,
	}
end

local function pushState(player: Player) end -- défini plus bas

local function progressQuest(player: Player, kind: QuestKind, amount: number)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	ensureQuests(player, data)
	local changed = false
	for _, quest in data.quests.list do
		if quest.id == kind and not quest.claimed then
			quest.progress = math.min(quest.target, quest.progress + amount)
			changed = true
			if quest.progress >= quest.target then
				quest.claimed = true
				grantReward(player, data, { coins = quest.reward }, "Reward", "Quest" .. kind)
				notify(player, string.format(TEXT_QUEST_DONE, questText(kind, quest.target)))
			end
		end
	end
	if not data.quests.bonusClaimed and #data.quests.list > 0 then
		local allDone = true
		for _, quest in data.quests.list do
			allDone = allDone and quest.claimed
		end
		if allDone then
			data.quests.bonusClaimed = true
			grantReward(player, data, RetentionConfig.QUEST_ALL_DONE_REWARD, "Reward", "QuestsAllDone")
			notify(player, TEXT_ALL_QUESTS)
		end
	end
	if changed then
		pushState(player)
	end
end

------------------------------------------------------------------------------------------------
-- Index de collection
------------------------------------------------------------------------------------------------

-- Pourcentage des objets d'une couche déjà trouvés (au moins une fois, avec ou sans mutation).
function RetentionService.indexPercent(index: { [string]: any }, layer: number): number
	local total, found = 0, 0
	for _, item in Items.list do
		if item.layer == layer then
			total += 1
			if index[item.id] ~= nil then
				found += 1
			end
		end
	end
	return if total == 0 then 0 else found / total * 100
end

local function applyTitle(player: Player, title: string?)
	player:SetAttribute("Title", title or "")
	local character = player.Character
	local head = if character ~= nil then character:FindFirstChild("Head") else nil
	if head == nil then
		return
	end
	local tag = head:FindFirstChild("TitleTag")
	if title == nil or title == "" then
		if tag ~= nil then
			tag:Destroy()
		end
		return
	end
	if tag == nil then
		tag = Instance.new("BillboardGui")
		tag.Name = "TitleTag"
		tag.Size = UDim2.fromOffset(RetentionConfig.TITLE_TAG_SIZE.X, RetentionConfig.TITLE_TAG_SIZE.Y)
		tag.StudsOffset = Vector3.new(0, RetentionConfig.TITLE_TAG_HEIGHT, 0)
		tag.MaxDistance = RetentionConfig.TITLE_TAG_MAX_DISTANCE
		tag.Adornee = head
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = RetentionConfig.TITLE_TAG_COLOR
		label.TextStrokeTransparency = 0.3
		label.Parent = tag
		tag.Parent = head
	end
	((tag :: BillboardGui):FindFirstChild("Text") :: TextLabel).Text = title
end

local function checkIndexTiers(player: Player, data: any, layer: number)
	local stratum = Strata.byLayer[layer]
	if stratum == nil then
		return
	end
	local percent = RetentionService.indexPercent(data.index, layer)
	for _, tier in RetentionConfig.INDEX_TIERS do
		local key = layer .. ":" .. tier.percent
		if percent >= tier.percent and not data.indexRewards[key] then
			data.indexRewards[key] = true
			notify(player, string.format(TEXT_INDEX_TIER, stratum.nameWithArticle, tier.percent))
			if tier.reward ~= nil then
				local reward = table.clone(tier.reward)
				if reward.coins ~= nil then
					reward.coins *= RetentionConfig.INDEX_COIN_REWARD_MULTIPLIER_BY_LAYER[layer] or 1
				end
				grantReward(player, data, reward, "Reward", "Index" .. key)
			end
			if tier.title then
				data.title = string.format(RetentionConfig.INDEX_TITLE, stratum.nameWithArticle)
				applyTitle(player, data.title)
				notify(player, string.format(TEXT_TITLE_EARNED, data.title))
				if layer == 1 then
					awardBadge(player, "DirtIndex")
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------------
-- Quotidien
------------------------------------------------------------------------------------------------

function RetentionService.isDailyAvailable(data: any): boolean
	return data.daily.lastClaimDay < RetentionService.today()
end

-- Case du calendrier qui sera réclamée (1 à 7). Manquer un jour ne remet pas à zéro.
function RetentionService.nextCalendarDay(data: any): number
	return data.daily.calendarDay % #RetentionConfig.DAILY_REWARDS + 1
end

local function onDailyClaim(player: Player)
	local now = os.clock()
	local last = lastClaim[player]
	if last ~= nil and now - last < DAILY_CLAIM_COOLDOWN then
		return
	end
	lastClaim[player] = now
	local data = PlayerDataService.getData(player)
	if data == nil or not RetentionService.isDailyAvailable(data) then
		return
	end
	local calendarDay = RetentionService.nextCalendarDay(data)
	data.daily.calendarDay = calendarDay
	data.daily.lastClaimDay = RetentionService.today()
	grantReward(player, data, RetentionConfig.DAILY_REWARDS[calendarDay], "DailyReward", "Daily" .. calendarDay)
	log(string.format("%s réclame le jour %d du calendrier", player.Name, calendarDay))
	pushState(player)
end

------------------------------------------------------------------------------------------------
-- État envoyé au client (quotidien, quêtes, Index)
------------------------------------------------------------------------------------------------

pushState = function(player: Player)
	local data = PlayerDataService.getData(player)
	if data == nil then
		return
	end
	ensureQuests(player, data)
	local quests = {}
	for _, quest in data.quests.list do
		table.insert(quests, {
			text = questText(quest.id, quest.target),
			progress = quest.progress,
			target = quest.target,
			reward = quest.reward,
			done = quest.claimed,
		})
	end
	remotes.state:FireClient(player, {
		daily = {
			available = RetentionService.isDailyAvailable(data),
			nextDay = RetentionService.nextCalendarDay(data),
			lastDay = data.daily.calendarDay,
		},
		quests = quests,
		questsBonusClaimed = data.quests.bonusClaimed,
		index = data.index,
		indexRewards = data.indexRewards,
		title = data.title,
	})
	player:SetAttribute("DailyAvailable", RetentionService.isDailyAvailable(data))
end

function RetentionService.pushState(player: Player)
	pushState(player)
end

-- Studio seulement : décale le jour UTC pour tester le changement de jour.
function RetentionService.shiftDayForTest(days: number)
	if not game:GetService("RunService"):IsStudio() then
		return
	end
	dayOffset += days
	for _, player in Players:GetPlayers() do
		pushState(player)
	end
end

------------------------------------------------------------------------------------------------
-- Branchements
------------------------------------------------------------------------------------------------

local function onLoaded(player: Player, data: any)
	badgesAwarded[player] = {}
	local today = RetentionService.today()
	funnelStep(player, data, "Arrivee")
	if data.daily.firstSeenDay == 0 then
		data.daily.firstSeenDay = today
	elseif today > data.daily.firstSeenDay then
		funnelStep(player, data, "RetourAutreJour")
	end
	-- Badges déjà mérités avant leur création (profils existants).
	if data.stats.totalDigs > 0 then
		awardBadge(player, "FirstDig")
	end
	if (data.stats.foundByRarity.Secret or 0) > 0 then
		awardBadge(player, "FirstSecret")
	end
	if data.depth >= Strata.byId.Clay.minDepth then
		awardBadge(player, "EnterClay")
	end
	if data.depth >= Strata.byId.Rock.minDepth then
		awardBadge(player, "EnterRock")
	end
	for layer = 1, #Strata.list do
		checkIndexTiers(player, data, layer)
	end
	applyTitle(player, data.title)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 5)
		local current = PlayerDataService.getData(player)
		if current ~= nil then
			applyTitle(player, current.title)
		end
	end)
	pushState(player)
end

function RetentionService.init()
	remotes = {
		state = Remotes.get(Remotes.Names.RetentionState),
		notice = Remotes.get(Remotes.Names.RetentionNotice),
	}
end

function RetentionService.start()
	PlayerDataService.onLoaded(onLoaded)
	Remotes.get(Remotes.Names.DailyClaim).OnServerEvent:Connect(onDailyClaim)
	Remotes.get(Remotes.Names.RetentionStateRequest).OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		local last = lastStateRequest[player]
		if last ~= nil and now - last < STATE_REQUEST_COOLDOWN then
			return
		end
		lastStateRequest[player] = now
		pushState(player)
	end)

	GameEvents.digHit.connect(function(player: Player)
		local data = PlayerDataService.getData(player)
		if data ~= nil then
			funnelStep(player, data, "PremierCoupDePelle")
			awardBadge(player, "FirstDig")
		end
	end)
	GameEvents.itemFound.connect(function(player: Player, item: Types.ItemInstance)
		local data = PlayerDataService.getData(player)
		if data == nil then
			return
		end
		funnelStep(player, data, "PremierObjet")
		local itemDef = Items.byId[item.itemId]
		local isNew = data.index[item.itemId] == nil
		PlayerDataService.recordInIndex(data, item.itemId, item.mutation)
		if itemDef ~= nil and isNew then
			checkIndexTiers(player, data, itemDef.layer)
		end
		if item.rarity == "Secret" then
			awardBadge(player, "FirstSecret")
		end
		progressQuest(player, "DigCells", 1)
		if RARE_OR_BETTER[item.rarity] then
			progressQuest(player, "FindRare", 1)
		end
		if item.mutation ~= nil then
			progressQuest(player, "FindMutation", 1)
		end
		if isNew then
			pushState(player)
		end
	end)
	GameEvents.depthReached.connect(function(player: Player, _depth: number, stratumId: string)
		local data = PlayerDataService.getData(player)
		if data == nil then
			return
		end
		progressQuest(player, "NewDepth", 1)
		if stratumId == "Clay" then
			funnelStep(player, data, "EntreeArgile")
			awardBadge(player, "EnterClay")
		elseif stratumId == "Rock" then
			awardBadge(player, "EnterRock")
		end
	end)
	GameEvents.sold.connect(function(player: Player, coins: number)
		local data = PlayerDataService.getData(player)
		if data ~= nil then
			funnelStep(player, data, "PremiereVente")
			progressQuest(player, "SellCoins", coins)
		end
	end)
	GameEvents.shovelBought.connect(function(player: Player, shovelId: string)
		local data = PlayerDataService.getData(player)
		if data ~= nil and shovelId == "Iron" then
			funnelStep(player, data, "PelleEnFer")
		end
	end)
	GameEvents.stealSucceeded.connect(function(thief: Player)
		awardBadge(thief, "FirstSteal")
		progressQuest(thief, "Steal", 1)
	end)
	GameEvents.ejected.connect(function(owner: Player)
		awardBadge(owner, "FirstEjection")
		progressQuest(owner, "Eject", 1)
	end)
	DayNightService.onPhaseChanged(function(phase)
		if phase ~= "Night" then
			return
		end
		for _, player in Players:GetPlayers() do
			local data = PlayerDataService.getData(player)
			if data ~= nil then
				funnelStep(player, data, "PremiereNuit")
			end
		end
	end)

	-- Changement de jour UTC pendant que les joueurs sont connectés : quotidien et quêtes suivent.
	task.spawn(function()
		local lastDay = RetentionService.today()
		while true do
			task.wait(RetentionConfig.DAY_CHECK_INTERVAL)
			local today = RetentionService.today()
			if today ~= lastDay then
				lastDay = today
				for _, player in Players:GetPlayers() do
					pushState(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
		lastStateRequest[player] = nil
		badgesAwarded[player] = nil
	end)
end

return RetentionService
