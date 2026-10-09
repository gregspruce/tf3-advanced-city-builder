--[[
Advanced City Builder - mod script (mod.json "preRunScript": advanced_city_builder::/mod.script@preRunFn).

WHAT IT DOES
  Applies the two game-wide street angle mod settings to the game's BaseConfig before the game starts:
    acb_growth_angle  -> baseConfig.townMajorStreetAngleRange         (all later town growth)
    acb_initial_angle -> baseConfig.townInitialMajorStreetAngleRange  (first layout of new towns made
                         without this tool, e.g. the regular Town Builder; also the default of this
                         tool's own Initial Road Angle Range slider)
  Both are degrees; the options come from scripts/advanced_city_builder/road_angles.lua.

WHY
  The native TownBuilder only takes an initial angle range for the town's first street core. Growth
  beyond that core (and every later expansion) uses the global townMajorStreetAngleRange, which the base
  game sets to 0 (base/mod.script.tl:110-111), so large towns turn into a straight grid outside the core.
  A preRunFn may override BaseConfig values; base runs first, then mods in activation order (wiki
  modding:general:modscripts; the official sandbox mod sets baseConfig.sandboxMode the same way).

  Option 1 (0 deg) leaves the game's value untouched instead of writing 0, so ACB never overrides another
  mod's setting unless the player picks an angle here.

The settings are chosen when the mod is enabled and are stored in the savegame; they can be changed
when a savegame is loaded. Plain Lua 5.2, `function data()` form; no globals (base/init.lua forbids them).
]]

local road_angles = require "/scripts/advanced_city_builder/road_angles.lua"

local MOD_ID = "advanced_city_builder" -- fallback; must match mod.json "modId"
-- mod.json params arrive as 1-based value indices (mod.json defaultIndex is 0-based).
local GROWTH_ANGLE_PARAM = "acb_growth_angle"
local INITIAL_ANGLE_PARAM = "acb_initial_angle"
local LOGGING_PARAM = "acb_logging" -- {"Off", "On"}
local LOGGING_ON = 2

-- Our params from allModParams. getCurrentModId() names the running mod; fall back to MOD_ID if it is
-- unavailable or unknown.
local function ownParams(allModParams)
	local modId = type(getCurrentModId) == "function" and getCurrentModId() or nil
	if modId == nil or allModParams[modId] == nil then
		modId = MOD_ID
	end
	return allModParams[modId] or {}
end

local function preRunFn(_captureParams, _configDict, allModParams, baseConfig)
	local params = ownParams(allModParams or {})
	local logging = params[LOGGING_PARAM] == LOGGING_ON

	local function apply(paramKey, configKey)
		local index = params[paramKey] or 1
		if index > 1 then
			baseConfig[configKey] = road_angles.degrees(index)
		end
		if logging then
			log.message("[ACB] " .. configKey .. " = " .. tostring(baseConfig[configKey])
				.. (index > 1 and " (set by mod setting " .. paramKey .. ")" or " (unchanged, mod setting " .. paramKey .. " = 0)"))
		end
	end

	apply(GROWTH_ANGLE_PARAM, "townMajorStreetAngleRange")
	apply(INITIAL_ANGLE_PARAM, "townInitialMajorStreetAngleRange")
end

function data()
	return {
		preRunFn = preRunFn,
	}
end
