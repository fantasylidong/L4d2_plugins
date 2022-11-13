#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS		FCVAR_NOTIFY

#define PLUGIN_VERSION "1.0"
ConVar 	g_hCvarEnable;
ConVar 	g_hCvarStuckInterval;
ConVar 	g_hCvarNonStuckRadius;
ConVar 	g_hCvarStuckFailsafe;
ConVar 	g_hCvarTankClawRangeDown;
ConVar 	g_hCvarTankClawRange;
ConVar  g_hCvarRusherPunish;
ConVar  g_hCvarRusherDist;
ConVar  g_hCvarRusherCheckTimes;
ConVar  g_hCvarRusherCheckInterv;
ConVar  g_hCvarRusherMinPlayers;

Handle 	g_hTimerIdler = INVALID_HANDLE;
Handle 	g_hTimerRusher = INVALID_HANDLE;

float 	g_pos[MAXPLAYERS+1][3];
float	g_fTankClawRange;

bool 	g_bLeft4Dead2;
bool 	g_bAngry[MAXPLAYERS+1];
bool 	g_bMapStarted = true;
bool 	g_bLateload;
bool	g_bAtLeastOneTankAngry;

int 	g_bEnabled;
int 	g_iTimes[MAXPLAYERS+1];
int 	g_iStuckTimes[MAXPLAYERS+1];
int 	g_iRushTimes[MAXPLAYERS+1];
int		g_iTanksCount;
public Plugin myinfo = 
{
	name = "Anne Stuck Tank Teleport System",
	author = "东",
	description = "当tank卡住时传送tank到靠近玩家但是玩家看不到的地方，有求生跑男时会传送到跑男位置",
	version = PLUGIN_VERSION,
	url = "https://github.com/fantasylidong/anne"
}
//游戏引擎检查
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test == Engine_Left4Dead2) {
		g_bLeft4Dead2 = true;		
	}
	else if (test != Engine_Left4Dead) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateload = late;
	return APLRes_Success;
}
public void OnPluginStart()
{
	CreateConVar(							"l4d2_Anne_stuck_tank_teleport",				PLUGIN_VERSION,	"Plugin version", FCVAR_DONTRECORD );
	g_hCvarEnable = CreateConVar(			"l4d2_Anne_stuck_tank_teleport_enable",					"1",		"Enable plugin (1 - On / 0 - Off)", CVAR_FLAGS );	
	g_hCvarStuckInterval = CreateConVar(	"l4d2_Anne_stuck_tank_teleport_check_interval",			"3",		"Time intervals (in sec.) tank stuck should be checked", CVAR_FLAGS );
	g_hCvarNonStuckRadius = CreateConVar(	"l4d2_Anne_stuck_tank_teleport_non_stuck_radius",		"20",		"Maximum radius where tank is cosidered non-stucked when not moved during X sec. (see l4d_TankAntiStuck_check_interval ConVar)", CVAR_FLAGS );
	g_hCvarRusherPunish = CreateConVar(		"l4d2_Anne_stuck_tank_teleport_rusher_punish",			"1",		"Punish the player who rush too far from the nearest tank by teleporting tank to him? (0 - No / 1 - Yes)", CVAR_FLAGS );
	g_hCvarRusherDist = CreateConVar(		"l4d2_Anne_stuck_tank_teleport_rusher_dist",			"2000",		"Maximum distance to the nearest tank considered as rusher", CVAR_FLAGS );
	g_hCvarRusherCheckTimes = CreateConVar(	"l4d2_Anne_stuck_tank_teleport_rusher_check_times",		"4",		"Number of checks before finally considering player as rusher", CVAR_FLAGS );
	g_hCvarRusherCheckInterv = CreateConVar("l4d2_Anne_stuck_tank_teleport_rusher_check_interval",	"10",		"Interval (in sec.) between each check for rusher", CVAR_FLAGS );	
	g_hCvarRusherMinPlayers = CreateConVar(	"l4d_TankAntiStuck_rusher_minplayers",		"2",		"Minimum living players allowed for 'Rusher player' rule to work", CVAR_FLAGS );
	
	//AutoExecConfig(true,			"l4d2_Anne_stuck_tank_teleport");
	
	g_hCvarStuckFailsafe = FindConVar("tank_stuck_failsafe");
	g_hCvarTankClawRange = FindConVar("claw_range");
	g_hCvarTankClawRangeDown = FindConVar("claw_range_down");
	
	HookConVarChange(g_hCvarEnable,				ConVarChanged);
	HookConVarChange(g_hCvarRusherPunish,		ConVarChanged);
	
	GetCvars();
	
	if (g_bLateload && g_bEnabled) {
		for (int i = 1; i <= MaxClients; i++) {
			if (i != 0 && IsClientInGame(i)) {
				if (IsTank(i))
					BeginTankTracing(i);
			}
		}
	}
}
void BeginTankTracing(int client)
{
	g_iStuckTimes[client] = 0;
	GetClientAbsOrigin(client, g_pos[client]);

	// wait until somebody make tank angry to begin check for stuck
	CreateTimer(2.0, Timer_CheckAngry, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}
public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnabled = g_hCvarEnable.BoolValue;	
	if (g_hTimerIdler != INVALID_HANDLE) {
			CloseHandle (g_hTimerIdler);
			g_hTimerIdler = INVALID_HANDLE;
		}
	if (g_hTimerRusher != INVALID_HANDLE) {
		CloseHandle (g_hTimerRusher);
		g_hTimerRusher = INVALID_HANDLE;
		}
	
	InitHook();
}

