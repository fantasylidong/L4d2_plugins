#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <readyup>
#undef REQUIRE_PLUGIN
#include <caster_system>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_VALID_CASTER(%1)     (IS_VALID_INGAME(%1) && casterSystemAvailable && IsClientCaster(%1))

#define TEAM_INFECTED           3
#define ZC_TANK                 8
#define MAXSTEAMID              64

ArrayList g_hWhosHadTank;
ArrayList g_hWhosHadTankPersistent; // Tracks who has had tank and does not reset when tank pool is empty like g_hWhosHadTank does
char g_sQueuedTankSteamId[MAXSTEAMID] = "";
ConVar g_hCvarTankPrint = null;
ConVar g_hCvarDebug = null;
Handle g_hChooseTankForward = INVALID_HANDLE;
Handle g_hTankGivenForward = INVALID_HANDLE;
Handle g_hTankChosenForward = INVALID_HANDLE;
Handle g_hTankControlResetForward = INVALID_HANDLE;
bool g_bRoundStarted = false;
bool casterSystemAvailable;

public Plugin myinfo = {
    name = "L4D2 Tank Control - RL4D2L",
    author = "arti, Sir, devilesk",
    description = "Distributes the role of the tank evenly throughout the team",
    version = "1.0.2",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    RegPluginLibrary("l4d_tank_control_eq");

    CreateNative("GetTankSelection", Native_GetTankSelection);
    CreateNative("TankControlEQ_SetTank", Native_SetTank);
    CreateNative("TankControlEQ_GetWhosHadTank", Native_GetWhosHadTank);
    CreateNative("TankControlEQ_GetWhosNotHadTank", Native_GetWhosNotHadTank);
    CreateNative("TankControlEQ_ClearWhosHadTank", Native_ClearWhosHadTank);
    CreateNative("TankControlEQ_GetTankPool", Native_GetTankPool);

    return APLRes_Success;
}

public int Native_GetTankSelection(Handle plugin, int numParams) {
    return GetValidInfectedClientBySteamId(g_sQueuedTankSteamId);
}

public void OnPluginStart() {
    // Forwards
    g_hChooseTankForward = CreateGlobalForward("TankControlEQ_OnChooseTank", ET_Event, Param_String);
    g_hTankGivenForward = CreateGlobalForward("TankControlEQ_OnTankGiven", ET_Ignore, Param_String);
    g_hTankChosenForward = CreateGlobalForward("TankControlEQ_OnTankChosen", ET_Ignore, Param_String);
    g_hTankControlResetForward = CreateGlobalForward("TankControlEQ_OnTankControlReset", ET_Ignore, Param_String);

    // Load translations (for targeting player)
    LoadTranslations("common.phrases");

    // Event hooks
    HookEvent("player_left_start_area", PlayerLeftStartArea_Event, EventHookMode_PostNoCopy);
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_PostNoCopy);
    HookEvent("tank_killed", TankKilled_Event, EventHookMode_PostNoCopy);
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);

    // Admin commands
    RegAdminCmd("sm_tankshuffle", TankShuffle_Cmd, ADMFLAG_SLAY, "Re-picks at random someone to become tank.");
    RegAdminCmd("sm_givetank", GiveTank_Cmd, ADMFLAG_SLAY, "Gives the tank to a selected player");
    RegAdminCmd("sm_addtankpool", AddTankPool_Cmd, ADMFLAG_SLAY, "Adds selected player to tank pool.");
    RegAdminCmd("sm_queuetank", AddTankPool_Cmd, ADMFLAG_SLAY, "Adds selected player to tank pool.");
    RegAdminCmd("sm_removetankpool", RemoveTankPool_Cmd, ADMFLAG_SLAY, "Removes selected player from tank pool.");
    RegAdminCmd("sm_dequeuetank", RemoveTankPool_Cmd, ADMFLAG_SLAY, "Removes selected player from tank pool.");

    // Initialise the tank arrays/data values
    g_hWhosHadTank = CreateArray(MAXSTEAMID);
    g_hWhosHadTankPersistent = CreateArray(MAXSTEAMID);

    // Register the boss commands
    RegConsoleCmd("sm_tank", Tank_Cmd, "Shows who is becoming the tank.");
    RegConsoleCmd("sm_tankpool", TankPool_Cmd, "Shows who is in the pool of possible tanks.");
    RegConsoleCmd("sm_boss", Tank_Cmd, "Shows who is becoming the tank.");
    RegConsoleCmd("sm_witch", Tank_Cmd, "Shows who is becoming the tank.");

    // Cvars
    g_hCvarTankPrint = CreateConVar("tankcontrol_print_all", "0", "Who gets to see who will become the tank? (0 = Infected, 1 = Everyone)", 0);
    g_hCvarDebug = CreateConVar("tankcontrol_debug", "0", "Whether or not to debug to console", 0);
}

