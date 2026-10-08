-- Soil adaptation layer for nativevillages.
-- The converted schematics carry a generic grass ground whatever the biome
-- they end up in (default:dirt_with_grass on the grassland family,
-- default:dry_dirt_with_dry_grass on the savanna family, cf. the schematics
-- audit in plans/proposition-sol-biomes.md), so a grassland house accepted
-- in snowy_grassland or an ethereal prairie keeps a green grass patch
-- inside a foreign landscape. This module resolves, for the real biome a
-- building is anchored in, the surface node the schematic ground should be
-- turned into, and builds the {source = target} table consumed by the 4th
-- argument (replacement) of minetest.place_schematic while the .mts is
-- decoded: no extra map write, no binary schematic rewritten.
-- The target is the node_top of the actual registered biome (third party
-- biome mods included), falling back to a declarative per-category table
-- mirroring ground_base of biomes.lua; when nothing resolves the sources
-- are left untouched. nativevillages.adapt_soil = false disables the whole
-- feature and restores the historical untouched placement.
-- Reference design: plans/proposition-sol-biomes.md

nativevillages = nativevillages or {}

local B = nativevillages.biomes

local S = {}
nativevillages.soil = S

-- Generic schematic ground nodes subject to replacement. Audit of the
-- schematics/*.mts node name headers: the grassland family carries
-- default:dirt_with_grass and the savanna family
-- default:dry_dirt_with_dry_grass as surface ground, while their 30-node
-- foundations are filled with default:dirt / default:dry_dirt (never
-- listed here: replacing the filler would raise full-height columns of
-- the target node). The desert (default:desert_sand) and ice
-- (default:snowblock) families are already biome consistent and use their
-- surface node as foundation filler too, so they stay untouched for the
-- same reason. The Mineclonia generic grass is listed for the day mcl_*
-- schematics are used (semantics of
-- schems/mineclonia_to_minetest_mapping.lua, offline library not loaded
-- in game: Mineclonia has a single generic grass node); the entry is
-- simply skipped when the node is not registered (minetest_game).
local sources = {
    "default:dirt_with_grass",
    "default:dry_dirt_with_dry_grass",
    "mcl_core:dirt_with_grass",
    -- possible phase 2 extension: low vegetation (default:grass_1, ...)
}

-- Declarative fallback per logical category, used ONLY when the node_top
-- of the real biome is missing, air or unregistered (mirrors ground_base
-- of biomes.lua, plus a few floor friendly variants)
local category_ground = {
    grassland = {"default:dirt_with_grass"},
    forest = {"default:dirt_with_grass"},
    jungle = {"default:dirt_with_rainforest_litter", "default:dirt_with_grass"},
    savanna = {"default:dry_dirt_with_dry_grass", "default:dirt_with_grass"},
    desert = {"default:desert_sand", "default:sand"},
    arctic = {"default:snowblock", "default:dirt_with_snow", "default:ice"},
    lake = {"default:sand", "default:dirt"},
    swamp = {"default:dirt", "default:dirt_with_grass"},
}

local enabled = minetest.settings:get_bool("nativevillages.adapt_soil", true)

-- Cache: biome name -> replacement table ready for place_schematic
-- (false caches the resolved "nothing to replace" answer, since Lua
-- tables cannot hold nil values)
local cache = {}

-- First registered, non air node of a list, nil when none resolves
local function first_known(list)
    for _, name in ipairs(list or {}) do
        if name and name ~= "air" and minetest.registered_nodes[name] then
            return name
        end
    end
    return nil
end

-- Target ground node of a real biome name, with fallbacks
function S.target(biome_name)
    -- 1) node_top of the actual registered biome: the exact answer,
    --    third party biome mods included (ethereal:prairie_dirt,
    --    default:dirt_with_snow, the default:sand of a *_ocean lake
    --    bed for the water anchored schematics, ...)
    local bdef = biome_name and minetest.registered_biomes[biome_name]
    local top = bdef and bdef.node_top
    if top and top ~= "air" and minetest.registered_nodes[top] then
        return top
    end
    -- 2) declarative fallback through the logical category of the biome
    local cat = B.category_of(biome_name)
    return first_known(category_ground[cat])
    -- 3) nil when nothing resolves: the sources stay untouched (safety)
end

-- Elect the biome whose ground will dress the schematic, from the votes
-- collected by placement.lua on the 3x3 grid of the real (rotated)
-- building footprint. Iteration 2 multi point sampling, reference design
-- plans/proposition-sol-biomes-echantillonnage.md section 4.8.
--   votes         ordered biome names, one per grid point; an unmeasurable
--                 point simply contributes no entry (nil vote ignored)
--   anchor_biome  biome of the centre column (historical anchor): wins
--                 every tie it is part of, ultimate fallback when no vote
--                 is exploitable (iteration 1 behaviour)
--   accepted_set  def.biome_set of the building, or nil for an open vote.
--                 Provided for water anchored buildings only: a lake
--                 building must never elect a land biome, whose node_top
--                 would put grass under water
-- Pure function (no engine call, no state): unit testable outside the
-- game. Returns the elected biome name, never nil when anchor_biome is
-- non nil.
function S.elect(votes, anchor_biome, accepted_set)
    local counts, order = {}, {}
    local best_n = 0
    for _, name in ipairs(votes) do
        -- valid vote: present name and, when a set is provided, biome
        -- inside that set; invalid votes count neither for nor against
        if name ~= nil and (accepted_set == nil or accepted_set[name]) then
            if counts[name] == nil then
                counts[name] = 0
                order[#order + 1] = name -- stable grid traversal order
            end
            counts[name] = counts[name] + 1
            if counts[name] > best_n then
                best_n = counts[name]
            end
        end
    end
    if best_n == 0 then
        return anchor_biome -- degenerate case, defensive guard
    end
    -- relative majority: the anchor wins any tie it is part of, otherwise
    -- the first tied name of the grid traversal (deterministic)
    local first_tied = nil
    for _, name in ipairs(order) do
        if counts[name] == best_n then
            if name == anchor_biome then
                return name
            end
            first_tied = first_tied or name
        end
    end
    return first_tied
end

-- Names of the generic ground nodes the schematics may carry
function S.source_names()
    return table.copy(sources)
end

-- {source = target} table for the 4th argument of place_schematic,
-- built once per encountered biome then cached. Returns nil when the
-- feature is disabled or nothing has to be replaced, which keeps the
-- historical untouched placement.
function S.replacement_for(biome_name)
    if not enabled or biome_name == nil then
        return nil
    end
    local cached = cache[biome_name]
    if cached ~= nil then
        return cached or nil
    end
    local repl, target = {}, S.target(biome_name)
    if target then
        for _, src in ipairs(sources) do
            if src ~= target and minetest.registered_nodes[src] then
                repl[src] = target
            end
        end
    end
    if next(repl) == nil then
        repl = nil -- nothing to replace: cache the negative answer too
    end
    cache[biome_name] = repl or false
    return repl
end

if not enabled then
    minetest.log("action", "[nativevillages] soil adaptation DISABLED by "
        .. "setting adapt_soil=false: schematic grounds left untouched")
end
