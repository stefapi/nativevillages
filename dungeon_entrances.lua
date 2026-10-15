-- Hidden randungeon entrances inside village houses -- "option E: piloted
-- spiral" of plans/proposition-integration-randungeon.md section 4.
--
-- When the optional randungeon mod is installed, a deterministic minority
-- of the placed houses receive a secret: the 4 steel trapdoors of a
-- randungeon spiral staircase, flush with the house floor, with nothing
-- visible above it. Without randungeon, or when the master setting is
-- disabled, this module is a complete silent no-op.
--
-- Vertical calibration (constants verified in the randungeon sources):
--   * make_dungeon builds level 1 (the topmost one) at
--     level_pos.y = pos.y - dungeon_top_deph
--     (build_dungeon_from_blocks.lua:1103; the level 1 map carries
--     top_deph = dungeon_top_deph, l.1080-1081)
--   * the level 1 top staircase is built with
--     staircase_height = dungeon_maps[1].top_deph (l.1114), and
--     build_dungeon_stairs raises its trapdoor platform to
--     tile_pos.y + deph + 3 (l.458), i.e. ALWAYS to pos.y + 3:
--     under a house the automatic truncation (l.401-440) can never
--     trigger (every slice of the foundation is ground content in
--     natural darkness < 6, l.412-414), so deph stays dungeon_top_deph
--   * pos.y = floor_y - 3 therefore lands the 4 trapdoors EXACTLY at
--     the house floor level, while the wall ring of the shaft stays
--     confined in the foundation at pos.y+1..pos.y+2 = F-2..F-1:
--     nothing emerges above the floor, nothing to clean up
--
-- XZ piloting through the official hook:
--   * randungeon.dungeon_prebuild_modifications (randungeon init.lua:11,
--     called at build_dungeon_from_blocks.lua:1096) receives the dungeon
--     maps BEFORE the build; the surface stair of a tile is only the
--     pair of fields map[x][z].stair_position / stair_orientation
--     (bands {1,2}|{9,10} x {3,4}|{7,8} of the 10x10 tile,
--     l.383-400, tile corner pos + (tx-1)*10 at l.949)
--   * our prebuild callback erases the stair fields of EVERY tile of
--     dungeon_maps[1] (no natural emergence anywhere else in the
--     village), then sets them on the tile whose candidate 2x2 hole
--     scores best inside the house (deterministic scoring on the real
--     nodes: distance to the scanned target + penalties for furniture,
--     walls or missing floor), and pre-carves the 4 floor nodes of the
--     elected hole to air so randungeon itself places its 4
--     doors:trapdoor_steel there (l.459 only trapdoors air nodes)
--
-- The callback is SELECTIVE: it does nothing for dungeons it did not
-- order (natural randungeon dungeons included). make_dungeon blocks the
-- server for ~0.5-2 s, so it is NEVER called from the placement flow:
-- eligible houses only enqueue an item, and a serial FIFO worker chained
-- by minetest.after builds one dungeon at a time (the next item starts
-- from the postbuild callback, or from a watchdog when a build silently
-- aborted).
--
-- Anti-double generation, three layers:
--   1. this mod's persistent registry (mod storage) of the ordered
--      dungeon centres + a minimum entrance distance: a site is never
--      retried, whatever happened to the build
--   2. an AABB overlap test against randungeon.dungeons (the p1/p2
--      boxes of every dungeon of the world, natural ones included)
--   3. the dedicated dungeon_id "nativevillages_<job pos>":
--      randungeon itself aborts a repeated id inside the session
--      (build_dungeon_from_blocks.lua:1003-1009)

nativevillages = nativevillages or {}

local D = {}
nativevillages.dungeon = D

-- Inert probe, the village_zones.lua:117 convention. CAUTION: because of
-- the mod name order ("nativevillages" sorts before "randungeon"), the
-- randungeon TABLE does not exist yet when this file is loaded; only the
-- installed flag is probed here and the global is resolved lazily at
-- runtime (by the time a house is placed, every mod is long loaded)
local rd_installed = minetest.get_modpath("randungeon") ~= nil

