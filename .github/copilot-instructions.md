# Copilot Instructions for VIP CustomFeatures SourcePawn Plugin

## Repository Overview

This repository contains a SourcePawn plugin for SourceMod that extends VIP Core functionality by allowing server administrators to create custom VIP menu items. The plugin enables configuration-driven VIP features that can execute commands when accessed through the VIP menu system.

**Key Purpose**: Provide a flexible framework for adding custom VIP features without hardcoding them into the plugin source code.

## Technology Stack

- **Language**: SourcePawn (Source engine scripting language)
- **Platform**: SourceMod 1.11.0+ (minimum version for compatibility)
- **Build Tool**: SourceKnight (modern SourcePawn build system)
- **Dependencies**:
  - SourceMod 1.11.0-git6917 (framework)
  - VIP Core plugin (provides VIP menu system)
- **CI/CD**: GitHub Actions with automated building, packaging, and releases

## Project Structure

```
├── .github/
│   ├── workflows/ci.yml          # CI/CD pipeline
│   └── copilot-instructions.md   # This file
├── addons/sourcemod/
│   ├── scripting/
│   │   └── VIP_CustomFeatures.sp # Main plugin source
│   └── data/vip/modules/
│       └── custom_items.cfg      # Feature configuration
├── sourceknight.yaml             # Build configuration
└── .gitignore                    # Git ignore rules
```

## Code Architecture

### Main Plugin (`VIP_CustomFeatures.sp`)
- **Configuration Parser**: Uses SourceMod Config (SMC) to parse custom_items.cfg
- **Feature Registration**: Dynamically registers VIP features based on configuration
- **Command System**: Uses CommandListener to intercept and control access to features
- **Memory Management**: Uses modern SourcePawn patterns with proper cleanup

### Key Components
1. **Feature Storage**: `g_hFeatures` ArrayList containing StringMaps for each feature
2. **VIP Integration**: Callbacks for VIP Core menu system (pressed, touched, render)
3. **Command Execution**: FakeClientCommand for feature execution
4. **Access Control**: RestrictAccess system for non-VIP users

## Development Standards

### SourcePawn Code Style
```sourcepawn
// Required pragmas (always include these)
#pragma newdecls required
#pragma semicolon 1

// Variable naming conventions
Handle g_hFeatures;              // Global variables with g_ prefix
int iClient;                     // Local variables camelCase
char szFeatureName[64];          // String variables with sz prefix

// Function naming
public void OnPluginStart()      // Public functions PascalCase
void VIP_LoadFeatures()          // Internal functions with module prefix

// Memory management
delete hHandle;                  // Use delete, never CloseHandle
// No null checks needed before delete

// String operations
#define SZFS(%0) %0, sizeof(%0)  // Use macros for string formatting
```

### Configuration Format (`custom_items.cfg`)
```keyvalues
"CustomFeatures"
{
    "FeatureName"
    {
        "Trigger"          "say !command"      // Command to execute
        "TriggerType"      "select"            // "select" or "toggle"
        "RestrictAccess"   "1"                 // 0=all, 1=VIP only, 2=admin bypass
        "SendNotify"       "1"                 // Show VIP purchase message
    }
}
```

## Build and Development Workflow

### Building the Plugin
```bash
# Install SourceKnight (if not available)
pip install sourceknight

# Build using SourceKnight
sourceknight build

# Build artifacts are placed in .sourceknight/package/
```

### Development Commands
```bash
# Reload configuration (server command)
sm_reloadvipci

# Check plugin status
sm plugins list VIP_CustomFeatures
```

### CI/CD Pipeline
- **Trigger**: Push to any branch or PR
- **Build**: Compiles plugin using SourceKnight
- **Package**: Creates deployment-ready package
- **Release**: Auto-tags and releases on main/master branch

## Key APIs and Integration Points

