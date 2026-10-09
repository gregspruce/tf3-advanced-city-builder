--[[
Road angle options shared by every road angle control of Advanced City Builder, so they always offer
the same values:
  - mod settings "Organic street growth" and "Organic streets in new towns" (mod.json params
    acb_growth_angle / acb_initial_angle, applied by content/mod.script.lua);
  - the tool's "Initial Road Angle Range" slider (gui/construction/tools/advanced_city_builder_tool.script.lua).

Option i (1-based, as mod params and tool sliders deliver it) = (i - 1) * STEP_DEG degrees:
0, 2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20.
The mod.json "values" lists are plain JSON and cannot use this module: keep them in sync by hand.

The degrees feed the engine's town street angle settings (BaseConfig townMajorStreetAngleRange /
townInitialMajorStreetAngleRange, native TownBuilder initialMajorStreetAngleRange), all in degrees.

Plain Lua 5.2 module (required by path, returns a table; no globals).
]]

local road_angles = {}

road_angles.STEP_DEG = 2.5
road_angles.COUNT = 9 -- 0 .. 20 degrees

-- Degrees for a 1-based option index. Out-of-range or missing indices are clamped (nil -> option 1, 0 deg).
function road_angles.degrees(index)
	local i = math.max(1, math.min(road_angles.COUNT, math.floor(tonumber(index) or 1)))
	return (i - 1) * road_angles.STEP_DEG
end

-- Option index whose angle is closest to `deg` (used to preselect a slider from a configured angle).
function road_angles.closestIndex(deg)
	local best, bestDiff = 1, math.huge
	for i = 1, road_angles.COUNT do
		local diff = math.abs(road_angles.degrees(i) - (deg or 0))
		if diff < bestDiff then
			best, bestDiff = i, diff
		end
	end
	return best
end

-- Display labels "0°", "2.5°", ... "20°" (%g drops the ".0" of whole numbers; degree sign in UTF-8).
function road_angles.labels()
	local labels = {}
	for i = 1, road_angles.COUNT do
		labels[i] = string.format("%g", road_angles.degrees(i)) .. "\194\176"
	end
	return labels
end

return road_angles
