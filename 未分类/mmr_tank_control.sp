#pragma semicolon 1;

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <readyup>
#include <l4d_tank_control_eq>

#pragma newdecls required

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))

#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define MAXSTEAMID              64
#define MAXMAP                  64
#define MAXTANKS                4

Handle g_hCvarDebug = INVALID_HANDLE;
Handle g_hTriePlayerRating = null;
Handle g_hTrieMatchups = null;
char g_sQueuedTankSteamId[MAXSTEAMID] = "";
char g_sFirstHalfTankSteamId[2][MAXSTEAMID];
int g_iTankCount = 0;
bool g_bRoundStarted = false;
bool g_bMatchupsGenerated = false;
int tankOrder[4] = {0, 1, 2, 3};
int g_iRound = 0;
ArrayList g_hTriePlayerRatingKeys;
ArrayList infectedPool;
ArrayList survivorPool;

public Plugin myinfo = {
    name = "MMR Tank Control",
    author = "devilesk",
    description = "MMR based tank control distribution.",
    version = "0.3.1",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public void OnPluginStart() {
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_PostNoCopy);

    RegServerCmd("mmr_tank_control", MmrTankControl_Command);
    RegConsoleCmd("sm_matchups", TankMatchups_Command, "");

    g_hCvarDebug = CreateConVar("mmr_tank_control_debug", "1", "Whether or not to debug to console", 0);

    g_hTriePlayerRating = CreateTrie();
    g_hTrieMatchups = CreateTrie();

    SortIntegers(tankOrder, 4, Sort_Random);

    g_hTriePlayerRatingKeys = new ArrayList(MAXSTEAMID);
    infectedPool = new ArrayList(MAXSTEAMID);
    survivorPool = new ArrayList(MAXSTEAMID);
    g_sFirstHalfTankSteamId[0][0] = '\0';
    g_sFirstHalfTankSteamId[1][0] = '\0';
}

public Action TankMatchups_Command(int client, int args) {
    if (!IS_VALID_INGAME(client))
        return Plugin_Handled;

    if (!g_bMatchupsGenerated) {
        CPrintToChat(client, "{red}Matchups are generated after the first round goes live.");
        return Plugin_Handled;
    }

    CPrintToChat(client, "{blue}MMR Tank Matchups: {default}(in no particular order)");

    char infectedSteamId[MAXSTEAMID];
    char survivorSteamId[MAXSTEAMID];
    float infectedRating = -999.0;
    float survivorRating = -999.0;
    char sInfectedRating[32];
    char sSurvivorRating[32];

    for (int i = 0; i < infectedPool.Length; i++) {
        infectedPool.GetString(i, infectedSteamId, sizeof(infectedSteamId));
        int infectedClient = GetValidInfectedClientBySteamId(infectedSteamId);
        if (infectedClient == -1) continue;

        if (GetTrieValue(g_hTriePlayerRating, infectedSteamId, infectedRating) && infectedRating != -999.0) {
            Format(sInfectedRating, sizeof(sInfectedRating), "%.2f", infectedRating);
        }
        else {
            sInfectedRating = "N/A";
        }

        if (!GetTrieString(g_hTrieMatchups, infectedSteamId, survivorSteamId, sizeof(survivorSteamId))) {
            CPrintToChat(client, "{green}%N {default}({green}%s{default}) no matchup found", infectedClient, sInfectedRating);
            continue;
        }

        int survivorClient = GetValidSurvivorClientBySteamId(survivorSteamId);
        if (survivorClient == -1) {
            CPrintToChat(client, "{green}%N {default}({green}%s{default}) no matchup found", infectedClient, sInfectedRating);
            continue;
        }

        if (GetTrieValue(g_hTriePlayerRating, survivorSteamId, survivorRating) && survivorRating != -999.0) {
            Format(sSurvivorRating, sizeof(sSurvivorRating), "%.2f", survivorRating);
        }
        else {
            sSurvivorRating = "N/A";
        }

        CPrintToChat(client, "{green}%N {default}({green}%s{default}) {blue}vs {green}%N {default}({green}%s{default})", infectedClient, sInfectedRating, survivorClient, sSurvivorRating);
    }

    return Plugin_Handled;
}

public Action MmrTankControl_Command(int args) {
    if (args < 2) {
        LogError("[MmrTankControl_Command] Missing args");
        return Plugin_Handled;
    }

    char steamId[MAXSTEAMID];
    GetCmdArg(1, steamId, sizeof(steamId));

    char sRating[16];
    GetCmdArg(2, sRating, sizeof(sRating));
    float fRating = StringToFloat(sRating);

    SetTrieValue(g_hTriePlayerRating, steamId, fRating);
    if (g_hTriePlayerRatingKeys.FindString(steamId) == -1) {
        g_hTriePlayerRatingKeys.PushString(steamId);
    }

    PrintDebug("[MmrTankControl_Command] Added steamId: %s, fRating: %f", steamId, fRating);

    return Plugin_Handled;
}

