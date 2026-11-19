--!strict
-- Géométrie des parcelles et règles de creusage.

local PlotConfig = {
	PLOT_COUNT = 8,
	PLOTS_PER_ROW = 4, -- 2 rangées de 4 parcelles
	GRID_SIZE = 8, -- 8 x 8 cases
	CELL_SIZE = 4, -- studs
	CELL_HEIGHT = 2, -- épaisseur d'une case, studs
	CELL_GAP = 0.15, -- petit joint entre les cases pour lire la grille
	BASE_HEIGHT = 1, -- socle sous les cases, visible quand une case est creusée
	PLOT_SPACING = 12, -- studs entre deux parcelles
	PLOT_ORIGIN = Vector3.new(0, 0, 0), -- centre de l'ensemble des parcelles, au niveau du sol
	GROUND_MARGIN = 40, -- studs de sol autour des parcelles
	GROUND_THICKNESS = 4,
	HITS_PER_CELL = 3, -- coups nécessaires avec une pelle de puissance 1

	MAX_DIG_DISTANCE = 30, -- studs entre le joueur et la case
	DIG_COOLDOWN = 0.2, -- secondes minimum entre deux coups
	DEPTH_PER_LAYER = 10, -- mètres gagnés par couche terminée
	SPAWN_OFFSET = 4, -- studs entre le bord de la parcelle et le point d'apparition
	SPAWN_HEIGHT = 3, -- hauteur du HumanoidRootPart au-dessus du sol

	CELL_COLOR = Color3.fromRGB(124, 84, 52),
	CELL_COLOR_VARIATION = 0.08, -- variation de luminosité aléatoire par case
	CELL_MATERIAL = Enum.Material.Ground,
	BASE_COLOR = Color3.fromRGB(60, 42, 30),
	BASE_MATERIAL = Enum.Material.Slate,
	GROUND_COLOR = Color3.fromRGB(96, 140, 70),
	GROUND_MATERIAL = Enum.Material.Grass,

	SIGN_HEIGHT = 7, -- studs au-dessus du socle
	SIGN_MAX_DISTANCE = 150,
}

return table.freeze(PlotConfig)
