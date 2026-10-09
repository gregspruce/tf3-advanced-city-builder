--[[
Advanced City Builder v0 (proof of concept): a town-placement tool in the Town menu > Tools.

WHAT v0 DOES
  Duplicates the base game's Experimental Town Builder (separate residential/commercial/industrial
  sizes, initial road angle range, capacity scaling factor) with these changes:
  - the initial road angle range offers the mod's shared angle options (0-20 degrees in 2.5 degree
    steps, scripts/advanced_city_builder/road_angles.lua; vanilla: 0-90 in 3 degree steps), the same as
    the mod settings that content/mod.script.lua applies game-wide;
  - every district gets ONE cargo-need choice: None, Random, or a specific cargo (instead of assigning
    each cargo type to a district);
  - district sizes are sliders (50 .. max in steps of 50); max = 1600 (the vanilla maximum) times the
    "Maximum town capacity" mod setting (100/125/150/200 %).

WHY A CUSTOM ACTION (and not action = "ACTION_TOWN_BUILDER_EXPERIMENTAL")
  For the vanilla actions, the base game's construction_react_util.tl converts the tool's params into the
  native TownBuilder action using ITS OWN param keys, so a mod cannot change that mapping (e.g. add
  "Random" to the experimental builder). A definition with a `customAction` instead renders our recipe,
  which binds its own action function through params.setActionFn (the pattern of the vanilla perk tools
  marketing_campaign_tool / industry_greenify_tool). Our action function builds the same native
  builtin.ConstructionAction{ townBuilder = ... } from our params, so the engine still does all the town
  placement work.

  Native TownBuilder fields (base scripts/builtin.d.tl:375-387): initialLandUseCapacity {R,C,I},
  landUse2CargoNeeds {R,C,I} (lists of cargo type ids; -1 = random, as the vanilla regular Town Builder
  sends), initialMajorStreetAngleRange (degrees), capacityScalingFactor, builderAudioRes.

Plain Lua 5.2 (the engine's version); `function data()` form like vanilla .script.lua files.

LOGGING
  Off by default. Enabled by the mod setting "Diagnostic logging" (mod.json param `acb_logging`), chosen
  when the mod is activated for a game. Lines go to stdout.txt with the prefix "[ACB]" (log.message
  reaches stdout.txt; log.verbose does not).
]]

local react = require "::/gui/main/react.lua"
local builtin = require "::/gui/main/builtin.lua"
local engine_react_util = require "::/gui/main/engine_react_util.tl"
local road_angles = require "/scripts/advanced_city_builder/road_angles.lua"

-- ------------------------------------------------------------------------------------------------
-- Mod settings (mod.json "params", chosen when the mod is activated for a game)
-- ------------------------------------------------------------------------------------------------
local MOD_ID = "advanced_city_builder" -- must match mod.json "modId"
-- Mod params arrive as 1-based value indices: mod.json `defaultIndex` is 0-based, but the runtime value
-- is 1-based (base game: reforestation `defaultIndex: 1` = On is read as `== 2`, base/mod.script.tl:253).
local LOGGING_PARAM = "acb_logging" -- values {"Off", "On"}
local LOGGING_ON = 2
local MAX_CAPACITY_PARAM = "acb_max_capacity" -- values {"100%", "125%", "150%", "200%"}
local MAX_CAPACITY_PERCENTS = { 100, 125, 150, 200 }

-- Value index of one of our mod settings, or `default` when it cannot be read. pcall: the config may
-- not be available yet while the script is first loaded.
local function getModSetting(key, default)
	local ok, value = pcall(function()
		local mine = api.engine.config.getModParams()[MOD_ID]
		return mine ~= nil and mine[key] or nil
	end)
	if ok and type(value) == "number" then
		return value
	end
	return default
end

-- Read on every call: the setting is fixed for a game, and logging is rare.
local function loggingEnabled()
	return getModSetting(LOGGING_PARAM, 1) == LOGGING_ON
end

