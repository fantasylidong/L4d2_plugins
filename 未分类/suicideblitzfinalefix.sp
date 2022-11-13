/*
		Finale Can't Spawn Glitch Fix (C) 2014 Michael Busby
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
		with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

// Offset of the prop we're looking for from m_ghostSpawnState,
// since its relative offset should be more stable than other stuff...
const int OFFS_FROM_SPAWNSTATE = 0x26;
int g_SawSurvivorsOutsideBattlefieldOffset;

public Plugin myinfo =
{
		name = "Finale Can't Spawn Glitch Fix",
		author = "ProdigySim, modified by Wicket and devilesk",
		description = "Fixing Waiting For Survivors To Start The Finale or w/e",
		version = "1.3.0",
		url = "https://github.com/devilesk/rl4d2l-plugins/blob/master/suicideblitzfinalefix.sp"
}
 
public void OnPluginStart()
{
	RegAdminCmd("sm_fix_wff", AdminFixWaitingForFinale, ADMFLAG_GENERIC, "Manually fix the 'Waiting for finale to start' issue for all infected.");
	
	g_SawSurvivorsOutsideBattlefieldOffset = FindSendPropInfo("CTerrorPlayer", "m_ghostSpawnState") + OFFS_FROM_SPAWNSTATE;
	
	HookEvent("round_start", RoundStartEvent);
}

public Action RoundStartEvent(Handle event, const char[] name, bool dontBroadcast)
{
	char mapname[200];
	if (GetCurrentMap(mapname, sizeof(mapname)) > 0)
	{
		if (StrEqual("l4d2_stadium5_stadium", mapname, false)) {
			FixAllInfected();
		}
	}
}

void FixAllInfected()
{
	PrintToChatAll("Fixing Waiting For Finale to Start issue for all infected");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3) 
		{
			SetSeenSurvivorsState(i, true);
			// This part shouldn't be necessary, but just for good measure:
			// Remove the "WAIT_FOR_FINALE" spawn flag
			SetSpawnFlags(i, GetSpawnFlags(i) & ~4);
		}
	}
}


public Action AdminFixWaitingForFinale(int client, int args)
{
	FixAllInfected();
}

// Spawn State - These look like flags, but get used like static values quite often.
// These names were pulled from reversing client.dll--specifically CHudGhostPanel::OnTick()'s uses of the "#L4D_Zombie_UI_*" strings
//
// SPAWN_OK             0
// SPAWN_DISABLED       1  "Spawning has been disabled..." (e.g. director_no_specials 1)
// WAIT_FOR_SAFE_AREA   2  "Waiting for the Survivors to leave the safe area..."
// WAIT_FOR_FINALE      4  "Waiting for the finale to begin..."
// WAIT_FOR_TANK        8  "Waiting for Tank battle conclusion..."
// SURVIVOR_ESCAPED    16  "The Survivors have escaped..."
// DIRECTOR_TIMEOUT    32  "The Director has called a time-out..." (lol wat)
// WAIT_FOR_STAMPEDE   64  "Waiting for the next stampede of Infected..."
// CAN_BE_SEEN        128  "Can't spawn here" "You can be seen by the Survivors"
// TOO_CLOSE          256  "Can't spawn here" "You are too close to the Survivors"
// RESTRICTED_AREA    512  "Can't spawn here" "This is a restricted area"
// INSIDE_ENTITY     1024  "Can't spawn here" "Something is blocking this spot"
stock void SetSpawnFlags(int entity, int flags)
{
	SetEntProp(entity, Prop_Send, "m_ghostSpawnState", flags);
}

stock int GetSpawnFlags(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_ghostSpawnState");
}

stock bool GetSeenSurvivorsState(int entity)
{
	// m_ghostSawSurvivorsOutsideFinaleArea
	return view_as<bool>(GetEntData(entity, g_SawSurvivorsOutsideBattlefieldOffset, 1));
}
stock void SetSeenSurvivorsState(int entity, bool seen)
{
	// m_ghostSawSurvivorsOutsideFinaleArea
	SetEntData(entity, g_SawSurvivorsOutsideBattlefieldOffset, seen ? 1: 0, 1);
}