public void OnAllPluginsLoaded()
{
    casterSystemAvailable = LibraryExists("caster_system");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "caster_system")) casterSystemAvailable = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "caster_system")) casterSystemAvailable = false;
}

public int Native_SetTank(Handle plugin, int numParams) {
    int len;
    GetNativeStringLength(1, len);

    if (len <= 0) return 0;

    // Retrieve the arg
    char[] steamId = new char[len + 1];
    GetNativeString(1, steamId, len + 1);

    // Queue that bad boy
    strcopy(g_sQueuedTankSteamId, sizeof(g_sQueuedTankSteamId), steamId);

    PrintDebug("[Native_SetTank] Set tank to %s.", g_sQueuedTankSteamId);

    return 1;
}

public int Native_GetWhosHadTank(Handle plugin, int numParams) {
    return view_as<int>(CloneHandle(g_hWhosHadTank, plugin));
}

public int Native_ClearWhosHadTank(Handle plugin, int numParams) {
    PrintDebug("[Native_ClearWhosHadTank] Resetting who has had tank on infected.");

    // Create our pool of players to choose from
    ArrayList infectedPool = new ArrayList(MAXSTEAMID);
    AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);

    //Remove infected players from had tank pool
    RemoveSteamIdsFromArray(g_hWhosHadTank, infectedPool);
    RemoveSteamIdsFromArray(g_hWhosHadTankPersistent, infectedPool);

    delete infectedPool;

    return 1;
}

public int Native_GetWhosNotHadTank(Handle plugin, int numParams) {
    ArrayList infectedPool = new ArrayList(MAXSTEAMID);
    AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);

    // Remove players who've already had tank from the pool.
    RemoveSteamIdsFromArray(infectedPool, g_hWhosHadTankPersistent);

    char sSteamId[MAXSTEAMID];
    for (int i = 0; i < GetArraySize(infectedPool); i++) {
        infectedPool.GetString(i, sSteamId, sizeof(sSteamId));
        PrintDebug("[Native_GetWhosNotHadTank] i: %i, steamId: %s", i, sSteamId);
    }

    ArrayList clonedHandle = view_as<ArrayList>(CloneHandle(infectedPool, plugin));
    delete infectedPool;
    return view_as<int>(clonedHandle);
}

public int Native_GetTankPool(Handle plugin, int numParams) {
    ArrayList infectedPool = new ArrayList(MAXSTEAMID);
    AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);

    // Remove players who've already had tank from the pool.
    RemoveSteamIdsFromArray(infectedPool, g_hWhosHadTank);

    // If the infected pool is empty, reset pool of players
    if (infectedPool.Length == 0)
        AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);

    char sSteamId[MAXSTEAMID];
    for (int i = 0; i < GetArraySize(infectedPool); i++) {
        infectedPool.GetString(i, sSteamId, sizeof(sSteamId));
        PrintDebug("[Native_GetTankPool] i: %i, steamId: %s", i, sSteamId);
    }

    ArrayList clonedHandle = view_as<ArrayList>(CloneHandle(infectedPool, plugin));
    delete infectedPool;
    return view_as<int>(clonedHandle);
}

/**
 *  When the tank disconnects, choose another one.
 */
public void OnClientDisconnect(int client)  {
    if (!g_bRoundStarted) return;
    char tmpSteamId[MAXSTEAMID];

    if (client) {
        GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
        if (StrEqual(g_sQueuedTankSteamId, tmpSteamId)) {
            PrintDebug("[OnClientDisconnect] Queued tank disconnected");
            ChooseTank();
            OutputTankToAll();
        }
    }
}

