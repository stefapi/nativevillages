-- Central placement engine for nativevillages buildings.
-- Every building of the mod is registered through
-- nativevillages.placement.register_building(def) by the *buildings.lua
-- data files. The factory is the single place where the placement mode
-- is decided:
--   * nativevillages.use_new_placement = true (default): a
--     register_on_generated engine samples the ground height over the
--     whole schematic footprint and rejects sloped or cliff sites before
--     placing with minetest.place_schematic. This fixes the floating
--     30-node dirt platforms and buried houses the old single point
--     anchor produced at cliff edges.
--   * nativevillages.use_new_placement = false: the historical
--     minetest.register_decoration behaviour is restored untouched (no
--     engine callback is registered, so there is no double placement).
--     The engine also falls back to this mode automatically on engines
--     older than 5.1 (decision derived from the version, because probing
--     VoxelManip at mod load time fails silently on Luanti servers).
-- Anchoring semantics are identical in both modes: the schematic base
-- lands at ground_y + offset, where offset is the old place_offset_y
-- (-29 on the _30_ foundation schematics), so a 30-node high foundation
-- keeps its top layer exactly at surface level on flat terrain. Lake
-- schematics (anchor = "water") are based on the flooded place_on node
-- of the lake bed (dirt/sand) with the historical y_min = y_max = -0.5
-- filter applied to it; no flatness test is applied to them.
-- Site selection only READS the mapgen voxelmanip inside the callback;
-- the actual minetest.place_schematic calls are deferred through
-- minetest.after(0): by the next server step the generated chunk has
-- been committed to the map, so the schematic can never be overwritten
-- by the mapgen write-back and is written on real committed map data.
-- Vertical containment: tall schematics (34..56 node foundations, lake
-- houses on stilts) routinely extend above or below the fragment the
-- callback reports, which can be as small as one 16 node mapblock on
-- this engine. Writing there anyway was the historical cause of
-- PARTIALLY DRAWN buildings: whatever place_schematic wrote into still
-- ungenerated mapblocks was overwritten later, when the mapgen finally
-- generated them. Every deferred placement therefore compares its
-- footprint to the Y window of the fragment and emerges the missing
-- mapblocks FIRST through minetest.emerge_area, placing only from the
-- emerge callback, on fully generated map data.
-- Anti-collision: the accepted footprint of every building is registered
-- (in memory for the session, mirrored to the mod storage under the
-- chunk keys it covers) and every later candidate site is rejected when
-- its footprint padded by nativevillages.min_spacing overlaps a
-- registered one, so two buildings of this mod can no longer overlap
-- inside a chunk or across neighbouring chunks. The registry only knows
-- the buildings placed by this engine: buildings of other mods and the
-- historical decoration fallback are invisible to it.
-- Village grouping (see village_zones.lua): on top of the scattered
-- sites, a deterministic coarse grid elects village cores and a plan of
-- building SLOTS around them. Every fragment a village spans processes
-- the slots whose POINT it hosts (one host per slot, whatever the chunk
-- generation order), the drawing still being elected by the REAL ground
-- of the slot through the very tests below: a village follows the
-- topography, a ravine or a shore simply punches holes in the plan. A
-- slot whose footprint crosses the fragment border is deferred behind
-- an emerge_area of its union footprint, the XZ counterpart of the
-- vertical containment below.

nativevillages = nativevillages or {}

local B = nativevillages.biomes
local Soil = nativevillages.soil
local Deco = nativevillages.deco

local P = {}
nativevillages.placement = P

local modpath = minetest.get_modpath(minetest.get_current_modname())

local unpack = table.unpack or unpack

-- Settings, with fallbacks on the defaults documented in settingtypes.txt
local setting_use_new = minetest.settings:get_bool("nativevillages.use_new_placement", true)
local max_ground_diff = tonumber(minetest.settings:get("nativevillages.max_ground_diff") or "") or 3
if max_ground_diff < 0 then
    max_ground_diff = 0
elseif max_ground_diff > 64 then
    max_ground_diff = 64
end
-- Surface density: expected candidate sites per generated node, so the
-- per chunk target is density * chunk area (6400 nodes on an 80x80
-- chunk), stochastically rounded then capped by max_tries_per_chunk.
-- Default calibrated on the historical decorations: the per-biome sum of
-- their fill_ratios ranges from 0.00026 (jungle) to 0.0006 (arctic);
-- 0.00035 is a representative average (~2.24 sites per 80x80 chunk).
-- Upper bound 1.0 = 6400 asked sites per chunk, in practice capped to
-- 64 by max_tries_per_chunk below. A negative value would reject even
-- perfectly flat sites, hence the clamps.
local density = tonumber(minetest.settings:get("nativevillages.placement_density") or "") or 0.00035
if density < 0.000001 then
    density = 0.000001
elseif density > 1.0 then
    density = 1.0
end

-- Safety margin in nodes kept between two buildings: a candidate whose
-- footprint expanded by this margin overlaps a registered footprint is
-- rejected (anti-collision registry below)
local min_spacing = tonumber(minetest.settings:get("nativevillages.min_spacing") or "") or 4
if min_spacing < 0 then
    min_spacing = 0
elseif min_spacing > 32 then
    min_spacing = 32
end
min_spacing = math.floor(min_spacing)

-- Hard safety cap on candidate sites per generated chunk. The number of
-- tried sites is the density derived target itself (density * chunk
-- area, stochastically rounded): it SCALES with the setting instead of
-- being a fixed 3, so a high density really produces more sites. This
-- cap only protects the callback at absurd densities: past ~64 tries on
-- an 80x80 chunk the anti-collision rejects almost everything anyway
-- (such a chunk physically fits about 13 buildings of footprint 18x18
-- plus min_spacing 4)
local max_tries_per_chunk = 64

-- Maximum weighted redraws of the building per candidate site: the first
-- draws often hit a building of a foreign biome and must be retried
local max_draws_per_site = 8

-- relax_altitude (default false): widen the altitude band of every
-- ground anchored building by RELAX_DOWN nodes below its y_min and
-- RELAX_UP nodes above its y_max. The historical bands were tuned for
-- sea level terrain (grassland 16..20, savanna 11..15, jungle 11..20,
-- desert 26..30, ice 1..3) and reject EVERY ground above them, so
-- plateaus and highlands never receive any village no matter how high
-- placement_density is: with the historical bands the altitude filter,
-- not the density, is the limiting factor there. Water anchored lake
-- buildings always keep their exact bed level.
local relax_altitude = minetest.settings:get_bool(
    "nativevillages.relax_altitude", false)
local RELAX_DOWN = 10
local RELAX_UP = 30
-- Multiplier of the scattered site density inside the village zones
-- (see village_zones.lua): the surroundings of a village must not
-- constellation with lone houses. 0 forbids the scattered channel
-- inside a zone, 1 keeps the exact outside density
local scatter_in_village = tonumber(minetest.settings:get(
    "nativevillages.scatter_in_village") or "") or 0.25
if scatter_in_village < 0 then
    scatter_in_village = 0
elseif scatter_in_village > 1 then
    scatter_in_village = 1
end

-- vary_deco (default true): furniture variation of the placed houses
-- (see deco_replacement.lua), a decorative counterpart of adapt_soil
-- above reading the same once-at-load pattern
local vary_deco = minetest.settings:get_bool("nativevillages.vary_deco", true)

-- Seed of the furniture variation draw: a constant distinct from every
-- other PRNG stream of the mod (dungeon_entrances.lua seeds on the raw
-- world seed, see its SEED), mixed with the world seed so two worlds
-- vary their houses differently while a regenerated chunk of the same
-- world (mapblock reset, /deleteblocks) redraws the identical furniture
local DECO_SEED = 0x5EEDC0DE
    + (tonumber(minetest.get_mapgen_setting("seed") or "") or 0)