void InitHook()
{
	static bool bHooked;
	
	if (g_bEnabled) {
		if (!bHooked) {
			HookEvent("tank_spawn",       		Event_TankSpawn,  	EventHookMode_Post);
			HookEvent("player_death",   		Event_PlayerDeath,	EventHookMode_Pre);
			HookEvent("round_start", 			Event_RoundStart,	EventHookMode_PostNoCopy);
			HookEvent("round_end", 				Event_RoundEnd,		EventHookMode_PostNoCopy);
			HookEvent("finale_win", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
			HookEvent("mission_lost", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
			HookEvent("map_transition", 		Event_RoundEnd,		EventHookMode_PostNoCopy);
			HookEvent("player_disconnect", 		Event_PlayerDisconnect, EventHookMode_Pre);
			bHooked = true;
		}
	} else {
		if (bHooked) {
			UnhookEvent("tank_spawn",       	Event_TankSpawn,  	EventHookMode_Post);
			UnhookEvent("player_death",   		Event_PlayerDeath,	EventHookMode_Pre);
			UnhookEvent("round_start", 			Event_RoundStart,	EventHookMode_PostNoCopy);
			UnhookEvent("round_end", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
			UnhookEvent("finale_win", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
			UnhookEvent("mission_lost", 		Event_RoundEnd,		EventHookMode_PostNoCopy);
			UnhookEvent("map_transition", 		Event_RoundEnd,		EventHookMode_PostNoCopy);
			UnhookEvent("player_disconnect", 	Event_PlayerDisconnect, EventHookMode_Pre);
			bHooked = false;
		}
	}
}
stock bool IsTank(int client)
{
	if( client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 )
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if( class == (g_bLeft4Dead2 ? 8 : 5 ))
			return true;
	}
	return false;
}
public Action Timer_CheckAngry(Handle timer, int UserId)
{
	static int client;
	client = GetClientOfUserId(UserId);
	if (client != 0 && IsClientInGame(client) && IsPlayerAlive(client) && g_bMapStarted) {
		// became angry?
		if (IsAngry(client) || g_bAngry[client]) {					
			g_bAtLeastOneTankAngry = true;		
			// 检查Tank是不是都在一个半径内移动
			CreateTimer(g_hCvarStuckInterval.FloatValue, Timer_CheckPos, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Stop;
		}
	}
	else
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public Action Timer_CheckPos(Handle timer, int UserId)
{
	static int tank;
	tank = GetClientOfUserId(UserId);
	if (tank != 0 && IsClientInGame(tank) && IsPlayerAlive(tank) && g_bMapStarted) {
		
		static float pos[3];
		GetClientAbsOrigin(tank, pos);
		
		static float distance;
		distance = GetVectorDistance(pos, g_pos[tank], false);
		
		if (distance < g_hCvarNonStuckRadius.FloatValue && !IsIncappedNearBy(pos) && !IsTankAttacking(tank)) {
			
			static bool bOnLadder;
			bOnLadder = IsOnLadder(tank);
			
			if ( g_iStuckTimes[tank] > 4)) {
				TeleportTank(tank);
			}
			else if (g_iStuckTimes[tank] > 1 || bOnLadder) {
				/*
				SetEntityMoveType (tank, MOVETYPE_NOCLIP);
				#if (DEBUG)
					PrintToChatAll("%N movetype: noclip", tank);
				#endif
				*/
				
				// teleport in direction of "bugger" player + apply velocity
				MakeTeleport(tank);
				
				#if (DEBUG)
					int anim = GetEntProp(tank, Prop_Send, "m_nSequence");
					PrintToChatAll("%N stucked => micro-teleport, dist: %f, anim: %i", tank, distance, anim);
				#endif
				
				/*
				SetEntProp(tank, Prop_Send, "m_nSequence", 12);
				CreateTimer(0.5, Timer_SetWalk, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
				*/
			}
			g_iStuckTimes[tank]++;
			
			CreateTimer(0.5, Timer_Unstuck, GetClientUserId(tank), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
		else {
			g_iStuckTimes[tank] = 0;
		}
		
		g_pos[tank] = pos;
	}
	else
		return Plugin_Stop;
	
	return Plugin_Continue;
}
bool IsTankAttacking(int tank)
{
	return GetEntProp(tank, Prop_Send, "m_fireLayerSequence") > 0;
}
bool IsIncappedNearBy(float vOrigin[3])
{
	static int i;
	static float vOriginPlayer[3];
	
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsIncapped(i))
		{
			GetClientAbsOrigin(i, vOriginPlayer);
			if (GetVectorDistance(vOriginPlayer, vOrigin) <= g_fTankClawRange)
				return true;
		}
	}
	return false;
}

stock bool IsOnLadder(int entity)
{
	return GetEntityMoveType(entity) == MOVETYPE_LADDER;
}
bool IsAngry(int tank)
{
	if (GetEntProp(tank, Prop_Send, "m_zombieState") != 0)
		return true;
	
	if (GetEntProp(tank, Prop_Send, "m_hasVisibleThreats") != 0)
		return true;
		
	return false;
}
public Action Timer_Unstuck(Handle timer, int UserId)
{
	static const int MAX_TRY = 10;
	
	static int client;
	client = GetClientOfUserId(UserId);
	
	static bool bOnLadder;
	bOnLadder = IsOnLadder(client);
	
	if (client != 0 && IsClientInGame(client) && (IsClientStuck(client) || bOnLadder)) {
		if (g_iTimes[client] < MAX_TRY) {
			TeleportPlayerSmoothByPreset(client);
			g_iTimes[client]++;
		}
		else {
			TeleportToObject(client);
			TeleportPlayerSmoothByPreset(client);
			g_iTimes[client] = 0;
			return Plugin_Stop;
		}
	}
	else {
		g_iTimes[client] = 0;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}