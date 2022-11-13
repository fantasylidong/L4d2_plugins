#pragma semicolon 1
#define AS_DEBUG 0
#define GRACETIME 5.0
#define TEAM_SURVIVOR 2
#include <sourcemod>
#include <sdktools>
#include<left4downtown>

// This plugin was created because of a Hard12 bug where one ore more survivors were not taking damage while pinned
// by special infected. If the whole team is immobilised, they get a grace period before they are AutoWiped.
public Plugin:myinfo = {
	name = "AutoWipe",
	author = "Breezy",
	description = "Wipes the team if they are simultaneously incapped/pinned for a period of time",
	version = "1.0"
};

new bool:g_bCanAllowNewAutowipe = false; // start true to prevent autowipe being activated at round start

public OnPluginStart() {
	// Disabling autowipe
	HookEvent("finale_vehicle_incoming", EventHook:FinaleEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", EventHook:FinaleEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", EventHook:FinaleEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:DisableAutoWipe, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", EventHook:DisableAutoWipe, EventHookMode_PostNoCopy);		
	HookEvent("player_incapacitated_start", Incap_Event);
}
public Incap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new Incap = GetClientOfUserId(GetEventInt(event, "userid"));
    ForcePlayerSuicide(Incap);
}
public FinaleEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetConVarString(FindConVar("mp_gamemode"), "versus");
}
public OnMapStart()
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
}
//stock IsPlayerIncap(client) return GetEntProp(client, Prop_Send, "m_isIncapacitated");
public DisableAutoWipe() 
{
	g_bCanAllowNewAutowipe = false; // prevents autowipe from being called until next map
}
public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
	g_bCanAllowNewAutowipe = true;
}
public OnGameFrame() {
	// activate AutoWipe if necessary
	if (g_bCanAllowNewAutowipe) {
		if (IsTeamImmobilised()) {
			SetConVarString(FindConVar("mp_gamemode"), "coop");
			//PrintToChatAll("[AW] Initiating an AutoWipe...");
			g_bCanAllowNewAutowipe = false;
		}
	} 
}

bool:IsTeamImmobilised() {
	//Check if there is still an upright survivor
	new bool:bIsTeamImmobilised = true;
	for (new client = 1; client < MaxClients; client++) {
		// If a survivor is found to be alive and neither pinned nor incapacitated
		// team is not immobilised.
		if (IsSurvivor(client) && IsPlayerAlive(client)) {	
				bIsTeamImmobilised = false;				
						#if AS_DEBUG
							decl String:ClientName[32];
							GetClientName(client, ClientName, sizeof(ClientName));
							LogMessage("IsTeamImmobilised() -> %s is mobile, team not immobilised: \x05", ClientName);
						#endif
				break;
			} 
	}
	return bIsTeamImmobilised;
}

bool:IsSurvivor(client) {
	return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool:IsValidClient(client) { 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
} 