local function logMessage(message)
	if loggingEnabled() then
		log.message("[ACB] " .. message)
	end
end

-- ------------------------------------------------------------------------------------------------
-- Parameter model (keys are prefixed "acb_" so remembered values never collide with vanilla tools)
-- ------------------------------------------------------------------------------------------------
-- District capacity sliders: CAPACITY_STEP .. max in steps of CAPACITY_STEP. The "normal" maximum is
-- the vanilla Experimental Town Builder's largest option (1600); the mod setting raises it by a percentage.
local CAPACITY_STEP = 50
local NORMAL_MAX_CAPACITY = 1600
local CAPACITY_DEFAULT = 100 -- vanilla experimental default

local function maxCapacity()
	local percent = MAX_CAPACITY_PERCENTS[getModSetting(MAX_CAPACITY_PARAM, 1)] or MAX_CAPACITY_PERCENTS[1]
	return math.floor(NORMAL_MAX_CAPACITY * percent / 100 / CAPACITY_STEP) * CAPACITY_STEP
end

-- {50, 100, ..., max}; slider index i <-> capacities[i]
local function capacitySteps(max)
	local steps = {}
	for capacity = CAPACITY_STEP, max, CAPACITY_STEP do
		steps[#steps + 1] = capacity
	end
	return steps
end
local CAPACITY_DEFAULT_INDEX = CAPACITY_DEFAULT / CAPACITY_STEP -- index of 100 in capacitySteps()

local SCALING_FACTORS = { 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0 }
local SCALING_DEFAULT_INDEX = 4 -- 1.0

-- Cargo-need choice per district: index 1 = None, 2 = Random, 3.. = cargo types in repository order.
local CARGO_NONE_INDEX = 1
local CARGO_RANDOM_INDEX = 2
local RANDOM_CARGO_ID = -1 -- marker the vanilla regular Town Builder uses for "random"

-- Districts in the order the native TownBuilder expects: residential, commercial, industrial.
local DISTRICTS = {
	{ capacityKey = "acb_res_capacity", cargoKey = "acb_res_cargo" },
	{ capacityKey = "acb_com_capacity", cargoKey = "acb_com_cargo" },
	{ capacityKey = "acb_ind_capacity", cargoKey = "acb_ind_cargo" },
}
-- Renamed from v0's "acb_road_angle_range" (3-degree steps) so a remembered old index is not
-- reinterpreted on the new 2.5-degree scale.
local ANGLE_KEY = "acb_initial_road_angle"
local SCALING_KEY = "acb_capacity_scaling"

local BUILDER_AUDIO = "::/gui/construction/sound/buildoze_town.builder_audio"
-- Ids of the construction menu's parameter windows (base gui/construction/construction.tl:175-176).
-- Passed like the default action does, so clicking our params does not steal focus from the action.
local PARAM_WINDOW_IDS = { "menu.construction.params.react", "menu.construction.bottomparams.react" }

-- Index of the angle option closest to the game's initial angle range (vanilla does the same). That
-- value is the mod setting "Organic streets in new towns" when it is not 0 (content/mod.script.lua).
local function defaultAngleIndex()
	return road_angles.closestIndex(api.res.getBaseConfig().townInitialMajorStreetAngleRange or 0)
end

-- ------------------------------------------------------------------------------------------------
-- Params -> native TownBuilder
-- ------------------------------------------------------------------------------------------------
-- p: {key = value} from the parameter panel. Button/Slider/ComboBox params deliver the 1-based value
-- index; a `numbers` param delivers the number itself (as in the vanilla experimental conversion).
local function cargoNeeds(index, cargoTypeIds)
	if index == nil or index == CARGO_RANDOM_INDEX then
		return { RANDOM_CARGO_ID }
	end
	if index == CARGO_NONE_INDEX then
		return {}
	end
	local cargoTypeId = cargoTypeIds[index - CARGO_RANDOM_INDEX]
	return cargoTypeId and { cargoTypeId } or {}
end

local function makeTownBuilder(p, capacities, cargoTypeIds, angleDefaultIndex)
	local townBuilder = builtin.type.ConstructionAction.TownBuilder.new()
	local chosen, needs = {}, {}
	for i, district in ipairs(DISTRICTS) do
		chosen[i] = capacities[p[district.capacityKey] or CAPACITY_DEFAULT_INDEX] or CAPACITY_DEFAULT
		needs[i] = cargoNeeds(p[district.cargoKey], cargoTypeIds)
	end
	townBuilder.initialLandUseCapacity = chosen
	townBuilder.landUse2CargoNeeds = needs
	townBuilder.initialMajorStreetAngleRange = road_angles.degrees(p[ANGLE_KEY] or angleDefaultIndex)
	townBuilder.capacityScalingFactor = p[SCALING_KEY] or SCALING_FACTORS[SCALING_DEFAULT_INDEX]
	townBuilder.builderAudioRes = BUILDER_AUDIO
	return townBuilder
end

-- One log line whenever the values sent to the town builder change (not on every re-render).
local lastLoggedSummary = nil
local function logTownBuilder(townBuilder)
	local cap, needs = townBuilder.initialLandUseCapacity, townBuilder.landUse2CargoNeeds
	local function list(t)
		local out = {}
		for i, v in ipairs(t) do
			out[i] = tostring(v)
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	local summary = "capacity R/C/I " .. cap[1] .. "/" .. cap[2] .. "/" .. cap[3]
		.. ", road angle range " .. townBuilder.initialMajorStreetAngleRange
		.. ", capacity scaling " .. townBuilder.capacityScalingFactor
		.. ", cargo needs R/C/I " .. list(needs[1]) .. " " .. list(needs[2]) .. " " .. list(needs[3]) .. " (-1 = random)"
	if summary ~= lastLoggedSummary then
		lastLoggedSummary = summary
		logMessage("town builder: " .. summary)
	end
end

-- Snapshot of the panel's current values (a copy, so the step-state comparison sees changes).
local function readParams(customParams, old)
	local ok, current = pcall(customParams.getCurrentParams)
	if not ok or current == nil then
		return old or {}
	end
	local copy = {}
	for k, v in pairs(current) do
		copy[k] = v
	end
	return copy
end

-- ------------------------------------------------------------------------------------------------
-- Custom action recipe
-- ------------------------------------------------------------------------------------------------
-- Rendered by the construction menu while our tool is selected (base construction.tl:401-438).
-- Once the tool is activated (params.isActive), we bind our action function; the menu then uses it
-- instead of its default action (base construction.tl:4488-4500).
local AdvancedCityBuilderAction = react.RegisterRecipe("AdvancedCityBuilderAction", function(params)
	if not params.isActive then
		return
	end
	local customParam = params.customParam

	local actionFn = function()
		-- Re-read the panel every frame; the state only changes (and the action only rebuilds) when a
		-- value actually changed.
		local paramState = engine_react_util.useStepState(function(old)
			return readParams(params, old)
		end)
		local current = paramState:old() or {}
		local townBuilder = makeTownBuilder(current, customParam.capacities, customParam.cargoTypeIds, customParam.angleDefaultIndex)
		logTownBuilder(townBuilder)
		return builtin.ActionDescriptor{
			onBack = function() params.abort() end,
			children = {
				builtin.ConstructionAction{
					townBuilder = townBuilder,
					preventFocusStealFromIds = PARAM_WINDOW_IDS,
				},
			},
		}
	end

	params.setActionFn(actionFn, "AdvancedCityBuilderAction" .. tostring(params.definition))
end)

-- ------------------------------------------------------------------------------------------------
-- Tool definition (menu entry + parameter panel)
-- ------------------------------------------------------------------------------------------------
local function getDefinition(constructionDefinition, repository, _params)
	local ScriptParamType = api.type.enum.ScriptParamType
	local DisplayMode = api.type.enum.ScriptParamDisplayMode

	-- Capacity slider steps depend on the "Maximum town capacity" mod setting (fixed for a game).
	local max = maxCapacity()
	local capacities = capacitySteps(max)
	local capacityStrings = {}
	for i, capacity in ipairs(capacities) do
		capacityStrings[i] = tostring(capacity)
	end
	local angleStrings = road_angles.labels()
	local angleDefaultIndex = defaultAngleIndex()

	-- One shared option list for every district (the experimental builder also allows any cargo in
	-- any district): None, Random, then each cargo type of this game.
	local cargoTypeIds = {}
	local cargoOptions = { _("None"), _("Random") }
	for __, cargoTypeId in ipairs(repository.cargoTypes) do -- "__", not "_": "_" is the translate function
		cargoTypeIds[#cargoTypeIds + 1] = cargoTypeId
		cargoOptions[#cargoOptions + 1] = api.res.cargoTypeRep.get(cargoTypeId).name
	end

	local districtNames = { _("Residential District"), _("Commercial District"), _("Industrial District") }
	local params = {}
	for i, district in ipairs(DISTRICTS) do
		params[#params + 1] = {
			key = district.capacityKey,
			name = districtNames[i],
			group = "districts",
			values = capacityStrings,
			defaultIndex = CAPACITY_DEFAULT_INDEX,
			displayMode = DisplayMode.Sparse,
			uiType = ScriptParamType.Slider,
			yearFrom = 0,
			yearTo = 0,
		}
	end
	params[#params + 1] = {
		key = ANGLE_KEY,
		name = _("Initial Road Angle Range"),
		group = "roads",
		values = angleStrings,
		defaultIndex = angleDefaultIndex,
		displayMode = DisplayMode.Sparse,
		uiType = ScriptParamType.Slider,
		yearFrom = 0,
		yearTo = 0,
	}
	params[#params + 1] = {
		key = SCALING_KEY,
		name = _("Capacity Scaling Factor"),
		group = "cargo",
		numbers = SCALING_FACTORS,
		defaultIndex = SCALING_DEFAULT_INDEX,
		displayMode = DisplayMode.Sparse,
		uiType = ScriptParamType.Slider,
		yearFrom = 0,
		yearTo = 0,
	}
	local cargoParamNames = { _("Residential Cargo Need"), _("Commercial Cargo Need"), _("Industrial Cargo Need") }
	for i, district in ipairs(DISTRICTS) do
		params[#params + 1] = {
			key = district.cargoKey,
			name = cargoParamNames[i],
			group = "cargo",
			values = cargoOptions,
			defaultIndex = CARGO_RANDOM_INDEX,
			uiType = ScriptParamType.ComboBox,
			yearFrom = 0,
			yearTo = 0,
		}
	end

	logMessage("definition built: capacity sliders " .. CAPACITY_STEP .. "-" .. max .. ", " .. #cargoTypeIds
		.. " cargo types, default angle index " .. angleDefaultIndex)

	return {
		resName = constructionDefinition,
		icon = { icon = "::/gui/construction/tools/build_town_adv.tga" },
		previewIcon = { icon = "::/gui/construction/tools/build_town_adv_preview.tga" },
		name = _("Advanced City Builder"),
		description = _("Place a town with custom district sizes, road angles and cargo needs."),
		action = "ACTION_CUSTOM",
		customAction = {
			recipe = AdvancedCityBuilderAction,
			customParam = { capacities = capacities, cargoTypeIds = cargoTypeIds, angleDefaultIndex = angleDefaultIndex },
		},
		availability = {
			yearFrom = 0,
			yearTo = 0,
		},
		params = params,
		hudIcons = {
			componentTypes = { api.type.ComponentType.TOWN },
			showTownBorders = true,
		},
		menuCategory = {
			categories = {
				{
					category = "town_tools",
					order = 3000, -- after the vanilla Town Builder (1000) and Experimental Town Builder (2000)
				},
			},
		},
		builderAudioRes = { BUILDER_AUDIO },
	}
end

logMessage("advanced_city_builder_tool.script loaded")

function data()
	return {
		getDefinition = getDefinition,
	}
end
