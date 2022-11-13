#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = {
    name = "Auth Engine Test",
    author = "devilesk",
    description = "Log client auth id engine values.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public OnPluginStart() {
    LogMessage("[OnPluginStart] loaded.");
    RegConsoleCmd("sm_authtest", AuthTest_Cmd, "Shows who is becoming the tank.");
}

public Action:AuthTest_Cmd(client, args)
{
    LogMessage("[AuthTest_Cmd] Clients.");
    decl String:tmpSteamId[64];
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
        {
            GetClientAuthId(i, AuthId_Engine, tmpSteamId, sizeof(tmpSteamId));
            LogMessage("%s", tmpSteamId);
            GetClientAuthId(i, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
            LogMessage("%s", tmpSteamId);
            GetClientAuthId(i, AuthId_Steam3, tmpSteamId, sizeof(tmpSteamId));
            LogMessage("%s", tmpSteamId);
        }
    }
}