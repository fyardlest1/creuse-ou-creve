--!strict
-- Disposition du haut de l'écran, partagée par le HUD, le minuteur jour/nuit, les annonces et les panneaux
-- du monde. Les pastilles (minuteur, profondeur, couche, coffre, Pièces) sont rangées depuis la gauche et
-- passent à la ligne avant la zone de la liste des joueurs de Roblox, en haut à droite. Sur téléphone
-- (écran bas), tout est plus petit et tient en général sur deux lignes.
-- Coordonnées en pixels, dans la zone d'interface (sous la barre de Roblox).

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UiConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.UiConfig)

export type Rect = { position: Vector2, size: Vector2 }
export type PillName = "timer" | "depth" | "stratum" | "chest" | "coins"
export type Layout = {
	compact: boolean,
	margin: number,
	spacing: number,
	pillHeight: number,
	pills: { [PillName]: Rect },
	freeLeft: number, -- zone libre du haut, hors liste des joueurs
	freeRight: number,
	pillsBottom: number, -- bas des pastilles du haut
	statusTop: number, -- ligne de la protection débutant et des bonus actifs, sous les pastilles
	hudBottom: number, -- bas du HUD du haut, ligne d'état comprise
	chipWidth: number,
	arrow: Rect, -- flèche vers le Marchand (ou son coffre), à droite de la zone libre
	arrowDialSize: number,
	bannerLeft: number, -- bandeaux et annonces : zone libre, sans la colonne de la flèche
	bannerRight: number,
	bannerTop: number,
	bannerHeight: number,
	announceTop: number,
	announceHeight: number,
	sideButtonsCenterY: number, -- centre des boutons latéraux, jamais au-dessus du bas du HUD
}

local PILL_ORDER: { PillName } = { "timer", "depth", "stratum", "chest", "coins" }

local HudLayout = {}

local listeners: { (Layout) -> () } = {}
local current: Layout? = nil
local started = false
local statusRowVisible = false

