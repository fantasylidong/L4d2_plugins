#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "Client Test",
    author = "devilesk",
    description = "Client Test.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public OnPluginStart() {
	RegConsoleCmd("sm_clienttest", Command_AliveTest);
}

public Action:Command_AliveTest(client, args)  {
    PrintToChatAll("ClientID: %i", client);
    PrintToChatAll("UserID: %i", GetClientUserId(client));
	
	if (args > 0) {
		new String:sUserId[32];
		GetCmdArg(1, sUserId, 32);
		new userId = StringToInt(sUserId, 10);
		PrintToChatAll("%i to ClientID: %i", userId, GetClientOfUserId(userId));
	}
}

stock PrintDebug(const String:Message[], any:...) {
    if (GetConVarBool(g_hCvarDebug)) {
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
    }
}