-- Basements dug under the village houses -- multi level cellars opening
-- through a wooden trapdoor flush with the house floor: a 1x2 ladder
-- shaft (ladder column + headroom landing leaning on its own support
-- wall), pierced through the house floor AND every intermediate slab
-- by ONE cell only (the ladder column), dug levels with floor slabs,
-- wall torches, wood pillars and a few utility items per level.
--
-- Scope and guards (mirrors the dungeon_entrances.lua conventions):
--   * eligible houses ONLY: the house name prefixes (grasslandhouse,
--     deserthouse, savannahouse, icehouse, junglehouse and the defensive
--     cannibalhouse: the jungle houses register as junglehouse1-3
--     although their schematic files are named cannibalhouse*) -- every
--     house family of the *buildings.lua files now anchors at the
--     shallow offset = -4 (the _30_ tribal families and the imported
--     house_1_0/house_medieval_fancy/house_with_garden ones alike),
--     their embed leaves the dig to the natural ground below, and the
--     historical "_30_" schematic NAME test was retired on 2026-10-15
--     (it stole 27% of the placed house sites, see maybe_dig_basement);
--     the prefixes alone exclude every civic building, and the water
--     anchored lake houses a second time
--   * the "_cloudlands" buildings are REJECTED: a floating island has
--     nothing solid under the floor, while the multidimensions
--     buildings stay eligible (their deferred fragments place real
--     foundations, see dimension_support.lua)
--   * mutual exclusion with the hidden randungeon entrances
--     (dungeon_entrances.lua): the exact draw of THAT module is
--     replayed locally -- same world seed stream, same chance setting
--     read a second time (the dimension_support.lua precedent of
--     duplicating a setting read rather than widening an interface) --
--     and when the house carries a dungeon the basement gives up: a
--     house never carries both
--
-- Determinism: the draw stream is PcgRandom(BASE_SEED, box.x1, box.y1,
-- box.z1) with BASE_SEED = 0xBA5E4E7 + world seed (leetspeak of
-- "BASEMENT"; the M of the intended 0xBA5EME7 is not a hex digit, the
-- 4 stands in), a stream DISTINCT from DECO_SEED of placement.lua and
-- from the plain world seed stream of dungeon_entrances.lua: same
-- world = same basements, and a regenerated chunk (mapblock reset,
-- /deleteblocks) redraws the identical basements. The rng draws are
-- consumed in a fixed order: the chance draw, the hole scan origin
-- (x, z), the level count, then per level the item count, the
-- perimeter walk origin and one pool index per placed item.
--e
-- The dig itself, ONE VoxelManip for the whole cellar:
--   * n levels of LEVEL_H = 4 interior height, one floor slab under
--     each level, total depth n * (LEVEL_H + 1) <= MAX_DEPTH (15)
--     nodes, dug through the shallow schematic embed into the natural
--     ground below; the XZ footprint is the interior
--     rectangle of the house, margin 2 from the schematic walls (at
--     least 2 nodes of retained ground all around)
--   * the floor material follows the biome theme when one is known
--     (default:desert_sand under the desert houses), default:cobble
--     otherwise
--   * optional ceiling beams and corner pillars in default:wood (or
--     default:tree), skipped silently when no wood is registered
--   * water or lava met in the DUG VOLUME itself (the exact interior
--     rectangle the fill rewrites, not the 1 node read buffer ring
--     around it: a wet pocket behind a retained wall stays sealed and
--     must not abort an otherwise dry shaft) aborts the dig WITHOUT
--     any write: set_data is never called, the map keeps its
--     original nodes, the restore is implicit (+ a warning log)
--
-- The furniture (trapdoors, ladder, torches, utility items) is placed
-- with minetest.set_node AFTER write_to_map, every node guarded by
-- minetest.registered_nodes (silent fallback on partial installs: the
-- mod hard depends on default and doors, so the guards only cover
-- degenerate games). The utility pool also carries THIRD PARTY
-- supplies (cottages, xdecor, darkage, mobs_animal -- see
-- modded_items below): those mods are not all in mod.conf, which is
-- safe because the pool is resolved lazily inside dig_basement at
-- generation time, long after every mod has registered its nodes.
-- minetest.set_node never calls on_construct, so only nodes whose
-- inventories are optional decoration were retained (no drawers, no
-- hoppers -- their visuals/transfer logic would stay dead).

nativevillages = nativevillages or {}

local Bs = {}
nativevillages.basements = Bs

--
-- Settings (see settingtypes.txt), clamped to their documented bounds
-- (the setting_int pattern of village_zones.lua)
--

local function clamp(n, lo, hi)
    if n < lo then
        return lo
    end
    if n > hi then
        return hi
    end
    return n
end

local function setting_int(name, default, lo, hi)
    return clamp(tonumber(minetest.settings:get(name) or "") or default,
        lo, hi)
end

local enabled_setting = minetest.settings:get_bool(
    "nativevillages.basements", true)
local chance = clamp(tonumber(minetest.settings:get(
    "nativevillages.basement_chance") or "") or 0.35, 0.0, 1.0)
local levels_min = setting_int("nativevillages.basement_levels_min",
    1, 1, 3)
local levels_max = setting_int("nativevillages.basement_levels_max",
    3, 1, 8)
-- keep a sane range whatever the user typed
if levels_max < levels_min then
    levels_max = levels_min
end

--
-- Deterministic draw seeds
--

-- World seed, read once at load (village_zones.lua convention)
local WORLD_SEED = tonumber(minetest.get_mapgen_setting("seed") or "") or 0

-- Own stream seed, mixed with the world seed like DECO_SEED in
-- placement.lua (see the header for the leetspeak note)
local BASE_SEED = 0xBA5E4E7 + WORLD_SEED

--
-- randungeon replay settings, read a SECOND time locally (the
-- dimension_support.lua precedent: placement.lua and
-- dungeon_entrances.lua keep their locals, duplicating the read is
-- less invasive than widening their interfaces). Only the exact draw
-- of the hidden entrance is replayed, not the registry checks: a house
-- can exceptionally end up with neither a dungeon nor a basement when
-- the dungeon side was itself rejected later (too close, overlap)
--

local rd_installed = minetest.get_modpath("randungeon") ~= nil
local rd_enabled = minetest.settings:get_bool(
    "nativevillages.randungeon_entrances", true)
local rd_chance = clamp(tonumber(minetest.settings:get(
    "nativevillages.randungeon_entrance_chance") or "") or 0.2, 0.0, 1.0)

-- Registered names of the eligible houses (dungeon_entrances.lua
-- convention: the jungle houses register as junglehouse1-3 although
-- their schematic FILES are named cannibalhouse*)
local house_prefixes = {
    "grasslandhouse", "deserthouse", "savannahouse",
    "icehouse", "junglehouse", "cannibalhouse",
}

local function is_house(name)
    for _, prefix in ipairs(house_prefixes) do
        if name:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

--
-- Node predicates, conservative on unknown nodes like spawn.lua
--

