-- Data driven definitions of the cloudlands island buildings.
--
-- Unlike the other *buildings.lua files, these entries are NOT passed
-- to nativevillages.placement.register_building(): they are PRIVATE
-- templates, consumed exclusively by the deferred island flow of
-- cloudlands_support.lua (see its header for the rationale: the ground
-- test of placement.lua resolves the acceptable nodes of a drawing
-- from the category sets of the REGISTERED buildings only, and there
-- is no injection hook for an outside module; the island pool is
-- therefore a per island shallow copy whose ground_set is pre-filled
-- with the island ground ids). The templates never enter the global
-- registry, so the surface, dimension and historical decoration flows
-- of the engine can never draw them.
--
-- Category of an island (decided per island by cloudlands_support.lua):
--   * "cloudlands" on every eligible island -> the tents only, an
--     offset 0 drawing of the desert tent family that simply stands
--     on the island surface;
--   * "cloudlands_large" additionally on the deep and wide islands
--     (depth >= 28 and radius >= 20) -> the small houses of the 30
--     node foundation family (offset -4). Their foundation pillars
--     may pierce through the island underside on the shallow spots:
--     an assumed "pilotis" stilt effect for those large islands, the
--     very effect the historical _30_ schematics produce on cliffs.
--
-- The historical y_min/y_max bands of the cloned definitions are kept
-- for documentation only: the island flow replaces them with the
-- absolute window of the island (surface +/- SURFACE_BAND nodes,
-- through ctx.dim, exactly like a dimension fragment).
--
-- The registered names deliberately keep the historical family
-- prefixes (grassland..., desert...): spawn.lua resolves the
-- deterministic population of a placed building from them, so the
-- island tents spawn their desert traders and the island houses their
-- grassland inhabitants.

local buildings = {
    -- Tents on every island (clone of the desert tent entries of
    -- desertbuildings.lua, category changed)
    {
        name = "deserttent_cloudlands_1",
        schematic = "tent_big_1.mts",
        biomes = {"cloudlands"},
        anchor = "ground",
        offset = -4,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00005,
    },
    {
        name = "deserttent_cloudlands_2",
        schematic = "tent_big_2.mts",
        biomes = {"cloudlands"},
        anchor = "ground",
        offset = -4,
        y_max = 30.5,
        y_min = 25.5,
        fill_ratio = 0.00005,
    },
    -- Small foundation houses on the large deep islands only (clones
    -- of the grassland entries of grasslandbuildings.lua, category
    -- changed)
    {
        name = "grasslandhut_cloudlands",
        schematic = "hut_2.mts",
        biomes = {"cloudlands_large"},
        anchor = "ground",
        offset = -4,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
    {
        name = "grasslandsmall_house_cloudlands",
        schematic = "small_house_1_0.mts",
        biomes = {"cloudlands_large"},
        anchor = "ground",
        offset = -4,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
    {
        name = "grasslandhouse_cloudlands",
        schematic = "house_1_0.mts",
        biomes = {"cloudlands_large"},
        anchor = "ground",
        offset = -4,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
    {
        name = "grasslandlogcabin_cloudlands",
        schematic = "logcabin2.mts",
        biomes = {"cloudlands_large"},
        anchor = "ground",
        offset = -4,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
    {
        name = "grasslandtaverne_cloudlands",
        schematic = "taverne_2.mts",
        biomes = {"cloudlands_large"},
        anchor = "ground",
        offset = -4,
        y_max = 20.5,
        y_min = 15.5,
        fill_ratio = 0.00004,
    },
}

-- Private template list exposed to cloudlands_support.lua. The
-- categories field mirrors what P.register_building would build, the
-- schematic field carries the FULL path (register_building is the one
-- prefixing it on the registered buildings). The list stays empty
-- without the cloudlands mod: nothing would ever consume it
local CB = {list = {}}
nativevillages.cloudlands_buildings = CB

if minetest.get_modpath("cloudlands") then
    local modpath = minetest.get_modpath(
        minetest.get_current_modname())
    for _, def in ipairs(buildings) do
        def.categories = {}
        for _, cat in ipairs(def.biomes) do
            def.categories[cat] = true
        end
        def.schematic = modpath .. "/schematics/" .. def.schematic
        CB.list[#CB.list + 1] = def
    end
end