// When a new game starts, reset the tank pool.
public void TankControlEQ_OnTankControlReset() {
    PrintDebug("[TankControlEQ_OnTankControlReset] Resetting tank control.");
    g_sQueuedTankSteamId[0] = '\0';
    g_iTankCount = 0;
    SortIntegers(tankOrder, 4, Sort_Random);
    ClearTrie(g_hTrieMatchups);
    infectedPool.Clear();
    survivorPool.Clear();
    g_bMatchupsGenerated = false;
}

public void OnRoundLiveCountdownPre() {
    GenerateMatchups();
}

void GenerateMatchups() {
    infectedPool.Clear();
    survivorPool.Clear();

    AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);
    AddTeamSteamIdsToArray(survivorPool, TEAM_SURVIVOR);

    infectedPool.SortCustom(SortSteamIdsByRating, g_hTriePlayerRating);
    survivorPool.SortCustom(SortSteamIdsByRating, g_hTriePlayerRating);

    char sSteamIdA[32];
    char sSteamIdB[32];
    ClearTrie(g_hTrieMatchups);
    for (int i = 0; i < min(GetArraySize(infectedPool), GetArraySize(survivorPool)); i++) {
        infectedPool.GetString(i, sSteamIdA, sizeof(sSteamIdA));
        survivorPool.GetString(i, sSteamIdB, sizeof(sSteamIdB));
        SetTrieString(g_hTrieMatchups, sSteamIdA, sSteamIdB);
        SetTrieString(g_hTrieMatchups, sSteamIdB, sSteamIdA);
    }

    char steamId[MAXSTEAMID];
    for (int i = 0; i < infectedPool.Length; i++) {
        infectedPool.GetString(i, steamId, sizeof(steamId));
        PrintDebug("[GenerateMatchups] infectedPool %s", steamId);
    }
    for (int i = 0; i < survivorPool.Length; i++) {
        survivorPool.GetString(i, steamId, sizeof(steamId));
        PrintDebug("[GenerateMatchups] survivorPool %s", steamId);
    }

    DumpOutput();
    g_bMatchupsGenerated = true;
}

void DumpOutput() {
    PrintDebug("[DumpOutput] round %i", g_iRound);
    PrintDebug("[DumpOutput] g_sQueuedTankSteamId %s", g_sQueuedTankSteamId);
    PrintDebug("[DumpOutput] tankOrder %i, %i, %i, %i", tankOrder[0], tankOrder[1], tankOrder[2], tankOrder[3]);

    char steamId[MAXSTEAMID];
    char matchupSteamId[MAXSTEAMID];

    for (int i = 0; i < infectedPool.Length; i++) {
        infectedPool.GetString(i, steamId, sizeof(steamId));
        int client = GetValidInfectedClientBySteamId(steamId);

        if (client == -1) {
            PrintDebug("[DumpOutput] infectedPool %s bad client %i", steamId, client);
        }
        else {
            if (GetTrieString(g_hTrieMatchups, steamId, matchupSteamId, sizeof(matchupSteamId))) {
                PrintDebug("[DumpOutput] infectedPool %s %i %N vs %s", steamId, client, client, matchupSteamId);
            }
            else {
                PrintDebug("[DumpOutput] infectedPool %s %i %N no matchup found", steamId, client, client);
            }
        }
    }

    char sSteamId[MAXSTEAMID];
    if (ChooseTank(sSteamId, sizeof(sSteamId))) {
        PrintDebug("[DumpOutput] tank player %s.", sSteamId);
    }
}

public void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast) {
    g_bRoundStarted = true;
    g_iTankCount = 0;
    g_sQueuedTankSteamId[0] = '\0';
    PrintDebug("[RoundStart_Event] InSecondHalfOfRound %i, round %i", InSecondHalfOfRound(), g_iRound);

    if (!InSecondHalfOfRound()) {
        g_sFirstHalfTankSteamId[0][0] = '\0';
        g_sFirstHalfTankSteamId[1][0] = '\0';
        PrintDebug("[RoundStart_Event] clearing first half queued tank");
    }
}

public void RoundEnd_Event(Handle event, const char[] name, bool dontBroadcast) {
    if (!g_bRoundStarted) return;

    g_bRoundStarted = false;
    if (InSecondHalfOfRound()) {
        g_iRound++;
    }
    PrintDebug("[RoundEnd_Event] InSecondHalfOfRound %i, round %i", InSecondHalfOfRound(), g_iRound);
}