local function is_walkable(name)
    if name == "ignore" then
        return false
    end
    local def = minetest.registered_nodes[name]
    return def ~= nil and def.walkable == true
end

-- Furniture / stair detector, the scan_floor_y filter: the eligible
-- houses carry stairs (stairs:stair_* to a loft, outdoor porch steps),
-- furnaces, chests, shelves, vessels and nativevillages display nodes
-- (hookah, shrines, barrels, vessels, carpets, throne, driedpeople,
-- blanket -- audited on every *_30_* schematic of the mod: no
-- nativevillages: node is ever a real floor material), all of them
-- WALKABLE nodes standing ON the floor. The historical walkable +
-- walkable-below + 2-open-above test elected such a piece of furniture
-- as the "floor" (F one node too high, then no standable spot at all:
-- the "no trapdoor spot" give-up of the desert and savanna houses). A
-- real floor is a stratum of cobble/desert_sand/wood, never one of
-- those names. The "door" group test covers doors:hidden and every
-- doors:trapdoor* hatch
local furniture_prefixes = {
    "stairs:", "default:furnace", "default:chest", "default:bookshelf",
    "vessels:", "nativevillages:",
    -- floor coverings of the regenerated _30_ schematics (wool carpets
    -- in the desert and ice houses, audited on the .mts files): a
    -- carpet is walkable and was elected as the "floor" ONE NODE TOO
    -- HIGH, so the fill pierced the REAL floor slab beside the
    -- trapdoor -- the reported open hole next to the hatch. A real
    -- floor never carries those prefixes; a carpeted column now
    -- elects nothing (the carpet is filtered, and the slab below it
    -- has no open node above), so the scan slides to a clear probe
    -- column of the +/-2 ring
    "wool:", "carpets:",
}

