#pragma semicolon 1;

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <readyup>
#include <l4d_tank_control_eq>
#include "includes/finalemaps"

#pragma newdecls required

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

#define MAXSTEAMID              64
#define MAXMAP                  64
#define MAXTANKS                4

Handle g_hCvarDebug = INVALID_HANDLE;
StringMap g_hStaticTankPlayers[MAXTANKS];
char g_sQueuedTankSteamId[MAXSTEAMID] = "";
int g_iTankCount = 0;
bool g_bRoundStarted = false;

enum strMapType {
    MP_FINALE
};

public Plugin myinfo = {
    name = "Static Tank Control",
    author = "devilesk",
    description = "Predetermined tank control distribution.",
    version = "0.7.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public void OnPluginStart() {
    for ( int i = 0; i < MAXTANKS; i++ ) {
        g_hStaticTankPlayers[i] = new StringMap();
    }
    
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_PostNoCopy);
    
    RegServerCmd("static_tank_control", StaticTankControl_Command);
    RegServerCmd("static_tank_control_tank_num", StaticTankControlTankNum_Command); 
    
    g_hCvarDebug = CreateConVar("static_tank_control_debug", "0", "Whether or not to debug to console", 0);
}

/**
 * Provides a way to set the tank count in case plugin is reloaded after a tank has spawned.
 */
public Action StaticTankControlTankNum_Command(int args) {
    if (args < 1) {
        LogError("[StaticTankControlTankNum_Command] Missing args");
        return Plugin_Handled;
    }
    
    char sTankNum[16];
    GetCmdArg(1, sTankNum, sizeof(sTankNum));
    int iTankNum = StringToInt(sTankNum);
    if (iTankNum < 1 || iTankNum > MAXTANKS) {
        LogError("[StaticTankControlTankNum_Command] Invalid tank num arg");
        return Plugin_Handled;
    }
    
    g_iTankCount = iTankNum - 1;
    PrintDebug("[StaticTankControlTankNum_Command] iTankNum: %i, g_iTankCount: %i", iTankNum, g_iTankCount);

    return Plugin_Handled;
}

public Action StaticTankControl_Command(int args) {
    if (args < 2) {
        LogError("[StaticTankControl_Command] Missing args");
        return Plugin_Handled;
    }

    char sTankNum[16];
    GetCmdArg(1, sTankNum, sizeof(sTankNum));
    int iTankNum = StringToInt(sTankNum);
    if (iTankNum < 1 || iTankNum > MAXTANKS) {
        LogError("[StaticTankControl_Command] Invalid tank num arg");
        return Plugin_Handled;
    }

    char sMapName[MAXMAP];
    GetCmdArg(2, sMapName, sizeof(sMapName));
    StrToLower(sMapName);
    ArrayList hSteamIds = new ArrayList(MAXSTEAMID);
    g_hStaticTankPlayers[iTankNum-1].SetValue(sMapName, hSteamIds);

    char steamId[MAXSTEAMID];
    for ( int i = 3; i <= args; i++ ) {
        GetCmdArg(i, steamId, sizeof(steamId));
        if (strlen(steamId)) {
            hSteamIds.PushString(steamId);
            PrintDebug("[StaticTankControl_Command] Added iTankNum: %i, sMapName: %s steamId: %s", iTankNum, sMapName, steamId);
        }
    }

    return Plugin_Handled;
}

/**
 * When a new game starts, reset the tank pool.
 */
public void TankControlEQ_OnTankControlReset() {
    PrintDebug("[TankControlEQ_OnTankControlReset] Resetting tank control.");
    g_sQueuedTankSteamId[0] = '\0';
    g_iTankCount = 0;
}

public void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast) {
    g_bRoundStarted = true;
    g_iTankCount = 0;
    g_sQueuedTankSteamId[0] = '\0';
}

public void RoundEnd_Event(Handle event, const char[] name, bool dontBroadcast) {
    g_bRoundStarted = false;
}

/**
 * When a player reconnects, check if they are the static tank player
 */
public void OnClientConnected(int client)  {
    if (!g_bRoundStarted) return;
    char steamId[MAXSTEAMID];
    if (IS_VALID_INFECTED(client)) {
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
        if (StrEqual(g_sQueuedTankSteamId, steamId)) {
            PrintDebug("[OnClientConnected] Static tank player reconnected. Setting player as tank. steamId: %s.", steamId);
            TankControlEQ_SetTank(steamId);
        }
    }
}

/**
 * When the queued tank switches to infected, check if they are the static tank player
 */
public void PlayerTeam_Event(Handle event, const char[] name, bool dontBroadcast) {
    if (!g_bRoundStarted) return;
    char steamId[MAXSTEAMID];
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IS_VALID_INFECTED(client)) {
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
        if (StrEqual(g_sQueuedTankSteamId, steamId)) {
            PrintDebug("[OnClientConnected] Static tank player joined infected. Setting player as tank. steamId: %s.", steamId);
            TankControlEQ_SetTank(steamId);
        }
    }
}

