#pragma semicolon 1;

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <readyup>
#include <builtinvotes>

#pragma newdecls required

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define MAXSTEAMID              64
#define MAXMAP                  64
#define MAXTANKS                4

Handle g_hCvarDebug = INVALID_HANDLE;
Handle g_hTriePlayerRating = null;
bool g_bMatchLive = false;
bool g_bGenerated = false;
ArrayList g_hTriePlayerRatingKeys;

int g_iTeamCombinations[35][8] = {
{0, 1, 2, 3, 4, 5, 6, 7},
{0, 1, 2, 4, 3, 5, 6, 7},
{0, 1, 2, 5, 3, 4, 6, 7},
{0, 1, 3, 4, 2, 5, 6, 7},
{0, 1, 3, 5, 2, 4, 6, 7},
{0, 1, 4, 5, 2, 3, 6, 7},
{0, 1, 4, 6, 2, 3, 5, 7},
{0, 1, 4, 7, 2, 3, 5, 6},
{0, 1, 5, 6, 2, 3, 4, 7},
{0, 1, 5, 7, 2, 3, 4, 6},
{0, 2, 3, 4, 1, 5, 6, 7},
{0, 2, 3, 5, 1, 4, 6, 7},
{0, 2, 4, 5, 1, 3, 6, 7},
{0, 2, 4, 6, 1, 3, 5, 7},
{0, 2, 4, 7, 1, 3, 5, 6},
{0, 2, 5, 6, 1, 3, 4, 7},
{0, 2, 5, 7, 1, 3, 4, 6},
{0, 3, 4, 5, 1, 2, 6, 7},
{0, 3, 4, 6, 1, 2, 5, 7},
{0, 3, 4, 7, 1, 2, 5, 6},
{0, 3, 5, 6, 1, 2, 4, 7},
{0, 3, 5, 7, 1, 2, 4, 6},
{0, 4, 5, 6, 1, 2, 3, 7},
{0, 4, 5, 7, 1, 2, 3, 6},
{0, 4, 6, 7, 1, 2, 3, 5},
{0, 5, 6, 7, 1, 2, 3, 4},
{1, 2, 4, 5, 0, 3, 6, 7},
{1, 3, 4, 5, 0, 2, 6, 7},
{1, 4, 5, 6, 0, 2, 3, 7},
{1, 4, 5, 7, 0, 2, 3, 6},
{2, 3, 4, 5, 0, 1, 6, 7},
{2, 4, 5, 6, 0, 1, 3, 7},
{2, 4, 5, 7, 0, 1, 3, 6},
{3, 4, 5, 6, 0, 1, 2, 7},
{3, 4, 5, 7, 0, 1, 2, 6}
};

char g_sTeamCombinationSteamIds[35][8][MAXSTEAMID];
int g_iTeamCombinationClients[35][8];
float g_fTeamCombinationRatings[35][8];
float g_fTeamCombinationRatingTotals[35][2];
float g_fTeamCombinationRatingDiff[35];
int g_iTeamCombinationSortOrder[35] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34};

enum VoteType
{
    VoteType_Teams,
    VoteType_SetMmr
}

Handle hVote = INVALID_HANDLE;
VoteType g_VoteType;
int g_iVoteTeamIndex;
int g_iVoteSetMmrTarget;
float g_fVoteSetMmrValue;
char g_Name[32];

