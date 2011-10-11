HealiumSettings = {
	enabled = true,
	debuffBlacklist = { 
		--57724,	-- Berserk
		57723,	-- Time Warp
		80354,	-- Ancient Hysteria
		--36032,	-- Arcane Blast
		95223,	-- Recently Mass Resurrected
		26013,	-- Deserter
		71041,	-- Dungeon Deserter
		99413,	-- Deserter
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
				{ spellID = 2782, cures = { ["Poison"] = true, ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,17)) > 0 end } }, -- Remove Corruption
				{ spellID = 20484 }, -- Rebirth
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
			spells = {
				{ spellID = 974, debuffs = { 57724 } }, -- Earth Shield
				{ spellID = 61295, buffs = { 974 } }, -- Riptide
				{ spellID = 331, buffs = { 61295 } }, -- Healing wave
				{ spellID = 51886, cures = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
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
		}
	},
	["MAGE"] = {
		[1] = {
			spells = {
				{ spellID = 475, cures = { ["Curse"] = true }, debuffs = { 36032 } }, -- Remove Curse (Mage)
				{ spellID = 475, cures = { ["Curse"] = true } }, -- Remove Curse (Mage)
				{ spellID = 475, cures = { ["Curse"] = true }, buffs = { 6117 } }, -- Remove Curse (Mage)
			},
			-- spellSize = 32,
			-- spellSpacing = 2,
			-- buffSize = 32,
			-- buffSpacing = 2,
			-- debuffSize = 32,
			-- debuffSpacing = 2,
		}
	},
}