HealiumSettings = {
	Options = {
		enabled = true, -- if set to false, classic tukui raid healing frames will be created
		unitframeWidth = 120, -- 150
		unitframeHeight = 28, -- 32
		showPets = false, -- add a frame for pets
		showTanks = false, -- add a frame for tanks
		showNamelist = false, -- add a frame with a list of player name
		showBuff = true, -- display buff castable by configured spells
		showDebuff = true, -- display debuff
		-- DISPELLABLE: show only dispellable debuff
		-- BLACKLIST: exclude non-dispellable debuff from list
		-- WHITELIST: include non-dispellable debuff from list
		-- NONE: show every non-dispellable debuff
		debuffFilter = "BLACKLIST",
		highlightDispel = true, -- highlight dispel button when debuff is dispellable (no matter they are shown or not)
		playSoundOnDispel = true, -- play a sound when a debuff is dispellable (no matter they are shown or not)
		-- FLASH: flash button
		-- FADEOUT: fadeout/fadein button
		-- NONE: no flash
		flashStyle = "NONE", -- flash/fadeout dispel button when debuff is dispellable (no matter they are shown or not)
		showPercentage = true, -- show health percentage instead of health value
		showButtonTooltip = true, -- display heal buttons tooltip
		showBuffDebuffTooltip = true, -- display buff and debuff tooltip
		showOOM = true, -- color heal button in blue when OOM
		showOOR = false, -- very time consuming and not really useful (Tukui already has per unitframe out-of-range)
		namelist = "Yoog,Sweetlight,Mirabillis",
		debuffBlacklist = { -- see debuffFilter
			--6788,	-- Weakened Soul
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
		debuffWhitelist = { -- see debuffFilter
		-- PVE
		------
		--MISC
			67479,	-- Impale
		--CATA DEBUFFS
			--Baradin Hold
			95173,	-- Consuming Darkness
			88942,	-- Meteor Slash (Argaloth)

		--Blackwing Descent
			--Magmaw
			91911,	-- Constricting Chains
			94679,	-- Parasitic Infection
			94617,	-- Mangle
			91923,	-- Infectious Vomit
			--Omnitron Defense System
			79835,	-- Poison Soaked Shell
			91433,	-- Lightning Conductor
			91521,	-- Incineration Security Measure
			92048,	-- Shadow Infusion
			--Maloriak
			77699,	-- Flash Freeze
			77786,	-- Consuming Flames
			77760,	-- Biting Chill
			--Atramedes
			92423,	-- Searing Flame
			92485,	-- Roaring Flame
			92407,	-- Sonic Breath
			--Chimaeron
			82881,	-- Break
			82705,	-- Finkle's Mixture
			89084,	-- Low Health
			--Nefarian
			92053,	-- Shadow Conductor
			--Sinestra
			92956,	--Wrack
		--The Bastion of Twilight
			--Valiona & Theralion
			92878,	-- Blackout
			86840,	-- Devouring Flames
			95639,	-- Engulfing Magic
			92861,	-- Twilight Meteorite

			--Halfus Wyrmbreaker
			39171,	-- Malevolent Strikes

			--Twilight Ascendant Council
			92511,	-- Hydro Lance
			82762,	-- Waterlogged
			92505,	-- Frozen
			92518,	-- Flame Torrent
			83099,	-- Lightning Rod
			92075,	-- Gravity Core
			92488,	-- Gravity Crush
			82662,	-- Burning Blood
			82667,	-- Heart of Ice
			83500,	-- Swirling Winds
			83587,	-- Magnetic Pull

			--Cho'gall
			86028,	-- Cho's Blast
			86029,	-- Gall's Blast
			81836,	-- Corruption: Accelerated
			82125,	-- Corruption: Malformation
			82170,	-- Corruption: Absolute
			93200,	-- Corruption: Sickness

		--Throne of the Four Winds
			--Conclave of Wind
				93123,	-- Wind Chill
				--Nezir <Lord of the North Wind>
				93131,	--Ice Patch
				--Anshal <Lord of the West Wind>
				86206,	--Soothing Breeze
				93122,	--Toxic Spores
				--Rohash <Lord of the East Wind>
				93058,	--Slicing Gale
			--Al'Akir
			87873,	-- Static Shock
			93260,	-- Ice Storm
			93295,	-- Lightning Rod
			93279,	-- Acid Rain

		-- Firelands, thanks Kaelhan :)
			-- Beth'tilac
				99506,	-- Widows Kiss
				97202,	-- Fiery Web Spin
				49026,	-- Fixate
				97079,	-- Seeping Venom
			-- Lord Rhyolith
				98492,	-- Eruption
			-- Alysrazor
				101296,	-- Fieroblast
				100723,	-- Gushing Wound
				99389,	-- Imprinted
				101729,	-- Blazing Claw
				99461,	-- Blazing Power
				100029,	--  Alysra's Razor
			-- Shannox
				99840,	-- Magma Rupture
				99837,	-- Crystal Prison
				99936,	-- Jagged Tear
			-- Baleroc
				99256,	-- Torment
				99252,	-- Blaze of Glory
				99516,	-- Countdown
				99257,	-- Tormented
			-- Majordomo Staghelm
				98450,	-- Searing Seeds
				98451,	-- Burning Orbs
			-- Ragnaros
				99399,	-- Burning Wound
				100293,	-- Lava Wave
				98313,	-- Magma Blast
				100675,	-- Dreadflame
				100460,	-- Blazing Heat
		-- PVP
		------
		-- Death Knight
			47481,	-- Gnaw (Ghoul)
			47476,	-- Strangulate
			45524,	-- Chains of Ice
			55741,	-- Desecration (no duration, lasts as long as you stand in it)
			58617,	-- Glyph of Heart Strike
			49203,	-- Hungering Cold
		-- Druid
			33786,	-- Cyclone
			2637,	-- Hibernate
			5211,	-- Bash
			22570,	-- Maim
			9005,	-- Pounce
			339,	-- Entangling Roots
			45334,	-- Feral Charge Effect
			58179,	-- Infected Wounds
		-- Hunter
			3355,	-- Freezing Trap Effect
			1513,	-- Scare Beast
			19503,	-- Scatter Shot
			50541,	-- Snatch (Bird of Prey)
			34490,	-- Silencing Shot
			24394,	-- Intimidation
			50519,	-- Sonic Blast (Bat)
			50518,	-- Ravage (Ravager)
			35101,	-- Concussive Barrage
			5116,	-- Concussive Shot
			13810,	-- Frost Trap Aura
			61394,	-- Glyph of Freezing Trap
			2974,	-- Wing Clip
			19306,	-- Counterattack
			19185,	-- Entrapment
			50245,	-- Pin (Crab)
			54706,	-- Venom Web Spray (Silithid)
			4167,	-- Web (Spider)
			92380,	-- Froststorm Breath (Chimera)
			50271,	-- Tendon Rip (Hyena)
		-- Mage
			31661,	-- Dragon's Breath
			118,	-- Polymorph
			18469,	-- Silenced - Improved Counterspell
			44572,	-- Deep Freeze
			33395,	-- Freeze (Water Elemental)
			122,	-- Frost Nova
			55080,	-- Shattered Barrier
			6136,	-- Chilled
			120,	-- Cone of Cold
			31589,	-- Slow
		-- Paladin
			20066,	-- Repentance
			10326,	-- Turn Evil
			63529,	-- Shield of the Templar
			853,	-- Hammer of Justice
			2812,	-- Holy Wrath
			20170,	-- Stun (Seal of Justice proc)
			31935,	-- Avenger's Shield
		-- Priest
			64058,	-- Psychic Horror
			605,	-- Mind Control
			64044,	-- Psychic Horror
			8122,	-- Psychic Scream
			15487,	-- Silence
			15407,	-- Mind Flay
		-- Rogue
			51722,	-- Dismantle
			2094,	-- Blind
			1776,	-- Gouge
			6770,	-- Sap
			1330,	-- Garrote - Silence
			18425,	-- Silenced - Improved Kick
			1833,	-- Cheap Shot
			408,	-- Kidney Shot
			31125,	-- Blade Twisting
			3409,	-- Crippling Poison
			26679,	-- Deadly Throw
		-- Shaman
			51514,	-- Hex
			64695,	-- Earthgrab
			63685,	-- Freeze
			39796,	-- Stoneclaw Stun
			3600,	-- Earthbind
			8056,	-- Frost Shock
		-- Warlock
			710,	-- Banish
			6789,	-- Death Coil
			5782,	-- Fear
			5484,	-- Howl of Terror
			6358,	-- Seduction (Succubus)
			24259,	-- Spell Lock (Felhunter)
			30283,	-- Shadowfury
			30153,	-- Intercept (Felguard)
			18118,	-- Aftermath
			18223,	-- Curse of Exhaustion
		-- Warrior
			20511,	-- Intimidating Shout
			676,	-- Disarm
			18498,	-- Silenced (Gag Order)
			7922,	-- Charge Stun
			12809,	-- Concussion Blow
			20253,	-- Intercept
			46968,	-- Shockwave
			58373,	-- Glyph of Hamstring
			23694,	-- Improved Hamstring
			1715,	-- Hamstring
			12323,	-- Piercing Howl
		-- Racials
			20549,	-- War Stomp
		}
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
			-- spells = {
				-- { spellID = 61295, buffs = { 974 } }, -- Riptide
				-- { spellID = 331, buffs = { 61295 } }, -- Healing Wave
				-- { spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
			-- },
			-- spells = {
				-- { spellID = 974, debuffs = { 57724 } }, -- Earth Shield
				-- { spellID = 61295, buffs = { 974 } }, -- Riptide
				-- { spellID = 331, buffs = { 61295 } }, -- Healing Wave
				-- { macroName = "NSHW" },  -- Macro Nature Swiftness + Greater Healing Wave
				-- { spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
				-- { spellID = 475, dispels = { ["Curse"] = true } }, -- Remove Curse (Mage)
				-- { spellID = 2008, rez = true }, -- Ancestral Spirit
				-- { macroName = "toto" }, --
			-- },
			spells = {
				{ spellID = 974 }, -- Earth Shield
				{ spellID = 61295 }, -- Riptide
				{ spellID = 8004 }, -- Afflux de soins
				{ spellID = 331 }, -- Healing Wave
				{ macroName = "NSHW" },  -- Macro Nature Swiftness + Greater Healing Wave
				{ spellID = 1064 }, -- Salve de Guérison
				{ spellID = 51886, dispels = { ["Curse"] = true, ["Magic"] = function() return select(5, GetTalentInfo(3,12)) > 0 end } }, -- Cleanse Spirit
			},
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
				{ spellID = 4987, dispels = { ["Poison"] = true, ["Disease"] = true, ["Magic"] = function() return select(5, GetTalentInfo(1,14)) > 0 end } }, -- Cleanse
				{ spellID = 53563 }, -- Beacon of Light
			}
		},
		[2] = { -- Protection
			spells = {
				{ spellID = 31789 }, -- Righteous Defense
				{ spellID = 6940 }, -- Hand of Sacrifice
				{ spellID = 633 }, -- Lay on Hands
				{ spellID = 4987, dispels = { ["Poison"] = true, ["Disease"] = true } }, -- Cleanse
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
				{ spellID = 527, dispels = { ["Magic"] = true } }, -- Dispel Magic
				{ spellID = 528, dispels = { ["Disease"] = true } }, -- Cure Disease
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
				{ spellID = 527, dispels = { ["Magic"] = true } }, -- Dispel Magic
				{ spellID = 528, dispels = { ["Disease"] = true } }, -- Cure Disease
			},
		}
	},
	["MAGE"] = {
		[1] = {
			spells = {
				{ spellID = 475, debuffs = { 36032 } }, -- Remove Curse (Mage)
			-- -- TEST MODE
				-- { spellID = 475, dispels = { ["Curse"] = true } }, -- Remove Curse (Mage)
				-- { spellID = 51886, dispells = { ["Curse"] = true } }, -- Cleanse Spirit (Shaman)
				-- { spellID = 475, buffs = { 6117 } }, -- Remove Curse (Mage)
				-- { spellID = 475, dispels = { ["Poison"] = true, ["Disease"] = true, ["Magic"] = function() return select(5, GetTalentInfo(1,14)) > 0 end } }, -- TEST
			},
		}
	},
}