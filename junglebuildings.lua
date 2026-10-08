local S = minetest.get_translator("nativevillages")

-- Data driven definitions of the jungle buildings. Every entry is
-- passed to nativevillages.placement.register_building() (placement.lua),
-- which decides how the building is actually placed.

local buildings = {
    {
        name = "junglehouse1",
        schematic = "cannibalhouse1_30_90.mts",
        biomes = {"jungle"},
        offset = -29,
        y_max = 20.5,
        y_min = 10.5,
        fill_ratio = 0.00005,
    },
    {
        name = "junglehouse2",
        schematic = "cannibalhouse2_30_90.mts",
        biomes = {"jungle"},
        offset = -29,
        y_max = 20.5,
        y_min = 10.5,
        fill_ratio = 0.00005,
    },
    {
        name = "junglehouse3",
        schematic = "cannibalhouse3_30_90.mts",
        biomes = {"jungle"},
        offset = -29,
        y_max = 20.5,
        y_min = 10.5,
        fill_ratio = 0.00005,
    },
    {
        name = "junglecage",
        schematic = "cannibalcage_30_270.mts",
        biomes = {"jungle"},
        offset = -29,
        y_max = 20.5,
        y_min = 10.5,
        fill_ratio = 0.00005,
    },
    {
        name = "junglepit",
        schematic = "cannibalpit_30_270.mts",
        biomes = {"jungle"},
        offset = -29,
        y_max = 20.5,
        y_min = 10.5,
        fill_ratio = 0.00005,
    },
    {
        name = "jungletower",
        schematic = "cannibaltower_30_180.mts",
        biomes = {"jungle"},
        offset = -29,
        y_max = 20.5,
        y_min = 10.5,
        fill_ratio = 0.00005,
    },
}

for _, def in ipairs(buildings) do
    nativevillages.placement.register_building(def)
end
