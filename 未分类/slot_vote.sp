/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.	 All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.	If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <sourcemod>
#include <builtinvotes>
#include <colors>
#undef REQUIRE_PLUGIN
#tryinclude <pause>

static Handle:g_hCVarMinAllowedSlots;
static Handle:g_hCVarMaxAllowedSlots;

static Handle:g_hCVarVoteDuration;
static Handle:g_hCVarVoteCommandDelay;

static Handle:g_hCVarMaxPlayersDowntown;
static Handle:g_hCVarMaxPlayersToolZ;

static Handle:g_hSlotVote;
static Handle:g_hNoSpecVote;
static g_iNoSpecVoteInitiator;

static g_iVoteDuration;
static Float:g_fVoteCommandDelay;

static bool:g_bLeft4Downtown2;
static bool:g_bL4DToolz;

static g_iMinAllowedSlots;
static g_iMaxAllowedSlots;

static g_iCurrentSlots;
static g_iDesiredSlots;

#if defined _pause_included_
static bool:g_bPause_Lib;
#endif
static Handle:g_cvarSlotsPluginEnabled = INVALID_HANDLE;
static Handle:g_cvarSlotsAutoconf	= INVALID_HANDLE;
static Handle:g_cvarSvVisibleMaxPlayers = INVALID_HANDLE;
static Handle:g_cvarCurrentMaxSlots = INVALID_HANDLE;
new bool:g_bSlotsLocked = false;

public Plugin:myinfo =
{
	name = "L4D2 Slot Vote",
	author = "X-Blaze",
	description = "Allow players to change server slots by using vote.",
	version = "2.2-ds-1.2"
};

