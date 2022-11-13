#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define PLUGIN_DATE "2022-3-28"

// ConVars
ConVar g_hInfectedTime, g_hInfectedLimit;
// Ints
int g_iInfectedTime, g_iInfectedLimit, g_iMaxPlayers, g_iRoundCount = 1;

// Chars
char currentmap[8], previousmap[8];

public Plugin myinfo = 
{
	name 			= "Mode Text Dispay",
	author 			= "Caibiii, 夜羽真白，东",
	description 	= "游戏模式，难度显示",
	version 		= "2022.03.29",
	url 			= "https://github.com/GlowingTree880/L4D2_LittlePlugins"
}

public void OnPluginStart()
{
	g_hInfectedTime = FindConVar("versus_special_respawn_interval");
	g_hInfectedLimit = FindConVar("l4d_infected_limit");
	// HookEvents
	HookEvent("round_start", evt_RoundStart, EventHookMode_Post);
	HookEvent("mission_lost", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", evt_RoundEnd, EventHookMode_PostNoCopy);
	// RegConsoleCmd
	RegConsoleCmd("sm_xx", Cmd_InfectedStatus);
	RegConsoleCmd("sm_zs", Cmd_Suicide);
	RegConsoleCmd("sm_kill", Cmd_Suicide);
	// AddCnahgeHook
	g_hInfectedTime.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedLimit.AddChangeHook(ConVarChanged_Cvars);
	// GetCvars
	GetCvars();
}

// *********************
//		获取Cvar值
// *********************
void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iInfectedLimit = g_hInfectedLimit.IntValue;
	g_iInfectedTime = g_hInfectedTime.IntValue;
}

// *********************
//		    事件
// *********************
public void OnMapStart()
{
	GetCurrentMap(currentmap, sizeof(currentmap));
	if (strcmp(currentmap, previousmap) != 0)
	{
		g_iRoundCount = 1;
	}
}

public Action evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	PrintStatus();
}

public Action evt_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	GetCurrentMap(previousmap, sizeof(previousmap));
	g_iRoundCount++;
}



public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	ReloadPlugins();
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	if (IsValidPlayer(client, false, true))
	{
		g_iMaxPlayers += 1;
		if (g_iMaxPlayers >= 3)
		{
			L4D_LobbyUnreserve();
			ServerCommand("sm_cvar sv_allow_lobby_connect_only 0");
		}
		PrintStatus();
	}
}

// *********************
//		    指令
// *********************
public Action Cmd_Suicide(int client, int args)
{
	ForcePlayerSuicide(client);
	return Plugin_Handled;
}

public Action Cmd_InfectedStatus(int client, int args)
{
	PrintStatus();
}

// *********************
//		    方法
// *********************
void PrintStatus()
{
	char spawnmode[16];
	CPrintToChatAll("{lightgreen}回合{green}[{olive}%d{green}] {lightgreen}特感{green}[{olive}%s%d特%d秒{green}] {lightgreen}插件{green}[{olive}%s{green}]", g_iRoundCount, g_iInfectedLimit, g_iInfectedTime, PLUGIN_DATE);

}

bool IsValidPlayer(int client, bool allowbot, bool allowdeath)
{
	if (client && client <= MaxClients)
	{
		if (IsClientConnected(client) && IsClientInGame(client))
		{
			if (!allowbot)
			{
				if (IsFakeClient(client))
				{
					return false;
				}
			}
			if (!allowdeath)
			{
				if (!IsPlayerAlive(client))
				{
					return false;
				}
			}
			return true;
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
}

bool IsValidSurvivor(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsIncapped(int client)
{
	bool bIsIncapped;
	if (IsValidSurvivor(client))
	{
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0)
		{
			bIsIncapped = true;
		}
		if (!IsPlayerAlive(client))
		{
			bIsIncapped = true;
		}
	}
	return bIsIncapped;
}

void ReloadPlugins()
{
	ServerCommand("sm plugins load_unlock");
	ServerCommand("sm plugins reload optional/infected_controlR.smx");
	ServerCommand("sm plugins load_lock");
	ServerCommand("sm_startspawn");
}

bool IsTeamImmobilised()
{
	bool bIsTeamImmobilised = true;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client) && IsPlayerAlive(client))
		{
			if (!IsIncapped(client))
			{
				bIsTeamImmobilised = false;
			}
		}
	}
	return bIsTeamImmobilised;
}