public Action TankControlEQ_OnChooseTank() {
    if (g_iTankCount >= MAXTANKS) {
        PrintDebug("[TankControlEQ_OnChooseTank] g_iTankCount: %i tanks spawned >= MAXTANKS %i. Continuing with default tank selection.", g_iTankCount, MAXTANKS);
        return Plugin_Continue;
    }
    
    ArrayList hStaticTankPlayers;
    
    char sMapName[MAXMAP];
    GetCurrentMapLower(sMapName, sizeof(sMapName));
    PrintDebug("[TankControlEQ_OnChooseTank] Attempting to find static tank player for map %s tank %i.", sMapName, g_iTankCount + 1);
    
    // check that there is a static tank list for the current tank spawn on this map
    if (!g_hStaticTankPlayers[g_iTankCount].GetValue(sMapName, hStaticTankPlayers)) {
        PrintDebug("[TankControlEQ_OnChooseTank] Map %s for tank %i not found. Continuing with default tank selection.", sMapName, g_iTankCount + 1);
        return Plugin_Continue;
    }
    
    // check static tank list not empty
    int iStaticTankPlayersSize = hStaticTankPlayers.Length;
    if (!iStaticTankPlayersSize) {
        PrintDebug("[TankControlEQ_OnChooseTank] Static tank players size: %i. Continuing with default tank selection.", iStaticTankPlayersSize);
        return Plugin_Continue;
    }

    // if finale and someone has not played tank, then use default tank selection
    ArrayList hWhosNotHadTank = TankControlEQ_GetWhosNotHadTank();
    int iWhosNotHadTankSize = hWhosNotHadTank.Length;
    if (IsMissionFinalMap() && iWhosNotHadTankSize > 0) {
        PrintDebug("[TankControlEQ_OnChooseTank] Finale with %i skipped tank player. Continuing with default tank selection.", iWhosNotHadTankSize);
        delete hWhosNotHadTank;
        return Plugin_Continue;
    }
    delete hWhosNotHadTank;

    // find a static tank player in the pool of tank players
    ArrayList hTankPool = TankControlEQ_GetTankPool();
    char sSteamId[MAXSTEAMID];
    if (FindSteamIdInArrays(sSteamId, sizeof(sSteamId), hTankPool, hStaticTankPlayers)) {
        strcopy(g_sQueuedTankSteamId, sizeof(g_sQueuedTankSteamId), sSteamId); // store static tank player in case they disconnect or change teams
        PrintDebug("[TankControlEQ_OnChooseTank] Setting tank to %s.", sSteamId);
        TankControlEQ_SetTank(sSteamId);
        delete hTankPool;
        return Plugin_Handled;
    }
    
    PrintDebug("[TankControlEQ_OnChooseTank] No static tank player in tank pool. Continuing with default tank selection.");
    delete hTankPool;
    return Plugin_Continue;
}

public bool FindSteamIdInArrays(char[] buffer, int bufferLen, ArrayList hArrayA, ArrayList hArrayB) {
    char sSteamIdA[MAXSTEAMID];
    char sSteamIdB[MAXSTEAMID];
    for (int i = 0; i < hArrayA.Length; i++) {
        hArrayA.GetString(i, sSteamIdA, sizeof(sSteamIdA));
        for (int j = 0; j < hArrayB.Length; j++) {
            hArrayB.GetString(j, sSteamIdB, sizeof(sSteamIdB));
            if (StrEqual(sSteamIdA, sSteamIdB)) {
                strcopy(buffer, bufferLen, sSteamIdA);
                PrintDebug("[FindSteamIdInArrays] Match found. steamId: %s. buffer: %s", sSteamIdA, buffer);
                return true;
            }
        }
    }
    PrintDebug("[FindSteamIdInArrays] Match not found.");
    return false;
}

public void TankControlEQ_OnTankGiven(const char[] steamId) {
    // stop storing static tank player once they've been given tank
    if (StrEqual(g_sQueuedTankSteamId, steamId))
        g_sQueuedTankSteamId[0] = '\0';

    g_iTankCount++;
    
    PrintDebug("[TankControlEQ_OnTankGiven] Gave tank %i to %s.", g_iTankCount, steamId);
}

/**
 * Retrieves a valid infected player's client index by their steam id.
 * 
 * @param const String:steamId[]
 *     The steam id to look for.
 * 
 * @return
 *     The player's client index.
 */
public int GetValidInfectedClientBySteamId(const char[] steamId) {
    char tmpSteamId[MAXSTEAMID];
   
    for (int i = 1; i <= MaxClients; i++) {
        if (!IS_VALID_INFECTED(i))
            continue;
        
        GetClientAuthId(i, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
        
        if (StrEqual(steamId, tmpSteamId))
            return i;
    }
    
    return -1;
}

stock void PrintDebug(const char[] Message, any ...) {
    if (GetConVarBool(g_hCvarDebug)) {
        char DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
        for (int x = 1; x <= MaxClients; x++) { 
            if (IsClientInGame(x)) {
                SetGlobalTransTarget(x); 
                PrintToConsole(x, DebugBuff); 
            } 
        }
    }
}