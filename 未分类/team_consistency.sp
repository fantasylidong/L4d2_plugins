#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <readyup>

#define ROUNDEND_DELAY          3.0
#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

bool g_bRoundLive = false;

Handle g_hCvarDebug = null;
Handle g_hTriePlayerTeam = null;

public Plugin myinfo =
{
    name = "Team Consistency",
    author = "devilesk",
    description = "Maintain consistent teams throughout a match.",
    version = "1.1.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("team_consistency");
    
    CreateNative("ClearTeamConsistency", Native_ClearTeamConsistency);
    return APLRes_Success;
}

public int Native_ClearTeamConsistency(Handle plugin, int numParams)
{
    ClearTrie(g_hTriePlayerTeam);
    return 1;
}

public void OnPluginStart()
{
    g_hCvarDebug = CreateConVar("team_consistency_debug", "1", "Whether or not to debug to console", 0);

    RegAdminCmd("sm_swap", Swap_Cmd, ADMFLAG_KICK, "");
    RegConsoleCmd("sm_untrackteam", UntrackTeam_Cmd, "");

    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);

    g_hTriePlayerTeam = CreateTrie();
}

public void OnMapStart() {
    g_bRoundLive = false;
}

public void OnRoundLiveCountdownPre() {
    g_bRoundLive = true;
}

// Store the logical team that players are on when the round ends
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if ( !g_bRoundLive ) {
        return;
    }
    g_bRoundLive = false;

    int survivorLogicalTeam = GameRules_GetProp("m_bAreTeamsFlipped");
    int infectedLogicalTeam = 1 - survivorLogicalTeam;

    PrintDebug("[Event_RoundEnd] Survivor index: %i Infected index: %i", survivorLogicalTeam, infectedLogicalTeam);

    for ( int client = 1; client <= MaxClients; client++ )
    {
        if (!IsClientInGame(client) || IsFakeClient(client)) continue;

        char sSteamId[32];
        GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));

        if (IS_VALID_SURVIVOR(client))
        {
            SetTrieValue(g_hTriePlayerTeam, sSteamId, survivorLogicalTeam);
            PrintDebug("[Event_RoundEnd] Saving survivor %N %s logical team %i.", client, sSteamId, survivorLogicalTeam);
        }
        else if (IS_VALID_INFECTED(client)) {
            SetTrieValue(g_hTriePlayerTeam, sSteamId, infectedLogicalTeam);
            PrintDebug("[Event_RoundEnd] Saving infected %N %s logical team %i.", client, sSteamId, infectedLogicalTeam);
        }
    }
}

public Action UntrackTeam_Cmd(int client, int args) {
    char sSteamId[32];
    GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
    PrintDebug("[UntrackTeam_Cmd] Removing saved logical team for client: %i %N", client, client);
    RemoveFromTrie(g_hTriePlayerTeam, sSteamId);
    CPrintToChatAll("{default}[{green}Team Consistency{default}] Cleared tracked team value for {olive}%N{default}.", client);
    return Plugin_Handled;
}

// Untrack swap targets so the swaps goes through
public Action Swap_Cmd(int client, int args) {
    if (args < 1)
    {
        return Plugin_Continue;
    }

    char argbuf[MAX_NAME_LENGTH];

    int[] targets = new int[MaxClients+1];
    int target;
    int targetCount;
    char target_name[MAX_TARGET_LENGTH];
    bool tn_is_ml;
    char sSteamId[32];

    for (int i = 1; i <= args; i++)
    {
        GetCmdArg(i, argbuf, sizeof(argbuf));
        targetCount = ProcessTargetString(
                argbuf,
                0,
                targets,
                MaxClients+1,
                COMMAND_FILTER_NO_BOTS,
                target_name,
                sizeof(target_name),
                tn_is_ml);

        for (int j = 0; j < targetCount; j++)
        {
            target = targets[j];
            if (!IsClientInGame(target) || IsFakeClient(target)) continue;
            GetClientAuthId(target, AuthId_Steam2, sSteamId, sizeof(sSteamId));
            PrintDebug("[Swap_Cmd] Removing saved logical team for client: %i %N", target, target);
            RemoveFromTrie(g_hTriePlayerTeam, sSteamId);
        }
    }

    return Plugin_Continue;
}

