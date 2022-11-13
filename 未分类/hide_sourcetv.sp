#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>

static int s_nSourceBotIndex = -1;

public void Handler_ResourceThink(int entity)
{
    if (s_nSourceBotIndex == -1) {
        SDKUnhook(entity, SDKHook_ThinkPost, Handler_ResourceThink);
        
        return;
    }
    
    SetEntProp(entity, Prop_Send, "m_bConnected", 0, .element = s_nSourceBotIndex);
}

public void OnClientPutInServer(int client)
{
    if (!IsClientSourceTV(client)) {
        return;
    }
    
    s_nSourceBotIndex = client;
    
    int entPlayerResource = FindEntityByClassname(INVALID_ENT_REFERENCE, "terror_player_manager");
    if (IsValidEdict(entPlayerResource)) {
        SDKHook(entPlayerResource, SDKHook_ThinkPost, Handler_ResourceThink);
    }
}

public void OnClientDisconnect_Post(int client)
{
    if (s_nSourceBotIndex == -1) {
        return;
    }
    
    if (s_nSourceBotIndex == client) {
        s_nSourceBotIndex = -1;
    }
}

public void OnPluginStart()
{
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) {
            continue;
        }
        
        if (!IsClientSourceTV(i)) {
            continue;
        }
        
        OnClientPutInServer(i);
        
        break;
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    switch (GetEngineVersion()) {
        case Engine_Left4Dead2, Engine_Left4Dead:
        {
            return APLRes_Success;
        }
    }

    strcopy(error, err_max, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");

    return APLRes_SilentFailure;
}

public Plugin myinfo =
{
    name = "[L4D/2] Hide SourceTV Bot",
    author = "shqke",
    description = "Hides SourceTV bot from scoreboard",
    version = "1.2",
    url = "https://github.com/shqke/sp_public"
};
