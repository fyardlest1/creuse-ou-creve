--!strict
-- Traduit, dans la langue du joueur, les textes que le serveur pose sur des instances visibles par tous
-- (panneaux des parcelles, Marchand, Forge, prompts des coffres, nom du garde, titre, classement).
-- Le serveur les écrit en français avec Locale.bind ; on les réécrit ici localement, sans rien renvoyer.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared.Locale)

local LocaleController = {}

local watched: { [Instance]: RBXScriptConnection } = {}

local function watch(instance: Instance)
	if watched[instance] ~= nil then
		return
	end
	Locale.applyBindings(instance)
	-- Le serveur rappelle bind quand le texte change (ex. nouveau propriétaire de parcelle).
	watched[instance] = instance.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, #Locale.BIND_PREFIX) == Locale.BIND_PREFIX then
			Locale.applyBindings(instance)
		end
	end)
end

local function unwatch(instance: Instance)
	local connection = watched[instance]
	if connection ~= nil then
		connection:Disconnect()
		watched[instance] = nil
	end
end

function LocaleController.init()
	Locale.getLanguage()
end

function LocaleController.start()
	-- La langue source n'a rien à réécrire : le serveur a déjà posé le français.
	if Locale.getLanguage() == Locale.SOURCE then
		return
	end
	CollectionService:GetInstanceAddedSignal(Locale.BIND_TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(Locale.BIND_TAG):Connect(unwatch)
	for _, instance in CollectionService:GetTagged(Locale.BIND_TAG) do
		watch(instance)
	end
end

return LocaleController
