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
	debuffBlacklist = { -- debuff found in this list are not shown
		57724,	-- Berserk
		57723,	-- Time Warp
		80354,	-- Ancient Hysteria
		36032,	-- Arcane Blast
		95223,	-- Recently Mass Resurrected
		26013,	-- Deserter
		71041,	-- Dungeon Deserter
		99413,	-- Deserter
		97821,	-- Void-Touched
	},
	["DRUID"] = {
		-- 774 Rejuvenation
		-- 2782 Remove Corruption
		-- 5185 Healing Touch
		-- 8936 Regrowth
		-- 18562 Swiftmend, castable only of affected by Rejuvenation or Regrowth
		-- 20484 Rebirth
		-- 29166 Innervate
		-- 33763 Lifebloom
		-- 48438 Wild Growth
		-- 50464 Nourish
		[3] = { -- Restoration
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
		[3] = { -- Restoration
			-- TEST MODE
			spells = {
				{ spellID = 974, debuffs = { 57724 } }, -- Earth Shield
				{ spellID = 61295, buffs = { 974 } }, -- Riptide
				{ spellID = 331, buffs = { 61295 } }, -- Healing Wave
				{ spellID = 77472 }, -- Greater Healing Wave
				{ spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
				{ spellID = 475, dispels = { ["Curse"] = true } }, -- Remove Curse (Mage)
				{ spellID = 2008, rez = true }, -- Ancestral Spirit
				{ macroName = "toto" }, --
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
		-- [1] = { -- Elemental
			-- -- TEST MODE
			-- spells = {
				-- { spellID = 475, dispels = { ["Curse"] = true } }, -- Remove Curse (Mage)
				-- { spellID = 1064 }, -- Salve de Guérison
			-- }
		-- }
	},
	["PALADIN"] = {
		-- 633 Lay on Hands
		-- 635 Holy Light
		-- 1022 Hand of Protection
		-- 1044 Hand of Freedom
		-- 1038 Hand of Salvation
		-- 4987 Cleanse
		-- 6940 Hand of Sacrifice
		-- 19750 Flash of Light
		-- 20473 Holy Shock
		-- 31789 Righteous Defense
		-- 53563 Beacon of Light
		-- 82326 Divine Light
		-- 85673 Word of Glory
		[1] = { -- Holy
			spells = {
				{ spellID = 20473 }, -- Holy Shock
				{ spellID = 85673 }, -- Word of Glory
				{ spellID = 19750 }, -- Flash of Light
				{ spellID = 635 }, -- Holy Light
				{ spellID = 82326 }, -- Divine Light
				{ spellID = 633 }, -- Lay on Hands
				{ spellID = 1022 }, -- Hand of Protection
				{ spellID = 1044 }, -- Hand of Freedom
				{ spellID = 6940 }, -- Hand of Sacrifice
				{ spellID = 4987, cures = { ["Poison"] = true, ["Disease"] = true, ["Magic"] = function() return select(5, GetTalentInfo(1,14)) > 0 end } }, -- Cleanse
				{ spellID = 53563 }, -- Beacon of Light
			}
		},
		[2] = { -- Protection
			spells = {
				{ spellID = 31789 }, -- Righteous Defense
				{ spellID = 6940 }, -- Hand of Sacrifice
				{ spellID = 633 }, -- Lay on Hands
				{ spellID = 4987, cures = { ["Poison"] = true, ["Disease"] = true } }, -- Cleanse
			}
		},
	},
	["PRIEST"] = {
		-- 17 Power Word: Shield not castable if affected by Weakened Soul (6788)
		-- 139 Renew
		-- 527 Dispel Magic (Discipline, Holy)
		-- 528 Cure Disease
		-- 596 Prayer of Healing
		-- 1706 Levitate
		-- 2061 Flash Heal
		-- 2050 Heal
		-- 2060 Greater Heal
		-- 6346 Fear Ward
		-- 32546 Binding Heal
		-- 33076 Prayer of Mending
		-- 47540 Penance (Discipline)
		-- 47788 Guardian Spirit (Holy)
		-- 73325 Leap of Faith
		-- 88684 Holy Word: Serenity (Holy)
		[1] = { -- Discipline
			spells = {
				{ spellID = 17, debuffs = { 6788 } }, -- Power Word: Shield not castable if affected by Weakened Soul
				{ spellID = 139 }, -- Renew
				{ spellID = 2061 }, -- Flash Heal
				{ spellID = 2050 }, -- Heal
				{ spellID = 2060 }, -- Greater Heal
				{ spellID = 47540 }, -- Penance
				{ spellID = 33076 }, -- Prayer of Mending
				{ spellID = 596 }, -- Prayer of Healing
				{ spellID = 527, cures = { ["Magic"] = true } }, -- Dispel Magic
				{ spellID = 528, cures = { ["Disease"] = true } }, -- Cure Disease
			},
		},
		[2] = {
			spells = {
				{ spellID = 139 }, -- Renew
				{ spellID = 2061 }, -- Flash Heal
				{ spellID = 2050 }, -- Heal
				{ spellID = 2060 }, -- Greater Heal
				{ spellID = 88684 }, -- Holy Word: Serenity
				{ spellID = 33076 }, -- Prayer of Mending
				{ spellID = 596 }, -- Prayer of Healing
				{ spellID = 47788 }, -- Guardian Spirit
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