// When a player reconnects, check if they are the mmr tank player
public void OnClientConnected(int client)  {
    if (!g_bRoundStarted) return;
    char steamId[MAXSTEAMID];
    if (IS_VALID_INFECTED(client)) {
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
        if (StrEqual(g_sQueuedTankSteamId, steamId)) {
            PrintDebug("[OnClientConnected] mmr tank player reconnected. Setting player as tank. steamId: %s.", steamId);
            TankControlEQ_SetTank(steamId);
        }
    }
}

// When the queued tank switches to infected, check if they are the mmr tank player
public void PlayerTeam_Event(Handle event, const char[] name, bool dontBroadcast) {
    if (!g_bRoundStarted) return;
    char steamId[MAXSTEAMID];
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IS_VALID_INFECTED(client)) {
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
        if (StrEqual(g_sQueuedTankSteamId, steamId)) {
            PrintDebug("[OnClientConnected] mmr tank player joined infected. Setting player as tank. steamId: %s.", steamId);
            TankControlEQ_SetTank(steamId);
        }
    }
}

bool ChooseTank(char[] buffer, int size) {
    // find a mmr tank player in the pool of tank players

    ArrayList hTankPool = TankControlEQ_GetTankPool();
    char sSteamId[MAXSTEAMID];

    // for the first 3 rounds and first tank of round 4, use the tank order
    if ((g_iRound >= 0 && g_iRound < 3) || (g_iRound == 3 && g_iTankCount == 0)) {
        int tankIndex = tankOrder[g_iRound];
        if (infectedPool.Length > tankIndex) {
            infectedPool.GetString(tankIndex, sSteamId, sizeof(sSteamId));
            if (FindStringInArray(hTankPool, sSteamId) != -1) {
                strcopy(buffer, size, sSteamId); // store mmr tank player in case they disconnect or change teams
                PrintDebug("[ChooseTank] Found player %s.", sSteamId);
                delete hTankPool;
                return true;
            }
            else {
                PrintDebug("[ChooseTank] Player not in tank pool %s.", sSteamId);
            }
        }
        else {
            PrintDebug("[ChooseTank] Infected pool size %i <= tankIndex %i.", infectedPool.Length, tankIndex);
        }
    }
    // tank choosing logic for the second tank of round 4 and rounds 5+
    else if ((g_iRound >= 4 && g_iTankCount < 2) || (g_iRound == 3 && g_iTankCount > 0)) {
        PrintDebug("[ChooseTank] round %i g_iTankCount %i InSecondHalfOfRound %i", g_iRound, g_iTankCount, InSecondHalfOfRound());

        ArrayList hNotTankPool = TankControlEQ_GetWhosNotHadTank();
        char matchupSteamId[MAXSTEAMID] = "";

        // second round use first round matchup if they have not had tank
        if (InSecondHalfOfRound()) {
            if (g_sFirstHalfTankSteamId[g_iTankCount][0]) {
                PrintDebug("[ChooseTank] g_sFirstHalfTankSteamId %i %s", g_iTankCount, g_sFirstHalfTankSteamId[g_iTankCount]);
                if (GetTrieString(g_hTrieMatchups, g_sFirstHalfTankSteamId[g_iTankCount], matchupSteamId, sizeof(matchupSteamId))) {
                    PrintDebug("[ChooseTank] matchupSteamId %s", matchupSteamId);
                    if (hNotTankPool.Length == 0 || FindStringInArray(hNotTankPool, matchupSteamId) != -1) {
                        PrintDebug("[ChooseTank] hNotTankPool.Length %i = 0 or %s in hNotTankPool", hNotTankPool.Length, matchupSteamId);
                        if (GetValidInfectedClientBySteamId(matchupSteamId) != -1) {
                            PrintDebug("[ChooseTank] matchupSteamId %s is valid infected", matchupSteamId);
                            strcopy(buffer, size, matchupSteamId); // store mmr tank player in case they disconnect or change teams
                            delete hTankPool;
                            delete hNotTankPool;
                            return true;
                        }
                        else {
                            PrintDebug("[ChooseTank] matchupSteamId %s not valid infected player", matchupSteamId);
                        }
                    }
                    else {
                        PrintDebug("[ChooseTank] matchupSteamId %s not in not had tank pool", matchupSteamId);
                    }
                }
                else {
                    PrintDebug("[ChooseTank] no matchup found for %s", g_sFirstHalfTankSteamId[g_iTankCount]);
                }
            }
            else {
                PrintDebug("[ChooseTank] no g_sFirstHalfTankSteamId %i", g_iTankCount);
            }
        }

        // select random player for tank from list of not had tank
        if (hNotTankPool.Length > 0) {
            PrintDebug("[ChooseTank] hNotTankPool.Length %i > 0, randomizing", hNotTankPool.Length);
            hNotTankPool.Sort(Sort_Random, Sort_String);
            for (int i = 0; i < GetArraySize(hNotTankPool); i++) {
                hNotTankPool.GetString(i, sSteamId, sizeof(sSteamId));
                if (GetValidInfectedClientBySteamId(sSteamId) != -1) {
                    PrintDebug("[ChooseTank] sSteamId %s is valid infected", sSteamId);
                    strcopy(buffer, size, sSteamId); // store mmr tank player in case they disconnect or change teams
                    delete hTankPool;
                    delete hNotTankPool;
                    return true;
                }
                else {
                    PrintDebug("[ChooseTank] sSteamId %s not valid infected player", matchupSteamId);
                }
            }
        }
        else {
            PrintDebug("[ChooseTank] hNotTankPool empty");
        }

        // second round use first round matchup because no one found in list of not had tank
        if (InSecondHalfOfRound() && matchupSteamId[0] && GetValidInfectedClientBySteamId(matchupSteamId) != -1) {
            PrintDebug("[ChooseTank] falling back to matchupSteamId %s as tank", sSteamId);
            strcopy(buffer, size, matchupSteamId); // store mmr tank player in case they disconnect or change teams
            delete hTankPool;
            delete hNotTankPool;
            return true;
        }

        delete hNotTankPool;
    }
    else {
        PrintDebug("[ChooseTank] round %i g_iTankCount %i", g_iRound, g_iTankCount);
    }
    delete hTankPool;
    return false;
}