public OnPluginStart()
{
	LoadTranslations("slotvote.phrases");
	g_cvarSlotsPluginEnabled = CreateConVar("sm_slot_vote_enabled", "1", "Enabled?", 0);
	g_cvarSlotsAutoconf = CreateConVar("sm_slot_autoconf", "1", "Autoconfigure slots vote max|min cvars?", 0);
	g_hCVarMinAllowedSlots = CreateConVar("sm_slot_vote_min", "1", "Minimum allowed number of server slots (this value must be equal or lesser than sm_slot_vote_max).", 0, true, 1.0, true, 32.0);
	g_hCVarMaxAllowedSlots = CreateConVar("sm_slot_vote_max", "12", "Maximum allowed number of server slots (this value must be equal or greater than sm_slot_vote_min).", 0, true, 1.0, true, 32.0);
	g_cvarCurrentMaxSlots = CreateConVar("sv_maxslots", "30", "Maximum server slots.", 0);
	
	g_hCVarVoteDuration = FindConVar("sv_vote_timer_duration");
	g_hCVarVoteCommandDelay = FindConVar("sv_vote_command_delay");

	g_hCVarMaxPlayersDowntown = FindConVar("l4d_maxplayers");
	g_hCVarMaxPlayersToolZ = FindConVar("sv_maxplayers");
	g_cvarSvVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");
	g_iMinAllowedSlots = GetConVarInt(g_hCVarMinAllowedSlots);
	g_iMaxAllowedSlots = GetConVarInt(g_hCVarMaxAllowedSlots);

	g_iVoteDuration = GetConVarInt(g_hCVarVoteDuration);
	g_fVoteCommandDelay = GetConVarFloat(g_hCVarVoteCommandDelay);
	SetConVarInt(g_cvarCurrentMaxSlots, GetConVarInt(g_hCVarMaxPlayersToolZ));
	//PrintToServer("Slots set onload to: %d", GetConVarInt(g_hCVarMaxPlayersToolZ));
	HookConVarChange(g_hCVarMinAllowedSlots, CVarChangeMinAllowedSlots);
	HookConVarChange(g_hCVarMaxAllowedSlots, CVarChangeMaxAllowedSlots);

	HookConVarChange(g_hCVarVoteDuration, CVarChangeVoteDuration);
	HookConVarChange(g_hCVarVoteCommandDelay, CVarChangeVoteCommandDelay);
	HookConVarChange(g_cvarCurrentMaxSlots, CurrentMaxSlots_Changed);
	HookConVarChange(g_cvarSvVisibleMaxPlayers, SvVisibleMaxPlayers_Changed);

	if (g_hCVarMaxPlayersDowntown != INVALID_HANDLE)
	{
		g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersDowntown);
		HookConVarChange(g_hCVarMaxPlayersDowntown, CVarChangeMaxPlayers);
		g_bLeft4Downtown2 = true;
	}

	if (g_hCVarMaxPlayersToolZ != INVALID_HANDLE)
	{
		g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersToolZ);
		HookConVarChange(g_hCVarMaxPlayersToolZ, CVarChangeMaxPlayers);
		g_bL4DToolz = true;
	}

	if (g_bLeft4Downtown2 && g_bL4DToolz)
	{
		SetFailState("Please do not use Left4Downtown2 playerslots build with L4DToolz. Slot Vote disabled.");
	}
	else if (!g_bLeft4Downtown2 && !g_bL4DToolz)
	{
		SetFailState("Supported slot patching mods not detected. Slot Vote disabled.");
	}

	if (g_iCurrentSlots == -1)
	{
		g_iCurrentSlots = 8;
	}
	if (GetConVarBool(g_cvarSlotsAutoconf)) {
		new Handle:hSurvivorLimit = FindConVar("survivor_limit");
		SetConVarInt(g_hCVarMinAllowedSlots, GetConVarInt(hSurvivorLimit) * 2);
		PrintToServer("Min slots automatically configured to %d", GetConVarInt(hSurvivorLimit) * 2);
		CloseHandle(hSurvivorLimit);
	}

	RegConsoleCmd("sm_slots", Cmd_SlotVote);
	RegConsoleCmd("sm_maxslots", Cmd_SlotVote);
	RegConsoleCmd("sm_limitslots", Cmd_SlotVote);

	RegConsoleCmd("sm_nospec", Cmd_NoSpec);
	RegConsoleCmd("sm_nospecs", Cmd_NoSpec);
	RegConsoleCmd("sm_kickspec", Cmd_NoSpec);
	RegConsoleCmd("sm_kickspecs", Cmd_NoSpec);

	RegAdminCmd("sm_forcekickspecs", Cmd_ForceNoSpec, ADMFLAG_KICK);
	RegAdminCmd("sm_lockslots", Cmd_LockSlots, ADMFLAG_CONVARS | ADMFLAG_CONFIG | ADMFLAG_PASSWORD | ADMFLAG_RCON | ADMFLAG_CHEATS | ADMFLAG_ROOT);
	RegAdminCmd("sm_unlockslots", Cmd_UnLockSlots, ADMFLAG_CONVARS | ADMFLAG_CONFIG | ADMFLAG_PASSWORD | ADMFLAG_RCON | ADMFLAG_CHEATS | ADMFLAG_ROOT);
}

public Action:Cmd_ForceNoSpec(int client, int args) {
	KickAllSpectators(client);
	return Plugin_Handled;
}

public Action:Cmd_LockSlots(int client, int args) {	
	g_bSlotsLocked = true;
	PrintToServer("Server slots count locked!");
	PrintToChatAll("Server slots count locked!");
	return Plugin_Handled;
}

public Action:Cmd_UnLockSlots(int client, int args) {
	g_bSlotsLocked = false;
	PrintToServer("[SM] Server slots count unlocked!");
	PrintToChatAll("[SM] Server slots count unlocked!");
	return Plugin_Handled;
}

#if defined _pause_included_
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "pause"))
	{
		g_bPause_Lib = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "pause"))
	{
		g_bPause_Lib = false;
	}
}
#endif

public OnAllPluginsLoaded()
{
#if defined _pause_included_
	if (LibraryExists("pause"))
	{
		g_bPause_Lib = true;
	}
#endif
}

