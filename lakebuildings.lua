local S = minetest.get_translator("nativevillages")

-- Data driven definitions of the lake buildings. Every entry is
-- passed to nativevillages.placement.register_building() (placement.lua),
-- which decides how the building is actually placed. The lake schematics
-- are anchored to the water surface (anchor = "water"): y_min/y_max are
-- kept for the legacy decoration mode only, no flatness test is applied.

local buildings = {
    {
        name = "lakehouse1",
        schematic = "lakehouse1_0_0.mts",
        biomes = {"lake"},
        anchor = "water",
        offset = 0,
        y_max = -0.5,
        y_min = -0.5,
        fill_ratio = 0.00005,
    },
    {
        name = "lakehouse2",
        schematic = "lakehouse2_0_0.mts",
        biomes = {"lake"},
        anchor = "water",
        offset = 0,
        y_max = -0.5,
        y_min = -0.5,
        fill_ratio = 0.00005,
    },
    {
        name = "lakehouse3",
        schematic = "lakehouse3_0_0.mts",
        biomes = {"lake"},
        anchor = "water",
        offset = 0,
        y_max = -0.5,
        y_min = -0.5,
        fill_ratio = 0.00005,
    },
    {
        name = "lakehouse4",
        schematic = "lakehouse4_0_0.mts",
        biomes = {"lake"},
        anchor = "water",
        offset = 0,
        y_max = -0.5,
        y_min = -0.5,
        fill_ratio = 0.00005,
    },
    {
        name = "lakefishtrap",
        schematic = "lakefishtrap_0_0.mts",
        biomes = {"lake", "swamp"},
        anchor = "water",
        offset = 0,
        y_max = -0.5,
        y_min = -0.5,
        fill_ratio = 0.00003,
    },
    {
        name = "lakeharbour",
        schematic = "lakeharbour_0_0.mts",
        biomes = {"lake", "swamp"},
        anchor = "water",
        offset = 0,
        y_max = -0.5,
        y_min = -0.5,
        fill_ratio = 0.00003,
    },
}

for _, def in ipairs(buildings) do
    nativevillages.placement.register_building(def)
end
