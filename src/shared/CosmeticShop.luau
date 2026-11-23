--!strict
-- Règles pures de la boutique de cosmétiques de voleur, partagées : le serveur décide avec elles, le
-- client s'en sert seulement pour l'état des boutons. Aucun accès au réseau ni aux données vivantes.

local Cosmetics = require(script.Parent.Config.Cosmetics)

export type State = { owned: { string }, mask: string?, bag: string? }

-- Raisons de refus (codes, traduits par le client via "cosmetic.error.<code>").
export type Reason = "unknown" | "owned" | "points" | "slot" | "notOwned"

local CosmeticShop = {}

function CosmeticShop.owns(state: State, id: string): boolean
	return table.find(state.owned, id) ~= nil
end

local function lookup(id: unknown): Cosmetics.CosmeticDef?
	if typeof(id) ~= "string" or #id == 0 or #id > Cosmetics.ID_MAX_LENGTH then
		return nil
	end
	return Cosmetics.byId[id]
end

-- Achat : retourne le cosmétique si l'achat est permis, sinon nil et la raison.
function CosmeticShop.checkBuy(state: State, points: number, id: unknown): (Cosmetics.CosmeticDef?, Reason?)
	local def = lookup(id)
	if def == nil then
		return nil, "unknown"
	end
	if CosmeticShop.owns(state, def.id) then
		return nil, "owned"
	end
	if points < def.price then
		return nil, "points"
	end
	return def, nil
end

-- Porter ou retirer : id = "" retire le cosmétique de l'emplacement. Retourne l'id à enregistrer
-- (nil pour « rien »), ou false et la raison.
function CosmeticShop.checkEquip(state: State, slot: unknown, id: unknown): (boolean, string?, Reason?)
	if slot ~= "mask" and slot ~= "bag" then
		return false, nil, "slot"
	end
	if id == "" then
		return true, nil, nil
	end
	local def = lookup(id)
	if def == nil then
		return false, nil, "unknown"
	end
	if def.slot ~= slot then
		return false, nil, "slot"
	end
	if not CosmeticShop.owns(state, def.id) then
		return false, nil, "notOwned"
	end
	return true, def.id, nil
end

-- Applique un achat validé : retire les points, ajoute le cosmétique et le porte tout de suite.
-- Retourne le nouveau solde.
function CosmeticShop.applyBuy(state: State, points: number, def: Cosmetics.CosmeticDef): number
	table.insert(state.owned, def.id)
	if def.slot == "mask" then
		state.mask = def.id
	else
		state.bag = def.id
	end
	return points - def.price
end

return CosmeticShop