local function RD()
    return rd_installed and randungeon or nil
end

-- Settings (see settingtypes.txt), clamped to their documented bounds
local enabled_setting = minetest.settings:get_bool(
    "nativevillages.randungeon_entrances", true)
local chance = tonumber(minetest.settings:get(
    "nativevillages.randungeon_entrance_chance") or "") or 0.2
if chance < 0 then
    chance = 0
elseif chance > 1 then
    chance = 1
end
local levels = tonumber(minetest.settings:get(
    "nativevillages.randungeon_entrance_levels") or "") or 3
levels = math.floor(levels)
if levels < 1 then
    levels = 1
elseif levels > 8 then
    levels = 8
end

-- World seed, read once at load (village_zones.lua convention): part of
-- the deterministic draw of which houses carry an entrance
local SEED = tonumber(minetest.get_mapgen_setting("seed") or "") or 0

-- Registered names of the eligible houses. The jungle houses register as
-- junglehouse1-3 (junglebuildings.lua) although their schematic FILES are
-- named cannibalhouse*; both prefixes are accepted defensively. Lake
-- houses (_0_ water anchor) and every civic building are excluded, and
-- the "_30_" foundation test below excludes them a second time
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

-- randungeon constants of the hidden dungeons, the natural generation
-- values (natural_generation.lua:70-83): a small width 3 dungeon (a
-- 30x30 zone) with the default 12 node level spacing, 100 bottom and
-- 250 top deph
local DUNGEON_WIDTH = 3
local DUNGEON_DEPH = 12
local DUNGEON_BOTTOM_DEPH = 100
local DUNGEON_TOP_DEPH = 250
local CAVE_PERCENTAGE = 30
local TREASURE_BLOCK = "randungeon:dungeon_treasure"

-- Minimum XZ distance in nodes between two hidden entrances (design doc
-- default, no setting: bounds the number of dungeons per village)
local MIN_ENTRANCE_DISTANCE = 48

-- Seconds after which an ordered entrance that never signalled its
-- postbuild (silently aborted id, failed emerge) is given up and the
-- queue moves on
local WATCHDOG_DELAY = 120

-- Serial FIFO state: make_dungeon is blocking, ONE dungeon at a time
local queue = {}    -- pending items, maybe_place_hidden_entrance fills it
local busy = false  -- true from the make_dungeon call to its postbuild
local pending = {}  -- pos_to_string(dungeon pos) -> item (hook selectivity)
local hooks_registered = false

-- Persistent registry of the ordered dungeon centres (XZ), one
-- "x,z" pair per ";" separated entry (the placement.lua storage style:
-- small strings, never deserialized globally)
local storage = minetest.get_mod_storage()
local REGISTRY_KEY = "dungeon_entrance_centers"