public Plugin myinfo = {
    name = "Team Generator",
    author = "devilesk",
    description = "Balance teams based on rating.",
    version = "0.2.1",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public void OnPluginStart() {
    RegServerCmd("mmr_tank_control", MmrTankControl_Command);
    RegConsoleCmd("sm_mmr", Mmr_Command, "");
    RegConsoleCmd("sm_setmmr", SetMmr_Command, "");
    RegConsoleCmd("sm_teams", Teams_Command, "");

    g_hCvarDebug = CreateConVar("team_generator_debug", "1", "Whether or not to debug to console", 0);

    g_hTriePlayerRating = CreateTrie();

    g_hTriePlayerRatingKeys = new ArrayList(MAXSTEAMID);
}

public Action Mmr_Command(int client, int args) {
    if (!IS_VALID_INGAME(client))
        return Plugin_Handled;

    CPrintToChat(client, "{blue}Player Ratings:");

    ArrayList players = new ArrayList(MAXSTEAMID);
    char steamId[MAXSTEAMID];

    // get in game players from list of player rating steamids
    for (int i = 0; i < g_hTriePlayerRatingKeys.Length; i++) {
        g_hTriePlayerRatingKeys.GetString(i, steamId, sizeof(steamId));
        int player = GetValidClientBySteamId(steamId);
        if (player == -1) continue;
        players.PushString(steamId);
    }

    // sort players by rating
    players.SortCustom(SortSteamIdsByRating, g_hTriePlayerRating);

    float fRating = -999.0;
    char sRating[32];
    for (int i = 0; i < players.Length; i++) {
        players.GetString(i, steamId, sizeof(steamId));
        int player = GetValidClientBySteamId(steamId);
        if (player == -1) continue;

        if (GetTrieValue(g_hTriePlayerRating, steamId, fRating) && fRating != -999.0) {
            Format(sRating, sizeof(sRating), "%.2f", fRating);
        }
        else {
            sRating = "N/A";
        }

        if (IS_INFECTED(player)) {
            CPrintToChat(client, "{olive}%N {default}%s", player, sRating);
        }
        else if (IS_SURVIVOR(player)) {
            CPrintToChat(client, "{green}%N {default}%s", player, sRating);
        }
        else {
            CPrintToChat(client, "{blue}%N {default}%s", player, sRating);
        }
    }

    delete players;

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

public Action SetMmr_Command(int client, int args) {
    if (!IS_VALID_INGAME(client))
        return Plugin_Handled;

    if (g_bMatchLive) {
        CPrintToChat(client, "{red}Cannot set mmr after match has started.");
        return Plugin_Handled;
    }

    if (args != 2) {
        CPrintToChat(client, "[SM] Usage: sm_setmmr <player> <number>");
        return Plugin_Handled;
    }

    bool bIsAdmin = CheckCommandAccess(client, "sm_goto", ADMFLAG_KICK, true);

    if (!bIsAdmin) {
        if (IsSpectator(client)) {
            PrintToChat(client, "\x01[\x04Team Generator\x01] Vote can only be started by a player!");
            return Plugin_Handled;
        }
        else if (!IsNewBuiltinVoteAllowed()) {
            PrintToChat(client, "\x01[\x04Team Generator\x01] Vote cannot be started now.");
            return Plugin_Handled;
        }
    }
    else {
        if (IsBuiltinVoteInProgress()) {
            PrintToChat(client, "\x01[\x04Team Generator\x01] There is a vote in progress.");
            return Plugin_Handled;
        }
    }

    char sNameArg[32];
    GetCmdArg(1, sNameArg, sizeof(sNameArg));

    int target = -1;

    for(int i = 1; i <= MaxClients; i++) {
        if(!IsClientConnected(i)) continue;

        GetClientName(i, g_Name, sizeof(g_Name));

        if (StrEqual(g_Name, sNameArg, false)) {
            target = i;
            break;
        }
        else if (StrContains(g_Name, sNameArg, false) != -1) {
            target = i;
        }
    }
    
    if(target == -1)
    {
        PrintToConsole(client, "Could not find client \x04%s", sNameArg);
        PrintToChat(client, "Could not find client \x04%s", sNameArg);
        return Plugin_Handled;
    }

    char sValue[8];
    GetCmdArg(2, sValue, sizeof(sValue));
    float value = StringToFloat(sValue);

    if (bIsAdmin) {
        SetMmmr(target, value);
    }
    else {
        g_iVoteSetMmrTarget = target;
        g_fVoteSetMmrValue = value;
        char prompt[100];
        Format(prompt, sizeof(prompt), "Set %N rating to %.2f?", target, value);
        StartVote(client, prompt, VoteType_SetMmr);
        FakeClientCommand(client, "Vote Yes");
    }

    return Plugin_Handled;
}

public Action Teams_Command(int client, int args) {
    if (!IS_VALID_INGAME(client))
        return Plugin_Handled;

    if (g_bMatchLive) {
        CPrintToChat(client, "{red}Cannot set teams after match has started.");
        return Plugin_Handled;
    }

    if (args > 1) {
        CPrintToChat(client, "[SM] Usage: sm_teams <team # to use>(optional)");
        return Plugin_Handled;
    }

    if (!GenerateTeams()) {
        CPrintToChat(client, "{red}Not enough players on survivor and infected.");
        return Plugin_Handled;
    }

    if (args == 0) {
        for (int i = 0; i < 5; i++) {
            PrintTeam(g_iTeamCombinationSortOrder[i]);
        }
    }
    else {
        int index = 1;
        int teamIndex = g_iTeamCombinationSortOrder[index - 1];
        char arg2[3];
        GetCmdArg(1, arg2, sizeof(arg2));
        if (StringToIntEx(arg2, index) < 1 || StringToIntEx(arg2, index) > 35) {
            CPrintToChat(client, "Team # must be between 1 and 35");
            return Plugin_Handled;
        }
        PrintTeam(teamIndex);

        bool bIsAdmin = CheckCommandAccess(client, "sm_goto", ADMFLAG_KICK, true);
        
        if (!bIsAdmin) {
            if (IsSpectator(client)) {
                PrintToChat(client, "\x01[\x04Team Generator\x01] Vote can only be started by a player!");
                return Plugin_Handled;
            }
            else if (!IsNewBuiltinVoteAllowed()) {
                PrintToChat(client, "\x01[\x04Team Generator\x01] Vote cannot be started now.");
                return Plugin_Handled;
            }
        }
        else {
            if (IsBuiltinVoteInProgress()) {
                PrintToChat(client, "\x01[\x04Team Generator\x01] There is a vote in progress.");
                return Plugin_Handled;
            }
        }

        if (bIsAdmin) {
            SetTeams(teamIndex);
        }
        else {
            g_iVoteTeamIndex = teamIndex;
            char prompt[100];
            Format(prompt, sizeof(prompt), "Use team %i?", index);
            StartVote(client, prompt, VoteType_Teams);
            FakeClientCommand(client, "Vote Yes");
        }
    }

    return Plugin_Handled;
}

void SetMmmr(int target, float value) {
    char steamId[MAXSTEAMID];
    GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));
    SetTrieValue(g_hTriePlayerRating, steamId, value);
    if (g_hTriePlayerRatingKeys.FindString(steamId) == -1) {
        g_hTriePlayerRatingKeys.PushString(steamId);
    }
    CPrintToChatAll("%N rating to %.2f", target, value);
}

