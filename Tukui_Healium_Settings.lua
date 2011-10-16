HealiumSettings = {
	enabled = true,
	unitframeWidth = 120, -- 150
	unitframeHeight = 28, -- 32
	showPets = true, -- display pets
	showBuff = true, -- display buff castable by configured spells
	showDebuff = true, -- display debuff
	showOnlyDispellableDebuff = false, -- display only dispellable debuff (showDebuff must be true)
	highlightDispel = true, -- highlight dispel button when debuff is dispellable no matter they are shown or not
	playSoundOnDispel = true, -- play a sound when a debuff is dispellable no matter they are shown or not
	flashDispel = true, -- flash dispel button when debuff is dispellable TODO
	showPercentage = true, -- show health percentage
	showButtonTooltip = true, -- display heal buttons tooltip
	showBuffDebuffTooltip = true, -- display buff and debuff tooltip
	showOOM = true, -- turn heal button in blue when OOM
	checkRangeBySpell = false, -- very time consuming and not really useful (Tukui already has per unitframe out-of-range)
	-- debuff found in this list are not shown
	debuffBlacklist = { 
		--57724,	-- Berserk
		57723,	-- Time Warp
		80354,	-- Ancient Hysteria
		--36032,	-- Arcane Blast
		95223,	-- Recently Mass Resurrected
		26013,	-- Deserter
		71041,	-- Dungeon Deserter
		99413,	-- Deserter
		97821,	-- Void-Touched
	},
	["DRUID"] = {
		[3] = {
			spells = {
				{ spellID = 774 }, -- Rejuvenation
				{ spellID = 33763 }, -- Lifebloom
				{ spellID = 50464 }, -- Nourish
				{ spellID = 8936 }, -- Regrowth
				{ spellID = 18562, buffs = { 774, 8936 } }, -- Swiftmend, castable only of affected by Rejuvenation or Regrowth
				{ macroName = "NSHT" }, -- Macro Nature Swiftness + Healing Touch
				{ spellID = 48438 }, -- Wild Growth
				{ spellID = 2782, dispels = { ["Poison"] = true, ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,17)) > 0 end } }, -- Remove Corruption
				{ spellID = 20484, rez = true }, -- Rebirth
			},
		}
	},
	["SHAMAN"] = {
		[3] = {
			-- TEST MODE
			spells = {
				{ spellID = 974, debuffs = { 57724 } }, -- Earth Shield
				{ spellID = 61295, buffs = { 974 } }, -- Riptide
				{ spellID = 331, buffs = { 61295 } }, -- Healing Wave
				{ spellID = 77472 }, -- Greater Healing Wave
				{ spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
				{ spellID = 475, dispels = { ["Curse"] = true } }, -- Remove Curse (Mage)
				{ spellID = 2008, rez = true }, -- Ancestral Spirit
			},
			-- spells = {
				-- { spellID = 974 }, -- Earth Shield
				-- { spellID = 61295 }, -- Riptide
				-- { spellID = 8004 }, -- Afflux de soins
				-- { spellID = 331 }, -- Healing Wave
				-- { macroName = "NSHW" },  -- Macro Nature Swiftness + Greater Healing Wave
				-- { spellID = 1064 }, -- Salve de Guérison
				-- { spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
			-- },
		},
		[1] = {
			-- TEST MODE
			spells = {
				{ spellID = 475, dispels = { ["Curse"] = true } }, -- Remove Curse (Mage)
				{ spellID = 1064 }, -- Salve de Guérison
			}
		}
	},
	["PALADIN"] = {
		[1] = {
			spells = {
				{ spellID = 20473 }, -- Horion Sacré
				{ spellID = 85673 }, -- Mot de Gloire
				{ spellID = 19750 }, -- Eclair Lumineux
				{ spellID = 635 }, -- Lumière Sacrée
				{ spellID = 82326 }, -- Lumière Divine
				{ spellID = 633 }, -- Imposition des Mains
				{ spellID = 1022 }, -- Main de Protection
				{ spellID = 1044 }, -- Main de Liberté
				{ spellID = 6940 }, -- Main de Sacrifice
				{ spellID = 4987, cures = { ["Poison"] = true, ["Disease"] = true, ["Magic"] = function() return select(5, GetTalentInfo(1,14)) > 0 end } }, -- Epuration
				{ spellID = 53563 }, -- Guide de Lumière
			}
		}
	},
	["PRIEST"] = {
		[1] = {
			-- TEST MODE
			spells = {
				{ spellID = 17, debuffs = { 6788 } }, -- Power Word: Shield not castable if affected by Weakened Soul
				{ spellID = 527, cures = { ["Magic"] = true } }, -- Dispel Magic
				{ spellID = 528, cures = { ["Disease"] = true } }, -- Cure Disease
			},
		},
		[3] = {
			-- TEST MODE
			spells = {
				{ spellID = 17, debuffs = { 6788 } }, -- Power Word: Shield not castable if affected by Weakened Soul
				{ spellID = 527, cures = { ["Magic"] = true } }, -- Dispel Magic
				{ spellID = 528, cures = { ["Disease"] = true } }, -- Cure Disease
			},
		}
	},
	["MAGE"] = {
		[1] = {
			-- TEST MODE
			spells = {
				{ spellID = 475, debuffs = { 36032 } }, -- Remove Curse (Mage)
				{ spellID = 475, dispels = { ["Curse"] = true } }, -- Remove Curse (Mage)
				{ spellID = 51886, dispells = { ["Curse"] = true } }, -- Cleanse Spirit (Shaman)
				{ spellID = 475, buffs = { 6117 } }, -- Remove Curse (Mage)
			},
		}
	},
	["HUNTER"] = {
		[1] = {
			-- TEST MODE
			spells = {
				{ spellID = 34477 }
			}
		}
	}
}