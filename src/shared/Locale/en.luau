--!strict
-- Textes en anglais : mêmes clés d'interface que `fr.luau`, plus les noms des données (objets, raretés,
-- mutations, couches, pelles, passes, produits), dont le français vient des configs.
-- Le test LocaleRules vérifie qu'aucune clé ne manque et que les marqueurs de formatage correspondent.

return table.freeze({
	-- Jeu et formats
	["game.title"] = "Creuse ou Crève",
	["game.subtitle"] = "Dig or Die",
	["format.thousands"] = ",",
	["common.coins"] = "%s Coins",

	-- HUD
	["hud.shop"] = "🛒\nShop",
	["hud.chest"] = "🧰\nChest",
	["hud.quests"] = "📜\nQuests",
	["hud.index"] = "📖\nIndex",
	["hud.reserve"] = "🎒\nStash",
	["hud.autoOff"] = "Auto\nOFF",
	["hud.autoOn"] = "Auto\nON",
	["hud.autoPaused"] = "Auto\npaused",
	["hud.protected"] = "Protected: %d min",
	["hud.shieldActive"] = "🛡 Active",
	["hud.shieldReady"] = "🛡 Ready",
	["hud.depth"] = "Depth: %d m",
	["hud.chestCount"] = "Chest: %d/%d",
	["hud.chestFull"] = "Chest full: sell your items at the Merchant",
	["hud.newStratum"] = "New layer: %s! (%d m)",
	["hud.deeper"] = "You're now %d m down",
	["hud.stratumBlocked"] = "You need the %s to dig into %s",
	["hud.shovelEquipped"] = "%s equipped!",
	["hud.merchantArrow"] = "Merchant",
	["hud.luckEvent"] = "2x luck, courtesy of %s!",
	["hud.revengeCompensated"] = "Your Revenge was no longer possible: a Luck Potion is waiting in your stash",

	-- Classement (liste des joueurs)
	["leaderstat.coins"] = "Coins",
	["leaderstat.depth"] = "Depth",

	-- Cycle jour et nuit
	["daynight.untilNight"] = "Night in %d:%02d",
	["daynight.untilDay"] = "Day in %d:%02d",
	["daynight.nightfall"] = "Night falls: guard your chest!",
	["daynight.daybreak"] = "The sun is up",

	-- Indice de premier lancement
	["dighint.pc"] = "Click a tile to dig",
	["dighint.mobile"] = "Tap a tile to dig",

	-- Coffre et Marchand
	["chest.title"] = "Chest",
	["chest.titleSell"] = "Merchant",
	["chest.sellOne"] = "Sell",
	["chest.sellAll"] = "Sell all (%s Coins)",
	["chest.empty"] = "Your chest is empty. Go dig!",
	["chest.stolenFrom"] = "Stolen from %s",

	-- Révélation
	["reveal.value"] = "Value: %s",

	-- Forge
	["forge.title"] = "Forge",
	["forge.free"] = "Free",
	["forge.stats"] = "%d hits per tile  •  Luck +%d%%  •  Reaches: %s",
	["forge.equipped"] = "Equipped",
	["forge.owned"] = "Owned",
	["forge.buy"] = "Buy (%s)",
	["forge.missing"] = "%s Coins short",
	["forge.locked"] = "Locked: %s required",
	["forge.coins"] = "Your Coins: %s",

	-- Boutique
	["shop.title"] = "Shop",
	["shop.tabPasses"] = "Passes",
	["shop.tabBonus"] = "Boosts",
	["shop.buy"] = "Buy",
	["shop.owned"] = "Owned",
	["shop.unavailable"] = "Coming soon",
	["shop.restricted"] = "Not available in your country",
	["shop.shieldAlready"] = "Your chest is already protected tonight",
	["shop.eventRunning"] = "An event is already running",
	["shop.revengeDay"] = "Available at night",
	["shop.revengeNoThief"] = "Nobody has robbed you",
	["shop.revengeBlocked"] = "Your thief can't be targeted",

	-- Probabilités de rareté
	["odds.title"] = "Chance to find each rarity",
	["odds.header"] = "No boost  •  With your boosts (x%s)",
	["odds.row"] = "%s: %s%%  •  %s%%",

	-- Rétention : Aujourd'hui, Index, Réserve
	["retention.todayTitle"] = "Today",
	["retention.dailySection"] = "Daily reward",
	["retention.day"] = "Day %d",
	["retention.claim"] = "Claim",
	["retention.comeBack"] = "Come back tomorrow!",
	["retention.questsSection"] = "Today's quests",
	["retention.questReward"] = "+%s Coins",
	["retention.questDone"] = "Done!",
	["retention.bonus"] = "Complete all 3 quests: +1 Luck Potion",
	["retention.bonusDone"] = "All 3 quests done: Luck Potion earned!",
	["retention.indexTitle"] = "Index",
	["retention.indexProgress"] = "%s: %d/%d items found (%d%%)",
	["retention.tier"] = "%d%%: %s",
	["retention.reserveTitle"] = "Stash",
	["retention.reserveHint"] = "Boosts you earn (calendar, quests, Index) land here. Use them whenever you want.",
	["retention.potionRow"] = "Luck Potion x%d",
	["retention.potionDescription"] = "%dx luck for %d minutes.",
	["retention.shieldRow"] = "Anti-Theft Shield x%d",
	["retention.shieldDescription"] = "Nobody can pick your chest for one night.",
	["retention.activate"] = "Use",
	["retention.empty"] = "Empty",
	["retention.shieldPlanned"] = "Already set",
	["retention.rewardPotion"] = "Potion",
	["retention.rewardShield"] = "Shield",
	["retention.rewardTitle"] = "Title",

	-- Quêtes (%s = objectif)
	["quest.FindRare"] = "Find %s Rare or better items",
	["quest.DigCells"] = "Dig %s tiles",
	["quest.SellCoins"] = "Sell items for %s Coins",
	["quest.Steal"] = "Pull off %s steal",
	["quest.Eject"] = "Kick out %s thief",
	["quest.FindMutation"] = "Find %s mutated item",
	["quest.NewDepth"] = "Go 10 m deeper %s time",

	-- Annonces du serveur
	["notice.indexTier"] = "%s Index: %d%% found!",
	["notice.titleEarned"] = "New title: %s",
	["notice.questDone"] = "Quest complete: %s",
	["notice.allQuests"] = "All 3 daily quests done: +1 Luck Potion",

	-- Titre affiché sous le nom à 100 % d'une couche (%s = couche)
	["title.index"] = "%s Archaeologist",

	-- Vol
	["steal.alert"] = "A thief is opening your chest!",
	["steal.arrowChest"] = "Your chest",
	["steal.victimSafe"] = "The thief left empty-handed",
	["steal.thiefEjected"] = "Thief kicked out!",
	["steal.ejectAction"] = "Kick out",
	["steal.ejected"] = "Kicked out by %s! Stunned %d s",
	["steal.thiefCancelled"] = "Lockpick cancelled: %s",
	["steal.stolenByMe"] = "You stole:",
	["steal.stolenFromMe"] = "You were robbed:",
	["steal.stolenFromMeBy"] = "by %s",
	["steal.stolenByMeFrom"] = "from %s",
	["steal.cancel.released"] = "you let go",
	["steal.cancel.ejected"] = "you were kicked out",
	["steal.cancel.tooFar"] = "you moved too far away",
	["steal.cancel.day"] = "the sun came up",
	["steal.cancel.left"] = "the player left",
	["steal.cancel.shield"] = "the chest is protected by a Shield",
	["steal.selfProtected"] = "You're protected (%d min)",
	["steal.victimProtected"] = "Protected (%d min)",
	["steal.robbed"] = "Already robbed tonight",
	["steal.thiefLimit"] = "You already stole %d times tonight",
	["steal.chestFull"] = "Your chest is full",
	["steal.banned"] = "You were kicked out of this chest",
	["steal.nothing"] = "Nothing to steal",
	["steal.shielded"] = "Protected by a Shield",

	-- Monde (panneaux et prompts posés par le serveur)
	["world.merchant"] = "💰 Merchant",
	["world.sell"] = "Sell",
	["world.forge"] = "⚒️ Forge",
	["world.buyShovel"] = "Buy a shovel",
	["world.chest"] = "Chest",
	["world.openChest"] = "Open chest",
	["world.pick"] = "Pick lock",
	["world.bodyguard"] = "Bodyguard",
	["plot.free"] = "Free plot",
	["plot.owned"] = "%s's plot",

	-- VIP
	["vip.tag"] = "VIP",

	-- Messages d'expulsion (données)
	["kick.loadFailed"] = "Couldn't load your data. Come back in a moment!",
	["kick.sessionEnded"] = "Your game was opened on another server. Please reconnect!",

	------------------------------------------------------------------------------------------------
	-- Noms des données
	------------------------------------------------------------------------------------------------

	-- Raretés
	["rarity.Common"] = "Common",
	["rarity.Uncommon"] = "Uncommon",
	["rarity.Rare"] = "Rare",
	["rarity.Epic"] = "Epic",
	["rarity.Legendary"] = "Legendary",
	["rarity.Secret"] = "Secret",

	-- Mutations
	["mutation.Golden"] = "Golden",
	["mutation.Diamond"] = "Diamond",
	["mutation.Rainbow"] = "Rainbow",
	["mutation.Cursed"] = "Cursed",

	-- Couches (".the" : forme utilisée dans les phrases ; l'anglais n'a pas besoin d'article)
	["stratum.Dirt"] = "Dirt",
	["stratum.Dirt.the"] = "Dirt",
	["stratum.Clay"] = "Clay",
	["stratum.Clay.the"] = "Clay",
	["stratum.Rock"] = "Rock",
	["stratum.Rock.the"] = "Rock",

	-- Pelles
	["shovel.Wood"] = "Wooden Shovel",
	["shovel.Iron"] = "Iron Shovel",
	["shovel.Steel"] = "Steel Shovel",

	-- Objets : la Terre
	["item.lost_sock"] = "Lost Sock",
	["item.rusty_can"] = "Rusty Can",
	["item.chewed_pencil"] = "Chewed Pencil",
	["item.lucky_button"] = "Lucky Button",
	["item.grandma_spoon"] = "Grandma's Spoon",
	["item.dino_tooth"] = "Dinosaur Tooth",
	["item.pirate_coin"] = "Pirate Coin",
	["item.gold_watch"] = "Gold Watch",
	["item.king_crown"] = "Forgotten King's Crown",
	["item.dragon_bone"] = "Dragon Bone",
	["item.mermaid_trident"] = "Mermaid's Trident",
	["item.cosmic_egg"] = "Cosmic Egg",
	["item.alien_remote"] = "Alien Remote",

	-- Objets : l'Argile
	["item.odd_marbles"] = "Mismatched Marbles",
	["item.fossil_shell"] = "Fossil Shell",
	["item.wheelless_car"] = "Little Car With No Wheels",
	["item.round_ammonite"] = "Perfectly Round Ammonite",
	["item.fossil_teddy"] = "Fossilized Teddy",
	["item.pterodactyl_egg"] = "Pterodactyl Egg",
	["item.grumpy_robot"] = "Grumpy Wind-Up Robot",
	["item.triceratops_skull"] = "Triceratops Skull",
	["item.mammoth_tusk"] = "Mammoth Tusk",
	["item.ancient_console"] = "Prehistoric Game Console",
	["item.roaring_trex_plush"] = "T-Rex Plush That Really Roars",
	["item.unicorn_fossil"] = "Unicorn Fossil",

	-- Objets : la Roche
	["item.shiny_pebble"] = "Slightly Shiny Pebble",
	["item.pirate_button"] = "Pirate Coat Button",
	["item.candy_quartz"] = "Candy Pink Quartz",
	["item.cracked_spyglass"] = "Cracked Spyglass",
	["item.sulky_amethyst"] = "Sulky Amethyst",
	["item.torn_treasure_map"] = "Torn Treasure Map",
	["item.starry_geode"] = "Geode Full of Stars",
	["item.captain_hook"] = "Captain's Hook",
	["item.storm_captain_chest"] = "Captain Storm's Chest",
	["item.singing_crystal"] = "Off-Key Singing Crystal",
	["item.crystal_parrot"] = "Talking Crystal Parrot",
	["item.earth_heart_diamond"] = "Diamond of the Earth's Heart",

	-- Game passes
	["pass.BiggerChest"] = "Bigger Chest",
	["pass.BiggerChest.desc"] = "Doubles your chest size: 60 slots instead of 30.",
	["pass.LuckX2"] = "2x Luck",
	["pass.LuckX2.desc"] = "Permanently doubles your chances of digging up Rare, Epic, Legendary and Secret items.",
	["pass.AutoDig"] = "Auto Dig",
	["pass.AutoDig.desc"] = "Your shovel digs your plot on its own. Turn it on or off anytime.",
	["pass.VIP"] = "VIP",
	["pass.VIP.desc"] = "+10% Coins on every sale and a golden VIP tag.",
	["pass.Bodyguard"] = "Bodyguard",
	["pass.Bodyguard.desc"] = "A guard watches your chest: thieves need 8 seconds to pick it instead of 5.",

	-- Developer products
	["product.LuckPotion"] = "Luck Potion",
	["product.LuckPotion.desc"] = "3x luck for 10 minutes. The time adds up if a potion is already active.",
	["product.Shield"] = "Anti-Theft Shield",
	["product.Shield.desc"] = "Nobody can pick your chest for one full night.",
	["product.CoinPouch"] = "Coin Pouch",
	["product.CoinPouch.desc"] = "5,000 Coins, added instantly.",
	["product.CoinBag"] = "Coin Bag",
	["product.CoinBag.desc"] = "15,000 Coins, added instantly.",
	["product.CoinChest"] = "Coin Chest",
	["product.CoinChest.desc"] = "35,000 Coins, added instantly. Enough for the Steel Shovel.",
	["product.CoinVault"] = "Coin Vault",
	["product.CoinVault.desc"] = "80,000 Coins, added instantly. The best Coins per Robux.",
	["product.ServerLuckEvent"] = "Server Luck Event",
	["product.ServerLuckEvent.desc"] = "2x luck for the whole server for 5 minutes, with your name shown to every player.",
	["product.Revenge"] = "Revenge",
	["product.Revenge.desc"] = "At night: teleport to your last thief's chest. Normal stealing rules apply.",
}) :: { [string]: string }