void PrintTeam(int i) {
    PrintDebug("[PrintTeam] %i %N %N %N %N %.2f %.2f %.2f %N %N %N %N",
            i,
            g_iTeamCombinationClients[i][0],
            g_iTeamCombinationClients[i][1],
            g_iTeamCombinationClients[i][2],
            g_iTeamCombinationClients[i][3],
            g_fTeamCombinationRatingTotals[i][0],
            g_fTeamCombinationRatingDiff[i],
            g_fTeamCombinationRatingTotals[i][1]);

    if (g_fTeamCombinationRatingDiff[i] >= 0) {
        CPrintToChatAll("{blue}%.2f{default} | {green}%N{default}, {green}%N{default}, {green}%N{default}, {green}%N",
            g_fTeamCombinationRatingTotals[i][0],
            g_iTeamCombinationClients[i][0],
            g_iTeamCombinationClients[i][1],
            g_iTeamCombinationClients[i][2],
            g_iTeamCombinationClients[i][3]);
        CPrintToChatAll("{blue}%.2f{default} | {green}%N{default}, {green}%N{default}, {green}%N{default}, {green}%N",
            g_fTeamCombinationRatingTotals[i][1],
            g_iTeamCombinationClients[i][4],
            g_iTeamCombinationClients[i][5],
            g_iTeamCombinationClients[i][6],
            g_iTeamCombinationClients[i][7]);
        CPrintToChatAll("{blue}%.2f", FloatAbs(g_fTeamCombinationRatingDiff[i]));
    }
    else {
        CPrintToChatAll("{blue}%.2f{default} | {green}%N{default}, {green}%N{default}, {green}%N{default}, {green}%N",
            g_fTeamCombinationRatingTotals[i][1],
            g_iTeamCombinationClients[i][4],
            g_iTeamCombinationClients[i][5],
            g_iTeamCombinationClients[i][6],
            g_iTeamCombinationClients[i][7]);
        CPrintToChatAll("{blue}%.2f{default} | {green}%N{default}, {green}%N{default}, {green}%N{default}, {green}%N",
            g_fTeamCombinationRatingTotals[i][0],
            g_iTeamCombinationClients[i][0],
            g_iTeamCombinationClients[i][1],
            g_iTeamCombinationClients[i][2],
            g_iTeamCombinationClients[i][3]);
        CPrintToChatAll("{blue}%.2f", FloatAbs(g_fTeamCombinationRatingDiff[i]));
    }
    CPrintToChatAll("------------------------------------------------------");
}

