-- Registers the Advanced City Builder as a construction tool, exactly like the vanilla town builders
-- (base: gui/construction/tools/town_builder_experimental_tool.res.lua). The game discovers resources of
-- type "construction_tool" and calls getDefinitionFn to build the menu entry and its parameter panel.
function data()
	return {
		type = "construction_tool",
		data = {
			getDefinitionFn = {
				fileName = resolve("advanced_city_builder_tool.script@getDefinition"),
			}
		}
	}
end
