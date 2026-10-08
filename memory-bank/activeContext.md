# Active Context - Native Villages Development

## Current Work Focus

### Primary Objectives
- Maintain and enhance existing village generation systems
- Ensure compatibility with latest Minetest versions
- Optimize performance for large world generation
- Expand biome coverage and content variety

### Active Development Areas
- **Biome Expansion**: Adding new village types and creature variants
- **Performance Optimization**: Reducing generation time and memory usage
- **Bug Fixes**: Addressing reported issues with spawning and structures
- **Code Quality**: Refactoring legacy code to follow current standards

## Recent Changes

### Latest Updates (v1.5)
- Enhanced desert village generation with new building variants
- Improved creature AI for more realistic behaviors
- Added localization support for additional languages
- Optimized schematic loading for faster world generation
- Performance optimizations and bug fixes
- Added jungle biome with tribal villages and appropriate flora
- Extended woodland mansions to most biomes (deciduous_forest, coniferous_forest, grassland, savanna, rainforest, and their variants)

### API Audit Fixes (Current)
- **Crash fixes**: desertcreatures.lua egg throwing now uses `obj:set_velocity()` / `obj:set_acceleration()` (removed pre-5.x `setvelocity`/`setacceleration`)
- **Dependency fix**: `stainedglass` renamed to `stained_glass` (actual node prefix used by buildings)
- **Modernization**: migrated depends.txt to mod.conf (title, description, depends, optional_depends incl. extra_biomes, min_minetest_version = 5.0); depends.txt and intllib.lua deleted
- **intllib purge**: all files now use `local S = minetest.get_translator("nativevillages")` (init.lua, arcticcreatures.lua, buyablestuff.lua x3); `mobs.intllib` assignment removed
- **Spawn fixes**: restored `chance = 15000` on 24 mobs:spawn calls (5 files); explodingtoad.lua fixed (`day_toggle`, `explosion_damage_radius`, merged `nodes` table incl. ethereal nodes, `type = "npc"`)
- **Table fixes**: merged duplicate `sounds` keys (savannacreatures.lua, explodingtoad.lua); fixed out-of-table `fly_in` in buyablestuff.lua; `is_ground_content = false` for egg node
- **Out of scope (unchanged)**: villages.lua stays unloaded (dead code, missing .mts), schems/ library untouched

### Woodland Mansion Fixes (Current)
- **RNG Parameter Issue**: Fixed "attempt to index local 'rng' (a number value)" error in woodland_mansion_create_start
- **Mock RNG Implementation**: Modified create_start function to use compatibility layer's mock RNG consistently
- **Parameter Isolation**: Changed function to ignore potentially incorrect rng parameter and use internal mock RNG
- **Method Consistency**: Ensured mock RNG has all required methods (next, next_within, next_boolean, next_integer)