public CVarChangeMinAllowedSlots(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	if (!GetConVarBool(g_cvarSlotsPluginEnabled)) return;
	g_iMinAllowedSlots = StringToInt(sNewValue);

	if (g_iMinAllowedSlots > g_iMaxAllowedSlots)
	{
		g_iMinAllowedSlots = g_iMaxAllowedSlots;
	}
}

public CVarChangeMaxAllowedSlots(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	if (!GetConVarBool(g_cvarSlotsPluginEnabled)) return;
	g_iMaxAllowedSlots = StringToInt(sNewValue);

	if (g_iMaxAllowedSlots < g_iMinAllowedSlots)
	{
		g_iMaxAllowedSlots = g_iMinAllowedSlots;
	}
}
public CurrentMaxSlots_Changed(Handle:cvar, const String:oldValue[], const String:newValue[]) {
	SetConVarInt(g_hCVarMaxPlayersToolZ, GetConVarInt(g_cvarCurrentMaxSlots));
	SetConVarInt(g_cvarSvVisibleMaxPlayers, GetConVarInt(g_cvarCurrentMaxSlots));
}

public Action:ChangeTrueSlots_Timed(Handle:timer) {
	SetConVarInt(g_hCVarMaxPlayersToolZ, GetConVarInt(g_cvarCurrentMaxSlots));
	SetConVarInt(g_cvarSvVisibleMaxPlayers, GetConVarInt(g_cvarCurrentMaxSlots));
	return Plugin_Stop;
}

public CVarChangeVoteDuration(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	g_iVoteDuration = StringToInt(sNewValue);
}

public CVarChangeVoteCommandDelay(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	g_fVoteCommandDelay = StringToFloat(sNewValue);
}

public CVarChangeMaxPlayers(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	if (!GetConVarBool(g_cvarSlotsPluginEnabled)) return;
	SetConVarInt(hCVar, GetConVarInt(g_cvarCurrentMaxSlots));
	SetConVarInt(g_cvarSvVisibleMaxPlayers, GetConVarInt(g_cvarCurrentMaxSlots));
}

public SvVisibleMaxPlayers_Changed(Handle:cvar, const String:oldValue[], const String:newValue[]) {
	if (!GetConVarBool(g_cvarSlotsPluginEnabled)) return;
	SetConVarInt(g_hCVarMaxPlayersToolZ, GetConVarInt(g_cvarCurrentMaxSlots));
	SetConVarInt(g_cvarSvVisibleMaxPlayers, GetConVarInt(g_cvarCurrentMaxSlots));
}

