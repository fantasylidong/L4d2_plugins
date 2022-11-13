#pragma semicolon 1
#define DEBUG 0
#define CVARS_PATH "configs/playermode_cvars.txt"

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <builtinvotes>
#include "includes/hardcoop_util.sp"

#define TEAM_SPECTATORS 1

Handle
	g_hVote = null;

ConVar
	g_hCvarVoteCommandDelay = null,
	g_hCvarVoteTimerDuration = null,
	hCvarMaxSurvivors = null;

int
	g_iPlayerMode = 4;

public Plugin:myinfo = 
{
	name = "Player Mode",
	author = "breezy, A1m`",
	description = "Allows survivors to change the team limit and adapts gameplay cvars to these changes",
	version = "2.1",
	url = ""
};

public OnPluginStart() {
	hCvarMaxSurvivors = CreateConVar( "pm_max_survivors", "8", "Maximum number of survivors allowed in the game" );
	RegConsoleCmd( "sm_playermode", Cmd_PlayerMode, "Change the number of survivors and adapt appropriately" );
	
	decl String:sGameFolder[128];
	GetGameFolderName( sGameFolder, sizeof(sGameFolder) );
	if( !StrEqual(sGameFolder, "left4dead2", false) ) {
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}

	g_hCvarVoteCommandDelay = FindConVar("sv_vote_command_delay");
	g_hCvarVoteTimerDuration = FindConVar("sv_vote_timer_duration");
}

public OnPluginEnd() {
	ResetConVar( FindConVar("survivor_limit") );
	if ( FindConVar("confogl_pills_limit") != INVALID_HANDLE ) 
	{
		ResetConVar(FindConVar("confogl_pills_limit"));	
	}
}

public Action Cmd_PlayerMode(int client, int args)
{
	if (!IsSurvivor(client) && !IsGenericAdmin(client)) {
		ReplyToCommand(client, "[Gauntlet] You do not have access to this command");
		return Plugin_Handled;
	}

	if (args != 1) {
		ReplyToCommand(client, "[Gauntlet] Usage: playermode <value> [ 1 <= value <= %d", GetConVarInt(hCvarMaxSurvivors));
		return Plugin_Handled;
	}

	char sValue[32]; 
	GetCmdArg(1, sValue, sizeof(sValue));
	int iValue = StringToInt(sValue);
	if (iValue < 1 || iValue > GetConVarInt(hCvarMaxSurvivors)) {
		ReplyToCommand(client, "[Gauntlet] Command restricted to values from 1 to %d", GetConVarInt(hCvarMaxSurvivors));
		return Plugin_Handled;
	}

	if (IsBuiltinVoteInProgress()) {
		ReplyToCommand(client, "[Gauntlet] There's a vote in progress.");
		return Plugin_Handled;
	}

	int iVoteDelay = CheckBuiltinVoteDelay();
	if (iVoteDelay > 0) {
		ReplyToCommand(client, "[Gauntlet] Wait for another %ds to call a vote.", iVoteDelay);
		return Plugin_Handled;
	}

	g_iPlayerMode = iValue;

	int iNumPlayers;
	int[] iPlayers = new int[MaxClients];

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= TEAM_SPECTATORS) {
			continue;
		}

		iPlayers[iNumPlayers++] = i;
	}

	char sVoteArgs[64];
	Format(sVoteArgs, sizeof(sVoteArgs), "Change to %d player mode?", iValue);

	g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel|BuiltinVoteAction_VoteEnd|BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_hVote, sVoteArgs);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
	DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, g_hCvarVoteTimerDuration.IntValue);

	FakeClientCommand(client, "Vote Yes");

	return Plugin_Handled;
}

public void VoteActionHandler(Handle hVote, BuiltinVoteAction iAction, int iParam1, int iParam2)
{
	switch (iAction) {
		case BuiltinVoteAction_End: {
			g_iPlayerMode = 4;

			g_hVote = null;
			delete hVote;
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail(hVote, view_as<BuiltinVoteFailReason>(iParam1));
		}
	}
}

public void VoteResultHandler(Handle hVote, int iNumVotes, int iNumClients, const int[][] iClientInfo, int iNumItems, const int[][] iItemInfo)
{
	for (int i = 0; i < iNumItems; i++) {
		if (iItemInfo[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (iItemInfo[i][BUILTINVOTEINFO_ITEM_VOTES] > (iNumClients / 2)) {
				char sMsgVoteSuccess[64];
				Format(sMsgVoteSuccess, sizeof(sMsgVoteSuccess), "Changing to %d playermode!", g_iPlayerMode);
				DisplayBuiltinVotePass(hVote, sMsgVoteSuccess);
				CreateTimer(g_hCvarVoteCommandDelay.FloatValue, Timer_CommandDelay, g_iPlayerMode);

				return;
			}
		}
	}

	DisplayBuiltinVoteFail(hVote, BuiltinVoteFail_Loses);
}

public Action Timer_CommandDelay(Handle hTimer, int iPlayerMode)
{
	SetConVarInt(FindConVar("survivor_limit"), iPlayerMode);

	ConVar hCvarConfoglPillsLimit = FindConVar("confogl_pills_limit");
	if (hCvarConfoglPillsLimit != null) {
		SetConVarInt(hCvarConfoglPillsLimit, iPlayerMode);
	}

	return Plugin_Stop;
}