/**
 * When a new game starts, reset the tank pool.
 */
public void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast) {
    g_bRoundStarted = true;
    g_sQueuedTankSteamId[0] = '\0';
    CreateTimer(10.0, newGame, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action newGame(Handle timer) {
    int teamAScore = L4D2Direct_GetVSCampaignScore(0);
    int teamBScore = L4D2Direct_GetVSCampaignScore(1);

    // If it's a new game, reset the tank pool
    if (teamAScore == 0 && teamBScore == 0) {
        PrintDebug("[newGame] Resetting tank control.");
        g_hWhosHadTank.Clear();
        g_hWhosHadTankPersistent.Clear();
        Call_StartForward(g_hTankControlResetForward);
        Call_Finish();
    }

    return Plugin_Stop;
}

/**
 * When the round ends, reset the active tank.
 */
public void RoundEnd_Event(Handle event, const char[] name, bool dontBroadcast) {
    g_bRoundStarted = false;
    g_sQueuedTankSteamId[0] = '\0';
    PrintDebug("[RoundEnd_Event] Cleared queued tank");
}

/**
 * When a player leaves the start area, choose a tank and output to all.
 */
public void PlayerLeftStartArea_Event(Handle event, const char[] name, bool dontBroadcast) {
    // Only choose a tank if nobody has been queued or queued tank is not a valid infected player
    if (!g_sQueuedTankSteamId[0] || GetValidInfectedClientBySteamId(g_sQueuedTankSteamId) == -1) {
        PrintDebug("[PlayerLeftStartArea_Event] No valid infected queued tank");
        ChooseTank();
    }
    OutputTankToAll();
}

/**
 * When the queued tank switches teams, choose a new one
 */
public void PlayerTeam_Event(Handle event, const char[] name, bool dontBroadcast) {
    if (!g_bRoundStarted) return;
    int oldTeam = GetEventInt(event, "oldteam");
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    char tmpSteamId[MAXSTEAMID];

    if (client && oldTeam == TEAM_INFECTED) {
        GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
        if (StrEqual(g_sQueuedTankSteamId, tmpSteamId)) {
            PrintDebug("[PlayerTeam_Event] Queued tank left infected");
            ChooseTank();
            OutputTankToAll();
        }
    }
}

/**
 * When the tank dies, requeue a player to become tank (for finales)
 */
public void PlayerDeath_Event(Handle event, const char[] name, bool dontBroadcast) {
    if (!g_bRoundStarted) return;
    int victimId = GetEventInt(event, "userid");
    int victim = GetClientOfUserId(victimId);

    if (IS_VALID_INGAME(victim) && GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_TANK) {
        PrintDebug("[PlayerDeath_Event] Tank died, choosing a new tank");
        ChooseTank();
    }
}

public void TankKilled_Event(Handle event, const char[] name, bool dontBroadcast) {
    if (!g_bRoundStarted) return;
    PrintDebug("[TankKilled_Event] Tank died, choosing a new tank");
    ChooseTank();
}

public Action Tank_Cmd(int client, int args) {
    if (!IsClientInGame(client)) 
        return Plugin_Handled;

    // Only output if we have a queued tank
    if (!g_sQueuedTankSteamId[0])
        return Plugin_Handled;

    // Only output if infected player or caster
    if (!IS_INFECTED(client) && (!casterSystemAvailable || !IsClientCaster(client)))
        return Plugin_Handled;

    int tankClientId = GetValidInfectedClientBySteamId(g_sQueuedTankSteamId);

    if (tankClientId == client)
        CPrintToChat(client, "{red}<{default}Tank Selection{red}> {green}You {default}will become the {red}Tank{default}!");
    else if (tankClientId != -1)
        CPrintToChat(client, "{red}<{default}Tank Selection{red}> {olive}%N {default}will become the {red}Tank!", tankClientId);

    return Plugin_Handled;
}

public Action TankPool_Cmd(int client, int args) {
    // Create our pool of players to choose from
    ArrayList infectedPool = new ArrayList(MAXSTEAMID);
    AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);

    // Remove players who've already had tank from the pool.
    RemoveSteamIdsFromArray(infectedPool, g_hWhosHadTank);

    // If the infected pool is empty, reset pool of players
    if (infectedPool.Length == 0)
        AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);

    // If there is nobody on the infected team
    if (infectedPool.Length == 0) {
        CPrintToChatAll("{red}<{default}Tank Selection{red}> Nobody on the infected team!");
        delete infectedPool;
        return Plugin_Handled;
    }

    int tankClientId;
    char steamId[MAXSTEAMID];
    char names[MAX_NAME_LENGTH * 4 + 6]; // 4 names, 3 comma+space in between
    names[0] = '\0';

    for (int i = 0; i < infectedPool.Length; i++) {
        infectedPool.GetString(i, steamId, sizeof(steamId));
        tankClientId = GetValidInfectedClientBySteamId(steamId);

        if (tankClientId == -1)
            continue;

        if (!names[0])
            Format(names, sizeof(names), "%N", tankClientId);
        else
            Format(names, sizeof(names), "%s, %N", names, tankClientId);
    }

    CPrintToChatAll("{red}<{default}Tank Selection{red}> Tank pool: %s", names);

    delete infectedPool;
    return Plugin_Handled;
}

