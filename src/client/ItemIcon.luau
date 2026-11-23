--!strict
-- Icône d'un objet (champ icon de Items.luau), partagée par la carte de révélation et les cartes du coffre
-- (le Marchand ouvre le coffre en mode vente). Repli tant qu'une icône manque, ou si l'image ne se
-- charge pas : un carré arrondi teinté de la couleur de la rareté, avec l'initiale du nom de l'objet
-- dans la langue du joueur.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local UiConfig = require(Shared.Config.UiConfig)
local Locale = require(Shared.Locale)

local WHITE = Color3.new(1, 1, 1)

local ItemIcon = {}

-- Initiale du nom affiché (premier caractère UTF-8 : « Œuf » donne « Œ »).
local function initialOf(itemId: string): string
	local name = Locale.item(itemId)
	local ok, codepoint = pcall(utf8.codepoint, name, 1)
	return if ok and codepoint ~= nil then utf8.char(codepoint) else "?"
end

-- Crée l'icône dans parent. Le cadre retourné reste carré, de côté égal à la hauteur que lui donne
-- l'appelant, qui règle sa position et sa taille.
function ItemIcon.create(itemId: string, accentColor: Color3, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Icon"
	frame.BackgroundColor3 = accentColor
	frame.BackgroundTransparency = UiConfig.ITEM_ICON_BACKGROUND_TRANSPARENCY
	frame.BorderSizePixel = 0
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height -- la hauteur donnée par l'appelant fixe le côté
	aspect.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(UiConfig.ITEM_ICON_CORNER, 0)
	corner.Parent = frame

	local letter = Instance.new("TextLabel")
	letter.Name = "Fallback"
	letter.AnchorPoint = Vector2.new(0.5, 0.5)
	letter.Position = UDim2.fromScale(0.5, 0.5)
	letter.Size = UDim2.fromScale(UiConfig.ITEM_ICON_LETTER_SCALE, UiConfig.ITEM_ICON_LETTER_SCALE)
	letter.BackgroundTransparency = 1
	letter.Font = Enum.Font.FredokaOne
	letter.TextScaled = true
	letter.TextColor3 = WHITE
	letter.TextStrokeTransparency = 0.4
	letter.Text = initialOf(itemId)
	letter.Parent = frame

	local definition = Items.byId[itemId]
	local icon = if definition ~= nil then definition.icon else nil
	if icon ~= nil then
		local image = Instance.new("ImageLabel")
		image.Name = "Image"
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = icon
		image.Parent = frame
		letter.Visible = false
		-- Image introuvable ou refusée : on revient à l'initiale plutôt que d'afficher un carré vide.
		task.spawn(function()
			ContentProvider:PreloadAsync({ image }, function(_: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Failure and image.Parent ~= nil then
					image.Visible = false
					letter.Visible = true
				end
			end)
		end)
	end
	frame.Parent = parent
	return frame
end

return ItemIcon