public Action TankControlEQ_OnChooseTank() {
    // find a mmr tank player in the pool of tank players
    char sSteamId[MAXSTEAMID];
    if (ChooseTank(sSteamId, sizeof(sSteamId))) {
        strcopy(g_sQueuedTankSteamId, sizeof(g_sQueuedTankSteamId), sSteamId); // store mmr tank player in case they disconnect or change teams
        PrintDebug("[TankControlEQ_OnChooseTank] Setting tank %i to %s.", g_iTankCount, sSteamId);
        TankControlEQ_SetTank(sSteamId);
        return Plugin_Handled;
    }

    PrintDebug("[TankControlEQ_OnChooseTank] No mmr tank player in tank pool. Continuing with default tank selection.");
    return Plugin_Continue;
}

public void TankControlEQ_OnTankGiven(const char[] steamId) {
    // stop storing mmr tank player once they've been given tank
    if (StrEqual(g_sQueuedTankSteamId, steamId))
        g_sQueuedTankSteamId[0] = '\0';

    // store mmr tank player for next half tank matchup
    if (!InSecondHalfOfRound() && g_iTankCount < 2) {
        strcopy(g_sFirstHalfTankSteamId[g_iTankCount], MAXSTEAMID, steamId);
        PrintDebug("[TankControlEQ_OnTankGiven] saved tank %i %s to g_sFirstHalfTankSteamId %s", g_iTankCount, steamId, g_sFirstHalfTankSteamId[g_iTankCount]);
    }

    g_iTankCount++;

    PrintDebug("[TankControlEQ_OnTankGiven] Gave tank %i to %s.", g_iTankCount, steamId);
}

void AddTeamSteamIdsToArray(ArrayList steamIds, int team) {
    char steamId[MAXSTEAMID];

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team) {
            GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
            steamIds.PushString(steamId);
        }
    }
}

int SortSteamIdsByRating(int index1, int index2, Handle steamIds, Handle hTriePlayerRating) {
    char sSteamIdA[MAXSTEAMID];
    char sSteamIdB[MAXSTEAMID];
    GetArrayString(steamIds, index1, sSteamIdA, sizeof(sSteamIdA));
    GetArrayString(steamIds, index2, sSteamIdB, sizeof(sSteamIdB));
    float ratingA;
    float ratingB;
    if (!GetTrieValue(hTriePlayerRating, sSteamIdA, ratingA)) {
        ratingA = -999.0;
    }
    if (!GetTrieValue(hTriePlayerRating, sSteamIdB, ratingB)) {
        ratingB = -999.0;
    }
    if (ratingA < ratingB) {
        return -1;
    }
    else if (ratingA > ratingB) {
        return 1;
    }
    return 0;
}

int GetValidInfectedClientBySteamId(const char[] steamId) {
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

int GetValidSurvivorClientBySteamId(const char[] steamId) {
    char tmpSteamId[MAXSTEAMID];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IS_VALID_SURVIVOR(i))
            continue;

        GetClientAuthId(i, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));

        if (StrEqual(steamId, tmpSteamId))
            return i;
    }

    return -1;
}

int InSecondHalfOfRound() {
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

int min(int a, int b) {
    return a < b ? a : b;
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
        //PrintToChatAll(DebugBuff); 
    }
}