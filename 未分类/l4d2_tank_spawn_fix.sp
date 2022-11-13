#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include "includes/rl4d2l_util"

#define DEBUG 0
#define TEAM_SURVIVOR 2

Handle g_hCvarDebug = INVALID_HANDLE;
Handle g_hVsBossBuffer = INVALID_HANDLE;
Handle g_hCvarEnabled = INVALID_HANDLE;
StringMap g_hDisabledMaps;
Address g_pTankSpawnNav = Address_Null;
bool g_bFirstFlowTankSpawned = false;
float g_fTankSpawnOrigin[3];
float g_fNavAreaFlow;
float g_fMapMaxFlowDistance;
float g_fTankFlow;

public Plugin myinfo = {
    name = "L4D2 Tank Spawn Fix",
    author = "devilesk",
    version = "1.2.2",
    description = "Fixes inconsistent tank spawns between rounds.",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public void OnPluginStart() {
    g_hCvarDebug = CreateConVar("sm_tank_spawn_fix_debug", "1", "Tank Spawn Fix debug mode", 0, true, 0.0, true, 1.0);
    g_hCvarEnabled = CreateConVar("tank_spawn_fix", "1", "Tank Spawn Fix enabled", 0, true, 0.0, true, 1.0);
    g_hVsBossBuffer = FindConVar("versus_boss_buffer");
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
    RegServerCmd("tank_spawn_fix_disable", TankSpawnFixMapDisable_Command);
    g_hDisabledMaps = new StringMap();
}

public Action TankSpawnFixMapDisable_Command(int args) {
    char mapname[64];
    GetCmdArg(1, mapname, sizeof(mapname));
    StrToLower(mapname);
    g_hDisabledMaps.SetValue(mapname, true);
    PrintDebug("[TankSpawnFixMapDisable_Command] Added: %s", mapname);
    return Plugin_Handled;
}

public bool IsMapEnabled() {
    if (!GetConVarBool(g_hCvarEnabled)) {
        PrintDebug("[IsMapEnabled] false");
        return false;
    }
    char mapname[64];
    GetCurrentMapLower(mapname, sizeof(mapname));
    bool dummy;
    if (g_hDisabledMaps.GetValue(mapname, dummy)) {
        PrintDebug("[IsMapEnabled] false %s", mapname);
        return false;
    }
    PrintDebug("[IsMapEnabled] true %s", mapname);
    return true;
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast) {
    if (!IsMapEnabled()) return;

    if (!InSecondHalfOfRound()) g_bFirstFlowTankSpawned = false;

    // Delayed flow check due to L4D2Direct_GetMapMaxFlowDistance not returning a consistent value if called immediately on round start
    CreateTimer(8.0, CheckFlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

/*
 * Calculates what the second round tank flow should be based off the nav area stored from the first round flow tank spawn.
 * If the flow returned from the nav area has changed between rounds or the max map flow distance has changed between rounds,
 * then update the second round flow tank percent.
 */
public Action CheckFlow(Handle timer) {
    if (!IsMapEnabled()) return Plugin_Stop;

    PrintDebug("[CheckFlow] Round: %i. Round 2 Tank Enabled: %i. FirstFlowTankSpawned: %i.", InSecondHalfOfRound(), L4D2Direct_GetVSTankToSpawnThisRound(1), g_bFirstFlowTankSpawned);

    // only check second round flow tanks if enabled and first round flow tank spawned
    if (!InSecondHalfOfRound() || !L4D2Direct_GetVSTankToSpawnThisRound(1) || !g_bFirstFlowTankSpawned) return Plugin_Stop;

    // get nav area that spawned first round flow tank
    Address pTankSpawnNav = L4D2Direct_GetTerrorNavArea(g_fTankSpawnOrigin);
    if (pTankSpawnNav == Address_Null) return Plugin_Stop;

    // calculate tank flow from the nav area
    float fMapMaxFlowDistance = L4D2Direct_GetMapMaxFlowDistance();
    float fNavAreaFlow = L4D2Direct_GetTerrorNavAreaFlow(pTankSpawnNav);
    float fTankFlow = (fNavAreaFlow + GetConVarFloat(g_hVsBossBuffer)) / fMapMaxFlowDistance;

    PrintDebug("[CheckFlow] NavArea: %i %i %i", g_pTankSpawnNav, pTankSpawnNav, g_pTankSpawnNav == pTankSpawnNav);
    PrintDebug("[CheckFlow] NavAreaFlow: %f %f %i", g_fNavAreaFlow, fNavAreaFlow, g_fNavAreaFlow == fNavAreaFlow);
    PrintDebug("[CheckFlow] TankFlow: %f %f %i", g_fTankFlow, fTankFlow, g_fTankFlow == fTankFlow);
    PrintDebug("[CheckFlow] MapFlowDist: %f %f %i", g_fMapMaxFlowDistance, fMapMaxFlowDistance, g_fMapMaxFlowDistance == fMapMaxFlowDistance);
    
    // update tank flow if nav area flows or map distances don't match between rounds or if the tank flow randomly changes during rounds
    if (g_fNavAreaFlow != fNavAreaFlow || g_fMapMaxFlowDistance != fMapMaxFlowDistance || L4D2Direct_GetVSTankFlowPercent(0) != L4D2Direct_GetVSTankFlowPercent(1)) {
        PrintDebug("[CheckFlow] Fixing tank flow.");
        L4D2Direct_SetVSTankFlowPercent(1, fTankFlow);
    }
    else {
        PrintDebug("[CheckFlow] Tank flow match.");
    }
    PrintDebug("[CheckFlow] VSTankFlow: %f %f %i", L4D2Direct_GetVSTankFlowPercent(0), L4D2Direct_GetVSTankFlowPercent(1), L4D2Direct_GetVSTankFlowPercent(0) == L4D2Direct_GetVSTankFlowPercent(1));

    return Plugin_Stop;
}

/*
 * Store the nav area that triggered the first round flow tank spawn along with other flow info
 */
public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3]) {
    if (!IsMapEnabled()) return Plugin_Continue;

    if (!InSecondHalfOfRound() && L4D2Direct_GetVSTankToSpawnThisRound(0) && !g_bFirstFlowTankSpawned) {
        GetMaxSurvivorNavInfo(g_pTankSpawnNav, g_fTankSpawnOrigin, g_fNavAreaFlow, g_fMapMaxFlowDistance, g_fTankFlow);
        g_bFirstFlowTankSpawned = true;
    }
#if DEBUG
    if (InSecondHalfOfRound() && L4D2Direct_GetVSTankToSpawnThisRound(1)) {
        Address pNavArea;
        float origin[3];
        float fNavAreaFlow;
        float fMapMaxFlowDistance
        float fTankFlow;
        GetMaxSurvivorNavInfo(pNavArea, origin, fNavAreaFlow, fMapMaxFlowDistance, fTankFlow);
    }
#endif
    return Plugin_Continue;
}

/*
 * Stores the nav area and flow info of the survivor with highest flow
 */
public void GetMaxSurvivorNavInfo(Address &pNavArea, float origin[3], float &fNavAreaFlow, float &fMapMaxFlowDistance, float &fTankFlow)
{
    fNavAreaFlow = 0.0;
    float tmp_flow;
    float tmp_origin[3];
    Address tmp_pNavArea;
    for (int client = 1; client <= MaxClients; client++) {
        if(IsSurvivor(client)) {
            GetClientAbsOrigin(client, tmp_origin);
            tmp_pNavArea = L4D2Direct_GetTerrorNavArea(tmp_origin);
            if (tmp_pNavArea != Address_Null) {
                tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(tmp_pNavArea);
                if (tmp_flow > fNavAreaFlow) {
                    pNavArea = tmp_pNavArea;
                    fNavAreaFlow = tmp_flow;
                    origin[0] = tmp_origin[0];
                    origin[1] = tmp_origin[1];
                    origin[2] = tmp_origin[2];
                }
            }
        }
    }
    fMapMaxFlowDistance = L4D2Direct_GetMapMaxFlowDistance();
    fTankFlow = (fNavAreaFlow + GetConVarFloat(g_hVsBossBuffer)) / fMapMaxFlowDistance;

    PrintDebug("[MaxSurvNav] Round: %i", InSecondHalfOfRound());
    PrintDebug("[MaxSurvNav] Origin: %f %f %f", origin[0], origin[1], origin[2]);
    PrintDebug("[MaxSurvNav] NavArea: %i", pNavArea);
    PrintDebug("[MaxSurvNav] NavAreaFlow: %f", fNavAreaFlow);
    PrintDebug("[MaxSurvNav] TankFlow: %f", fTankFlow);
    PrintDebug("[MaxSurvNav] MapFlowDist: %f", fMapMaxFlowDistance);
    PrintDebug("[MaxSurvNav] VSTankFlow: %f. Round: %i", L4D2Direct_GetVSTankFlowPercent(InSecondHalfOfRound()), InSecondHalfOfRound());
}

stock void PrintDebug(const char[] Message, any ...) {
    if (GetConVarBool(g_hCvarDebug)) {
        char DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
#if DEBUG
        PrintToChatAll(DebugBuff);
#endif
    }
}

int InSecondHalfOfRound() {
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

bool IsSurvivor(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR);
}