#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
//#include <l4d2_direct>

public Plugin:myinfo = {
    name = "Round Start Test",
    author = "devilesk",
    description = "Log round_start event.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public OnPluginStart() {
    HookEvent("round_start", EventHook:RoundStartEvent, EventHookMode_PostNoCopy);
    LogMessage("[OnPluginStart] loaded.");
}

public RoundStartEvent() {
    LogMessage("[RoundStartEvent] round_start fired.");
}

public OnRoundStart() {
    LogMessage("[OnRoundStart] round_start fired.");
}