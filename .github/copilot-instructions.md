# Copilot Instructions - TOGs Jump Stats Plugin

## Repository Overview

This repository contains **TOGs Jump Stats**, a SourceMod plugin for Source engine games that analyzes player movement patterns to detect potential cheating behaviors in bunny hopping (bhop). The plugin monitors jump statistics, detects hyperscrolling, pattern jumping, movement hacks, and FPS abuse.

**Primary Purpose**: Anti-cheat detection system focused on movement analysis with configurable thresholds, admin notifications, logging, and integration with Discord webhooks and SourceBans++.

## Technical Environment

### Core Technologies
- **Language**: SourcePawn
- **Platform**: SourceMod 1.11+ (configured for 1.11.0-git6917)
- **Build Tool**: SourceKnight (modern SourceMod build system)
- **Compiler**: SourcePawn Compiler (spcomp) via SourceKnight

### Dependencies
Automatically managed through `sourceknight.yaml`:
- `sourcemod` (1.11.0-git6917) - Core SourceMod framework
- `multicolors` - Chat color formatting
- `discordwebapi` - Discord webhook integration
- `sourcebans-pp` - Banning system integration
- `autoexecconfig` - Configuration management

### Build Process
```bash
# SourceKnight handles dependency resolution and compilation
# No manual setup required - dependencies auto-fetched
sourceknight build  # Compiles to .sourceknight/package/
```

## Code Architecture & Patterns

### Plugin Structure
```
TogsJumpStats.sp (1215 lines) - Main plugin logic
├── Plugin Info & CVars (lines 17-140)
├── Event Handlers (player_jump hook)
├── Detection Algorithms (hyperscroll, patterns, hacks)
├── Admin Commands & Notifications
├── Logging & Discord Integration
└── API Functions (forwards)

include/TogsJumpStats.inc - API for other plugins
```

### Key Components
1. **Detection Systems**:
   - Hyperscroll detection (excessive jump commands)
   - Pattern detection (scripted movement)
   - Performance-based hack detection
   - FPS max abuse detection

2. **Configuration**: 15+ ConVars for threshold tuning
3. **Notifications**: Admin chat alerts with cooldowns
4. **Logging**: Separate log files per detection type
5. **Integration**: Discord webhooks, SourceBans++ banning
6. **API**: Forward `TJS_OnClientDetected` for other plugins

### Global Variables Convention
```sourcepawn
// ConVars
ConVar g_hVariableName = null;

// Arrays/Data
float ga_fAvgJumps[MAXPLAYERS + 1];    // Player-indexed arrays
bool ga_bFlagged[MAXPLAYERS + 1];      // Boolean states
int ga_iJumps[MAXPLAYERS + 1];         // Integer counters

// Strings
char g_sVariableName[SIZE];            // Global strings
```

## SourcePawn Coding Standards

### Required Pragmas
```sourcepawn
#pragma semicolon 1        // Always at top of file
#pragma newdecls required  // Modern variable declarations
```

### Naming Conventions
- **Functions**: `PascalCase` (e.g., `Event_PlayerJump`)
- **Variables**: `camelCase` for local, `g_` prefix for global
- **ConVars**: `g_h` prefix (e.g., `g_hEnableLogs`)
- **Arrays**: `ga_` prefix (e.g., `ga_fAvgJumps`)
- **Constants**: `UPPER_CASE` with `#define`

### Memory Management
```sourcepawn
// ALWAYS use delete directly - no null checks needed
delete someHandle;        // ✓ Correct
someHandle = null;        // ✓ Set to null after delete

// Never use .Clear() on StringMap/ArrayList - creates memory leaks
delete myStringMap;       // ✓ Correct
myStringMap = new StringMap();  // ✓ Create new instance

// Use methodmaps for SQL operations (all async)
Database db = SQL_Connect("mysqlconnection");
db.Query(MyCallback, "SELECT * FROM table WHERE id = %d", clientId);
```

### Error Handling
```sourcepawn
// Always check API call results
if (!IsClientInGame(client))
    return;

// Handle SQL errors in callbacks
public void MyCallback(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null) {
        LogError("SQL Error: %s", error);
        return;
    }
    // Process results...
}
```

## Development Workflow

### 1. Building & Testing
```bash
# Build plugin (auto-fetches dependencies)
cd /path/to/repository
sourceknight build

# Output location: .sourceknight/package/addons/sourcemod/plugins/TogsJumpStats.smx
```

### 2. Configuration Testing
```sourcepawn
// Key ConVars to understand:
g_hAboveNumber        // Jump threshold for hyperscroll detection
g_hHypPerf           // Performance ratio threshold
g_hPatCount          // Pattern detection sensitivity
g_hBanHacks/Pat/Hyp  // Ban lengths (-1 = disabled, 0 = perm)
```

### 3. Common Development Tasks