-- Village grouping layer (bound lazily: placement.lua loads BEFORE
-- village_zones.lua per init.lua, the local V is captured at the first
-- generated chunk instead)
local V = nil

-- Dimension support layer (bound lazily like V above:
-- dimension_support.lua loads AFTER this file per init.lua, the local
-- Dim is captured at the first generated chunk instead)
local Dim = nil

-- The engine indexes the mapgen voxelmanip through its emerged area, an
-- API only available since Minetest 5.1. The capability CANNOT be probed
-- at mod load time: on Luanti 5.x servers minetest.get_voxel_manip called
-- from the main thread during load returns nil (and get_mapgen_object
-- errors "Must only be called in a mapgen thread!"), which silently
-- disabled the whole engine and its anti-collision on every start -- the
-- exact bug that made the user still see overlapping houses while both
-- code reviews validated the source. The decision is therefore derived
-- deterministically from the engine version (get_emerged_area shipped
-- with 5.1), never from a runtime probe at load, and the callback still
-- verifies the method on the first chunk as a belt and braces guard
local engine_capable
do
    local v = minetest.get_version and minetest.get_version() or {}
    local rel = tonumber(v.release or "") or 0
    if rel > 0 then
        engine_capable = rel >= 50100
    else
        -- development builds have no release number: parse "5.15.2" out
        -- of the human readable version string, assume modern otherwise
        local maj, minr = tostring(v.string or ""):match("(%d+)%.(%d+)")
        engine_capable = not maj or tonumber(maj) > 5
            or (tonumber(maj) == 5 and tonumber(minr) >= 1)
    end
end

local use_new = setting_use_new and engine_capable
if setting_use_new and not engine_capable then
    minetest.log("action", "[nativevillages] engine older than 5.1 "
        .. "(no VoxelManip:get_emerged_area): falling back to the "
        .. "historical mapgen decorations, NO anti-collision")
elseif not setting_use_new then
    minetest.log("action", "[nativevillages] placement engine DISABLED by "
        .. "setting use_new_placement=false: historical mapgen decorations "
        .. "in use, NO anti-collision")
end

-- Diagnostic log switch: traces every accepted/rejected candidate site so
-- the anti-collision can be confirmed live in-game (see settingtypes.txt)
local debug_placement = minetest.settings:get_bool(
    "nativevillages.debug_placement", false)

-- The chunk key grid of the anti-collision registry is derived from a
-- FIXED grid size, never from the csize reported by the on_generated
-- callback: mapgen v7 merges small emerged areas into 80 node chunks,
-- but other mapgens or engine versions may report a different csize, and
-- a footprint written under keys derived from one csize must stay
-- readable when a later callback reports another one
local KEY_GRID = 80

--
-- One visible startup line stating which mode is running (this is the
-- line to look for in debug.txt to confirm the engine is really active)
minetest.log("action", "[nativevillages] placement engine "
    .. (use_new and "ACTIVE (register_on_generated + anti-collision, "
        .. "min_spacing=" .. min_spacing .. ", density=" .. density
        .. ", altitude bands " .. (relax_altitude and "relaxed" or "historical")
        .. ", max_sites_per_chunk=" .. max_tries_per_chunk .. ")"
    or "FALLBACK (historical mapgen decorations, NO anti-collision)"))
-- Village grouping availability, logged once at startup like the engine
-- line above (village_zones.lua loads after this file: probe the setting
-- directly, the layer itself is bound at the first generated chunk)
local villages_on = minetest.settings:get_bool(
    "nativevillages.use_villages", true)

minetest.log("action", "[nativevillages] village grouping "
    .. (use_new and villages_on and "ACTIVE (deterministic zones, see village_zones.lua)"
        or "DISABLED (" .. (use_new and "use_villages=false" or "engine fallback")
        .. ")"))

-- All buildings registered through the factory, in registration order
-- (a stable drawing order keeps the engine deterministic per chunk seed)
local registry = {}
local total_weight = 0

-- Lazy schematic size cache (minetest.read_schematic is called once per
-- schematic, on first use; a sane fallback keeps the engine running even
-- if the call is unavailable or a .mts cannot be read)
local sizes = {}

local function schematic_size(path)
    if not sizes[path] then
        local ok, schem = pcall(minetest.read_schematic, path, {})
        sizes[path] = (ok and schem and schem.size) or {x = 16, y = 30, z = 16}
    end
    return sizes[path]
end

