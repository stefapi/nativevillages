local S = minetest.get_translator("nativevillages")

-- Data driven definitions of the arctic buildings. Every entry is
-- passed to nativevillages.placement.register_building() (placement.lua),
-- which decides how the building is actually placed.

local buildings = {
    {
        name = "icehouse1",
        schematic = "icehouse1_30_90.mts",
        biomes = {"arctic"},
        offset = -4,
        y_max = 3.5,
        y_min = 1.0,
        fill_ratio = 0.0001,
    },
    {
        name = "icehouse2",
        schematic = "icehouse2_30_90.mts",
        biomes = {"arctic"},
        offset = -4,
        y_max = 3.5,
        y_min = 1.0,
        fill_ratio = 0.0001,
    },
    {
        name = "icehouse3",
        schematic = "icehouse3_30_90.mts",
        biomes = {"arctic"},
        offset = -4,
        y_max = 3.5,
        y_min = 1.0,
        fill_ratio = 0.0001,
    },
    {
        name = "icelogs",
        schematic = "icelogs_30_90.mts",
        biomes = {"arctic"},
        offset = -4,
        y_max = 3.5,
        y_min = 1.0,
        fill_ratio = 0.0001,
    },
    {
        name = "icepelts",
        schematic = "icepelts_30_90.mts",
        biomes = {"arctic"},
        offset = -4,
        y_max = 3.5,
        y_min = 1.0,
        fill_ratio = 0.0001,
    },
    {
        name = "icesledge",
        schematic = "icesledge_30_90.mts",
        biomes = {"arctic"},
        offset = -4,
        y_max = 3.5,
        y_min = 1.0,
        fill_ratio = 0.0001,
    },
}

for _, def in ipairs(buildings) do
    nativevillages.placement.register_building(def)
end
