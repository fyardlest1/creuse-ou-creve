--!strict
-- Sons et musiques du jeu (plan semaine 5, section 8). Tous viennent du pack Kenney Game Assets
-- All-in-1 (CC0) et sont notés un par un dans docs/LICENCES.md. Ils appartiennent au compte qui
-- publie le jeu (au transfert vers le groupe, il faudra les renvoyer ou en donner l'accès au jeu).
-- Deux groupes, coupables séparément dans le menu Son : la musique et les effets sonores.

export type SoundDef = {
	id: string, -- "rbxassetid://<nombre>"
	volume: number,
	pitch: number?, -- vitesse de lecture (1 par défaut)
}

local function sound(assetId: number, volume: number, pitch: number?): SoundDef
	return table.freeze({ id = "rbxassetid://" .. assetId, volume = volume, pitch = pitch })
end

local AudioConfig = {
	-- Creusage : une variante au hasard à chaque coup
	DIG_HITS = table.freeze({
		sound(71845224765541, 0.5), -- CoC_dig_hit_1
		sound(85059165910638, 0.5), -- CoC_dig_hit_2
		sound(82191501804971, 0.5), -- CoC_dig_hit_3
	}),

	-- Révélations
	REVEAL = sound(102008875800532, 0.6), -- CoC_reveal (Commun à Rare)
	REVEAL_EPIC = sound(76698623998150, 0.9), -- CoC_reveal_epic
	REVEAL_IMPACT = sound(103762663679765, 1), -- CoC_reveal_impact (Légendaire et Secret)
	REVEAL_SECRET_VICTORY = sound(123677676815531, 1), -- CoC_reveal_secret_victory

	-- Économie
	SELL = sound(81882312193102, 0.7), -- CoC_sell
	SHOVEL_BUY = sound(80587804377145, 0.8), -- CoC_shovel_buy
	INVENTORY_FULL = sound(103027199143841, 0.6), -- CoC_inventory_full

	-- Annonces et cycle
	ANNOUNCE = sound(95038942153664, 0.7), -- CoC_announce
	PHASE_BELL = sound(127399780766865, 0.8), -- CoC_phase_bell
	BLOOD_NIGHT = sound(77927147262256, 1, 0.7), -- CoC_blood_night (cloche jouée plus grave)

	-- Vol
	STEAL_ALARM = sound(112850018021477, 0.5), -- CoC_steal_alarm (en boucle)
	EJECT_PUNCH = sound(139729931229893, 0.8), -- CoC_eject_punch
	EJECT_WOOSH = sound(133499672690812, 0.7), -- CoC_eject_woosh (rééchantillonné à 48 kHz)
	LOCKPICK_HIT = sound(134052168889977, 0.6), -- CoC_lockpick_hit
	LOCKPICK_MISS = sound(78021126935770, 0.6), -- CoC_lockpick_miss
	LOCKPICK_DONE = sound(79172070940555, 0.8), -- CoC_lockpick_done

	-- Événements
	METEOR_IMPACT = sound(98050743779257, 0.5), -- CoC_meteor_impact (joué au point d'impact)
	METEOR_ROLLOFF_MAX = 120, -- studs : au-delà, l'impact ne s'entend plus

	-- Musique (groupe Musique)
	MUSIC_DAY = sound(75054087770832, 0.25), -- CoC_music_day (boucle, le jour)
	MUSIC_NIGHT = sound(113958371532738, 0.25), -- CoC_night_ambience (boucle, la nuit)
	MUSIC_FADE_TIME = 3, -- secondes de fondu entre la musique de jour et celle de nuit

	-- Groupes (volume quand le groupe n'est pas coupé)
	MUSIC_GROUP_VOLUME = 1,
	EFFECTS_GROUP_VOLUME = 1,
	SETTING_COOLDOWN = 0.3, -- secondes minimum entre deux changements de réglage (anti-spam serveur)
}

return table.freeze(AudioConfig)