public Action:Cmd_SlotVote(iClient, iArgs)
{
	if (g_bSlotsLocked) {
		PrintToChat(iClient, "[SM] You can not change slots count. It's locked by config or admin.");
		return Plugin_Handled;
	}
	if (!GetConVarBool(g_cvarSlotsPluginEnabled)) return Plugin_Handled;
#if defined _pause_included_
	if (g_bPause_Lib && IsInPause())
	{
		return Plugin_Handled;
	}
#endif
	if (iClient < 1) return Plugin_Handled;
	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%t", "Spectator response");
		return Plugin_Handled;
	}

	if (IsNewBuiltinVoteAllowed())
	{
		if (iArgs == 1)
		{
			decl String:sArgs[4];
			GetCmdArg(1, sArgs, sizeof(sArgs));

			g_iDesiredSlots = StringToInt(sArgs);

			if (g_iDesiredSlots == g_iCurrentSlots)
			{
				CPrintToChat(iClient, "%t", "Same as current", g_iDesiredSlots);
				return Plugin_Handled;
			}

			if (g_iDesiredSlots >= g_iMinAllowedSlots && g_iDesiredSlots <= g_iMaxAllowedSlots)
			{
				CreateTimer(0.1, Timer_StartSlotVote, iClient, TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				CPrintToChat(iClient, "%t", "Usage", g_iMinAllowedSlots, g_iMaxAllowedSlots);
			}

			return Plugin_Handled;
		}

		CreateTimer(0.1, Timer_CreateSlotMenu, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		PrintToChat(iClient, "%t", "Vote denied");
	}

	return Plugin_Handled;
}

public Action:Timer_StartSlotVote(Handle:hTimer, any:iClient)
{
	if (IsClientInGame(iClient) && GetClientTeam(iClient) > 1)
	{
		StartSlotVote(iClient);
	}
}

public Action:Timer_CreateSlotMenu(Handle:hTimer, any:iClient)
{
	if (IsClientInGame(iClient) && GetClientTeam(iClient) > 1)
	{
		CreateSlotMenu(iClient);
	}
}

public Action:Cmd_NoSpec(iClient, iArgs)
{
	if (g_bSlotsLocked) {
		PrintToChat(iClient, "[SM] You can not kick specs. It's locked by config or admin.");
		return Plugin_Handled;
	}
	if (!GetConVarBool(g_cvarSlotsPluginEnabled)) return Plugin_Handled;
#if defined _pause_included_
	if (g_bPause_Lib && IsInPause())
	{
		return Plugin_Handled;
	}
#endif

	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%t", "Spectator response");
		return Plugin_Handled;
	}

	new iSpecs = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)
		&&	!IsFakeClient(i)
		&&	GetClientTeam(i) == 1)
		{
			iSpecs++;
		}
	}

	if (iSpecs != 0)
	{
		CreateTimer(0.1, Timer_StartNoSpecVote, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		PrintToChat(iClient, "%t", "No spectators");
	}

	return Plugin_Handled;
}

public Action:Timer_StartNoSpecVote(Handle:hTimer, any:iClient)
{
	if (IsClientInGame(iClient) && GetClientTeam(iClient) > 1)
	{
		StartNoSpecVote(iClient);
	}
}

static CreateSlotMenu(iClient)
{
	new Handle:hSlotMenu = CreateMenu(MenuHandler_SlotMenu);

	decl String:sBuffer[256], String:sCycle[4];

	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slot vote title", iClient, g_iCurrentSlots);
	SetMenuTitle(hSlotMenu, sBuffer);

	for (new i = g_iMinAllowedSlots; i <= g_iMaxAllowedSlots; i++)
	{
		FormatEx(sCycle, sizeof(sCycle), "%i", i);
		FormatEx(sBuffer, sizeof(sBuffer), "%i %T", i, "Slots", iClient);
		AddMenuItem(hSlotMenu, sCycle, sBuffer);
	}

	SetMenuExitButton(hSlotMenu, true);
	DisplayMenu(hSlotMenu, iClient, 30);
}

public MenuHandler_SlotMenu(Handle:hSlotMenu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[3];

		if (GetMenuItem(hSlotMenu, param2, sInfo, sizeof(sInfo)))
		{
			g_iDesiredSlots = StringToInt(sInfo);

			if (g_iDesiredSlots == g_iCurrentSlots)
			{
				CPrintToChat(param1, "%t", "Same as current", g_iDesiredSlots);
				return;
			}

			StartSlotVote(param1);
		}
	}

	if (action == MenuAction_End)
	{
		CloseHandle(hSlotMenu);
	}
}

