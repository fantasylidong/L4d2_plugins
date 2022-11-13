/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
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
	with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <l4d2util_constants>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "1v1 instand stand up",
	author = "东",
	description = "A plugin designed to support 1vAI.",
	version = "1.0",
	url = "https://github.com/fantasylidong/CompetitiveWithAnne"
};

public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
}
public void Event_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{

	
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if (!IsClientAndInGame(iAttacker) || GetClientTeam(iAttacker) != L4D2Team_Infected) {
		return;
	}
	
	int iZclass = GetEntProp(iAttacker, Prop_Send, "m_zombieClass");
	
	if (iZclass < L4D2Infected_Smoker || iZclass > L4D2Infected_Charger) {
		return;
	}
	
	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!IsClientAndInGame(iVictim) || GetClientTeam(iVictim) != L4D2Team_Survivor) {
		return;
	}
	
	SDKHook(iVictim, SDKHook_PostThinkPost, CancelGetup);
}

public Action CancelGetup(int client)
{
	if (IsClientAndInGame(client))
	{
		SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0, 0);
	}
	return Plugin_Continue;
}

stock bool IsClientAndInGame(int iClient)
{
	return (iClient > 0 && IsClientInGame(iClient));
}
