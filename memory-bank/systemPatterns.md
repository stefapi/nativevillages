# System Patterns - Native Villages Architecture

## System Architecture

### Core Components
```
Native Villages Mod
├── init.lua (Main entry point)
├── villages.lua (Village generation logic)
├── Biome-specific modules
│   ├── {biome}blocks.lua (Blocks and items)
│   ├── {biome}buildings.lua (Building schematics)
│   └── {biome}creatures.lua (Creatures and entities)
├── Support modules
│   ├── biomes.lua (Biome resolution layer)
│   ├── soil_replacement.lua (Biome-adaptive schematic ground)
│   ├── placement.lua (Flatness-aware placement engine)
│   ├── intllib.lua (Internationalization)
│   ├── buyablestuff.lua (Trading system)
│   └── hunger.lua (Hunger mechanics)
└── Assets
    ├── schematics/ (Building templates)
    ├── models/ (3D models)
    ├── textures/ (Visual assets)
    └── sounds/ (Audio assets)
```

### Data Flow Architecture
1. **World Generation Phase**
   - Minetest engine triggers decoration registration
   - Biome detection determines content type
   - Schematic placement with rotation and positioning
   - Entity spawning based on biome conditions

2. **Runtime Phase**
   - Entity behaviors execute via callbacks
   - Player interactions trigger events
   - Trading systems handle NPC interactions
   - Sound and particle effects enhance immersion

## Key Technical Decisions

### Modular Architecture
- **Biome Separation**: Each biome has dedicated files for blocks, buildings, and creatures
- **Functional Decomposition**: Clear separation between generation, entities, and gameplay
- **Namespace Isolation**: All content prefixed with `nativevillages:` to prevent conflicts

### Schematic Soil Adaptation (implemented 2026-10-08; multi-point election added same day, iteration 2)
- **Multi-point biome election (iteration 2)**: the biome carried by `job.biome_name` is elected by `S.elect(votes, anchor_biome, accepted_set)` — a pure, unit tested function of soil_replacement.lua — from 9 votes collected on the 3×3 grid of the real rotated footprint (same grid positions as the flatness test; water anchors vote at the constant `bed_y`, ground anchors at each point's real surface) ; relative majority, the anchor biome wins ties and is the fallback; **water anchored buildings filter votes on `def.biome_set`** (never grass under water), ground anchored ones vote open. Cost: +9 `get_biome_data` on accepted sites only
- **Declarative replacement table**: `nativevillages.soil` (soil_replacement.lua) resolves the elected biome surface node (`node_top` of `minetest.registered_biomes`, per-category fallback via biomes.lua `category_of`) and caches a `{source = target}` table per biome (negative answers cached via `false`)
- **Engine-native application**: the table feeds the 4th `replacement` argument of `minetest.place_schematic` in placement.lua (elected biome name carried by `job.biome_name`) — replacement happens during .mts decoding, zero extra map writes
- **Opt-out setting**: `nativevillages.adapt_soil` (default true) restores the historical untouched soils (the election still runs, `replacement_for` then returns nil); the historical decoration mode (`use_new_placement = false`) is not covered (documented limitation, see plans/proposition-sol-biomes.md §0/§5.4 and plans/proposition-sol-biomes-echantillonnage.md §4.9)

### Performance Optimizations
- **Lazy Loading**: Schematics loaded only when needed during generation
- **Conditional Spawning**: Creatures spawn based on probability and biome requirements
- **Memory Management**: Large assets streamed rather than preloaded
- **Error Boundaries**: Pcall() usage prevents single failures from crashing generation

### API Integration Patterns
- **Decoration System**: Uses `minetest.register_decoration()` for natural placement
- **Entity Framework**: Extends mobs API for creature behaviors
- **Schematic Engine**: Leverages `minetest.place_schematic()` for structure placement
- **Internationalization**: Intllib integration for multi-language support

## Design Patterns

### Factory Pattern for Entities
```lua
-- Pattern: Entity factory functions create variants
local function create_villager_variant(base_properties, variant_modifiers)
    local properties = table.copy(base_properties)
    for key, modifier in pairs(variant_modifiers) do
        properties[key] = modifier
    end
    return properties
end
```

### Configuration Table Pattern
```lua
-- Pattern: Centralized configuration tables
local village_config = {
    desert = {
        building_density = 0.0001,
        creature_types = {"trader", "guard", "villager"},
        height_range = {y_min = 0, y_max = 50}
    }
}
```

### Callback Registration Pattern
```lua
-- Pattern: Standardized callback registration
local function register_entity_callbacks(entity_name, callbacks)
    for callback_name, callback_func in pairs(callbacks) do
        minetest.register_entity(":" .. entity_name, {
            [callback_name] = callback_func
        })
    end
end
```

### Inheritance via Metatables
```lua
-- Pattern: Entity inheritance for shared behaviors
local base_creature = {
    on_activate = function(self, staticdata)
        -- Common activation logic
    end
}

local specific_creature = setmetatable({
    on_punch = function(self, puncher)
        -- Specific behavior
    end
}, {__index = base_creature})
```

## Component Relationships

### Village Generation System
- **villages.lua**: Orchestrates overall village placement
- **Biome modules**: Provide content-specific implementations
- **Schematics**: Pre-built structures with metadata
- **Decorations**: Registered placement rules

### Entity Management System
- **Creature modules**: Define entity properties and behaviors
- **Mobs API**: Provides core entity functionality
- **Sound system**: Manages audio assets and playback
- **AI system**: Handles creature decision-making

### Content Management System
- **Blocks registry**: Manages custom block definitions
- **Items registry**: Handles craftable and collectible items
- **Models system**: 3D model loading and caching
- **Textures system**: Visual asset management

## Critical Implementation Paths

### World Generation Flow
1. Engine calls decoration function
2. Biome detection and validation
3. Schematic selection based on probability
4. Position calculation with collision avoidance
5. Structure placement with rotation
6. Entity spawning in appropriate locations
7. Post-placement cleanup and optimization

### Entity Lifecycle
1. Registration during mod loading
2. Spawning during world generation or runtime
3. Activation and initialization
4. Behavior execution via step callbacks
5. Interaction handling (punch, right-click)
6. Despawning or persistence management

### Player Interaction Flow
1. Player approaches village/entity
2. Proximity triggers activation
3. Interaction options presented
4. Trading or combat systems engaged
5. State changes and persistence
6. Audio/visual feedback provided

## Error Handling Patterns

### Graceful Degradation
- Failed schematic loads fall back to simpler structures
- Missing assets use default placeholders
- Performance issues trigger reduced feature sets
- Network errors retry with exponential backoff

### Logging and Debugging
- Comprehensive logging for generation events
- Performance metrics collection
- Error context preservation
- Debug modes for development testing

## Performance Considerations

### Memory Optimization
- Asset streaming prevents memory bloat
- Entity pooling for frequently used objects
- Garbage collection hints for large operations
- Cache management for repeated calculations

### CPU Optimization
- Asynchronous generation where possible
- Batching of similar operations
- Early exit conditions for invalid states
- Profiling hooks for performance monitoring
