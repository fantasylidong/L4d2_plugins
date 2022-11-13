#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <readyup>

public Plugin:myinfo = {
    name = "Max Completion Score Test",
    author = "devilesk",
    description = "Test max completion score.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public OnPluginStart() {
    LogMessage("[OnPluginStart] loaded.");
    RegConsoleCmd("sm_maxscoretest", MaxScoreTest_Cmd, "Shows max completion score.");
    HookEvent("round_start", RoundStart);
    HookEvent("round_end", RoundEnd);
    HookEvent("tank_spawn", TankSpawn);
}

public OnMapStart() {
    PrintDebug("[OnMapStart] Max completion score: %i.", L4D_GetVersusMaxCompletionScore());
}

public OnConfigsExecuted() {
    PrintDebug("[OnConfigsExecuted] Max completion score: %i.", L4D_GetVersusMaxCompletionScore());
}

public OnRoundIsLive() {
    PrintDebug("[OnRoundIsLive] Max completion score: %i.", L4D_GetVersusMaxCompletionScore());
}

public Action:RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
    PrintDebug("[RoundStart] Max completion score: %i.", L4D_GetVersusMaxCompletionScore());
}

public Action:RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
    PrintDebug("[RoundEnd] Max completion score: %i.", L4D_GetVersusMaxCompletionScore());
}

public Action:TankSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
    PrintDebug("[TankSpawn] Max completion score: %i.", L4D_GetVersusMaxCompletionScore());
}

public Action:MaxScoreTest_Cmd(client, args) {
    PrintDebug("[MaxScoreTest_Cmd] Max completion score: %i.", L4D_GetVersusMaxCompletionScore());
}

stock PrintDebug(const String:Message[], any:...) {
    decl String:DebugBuff[256];
    VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
    LogMessage(DebugBuff);
    PrintToChatAll(DebugBuff);
}