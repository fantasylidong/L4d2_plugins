#pragma semicolon 1

#define DEBUG 0

#include <sourcemod>
#include <sdktools>
#include <l4d2lib>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>
#include <left4dhooks>
#include "includes/rl4d2l_util"

#pragma newdecls required

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))

public Plugin myinfo = {
    name = "Tank and no Witch ifier!",
    author = "CanadaRox, Sir, devilesk",
    version = "2.2.2",
    description = "Sets a tank spawn and removes witch spawn point on every map",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

Handle g_hVsBossBuffer;
Handle g_hVsBossFlowMax;
Handle g_hVsBossFlowMin;
StringMap hStaticTankMaps;
Handle g_hCvarDebug = INVALID_HANDLE;
bool bValidSpawn[101];

public void OnPluginStart() {
    g_hCvarDebug = CreateConVar("sm_tank_nowitch_debug", "0", "Tank and no Witch ifier debug mode", 0, true, 0.0, true, 1.0);
    
    g_hVsBossBuffer = FindConVar("versus_boss_buffer");
    g_hVsBossFlowMax = FindConVar("versus_boss_flow_max");
    g_hVsBossFlowMin = FindConVar("versus_boss_flow_min");
    hStaticTankMaps = new StringMap();

    HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
    RegServerCmd("static_tank_map", StaticTank_Command);
    RegServerCmd("reset_static_maps", Reset_Command);
    
    RegAdminCmd("sm_tank_nowitch_debug_info", Info_Cmd, ADMFLAG_KICK, "Dump spawn state info");

#if DEBUG
    RegConsoleCmd("sm_tank_nowitch_debug_test", Test_Cmd);
#endif
}

public Action L4D_OnSpawnWitch(const float vector[3], const float qangle[3]) {
    return Plugin_Handled;
}

public Action L4D_OnSpawnWitchBride(const float vector[3], const float qangle[3]) {
    return Plugin_Handled;
}

public Action StaticTank_Command(int args) {
    char mapname[64];
    GetCmdArg(1, mapname, sizeof(mapname));
    StrToLower(mapname);
    hStaticTankMaps.SetValue(mapname, true);
#if DEBUG
    PrintDebug("[StaticTank_Command] Added: %s", mapname);
#endif
}

public Action Reset_Command(int args) {
    hStaticTankMaps.Clear();
}

public Action RoundStartEvent(Handle event, const char[] name, bool dontBroadcast) {
    CreateTimer(0.5, AdjustBossFlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Info_Cmd(int client, int args) {
    PrintDebugInfoDump();
}
#if DEBUG
public Action Test_Cmd(int client, int args) {
    PrintDebug("[Test_Cmd] Starting AdjustBossFlow timer...");
    CreateTimer(0.5, AdjustBossFlow, _, TIMER_FLAG_NO_MAPCHANGE);
}
#endif

public Action AdjustBossFlow(Handle timer) {
    if (InSecondHalfOfRound()) return;

    char sCurMap[64];
    int dummy;
    GetCurrentMapLower(sCurMap, sizeof(sCurMap));

    // javascript implementation to test algorithm: https://jsfiddle.net/4ncw70Lv/

    if (!hStaticTankMaps.GetValue(sCurMap, dummy)) {
        PrintDebug("[AdjustBossFlow] Not static tank map. Flow tank enabled.");

        int iCvarMinFlow = RoundFloat(GetConVarFloat(g_hVsBossFlowMin) * 100);
        int iCvarMaxFlow = RoundFloat(GetConVarFloat(g_hVsBossFlowMax) * 100);

        // mapinfo override
        iCvarMinFlow = L4D2_GetMapValueInt("versus_boss_flow_min", iCvarMinFlow);
        iCvarMaxFlow = L4D2_GetMapValueInt("versus_boss_flow_max", iCvarMaxFlow);

        int iMinBanFlow = L4D2_GetMapValueInt("tank_ban_flow_min", -1);
        int iMaxBanFlow = L4D2_GetMapValueInt("tank_ban_flow_max", -1);
        int iMinBanFlowB = L4D2_GetMapValueInt("tank_ban_flow_min_b", -1);
        int iMaxBanFlowB = L4D2_GetMapValueInt("tank_ban_flow_max_b", -1);
        int iMinBanFlowC = L4D2_GetMapValueInt("tank_ban_flow_min_c", -1);
        int iMaxBanFlowC = L4D2_GetMapValueInt("tank_ban_flow_max_c", -1);

        PrintDebug("[AdjustBossFlow] flow: (%i, %i). ban (%i, %i). ban b (%i, %i). ban c (%i, %i)", iCvarMinFlow, iCvarMaxFlow, iMinBanFlow, iMaxBanFlow, iMinBanFlowB, iMaxBanFlowB, iMinBanFlowC, iMaxBanFlowC);

        // check each array index to see if it is within a ban range
        int iValidSpawnTotal = 0;
        for (int i = 0; i <= 100; i++) {
            bValidSpawn[i] = (iCvarMinFlow <= i && i <= iCvarMaxFlow) && !(iMinBanFlow <= i && i <= iMaxBanFlow) && !(iMinBanFlowB <= i && i <= iMaxBanFlowB) && !(iMinBanFlowC <= i && i <= iMaxBanFlowC);
            if (bValidSpawn[i]) iValidSpawnTotal++;
        }

        if (iValidSpawnTotal == 0) {
            L4D2Direct_SetVSTankToSpawnThisRound(0, false);
            L4D2Direct_SetVSTankToSpawnThisRound(1, false);
            PrintDebug("[AdjustBossFlow] Ban range covers entire flow range. Flow tank disabled.");
        }
        else {
            int n = Math_GetRandomInt(1, iValidSpawnTotal);

            // the nth valid spawn index is the chosen tank flow %
            for (int iTankFlow = 0; iTankFlow <= 100; iTankFlow++) {
                if (bValidSpawn[iTankFlow]) {
                    n--;
                    if (n == 0) {
                        float fTankFlow = iTankFlow / 100.0;
                        PrintDebug("[AdjustBossFlow] iTankFlow: %i, fTankFlow: %f. iValidSpawnTotal: %i", iTankFlow, fTankFlow, iValidSpawnTotal);
                        L4D2Direct_SetVSTankToSpawnThisRound(0, true);
                        L4D2Direct_SetVSTankToSpawnThisRound(1, true);
                        L4D2Direct_SetVSTankFlowPercent(0, fTankFlow);
                        L4D2Direct_SetVSTankFlowPercent(1, fTankFlow);
                        break;
                    }
                }
            }
        }
    }
    else {
        L4D2Direct_SetVSTankToSpawnThisRound(0, false);
        L4D2Direct_SetVSTankToSpawnThisRound(1, false);

        PrintDebug("[AdjustBossFlow] Static tank map. Flow tank disabled.");
    }
    L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
    L4D2Direct_SetVSWitchToSpawnThisRound(1, false);

    PrintDebugInfoDump();
}

stock float GetTankFlow(int round) {
    return L4D2Direct_GetVSTankFlowPercent(round) - GetConVarFloat(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();
}

stock void PrintDebugInfoDump() {
    if (GetConVarBool(g_hCvarDebug)) {
        PrintDebug("[Round 1] tank enabled: %i, tank flow: %f, display: %f, witch enabled: %i", L4D2Direct_GetVSTankToSpawnThisRound(0), L4D2Direct_GetVSTankFlowPercent(0), GetTankFlow(0), L4D2Direct_GetVSWitchToSpawnThisRound(0));
        PrintDebug("[Round 2] tank enabled: %i, tank flow: %f, display: %f, witch enabled: %i", L4D2Direct_GetVSTankToSpawnThisRound(1), L4D2Direct_GetVSTankFlowPercent(1), GetTankFlow(1), L4D2Direct_GetVSWitchToSpawnThisRound(1));
    }
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

#define SIZE_OF_INT         2147483647 // without 0
stock int Math_GetRandomInt(int min, int max)
{
    int random = GetURandomInt();

    if (random == 0) {
        random++;
    }

    return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}
