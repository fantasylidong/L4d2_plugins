#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <plugin_parent_test>

public Plugin:myinfo = {
    name = "Plugin Child Test",
    author = "devilesk",
    description = "Child plugin for testing OnPluginEnd.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public OnPluginStart() {
    LogMessage("[OnPluginStart] plugin child loaded.");
}

public OnPluginEnd() {
    LogMessage("[OnPluginEnd] plugin child unloaded.");
}

public LGO_OnMatchModeUnloaded() {
    LogMessage("[LGO_OnMatchModeUnloaded] plugin child unloaded.");
}

public OnLibraryRemoved(const char[] name) {
    LogMessage("[OnLibraryRemoved] %s removed", name);
    if (StrEqual(name, "left4dhooks"))
    {
        LogMessage("[OnLibraryRemoved] DHOOKS REMOVED. tank spawn this round. %i", L4D2Direct_GetVSTankToSpawnThisRound(0));
    }
}