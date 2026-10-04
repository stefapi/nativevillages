# Technical Context - Native Villages Development

## Technologies Used

### Core Technologies
- **Lua 5.1**: Primary programming language for Minetest mods
- **Minetest Engine**: Game engine and API (5.x+ compatibility)
- **Mobs API**: Entity and creature management framework
- **Intllib**: Internationalization and localization library

### Development Tools
- **Git**: Version control and collaboration
- **Luacheck**: Lua code linting and static analysis
- **Minetest Game**: Development and testing environment
- **Blender**: 3D model creation for entities and structures
- **GIMP/Photoshop**: Texture and image editing

### File Formats
- **.lua**: Source code files
- **.mts**: Minetest schematic files (building templates)
- **.b3d**: 3D model files (Blender format)
- **.png**: Texture and icon files
- **.ogg**: Audio files for creature sounds
- **.tr**: Translation files for localization

## Development Setup

### Environment Requirements
- **Minetest 5.0+**: Core engine for running and testing
- **Development World**: Isolated test world for validation
- **Mod Dependencies**: mobs, intllib (automatically handled)
- **System Resources**: Sufficient RAM for large world generation testing

### Project Structure
```
/home/stef/workspace/nativevillages/
├── Core Files
│   ├── init.lua          # Mod initialization
│   ├── mod.conf          # Mod configuration
│   └── depends.txt       # Dependencies list
├── Source Code
│   ├── villages.lua      # Main generation logic
│   ├── Biome files       # {biome}{type}.lua
│   └── Support files     # intllib.lua, etc.
├── Assets
│   ├── schematics/       # Building templates
│   ├── models/           # 3D models
│   ├── textures/         # Visual assets
│   ├── sounds/           # Audio files
│   └── locale/           # Translation files
└── Documentation
    ├── .clinerules/      # Project rules
    ├── memory-bank/      # Development context
    └── guide.txt         # User documentation
```

### Build Process
1. **Code Validation**: Luacheck static analysis
2. **Asset Preparation**: Convert and optimize media files
3. **Mod Packaging**: Create distributable mod archive
4. **Testing**: Validate in Minetest environment
5. **Deployment**: Upload to mod repository

## Technical Constraints

### Engine Limitations
- **Lua Version**: Restricted to Lua 5.1 feature set
- **Memory Limits**: Careful management of large schematics
- **Performance Budget**: World generation must complete within time limits
- **API Stability**: Changes between Minetest versions require adaptation

### Platform Constraints
- **Cross-Platform**: Must work on Windows, Linux, macOS
- **Hardware Variance**: Different performance on various systems
- **Network Play**: Considerations for multiplayer environments
- **Mod Compatibility**: Avoid conflicts with other mods

### Resource Constraints
- **File Size**: Mod package size limitations for distribution
- **Load Times**: Asset loading performance during world generation
- **Runtime Memory**: Entity and structure memory footprint
- **CPU Usage**: Generation algorithm computational complexity

## Dependencies

### Required Dependencies
- **mobs**: Entity framework for creatures and NPCs
  - Provides: Entity registration, AI behaviors, spawning logic
  - Version: Compatible with Minetest 5.x mobs API
- **intllib**: Internationalization support
  - Provides: Multi-language text handling
  - Version: Latest stable release

### Optional Dependencies
- **More Mobs**: Enhanced creature variety (if available)
- **Biome Lib**: Advanced biome detection (fallback to basic)
- **World Edit**: Development tool for schematic creation

### Development Dependencies
- **Luacheck**: Code quality and style checking
- **Lua LSP**: Language server for IDE support
- **Git LFS**: Large file storage for assets
- **Testing Framework**: Custom validation scripts

## Development Workflow

### Code Standards
- **Lua Style Guide**: Consistent indentation (4 spaces)
- **Naming Conventions**: snake_case for functions, CamelCase for modules
- **Documentation**: Inline comments for complex logic
- **Error Handling**: Pcall() for critical operations

### Version Control
- **Branch Strategy**: main for stable, develop for features
- **Commit Messages**: Descriptive, imperative mood
- **Asset Management**: Git LFS for large binary files
- **Release Tags**: Semantic versioning (v1.2.3)

### Testing Strategy
- **Unit Tests**: Lua function validation
- **Integration Tests**: Mod loading and basic functionality
- **World Tests**: Generation validation in test worlds
- **Performance Tests**: Generation time and memory usage profiling

### Deployment Process
1. **Code Review**: Peer review of changes
2. **Build Validation**: Automated testing pipeline
3. **Package Creation**: Mod archive generation
4. **Distribution**: Upload to ContentDB and forums
5. **User Feedback**: Monitor issue reports and feature requests

## Tool Usage Patterns

### Schematic Creation
- **World Edit**: In-game structure building and saving
- **Manual Editing**: Direct .mts file modification for precision
- **Template Reuse**: Base structures with variation parameters

### Model Development
- **Blender Pipeline**: Model creation → export to .b3d → import testing
- **Texture Mapping**: UV unwrapping and material assignment
- **Animation**: Bone-based animations for creatures

### Audio Production
- **Recording**: High-quality source material
- **Processing**: Normalization and compression for .ogg format
- **Organization**: Consistent naming and metadata

### Localization
- **String Extraction**: Automated scanning of source files
- **Translation Management**: Collaborative translation workflow
- **Fallback Handling**: Default language for missing translations