local function compute(viewport: Vector2, guiHeight: number): Layout
	local compact = viewport.Y < UiConfig.COMPACT_SCREEN_HEIGHT
	local width = viewport.X
	local margin = UiConfig.HUD_MARGIN
	local top = UiConfig.HUD_TOP_MARGIN
	local spacing = if compact then UiConfig.HUD_SPACING_COMPACT else UiConfig.HUD_SPACING
	local height = if compact then UiConfig.HUD_PILL_HEIGHT_COMPACT else UiConfig.HUD_PILL_HEIGHT
	local widths = if compact then UiConfig.HUD_PILL_WIDTHS_COMPACT else UiConfig.HUD_PILL_WIDTHS
	local reserved = if compact
		then math.max(UiConfig.PLAYER_LIST_RESERVED_MIN_COMPACT, width * UiConfig.PLAYER_LIST_RESERVED_SCALE_COMPACT)
		else UiConfig.PLAYER_LIST_RESERVED_WIDTH
	local freeRight = math.max(margin + widths.timer, width - reserved)

	-- Rangement de gauche à droite, à la ligne quand la pastille suivante entrerait dans la zone réservée.
	local pills = {}
	local x, y = margin, top
	for _, name in PILL_ORDER do
		local pillWidth = widths[name]
		if x > margin and x + pillWidth > freeRight then
			x = margin
			y += height + spacing
		end
		pills[name] = { position = Vector2.new(x, y), size = Vector2.new(pillWidth, height) }
		x += pillWidth + spacing
	end
	local firstRowBottom = top + height
	local statusTop = y + height + spacing
	local hudBottom = statusTop + height

	local arrowDial = if compact then UiConfig.MERCHANT_ARROW_SIZE_COMPACT else UiConfig.MERCHANT_ARROW_SIZE
	local arrowWidth = if compact then UiConfig.MERCHANT_ARROW_WIDTH_COMPACT else UiConfig.MERCHANT_ARROW_WIDTH
	local arrow = {
		position = Vector2.new(freeRight - arrowWidth, firstRowBottom + spacing),
		size = Vector2.new(arrowWidth, arrowDial + UiConfig.MERCHANT_ARROW_CAPTION_HEIGHT),
	}

	-- Bandeaux : sur grand écran sous la ligne d'état ; sur téléphone à sa hauteur (elle est souvent vide),
	-- pour ne pas descendre sur les boutons Coffre, Quêtes et Index.
	local bannerHeight = if compact then UiConfig.BANNER_HEIGHT_COMPACT else UiConfig.BANNER_HEIGHT
	local bannerTop = if compact then statusTop else hudBottom + spacing
	local announceHeight = if compact then UiConfig.ANNOUNCE_HEIGHT_COMPACT else UiConfig.ANNOUNCE_SIZE.Y

	return {
		compact = compact,
		margin = margin,
		spacing = spacing,
		pillHeight = height,
		pills = pills :: any,
		freeLeft = margin,
		freeRight = freeRight,
		pillsBottom = y + height,
		statusTop = statusTop,
		hudBottom = hudBottom,
		chipWidth = if compact then UiConfig.BOOST_CHIP_WIDTH_COMPACT else UiConfig.BOOST_CHIP_WIDTH,
		arrow = arrow,
		arrowDialSize = arrowDial,
		-- La flèche s'affiche avec le bandeau « coffre plein » : ils ne doivent pas se recouvrir.
		bannerLeft = margin,
		bannerRight = arrow.position.X - spacing,
		bannerTop = bannerTop,
		bannerHeight = bannerHeight,
		-- Sur téléphone, l'annonce prend la place du bandeau (elle passe devant) plutôt que de descendre
		-- sur les boutons ; sur grand écran, elle se range dessous.
		announceTop = if compact then bannerTop else bannerTop + bannerHeight + spacing,
		announceHeight = announceHeight,
		-- Écran bas (Android d'entrée de gamme) : les boutons descendent juste sous le HUD.
		sideButtonsCenterY = math.max(
			guiHeight * UiConfig.HUD_SIDE_BUTTONS_Y,
			hudBottom + spacing + UiConfig.HUD_CHEST_BUTTON_SIZE / 2
		),
	}
end

local function viewportSize(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
end

local function refresh()
	local viewport = viewportSize()
	local layout = compute(viewport, viewport.Y - GuiService:GetGuiInset().Y)
	current = layout
	for _, callback in listeners do
		task.spawn(callback, layout)
	end
end

local function ensureStarted()
	if started then
		return
	end
	started = true
	local cameraConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if cameraConnection ~= nil then
			cameraConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera ~= nil then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
		end
		refresh()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(refresh) -- hauteur de la barre de Roblox
	watchCamera()
end

-- Disposition actuelle.
function HudLayout.get(): Layout
	ensureStarted()
	return current :: Layout
end

-- Appelle callback tout de suite, puis à chaque changement de taille d'écran (rotation, fenêtre).
function HudLayout.observe(callback: (Layout) -> ())
	ensureStarted()
	table.insert(listeners, callback)
	callback(current :: Layout)
end

-- Place un élément à un rectangle de la disposition (élément posé directement dans un ScreenGui).
function HudLayout.place(element: GuiObject, rect: Rect)
	element.AnchorPoint = Vector2.zero
	element.Position = UDim2.fromOffset(rect.position.X, rect.position.Y)
	element.Size = UDim2.fromOffset(rect.size.X, rect.size.Y)
end

-- Centre du compteur de Pièces, en coordonnées d'interface (animation des pièces après une vente).
function HudLayout.coinsCenter(): UDim2
	local coins = HudLayout.get().pills.coins
	local center = coins.position + coins.size / 2
	return UDim2.fromOffset(center.X, center.Y)
end

-- Le HUD signale si sa ligne d'état (protection, bonus actifs) affiche quelque chose.
function HudLayout.setStatusRowVisible(visible: boolean)
	statusRowVisible = visible
end

-- Bas du HUD du haut en pixels d'écran (barre de Roblox comprise), pour WorldToViewportPoint.
-- La ligne d'état ne compte que lorsqu'elle affiche quelque chose.
function HudLayout.hudBottomOnScreen(): number
	local layout = HudLayout.get()
	return GuiService:GetGuiInset().Y + (if statusRowVisible then layout.hudBottom else layout.pillsBottom)
end

return HudLayout
