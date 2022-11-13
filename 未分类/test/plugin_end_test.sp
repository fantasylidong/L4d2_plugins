#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <left4dhooks>
#define REQUIRE_PLUGIN

public Plugin:myinfo = {
    name = "Plugin End Test",
    author = "devilesk",
    description = "Test OnPluginEnd.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public OnPluginStart() {
    LogMessage("[OnPluginStart] loaded. dhooks optional");
}

public OnPluginEnd() {
    LogMessage("[OnPluginEnd] OnPluginEnd fired. dhooks optional");
}

public OnLibraryRemoved(const char[] name) {
    LogMessage("[OnPluginEnd] OnLibraryRemoved fired. dhooks optional. %s removed", name);
}