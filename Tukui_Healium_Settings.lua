HealiumSettings = {
	enabled = true,
	unitframeWidth = 120, -- 150
	unitframeHeight = 28, -- 32
	showPercentage = true,
	showButtonTooltip = true,
	showBuffDebuffTooltip = true,
	checkRangeBySpell = false, -- very time consuming and not really useful
	showNoMana = true, -- turn heal button in blue when OOM
	highlightDispel = true, -- highlight dispel button when debuff is dispellable
	playSoundOnDispel = true, -- play a sound when a debuff is dispellable
	showOnlyDispellableDebuff = false, -- display only dispellable debuff
	showPets = true,
	flashDispel = false, -- flash dispel button when debuff is dispellable TODO
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
			-- spellSize = 32,
			-- spellSpacing = 2,
			-- buffSize = 32,
			-- buffSpacing = 2,
			-- debuffSize = 32,
			-- debuffSpacing = 2,
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
			-- spellSize = 32,
			-- spellSpacing = 2,
			-- buffSize = 32,
			-- buffSpacing = 2,
			-- debuffSize = 32,
			-- debuffSpacing = 2,
		}
	},
	["PRIEST"] = {
		[1] = {
			spells = {
				{ spellID = 17, debuffs = { 6788 } }, -- Power Word: Shield not castable if affected by Weakened Soul
			},
		},
		[3] = {
			spells = {
				{ spellID = 17, debuffs = { 6788 } }, -- Power Word: Shield not castable if affected by Weakened Soul
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
			-- spellSize = 32,
			-- spellSpacing = 2,
			-- buffSize = 32,
			-- buffSpacing = 2,
			-- debuffSize = 32,
			-- debuffSpacing = 2,
		}
	},
	["HUNTER"] = {
		[1] = {
			spells = {
				{ spellID = 34477 }
			}
		}
	}
}