### Biome-Adaptive Building Soil (2026-10-08, IMPLÉMENTÉ — tests en jeu en attente)
- **Fonctionnalité implémentée** conformément à plans/proposition-sol-biomes.md (§0 « Statut d'implémentation », numéros de ligne vérifiés) : nouveau module `soil_replacement.lua` (`nativevillages.soil`) + remontée du biome d'ancrage dans placement.lua jusqu'au 4ᵉ argument `replacement` de `minetest.place_schematic`
- **Fichiers touchés** : soil_replacement.lua (créé) ; placement.lua (modifié : `biome_name_at()`/`biome_ok()` retournent le nom du biome, `accept_site()` stocke `job.biome_name`, table de remplacement passée au placement différé) ; init.lua (dofile entre biomes.lua et placement.lua) ; settingtypes.txt (`nativevillages.adapt_soil`, défaut true)
- **Sources remplacées** : `default:dirt_with_grass` (famille grassland), `default:dry_dirt_with_dry_grass` (famille savanna, ajout issu de l'audit des .mts), `mcl_core:dirt_with_grass` (sémantique Mineclonia, ignoré sous MTG) ; remplissages de fondations (`dirt`, `dry_dirt`, `desert_sand`, `snowblock`) volontairement exclus (risque de colonnes pleine hauteur)
- **Résolution de la cible** : `node_top` du biome réel enregistré (biomes tiers ethereal/ebiomes inclus, sable du lit pour les ancres water, neige pour ice), puis fallback par catégorie logique (miroir de `ground_base` de biomes.lua), sinon sol intact ; table mise en cache par biome (cache négatif via `false`)
- **Écart unique vs spéc §4.2** : source savanna `default:dry_dirt_with_dry_grass` ajoutée (audit §5.1 du plan) ; **limitation documentée** : mode historique (`use_new_placement = false`) non couvert ; syntaxe validée (`texluac -p` → SYNTAX OK)
- **Prochaine étape** : tests en jeu selon la matrice §5.3 du plan (biomes MTG nominaux, biomes tiers, frontières de biome, rotations, régression `adapt_soil = false`)

### Multi-Point Biome Sampling — Itération 2 (2026-10-08, IMPLÉMENTÉ — tests en jeu en attente)
- **Fonctionnalité implémentée** conformément à plans/proposition-sol-biomes-echantillonnage.md (§0 « Statut d'implémentation », numéros de ligne vérifiés sur les fichiers réels) : le biome décidant du sol est désormais **élu par échantillonnage 3×3 de l'emprise réelle post-rotation**, et non plus mesuré au seul point d'ancre
- **Fichiers touchés** : soil_replacement.lua (AJOUT : `S.elect(votes, anchor_biome, accepted_set)`, fonction pure ≈ l.95-143 — majorité relative, l'ancre gagne les égalités, fallback ancre, filtrage optionnel sur un ensemble) ; placement.lua (MODIF : branche water ≈ l.748-781 — grille 3×3 à `bed_y` constant, élection filtrée sur `def.biome_set` ; branche ground ≈ l.872-913 — grille 3×3 à la surface réelle de chaque point après `flat`, élection ouverte ; log debug « soil biome elected X over anchor Y » dans les deux branches) ; `accept_site`, job, `minetest.after`, `place_schematic` inchangés — `job.biome_name` porte le biome élu
- **Comportement livré** : site homogène → élu = ancre → identique itération 1 ; frontière → biome dominant ; égalité → ancre ; poche atypique contenant l'ancre → corrigée par les 8 autres votes ; ancres water jamais d'herbe sous l'eau (votes filtrés) ; `adapt_soil = false` → l'élection tourne (choix assumé §4.7) mais `replacement_for` retourne nil → comportement historique ; coût +9 `get_biome_data` sur sites acceptés uniquement
- **Vérifications** : `texluac -p` → SYNTAX OK (2 fichiers) ; harnais hors jeu (texlua + stubs minetest, nettoyé ensuite) : 15 tests `S.elect` couvrant la matrice §5.2 — tous passés ; commentaires d'origine conservés (harmonisation annulée par l'utilisateur) ; précision : un vote nil n'entre jamais dans la table (`votes[#votes+1] = nil` est un no-op Lua, sémantiquement équivalent au §4.4)
- **Prochaine étape** : tests en jeu selon la matrice §5.2 du plan d'échantillonnage (régression ancre unique, frontières 5/4 et 4/4 + ancre, bâtiments lake sur berge, rotations, biomes tiers, poches atypiques, opt-out)

### Biome Mapping Integration (Current)
- **Extra Biomes Compatibility**: Created mapping system to use extra_biomes mod for enhanced village generation
- **Biome Conversion**: Mapped Mineclonia biomes to extra_biomes equivalents:
  - Lake villages: cold_deciduous_forest, grassland extensions
  - Jungle villages: japanese_rainforest, swamp with bog
  - Grassland villages: dry_grassland, deciduous_forest extensions
  - Savanna villages: humid_savanna for richer content
- **Dynamic Loading**: Implemented automatic biome conversion in villages.lua
- **Fallback System**: Maintains compatibility when extra_biomes is not installed

### Enhanced Block Mapping (Current)
- **More Blocks Integration**: Extended mapping to use moreblocks for advanced building shapes
- **More Trees Integration**: Added moretrees support for diverse wood types and tree species
- **Improved Construction**: Better variety in stairs, slabs, and decorative blocks
- **Wood Diversity**: 13 different tree types from moretrees for richer village aesthetics

### Code Quality Improvements
- Standardized Lua indentation and naming conventions
- Added comprehensive error handling with pcall()
- Implemented proper namespace usage (nativevillages:*)
- Enhanced documentation and code comments

## Next Steps

### Immediate Priorities
1. **Testing Phase**: Validate all biome implementations in Minetest environment, including the biome-adaptive building soil (itération 1 : plans/proposition-sol-biomes.md §5.3 matrix) and the multi-point elected biome (itération 2 : plans/proposition-sol-biomes-echantillonnage.md §5.2 matrix)
2. **Performance Profiling**: Identify and optimize bottleneck areas
3. **Documentation Update**: Ensure all new features are properly documented
4. **Community Feedback**: Address issues reported by users

### Medium-term Goals
- Expand jungle biome content with additional structures
- Implement seasonal variations for village appearances
- Add configurable generation parameters
- Create comprehensive testing framework

## Active Decisions and Considerations

### Technical Decisions
- **API Compatibility**: Maintain support for Minetest 5.x while preparing for 6.x
- **Mod Dependencies**: Keep external dependencies minimal (mobs); localization via minetest.get_translator (intllib purged)
- **Performance vs Features**: Balance rich content with generation speed
- **Code Organization**: Maintain biome-specific file structure

### Design Considerations
- **Cultural Accuracy**: Research and implement authentic architectural styles
- **Gameplay Balance**: Ensure villages enhance rather than disrupt gameplay
- **Accessibility**: Make content discoverable without being overwhelming
- **Extensibility**: Design system to easily add new biomes and content

## Important Patterns and Preferences

### Code Style
- Use 4-space indentation consistently
- Prefer local variables over globals
- Implement error handling for critical operations
- Document complex functions with detailed comments

### Naming Conventions
- Biome-specific files: `{biome}{type}.lua` (e.g., desertbuildings.lua)
- Entity names: `nativevillages:{biome}_{entity}_{variant}`
- Function names: descriptive, lowercase with underscores

### Development Workflow
- Test changes in isolated Minetest environment
- Validate performance impact before committing
- Update localization files for new strings
- Document breaking changes in release notes

## Learnings and Project Insights

### Performance Insights
- Schematic complexity directly impacts generation time
- Entity spawning should be conditional based on biome requirements
- Memory usage scales with number of registered decorations
- World generation benefits from asynchronous processing

### Architecture Lessons
- Modular design enables easier maintenance and expansion
- Separation of content (blocks, creatures, buildings) improves organization
- Configuration tables make parameters easily adjustable
- Error boundaries prevent single failures from breaking entire systems

### Community Feedback
- Players appreciate variety in village layouts
- Realistic creature behaviors enhance immersion
- Performance issues are major pain points
- Clear documentation improves mod adoption
