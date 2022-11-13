#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = {
    name = "Plugin Parent Test",
    author = "devilesk",
    description = "Parent plugin for testing OnPluginEnd.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public OnPluginStart() {
    LogMessage("[OnPluginStart] plugin parent loaded.");
}

public OnPluginEnd() {
    LogMessage("[OnPluginEnd] plugin parent unloaded.");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    //... code here ...
    RegPluginLibrary("plugin_parent_test");
 
    return APLRes_Success;
}