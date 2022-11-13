#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>

#define TEAM_SPECTATOR          1

enum VoteType
{
    VoteType_GoTo,
    VoteType_Bring
}

Handle hVote = INVALID_HANDLE;
VoteType g_VoteType;
int g_SourceClient = -1;
char g_Name[32];
float g_fTeleportDestination[3];

public Plugin myinfo =
{
    name = "Teleport Player",
    author = "devilesk",
    description = "Adds sm_goto and sm_bring to teleport players.",
    version = "0.1.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_goto", Command_GoTo, "Go to a player.");
    RegConsoleCmd("sm_bring", Command_Bring," Teleport a player to the point you are looking at.");
}

public Action Command_GoTo(int client, int args)
{
    if(args < 1)
    {
        PrintToConsole(client, "Usage: sm_goto <name>");
        PrintToChat(client, "Usage:\x04 sm_goto <name>");
        return Plugin_Handled;
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

    GetClientName(target, g_Name, sizeof(g_Name));

    bool bIsAdmin = CheckCommandAccess(client, "sm_goto", ADMFLAG_KICK, true);
    
    if (!bIsAdmin) {
        if (IsSpectator(client)) {
            PrintToChat(client, "\x01[\x04Teleport Player\x01] Vote can only be started by a player!");
            return Plugin_Handled;
        }
        else if (!IsNewBuiltinVoteAllowed()) {
            PrintToChat(client, "\x01[\x04Teleport Player\x01] Vote cannot be started now.");
            return Plugin_Handled;
        }
    }
    else {
        if (IsBuiltinVoteInProgress()) {
            PrintToChat(client, "\x01[\x04Teleport Player\x01] There is a vote in progress.");
            return Plugin_Handled;
        }
    }

    g_SourceClient = client;

    float fTargetOrigin[3];
    GetClientAbsOrigin(target, fTargetOrigin);

    g_fTeleportDestination[0] = fTargetOrigin[0];
    g_fTeleportDestination[1] = fTargetOrigin[1];
    g_fTeleportDestination[2] = (fTargetOrigin[2] + 73);

    if (bIsAdmin) {
        DoTeleport();
    }
    else {
        char prompt[100];
        Format(prompt, sizeof(prompt), "Allow %N to go to %s?", client, g_Name);
        StartVote(client, prompt, VoteType_GoTo);
        FakeClientCommand(client, "Vote Yes");
    }

    return Plugin_Handled;
}

public Action Command_Bring(int client, int args)
{
    if(args < 1)
    {
        PrintToConsole(client, "Usage: sm_bring <name>");
        PrintToChat(client, "Usage:\x04 sm_bring <name>");
        return Plugin_Handled;
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

    GetClientName(target, g_Name, sizeof(g_Name));

    bool bIsAdmin = CheckCommandAccess(client, "sm_goto", ADMFLAG_KICK, true);
    
    if (!bIsAdmin) {
        if (IsSpectator(client)) {
            PrintToChat(client, "\x01[\x04Teleport Player\x01] Vote can only be started by a player!");
            return Plugin_Handled;
        }
        else if (!IsNewBuiltinVoteAllowed()) {
            PrintToChat(client, "\x01[\x04Teleport Player\x01] Vote cannot be started now.");
            return Plugin_Handled;
        }
    }
    else {
        if (IsBuiltinVoteInProgress()) {
            PrintToChat(client, "\x01[\x04Teleport Player\x01] There is a vote in progress.");
            return Plugin_Handled;
        }
    }

    g_SourceClient = target;

    float fTargetOrigin[3];
    GetCollisionPoint(client, fTargetOrigin);

    g_fTeleportDestination[0] = fTargetOrigin[0];
    g_fTeleportDestination[1] = fTargetOrigin[1];
    g_fTeleportDestination[2] = (fTargetOrigin[2] + 4);

    if (bIsAdmin) {
        DoTeleport();
    }
    else {
        char prompt[100];
        Format(prompt, sizeof(prompt), "Allow %s to go to %N?", g_Name, client);
        StartVote(client, prompt, VoteType_Bring);
        FakeClientCommand(client, "Vote Yes");
    }

    return Plugin_Handled;
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
                DisplayBuiltinVotePass(vote, "Teleporting player...");
                PrintToChatAll("\x01[\x04Teleport Player\x01] Vote passed! Teleporting player...");
                PrintDebug("[VoteResultHandler] Vote passed! Teleporting player...");
                if (g_VoteType == VoteType_GoTo)
                    DoTeleport();
                else if (g_VoteType == VoteType_Bring)
                    DoTeleport();
                return;
            }
        }
    }
    DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

void DoTeleport() {
    PrintDebug("[DoTeleport] Teleporting %N to %f %f %f", g_SourceClient, g_fTeleportDestination[0], g_fTeleportDestination[1], g_fTeleportDestination[2]);
    TeleportEntity(g_SourceClient, g_fTeleportDestination, NULL_VECTOR, NULL_VECTOR);
}

bool IsSpectator(int client) {
    return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SPECTATOR;
}

// Trace

stock void GetCollisionPoint(int client, float pos[3])
{
    float vOrigin[3];
    float vAngles[3];
    
    GetClientEyePosition(client, vOrigin);
    GetClientEyeAngles(client, vAngles);
    
    Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
    
    if(TR_DidHit(trace))
    {
        TR_GetEndPosition(pos, trace);
        delete trace;
        
        return;
    }
    
    delete trace;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
    return entity > MaxClients;
}

stock void PrintDebug(const char[] Message, any ...) {
    char DebugBuff[256];
    VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
    LogMessage(DebugBuff);
}