local function is_furniture_or_stair(name)
    for _, prefix in ipairs(furniture_prefixes) do
        if name:sub(1, #prefix) == prefix then
            return true
        end
    end
    local def = minetest.registered_nodes[name]
    return def ~= nil and def.groups ~= nil and (def.groups.door or 0) > 0
end

local function is_open(name)
    if name == "ignore" then
        return false
    end
    local def = minetest.registered_nodes[name]
    return def ~= nil and not def.walkable
end

-- Bed detector of the spawn layer (loaded before this module, see
-- init.lua), used by the floor scan to reject furniture
local Spawn = nativevillages.spawn

local function is_bed_node(name)
    return Spawn and Spawn.is_bed and Spawn.is_bed(name) or false
end

-- Trapdoor node of the shaft cover, resolved ONCE at load time with a
-- fallback chain: the historical "doors:trapdoor_wood" of Minetest
-- Game does not exist in every game running this mod (minetest_extended
-- registers "doors:trapdoor" and "doors:trapdoor_steel"), and the old
-- per-call registered_nodes guard was then always false -- the hole
-- was dug with NO trapdoor over it. The mod hard depends on doors, so
-- its nodes are registered before this file runs
local trapdoor_name = minetest.registered_nodes["doors:trapdoor_wood"]
    and "doors:trapdoor_wood"
    or (minetest.registered_nodes["doors:trapdoor"] and "doors:trapdoor"
        or (minetest.registered_nodes["doors:trapdoor_steel"]
            and "doors:trapdoor_steel" or nil))
local trapdoor_warned = false

--
-- Geometry constants
--

local LEVEL_H = 4       -- interior height of one level
local MAX_DEPTH = 15    -- total dig depth bound (n * (LEVEL_H + 1))
local MARGIN = 2        -- margin from the schematic walls
local SOLID_RATIO = 0.9 -- foundation integrity threshold
local FOUNDATION_OFFSET = -4 -- _30_ schematics anchor at -4 (shallow
                            -- embed, see the *buildings.lua data files)
local DOOR_CLEAR = 3    -- chebyshev clearance from any door column
local ROOF_SPAN = 12    -- roof search height above the floor (interior test)
local ROOF_MIN_RUN = 3  -- consecutive walkable nodes forming a real ceiling
local WALL_DIST = 3     -- wall search radius of the enclosed test
local ROOM_MAX_DIST = 5 -- relaxed wall radius for the widest rooms (span/2)

--
-- Scans
--

-- Real floor height of the house (clone of the scan_floor_y pattern of
-- dungeon_entrances.lua): first walkable node of the centre column,
-- scanning down around the schematic derived estimate, that has two
-- open nodes above (the interior) and a walkable node below (a floor
-- slab over the foundation: this rejects beds and chests standing on
-- the floor, which would otherwise be elected as the "floor"). The
-- candidate node AND the node below must both be plain structure (not
-- furniture: a furnace or stair standing on the floor passes the raw
-- walkable tests, and a stair laid ON the floor slab makes the node
-- below furniture too); when the centre column carries furniture all
-- the way down it is retried on the four neighbour columns (same
-- filter) before giving up
local function scan_floor_y(box, offset)
    local cx = math.floor((box.x1 + box.x2) / 2)
    local cz = math.floor((box.z1 + box.z2) / 2)
    local y0 = box.y1 - (offset or FOUNDATION_OFFSET)
    local columns = {
        {cx, cz},
        {cx - 1, cz}, {cx + 1, cz}, {cx, cz - 1}, {cx, cz + 1},
        -- the regenerated _30_ schematics lay carpets/wool and beds
        -- over the centre of some houses (the deserthouse4 centre
        -- column reads wool all the way down): widen the probe ring
        -- to +/-2 so a furnished centre no longer hides the floor
        {cx - 2, cz}, {cx + 2, cz}, {cx, cz - 2}, {cx, cz + 2},
    }
    for _, col in ipairs(columns) do
        local x, z = col[1], col[2]
        for y = y0 + 3, y0 - 5, -1 do
            local floor_name = minetest.get_node({x = x, y = y, z = z}).name
            local above_name = minetest.get_node({x = x, y = y + 1, z = z}).name
            if is_walkable(floor_name)
                and not is_furniture_or_stair(floor_name)
                and not is_furniture_or_stair(minetest.get_node(
                    {x = x, y = y - 1, z = z}).name)
                and not is_bed_node(floor_name)
                and not is_bed_node(above_name)
                and is_walkable(minetest.get_node({x = x, y = y - 1, z = z}).name)
                and is_open(above_name)
                and is_open(minetest.get_node({x = x, y = y + 2, z = z}).name) then
                return y
            end
        end
    end
    return nil
end

-- Door column detector: any footprint column carrying a door node at
-- F+1 or F+2. The name test is deliberately wide -- "door" matches
-- doors:door_* (both halves), doors:hidden (the "doors" prefix), the
-- xpanes:door_* gates and every doors:trapdoor* hatch -- because a
-- shaft, a trapdoor or a ladder flush with ANY of those is unusable.
-- The houses of this mod set their doors IN the wall plane, one to two
-- nodes INSIDE the schematic edges, so the plain margin of the window
-- below does NOT keep them out: measured on the real schematics
-- (grasslandhouse1_30_0: door column (2,z=3) of an 11x7 footprint),
-- the front-of-door floor cell satisfies walkable + 2 air and WAS
-- elected, digging the shaft at the doorstep (bug: "no trapdoor in
-- the room, the ladder ends at the door")
local function is_door_name(name)
    return name:find("door", 1, true) ~= nil
end

local function scan_door_columns(box, F)
    local cols = {}
    for x = box.x1, box.x2 do
        for z = box.z1, box.z2 do
            if is_door_name(minetest.get_node({x = x, y = F + 1, z = z}).name)
                or is_door_name(
                    minetest.get_node({x = x, y = F + 2, z = z}).name) then
                cols[#cols + 1] = {x = x, z = z}
            end
        end
    end
    return cols
end

-- Deterministic scan of a free 1x1 INTERIOR spot on the house floor
-- (the 1x1 variant of the scan_trap_hole pattern of
-- dungeon_entrances.lua: margin of 2 nodes from the schematic edges,
-- ordered walk starting from a PRNG drawn origin). A candidate column
-- must satisfy, on top of the historical walkable-floor + 2-open-above
-- + not-a-bed filter:
--   * four horizontal neighbours walkable at F AND open at F+1: the
--     candidate stands clear of the house walls (a wall column carries
--     wall nodes at F+1) and of the front-of-door cell (whose F+1
--     neighbour is the door panel itself) -- the real footprints bury
--     their walls one to two nodes inside the schematic edges, so the
--     margin alone never guaranteed interior cells
--   * a roof overhead: >= ROOF_MIN_RUN CONSECUTIVE walkable nodes in
--     the column between F+3 and F+ROOF_SPAN (bounded by box.y2) -- a
--     house ceiling is a continuous stratum while an isolated porch
--     step or garden stair (grasslandhouse3) is not, and outside
--     cells (open sky) are rejected all the same; results are cached
--     per column, the cache is a pure function of the column so the
--     determinism holds
--   * structurally enclosed: >= 2 of the 4 cardinal directions carry
--     a wall within WALL_DIST -- a wall is a column walkable from
--     F+1 to F+4 -- an interior cell of a room always qualifies, a
--     garden/porch cell almost never does; the centre of the widest
--     rooms of the schematics can sit past WALL_DIST of every wall,
--     so the relaxed fallback accepts a single wall within
--     ROOM_MAX_DIST
--   * chebyshev distance >= DOOR_CLEAR from every door column found by
--     scan_door_columns (doors, gates, hatches and their thresholds):
--     the shaft never opens at, in front of, or beside a door again
-- Five ordered passes over the SAME window and the SAME drawn origin,
-- strictest first (see pass_levels below): a roomy house still gets
-- its historical strict spot (8 standable neighbours, 3 node roof
-- run), a crowded hut degrades gracefully instead of losing its
-- basement. The regenerated 2026-10 _30_ schematics are small huts
-- whose ceilings/roofs are SINGLE node strata with furniture on every
-- floor cell: the historical two passes elected nothing on ANY of the
-- 19 eligible schematics (100% "no trapdoor spot" give-ups in game,
-- 2026-10-14). No rng is drawn inside the loops. Returns
-- {x =, z =, pass =}, or nil when nothing valid remains (the caller
-- gives up cleanly: a house without a safe spot keeps its plain floor
-- rather than a doorstep shaft)
local function scan_ladder_hole(prng, box, F)
    local ix1, ix2 = box.x1 + MARGIN, box.x2 - MARGIN
    local iz1, iz2 = box.z1 + MARGIN, box.z2 - MARGIN
    local span_x = ix2 - ix1 + 1
    local span_z = iz2 - iz1 + 1
    if span_x < 1 or span_z < 1 then
        return nil
    end
    local doors = scan_door_columns(box, F)
    local y_roof_max = math.min(F + ROOF_SPAN, box.y2)
    local roof_cache = {}
    local function roofed(hx, hz, min_run)
        local k = min_run .. "," .. hx .. "," .. hz
        local cached = roof_cache[k]
        if cached == nil then
            cached = false
            local run = 0
            for y = F + 3, y_roof_max do
                if is_walkable(
                        minetest.get_node({x = hx, y = y, z = hz}).name) then
                    run = run + 1
                    if run >= min_run then
                        cached = true
                        break
                    end
                else
                    run = 0
                end
            end
            roof_cache[k] = cached
        end
        return cached
    end
    local function standable(x, z)
        return is_walkable(minetest.get_node({x = x, y = F, z = z}).name)
            and is_open(minetest.get_node({x = x, y = F + 1, z = z}).name)
    end
    -- Interior test helpers: wall_within walks ONE cardinal direction
    -- from the candidate and answers whether a WALL stands within
    -- maxdist -- a wall column is walkable from F+1 to F+4 (a porch
    -- step, a fence post or a furniture piece is not). enclosed then
    -- counts the cardinal directions carrying such a wall: a room
    -- cell has walls on at least two close sides, a garden or porch
    -- cell has none so close; the centre of the widest rooms of the
    -- schematics sits past WALL_DIST of every wall, the relaxed
    -- fallback accepts there a single wall within ROOM_MAX_DIST
    local cardinals = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
    local function wall_within(hx, hz, dir, maxdist)
        for dist = 1, maxdist do
            local wx = hx + dir[1] * dist
            local wz = hz + dir[2] * dist
            local wall = true
            for y = F + 1, F + 4 do
                if not is_walkable(
                        minetest.get_node({x = wx, y = y, z = wz}).name) then
                    wall = false
                    break
                end
            end
            if wall then
                return true
            end
        end
        return false
    end
    local function enclosed(hx, hz)
        local near, any = 0, 0
        for _, dir in ipairs(cardinals) do
            if wall_within(hx, hz, dir, WALL_DIST) then
                near = near + 1
                any = any + 1
            elseif wall_within(hx, hz, dir, ROOM_MAX_DIST) then
                any = any + 1
            end
        end
        return near >= 2 or any >= 1
    end
    -- Graded relaxation ladder, strictest first (see the header note):
    -- P1/P2 are the historical passes, P3 accepts the single node
    -- ceiling strata of the new schematics, P4 drops the enclosure
    -- test (open plan lofts), P5 is the last resort (floor + 2 open +
    -- door clearance only). The door clearance also relaxes from 3 to
    -- 2 at P3: the new huts are 8-12 nodes wide, DOOR_CLEAR 3 next to
    -- an in-wall door blanks the whole window
    local pass_levels = {
        {neigh = "all8", run = ROOF_MIN_RUN, enc = true,  dc = DOOR_CLEAR},
        {neigh = "all4", run = ROOF_MIN_RUN, enc = true,  dc = DOOR_CLEAR},
        {neigh = "one",  run = 1,            enc = true,  dc = 2},
        {neigh = "one",  run = 1,            enc = false, dc = 2},
        {neigh = "none", run = 0,            enc = false, dc = 2},
    }
    local function valid(hx, hz, lvl)
        local floor_name = minetest.get_node({x = hx, y = F, z = hz}).name
        if not is_walkable(floor_name) or is_bed_node(floor_name)
            or not is_open(minetest.get_node({x = hx, y = F + 1, z = hz}).name)
            or not is_open(minetest.get_node({x = hx, y = F + 2, z = hz}).name) then
            return false
        end
        if lvl.neigh == "all8" or lvl.neigh == "all4" then
            if not standable(hx - 1, hz) or not standable(hx + 1, hz)
                or not standable(hx, hz - 1) or not standable(hx, hz + 1) then
                return false
            end
        elseif lvl.neigh == "one" then
            if not (standable(hx - 1, hz) or standable(hx + 1, hz)
                or standable(hx, hz - 1) or standable(hx, hz + 1)) then
                return false
            end
        end
        if lvl.run >= 1 and not roofed(hx, hz, lvl.run) then
            return false
        end
        if lvl.enc and not enclosed(hx, hz) then
            return false
        end
        for _, d in ipairs(doors) do
            if math.max(math.abs(hx - d.x), math.abs(hz - d.z))
                < lvl.dc then
                return false
            end
        end
        if lvl.neigh == "all8" then
            for dx = -1, 1 do
                for dz = -1, 1 do
                    if (dx ~= 0 or dz ~= 0)
                        and not standable(hx + dx, hz + dz) then
                        return false
                    end
                end
            end
        end
        return true
    end
    local sx = prng:next(0, span_x - 1)
    local sz = prng:next(0, span_z - 1)
    for pass, lvl in ipairs(pass_levels) do
        for dz = 0, span_z - 1 do
            for dx = 0, span_x - 1 do
                local hx = ix1 + (sx + dx) % span_x
                local hz = iz1 + (sz + dz) % span_z
                if valid(hx, hz, lvl) then
                    return {x = hx, z = hz, pass = pass}
                end
            end
        end
    end
    return nil
end

-- Foundation integrity guard: samples the columns of the interior
-- every 2 nodes, from F-2 down to F-25, and gives up when less than
-- 90% of the sampled nodes are solid -- a house on stilts (or above a
-- cave) has no ground to dig into. F-25 covers the MAX_DEPTH = 15 dig
-- plus a 10 node margin: with the shallow -4 embeds the dig reaches
-- BELOW the schematic into natural ground, which is exactly what must
-- be probed (the historical box.y1 + 2 clamp only made sense with the
-- 30 node foundations). "ignore" counts as non solid: un-emerged
-- pockets abort safely
local function foundation_solid(box, F)
    local ix1, ix2 = box.x1 + MARGIN, box.x2 - MARGIN
    local iz1, iz2 = box.z1 + MARGIN, box.z2 - MARGIN
    local y_lo = F - 25
    local total, solid = 0, 0
    for x = ix1, ix2, 2 do
        for z = iz1, iz2, 2 do
            for y = F - 2, y_lo, -1 do
                total = total + 1
                if is_walkable(minetest.get_node({x = x, y = y, z = z}).name) then
                    solid = solid + 1
                end
            end
        end
    end
    if total == 0 then
        return false
    end
    return solid / total >= SOLID_RATIO
end

--
-- Liquid detection on raw content ids (the VM buffer only carries
-- ids): the name is resolved once per unknown id, then cached. A node
-- is a liquid when the game says so (a positive liquid group) or when
-- its name says water or lava (third party liquids that forgot the
-- group)
--

local liquid_ids = {}

local function is_liquid_id(id)
    local cached = liquid_ids[id]
    if cached ~= nil then
        return cached
    end
    local name = minetest.get_name_from_content_id(id)
    local def = minetest.registered_nodes[name]
    local is_liq = false
    if def and def.groups and (def.groups.liquid or 0) > 0 then
        is_liq = true
    elseif name:find("water", 1, true) or name:find("lava", 1, true) then
        is_liq = true
    end
    liquid_ids[id] = is_liq
    return is_liq
end

--
-- Perimeter helpers
--

-- Ordered perimeter ring of the interior (deterministic ipairs order):
-- the two X edges full length, then the two Z edges without their
-- corners (already listed)
local function build_ring(ix1, ix2, iz1, iz2)
    local ring = {}
    for x = ix1, ix2 do
        ring[#ring + 1] = {x = x, z = iz1}
    end
    for x = ix1, ix2 do
        ring[#ring + 1] = {x = x, z = iz2}
    end
    for z = iz1 + 1, iz2 - 1 do
        ring[#ring + 1] = {x = ix1, z = z}
    end
    for z = iz1 + 1, iz2 - 1 do
        ring[#ring + 1] = {x = ix2, z = z}
    end
    return ring
end

-- wallmounted of a wall fixture at a perimeter cell: param2 carries
-- the direction of the SUPPORT wall (canonical values: 0=y+, 1=y-,
-- 2=x+, 3=x-, 4=z+, 5=z-), the retained ground just outside the
-- interior rectangle
local function ring_wallmounted(cell, ix1, ix2, iz1)
    if cell.x == ix1 then
        return 3 -- support wall at x- (wallmounted 3 = x-)
    elseif cell.x == ix2 then
        return 2 -- support wall at x+ (wallmounted 2 = x+)
    elseif cell.z == iz1 then
        return 5 -- support wall at z- (wallmounted 5 = z-)
    end
    return 4 -- support wall at z+ (wallmounted 4 = z+)
end

-- facedir turning the FRONT of a node towards the interior:
-- facedir_to_dir() gives the BACK of the node, the front is the
-- opposite direction (facedir 0 -> front z-, 1 -> front x-,
-- 2 -> front z+, 3 -> front x+)
local function ring_facedir(cell, ix1, ix2, iz1)
    if cell.x == ix1 then
        return 3 -- front towards +X (into the room)
    elseif cell.x == ix2 then
        return 1 -- front towards -X (into the room)
    elseif cell.z == iz1 then
        return 2 -- front towards +Z (into the room)
    end
    return 0 -- front towards -Z (into the room)
end


--
-- Utility items catalogue. Every entry is guarded by
-- minetest.registered_nodes at placement time and the lists are walked
-- with ipairs ONLY: the order is part of the deterministic contract.
-- The biome category comes from the registered name prefix of the job
-- (the building_biome convention of spawn.lua: grasslandhouse ->
-- grassland, icehouse -> arctic, junglehouse/cannibalhouse -> jungle,
-- ...)
--

local theme_items = {
    grassland = {
        "nativevillages:grasslandbarrel",
        "nativevillages:grasslandaltar",
    },
    desert = {
        "nativevillages:hookah",
    },
    savanna = {
        "nativevillages:savannavessels",
    },
    lake = {
        "nativevillages:fishtrap",
    },
    arctic = {
        "nativevillages:sledge",
    },
    jungle = {
        "nativevillages:driedpeople",
    },
}

-- Generic pool, every theme: storage, shaping/cooking, repair (the
-- optional anvil mod is dropped silently by its guard), building/deco
local generic_items = {
    "default:chest",
    "default:chest_locked",
    "default:furnace",
    "default:bookshelf",
    "wool:white",
    "wool:grey",
    "wool:black",
    "wool:brown",
    "anvil:anvil",
}

-- Third party supplies (cottages and friends), appended to the pool
-- ONLY when at least one entry is actually registered: the weights
-- keep the native furniture (theme + generic) the MAJORITY, see the
-- doubling in dig_basement. Every name was verified against the
-- register_node/xdecor.register calls of the installed mods; the
-- candidates REJECTED on purpose: cottages:oven and cottages:chest_stub
-- (not registered by this cottages version), drawers:* (drawer
-- visuals and inventory live in on_construct, never called by
-- minetest.set_node), hopper:* (the spout would sink into the floor)
-- and cottages:wagon_wheel (wallmounted, incompatible with the
-- facedir ring placement). Order is part of the deterministic
-- contract: ipairs only, grouped by mod.
local modded_items = {
    -- cottages (hard dependency, guarded anyway for partial installs):
    -- storage shelf + NPC chests + barrel, handmill, anvil, bench, table
    "cottages:shelf",
    "cottages:chest_private",
    "cottages:chest_work",
    "cottages:chest_storage",
    "cottages:barrel",
    "cottages:handmill",
    "cottages:anvil",
    "cottages:bench",
    "cottages:table",
    -- xdecor (optional): cabinet + multishelf storage, workbench
    -- (crafting + tool repair), cauldron
    "xdecor:cabinet",
    "xdecor:multishelf",
    "xdecor:workbench",
    "xdecor:cauldron_empty",
    -- darkage (optional): box + wooden shelves
    "darkage:box",
    "darkage:wood_shelves",
    -- mobs_animal (optional): food reserves for the cellar
    "mobs:cheeseblock",
    "mobs:honey_block",
}

--
-- Core dig. opts = { levels = n, rng = PcgRandom, floor_y = F,
-- hole = {x =, z =} }: everything maybe_dig_basement resolved. Returns
-- true when the cellar was written to the map, false/nil on any give
-- up (always with a log); the caller never retries.
--

function Bs.dig_basement(job, opts)
    opts = opts or {}
    local box = job and job.box
    local rng = opts.rng
    local floor_y = tonumber(opts.floor_y)
    local hole = opts.hole
    if not box or not rng or not floor_y
        or not hole or not hole.x or not hole.z then
        minetest.log("warning", "[nativevillages] basement dig: invalid "
            .. "arguments, giving up")
        return false
    end
    local jname = tostring(job.name or "building")

    -- level count, clamped by the dig depth bound: n * (LEVEL_H + 1)
    -- must stay <= MAX_DEPTH. The historical box.y1 + 2 clamp assumed
    -- a 30 node foundation and kept the dig inside the schematic's own
    -- ground; the shallow -4 embeds rewrote that contract (see the
    -- *buildings.lua data files), the dig now continues into the
    -- NATURAL terrain below the schematic and foundation_solid()
    -- already guarantees that ground is real and continuous
    local n = math.floor(tonumber(opts.levels) or 1)
    if n < 1 then
        n = 1
    end
    local max_by_depth = math.floor(MAX_DEPTH / (LEVEL_H + 1))
    if n > max_by_depth then
        n = max_by_depth
    end

    -- interior footprint, margin 2 from the schematic walls
    local ix1, ix2 = box.x1 + MARGIN, box.x2 - MARGIN
    local iz1, iz2 = box.z1 + MARGIN, box.z2 - MARGIN
    if ix2 < ix1 or iz2 < iz1 then
        minetest.log("action", "[nativevillages] basement given up for "
            .. jname .. ": interior too small")
        return false
    end
    local y_bot = floor_y - n * (LEVEL_H + 1)

    -- level geometry: the interior rows of level k run from
    --   floor_y - (k-1)*(LEVEL_H+1) - 1   (ceiling, under the slab above)
    -- down to
    --   floor_y - (k-1)*(LEVEL_H+1) - LEVEL_H
    -- and its floor slab row is floor_y - k*(LEVEL_H+1); y_bot is the
    -- slab row of the bottom level n
    local slab_row, ceiling_row = {}, {}
    for k = 1, n do
        slab_row[floor_y - k * (LEVEL_H + 1)] = true
        ceiling_row[floor_y - (k - 1) * (LEVEL_H + 1) - 1] = true
    end

    -- materials
    local c_air = minetest.get_content_id("air")
    local floor_name = "default:cobble"
    if type(job.biome_name) == "string"
        and job.biome_name:find("desert", 1, true)
        and minetest.registered_nodes["default:desert_sand"] then
        floor_name = "default:desert_sand"
    end
    local c_floor = minetest.get_content_id(floor_name)
    local c_wood = nil
    if minetest.registered_nodes["default:wood"] then
        c_wood = minetest.get_content_id("default:wood")
    elseif minetest.registered_nodes["default:tree"] then
        c_wood = minetest.get_content_id("default:tree")
    end

    -- ONE VoxelManip over the basement AABB enlarged by 1 node
    local vm = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map(
        {x = ix1 - 1, y = y_bot - 1, z = iz1 - 1},
        {x = ix2 + 1, y = floor_y, z = iz2 + 1})
    local va = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()

    -- liquid guard over the DUG VOLUME itself (the exact interior
    -- rectangle the fill below rewrites), NOT over the 1 node read
    -- buffer ring around it: a wet pocket behind a retained wall
    -- stays sealed and must not abort an otherwise dry shaft. Give up
    -- before any write, the restore is implicit (set_data was never
    -- called, the map keeps its original nodes)
    for vi in va:iterp({x = ix1, y = y_bot, z = iz1},
        {x = ix2, y = floor_y - 1, z = iz2}) do
        if is_liquid_id(data[vi]) then
            local p = va:position(vi)
            minetest.log("warning", "[nativevillages] basement given up "
                .. "for " .. jname .. ": liquid found in the dig area at ("
                .. p.x .. "," .. p.y .. "," .. p.z .. "), nothing written")
            return false
        end
    end

    -- ladder cell: the neighbour of the shaft towards the NEAREST
    -- interior wall (ties broken in the fixed x-, x+, z-, z+ order),
    -- skipping the directions that would step out of the interior (a
    -- shaft flush against a wall); the cell BEYOND the ladder is its
    -- load bearing wall: the fill below writes it in floor material
    -- when it falls inside the interior, and it is the retained
    -- foundation when already outside -- the ladder never floats
    local cand = {
        -- wm = wallmounted of the support wall the ladder leans on
        -- (canonical: 2=x+, 3=x-, 4=z+, 5=z-); order keeps the
        -- documented x-, x+, z-, z+ tie break in the sort below
        {wm = 3, dx = -1, dz = 0, d = hole.x - ix1, order = 1},
        {wm = 2, dx = 1, dz = 0, d = ix2 - hole.x, order = 2},
        {wm = 5, dx = 0, dz = -1, d = hole.z - iz1, order = 3},
        {wm = 4, dx = 0, dz = 1, d = iz2 - hole.z, order = 4},
    }
    table.sort(cand, function(a, b)
        if a.d ~= b.d then
            return a.d < b.d
        end
        return a.order < b.order
    end)
    local ladder, ladder_wm, support = nil, nil, nil
    for _, c in ipairs(cand) do
        local lx, lz = hole.x + c.dx, hole.z + c.dz
        if lx >= ix1 and lx <= ix2 and lz >= iz1 and lz <= iz2 then
            ladder = {x = lx, z = lz}
            ladder_wm = c.wm
            support = {x = lx + c.dx, z = lz + c.dz}
            break
        end
    end
    if not ladder then
        minetest.log("action", "[nativevillages] basement given up for "
            .. jname .. ": no cell beside the shaft for the ladder "
            .. "(1x1 interior), nothing written")
        return false
    end

    -- degraded mode without any registered trapdoor node (a degenerate
    -- game without a single doors:trapdoor*): the headroom column is
    -- NOT pierced in the fill below -- its slab rows are written like
    -- any plain column, so no 1x2 hole ever opens in the house floor
    -- or the intermediate slabs; the cellar stays sealed under its
    -- intact floor (a player digging through later finds the ladder
    -- and the levels). One warning per session
    if not trapdoor_name and not trapdoor_warned then
        trapdoor_warned = true
        minetest.log("warning", "[nativevillages] no trapdoor node "
            .. "available, the basement shafts stay closed")
    end

    -- fill: interior air, slab rows in the floor material, optional
    -- ceiling beams and corner pillars in wood. The shaft pierces
    -- EVERY slab by ONE cell only, the LADDER column (it carries
    -- every rung and trapdoor in its own axis, one single descent
    -- line like the house floor hatch): at each slab row the fill
    -- writes the floor material back into the headroom column (hole),
    -- so the intermediate crossings are 1 cell wide like the house
    -- floor -- between the slabs the 1x2 shaft stays open (the
    -- headroom is the landing at the top of the ladder of each
    -- level). In the degraded mode above (no trapdoor node) the
    -- headroom column leaves the shaft entirely and keeps whole
    -- slabs; only the bottom slab stays whole under the shaft (it is
    -- the walking floor of the last level). The support column is
    -- solid floor material from y_bot to floor_y - 1: the wall the
    -- ladder leans on. The y argument is optional: nil (the torch
    -- and item ring guards below) excludes BOTH shaft columns, a slab
    -- row y excludes the ladder column only (the headroom cell is
    -- then filled by the slab_row branch)
    local function is_shaft(x, z, y)
        if x == ladder.x and z == ladder.z then
            return true
        end
        if trapdoor_name == nil or x ~= hole.x or z ~= hole.z then
            return false
        end
        return y == nil or not slab_row[y]
    end
    local width = ix2 - ix1 + 1
    local depth = iz2 - iz1 + 1
    local pillars = c_wood and (width > 7 or depth > 7)
    local beams_along_x = width >= depth
    for z = iz1, iz2 do
        for y = y_bot, floor_y - 1 do
            for x = ix1, ix2 do
                local vi = va:index(x, y, z)
                if x == support.x and z == support.z then
                    data[vi] = c_floor
                elseif is_shaft(x, z, y) then
                    if y == y_bot then
                        data[vi] = c_floor
                    else
                        data[vi] = c_air
                    end
                elseif slab_row[y] then
                    data[vi] = c_floor
                elseif c_wood and ceiling_row[y] and (
                    (beams_along_x and (z - iz1) % 5 == 0)
                    or (not beams_along_x and (x - ix1) % 5 == 0)) then
                    data[vi] = c_wood
                elseif c_wood and pillars
                    and (x == ix1 or x == ix2)
                    and (z == iz1 or z == iz2) then
                    data[vi] = c_wood
                else
                    data[vi] = c_air
                end
            end
        end
    end
    -- commit the dug volume: set_data takes the WHOLE buffer array as
    -- its single argument (the nether/worldedit canonical sequence --
    -- set_data(index, id) with two arguments does not exist in the API
    -- and is silently ignored by the engine, which once left the
    -- cellar undug while the set_node furniture persisted); its true
    -- argument of write_to_map orders the lighting update, and run_job
    -- also runs from the DEFERRED emerge callbacks of dispatch_job
    -- where nothing else would relight the written mapblocks)
    vm:set_data(data)
    vm:write_to_map(true)

    -- 1. floor re-close: the shaft pierces the house floor through
    --    ONE cell only, the LADDER column -- the hatch and the
    --    climbing column share the same cell, one single descent axis
    --    (the historical hatch one step aside was the reported
    --    misalignment: a hole next to the ladder, and a second almost
    --    redundant rung column under it). The old hatch cell (the
    --    shaft headroom, hole) is defensively re-closed at floor_y
    --    whenever the node there is not a walkable floor (a residual
    --    mis-calibration of floor_y would otherwise leave an open
    --    hole beside the hatch): the refill takes the first plain
    --    floor node read around it (fixed x-, x+, z-, z+, diagonals
    --    order, the ladder cell skipped -- it is about to carry the
    --    hatch rung), falling back to the theme floor material. With a
    --    correctly calibrated floor_y the cell already carries the
    --    house floor and nothing is written
    local function nearby_floor_name()
        local dirs = {{-1, 0}, {1, 0}, {0, -1}, {0, 1},
            {-1, -1}, {1, 1}}
        for _, d in ipairs(dirs) do
            local px, pz = hole.x + d[1], hole.z + d[2]
            if not (px == ladder.x and pz == ladder.z) then
                local fname = minetest.get_node(
                    {x = px, y = floor_y, z = pz}).name
                if is_walkable(fname) and not is_furniture_or_stair(fname)
                    and not is_bed_node(fname) then
                    return fname
                end
            end
        end
        return floor_name
    end
    if not is_walkable(minetest.get_node(
            {x = hole.x, y = floor_y, z = hole.z}).name) then
        minetest.set_node({x = hole.x, y = floor_y, z = hole.z},
            {name = nearby_floor_name()})
    end

    -- 2. trapdoors, ATTACHED to the TOP of each hole: the ladder
    --    cell keeps a full RUNG inside the hole itself (continuity
    --    with the rung column below -- the hole stays exactly ONE
    --    trapdoor wide, it is NOT enlarged) and the plate stands OPEN
    --    one cell ABOVE the hole, vertical and flush against the
    --    SUPPORT wall: the descent axis stays directly passable, one
    --    click folds the plate flat over the hole to close it. Every
    --    intermediate slab crossing repeats the same motif (rung in
    --    the slab row, open plate right above it) and the headroom
    --    cell (hole) beside it carries the slab material written by
    --    the fill above -- each crossing is ONE cell wide, like the
    --    house floor hatch. The load time resolved trapdoor_name is
    --    paramtype2
    --    "facedir" in the doors mod of this install
    --    (doors.register_trapdoor hardcodes it): CLOSED the nodebox
    --    is a flat horizontal plate whatever param2, and OPEN the
    --    plate swings up against the facedir_to_dir(param2) side of
    --    the node. param2 is therefore aimed at the SUPPORT wall:
    --    wm_to_facedir maps the support direction (the side the
    --    ladder leans on, always solid by the fill above) to the
    --    facedir of the same world side, so every open plate stands
    --    flush against the bearing wall and the headroom side stays
    --    fully clear -- aiming the plate at the headroom would wall
    --    the landing off (the walking axis headroom <-> hatch runs
    --    through it), a side flap would half block it, and the
    --    bearing wall is the only edge guaranteed solid. param2 = 0
    --    stays the safe flat fallback for a wallmounted trapdoor of
    --    another game (0 = +Y lays it horizontally there)
    local trapdoor_p2 = 0
    local td_def = trapdoor_name
        and minetest.registered_nodes[trapdoor_name] or nil
    if td_def and td_def.paramtype2 == "facedir" then
        local wm_to_facedir = {
            [2] = 1, -- support wall at x+ -> plate stands against +X
            [3] = 3, -- x- -> -X
            [4] = 0, -- z+ -> +Z
            [5] = 2, -- z- -> -Z
        }
        trapdoor_p2 = wm_to_facedir[ladder_wm] or 0
    end
    -- the OPEN state of a doors trapdoor is the registered
    -- "<name>_open" node (doors.register_trapdoor registers both
    -- states); resolved defensively, and each open plate is only
    -- written over a FREE cell (air or buildable_to): a schematic
    -- wall or furniture above a hole keeps its node and that hatch
    -- falls back to the historical flat plate IN the hole
    local trapdoor_open_name = trapdoor_name
        and minetest.registered_nodes[trapdoor_name .. "_open"]
        and (trapdoor_name .. "_open") or nil
    local function hatch_cell_free(p)
        local name = minetest.get_node(p).name
        if name == "air" then
            return true
        end
        if name == "ignore" then
            return false
        end
        local def = minetest.registered_nodes[name]
        return def ~= nil and def.buildable_to == true
    end
    -- ladder column cells owned by a plate: the OPEN plates below
    -- replace the rung one cell above each hole -- climbable nodes,
    -- the ascent stays continuous -- and the flat FALLBACK plates
    -- sit inside the holes themselves, so step 3 writes no rung on
    -- those cells
    local no_rung_y = {}
    local hatch_desc = "no trapdoor, sealed shaft"
    if trapdoor_name then
        -- floor hatch: rung in the hole, open plate above it
        -- against the bearing wall
        if trapdoor_open_name and hatch_cell_free(
                {x = ladder.x, y = floor_y + 1, z = ladder.z}) then
            minetest.set_node({x = ladder.x, y = floor_y + 1,
                z = ladder.z},
                {name = trapdoor_open_name, param2 = trapdoor_p2})
            no_rung_y[floor_y + 1] = true
            hatch_desc = "ladder in hatch, open trapdoor above"
        else
            minetest.set_node({x = ladder.x, y = floor_y, z = ladder.z},
                {name = trapdoor_name, param2 = trapdoor_p2})
            no_rung_y[floor_y] = true
            hatch_desc = "flat plate in hatch (fallback)"
        end
        -- intermediate slab crossings: the same motif
        for k = 1, n - 1 do
            local y = floor_y - k * (LEVEL_H + 1)
            if trapdoor_open_name and hatch_cell_free(
                    {x = ladder.x, y = y + 1, z = ladder.z}) then
                minetest.set_node({x = ladder.x, y = y + 1, z = ladder.z},
                    {name = trapdoor_open_name, param2 = trapdoor_p2})
                no_rung_y[y + 1] = true
            else
                minetest.set_node({x = ladder.x, y = y, z = ladder.z},
                    {name = trapdoor_name, param2 = trapdoor_p2})
                no_rung_y[y] = true
            end
        end
    end

    -- 3. ladders: CONTINUOUS on the ladder column from the walking
    --    floor of the bottom level up to floor_y INCLUSIVE -- the
    --    top rung sits INSIDE the floor hatch of the SAME cell,
    --    welded to the column below and to the open plate above it,
    --    a single straight climb out of the cellar -- leaning on the
    --    support wall (ladder_wm faces it). no_rung_y (step 2) holds
    --    the cells a plate owns: the OPEN plates replace the rung
    --    one cell above each hole (climbable, the ascent stays
    --    continuous) and the flat FALLBACK plates lie inside the
    --    holes, every slab crossing keeping one rung right below the
    --    hole -- and, in the open mode, one inside it. Without any
    --    trapdoor node (degraded mode) the rungs stay continuous
    --    through the slabs instead and the house floor cell keeps
    --    its sealed floor node -- the headroom column keeps whole
    --    slabs there, a rung inside it would float unseen
    if minetest.registered_nodes["default:ladder_wood"] then
        if not trapdoor_name then
            no_rung_y[floor_y] = true -- degraded: floor stays sealed
        end
        for y = y_bot + 1, floor_y do
            if not no_rung_y[y] then
                minetest.set_node({x = ladder.x, y = y, z = ladder.z},
                    {name = "default:ladder_wood", param2 = ladder_wm})
            end
        end
    end

    -- 4. lighting: one wall torch every ~5 nodes along the perimeter
    --    ring of each level (fixed stride, no rng draw), only on free
    --    air cells with the retained wall behind them
    local ring = build_ring(ix1, ix2, iz1, iz2)
    if minetest.registered_nodes["default:torch_wall"] then
        for k = 1, n do
            local y = floor_y - k * (LEVEL_H + 1) + 2 -- waist height
            for i, cell in ipairs(ring) do
                if i % 5 == 2 and not is_shaft(cell.x, cell.z) then
                    local p = {x = cell.x, y = y, z = cell.z}
                    if minetest.get_node(p).name == "air" then
                        minetest.set_node(p, {name = "default:torch_wall",
                            param2 = ring_wallmounted(cell, ix1, ix2, iz1)})
                    end
                end
            end
        end
    end

    -- 5. utility items, 2-5 per level drawn from the theme ∪ generic
    --    pool: free cells of the perimeter ring (never the ladder
    --    shaft), flush against the walls, front turned towards the
    --    interior; the ordered walk starts from a drawn origin
    local pool = {}
    local category = Spawn and Spawn.building_biome
        and Spawn.building_biome(jname) or nil
    for _, name in ipairs(theme_items[category or ""] or {}) do
        if minetest.registered_nodes[name] then
            pool[#pool + 1] = name
        end
    end
    for _, name in ipairs(generic_items) do
        if minetest.registered_nodes[name] then
            pool[#pool + 1] = name
        end
    end
    -- third party enrichment, weighted: when at least one modded
    -- supply is registered, the native part (theme + generic, already
    -- resolved above) is DOUBLED once before the modded entries join,
    -- so the nativevillages/default furniture keeps the majority
    -- (>= 2 * 10 native slots vs <= 17 modded ones on a full install)
    local extra = {}
    for _, name in ipairs(modded_items) do
        if minetest.registered_nodes[name] then
            extra[#extra + 1] = name
        end
    end
    if #extra > 0 then
        local native_count = #pool
        for i = 1, native_count do
            pool[#pool + 1] = pool[i]
        end
        for _, name in ipairs(extra) do
            pool[#pool + 1] = name
        end
    end
    if #pool > 0 and #ring > 0 then
        for k = 1, n do
            local fy = floor_y - k * (LEVEL_H + 1) -- slab row: item floor
            local count = rng:next(2, 5)
            local start = rng:next(0, #ring - 1)
            for j = 0, #ring - 1 do
                if count <= 0 then
                    break
                end
                local cell = ring[1 + (start + j) % #ring]
                if not is_shaft(cell.x, cell.z) then
                    local p = {x = cell.x, y = fy + 1, z = cell.z}
                    if minetest.get_node(p).name == "air"
                        and minetest.get_node(
                            {x = p.x, y = p.y + 1, z = p.z}).name == "air"
                        and is_walkable(minetest.get_node(
                            {x = p.x, y = fy, z = p.z}).name) then
                        minetest.set_node(p,
                            {name = pool[rng:next(1, #pool)],
                             param2 = ring_facedir(cell, ix1, ix2, iz1)})
                        count = count - 1
                    end
                end
            end
        end
    end

    minetest.log("action", "[nativevillages] basement dug under " .. jname
        .. " at (" .. tostring(job.pos and job.pos.x) .. ","
        .. tostring(job.pos and job.pos.y) .. ","
        .. tostring(job.pos and job.pos.z) .. "): " .. n .. " level(s), "
        .. floor_name .. " floors, floor y=" .. floor_y .. ", shaft at ("
        .. hole.x .. "," .. hole.z .. "), ladder/hatch at (" .. ladder.x
        .. "," .. ladder.z .. "), " .. hatch_desc)
    return true
end

--
-- Entry point, called by run_job() in placement.lua right before the
-- Spawn.populate pcall (guarded pcall there, the dungeon_entrances.lua
-- hook pattern). Cheap: the guards, the deterministic draws and the
-- scans only, then the single dig
--

function Bs.maybe_dig_basement(job)
    -- a) master setting off: complete silent no-op, no error, no log
    if not enabled_setting then
        return
    end
    if not job or not job.box or not job.name or not job.pos then
        return
    end

    -- b) eligible houses only: house name prefixes (this alone excludes
    --    every civic building: stable, market, well, tower, pond, blot,
    --    pit, cage, harbour, fishtrap, logs, pelts, sledge, altar... --
    --    and the water anchored lake houses a second time). The
    --    historical "_30_" schematic name test was RETIRED (2026-10-15):
    --    it was a proxy for "shallow -4 embed", but every house family
    --    of the *buildings.lua files now carries offset = -4 (the 16
    --    tribal _30_ families AND house_1_0/house_medieval_fancy/
    --    house_with_garden), so the test only stole real houses from
    --    the draw (21 of the 79 house sites of the 2026-10-15 sessions,
    --    27%: grasslandhouse_1_0, grasslandhouse_medieval_fancy_1_90,
    --    grasslandhouse_with_garden_1_0 and their _swamp variants, all
    --    passing scan_floor_y/scan_ladder_hole/foundation on their
    --    schematics like the _30_ ones -- /tmp/bsfloor7.py)
    if not is_house(job.name) then
        return
    end

    -- c) cloudlands buildings rejected (floating islands, nothing
    --    solid to dig into); the multidimensions buildings are allowed
    if job.name:find("_cloudlands", 1, true) then
        return
    end

    local box = job.box

    -- d) un-emerged footprints are skipped silently (spawn.lua
    --    convention: get_node answers "ignore" there and the scans
    --    could not run)
    if minetest.get_node({x = box.x1, y = box.y1, z = box.z1}).name == "ignore"
        or minetest.get_node({x = box.x2, y = box.y2, z = box.z2}).name == "ignore" then
        return
    end

    -- e) mutual exclusion with the hidden randungeon entrances: exact
    --    replay of THEIR draw (same world seed stream, same chance),
    --    run only when their module would have drawn too (their own
    --    installed/enabled/house/foundation guards are the ones we
    --    just passed); when the house carries a dungeon, the basement
    --    gives up
    if rd_installed and rd_enabled then
        local dprng = PcgRandom(WORLD_SEED, box.x1, box.y1, box.z1)
        if dprng:next(0, 999999) / 999999 < rd_chance then
            return
        end
    end

    -- f) own deterministic draw: which houses carry a basement is a
    --    pure function of (BASE_SEED, footprint), reproducible across
    --    regenerations of the same chunks
    local rng = PcgRandom(BASE_SEED, box.x1, box.y1, box.z1)
    if rng:next(0, 999999) / 999999 >= chance then
        return
    end

    -- g) calibration inputs: real floor level, free interior 1x1 spot
    local floor_y = scan_floor_y(box, FOUNDATION_OFFSET)
    if not floor_y then
        -- [BASEMENT-DEBUG] temporary instrumentation, remove after the
        -- in-game confirmation
        minetest.log("warning", "[BASEMENT-DEBUG] " .. job.name .. " at ("
            .. job.pos.x .. "," .. job.pos.y .. "," .. job.pos.z
            .. "): scan_floor_y found no floor")
        return
    end
    local hole = scan_ladder_hole(rng, box, floor_y)
    if not hole then
        -- no interior cell clear of the doors, walls and outside
        -- rings: clean abandon with a log (a plain floor beats a
        -- doorstep shaft), the caller never retries
        minetest.log("action", "[nativevillages] basement given up for "
            .. job.name .. " at (" .. job.pos.x .. "," .. job.pos.y .. ","
            .. job.pos.z .. "): no trapdoor spot clear of doors, walls "
            .. "and outside cells")
        return
    end
    -- [BASEMENT-DEBUG] temporary instrumentation, remove after the
    -- in-game confirmation: floor level and relaxation pass elected
    minetest.log("warning", "[BASEMENT-DEBUG] " .. job.name .. " at ("
        .. job.pos.x .. "," .. job.pos.y .. "," .. job.pos.z
        .. "): floor_y=" .. floor_y .. ", trapdoor spot (" .. hole.x
        .. "," .. hole.z .. ") elected at pass P" .. tostring(hole.pass))

    -- h) foundation integrity: houses on stilts or above a cave give
    --    up (the cellar would hang in the air)
    if not foundation_solid(box, floor_y) then
        minetest.log("action", "[nativevillages] basement skipped for "
            .. job.name .. " at (" .. job.pos.x .. "," .. job.pos.y .. ","
            .. job.pos.z .. "): foundation not solid enough under the "
            .. "floor (stilt house or cave below)")
        return
    end

    -- level count draw, then the dig; dig_basement logs its own
    -- outcome (success or give up), maybe_dig stays silent on it
    local n = rng:next(levels_min, levels_max)
    Bs.dig_basement(job, {levels = n, rng = rng, floor_y = floor_y,
        hole = hole})
end
