
-- Initialize nativevillages namespace
nativevillages = {}

local path = minetest.get_modpath(minetest.get_current_modname()) .. "/"

local S = minetest.get_translator("nativevillages")


-- Check for custom mob spawn file
local input = io.open(path .. "spawn.lua", "r")

if input then
	mobs.custom_spawn_nativevillages = true
	input:close()
	input = nil
end


-- Biome resolution layer (must load before the buildings files so that
-- nativevillages.biomes.get() / get_ground() are available)
dofile(path .. "biomes.lua") --

-- Soil adaptation of the placed schematics to the anchor biome (must load
-- after biomes.lua, which it consumes, and before placement.lua, which
-- consumes nativevillages.soil in turn)
dofile(path .. "soil_replacement.lua") --

-- Placement engine and building factory (must load before the buildings
-- files so that nativevillages.placement.register_building() is available)
dofile(path .. "placement.lua") --

-- Buildings


dofile(path .. "cannibalblocks.lua") --
dofile(path .. "savannablocks.lua") --
dofile(path .. "arcticblocks.lua") --
dofile(path .. "grasslandblocks.lua") --
dofile(path .. "lakeblocks.lua") --
dofile(path .. "desertblocks.lua") --
dofile(path .. "junglebuildings.lua") --
dofile(path .. "icebuildings.lua") --
dofile(path .. "grasslandbuildings.lua") --
dofile(path .. "lakebuildings.lua") --
dofile(path .. "desertbuildings.lua") --
dofile(path .. "savannabuildings.lua") --
dofile(path .. "grasslandcreatures.lua") --
dofile(path .. "junglecreatures.lua") --
dofile(path .. "arcticcreatures.lua") --
dofile(path .. "savannacreatures.lua") --
dofile(path .. "lakecreatures.lua") --
dofile(path .. "desertcreatures.lua") --
dofile(path .. "slavecreatures.lua") --
dofile(path .. "buyablestuff.lua") --
dofile(path .. "explodingtoad.lua") --
dofile(path .. "hunger.lua") --


-- Load custom spawning
if mobs.custom_spawn_nativevillages then
	dofile(path .. "spawn.lua")
end



print (S("[MOD] Buildings loaded"))