#### Adding New Detection Method
1. Add ConVar in `OnPluginStart()` using `AutoExecConfig_CreateConVar`
2. Add player state variables (follow `ga_` naming)
3. Implement detection logic in `OnPlayerRunCmd()` or event handlers
4. Add logging in detection functions
5. Update `GetClientStats()` for display

#### Modifying Thresholds
- All detection thresholds are ConVar-controlled
- Use `AutoExecConfig_CreateConVar` for new settings
- Add bounds checking (`true, min, true, max`)
- Document purpose clearly in description

#### Adding API Functions
```sourcepawn
// In TogsJumpStats.inc
native bool TJS_IsClientFlagged(int client);

// In main plugin
public int Native_IsClientFlagged(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return ga_bFlagged[client];
}
```

### 4. Plugin-Specific Performance Considerations
- **Critical Path**: `OnPlayerRunCmd()` runs every game tick
- **Optimization**: Cache expensive calculations
- **Memory**: Reset player arrays on disconnect
- **Timers**: Use minimal timers, prefer event-driven approach

```sourcepawn
// ✓ Efficient - early returns
public Action OnPlayerRunCmd(int client, int &buttons)
{
    if (!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;
    
    // Core detection logic here
    return Plugin_Continue;
}

// ✓ Efficient - batch operations
// Process multiple checks in single function call
```

## Testing & Validation

### Manual Testing Approach
1. **Load on test server** with various movement types
2. **Test detection thresholds** with known legitimate players
3. **Verify Discord integration** if webhook configured
4. **Check SourceBans++ integration** for banning functionality
5. **Monitor performance** with `sm_profiler` command

### Key Test Scenarios
- Normal bhop movement (should not trigger)
- Obvious hyperscrolling (should trigger)
- Pattern-based scripts (should detect patterns)
- FPS max abuse (fps_max < threshold)
- Multiple rounds of suspicious activity

### Configuration Validation
```sourcepawn
// Always validate ConVar ranges
ConVar cvar = AutoExecConfig_CreateConVar(
    "tjs_example", "1.0",
    "Description here",
    FCVAR_NONE,
    true, 0.0,    // Has min value of 0.0
    true, 1.0     // Has max value of 1.0
);
```

## Integration Points

### Discord Webhooks
- ConVar: `tjs_webhook` (URL)
- Function: Uses `discordWebhookAPI` include
- Triggered on player detection

### SourceBans++
- Optional dependency (graceful degradation)
- Auto-banning based on detection type
- ConVars: `tjs_ban_hacks`, `tjs_ban_pat`, `tjs_ban_hyp`, `tjs_ban_fpsmax`

### Translation Support
- File: `translations/common.phrases` (loaded)
- Use `%T` formatting for user messages
- Consider adding plugin-specific translation file

## Common Issues & Solutions

### Build Issues
- **Missing dependencies**: SourceKnight auto-resolves, check `sourceknight.yaml`
- **Compilation errors**: Verify SourceMod version compatibility
- **Include errors**: Ensure all dependencies in `sourceknight.yaml`

### Runtime Issues
- **High CPU usage**: Review `OnPlayerRunCmd` efficiency
- **Memory leaks**: Check for proper `delete` usage, avoid `.Clear()`
- **False positives**: Adjust detection thresholds via ConVars

### Performance Optimization
```sourcepawn
// ✓ Cache frequently accessed data
int clientTeam = GetClientTeam(client);

// ✓ Minimize string operations in hot paths
// ✓ Use early returns to skip unnecessary processing
// ✓ Consider tick-based sampling for expensive operations
```

## API Usage for Other Plugins

```sourcepawn
// Include the API
#include <TogsJumpStats>

// Listen for detections
public void TJS_OnClientDetected(int client, char[] sReason, char[] sStats)
{
    // Handle detection event
    LogMessage("Client %N detected for: %s", client, sReason);
}
```

## Best Practices Summary

1. **Always use async SQL** operations with proper error handling
2. **Cache expensive operations** in frequently called functions
3. **Use ConVars** for all configurable values
4. **Follow memory management** rules (delete without null checks)
5. **Test thoroughly** on development servers before deployment
6. **Document complex detection logic** with inline comments
7. **Consider performance impact** of changes in `OnPlayerRunCmd`
8. **Use translation files** for user-facing messages
9. **Implement graceful degradation** for optional dependencies
10. **Follow existing code style** and naming conventions consistently

## File Structure Reference
```
.github/
├── workflows/ci.yml         # GitHub Actions build pipeline
├── copilot-instructions.md  # This file
addons/sourcemod/scripting/
├── TogsJumpStats.sp         # Main plugin (1215 lines)
├── include/
│   ├── TogsJumpStats.inc    # Plugin API
│   └── autoexecconfig.inc   # Config management
sourceknight.yaml            # Build configuration & dependencies
```

This plugin is performance-critical and security-focused. Always prioritize accuracy in detection algorithms and efficiency in hot code paths.