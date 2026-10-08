local S = minetest.get_translator("nativevillages")

-- Data driven definitions of the desert buildings. Every entry is
-- passed to nativevillages.placement.register_building() (placement.lua),
-- which decides how the building is actually placed.

local buildings = {
    {
        name = "deserthouse1",
        schematic = "deserthouse1_30_180.mts",
        biomes = {"desert"},
        offset = -29,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00005,
    },
    {
        name = "deserthouse2",
        schematic = "deserthouse2_30_180.mts",
        biomes = {"desert"},
        offset = -29,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00005,
    },
    {
        name = "deserthouse3",
        schematic = "deserthouse3_30_180.mts",
        biomes = {"desert"},
        offset = -29,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00005,
    },
    {
        name = "deserthouse4",
        schematic = "deserthouse4_30_180.mts",
        biomes = {"desert"},
        offset = -29,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00005,
    },
    {
        name = "deserthouse5",
        schematic = "deserthouse5_30_0.mts",
        biomes = {"desert"},
        offset = -29,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00005,
    },
    {
        name = "desertwell",
        schematic = "desertwell_30_0.mts",
        biomes = {"desert"},
        offset = -29,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00004,
    },
    {
        name = "desertmarket",
        schematic = "desertmarket_30_0.mts",
        biomes = {"desert"},
        offset = -29,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00008,
    },
    {
        name = "desertstable",
        schematic = "deserstable_30_0.mts",
        biomes = {"desert"},
        offset = -29,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00004,
    },
}

for _, def in ipairs(buildings) do
    nativevillages.placement.register_building(def)
end
