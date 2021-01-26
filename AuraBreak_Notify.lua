-- Constants
local ANNOUNCEMENTS = {OFF=1,RAID=2,PARTY=3,ALWAYS=4}
local GREEN = "ff00ff00"
local RED   = "ffff0000"

local locale = GetLocale()
local _L = {}

local f = CreateFrame("Frame")
f.mobs = {}

-- Localization
if string.sub(locale, 1, 2) == "fr" then
	_L.warning_format = "Tu as cassé '%s' sur '%s' avec '%s' ! Le sort a duré %.2fs"
	_L.denunciation_format = "%s a cassé '%s' sur '%s' avec '%s' ! Le sort a duré %.2fs"
	_L.announcement_format = "%s a cassé '%s' sur '%s' avec '%s' ! Le sort a duré %.2fs"
	_L.swing = "coup blanc"
	_L.ranged = "tir"
else
	-- default to english
	_L.warning_format = "You broke '%s' on '%s' with your '%s'! The aura lasted for %.2fs"
	_L.denunciation_format = "%s broke your '%s' on '%s' with '%s'! The aura lasted for %.2fs"
	_L.announcement_format = "%s broke '%s' on '%s' with '%s'! The aura lasted for %.2fs"
	_L.swing = "melee hit"
	_L.ranged = "ranged hit"
end

-- utils
function table.hasKey(haystack, needle)
	for i,v in pairs(haystack) do
		if i == needle then
			return true, i
		end
	end

	return false, nil
end

function table.find(haystack, needle)
	for i,v in pairs(haystack) do 
		if v == needle then
			return i
		end
	end

	return nil 
end

local function printf(format, ...)
	return print(string.format(format, ...))
end

local function debug_print(...)
	if AuraBreak.debug then
		print(...)
	end
end

--------------------------------------------------------------------------------
------------Addon functionalities-----------------------------------------------
--------------------------------------------------------------------------------

local function print_spell_list()
	local list = {}
	for i,v in pairs(AuraBreak.auras_we_care_about) do
		local spell_name, rank, _, _, _, _, spell_id = GetSpellInfo(v)
		if not list[spell_name] then list[spell_name] = {} end

		table.insert(list[spell_name], spell_id)
	end

	print("AuraBreakNotify spell list:")
	for i,v in pairs(list) do
		printf("    %s [%s]", i, table.concat(v, ","))
	end
end

local function tprint(t, indent)
	if not indent then indent = "" end

	for i,v in pairs(t) do 
		if type(v) == "table" then
			print(indent .. tostring(i) .. ": {")
			tprint(v, "  "..indent)
			print("}")
		else
			print(indent .. tostring(i),v)
		end
	end
end

local function unwatch_spell(spell_to_unwatch)
	-- if user passed bogus spell name
	if not spell_to_unwatch or tostring(spell_to_unwatch) == "" then
		print("AuraBreak Notify: Error, wrong usage for 'unwatch'\n" .. "Usage: " .. cmd.UNWATCH.syntax)
		return false
	end

	local spell_to_unwatch_name, _, _, _, _, _, spell_to_unwatch_id = GetSpellInfo(spell_to_unwatch)

	-- list of spell ids
	local found = 0
	local lower_spell_to_unwatch_name = string.lower(spell_to_unwatch_name)	
	for i,spell_id in pairs(AuraBreak.auras_we_care_about) do
		local spell_name, _, _, _, _, _, spell_id = GetSpellInfo(spell_id)
		if spell_id ~= nil then
			if string.lower(spell_name) == lower_spell_to_unwatch_name then
				AuraBreak.auras_we_care_about[i] = nil
				AuraBreak.auras_we_care_about_by_name[spell_name] = nil
				found = found+1
				print("Removed '" .. spell_name .. "' from watch list (" .. spell_id .. ")")
			end
		end
	end

	if found <= 0 then
		print("AuraBreak Notify: Spell " .. spell_to_unwatch .. " not found in the watched list.")
		return false
	end

	return found
end 

