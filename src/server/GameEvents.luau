--!strict
-- Signaux serveur du jeu : les services émettent ce qui se passe (coup de pelle, objet trouvé, vente...),
-- les services de suivi (rétention, quêtes, badges, entonnoir) écoutent. Évite les dépendances circulaires
-- entre services. Chaque écouteur est appelé dans son propre thread (task.spawn).

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Types)

type Callback<T...> = (T...) -> ()

local function newSignal<T...>()
	local callbacks: { Callback<T...> } = {}
	return {
		connect = function(callback: Callback<T...>)
			table.insert(callbacks, callback)
		end,
		fire = function(...: T...)
			for _, callback in callbacks do
				task.spawn(callback, ...)
			end
		end,
	}
end

local GameEvents = {
	digHit = newSignal() :: any, -- (player)
	itemFound = newSignal() :: any, -- (player, item: ItemInstance)
	depthReached = newSignal() :: any, -- (player, depth: number, stratumId: string)
	sold = newSignal() :: any, -- (player, coinsEarned: number, count: number)
	shovelBought = newSignal() :: any, -- (player, shovelId: string)
	stealSucceeded = newSignal() :: any, -- (thief, victim)
	ejected = newSignal() :: any, -- (owner, thief)
}

local _ = Types -- ItemInstance documenté ci-dessus

return GameEvents
