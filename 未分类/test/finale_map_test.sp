#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include "includes/finalemaps"

public Plugin:myinfo = {
    name = "Finale Map Test",
    author = "devilesk",
    description = "Test finale map detection.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public OnPluginStart() {
    LogMessage("[OnPluginStart] loaded.");
}

public OnMapStart() {
    if (IsMissionFinalMap())
        LogMessage("[OnMapStart] finale map.");
    else
        LogMessage("[OnMapStart] not finale map.");
}