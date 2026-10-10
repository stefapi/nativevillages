-- Furniture variation layer for nativevillages.
-- Every house of a family is placed from the same converted schematic,
-- so two neighbouring grasslandhouse1 carry the exact same barrel and
-- cow dropping and the village looks cloned. This module holds a per
-- family catalogue of decorative swaps ({furniture node = candidate
-- replacements}) and, given the site seeded PRNG the placement engine
-- builds for each house, draws the swaps that house receives. The
-- resulting table feeds the very {source = target} channel of
-- minetest.place_schematic (4th argument, node name substitution while
-- the .mts is decoded, param2 preserved) soil_replacement.lua uses for
-- the ground: no extra map write, no binary schematic rewritten.
-- Determinism: the PRNG comes from the caller, seeded on the site
-- footprint (PcgRandom(DECO_SEED, box.x1, box.y1, box.z1) in
-- placement.lua run_job), so a regenerated chunk (mapblock reset,
-- /deleteblocks) redraws the exact same furniture; the catalogue and
-- its candidate lists are ordered lists iterated through ipairs (never
-- pairs), so the draw sequence, hence the result, never depends on the
-- hash order of a Lua table. Every target is guarded by
-- minetest.registered_nodes (first_known pattern of
-- soil_replacement.lua): an entry whose targets are all unknown on the
-- running game (mobs:meatblock comes and goes with the mobs_animal
-- version) simply self skips. Only registered names containing "house"
-- vary: the civic structures (wells, markets, ponds, stables, logs,
-- pelts, harbours, sledges, cages, pits, towers, altars, shrines, fish
-- traps) keep their historical content. Beds, anvils and
-- nativevillages:driedpeople are never a source nor a target: the
-- deterministic population of spawn.lua scans the map AFTER placement,
-- so it follows the furniture actually present (a lake house whose
-- hanging fish became a fish trap becomes a fisher house: wanted
-- population variation), while the inhabitants of beds, anvils and
-- dried people stay guaranteed. The setting nativevillages.vary_deco
-- (read once at load by placement.lua) disables the whole feature and
-- restores the historical untouched placement.

nativevillages = nativevillages or {}

local D = {}
nativevillages.deco = D

-- Probability that ONE catalogue entry is drawn for ONE house: every
-- entry draws independently, so a family with two entries varies
-- roughly 44% of its houses at 0.25. Tune the constant here, the draw
-- itself stays deterministic per site
local SWAP_CHANCE = 0.25

-- Building family of a registered name, from its prefix: mirror of the
-- building_prefixes table of spawn.lua (which loads AFTER this file
-- per init.lua, the duplication keeps this module standalone); the
-- arctic family answers to both ice* and arctic* and the jungle family
-- to both jungle* and cannibal* (the jungle houses register as
-- junglehouse1-3 although their schematic FILES are named
-- cannibalhouse*), the very convention of dungeon_entrances.lua. The
-- prefixes are pairwise disjoint, so the pairs() traversal order below
-- cannot change the answer
local family_prefixes = {
    grassland = "grassland",
    desert = "desert",
    savanna = "savanna",
    lake = "lake",
    ice = "arctic",
    arctic = "arctic",
    jungle = "jungle",
    cannibal = "jungle",
}

local function family_of(name)
    for prefix, family in pairs(family_prefixes) do
        if name:sub(1, #prefix) == prefix then
            return family
        end
    end
    return nil
end

-- Per family catalogue, as ORDERED lists (ipairs only): the traversal
-- order is part of the deterministic contract above. Each drawn entry
-- swaps every occurrence of its source node inside the schematic for
-- one target drawn among the registered candidates. The sources are
-- the decorative trigger nodes of the *blocks.lua files; a target that
-- is itself a trigger node (nativevillages:fishtrap) re-targets the
-- deterministic population on purpose
local CATALOG = {
    grassland = {
        {source = "nativevillages:grasslandbarrel",
            targets = {"people:feeder", "default:chest"}},
        {source = "nativevillages:cowdropping",
            targets = {"farming:straw"}},
    },
    desert = {
        {source = "nativevillages:hookah",
            targets = {"nativevillages:desertseeds",
                "nativevillages:egg"}},
        {source = "nativevillages:desertcrpet",
            targets = {"carpets:sand", "wool:sand"}},
    },
    savanna = {
        {source = "nativevillages:savannavessels",
            targets = {"nativevillages:cheeseblock"}},
        {source = "nativevillages:savannathrone",
            targets = {"wool:red"}},
        {source = "nativevillages:savannacorpse",
            targets = {"mobs:meatblock"}}, -- guarded below: absent on
            -- many mobs_animal versions, the entry self skips
    },
    lake = {
        -- hangingfish -> fishtrap turns a villager house into a fisher
        -- house (nativevillages:fishtrap is a spawn trigger): wanted
        -- population variation, the populate scan of spawn.lua follows
        -- the final map
        {source = "nativevillages:hangingfish",
            targets = {"nativevillages:fishtrap", "default:chest"}},
    },
    arctic = {
        {source = "nativevillages:blanket",
            targets = {"wool:white", "wool:brown"}},
        {source = "nativevillages:sledge",
            targets = {"default:chest"}},
    },
    jungle = {}, -- phase 1: no swap designed yet, family kept explicit
}

-- {source = target} furniture table of one house, drawn from the site
-- seeded PRNG the caller built (placement.lua run_job). Returns a
-- freshly built table, possibly empty: no swap for this house (unknown
-- family, civic structure, or no draw passed the SWAP_CHANCE gate).
-- Pure beyond its PRNG consumption and the registered_nodes lookups:
-- unit testable outside the game with a stub rng
function D.replacement_for(job, rng)
    local out = {}
    if not job or not job.name or not rng then
        return out
    end
    -- only the houses vary: wells, markets, ponds, stables, logs,
    -- pelts, harbours, sledges, cages, pits, towers, altars, shrines
    -- and fish trap structures carry no "house" in their registered
    -- names and stay untouched
    if not job.name:find("house", 1, true) then
        return out
    end
    local catalog = CATALOG[family_of(job.name)]
    if not catalog then
        return out
    end
    for _, entry in ipairs(catalog) do
        if minetest.registered_nodes[entry.source]
            and rng:next(0, 10000) < SWAP_CHANCE * 10000 then
            -- registered candidates only, in declaration order
            local valid = {}
            for _, target in ipairs(entry.targets) do
                if minetest.registered_nodes[target] then
                    valid[#valid + 1] = target
                end
            end
            if valid[1] then
                out[entry.source] = valid[rng:next(1, #valid)]
            end
        end
    end
    return out
end