public Action TankShuffle_Cmd(int client, int args) {
    PrintDebug("[TankShuffle_Cmd] %N.", client);
    ChooseTank();
    OutputTankToAll();
    return Plugin_Handled;
}

/**
 * Give the tank to a specific player.
 */
public Action GiveTank_Cmd(int client, int args) {
    PrintDebug("[GiveTank_Cmd] %N.", client);

    // Who are we targetting?
    char arg1[MAX_NAME_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    // Try and find a matching player
    int target = FindTarget(client, arg1);
    if (target == -1)
        return Plugin_Handled;

    // Set the tank
    if (IsClientInGame(target) && !IsFakeClient(target)) {
        // Checking if on our desired team
        if (!IS_INFECTED(target)) {
            CPrintToChatAll("{olive}[SM] {default}%N not on infected. Unable to give tank", target);
            return Plugin_Handled;
        }

        char steamId[MAXSTEAMID];
        GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

        g_sQueuedTankSteamId = steamId;
        OutputTankToAll();

        PrintDebug("[GiveTank_Cmd] Tank set. arg1: %s, target: %i %N, steamId: %s", arg1, target, target, steamId);
    }

    return Plugin_Handled;
}

/**
 * Adds specific player to tank pool.
 */
public Action AddTankPool_Cmd(int client, int args) {
    // Who are we targetting?
    char arg1[MAX_NAME_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    // Try and find a matching player
    int target = FindTarget(client, arg1);
    if (target == -1)
        return Plugin_Handled;

    // Set the tank
    if (IsClientInGame(target) && !IsFakeClient(target)) {
        // Checking if on our desired team
        if (!IS_INFECTED(target)) {
            CPrintToChatAll("{olive}[SM] {default}%N not on infected. Unable to add to tank pool", target);
            return Plugin_Handled;
        }

        char steamId[MAXSTEAMID];
        GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

        // Remove player from list of who had tank
        int index = g_hWhosHadTank.FindString(steamId);
        if (index != -1) {
            g_hWhosHadTank.Erase(index);
        }
        index = g_hWhosHadTankPersistent.FindString(steamId);
        if (index != -1) {
            g_hWhosHadTankPersistent.Erase(index);
        }

        CPrintToChatAll("{red}<{default}Tank Selection{red}> {olive}%N {default}added to tank pool!", target);

        PrintDebug("[GiveTank_Cmd] Tank pool added. arg1: %s, target: %i %N, steamId: %s", arg1, target, target, steamId);
    }

    return Plugin_Handled;
}

/**
 * Removes specific player from tank pool.
 */
public Action RemoveTankPool_Cmd(int client, int args) {
    // Who are we targetting?
    char arg1[MAX_NAME_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    // Try and find a matching player
    int target = FindTarget(client, arg1);
    if (target == -1)
        return Plugin_Handled;

    // Set the tank
    if (IsClientInGame(target) && !IsFakeClient(target)) {
        // Checking if on our desired team
        if (!IS_INFECTED(target)) {
            CPrintToChatAll("{olive}[SM] {default}%N not on infected. Unable to remove from tank pool", target);
            return Plugin_Handled;
        }

        char steamId[MAXSTEAMID];
        GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

        // Add player to list of who had tank
        int index = g_hWhosHadTank.FindString(steamId);
        if (index == -1) {
            g_hWhosHadTank.PushString(steamId);
        }
        index = g_hWhosHadTankPersistent.FindString(steamId);
        if (index == -1) {
            g_hWhosHadTankPersistent.PushString(steamId);
        }

        CPrintToChatAll("{red}<{default}Tank Selection{red}> {olive}%N {default}removed from tank pool!", target);

        PrintDebug("[GiveTank_Cmd] Tank pool removed. arg1: %s, target: %i %N, steamId: %s", arg1, target, target, steamId);
    }

    return Plugin_Handled;
}

/**
 * Selects a player on the infected team from random who hasn't been
 * tank and gives it to them.
 */
public void ChooseTank() {
    Action result;
    Call_StartForward(g_hChooseTankForward);
    Call_Finish(result);
    PrintDebug("[ChooseTank] Forward call result: %i", result);
    if (result == Plugin_Handled) {
        PrintDebug("[ChooseTank] Plugin_Handled. queued tank: %s.", g_sQueuedTankSteamId);
        return;
    }

    // Create our pool of players to choose from
    ArrayList infectedPool = new ArrayList(MAXSTEAMID);
    AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);

    // Remove players who've already had tank from the pool.
    RemoveSteamIdsFromArray(infectedPool, g_hWhosHadTank);

    // If the infected pool is empty, reset pool, and remove infected players from had tank pool
    if (infectedPool.Length == 0) {
        PrintDebug("[ChooseTank] Resetting who has had tank on infected.");
        AddTeamSteamIdsToArray(infectedPool, TEAM_INFECTED);
        RemoveSteamIdsFromArray(g_hWhosHadTank, infectedPool); // g_hWhosHadTankPersistent is not reset
    }

    // If no infected players, clear queued tank and return
    if (infectedPool.Length == 0) {
        PrintDebug("[ChooseTank] No infected players. Clearing queued tank.");
        g_sQueuedTankSteamId[0] = '\0';
        delete infectedPool;
        return;
    }

    // Select a random person to become tank
    int maxIndex = infectedPool.Length - 1;
    int rndIndex = Math_GetRandomInt(0, maxIndex);
    infectedPool.GetString(rndIndex, g_sQueuedTankSteamId, sizeof(g_sQueuedTankSteamId));
    delete infectedPool;
    PrintDebug("[ChooseTank] maxIndex: %i, rndIndex: %i, queued tank: %s.", maxIndex, rndIndex, g_sQueuedTankSteamId);

    PrintDebug("[ChooseTank] Calling g_hTankChosenForward forward. g_sQueuedTankSteamId: %s", g_sQueuedTankSteamId);
    Call_StartForward(g_hTankChosenForward);
    Call_PushString(g_sQueuedTankSteamId);
    Call_Finish();
}

/**
 * Make sure we give the tank to our queued player.
 */
public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStatis) {
    // Reset the tank's frustration if need be
    PrintDebug("[L4D_OnTryOfferingTankBot] tank_index: %i %L", tank_index, tank_index);
    if (!IS_VALID_INGAME(tank_index)) {
        PrintDebug("[L4D_OnTryOfferingTankBot] tank_index: %i %L not valid ingame", tank_index, tank_index);
        return Plugin_Continue;
    }

    if (!IsFakeClient(tank_index)) {
        PrintHintText(tank_index, "Rage Meter Refilled");
        for (int i = 1; i <= MaxClients; i++) {
            if (!IS_VALID_INFECTED(i))
                continue;

            if (i == tank_index)
                CPrintToChat(i, "{red}<{default}Tank Rage{red}> {olive}Rage Meter {red}Refilled");
            else
                CPrintToChat(i, "{red}<{default}Tank Rage{red}> {default}({green}%N{default}'s) {olive}Rage Meter {red}Refilled", tank_index);
        }

        SetTankFrustration(tank_index, 100);

        int tankPassCount = L4D2Direct_GetTankPassedCount() + 1;
        PrintDebug("[L4D_OnTryOfferingTankBot] tankPassCount: %i", tankPassCount);
        L4D2Direct_SetTankPassedCount(tankPassCount);

        return Plugin_Handled;
    }

    // If we don't have a queued tank, choose one
    if (!g_sQueuedTankSteamId[0]) {
        PrintDebug("[L4D_OnTryOfferingTankBot] No queued tank. Choosing one...");
        ChooseTank();
    }

    // Mark the player as having had tank
    if (g_sQueuedTankSteamId[0]) {
        SetTankTickets(g_sQueuedTankSteamId, 20000);
        int index = g_hWhosHadTank.FindString(g_sQueuedTankSteamId);
        if (index == -1) {
            g_hWhosHadTank.PushString(g_sQueuedTankSteamId);
        }
        index = g_hWhosHadTankPersistent.FindString(g_sQueuedTankSteamId);
        if (index == -1) {
            g_hWhosHadTankPersistent.PushString(g_sQueuedTankSteamId);
        }
        PrintDebug("[L4D_OnTryOfferingTankBot] Calling g_hTankGivenForward forward. g_sQueuedTankSteamId: %s", g_sQueuedTankSteamId);
        Call_StartForward(g_hTankGivenForward);
        Call_PushString(g_sQueuedTankSteamId);
        Call_Finish();
        g_sQueuedTankSteamId[0] = '\0';
    }

    return Plugin_Continue;
}

/**
 * Sets the amount of tickets for a particular player, essentially giving them tank.
 */
public void SetTankTickets(const char[] steamId, const int tickets) {
    int tankClientId = GetValidInfectedClientBySteamId(steamId);
    PrintDebug("[SetTankTickets] tankClientId: %i", tankClientId);

    for (int i = 1; i <= MaxClients; i++) {
        if (IS_VALID_INFECTED(i) && !IsFakeClient(i)) {
            L4D2Direct_SetTankTickets(i, (i == tankClientId) ? tickets : 0);
            PrintDebug("[SetTankTickets] %L", tankClientId);
        }
    }
}

/**
 * Output who will become tank
 */
public void OutputTankToAll() {
    int tankClientId = GetValidInfectedClientBySteamId(g_sQueuedTankSteamId);

    if (tankClientId == -1)
        return;

    if (g_hCvarTankPrint.BoolValue) {
        CPrintToChatAll("{red}<{default}Tank Selection{red}> {olive}%N {default}will become the {red}Tank!", tankClientId);
    }
    else {
        for (int i = 1; i <= MaxClients; i++) {
            if (IS_VALID_INFECTED(i) || IS_VALID_CASTER(i))
                CPrintToChat(i, "{red}<{default}Tank Selection{red}> {olive}%N {default}will become the {red}Tank!", tankClientId);
        }
    }
}

/**
 * Adds steam ids for a particular team to an array.
 * 
 * @param Handle:steamIds
 *     The array to modify.
 * @param team
 *     The team which to return steam ids for.
 * 
 * @noreturn
 */
public void AddTeamSteamIdsToArray(ArrayList steamIds, int team) {
    char steamId[MAXSTEAMID];

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team) {
            GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
            steamIds.PushString(steamId);
        }
    }
}

/**
 * Removes an array of steam ids from another array.
 * 
 * @param Handle:steamIds
 *     The array of steam ids to modify.
 * @ param Handle:steamIdsToRemove
 *     The steam ids to remove.
 * 
 * @noreturn
 */
public void RemoveSteamIdsFromArray(ArrayList steamIds, ArrayList steamIdsToRemove) {
    int index = -1;
    char steamId[MAXSTEAMID];

    for (int i = 0; i < steamIdsToRemove.Length; i++) {
        steamIdsToRemove.GetString(i, steamId, sizeof(steamId));
        index = steamIds.FindString(steamId);

        if (index != -1)
            steamIds.Erase(index);
    }
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
    if (g_hCvarDebug.BoolValue) {
        char DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
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

void SetTankFrustration(int iTankClient, int iFrustration) {
    if (iFrustration < 0 || iFrustration > 100) {
        return;
    }

    SetEntProp(iTankClient, Prop_Send, "m_frustration", 100-iFrustration);
}
