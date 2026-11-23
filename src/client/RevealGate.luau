--!strict
-- Tant qu'une révélation Légendaire ou Secret occupe l'écran (arrêt sur image, carte, disparition), les
-- annonces serveur attendent : la carte passerait devant et couperait leur texte. RevealController
-- signale la fin prévue de la révélation ; AnnouncementController attend qu'elle soit passée.

local RevealGate = {}

local busyUntil = 0

-- La révélation en cours occupe l'écran jusqu'à endsAt (horloge os.clock).
function RevealGate.holdUntil(endsAt: number)
	busyUntil = math.max(busyUntil, endsAt)
end

function RevealGate.isBusy(): boolean
	return os.clock() < busyUntil
end

-- Rend la main dès que plus aucune révélation spectaculaire n'est à l'écran.
function RevealGate.waitUntilFree()
	while os.clock() < busyUntil do
		task.wait(busyUntil - os.clock())
	end
end

return RevealGate