### VIP Core Integration
```sourcepawn
// Register feature with VIP Core
VIP_RegisterFeature(szFeatureName, BOOL, eFeatureType, fCallback, VIP_OnRenderTextItem);

// Feature callbacks
public Action VIP_OnItemPressed(int iClient, const char[] szFeatureName, ...);
public bool VIP_OnItemTouched(int iClient, const char[] szFeatureName);
public bool VIP_OnRenderTextItem(int iClient, const char[] szFeatureName, char[] szDisplay, int iMaxLength);
```

### Command System
```sourcepawn
// Add command listener for feature access control
AddCommandListener(OnCommandExecuted, szCommand);

// Check VIP access
if (VIP_IsClientFeatureUse(iClient, szFeatureName))
    return Plugin_Continue;
```

## Common Development Tasks

### Adding New Configuration Options
1. Modify `OnKeyValue()` parser function
2. Add new StringMap key storage
3. Update feature execution logic if needed
4. Test with sample configuration

### Debugging Plugin Issues
```sourcepawn
// Use LogError for debugging
LogError("Feature %s execution failed for client %L", szFeatureName, iClient);

// Enable debug logging in server.cfg
sm_cvar sourcemod_basepath "addons/sourcemod"
sm_cvar sm_debug 1
```

### Memory Management Best Practices
```sourcepawn
// Correct pattern for cleanup
delete g_hFeatures;
g_hFeatures = CreateArray(4);

// Don't use Clear() - creates memory leaks
// ClearArray(g_hFeatures);  // WRONG!

// Instead use delete and recreate
delete g_hFeatures;
g_hFeatures = CreateArray(4);
```

## Testing and Validation

### Manual Testing Checklist
1. **Plugin Load**: Verify plugin loads without errors
2. **Configuration Parse**: Check custom_items.cfg loads correctly
3. **VIP Menu**: Test features appear in VIP menu
4. **Feature Execution**: Verify commands execute when selected
5. **Access Control**: Test RestrictAccess settings work
6. **Reload Function**: Test `sm_reloadvipci` command

### Common Issues and Solutions
- **Plugin fails to load**: Check VIP Core dependency is installed
- **Features not appearing**: Verify VIP Core is loaded first
- **Commands not executing**: Check command syntax in configuration
- **Memory leaks**: Ensure proper cleanup in OnPluginEnd/OnMapEnd

## Translation System

### Translation Files
- Uses SourceMod translation system
- Loads "vip_modules.phrases" translation file
- Format feature names as translation keys in phrases file

### Adding Translations
```keyvalues
"Phrases"
{
    "FeatureName"
    {
        "en"    "Feature Display Name"
        "ru"    "Название функции"
    }
}
```

## Performance Considerations

### Optimization Guidelines
- **Feature Lookup**: Uses O(n) search through features array - consider HashMap for large feature sets
- **Command Parsing**: Minimize string operations in frequently called functions
- **Memory Usage**: Clean up features on map change to prevent memory accumulation
- **Timer Usage**: Plugin doesn't use timers - good for performance

### Monitoring
- Use `sm_profiler` to monitor performance impact
- Watch for memory leaks with `sm_memleak_check`
- Monitor server tick rate impact

## Security Considerations

- **Command Injection**: Plugin uses FakeClientCommand - ensure config commands are safe
- **Access Control**: RestrictAccess system provides proper authorization
- **Input Validation**: Configuration parser validates structure and types
- **Admin Bypass**: Admin users can bypass VIP restrictions when configured

## Troubleshooting Guide

### Common Error Messages
```
"Feature X already registered! Skipping..."
- Solution: Check for duplicate feature names in configuration

"Couldn't find configuration file: custom_items.cfg"
- Solution: Ensure file exists in data/vip/modules/ directory

"Invalid Config" 
- Solution: Check configuration syntax and required keys
```

### Debug Commands
```
sm plugins list                    // List all loaded plugins
sm plugins info VIP_CustomFeatures // Show plugin details
sm_reloadvipci                     // Reload configuration
```

This documentation should provide all necessary information for efficient development and maintenance of the VIP CustomFeatures plugin.