void SetTeams(int teamIndex) {
    if (g_bMatchLive) return;

    bool bTeamsFlipped = g_fTeamCombinationRatingDiff[teamIndex] < 0;

    for (int i = 0; i < 8; i++) {
        int client = g_iTeamCombinationClients[teamIndex][i];
        if (!IsClientInGame(client) || IsFakeClient(client)) continue;
        int clientTeam = GetClientTeam(client);
        if (clientTeam == TEAM_SPECTATOR) {
            continue;
        }
        if (!bTeamsFlipped && i < 4 && clientTeam == TEAM_INFECTED) {
            ChangeClientTeam(client, TEAM_SPECTATOR);
        }
        else if (!bTeamsFlipped && i >= 4 && clientTeam == TEAM_SURVIVOR) {
            ChangeClientTeam(client, TEAM_SPECTATOR);
        }
        else if (bTeamsFlipped && i < 4 && clientTeam == TEAM_SURVIVOR) {
            ChangeClientTeam(client, TEAM_SPECTATOR);
        }
        else if (bTeamsFlipped && i >= 4 && clientTeam == TEAM_INFECTED) {
            ChangeClientTeam(client, TEAM_SPECTATOR);
        }
    }

    for (int i = 0; i < 8; i++) {
        int client = g_iTeamCombinationClients[teamIndex][i];
        if (!IsClientInGame(client) || IsFakeClient(client)) continue;
        int clientTeam = GetClientTeam(client);
        if (clientTeam != TEAM_SURVIVOR && ((!bTeamsFlipped && i < 4) || (bTeamsFlipped && i >= 4))) {
            int flags = GetCommandFlags("sb_takecontrol");
            SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
            FakeClientCommand(client, "sb_takecontrol");
            SetCommandFlags("sb_takecontrol", flags);
        }
        else if (clientTeam != TEAM_INFECTED && ((!bTeamsFlipped && i >= 4) || (bTeamsFlipped && i < 4))) {
            ChangeClientTeam(client, TEAM_INFECTED);
        }
    }
}

public void OnRoundLiveCountdownPre() {
    if (g_bMatchLive) return;
    g_bMatchLive = true;
}

bool GenerateTeams() {
    ArrayList steamIds = new ArrayList(MAXSTEAMID);
    int clients[8];
    float ratings[8];
    char names[8][MAX_NAME_LENGTH];
    char steamId[MAXSTEAMID];

    AddTeamSteamIdsToArray(steamIds, TEAM_INFECTED);
    AddTeamSteamIdsToArray(steamIds, TEAM_SURVIVOR);

    // create cache of steamIds to clients, and steamIds to ratings
    for (int i = 0; i < steamIds.Length; i++) {
        steamIds.GetString(i, steamId, sizeof(steamId));
        int client = GetValidClientBySteamId(steamId);
        clients[i] = client;
        Format(names[i], MAX_NAME_LENGTH, "%N", client);

        float fRating = 0.0;
        GetTrieValue(g_hTriePlayerRating, steamId, fRating);
        ratings[i] = fRating;

        PrintDebug("[GenerateTeams] cache %i %s %s %.2f", client, steamId, names[i], fRating);
    }

    return DoGenerateTeams(steamIds, clients, ratings, names);
}