-- Register one building definition:
--   name        short name, decorated as "nativevillages:<name>" in the
--               legacy decoration mode
--   schematic   file name inside schematics/
--   biomes      logical biome categories (see biomes.lua), used both for
--               the biome list and the acceptable ground nodes
--   offset      y offset of the schematic base (the old place_offset_y:
--               -29 on the _30_ foundation schematics, 0 on the lake ones)
--   anchor      "ground" (default) or "water" (lake schematics based on
--               the flooded place_on node of the lake bed, without
--               flatness test)
--   y_min, y_max  altitude filter of the ground node (legacy mode filter,
--               also applied by the engine for ground anchored buildings)
--   fill_ratio  placement frequency (legacy mode) and relative drawing
--               weight of the building in the engine
function P.register_building(def)
    def.categories = {}
    for _, cat in ipairs(def.biomes) do
        def.categories[cat] = true
    end
    def.schematic = modpath .. "/schematics/" .. def.schematic
    def.anchor = def.anchor or "ground"
    def.fill_ratio = def.fill_ratio or 0.00005
    def.y_min = def.y_min or -31000
    def.y_max = def.y_max or 31000
    registry[#registry + 1] = def
    total_weight = total_weight + def.fill_ratio

    if not use_new then
        -- Historical behaviour, field for field identical to the previous
        -- register_decoration calls of the *buildings.lua files
        minetest.register_decoration({
            name = "nativevillages:" .. def.name,
            deco_type = "schematic",
            place_on = B.get_ground(unpack(def.biomes)),
            place_offset_y = def.offset,
            sidelen = 16,
            fill_ratio = def.fill_ratio,
            biomes = B.get(unpack(def.biomes)),
            y_max = def.y_max,
            y_min = def.y_min,
            schematic = def.schematic,
            flags = "force_placement",
            rotation = "random",
        })
    end
end

-- Content id caches, filled lazily on the first generated chunk so that
-- every optional mod has finished registering its nodes
local air_id = minetest.get_content_id("air")
local ignore_id = minetest.get_content_id("ignore")
local water_ids = {}   -- known surface liquids
local ground_ids = {}  -- category -> { [content_id] = true }
local ids_ready = false

local function collect_ids(names, set)
    for _, name in ipairs(names) do
        if minetest.registered_nodes[name] then
            set[minetest.get_content_id(name)] = true
        end
    end
end

local function init_ids()
    for _, def in ipairs(registry) do
        -- Exact biome name set of the building: the very list the
        -- historical mode passes as biomes= to register_decoration. It
        -- replaces any reverse-category lookup, which misclassifies the
        -- biomes shared by several categories (grassland_ocean belongs
        -- to the lake buildings but is claimed by grassland first).
        if not def.biome_set then
            def.biome_set = {}
            for _, name in ipairs(B.get(unpack(def.biomes))) do
                def.biome_set[name] = true
            end
        end
        for cat in pairs(def.categories) do
            if not ground_ids[cat] then
                ground_ids[cat] = {}
                collect_ids(B.get_ground(cat), ground_ids[cat])
            end
        end
    end
    collect_ids({
        "default:water_source", "default:river_water_source",
        "mcl_core:water_source", "mcl_core:river_water_source",
    }, water_ids)
    -- dimension grounds (dimension_support.lua): every eligible
    -- multidimensions dimension injects its NUMERIC ground content
    -- ids into the category sets here, so a building sharing a
    -- category with the dimension accepts its ground; strict no-op
    -- without the mod (Dim nil or disabled)
    if Dim and Dim.enabled then
        Dim.inject_ground(ground_ids)
    end
    ids_ready = true
end

-- Union of the acceptable ground node ids of the categories of a building
local function ground_set_of(def)
    if not def.ground_set then
        local set = {}
        for cat in pairs(def.categories) do
            for id in pairs(ground_ids[cat] or {}) do
                set[id] = true
            end
        end
        def.ground_set = set
    end
    return def.ground_set
end

-- Anti-collision registry of the placed building footprints.
-- Design notes:
--   * every accepted footprint is a 3D AABB, registered in memory
--     IMMEDIATELY when the candidate site is accepted, so the later
--     candidates of the same chunk or of a neighbour chunk generated in
--     the same session are tested against it; it is mirrored to the mod
--     storage only once the deferred place_schematic really wrote it
--   * storage layout: one key per mapgen chunk, "b:<cx>,<cz>", holding
--     the ";" separated footprints COVERING that chunk, each one the ","
--     separated signed base 36 encoded "x1,y1,z1,x2,y2,z2" corners. A
--     footprint covering several chunks is duplicated under each of
--     them, so a collision test only reads the few chunk keys its padded
--     AABB covers (at most the 9 keys around the candidate chunk with
--     the default settings); nothing is ever deserialized globally
--   * the parsed per-key lists stay in memory for the whole session: a
--     mapgen chunk is only generated once, so there is nothing to
--     invalidate and no cache eviction is needed
--   * the registry functions never consume the per chunk PRNG, so the
--     engine stays deterministic per chunk seed at equal registry state
--   * known limits: the registry only sees the buildings placed by this
--     engine of this mod. Buildings of other mods (villages, settlements,
--     ...) and the historical decoration fallback are invisible to it,
--     and entries are never purged (a few bytes per placed footprint)

local storage = minetest.get_mod_storage()

-- In-memory mirror of the storage: chunk key -> list of placed AABBs
local chunk_boxes = {}

local b36 = "0123456789abcdefghijklmnopqrstuvwxyz"

-- Signed base 36 conversion of one coordinate: 3-4 bytes per value
-- instead of up to 7 in decimal with the sign
local function to_b36(n)
    if n == 0 then
        return "0"
    end
    local neg = n < 0
    if neg then
        n = -n
    end
    local s = ""
    while n > 0 do
        local m = n % 36
        s = b36:sub(m + 1, m + 1) .. s
        n = math.floor(n / 36)
    end
    return neg and "-" .. s or s
end

local function from_b36(s)
    local neg = s:sub(1, 1) == "-"
    if neg then
        s = s:sub(2)
    end
    if s == "" then
        return nil
    end
    local n = 0
    for i = 1, #s do
        local v = b36:find(s:sub(i, i), 1, true)
        if not v then
            return nil
        end
        n = n * 36 + v - 1
    end
    return neg and -n or n
end

-- One ";" separated storage entry -> AABB table, nil when malformed
local function decode_entry(field)
    local vals = {}
    for v in field:gmatch("[^,]+") do
        vals[#vals + 1] = from_b36(v)
    end
    if #vals ~= 6 then
        return nil
    end
    for _, v in ipairs(vals) do
        if not v then
            return nil
        end
    end
    -- placed = true: an entry read back from the storage is a footprint
    -- whose schematic was really placed in an earlier session
    return {x1 = vals[1], y1 = vals[2], z1 = vals[3],
        x2 = vals[4], y2 = vals[5], z2 = vals[6], placed = true}
end

-- Lazily load one chunk key into the memory mirror (once per session and
-- per key); the mod storage already lives in engine memory, so this is a
-- cheap string parse, never a map or disk access
local function load_chunk(key)
    local boxes = chunk_boxes[key]
    if not boxes then
        boxes = {}
        local raw = storage:get_string(key)
        if raw ~= "" then
            for field in raw:gmatch("[^;]+") do
                local box = decode_entry(field)
                if box then
                    boxes[#boxes + 1] = box
                end
            end
        end
        chunk_boxes[key] = boxes
    end
    return boxes
end

-- Call fn(key) for every chunk key covered by an XZ rectangle
local function for_keys_overlapped(x1, z1, x2, z2, csize, fn)
    for cx = math.floor(x1 / csize), math.floor(x2 / csize) do
        for cz = math.floor(z1 / csize), math.floor(z2 / csize) do
            fn("b:" .. cx .. "," .. cz)
        end
    end
end

-- True when the padded footprint of a candidate overlaps a registered
-- one. The min_spacing margin is applied on the XZ axes only; the Y
-- ranges must genuinely intersect, so a lake building anchored on a lake
-- bed and a surface building above it may share an XZ footprint.
local function site_occupied(box)
    local x1 = box.x1 - min_spacing
    local z1 = box.z1 - min_spacing
    local x2 = box.x2 + min_spacing
    local z2 = box.z2 + min_spacing
    local hit, identical = false, false
    for_keys_overlapped(x1, z1, x2, z2, KEY_GRID, function(key)
        if not hit then
            for _, other in ipairs(load_chunk(key)) do
                if x1 <= other.x2 and x2 >= other.x1
                    and z1 <= other.z2 and z2 >= other.z1
                    and box.y1 <= other.y2 and box.y2 >= other.y1 then
                    hit = true
                    -- corner for corner twin of an already PLACED
                    -- footprint: the signature of a regenerated area
                    -- (/deleteblocks, world restored without its mod
                    -- storage) being offered the exact same site again
                    identical = other.placed
                        and other.x1 == box.x1 and other.y1 == box.y1
                        and other.z1 == box.z1 and other.x2 == box.x2
                        and other.y2 == box.y2 and other.z2 == box.z2
                    break
                end
            end
        end
    end)
    if identical then
        -- loud on purpose: the placement engine works as intended (the
        -- twin site is rejected), but the surrounding mapblocks were
        -- regenerated and the building the storage remembers is now
        -- gone from the map, which looks like a partially drawn village
        minetest.log("warning", "[nativevillages] candidate at ("
            .. box.x1 .. "," .. box.y1 .. "," .. box.z1
            .. ") matches an already placed footprint corner for corner: "
            .. "regenerated mapblocks or mod storage desync, the twin "
            .. "site is rejected")
    end
    return hit
end

-- Register an accepted footprint in the memory mirror under every chunk
-- key it covers; the storage copy is written later by commit_box, only
-- once the schematic has really been placed
local function record_box(box)
    box.keys = {}
    for_keys_overlapped(box.x1, box.z1, box.x2, box.z2, KEY_GRID, function(key)
        local boxes = load_chunk(key)
        boxes[#boxes + 1] = box
        box.keys[#box.keys + 1] = key
    end)
    return box
end

-- Rewrite one chunk key of the storage from the memory mirror, keeping
-- only the footprints whose schematic has really been placed. A pending
-- footprint of another deferred job sharing the key must never leak
-- into the storage: its placement can still fail, and a leaked entry
-- would survive as a ghost footprint blocking its site forever, across
-- restarts (an empty list clears the key)
local function persist_key(key)
    local parts = {}
    for _, b in ipairs(chunk_boxes[key]) do
        if b.placed then
            parts[#parts + 1] = to_b36(b.x1) .. "," .. to_b36(b.y1) .. ","
                .. to_b36(b.z1) .. "," .. to_b36(b.x2) .. "," .. to_b36(b.y2)
                .. "," .. to_b36(b.z2)
        end
    end
    storage:set_string(key, table.concat(parts, ";"))
end

-- Persist every memory list the box belongs to (rewriting each whole
-- list keeps the storage and the memory mirror consistent)
local function commit_box(box)
    box.placed = true
    for _, key in ipairs(box.keys) do
        persist_key(key)
    end
end

-- Drop a footprint whose schematic could not be placed: remove it from
-- the mirror under every chunk key it covers, then rewrite those keys
-- so a footprint that leaked into the storage through the commit of
-- another job sharing a key cannot survive there as a ghost entry
local function discard_box(box)
    for _, key in ipairs(box.keys) do
        local boxes = chunk_boxes[key]
        if boxes then
            for i = #boxes, 1, -1 do
                if boxes[i] == box then
                    table.remove(boxes, i)
                end
            end
            persist_key(key)
        end
    end
end

-- Name of the biome at a position, nil when the engine cannot answer
-- (module level: the deferred village slot validation reuses it from
-- its emerge callback, outside on_generated)
local function biome_name_at(x, y, z)
    local bdata = minetest.get_biome_data({x = x, y = y, z = z})
    if not bdata then
        return nil
    end
    return minetest.get_biome_name(bdata.biome)
end

-- Biome check against the exact biome name set of the building (the
-- same list the historical decorations passed as biomes=). Also
-- returns the accepted biome name so the site can adapt its schematic
-- ground to it (see soil_replacement.lua)
local function biome_ok(x, y, z, biome_set)
    local name = biome_name_at(x, y, z)
    if name == nil or not biome_set[name] then
        return false, nil
    end
    return true, name
end

-- Height and content id of the first non-air node of a column,
-- scanning down from top to yfloor (nil when the whole column is air).
-- Parameterized by its voxel view (area + data + floor) so the
-- deferred village slot validation reuses the very scan on a manually
-- read VoxelManip
local function vm_top_node(va, data, yfloor, x, z, top)
    for y = top, yfloor, -1 do
        local id = data[va:index(x, y, z)]
        if id ~= air_id and id ~= ignore_id then
            return y, id
        end
    end
    return nil
end

-- Ground node height of a column, or nil when the site must be
-- rejected: the first non-air node has to be an acceptable ground node
-- (the historical place_on contract: a tree, a building or a wrong
-- surface node on top rejects the site). Water anchored schematics
-- skip the liquid column down to the lake bed instead
local function vm_ground_height(va, data, yfloor, x, z, ground_set, skip_liquids, top)
    for y = top, yfloor, -1 do
        local id = data[va:index(x, y, z)]
        if id ~= air_id and id ~= ignore_id then
            if skip_liquids and water_ids[id] then
                -- keep scanning through the water column
            elseif ground_set[id] then
                return y
            else
                return nil
            end
        end
    end
    return nil
end

-- Civic drawings for the village core slots: the registered buildings
-- whose name is listed by nativevillages.village.civic. Built lazily
-- on first use, once every *buildings.lua file has registered
local civic_list = nil
local civic_total = 0
local function civic_registry()
    if civic_list == nil then
        civic_list = {}
        civic_total = 0
        local Vv = nativevillages.village
        if Vv and Vv.civic then
            for _, d in ipairs(registry) do
                if Vv.civic[d.name] then
                    civic_list[#civic_list + 1] = d
                    civic_total = civic_total + d.fill_ratio
                end
            end
        end
    end
    return civic_list, civic_total
end

-- Internal contract (dimension support): the deferred dimension path
-- of dimension_support.lua replays the village slot flow outside this
-- callback and needs the same civic pool to filter per dimension
P._civic_registry = civic_registry

-- Real placement of one accepted job: ground adaptation table of the
-- elected biome applied while the .mts is decoded, furniture variation
-- merged on top, footprint persisted once really on the map,
-- deterministic population. Module level: the deferred village slot
-- validations place through it too
local function run_job(job)
    local repl = Soil.replacement_for(job.biome_name)
    -- Furniture variation (see deco_replacement.lua), drawn from a PRNG
    -- seeded on the site footprint: deterministic per site, a chunk
    -- regenerated later redraws the same furniture. Soil.replacement_for
    -- returns the per biome CACHED table, so the merge happens in a
    -- fresh copy (mutating repl would leak the swaps of this house into
    -- every later house of the same biome); the soil and deco keys are
    -- disjoint anyway (ground nodes vs furniture nodes), the merge order
    -- is therefore irrelevant
    if vary_deco and job.box then
        local rng = PcgRandom(DECO_SEED, job.box.x1, job.box.y1,
            job.box.z1)
        local deco = Deco.replacement_for(job, rng)
        if next(deco) then
            if repl then
                local merged = {}
                for k, v in pairs(repl) do
                    merged[k] = v
                end
                for k, v in pairs(deco) do
                    merged[k] = v
                end
                repl = merged
            else
                repl = deco
            end
            if debug_placement then
                local n = 0
                for _ in pairs(deco) do
                    n = n + 1
                end
                minetest.log("action", "[nativevillages] deco varied for "
                    .. job.name .. " at (" .. job.pos.x .. "," .. job.pos.y
                    .. "," .. job.pos.z .. "): " .. n .. " swap(s)")
            end
        end
    end
    local ok = minetest.place_schematic(job.pos, job.schematic,
        tostring(job.rot), repl, true)
    if ok then
        -- the footprint is really on the map, persist it
        commit_box(job.box)
        minetest.log("action", "[nativevillages] placed " .. job.name
            .. " at (" .. job.pos.x .. "," .. job.pos.y .. "," .. job.pos.z
            .. ") rot=" .. job.rot .. (job.tag or ""))
        if debug_placement and repl then
            minetest.log("action", "[nativevillages] soil adapted for "
                .. job.name .. " in biome " .. job.biome_name)
        end
        -- multi level basements under the eligible houses (see
        -- basements.lua): guarded pcall, purely additive, no-op when
        -- the nativevillages.basements setting is disabled. NOT a
        -- silent pcall: a broken hook must surface in the log, a mute
        -- one once hid a systematic write failure (see progress.md)
        local Basement = nativevillages.basements
        if Basement and Basement.maybe_dig_basement then
            local ok, err = pcall(Basement.maybe_dig_basement, job)
            if not ok then
                minetest.log("warning", "[nativevillages] basement hook "
                    .. "failed for " .. job.name .. ": " .. tostring(err))
            end
        end
        -- deterministic population of the placed building (beds, native
        -- trigger nodes, anvils): purely additive, silent no-op when the
        -- nativevillages.deterministic_spawn setting is disabled or the
        -- building category is unknown
        local Spawn = nativevillages.spawn
        if Spawn and Spawn.populate then
            pcall(Spawn.populate, job)
        end
        -- hidden randungeon entrance (see dungeon_entrances.lua): same
        -- guarded pcall pattern, purely additive, no-op without the
        -- optional randungeon mod
        local Dungeon = nativevillages.dungeon
        if Dungeon and Dungeon.maybe_place_hidden_entrance then
            pcall(Dungeon.maybe_place_hidden_entrance, job)
        end
    else
        -- nothing was written: drop the registered footprint, it must
        -- not block future sites
        discard_box(job.box)
        minetest.log("warning", "[nativevillages] could not place "
            .. job.name .. " at (" .. job.pos.x .. "," .. job.pos.y .. ","
            .. job.pos.z .. "), footprint discarded")
    end
end

-- VERTICAL CONTAINMENT. When the footprint extends above or below the
-- Y window [fy1, fy2] of the fragment that accepted it, the missing
-- mapblocks must be generated FIRST: place_schematic happily writes
-- into ungenerated mapblocks, and the mapgen later overwrites them,
-- leaving a partially drawn building. emerge_area generates (or loads)
-- the whole 3D box of the footprint, and the placement only runs from
-- the final emerge callback, on committed map data. The extra
-- on_generated calls the emerge triggers for the freshly generated
-- mapblocks are harmless: their Y window sits above or below the
-- surface, so their site draws die on the ground test, and the
-- anti-collision registry rejects the rest
local function dispatch_job(job, fy1, fy2)
    local box = job.box
    if box.y1 < fy1 or box.y2 > fy2 then
        if debug_placement then
            minetest.log("action", "[nativevillages] deferring "
                .. job.name .. " at (" .. job.pos.x .. "," .. job.pos.y
                .. "," .. job.pos.z .. "): footprint y " .. box.y1
                .. ".." .. box.y2 .. " spills out of fragment y " .. fy1
                .. ".." .. fy2 .. ", emerging it first")
        end
        minetest.emerge_area(
            {x = box.x1, y = box.y1, z = box.z1},
            {x = box.x2, y = box.y2, z = box.z2},
            function(_, _, remaining)
                if remaining <= 0 then
                    run_job(job)
                end
            end)
    else
        run_job(job)
    end
end

-- Queue an accepted site and register its footprint right away: the
-- later candidates of this chunk are tested against it before anything
-- is written to the map. Returns false when the padded footprint
-- overlaps an already placed building. The biome name stored in the job
-- (multi point elected over the real footprint, anchor only deciding
-- the ties, see soil_replacement.lua S.elect) lets the deferred
-- placement adapt the schematic ground to it. ctx carries the stats
-- table, the queue (nil for the deferred village slots, which place
-- directly on their emerged data through place_now) and a debug tag
local function accept_site_ctx(ctx, def, rot, px, pz, y1, w, d, size, biome_name)
    local box = {
        x1 = px, y1 = y1, z1 = pz,
        x2 = px + w - 1, y2 = y1 + size.y - 1, z2 = pz + d - 1,
        placed = false, -- flipped to true by commit_box, once placed
    }
    if site_occupied(box) then
        ctx.stats.collision = ctx.stats.collision + 1
        if debug_placement then
            minetest.log("action", "[nativevillages] site REJECTED "
                .. def.name .. " at (" .. px .. "," .. y1 .. "," .. pz
                .. "): collision with a registered footprint"
                .. (ctx.tag or ""))
        end
        return false -- overlaps an already placed footprint
    end
    ctx.stats.accepted = ctx.stats.accepted + 1
    if debug_placement then
        minetest.log("action", "[nativevillages] site ACCEPTED "
            .. def.name .. " at (" .. px .. "," .. y1 .. "," .. pz
            .. ") rot=" .. rot .. " box=(" .. box.x1 .. "," .. box.y1
            .. "," .. box.z1 .. ")-(" .. box.x2 .. "," .. box.y2
            .. "," .. box.z2 .. ")" .. (ctx.tag or ""))
    end
    local job = {
        pos = {x = px, y = y1, z = pz},
        schematic = def.schematic,
        rot = rot,
        name = def.name,
        biome_name = biome_name,
        tag = ctx.tag or "",
        box = record_box(box),
    }
    if ctx.place_now then
        dispatch_job(job, ctx.yfloor, ctx.top)
    else
        ctx.queue[#ctx.queue + 1] = job
    end
    return true
end

-- One candidate attempt loop, shared by the scattered sites and the
-- village slots. Draws a building (weighted by fill_ratio, bounded
-- redraws), tests it around a centre and queues it when the site is
-- good. ctx fields:
--   va, data, yfloor, top   voxel view and Y scan window
--   eminx/eminz/emaxx/emaxz readable XZ window of the view
--   minp, maxp              fragment (scattered containment)
--   stats, queue            bookkeeping and deferred queue
--   rng, defs, weight       PRNG and weighted drawing pool
--   slot                    nil = scattered site (rotation and centre
--                           drawn from rng, footprint inside the chunk,
--                           lone house suppression inside village
--                           zones), {x, z, rot} = village slot (the
--                           point is the centre, rotation from the
--                           plan, footprint may cross the fragment
--                           borders within the readable window,
--                           otherwise the whole loop is handed over to
--                           ctx.defer, and a not flat site spends its
--                           remaining draws on smaller drawings)
--   defer                   XZ deferral callback of the village slots
--   place_now, tag          deferred placement context markers
local function try_at(ctx)
    local cx, cz
    for _ = 1, max_draws_per_site do
        -- draw a building, weighted by fill_ratio
        local def
        local r = ctx.rng:next(0, 999999) / 999999 * ctx.weight
        local acc = 0
        for _, d in ipairs(ctx.defs) do
            acc = acc + d.fill_ratio
            if r <= acc then
                def = d
                break
            end
        end
        if not def then
            def = ctx.defs[#ctx.defs]
        end

        -- draw the rotation first: a 90/270 rotation swaps the XZ
        -- extents, and the flatness test must sample the footprint
        -- that will actually be placed. A village slot takes the
        -- rotation of its plan instead
        local size = schematic_size(def.schematic)
        local w, d = size.x, size.z
        local rot
        if ctx.slot then
            rot = ctx.slot.rot
            cx, cz = ctx.slot.x, ctx.slot.z
        else
            rot = ctx.rng:next(0, 3) * 90
        end
        if rot % 180 ~= 0 then
            w, d = d, w
        end

        local px, pz
        if ctx.slot then
            -- village slot: the point is the centre of the (rotated)
            -- footprint; the columns must merely stay readable inside
            -- the emerged area of the fragment
            px = cx - math.floor(w / 2)
            pz = cz - math.floor(d / 2)
        else
            -- random centre point, keeping the whole footprint inside
            -- the current chunk (see the engine design notes above)
            local x0 = ctx.minp.x + math.floor(w / 2) + 1
            local x1 = ctx.maxp.x - math.ceil(w / 2) - 1
            local z0 = ctx.minp.z + math.floor(d / 2) + 1
            local z1 = ctx.maxp.z - math.ceil(d / 2) - 1
            if x1 < x0 or z1 < z0 then
                ctx.stats.too_wide = ctx.stats.too_wide + 1
                return false -- schematic wider than the chunk, give up
            end
            local scx = x0 + ctx.rng:next(0, x1 - x0)
            local scz = z0 + ctx.rng:next(0, z1 - z0)
            px = scx - math.floor(w / 2)
            pz = scz - math.floor(d / 2)
            -- lone house suppression inside the village zones: the
            -- surroundings of a village must not constellation with
            -- isolated houses, the grouped slots play that role there
            if V and villages_on then
                -- in a dimension fragment the plan is salted by the
                -- dimension (independent village layouts per world
                -- layer; salt 0 = surface = the historical plan)
                local plan = V.plan(math.floor(scx / V.region),
                    math.floor(scz / V.region),
                    ctx.dim and ctx.dim.salt or nil)
                if plan and ctx.rng:next(0, 999999) / 999999
                    >= scatter_in_village then
                    return false
                end
            end
            cx, cz = scx, scz
        end

        -- readability guard: the tests below must READ the columns of
        -- the footprint. A village slot whose footprint crosses the
        -- emerged area of the fragment is handed over to the deferred
        -- path (emerge first); in a deferred context (defer = nil) a
        -- drawing wider than the readable window is dropped instead.
        -- A scattered site never reaches this: its footprint already
        -- fits the chunk, hence the emerged area
        if px < ctx.eminx or px + w - 1 > ctx.emaxx
            or pz < ctx.eminz or pz + d - 1 > ctx.emaxz then
            if ctx.defer then
                return ctx.defer(ctx) or true
            end
            ctx.stats.too_wide = ctx.stats.too_wide + 1
            return false -- drawing wider than the readable window
        end

        local ground_set = ground_set_of(def)

        if def.anchor == "water" then
            -- anchor to the lake bed, like the historical
            -- decorations: the engine found the place_on node
            -- (dirt/sand) under the water column and based the
            -- schematic on it, the y_min/y_max = -0.5 filter
            -- selecting beds at y = -1 exactly. The centre column
            -- must be flooded open water of an acceptable biome
            -- (the historical biomes= filter) above that bed.
            -- relax_altitude never widens these bands: the lake
            -- schematics are built for a bed one node under the
            -- water surface, a deeper bed would drown them.
            local top_y, top_id = vm_top_node(ctx.va, ctx.data,
                ctx.yfloor, cx, cz, ctx.top)
            if not top_y or not water_ids[top_id] then
                ctx.stats.draw_water = ctx.stats.draw_water + 1
            else
                local bed_y = vm_ground_height(ctx.va, ctx.data,
                    ctx.yfloor, cx, cz, ground_set, true, top_y)
                local bed_ok, bed_biome
                if bed_y then
                    bed_ok, bed_biome = biome_ok(cx, bed_y, cz, def.biome_set)
                end
                if not bed_y then
                    ctx.stats.draw_ground = ctx.stats.draw_ground + 1
                elseif not bed_ok then
                    ctx.stats.draw_biome = ctx.stats.draw_biome + 1
                else
                    local c = bed_y + 0.5
                    if c >= def.y_min and c <= def.y_max then
                        -- 3x3 biome sampling of the real (rotated)
                        -- footprint at the constant bed height: no
                        -- extra column scan, a lake bed has no
                        -- vertical biome boundary to care about. A
                        -- grid point fallen on an emerged shore
                        -- votes a land biome, filtered out at
                        -- election time below
                        local votes = {}
                        for i = 0, 2 do
                            for j = 0, 2 do
                                local sx = px + math.floor((w - 1) * i / 2)
                                local sz = pz + math.floor((d - 1) * j / 2)
                                votes[#votes + 1] = biome_name_at(sx, bed_y, sz)
                            end
                        end
                        -- votes filtered on the accepted biome set:
                        -- a lake building can only elect a bed biome
                        -- (sand/dirt node_top), never a land one
                        -- (grass under water); ties and fallback go
                        -- to the bed anchor
                        local elected = Soil.elect(votes, bed_biome, def.biome_set)
                        if debug_placement and elected ~= bed_biome then
                            minetest.log("action", "[nativevillages] soil biome "
                                .. "elected " .. tostring(elected) .. " over anchor "
                                .. tostring(bed_biome) .. " for " .. def.name)
                        end
                        -- cheap AABB anti-collision test, then
                        -- queue the accepted footprint; the job
                        -- carries the ELECTED biome, the bed anchor
                        -- biome only decided the ties
                        return accept_site_ctx(ctx, def, rot, px, pz,
                            bed_y + def.offset, w, d, size, elected)
                    end
                    ctx.stats.draw_alt = ctx.stats.draw_alt + 1
                end
            end
            -- wrong site for this drawing, try another drawing
        else
            -- ground anchored: the centre column must carry an
            -- acceptable ground node of an acceptable biome inside
            -- the altitude band. y_min/y_max are compared at the
            -- centre of the node (y + 0.5), the engine decoration
            -- convention that makes the historical x.5 bounds
            -- select whole node rows. relax_altitude widens the
            -- band of the drawing (see the setting block above).
            -- Swamp anchored drawings additionally skip a SHALLOW
            -- water column: a real swamp is flooded, the first
            -- non air node of its columns is water, so a strict
            -- ground scan rejects every site of every real swamp
            -- (the run F logs showed ~450/512 draws dying on the
            -- ground test inside a genuine swamp biome). The 30
            -- node foundation then emerges from the water like a
            -- stilt house. The 0.5..10.5 altitude band still
            -- rejects the beds of deep lakes.
            local swampy = def.categories.swamp == true
            local gy = vm_ground_height(ctx.va, ctx.data, ctx.yfloor,
                cx, cz, ground_set, swampy, ctx.top)
            -- surface reference of a swampy site: the FIRST non air
            -- node (water surface or dry mud island top). It is the
            -- flatness reference AND the anchor: anchoring on the
            -- bed would leave the ground floor under the water
            local surface_y = swampy and vm_top_node(ctx.va, ctx.data,
                ctx.yfloor, cx, cz, ctx.top) or gy
            local ground_ok, ground_biome
            if gy and ctx.dim then
                -- dimension fragment: no real biome to test (the
                -- engine would answer the surface biome of the
                -- column), the injected dimension ground ids already
                -- decided; the pseudo biome label only feeds the logs
                -- and the soil election fallback
                ground_ok, ground_biome = true, ctx.dim.label
            elseif gy then
                ground_ok, ground_biome = biome_ok(cx, gy, cz, def.biome_set)
            end
            if not gy then
                ctx.stats.draw_ground = ctx.stats.draw_ground + 1
            elseif not ground_ok then
                ctx.stats.draw_biome = ctx.stats.draw_biome + 1
            else
                -- swampy sites need SHALLOW water: more than
                -- SWAMP_MAX_DEPTH nodes between the surface and
                -- the bed is a lake, not a swamp, and a 30 node
                -- foundation anchored there would build a dirt
                -- tower from the abyss
                if swampy and surface_y - gy > 3 then
                    ctx.stats.draw_water = ctx.stats.draw_water + 1
                else
                    -- the altitude band is checked on the anchoring
                    -- reference: the surface for a swampy site (the
                    -- water surface of a flooded swamp sits around y=1
                    -- while its bed lies at -2..0 and would fall below
                    -- the 0.5 floor), the ground node otherwise
                    local c = (swampy and surface_y or gy) + 0.5
                    local y_lo = def.y_min
                    local y_hi = def.y_max
                    if ctx.dim then
                        -- dimension fragment: the absolute altitude
                        -- window of the dimension replaces the
                        -- historical band, relax_altitude is
                        -- neutralised there
                        y_lo, y_hi = ctx.dim.y_lo, ctx.dim.y_hi
                    elseif relax_altitude then
                        y_lo = y_lo - RELAX_DOWN
                        y_hi = y_hi + RELAX_UP
                    end
                    if c >= y_lo and c <= y_hi then
                        -- flatness test over the whole footprint (3x3
                        -- grid: corners, edge midpoints, centre).
                        -- Swampy drawings compare the FIRST non air
                        -- node of each column (the water surface of a
                        -- flooded swamp or the top of a mud island):
                        -- the bed of a real swamp is a chaotic mix of
                        -- pools, mud humps and mangrove trunks, and
                        -- comparing bed heights rejected every site
                        -- (run H logs), while the water surface is
                        -- what a stilt house actually stands over
                        local flat = true
                        for i = 0, 2 do
                            for j = 0, 2 do
                                local sx = px + math.floor((w - 1) * i / 2)
                                local sz = pz + math.floor((d - 1) * j / 2)
                                local sy
                                if swampy then
                                    sy = vm_top_node(ctx.va, ctx.data,
                                        ctx.yfloor, sx, sz, ctx.top)
                                else
                                    sy = vm_ground_height(ctx.va, ctx.data,
                                        ctx.yfloor, sx, sz, ground_set, false,
                                        ctx.top)
                                end
                                if not sy or math.abs(sy - surface_y) > max_ground_diff then
                                    flat = false -- too steep, cliff...
                                    break
                                end
                            end
                            if not flat then
                                break
                            end
                        end
                        if flat then
                            -- 3x3 biome sampling on the same grid
                            -- positions as the flatness test above,
                            -- measured at the real surface of each
                            -- point (the biome also varies vertically);
                            -- swampy sites sample the water or island
                            -- surface, their flatness reference. Runs
                            -- only on flat accepted candidates: a
                            -- rejected site pays no vote
                            local votes = {}
                            for i = 0, 2 do
                                for j = 0, 2 do
                                    local sx = px + math.floor((w - 1) * i / 2)
                                    local sz = pz + math.floor((d - 1) * j / 2)
                                    local sy
                                    if swampy then
                                        sy = vm_top_node(ctx.va, ctx.data,
                                            ctx.yfloor, sx, sz, ctx.top)
                                    else
                                        sy = vm_ground_height(ctx.va, ctx.data,
                                            ctx.yfloor, sx, sz, ground_set,
                                            false, ctx.top)
                                    end
                                    votes[#votes + 1] = sy and biome_name_at(sx, sy, sz) or nil
                                end
                            end
                            -- open vote: the ground follows the biome
                            -- dominating the visible terrain, even
                            -- outside the categories of the building
                            -- (e.g. a grassland house mostly standing
                            -- on desert ground gets desert sand); ties
                            -- and fallback go to the ground anchor
                            local elected = Soil.elect(votes, ground_biome, nil)
                            if debug_placement and elected ~= ground_biome then
                                minetest.log("action", "[nativevillages] soil biome "
                                    .. "elected " .. tostring(elected) .. " over anchor "
                                    .. tostring(ground_biome) .. " for " .. def.name)
                            end
                            -- cheap AABB anti-collision test, then
                            -- queue the accepted footprint, anchored on
                            -- the surface (water surface of a flooded
                            -- swamp, top of a dry mud island); the job
                            -- carries the ELECTED biome, the anchor
                            -- biome only decided the ties
                            return accept_site_ctx(ctx, def, rot, px, pz,
                                surface_y + def.offset, w, d, size, elected)
                        end
                        ctx.stats.not_flat = ctx.stats.not_flat + 1
                        if debug_placement then
                            minetest.log("action", "[nativevillages] site REJECTED "
                                .. def.name .. " at (" .. px .. "," .. gy .. ","
                                .. pz .. "): ground not flat enough (diff > "
                                .. max_ground_diff .. ")")
                        end
                        if not ctx.slot then
                            -- scattered site: right drawing, bad ground
                            -- shape or already occupied site: reject it,
                            -- do not redraw another building on it
                            return false
                        end
                        -- village slot: the position is fixed, but a
                        -- smaller drawing may still fit the slope, so
                        -- the remaining bounded draws are spent instead
                        -- of dropping the slot outright
                    end
                    ctx.stats.draw_alt = ctx.stats.draw_alt + 1
                end
            end
            -- wrong biome, ground or altitude for this drawing,
            -- try another drawing
        end
    end
    -- none of the bounded redraws matched this site (biome, ground
    -- node or altitude rejected them all)
    ctx.stats.no_match = ctx.stats.no_match + 1
    return false
end

-- Internal contract (dimension support): the deferred dimension path
-- of dimension_support.lua calls this very site attempt loop on its
-- own re-read VoxelManip of a dimension fragment; ctx.dim drives the
-- dimension specific branches inside (pseudo biome, absolute altitude
-- window, salted village plans, place_now placement)
P._try_at = try_at

-- Engine: chunk by chunk alternative to the mapgen decorations.
-- Design notes:
--   * the VoxelManip of the mapgen object is only READ (column scans,
--     indexed through the emerged area it reports); the schematics are
--     written by deferred minetest.place_schematic calls, which handle
--     the .mts decoding and the rotation natively
--   * the rotation is drawn from the chunk seeded PRNG before the
--     flatness test, so the sampled footprint is the placed footprint
--   * candidate sites keep the whole footprint inside the current chunk
--     on X and Z only: a schematic overflowing into a still ungenerated
--     neighbour could be partially overwritten when that neighbour chunk
--     is generated. The Y axis cannot use the same rejection (tall
--     schematics would never fit a 16 node high fragment), so the
--     vertical spill is handled at placement time by emerging the
--     missing mapblocks first (see the deferred placement below)
if use_new then
    minetest.register_on_generated(function(minp, maxp, blockseed)
        -- bind the dimension layer once available
        -- (dimension_support.lua loads after this file, see init.lua),
        -- BEFORE init_ids: the dimension ground ids are injected
        -- inside it
        if Dim == nil then
            Dim = nativevillages.dimensions
        end
        if not ids_ready then
            init_ids()
        end

        -- bind the village layer once available (village_zones.lua
        -- loads after this file, see init.lua)
        if V == nil then
            V = nativevillages.village
        end
        if #registry == 0 or total_weight <= 0 then
            return
        end

        -- Dimension fragments are routed ENTIRELY to the deferred
        -- path of dimension_support.lua: multidimensions writes its
        -- own terrain from its own callback, whose order relative to
        -- ours is not guaranteed, so NOTHING is decided here on the
        -- mapgen voxelmanip (neither scatter nor village slots). A
        -- fragment outside every dimension (nil dimcfg) keeps the
        -- surface flow below untouched
        if Dim and Dim.enabled then
            local dimcfg = Dim.fragment(minp, maxp)
            if dimcfg then
                Dim.process_fragment(minp, maxp, blockseed, dimcfg,
                    registry, total_weight)
                return
            end
        end

        local prng = PcgRandom(blockseed)

        -- Expected number of candidate sites for this chunk: density is a
        -- surface density (expected sites per generated node), so the
        -- target is density * chunk area, stochastically rounded (2.24
        -- gives 2 sites three chunks out of four, 3 once out of four)
        -- then hard capped by max_tries_per_chunk. The default 0.00035
        -- asks 2.24 sites per 80x80 chunk; density = 0.1 asks 640,
        -- capped to 64.
        -- Chunk size on the X/Z axes, only used to scale the expected
        -- number of sites to the generated area (the anti-collision
        -- key grid is the fixed KEY_GRID above, independent of csize)
        local csize = maxp.x - minp.x + 1
        local area = csize * (maxp.z - minp.z + 1)
        local target = density * area
        local tries = math.floor(target)
        if prng:next(0, 999999) < (target - tries) * 1000000 then
            tries = tries + 1
        end
        if tries > max_tries_per_chunk then
            tries = max_tries_per_chunk
        end
        -- 0 scattered tries must NOT return early: the village slots
        -- below still have to be processed (a low placement_density
        -- must not empty the villages)
        if tries < 1 then
            tries = 0
        end

        -- Per chunk counters (debug_placement): where the tried sites
        -- go. Site level: no_drawing (every bounded redraw failed the
        -- biome/ground/altitude test), not_flat, collision, too_wide.
        -- Draw level (inside the bounded redraws of a site): ground,
        -- biome, altitude, open_water. Counting never consumes the
        -- chunk PRNG, the engine stays deterministic per chunk seed.
        local stats = {
            accepted = 0,
            no_match = 0, not_flat = 0, collision = 0, too_wide = 0,
            draw_ground = 0, draw_biome = 0, draw_alt = 0, draw_water = 0,
            deferred = 0,
        }

        local vm = minetest.get_mapgen_object("voxelmanip")
        if not vm or type(vm.get_emerged_area) ~= "function" then
            -- impossible on an engine >= 5.1, kept as a loud guard
            minetest.log("error", "[nativevillages] no get_emerged_area on "
                .. "the mapgen voxelmanip, skipping chunk " .. minp.x .. ","
                .. minp.z .. " (report this bug)")
            return
        end
        local data = vm:get_data()
        local emin, emax = vm:get_emerged_area()
        local va = VoxelArea:new({MinEdge = emin, MaxEdge = emax})

        -- Deferred placements of this chunk: executed on the next server
        -- step, once the generated chunk has been committed to the map
        local queue = {}

        -- Village slot bookkeeping of this fragment (debug_placement
        -- recap): hosted counts the slots whose POINT belongs to this
        -- fragment, tried the ones actually offered to the engine
        local vstats = {
            hosted = 0, tried = 0, accepted = 0, not_flat = 0,
            collision = 0, no_match = 0, too_wide = 0, deferred = 0,
            draw_ground = 0, draw_biome = 0, draw_alt = 0, draw_water = 0,
        }

        -- XZ deferral of a village slot: the footprint of the drawn
        -- building crosses outside the emerged area of the fragment,
        -- so its columns cannot be read yet. The whole attempt loop
        -- is resumed from the emerge callback, on a manual VoxelManip
        -- read of a generous window around the slot (the redrawn
        -- drawings must almost always fit it), with place_now: an
        -- accepted slot is placed right there on committed data (the
        -- vertical containment of dispatch_job still applies). This
        -- is the XZ counterpart of the vertical containment of the
        -- deferred queue below
        local function defer_slot(ctx)
            ctx.stats.deferred = ctx.stats.deferred + 1
            local slot = ctx.slot
            local m = 24
            local p1 = {x = slot.x - m, y = emin.y, z = slot.z - m}
            local p2 = {x = slot.x + m, y = emax.y, z = slot.z + m}
            if debug_placement then
                minetest.log("action", "[nativevillages] deferring village "
                    .. "slot at (" .. slot.x .. "," .. slot.z
                    .. "): footprint outside the fragment emerged area, "
                    .. "emerging it first")
            end
            minetest.emerge_area(p1, p2, function(_, _, remaining)
                if remaining > 0 then
                    return
                end
                local vm2 = minetest.get_voxel_manip()
                local e1, e2 = vm2:read_from_map(p1, p2)
                if not e1 then
                    return
                end
                local ctx2 = {
                    va = VoxelArea:new({MinEdge = e1, MaxEdge = e2}),
                    data = vm2:get_data(),
                    yfloor = e1.y, top = e2.y,
                    eminx = e1.x, eminz = e1.z, emaxx = e2.x, emaxz = e2.z,
                    stats = ctx.stats, queue = nil, place_now = true,
                    rng = ctx.rng, defs = ctx.defs, weight = ctx.weight,
                    slot = slot, defer = nil, tag = ctx.tag,
                }
                try_at(ctx2)
            end)
            return true -- handled: the slot must not be retried here
        end

        -- Scattered candidate sites, unchanged behaviour: the drawings,
        -- rotations and centres all come from the chunk seeded PRNG
        local scatter_ctx = {
            va = va, data = data, yfloor = minp.y, top = maxp.y,
            eminx = emin.x, eminz = emin.z, emaxx = emax.x, emaxz = emax.z,
            minp = minp, maxp = maxp,
            stats = stats, queue = queue, rng = prng,
            defs = registry, weight = total_weight, slot = nil,
        }

        for _ = 1, tries do
            try_at(scatter_ctx)
        end

        -- Village slots: every fragment processes the slots of the
        -- crossing village plans whose POINT it hosts (one host per
        -- slot, whatever the chunk generation order). The drawing of a
        -- slot is elected by the REAL ground of the slot through the
        -- very tests above, from a PRNG derived from the village plan
        -- alone (PcgRandom(plan.seed, plan.seq + slot index)), so a
        -- village is reproducible from its cell whatever fragment
        -- hosts its slots and whatever their order
        if V and villages_on and V.enabled then
            local civic_defs, civic_total = civic_registry()
            for _, cell in ipairs(V.cells_overlapping(minp, maxp)) do
                local plan = V.plan(cell.cx, cell.cz)
                if plan then
                    if debug_placement then
                        minetest.log("action", "[nativevillages] village zone ("
                            .. cell.cx .. "," .. cell.cz .. ") core=(" .. plan.nx
                            .. "," .. plan.nz .. ") slots=" .. #plan.slots
                            .. (plan.near_path and " near_path" or ""))
                    end
                    for i, slot in ipairs(plan.slots) do
                        if slot.x >= minp.x and slot.x <= maxp.x
                            and slot.z >= minp.z and slot.z <= maxp.z then
                            vstats.hosted = vstats.hosted + 1
                            vstats.tried = vstats.tried + 1
                            local srng = PcgRandom(plan.seed, plan.seq + i)
                            local function mkctx(defs, weight)
                                return {
                                    va = va, data = data,
                                    yfloor = emin.y, top = emax.y,
                                    eminx = emin.x, eminz = emin.z,
                                    emaxx = emax.x, emaxz = emax.z,
                                    stats = vstats, queue = queue,
                                    rng = srng, defs = defs, weight = weight,
                                    slot = slot, tag = " (village slot)",
                                    defer = defer_slot,
                                }
                            end
                            -- civic preference of the core slots: wells,
                            -- markets, ponds... are tried first, housing
                            -- stays the fallback of the same slot
                            local done = false
                            if slot.civic and civic_total > 0 then
                                done = try_at(mkctx(civic_defs, civic_total))
                            end
                            if not done then
                                try_at(mkctx(registry, total_weight))
                            end
                        end
                    end
                end
            end
        end


        -- One recap line per generated chunk (debug_placement) so the
        -- effect of the density setting is directly readable in
        -- debug.txt: how many sites were tried, how many were accepted
        -- and where the rejections went. The deferred count is derived
        -- synchronously from the queue (the spill test only reads the
        -- footprint against the fragment Y window), because the recap
        -- must be logged BEFORE the deferred placements start
        for _, job in ipairs(queue) do
            if job.box.y1 < minp.y or job.box.y2 > maxp.y then
                stats.deferred = stats.deferred + 1
            end
        end
        if debug_placement then
            minetest.log("action", "[nativevillages] chunk (" .. minp.x .. ","
                .. minp.z .. ") fragment=" .. csize .. "x"
                .. (maxp.z - minp.z + 1) .. "x" .. (maxp.y - minp.y + 1)
                .. ": sites tried=" .. tries
                .. " accepted=" .. stats.accepted
                .. " deferred=" .. stats.deferred
                .. " | site rejections: no_drawing=" .. stats.no_match
                .. " not_flat=" .. stats.not_flat
                .. " collision=" .. stats.collision
                .. " too_wide=" .. stats.too_wide
                .. " | failed draws: ground=" .. stats.draw_ground
                .. " biome=" .. stats.draw_biome
                .. " altitude=" .. stats.draw_alt
                .. " open_water=" .. stats.draw_water)
        end

        if debug_placement then
            minetest.log("action", "[nativevillages] chunk (" .. minp.x .. ","
                .. minp.z .. ") village slots: hosted=" .. vstats.hosted
                .. " tried=" .. vstats.tried
                .. " accepted=" .. vstats.accepted
                .. " | slot rejections: no_drawing=" .. vstats.no_match
                .. " not_flat=" .. vstats.not_flat
                .. " collision=" .. vstats.collision
                .. " too_wide=" .. vstats.too_wide
                .. " deferred=" .. vstats.deferred
                .. " | failed draws: ground=" .. vstats.draw_ground
                .. " biome=" .. vstats.draw_biome
                .. " altitude=" .. vstats.draw_alt
                .. " open_water=" .. vstats.draw_water)
        end

        -- Deferred placements of this chunk: executed on the next server
        -- step, once the generated chunk has been committed to the map.
        -- run_job / dispatch_job are module level, shared with the
        -- deferred village slots placed by defer_slot
        if #queue > 0 then
            minetest.after(0, function()
                for _, job in ipairs(queue) do
                    dispatch_job(job, minp.y, maxp.y)
                end
            end)
        end
    end)
end


