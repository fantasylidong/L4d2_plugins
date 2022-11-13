#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "Alive Test",
    author = "devilesk",
    description = "Alive Test.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public OnPluginStart() {
	RegConsoleCmd("sm_alivetest", Command_AliveTest);
}

public Action:Command_AliveTest(client, args)  {
    PrintToChatAll("IsPlayerAlive: %i", IsPlayerAlive(client));
}

stock PrintDebug(const String:Message[], any:...) {
    if (GetConVarBool(g_hCvarDebug)) {
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
    }
}