bool DoGenerateTeams(ArrayList steamIds, const int clients[8], const float ratings[8], const char[][] names) {
    char steamId[MAXSTEAMID];

    if (steamIds.Length != 8) {
        return false;
    }

    // map player steamids, clients, and ratings to team combinations
    for (int i = 0; i < 35; i++) {
        for (int j = 0; j < 8; j++) {
            int playerIndex = g_iTeamCombinations[i][j];
            steamIds.GetString(playerIndex, steamId, sizeof(steamId));
            g_sTeamCombinationSteamIds[i][j] = steamId;
            g_iTeamCombinationClients[i][j] = clients[playerIndex];
            g_fTeamCombinationRatings[i][j] = ratings[playerIndex];
        }
    }

    // calculate team combination rating totals and differences
    for (int i = 0; i < 35; i++) {
        g_fTeamCombinationRatingTotals[i][0] = g_fTeamCombinationRatings[i][0] + g_fTeamCombinationRatings[i][1] + g_fTeamCombinationRatings[i][2] + g_fTeamCombinationRatings[i][3];
        g_fTeamCombinationRatingTotals[i][1] = g_fTeamCombinationRatings[i][4] + g_fTeamCombinationRatings[i][5] + g_fTeamCombinationRatings[i][6] + g_fTeamCombinationRatings[i][7];
        g_fTeamCombinationRatingDiff[i] = g_fTeamCombinationRatingTotals[i][0] - g_fTeamCombinationRatingTotals[i][1];
    }

    // generate team combination sort order by rating difference
    for (int i = 0; i < 35; i++) {
        g_iTeamCombinationSortOrder[i] = i;
    }
    for (int i = 0; i < 35 - 1; i++) {
        for (int j = 0; j < 35 - i - 1; j++) {
            float ratingA = g_fTeamCombinationRatingDiff[g_iTeamCombinationSortOrder[j]];
            float ratingB = g_fTeamCombinationRatingDiff[g_iTeamCombinationSortOrder[j+1]];
            PrintDebug("[GenerateTeams] comparing i: %i, j: %i j+1: %i, order1: %i, order2: %i, ratingA: %.2f, ratingB: %.2f, swapping: %i",
                i,
                j,
                j+1,
                g_iTeamCombinationSortOrder[j],
                g_iTeamCombinationSortOrder[j+1],
                ratingA,
                ratingB,
                FloatAbs(ratingA) > FloatAbs(ratingB));
            if (FloatAbs(ratingA) > FloatAbs(ratingB)) {
                int tmp = g_iTeamCombinationSortOrder[j];
                g_iTeamCombinationSortOrder[j] = g_iTeamCombinationSortOrder[j+1];
                g_iTeamCombinationSortOrder[j+1] = tmp;
            }
        }
    }

    for (int j = 0; j < 35; j++) {
        int i = g_iTeamCombinationSortOrder[j];
        PrintDebug("[GenerateTeams] team %i, sort %i, %.2f %.2f %.2f, %s %s %s %s %s %s %s %s",
            i,
            j,
            g_fTeamCombinationRatingDiff[i],
            g_fTeamCombinationRatingTotals[i][0],
            g_fTeamCombinationRatingTotals[i][1],
            names[g_iTeamCombinations[i][0]],
            names[g_iTeamCombinations[i][1]],
            names[g_iTeamCombinations[i][2]],
            names[g_iTeamCombinations[i][3]],
            names[g_iTeamCombinations[i][4]],
            names[g_iTeamCombinations[i][5]],
            names[g_iTeamCombinations[i][6]],
            names[g_iTeamCombinations[i][7]]);
    }

    delete steamIds;
    g_bGenerated = true;

    return true;
}

public void StartVote(int client, const char[] sVoteHeader, VoteType voteType) {
    int iNumPlayers;
    int[] players = new int[MaxClients];
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientConnected(i) || !IsClientInGame(i)) continue;
        if (IsSpectator(i) || IsFakeClient(i)) continue;
        
        players[iNumPlayers++] = i;
    }

    g_VoteType = voteType;
    hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
    SetBuiltinVoteArgument(hVote, sVoteHeader);
    SetBuiltinVoteInitiator(hVote, client);
    SetBuiltinVoteResultCallback(hVote, VoteResultHandler);
    DisplayBuiltinVote(hVote, players, iNumPlayers, 20);
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2) {
    switch (action) {
        case BuiltinVoteAction_End: {
            hVote = INVALID_HANDLE;
            delete vote;
        }
        case BuiltinVoteAction_Cancel: {
            DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
        }
    }
}

public void VoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info) {
    for (int i = 0; i < num_items; i++) {
        if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
            if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2)) {
                DisplayBuiltinVotePass(vote, "Setting teams...");
                PrintToChatAll("\x01[\x04Team Generator\x01] Vote passed! Setting teams...");
                PrintDebug("[VoteResultHandler] Vote passed! Setting teams...");
                if (g_VoteType == VoteType_Teams)
                    SetTeams(g_iVoteTeamIndex);
                else if (g_VoteType == VoteType_SetMmr)
                    SetMmmr(g_iVoteSetMmrTarget, g_fVoteSetMmrValue);
                return;
            }
        }
    }
    DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

bool IsSpectator(int client) {
    return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SPECTATOR;
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

int GetValidClientBySteamId(const char[] steamId) {
    char tmpSteamId[MAXSTEAMID];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IS_VALID_INGAME(i))
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
        //PrintToChatAll(DebugBuff); 
    }
}