--!strict
-- Géométrie des parcelles et règles de creusage.

local PlotConfig = {
	PLOT_COUNT = 8,
	GRID_SIZE = 8, -- 8 x 8 cases
	CELL_SIZE = 4, -- studs
	CELL_HEIGHT = 2, -- épaisseur d'une case, studs
	PLOT_SPACING = 12, -- studs entre deux parcelles
	PLOT_ORIGIN = Vector3.new(0, 0, 0), -- centre de la première parcelle
	HITS_PER_CELL = 3, -- coups nécessaires avec une pelle de puissance 1

	MAX_DIG_DISTANCE = 30, -- studs entre le joueur et la case
	DIG_COOLDOWN = 0.2, -- secondes minimum entre deux coups
	DEPTH_PER_LAYER = 10, -- mètres gagnés par couche terminée
	SPAWN_OFFSET = 4, -- studs entre le bord de la parcelle et le point d'apparition

	CELL_COLOR = Color3.fromRGB(124, 84, 52),
	CELL_MATERIAL = Enum.Material.Ground,
	BASE_COLOR = Color3.fromRGB(70, 50, 35),
}

return table.freeze(PlotConfig)