local function watch_spell(spell_name)
	if spell_name == "" or not spell_name then
		print("AuraBreak Notify: Error, wrong usage for 'watch'\n" .. "Usage: " .. cmd.WATCH.syntax)
		return false
	end

	local _, _, _, _, _, _, spell_id = GetSpellInfo(spell_name)
	if type(spell_id) ~= "number" then
		print("AuraBreak Notify: Spell '" .. spell_name .. "'' not found. Try to use a spell ID instead, those always work.")
		return false
	end

	for i,v in pairs(AuraBreak.auras_we_care_about) do
		if v == spell_id then
			print("AuraBreak Notify: Spell '" .. spell_name .. "'' is already being watched (" .. spell_id .. ")")
			return false
		end
	end

	AuraBreak.auras_we_care_about[#AuraBreak.auras_we_care_about] = spell_id
	AuraBreak.auras_we_care_about_by_name[spell_name] = spell_id
	return true
end

local function spells_by_name(spell_IDs)
	local t = {}
	for _, spell_id in pairs(spell_IDs) do
		local spell_name = GetSpellInfo(spell_id)
		t[spell_name] = spell_id
	end

	return t
end

local function reset()
	if not AuraBreak then AuraBreak = {} end
	AuraBreak = {
		debug = AuraBreak.debug or false,
		auto_whisper = AuraBreak.auto_whisper or false,
		whisper_everyone = AuraBreak.whisper_everyone or false,
		reset_on_death = true,
		denunciation = true,
		warnings = true,
		announcements = "OFF",
		enabled = true,
		auras_we_care_about = {
			9484, 9485, 10955,                      -- Priest undead caging
			--10890, 8122, 8124, 10888,               -- Priest area fear
			5782, 6213, 6215,                       -- Warlock fear
			--5484, 17928,                            -- Warlock area fear
			--5246, 19871, 19870,                     -- Warrior area fear
			12826, 12825, 12824, 118, 28271, 28272, -- Mage sheep
			10326, 2878, 5627,                      -- Paladin undead fear
			--11286, 1777, 8629, 11285,               -- Rogue gouge
			--6770, 2070,                             -- Rogue sap
			--2094,                                   -- Rogue blind
			1513, 14326, 14327,                     -- Hunter beast fear
			2637, 18658, 18657,                     -- Druid hibernate
			--6358,                                   -- Succubus seduction
		},
		auras_we_care_about_by_name = {} -- filled at runtime
	}

	AuraBreak.auras_we_care_about_by_name = spells_by_name(AuraBreak.auras_we_care_about)
end



--------------------------------------------------------------------------------
------------Event handling for the combat log-----------------------------------
--------------------------------------------------------------------------------
local subevent_handlers = {}
function subevent_handlers.SPELL_AURA_APPLIED(state, ...)
	local timestamp, subevent, unk, source_guid, source_name, source_flags, source_raid_flags, dest_guid, dest_name, dest_flags, destRaidFlags, unk_int, spell_name, aura_type_name = ...
	debug_print("## AURA APPLIED", spell_name)


	if AuraBreak.auras_we_care_about_by_name[spell_name] then
		print("#### WE CARE")
		if not state.mobs[dest_guid] then
			state.mobs[dest_guid] = {
				name=dest_name,
				auras = {},
			}
		end
		state.mobs[dest_guid].auras[spell_name] = {
			timestamp=timestamp,
			caster=source_name,
			caster_guid=source_guid,
		}
	end
end

function subevent_handlers.SPELL_AURA_REMOVED(state, ...)
	local timestamp, subevent, unk, source_guid, source_name, source_flags, source_raid_flags, dest_guid, dest_name, dest_flags, destRaidFlags, unk_int, spell_name, aura_type_name = ...
	-- If aura removed then check why and notify aura breaker

	debug_print("## AURA REMOVED", spell_name)

	-- If mob is tracked
	if state.mobs[dest_guid] and AuraBreak.auras_we_care_about_by_name[spell_name] then
		debug_print("#### WE CARE", state.mobs[dest_guid].name)
		C_Timer.After(1, function()
			local mob = state.mobs[dest_guid]
			if not mob or not mob.auras or not mob.auras[spell_name] then return end

			debug_print("## TATTLING")
			-- If mob was hit recently
			if mob.last_hit then
				debug_print("#### LAST HIT FOUND", mob.last_hit.spell_name, mob.last_hit.caster, mob.auras[spell_name].caster)
				if mob.last_hit.caster ~= mob.auras[spell_name].caster or AuraBreak.auto_whisper then
					local time_buff_was_up = timestamp - mob.auras[spell_name].timestamp

					if AuraBreak.denunciation then
						local dest = mob.auras[spell_name].caster
						if AuraBreak.whisper_everyone or UnitInParty(dest) or UnitInRaid(dest) or (UnitGUID(dest) == UnitGUID("player") and AuraBreak.auto_whisper) then
							-- He broke it
							SendChatMessage(
								string.format(_L.denunciation_format, mob.last_hit.caster, spell_name, mob.name, mob.last_hit.spell_name, time_buff_was_up)

								, "WHISPER", nil, dest
							)
						end
					end

					if AuraBreak.warnings then
						local dest = mob.last_hit.caster
						if AuraBreak.whisper_everyone or UnitInParty(dest) or UnitInRaid(dest) or (UnitGUID(dest) == UnitGUID("player") and AuraBreak.auto_whisper) then
							-- You broke it
							SendChatMessage(
								string.format(_L.warning_format, spell_name, mob.name, mob.last_hit.spell_name, time_buff_was_up)

								, "WHISPER", nil, dest
							)
						end
					end

					if AuraBreak.announcements ~= "OFF" then
						local restriction_level_allowed = ANNOUNCEMENTS[AuraBreak.announcements] or ANNOUNCEMENTS.OFF
						local channel
						local channel_restriction
						local talk = true

						-- 1 Off => 
						-- 2 Raid => Raid
						-- 3 Party => Party and raid
						-- 4 Always => Party and raid and say

						if UnitInRaid("player") then
							channel = "RAID"
							channel_restriction = ANNOUNCEMENTS.RAID
						elseif UnitInParty("player") then
							channel = "PARTY"
							channel_restriction = ANNOUNCEMENTS.PARTY
						else
							channel = "SAY"
							channel_restriction = ANNOUNCEMENTS.ALWAYS
						end

						print(restriction_level_allowed, channel_restriction, channel, string.format(_L.announcement_format, mob.last_hit.caster, spell_name, mob.name, mob.last_hit.spell_name, time_buff_was_up))

						if restriction_level_allowed >= channel_restriction then
							SendChatMessage(
								string.format(_L.announcement_format, mob.last_hit.caster, spell_name, mob.name, mob.last_hit.spell_name, time_buff_was_up)
								, channel, nil
							)
						end
					end
				end
			end

			if mob.auras[spell_name] then
				mob.auras[spell_name] = nil
			end
		end)
	end
end
local function ANY_DAMAGE(state, spell_name, ...)
	-- If mob with aura is threatened, log the hit
	local timestamp,_,_,_, source_name,_,_, dest_guid,_,_,_,_, spell_name = ...
	local mob = state.mobs[dest_guid]

	debug_print("## DAMAGE", spell_name)

	if mob then
		debug_print("#### WE CARE", mob.name)
		mob.last_hit = {
			caster=source_name,
			timestamp=timestamp,
			spell_name=spell_name,
		}
	end
end
function subevent_handlers.SPELL_DAMAGE(state, ...)
	return ANY_DAMAGE(state, spell_name, ...)
end
subevent_handlers.SPELL_PERIODIC_DAMAGE = subevent_handlers.SPELL_DAMAGE
function subevent_handlers.SWING_DAMAGE(state, ...)
	return ANY_DAMAGE(state, _L.swing, ...)
end
function subevent_handlers.RANGE_DAMAGE(state, ...)
	return ANY_DAMAGE(state, _L.ranged, ...)
end

function subevent_handlers.UNIT_DIED(state, ...)
	local timestamp, subevent, unk, source_guid, source_name, source_flags, source_raid_flags, dest_guid, dest_name, dest_flags, destRaidFlags, unk_int, spell_name, aura_type_name = ...
	-- If a unit dies, we forget about it

	debug_print("## MOB DEAD", dest_name)


	if AuraBreak.reset_on_death then
		state:reset_mob(dest_guid)
	end
end

-- f is of type Frame
function f:reset_mob(dest_guid)
	if self.mobs then
		if self.mobs[dest_guid] then
			self.mobs[dest_guid].last_hit = nil
			self.mobs[dest_guid].auras = nil
			self.mobs[dest_guid] = nil
		end
	end
end

function f:RESET_TRACKING()
	--print("## RESET_TRACKING")
	if self.mobs then
		for i,v in pairs(self.mobs) do
			--print("  ## ", v.name)
			self:reset_mob(i)
		end
	end
end

function f:COMBAT_LOG_EVENT_UNFILTERED(...)
	if AuraBreak.enabled == false then return end
	
	local _, subevent = ...
	local subevent_handler = subevent_handlers[subevent]
	
	if subevent_handler ~= nil then
		subevent_handler(self, ...)
	end
end


--------------------------------------------------------------------------------
------------Chat commands-------------------------------------------------------
--------------------------------------------------------------------------------
local cmd
local function print_usage()
	local help_str = "Usage: "
	for i,v in pairs(cmd) do
		help_str = help_str .. "\n/abn " .. v.syntax
	end
	print(help_str)
end
local function get_status(subcommand)
	local SUBCOMMAND = string.upper(subcommand) 
	if cmd[SUBCOMMAND] and cmd[SUBCOMMAND].toString then
		return cmd[SUBCOMMAND]:toString()
	else
		return nil
	end
end
local function print_status(subcommand)
	if subcommand and subcommand ~= "" then
		local status = get_status(subcommand)
		if status then
			print(status)
		else
			printf("Status is unknown for '%s'", tostring(subcommand))
		end
	elseif AuraBreak.debug then
		tprint(AuraBreak)
	else
		for i,v in pairs(cmd) do
			if type(v.toString) == "function" then
				print(v:toString())
			end
		end
		print_spell_list()
	end
end
local function print_help(subcommand)
	if not subcommand or type(subcommand) ~= "string" then
		return print_usage()
	end

	if subcommand == "" then
		for i,v in pairs(cmd) do print_help(i) end
		return
	end

	local SUBCOMMAND = string.upper(subcommand)
	if cmd[SUBCOMMAND] then
		printf("Aura Break Notify: Here's the help for the command '%s':", subcommand)
		printf("  Syntax: %s", cmd[SUBCOMMAND].syntax or "")
		
		local help = cmd[SUBCOMMAND].help
		if help then
			printf("    %s", help)
		end

		local status = get_status(subcommand)
		if status then
			printf("  Status: %s", status)
		end
	else
		printf("AuraBreak Notify: no such command as %s.", tostring(subcommand))
	end
end
cmd = {
	LIST = {
		syntax="list",
		help="Lists all spells being watched",
		handler=print_spell_list,
	},
	RESET = {
		syntax="reset",
		help="Reset the addon's configs to its defaults",
		handler=function() 
			reset()
			print_spell_list()
		end,
	},
	WATCH = {
		syntax="watch <spell_name | spell_id>",
		help="Will start watching aura breaks for this spell",
		handler=function(_, arg) 
			local ret, err = watch_spell(arg)
			if ret then
				print("Success!")
				print_spell_list()
			end
		end,
	},
	UNWATCH = {
		syntax="unwatch <spell_name | spell_id>",
		help="Will stop watching whether or not this aura breaks",
		handler=function(_, arg)
			local ret, err = unwatch_spell(arg)
			if ret then
				print_spell_list()
			end
		end,
	},
	DISABLE = {
		syntax="disable",
		help="Disable the addon entirely",
		toString=function()
			return "AuraBreak is " .. (AuraBreak.enabled and WrapTextInColorCode("enabled", GREEN) or WrapTextInColorCode("disabled", RED))
		end,
		handler=function()
			f:RESET_TRACKING()
			AuraBreak.enabled = false
			print("AuraBreak Notifications disabled")
		end,
	},
	ENABLE = {
		syntax="enable",
		help="Enable the addon",
		toString=function()
			return "AuraBreak is " .. (AuraBreak.enabled and WrapTextInColorCode("enabled", GREEN) or WrapTextInColorCode("disabled", RED))
		end,
		handler=function() 
			AuraBreak.enabled = true
			print("AuraBreak Notifications enabled")
		end,
	},
	STATUS = {
		syntax="status [optional subcommand]",
		help="Display the current configuration",
		handler=function(_, arg) print_status(arg) end,
	},
	ANNOUNCEMENTS = {
		syntax="announcements <off | party | raid | always>",
		help="Configures when to broadcast aura breaks. Default is OFF. I find it distasteful, but it's available anyway.\n    OFF: Never\n    PARTY: When in group or in raid (will use /raid if you're in raid, /party if not)\n    RAID: Only in raid\n    ALWAYS: Even alone, you will broadcast aurabreaks in /say (note: this API call was protected in 1.13.3, it now only works in dungeons or battlegrounds).",
		toString=function()
			if AuraBreak.announcements == "OFF" then
				return "AuraBreak public announcements are " .. WrapTextInColorCode("OFF", RED)
			else
				return "AuraBreak public announcements are set to " .. WrapTextInColorCode(AuraBreak.announcements, GREEN)
			end
		end,
		handler=function(_, arg) 
			local ARG=string.upper(arg)
			if table.hasKey(ANNOUNCEMENTS, ARG) then
				AuraBreak.announcements = ARG
			else
				AuraBreak.announcements = "OFF"
			end
			print_status("announcements")
		end,
	},
	WARNINGS = {
		syntax="warnings <on | off>",
		help="Toggles whispering the aura breaker that they broke an aura.",
		toString=function()
			return "AuraBreak warnings are " .. (AuraBreak.warnings and WrapTextInColorCode("ON", GREEN) or WrapTextInColorCode("OFF", RED))
		end,
		handler=function(_, arg) 
			if arg ~= "" then
				AuraBreak.warnings = (arg == "on") and true or false
			end
			print_status("warnings")
		end,
	},
	DENUNCIATION = {
		syntax="denunciation <on | off>",
		help="Toggles whispering to the original caster of an important aura that his spell broke.",
		toString=function()
			return "AuraBreak denunciations are " .. (AuraBreak.denunciation and WrapTextInColorCode("ON", GREEN) or WrapTextInColorCode("OFF", RED))
		end,
		handler=function(_, arg) 
			if arg ~= "" then
				AuraBreak.denunciation = (arg == "on") and true or false
			end
			print_status("denunciation")
		end,
	},
	DEATH_RESET = {
		syntax="death_reset <on | off>",
		help="Toggles messages for auras broken by the death of an NPC. You probably want this ON, turning it off is a niche use. Mainly for debugging purposes.",
		toString=function() 
			return "AuraBreak reset on death is " .. (AuraBreak.reset_on_death and WrapTextInColorCode("ON", GREEN) or WrapTextInColorCode("OFF", RED))
		end,
		handler=function(_, arg)
			if arg ~= "" then
				AuraBreak.reset_on_death = (arg == "on") and true or false
			end
			print_status("death_reset")
		end,
	},
	HELP = {
		syntax="help",
		help="Gives detailed instructions about a /abn command",
		handler=function(_, arg) print_help(arg) end,
	},
}

--------------------------------------------------------------------------------
----------Code that will execute after the global "AuraBreak" is loaded---------
--------------------------------------------------------------------------------
local function on_variable_load()
	if AuraBreak and AuraBreak.debug == true then
		-- Chat typing shenanigans
		for i = 1, NUM_CHAT_WINDOWS do
			_G["ChatFrame" .. i .. "EditBox"]:SetAltArrowKeyMode(false)
		end

		-- Register commands
		SLASH_RELOADUI1 = "/rl"
		SLASH_FRAMESTK1 = "/fs"
		SlashCmdList.FRAMESTK = function()
			LoadAddOn('Blizzard_DebugTools')
			FrameStackTooltip_Toggle()
		end
	end

	SLASH_ABN1 = "/abn"
	SlashCmdList.ABN = function(subcommand)
		local subcommand, arg = string.match(subcommand, "([^ ]*) *(.*)$")

		-- Check if the subcommand is something that exists
		-- if it does, call command handler
		local SUBCOMMAND=string.upper(subcommand)
		if cmd[SUBCOMMAND] ~= nil then
			cmd[SUBCOMMAND].handler(subcommand, arg)
		else
			printf("AuraBreak Notify: no such command as '%s'.", tostring(subcommand))
			print_usage()
		end
	end
	
	if not AuraBreak then reset() end
	print_spell_list()
end

--------------------------------------------------------------------------------
----------Code that will execute first------------------------------------------
--------------------------------------------------------------------------------
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function(self, event)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		self:COMBAT_LOG_EVENT_UNFILTERED(CombatLogGetCurrentEventInfo())
	elseif event == "VARIABLES_LOADED" then
		on_variable_load()
	elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
		self:RESET_TRACKING()
	end
end)