static StartSlotVote(iClient)
{
	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%t", "Spectator response");
		return;
	}

	if (IsNewBuiltinVoteAllowed())
	{
		new iPlayers[MaxClients], iNumPlayers;

		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)
			||	IsFakeClient(i)
			||	(GetClientTeam(i) == 1))
			{
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		g_hSlotVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

		decl String:sBuffer[64];
		FormatEx(sBuffer, sizeof(sBuffer), "Change server slots to %i?", g_iDesiredSlots);
		SetBuiltinVoteArgument(g_hSlotVote, sBuffer);
		SetBuiltinVoteInitiator(g_hSlotVote, iClient);
		SetBuiltinVoteResultCallback(g_hSlotVote, SlotVoteResultHandler);
		DisplayBuiltinVote(g_hSlotVote, iPlayers, iNumPlayers, g_iVoteDuration);

		FakeClientCommand(iClient, "Vote Yes");
		return;
	}

	PrintToChat(iClient, "%t", "Vote denied");
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hSlotVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public SlotVoteResultHandler(Handle:vote,num_votes, num_clients, const client_info[][], num_items, const item_info[][])
{
	for (new i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				decl String:sBuffer[64];
				FormatEx(sBuffer, sizeof(sBuffer), "Server slots changed to %i", g_iDesiredSlots);
				DisplayBuiltinVotePass(vote, sBuffer);

				CreateTimer(g_fVoteCommandDelay, TimerChangeMaxPlayers, _, TIMER_FLAG_NO_MAPCHANGE);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action:TimerChangeMaxPlayers(Handle:timer)
{
	if (g_bLeft4Downtown2)
	{
		SetConVarInt(g_hCVarMaxPlayersDowntown, g_iDesiredSlots);
	}
	else if (g_bL4DToolz)
	{
		SetConVarInt(g_cvarCurrentMaxSlots, g_iDesiredSlots);	
	}

	return Plugin_Stop;
}

static StartNoSpecVote(client)
{
	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "%t", "Spectator response");
		return;
	}

	if (IsNewBuiltinVoteAllowed())
	{
		new iNumPlayers, iPlayers[MaxClients];

		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)
			||	IsFakeClient(i)
			||	(GetClientTeam(i) == 1))
			{
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}

		g_hNoSpecVote = CreateBuiltinVote(NoSpecVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		g_iNoSpecVoteInitiator = client;

		decl String:sBuffer[64];
		FormatEx(sBuffer, sizeof(sBuffer), "Do you want to kick spectators?");
		SetBuiltinVoteArgument(g_hNoSpecVote, sBuffer);
		SetBuiltinVoteInitiator(g_hNoSpecVote, client);
		SetBuiltinVoteResultCallback(g_hNoSpecVote, NoSpecVoteResultHandler);
		DisplayBuiltinVote(g_hNoSpecVote, iPlayers, iNumPlayers, g_iVoteDuration);

		FakeClientCommand(client, "Vote Yes");
		return;
	}

	PrintToChat(client, "%t", "Vote denied");
}

public NoSpecVoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hNoSpecVote = INVALID_HANDLE;
			g_iNoSpecVoteInitiator = 0;
			CloseHandle(vote);
		}

		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public NoSpecVoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][], num_items, const item_info[][])
{
	for (new i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				decl String:sBuffer[64];
				FormatEx(sBuffer, sizeof(sBuffer), "Kicking spectators...");
				DisplayBuiltinVotePass(vote, sBuffer);

				CreateTimer(g_fVoteCommandDelay, TimerKickAllSpectators, _, TIMER_FLAG_NO_MAPCHANGE);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action:TimerKickAllSpectators(Handle:hTimer)
{
	KickAllSpectatorsByVote();
	return Plugin_Stop;
}

static void KickAllSpectatorsByVote()
{
	KickAllSpectators(g_iNoSpecVoteInitiator);
}

static void KickAllSpectators(int client)
{
	int numSpecs;
	decl String:reason[255];
	Format(reason, sizeof(reason), "%t", "Spectator kick reason");

	AdminId callerid = INVALID_ADMIN_ID;
	AdminId targetid = INVALID_ADMIN_ID;

	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		callerid = GetUserAdmin(client);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 1 && i != client)
		{
			targetid = GetUserAdmin(i);

			// Enforce admin immunity.
			if (targetid == INVALID_ADMIN_ID || (callerid != INVALID_ADMIN_ID && CanAdminTarget(callerid, targetid))) {
				BanClient(i, 5, BANFLAG_AUTHID, reason, reason, "nospec");
				numSpecs++;
			}
		}
	}

	if (numSpecs)
	{
		PrintToChatAll("%t", "All spectators kicked");
	}
}

stock GetHumanCount()
{
	new iHumanCount = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			iHumanCount++;
		}
	}

	return iHumanCount;
}