local centers = {}
do
    local raw = storage:get_string(REGISTRY_KEY)
    for field in raw:gmatch("[^;]+") do
        local x, z = field:match("^(-?%d+),(-?%d+)$")
        if x and z then
            centers[#centers + 1] = {x = tonumber(x), z = tonumber(z)}
        end
    end
end

local function persist_centers()
    local parts = {}
    for _, c in ipairs(centers) do
        parts[#parts + 1] = c.x .. "," .. c.z
    end
    storage:set_string(REGISTRY_KEY, table.concat(parts, ";"))
end

local function add_center(dpos)
    centers[#centers + 1] = {x = dpos.x + 15, z = dpos.z + 15}
    persist_centers()
end

local function too_close(dpos)
    local cx, cz = dpos.x + 15, dpos.z + 15
    for _, c in ipairs(centers) do
        local dx, dz = c.x - cx, c.z - cz
        if dx * dx + dz * dz < MIN_ENTRANCE_DISTANCE * MIN_ENTRANCE_DISTANCE then
            return true
        end
    end
    return false
end

-- AABB of OUR dungeon (the very area randungeon emerges and builds in,
-- build_dungeon_from_blocks.lua:991-992 and 1026-1027) against the p1/p2
-- box of every dungeon randungeon knows (natural ones included)
local function overlaps_existing(dpos)
    local rd = RD()
    if not rd or type(rd.dungeons) ~= "table" then
        return false
    end
    local total = DUNGEON_TOP_DEPH + DUNGEON_BOTTOM_DEPH
        + (levels - 1) * DUNGEON_DEPH
    local a1 = {
        x = dpos.x - 60,
        y = dpos.y - total - 60,
        z = dpos.z - 60,
    }
    local a2 = {
        x = dpos.x + DUNGEON_WIDTH * 10 + 60,
        y = dpos.y + 150,
        z = dpos.z + DUNGEON_WIDTH * 10 + 60,
    }
    for _, d in pairs(rd.dungeons) do
        local b1, b2 = d.p1, d.p2
        if type(b1) == "table" and type(b2) == "table"
            and a1.x <= b2.x and a2.x >= b1.x
            and a1.y <= b2.y and a2.y >= b1.y
            and a1.z <= b2.z and a2.z >= b1.z then
            return true
        end
    end
    return false
end

-- Node predicates, conservative on unknown nodes like spawn.lua
local function is_walkable(name)
    if name == "ignore" then
        return false
    end
    local def = minetest.registered_nodes[name]
    return def ~= nil and def.walkable == true
end

local function is_open(name)
    if name == "ignore" then
        return false
    end
    local def = minetest.registered_nodes[name]
    return def ~= nil and not def.walkable
end

-- Foundation offset of the placed schematic, derived from its FILE
-- NAME (the placement registry holding the real def.offset is local to
-- placement.lua and the job does not carry it): the _30_ foundation
-- schematics anchor with offset -4 (a shallow 4 node embed, see the
-- *buildings.lua data files), every eligible house of this mod is one
-- of them, hence the generic surface_y = box.y1 - def.offset =
-- box.y1 + 4. The value is only the SCAN CENTRE: the real map (the
-- walkable floor test below) wins over the approximation
local FOUNDATION_OFFSET = -4

-- Bed detector of the spawn layer (loaded before this module, see
-- init.lua), used by the floor scan to reject furniture: without it a
-- bed standing on the centre column would be elected as the "floor"
-- and the trapdoors would end up ON the bed
local Spawn = nativevillages.spawn

local function is_bed_node(name)
    return Spawn and Spawn.is_bed and Spawn.is_bed(name) or false
end

-- Real floor height of the house: first walkable node of the centre
-- column, scanning down around the schematic derived estimate
-- (box.y1 - offset, i.e. box.y1 + 4 on the shallow -4 embeds), that has
-- two open nodes above (the interior) and a walkable node below (floor
-- slab over the foundation: this rejects beds and chests standing on
-- the floor, which would otherwise be elected as the "floor"). The real
-- map wins over the y1+4 approximation (design doc section 4.1)
local function scan_floor_y(box, offset)
    local cx = math.floor((box.x1 + box.x2) / 2)
    local cz = math.floor((box.z1 + box.z2) / 2)
    local y0 = box.y1 - (offset or FOUNDATION_OFFSET)
    for y = y0 + 3, y0 - 5, -1 do
        local floor_name = minetest.get_node({x = cx, y = y, z = cz}).name
        local above_name = minetest.get_node({x = cx, y = y + 1, z = cz}).name
        if is_walkable(floor_name) and not is_bed_node(floor_name)
            and not is_bed_node(above_name)
            and is_walkable(minetest.get_node({x = cx, y = y - 1, z = cz}).name)
            and is_open(above_name)
            and is_open(minetest.get_node({x = cx, y = y + 2, z = cz}).name) then
            return y
        end
    end
    return nil
end

-- Deterministic scan of a free 2x2 spot on the floor inside the house
-- (margin of 2 nodes from the walls). Ordered walk starting from a PRNG
-- drawn corner; returns the min corner of the first 2x2 whose 4 nodes
-- are walkable at F and open at F+1 and F+2, nil when the interior is
-- too small or fully furnished
local function scan_trap_hole(prng, box, F)
    local ix1, ix2 = box.x1 + 2, box.x2 - 2
    local iz1, iz2 = box.z1 + 2, box.z2 - 2
    local span_x = ix2 - ix1
    local span_z = iz2 - iz1
    if span_x < 1 or span_z < 1 then
        return nil
    end
    local sx = ix1 + prng:next(0, span_x - 1)
    local sz = iz1 + prng:next(0, span_z - 1)
    for dz = 0, span_z - 1 do
        for dx = 0, span_x - 1 do
            local hx = ix1 + (sx - ix1 + dx) % span_x
            local hz = iz1 + (sz - iz1 + dz) % span_z
            local ok = true
            for ox = 0, 1 do
                for oz = 0, 1 do
                    local px, pz = hx + ox, hz + oz
                    if not is_walkable(minetest.get_node({x = px, y = F, z = pz}).name)
                        or not is_open(minetest.get_node({x = px, y = F + 1, z = pz}).name)
                        or not is_open(minetest.get_node({x = px, y = F + 2, z = pz}).name) then
                        ok = false
                        break
                    end
                end
                if not ok then
                    break
                end
            end
            if ok then
                return {x = hx, z = hz}
            end
        end
    end
    return nil
end

-- forward declaration of the serial worker: postbuild (below) and the
-- queue restarts chain it, but it is only defined further down
local pump

--
-- randungeon hooks (prebuild: piloting, postbuild: completion signal).
-- Both are wrapped in a pcall shim: randungeon calls its modification
-- lists without protection (build_dungeon_from_blocks.lua:1096-1098 and
-- 1139-1141), an error in a third party callback must never break the
-- dungeon build.
--

local function prebuild(pos, dungeon_maps)
    local key = minetest.pos_to_string(pos)
    local item = pending[key]
    if not item then
        return -- not one of ours (natural dungeon): strictly no-op
    end
    local map = dungeon_maps and dungeon_maps[1]
    if type(map) ~= "table" or type(map[1]) ~= "table" then
        minetest.log("warning", "[nativevillages] dungeon prebuild: "
            .. "unexpected level 1 map, dungeon left unmodified")
        return
    end

    -- Enumerate the candidate 2x2 holes: every non empty tile of the
    -- width 3 map x its OPEN directions (a closed one would seal the
    -- shaft: the stair tile must open towards its own corridor) x the 2
    -- orientations of the perpendicular axis. The hole offsets in the
    -- 10x10 tile come from the fixed bands of build_dungeon_stairs
    -- (l.383-400): stair_position pins one axis on {1,2}|{9,10},
    -- stair_orientation pins the other on {3,4}|{7,8}
    local best = nil
    for tx = 1, DUNGEON_WIDTH do
        local column = map[tx]
        if type(column) == "table" then
            for tz = 1, DUNGEON_WIDTH do
                local tile = column[tz]
                if type(tile) == "table" and not tile.empty_spot then
                    local base_x = pos.x + (tx - 1) * 10
                    local base_z = pos.z + (tz - 1) * 10
                    local dirs = {"x_minus", "x_plus", "z_minus", "z_plus"}
                    for _, dir in ipairs(dirs) do
                        if tile[dir] then
                            local orients = dir:sub(1, 1) == "x"
                                and {"z_minus", "z_plus"}
                                or {"x_minus", "x_plus"}
                            for _, orient in ipairs(orients) do
                                local hx, hz
                                if dir == "x_minus" then
                                    hx = 1
                                elseif dir == "x_plus" then
                                    hx = 9
                                elseif dir == "z_minus" then
                                    hz = 1
                                else
                                    hz = 9
                                end
                                if orient == "x_minus" then
                                    hx = 3
                                elseif orient == "x_plus" then
                                    hx = 7
                                elseif orient == "z_minus" then
                                    hz = 3
                                else
                                    hz = 7
                                end
                                local hole = {x = base_x + hx, z = base_z + hz}
                                -- deterministic scoring on the REAL nodes:
                                -- squared distance to the scanned target
                                -- plus penalties (walls and furniture
                                -- above the hole, missing floor under
                                -- it); strict < keeps the first of equal
                                -- scores, the enumeration order is fixed
                                local sdx = hole.x - item.target.x
                                local sdz = hole.z - item.target.z
                                local score = sdx * sdx + sdz * sdz
                                local valid = true
                                for ox = 0, 1 do
                                    for oz = 0, 1 do
                                        local px, pz = hole.x + ox, hole.z + oz
                                        local nf = minetest.get_node(
                                            {x = px, y = item.floor_y, z = pz}).name
                                        local n1 = minetest.get_node(
                                            {x = px, y = item.floor_y + 1, z = pz}).name
                                        local n2 = minetest.get_node(
                                            {x = px, y = item.floor_y + 2, z = pz}).name
                                        if nf == "ignore" or n1 == "ignore"
                                            or n2 == "ignore" then
                                            valid = false
                                        else
                                            if not is_walkable(nf) then
                                                score = score + 100
                                            end
                                            if is_walkable(n1) then
                                                score = score + 25
                                            end
                                            if is_walkable(n2) then
                                                score = score + 25
                                            end
                                        end
                                    end
                                end
                                if valid and (not best or score < best.score) then
                                    best = {
                                        score = score, tx = tx, tz = tz,
                                        dir = dir, orient = orient,
                                        hole = hole,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not best then
        -- pathological: not a single usable candidate; leave the natural
        -- stairs rather than blinding the dungeon with no entrance
        minetest.log("warning", "[nativevillages] dungeon prebuild: no "
            .. "stair candidate found for the entrance under "
            .. item.job_name .. ", dungeon left unmodified")
        return
    end

    -- 1. erase EVERY surface stair of level 1: the only emergence in
    --    the village will be the piloted one (dungeon_maps[1] is the
    --    topmost level, the only one whose staircases reach the
    --    surface; the deeper levels keep their internal stairs)
    for tx = 1, #map do
        if type(map[tx]) == "table" then
            for tz = 1, #map[tx] do
                local t = map[tx][tz]
                if type(t) == "table" then
                    t.stair_position = nil
                    t.stair_orientation = nil
                end
            end
        end
    end

    -- 2. pilot the elected tile. Stair tiles never carry a room, like
    --    the native generator tags them (make_dungeon_map.lua:328-334)
    local tile = map[best.tx][best.tz]
    tile.stair_position = best.dir
    tile.stair_orientation = best.orient
    tile.has_room = false

    -- 3. pre-carve the 4 floor nodes of the elected hole: randungeon
    --    only trapdoors AIR nodes (build_dungeon_from_blocks.lua:459),
    --    so it will place its 4 doors:trapdoor_steel right here, in its
    --    own style. The original nodes are remembered for the postbuild
    --    safety restore
    item.hole = best.hole
    item.saved = {}
    for ox = 0, 1 do
        for oz = 0, 1 do
            local p = {x = best.hole.x + ox, y = item.floor_y,
                z = best.hole.z + oz}
            local node = minetest.get_node(p)
            item.saved[#item.saved + 1] = {
                x = p.x, y = p.y, z = p.z,
                name = node.name, param2 = node.param2,
            }
            minetest.set_node(p, {name = "air"})
        end
    end
    minetest.log("action", "[nativevillages] dungeon entrance piloted: "
        .. "stair on tile (" .. best.tx .. "," .. best.tz .. ") "
        .. best.dir .. "/" .. best.orient .. ", hole 2x2 at ("
        .. best.hole.x .. "," .. item.floor_y .. "," .. best.hole.z
        .. "), score " .. best.score)
end

local function postbuild(pos)
    local key = minetest.pos_to_string(pos)
    local item = pending[key]
    if not item then
        return -- not one of ours: strictly no-op
    end
    -- the real build is over: free the queue whatever happens below
    pending[key] = nil
    busy = false

    -- verify the 4 steel trapdoors really sit at the floor level on the
    -- carved hole (a lit cave right under the foundation could in theory
    -- have truncated the staircase below the floor: build_dungeon_stairs
    -- would then have sealed the shaft with roof blocks instead)
    local trapdoors = 0
    if item.hole then
        for ox = 0, 1 do
            for oz = 0, 1 do
                if minetest.get_node({x = item.hole.x + ox, y = item.floor_y,
                    z = item.hole.z + oz}).name == "doors:trapdoor_steel" then
                    trapdoors = trapdoors + 1
                end
            end
        end
    end
    if trapdoors == 4 then
        minetest.log("action", "[nativevillages] randungeon entrance "
            .. "complete under " .. item.job_name .. ": house at ("
            .. item.house_pos.x .. "," .. item.house_pos.y .. ","
            .. item.house_pos.z .. ") -> dungeon at (" .. item.dpos.x
            .. "," .. item.dpos.y .. "," .. item.dpos.z
            .. ") -> 4 steel trapdoors at floor y=" .. item.floor_y)
    else
        minetest.log("warning", "[nativevillages] randungeon entrance "
            .. "under " .. item.job_name .. ": only " .. trapdoors
            .. "/4 trapdoors found at floor level, restoring the carved "
            .. "floor nodes")
        if item.saved then
            for _, s in ipairs(item.saved) do
                minetest.set_node({x = s.x, y = s.y, z = s.z},
                    {name = s.name, param2 = s.param2})
            end
        end
    end
    if #queue > 0 then
        minetest.after(0, pump)
    end
end

local function prebuild_safe(pos, dungeon_maps, materials, room_styles)
    local ok, err = pcall(prebuild, pos, dungeon_maps, materials, room_styles)
    if not ok then
        minetest.log("warning", "[nativevillages] dungeon prebuild hook "
            .. "failed: " .. tostring(err))
    end
end

local function postbuild_safe(pos, dungeon_maps, materials, room_styles)
    local ok, err = pcall(postbuild, pos, dungeon_maps, materials, room_styles)
    if not ok then
        minetest.log("warning", "[nativevillages] dungeon postbuild hook "
            .. "failed: " .. tostring(err))
    end
end

-- Registered ONCE and only while randungeon is actually loaded; the
-- lists exist since randungeon's own init.lua:11/:16, well before the
-- first house placement
local function register_hooks_once()
    if hooks_registered then
        return
    end
    local rd = RD()
    if not rd then
        return
    end
    if type(rd.dungeon_prebuild_modifications) == "table" then
        table.insert(rd.dungeon_prebuild_modifications, prebuild_safe)
    end
    if type(rd.dungeon_postbuild_modifications) == "table" then
        table.insert(rd.dungeon_postbuild_modifications, postbuild_safe)
    end
    hooks_registered = true
end

-- Give up on an item without any build coming (skip, abort or failure):
-- free the pending entry, restart the queue
local function finish_item(item, why)
    pending[minetest.pos_to_string(item.dpos)] = nil
    busy = false
    if why then
        minetest.log("action", "[nativevillages] randungeon entrance "
            .. "skipped for " .. item.job_name .. ": " .. why)
    end
    if #queue > 0 then
        minetest.after(0, pump)
    end
end

-- Serial worker: ONE dungeon at a time, never called from the placement
-- flow. The next item only starts from the postbuild of this one (or
-- the watchdog when the build silently died: aborted dungeon id, failed
-- emerge), because make_dungeon itself may return long before building
-- (it defers through emerge_area, build_dungeon_from_blocks.lua:1014-1020)
pump = function()
    if busy then
        return
    end
    local item = table.remove(queue, 1)
    if not item then
        return
    end
    busy = true

    -- re-probe randungeon: silent no-op if it vanished (should not)
    local rd = RD()
    if not rd or type(rd.make_dungeon) ~= "function"
        or type(rd.dungeons) ~= "table" then
        finish_item(item, nil)
        return
    end

    -- anti-double layer 3: randungeon's own session list aborts a
    -- repeated dungeon_id (build_dungeon_from_blocks.lua:1003-1009);
    -- check it ourselves so the queue does not wait for a postbuild
    -- that will never come
    if type(randungeon_finished_dungeons) == "table" then
        for _, finished_id in ipairs(randungeon_finished_dungeons) do
            if finished_id == item.id then
                finish_item(item, "dungeon id already built in this session")
                return
            end
        end
    end

    register_hooks_once()
    local key = minetest.pos_to_string(item.dpos)
    pending[key] = item

    -- randungeon only seeds dungeon_generation_started for RANDOM ids
    -- (build_dungeon_from_blocks.lua:1003-1009); seed it for our
    -- provided id or its final timing print (l.1184-1185) would do
    -- arithmetic on nil. Writing the value the mod expects is data, not
    -- a modification of randungeon
    if type(dungeon_generation_started) == "table" then
        dungeon_generation_started[item.id] = minetest.get_us_time() / 10000000
    end

    -- watchdog: if no postbuild ever signals the end
    minetest.after(WATCHDOG_DELAY, function()
        if pending[key] ~= item then
            return -- postbuild already came
        end
        pending[key] = nil
        busy = false
        minetest.log("warning", "[nativevillages] randungeon entrance "
            .. "under " .. item.job_name .. " never completed (no "
            .. "postbuild signal), giving up on it")
        if #queue > 0 then
            minetest.after(0, pump)
        end
    end)

    -- THE call, the exact natural generation profile
    -- (natural_generation.lua:70-83), only pos, width, levels and the
    -- dungeon id differ: pos.y = floor - 3 so the trapdoor platform
    -- lands exactly at the house floor (see the calibration notes in
    -- the header), width 3 = a 30x30 zone centred under the house
    local ok, err = pcall(rd.make_dungeon, item.dpos,
        DUNGEON_WIDTH,                    -- width 3 => 30x30 zone
        nil, nil, nil, nil, nil, nil,     -- materials: random
        DUNGEON_DEPH,                     -- 12, natural default
        true,                             -- rim_sealed
        levels,                           -- dungeon_levels (setting)
        DUNGEON_BOTTOM_DEPH,              -- 100, natural value
        DUNGEON_TOP_DEPH,                 -- 250, natural value
        true,                             -- random_materials
        CAVE_PERCENTAGE,                  -- 30, natural value
        false,                            -- light_up_corridors OFF:
                                          -- glowing air would flood the
                                          -- whole stair shaft
        true,                             -- gold_pools
        TREASURE_BLOCK,
        item.id)                          -- native de-duplication

    -- the ATTEMPT is registered for good, success or failure: this site
    -- is never offered again (anti-double layer 1)
    add_center(item.dpos)

    if not ok then
        minetest.log("warning", "[nativevillages] randungeon make_dungeon "
            .. "failed for " .. item.job_name .. ": " .. tostring(err)
            .. " (site registered, will not be retried)")
        -- nothing will come from a failed call: free the entry now
        if pending[key] == item then
            pending[key] = nil
            busy = false
            if #queue > 0 then
                minetest.after(0, pump)
            end
        end
        return
    end
    minetest.log("action", "[nativevillages] randungeon entrance ordered: "
        .. item.job_name .. " at (" .. item.house_pos.x .. ","
        .. item.house_pos.y .. "," .. item.house_pos.z .. ") -> dungeon at ("
        .. item.dpos.x .. "," .. item.dpos.y .. "," .. item.dpos.z
        .. "), trapdoor floor y=" .. item.floor_y)
end

-- Entry point, called by run_job() in placement.lua right after the
-- Spawn.populate pcall. Cheap: guards, the deterministic draw and the
-- two scans only, then the item is queued; the blocking make_dungeon
-- lives in the serial worker above
function D.maybe_place_hidden_entrance(job)
    -- complete no-op without randungeon or with the feature disabled:
    -- no error, no log
    if not rd_installed or not enabled_setting then
        return
    end
    local rd = RD()
    if not rd or type(rd.make_dungeon) ~= "function"
        or type(rd.dungeons) ~= "table" then
        return
    end
    if not job or not job.box or not job.name or not job.pos then
        return
    end

    -- eligible houses only: house name prefixes (this alone excludes
    -- every civic building: stable, market, well, tower, pond, blot,
    -- pit, cage, harbour, fishtrap, logs, pelts, sledge, altar...) and
    -- the _30_ foundation schematics (this excludes the water anchored
    -- lake houses a second time)
    if not is_house(job.name) then
        return
    end
    if type(job.schematic) ~= "string"
        or not job.schematic:find("_30_", 1, true) then
        return
    end

    local box = job.box

    -- un-emerged footprints are skipped silently (spawn.lua convention:
    -- get_node answers "ignore" there and the scans could not run)
    if minetest.get_node({x = box.x1, y = box.y1, z = box.z1}).name == "ignore"
        or minetest.get_node({x = box.x2, y = box.y2, z = box.z2}).name == "ignore" then
        return
    end

    -- deterministic draw: which houses carry an entrance is a pure
    -- function of (world seed, footprint), reproducible across
    -- regenerations of the same chunks
    local prng = PcgRandom(SEED, box.x1, box.y1, box.z1)
    if prng:next(0, 999999) / 999999 >= chance then
        return
    end

    -- calibration inputs: real floor level, free interior 2x2 spot
    local floor_y = scan_floor_y(box, FOUNDATION_OFFSET)
    if not floor_y then
        return
    end
    local target = scan_trap_hole(prng, box, floor_y)
    if not target then
        return -- fully furnished or tiny interior: silent give up
    end

    -- dungeon anchor: min corner of the 30x30 zone, aligned to CENTRE
    -- the zone under the house; pos.y = F - 3 (see header calibration)
    local dpos = {
        x = math.floor((box.x1 + box.x2) / 2) - 15,
        y = floor_y - 3,
        z = math.floor((box.z1 + box.z2) / 2) - 15,
    }

    -- anti-double layer 1: our persistent registry + min distance
    if too_close(dpos) then
        minetest.log("action", "[nativevillages] randungeon entrance "
            .. "skipped for " .. job.name .. ": another entrance lies "
            .. "closer than " .. MIN_ENTRANCE_DISTANCE .. " nodes")
        return
    end
    -- layer 2: overlap with any dungeon randungeon already knows
    if overlaps_existing(dpos) then
        minetest.log("action", "[nativevillages] randungeon entrance "
            .. "skipped for " .. job.name .. ": target area overlaps an "
            .. "existing randungeon dungeon")
        return
    end
    if rd.dungeons[minetest.pos_to_string(dpos)] then
        return
    end

    queue[#queue + 1] = {
        job_name = job.name,
        house_pos = {x = job.pos.x, y = job.pos.y, z = job.pos.z},
        dpos = dpos,
        floor_y = floor_y,
        target = target,
        id = "nativevillages_"
            .. minetest.pos_to_string({x = job.pos.x, y = job.pos.y, z = job.pos.z}),
    }
    if not busy then
        minetest.after(0, pump)
    end
end