// Trigger team consistency check whenever a tracked player joins survivor or infected
public void PlayerTeam_Event(Handle event, const char[] name, bool dontBroadcast) {
    // No check while round is live
    if (g_bRoundLive) {
        return;
    }

    int team = GetEventInt(event, "team");
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!IsClientInGame(client) || IsFakeClient(client) || team == TEAM_SPECTATOR) return;

    char sSteamId[32];
    int playerLogicalTeam;
    GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
    if (GetTrieValue(g_hTriePlayerTeam, sSteamId, playerLogicalTeam)) {
        PrintDebug("[PlayerTeam_Event] Found saved logical team %i for client: %i %N team: %i", playerLogicalTeam, client, client, team);
        RequestFrame(SetTeams);
    }
    else {
        PrintDebug("[PlayerTeam_Event] No saved logical team for client: %i %N team: %i", client, client, team);
    }
}

// Move all tracked players on the wrong team to spectator first and then move them to the correct team
void SetTeams() {
    int survivorLogicalTeam = GameRules_GetProp("m_bAreTeamsFlipped");
    int infectedLogicalTeam = 1 - survivorLogicalTeam;
    char sSteamId[32];
    int playerLogicalTeam;

    PrintDebug("[SetTeams] Logical team %i as survivor, logical team %i as infected", survivorLogicalTeam, infectedLogicalTeam);
    PrintDebug("[SetTeams] Moving players to spectator...");
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client)) continue;
        GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
        if (GetTrieValue(g_hTriePlayerTeam, sSteamId, playerLogicalTeam)) {
            int clientTeam = GetClientTeam(client);
            if (clientTeam == TEAM_SPECTATOR) {
                PrintDebug("[SetTeams] Already spectator %N %s. Saved logical team: %i", client, sSteamId, playerLogicalTeam);
                continue;
            }
            if (playerLogicalTeam == survivorLogicalTeam && clientTeam != TEAM_SURVIVOR) {
                ChangeClientTeam(client, TEAM_SPECTATOR);
                PrintDebug("[SetTeams] Moving to spectator %N %s. Team: %i. Saved logical team: %i", client, sSteamId, clientTeam, playerLogicalTeam);
            }
            else if (playerLogicalTeam == infectedLogicalTeam && clientTeam != TEAM_INFECTED) {
                ChangeClientTeam(client, TEAM_SPECTATOR);
                PrintDebug("[SetTeams] Moving to spectator %N %s. Team: %i. Saved logical team: %i", client, sSteamId, clientTeam, playerLogicalTeam);
            }
            else {
                PrintDebug("[SetTeams] On the correct team %N %s. Team: %i. Saved logical team: %i", client, sSteamId, clientTeam, playerLogicalTeam);
            }
        }
        else {
            //ChangeClientTeam(client, TEAM_SPECTATOR);
            PrintDebug("[SetTeams] Player not found %N %s", client, sSteamId);
        }
    }

    PrintDebug("[SetTeams] Moving players to teams...");
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client)) continue;
        GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
        if (GetTrieValue(g_hTriePlayerTeam, sSteamId, playerLogicalTeam)) {
            int clientTeam = GetClientTeam(client);
            if (playerLogicalTeam == survivorLogicalTeam && clientTeam != TEAM_SURVIVOR) {
                int flags = GetCommandFlags("sb_takecontrol");
                SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
                FakeClientCommand(client, "sb_takecontrol");
                SetCommandFlags("sb_takecontrol", flags);
                CPrintToChatAll("{default}[{green}Team Consistency{default}] Moved {olive}%N{default} to survivor.", client);
                PrintDebug("[SetTeams] Moving to survivor %N %s. Team: %i. Saved logical team: %i", client, sSteamId, clientTeam, playerLogicalTeam);
            }
            else if (playerLogicalTeam == infectedLogicalTeam && clientTeam != TEAM_INFECTED) {
                ChangeClientTeam(client, TEAM_INFECTED);
                CPrintToChatAll("{default}[{green}Team Consistency{default}] Moved {olive}%N{default} to infected.", client);
                PrintDebug("[SetTeams] Moving to infected %N %s. Team: %i. Saved logical team: %i", client, sSteamId, clientTeam, playerLogicalTeam);
            }
            else {
                PrintDebug("[SetTeams] On the correct team %N %s. Team: %i. Saved logical team: %i", client, sSteamId, clientTeam, playerLogicalTeam);
            }
        }
        else {
            PrintDebug("[SetTeams] Player not found %N %s", client, sSteamId);
        }
    }
}

stock void PrintDebug(const char[] Message, any ...) {
    if (GetConVarBool(g_hCvarDebug)) {
        char DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
        //PrintToChatAll(DebugBuff);
    }
}