#pragma semicolon 1
#pragma tabsize 0
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <colors>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define L4D_MAXHUMANS_LOBBY_OTHER 3
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))

new Handle:hCvarMotdUrl;
new Handle:hCvarIPUrl;
new Handle:COLD_DOWN_Timer;
public OnPluginStart()
{
	RegConsoleCmd("sm_away", AFKTurnClientToSpe);
	RegConsoleCmd("sm_afk", AFKTurnClientToSpe);
	RegConsoleCmd("sm_s", AFKTurnClientToSpe);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookUserMessage(GetUserMessageId("TextMsg"), TextMsg, true);
	RegAdminCmd("sm_restartmap", RestartMap, ADMFLAG_ROOT, "restarts map");
	HookEvent("map_transition", ChangeMap_Event);
	HookEvent("witch_killed", WitchKilled_Event);
	HookEvent("revive_success", BlackReminder_Event);	
	RegConsoleCmd("sm_ip", ShowAnneServerIP);
	RegConsoleCmd("sm_zs", ZiSha);
	RegConsoleCmd("sm_kill", ZiSha);
	RegAdminCmd("sm_restart", RestartServer, ADMFLAG_ROOT, "Kicks all clients and restarts server");
    hCvarMotdUrl = CreateConVar("sm_cfgmotd_url", "http://sb.trygek.com:8880/l4d_stats/index.php");  // 以后更换为数据库控制
	hCvarIPUrl = CreateConVar("sm_cfgip_url", "http://sb.trygek.com:8880/l4d_stats/index.php");	// 以后更换为数据库控制
}
//系统自带的玩家离开游戏提示(聊天提示：XXX 离开了游戏。)
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = true;
}

//系统自带的闲置提示(聊天提示：XXX 已闲置。)
public Action TextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	static char sBuffer[256];
	msg.ReadString(sBuffer, sizeof(sBuffer));

	if(StrContains(sBuffer, "L4D_idle_spectator") != -1)
		return Plugin_Handled;

	return Plugin_Continue;
}
public Action:ZiSha(client, args)
{
	ForcePlayerSuicide(client);
	return Plugin_Handled;
}
void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();
	}
}

// by sorallll
int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if (index == -1)
		return -1;

	for (int i = strlen(sBuffer); i >= 0; i--)
	{
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	}

	return -1;
}
public Action RestartServer(client,args)
{
	UnloadAccelerator();
	CreateTimer(3.0, CrashServer);
}

ShowMotdToPlayer(client)
{
	decl String:title[64], String:url[192];
    GetConVarString(hCvarMotdUrl, url, sizeof(url));
    ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
}
public Action:ShowAnneServerIP(client, args) 
{
    decl String:title[64], String:url[192];
    GetConVarString(hCvarIPUrl, url, sizeof(url));
	ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
}

public Action RestartMap(client,args)
{
	CrashMap();
}

public OnClientPutInServer(client)
{
	ShowMotdToPlayer(client);
}


public Action:Command_Setinfo(client, const String:command[], args)
{
    decl String:arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    if (!StrEqual(arg, "survivor") || IsSuivivorTeamFull())
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
} 

public Action:Command_Setinfo1(client, const String:command[], args)
{
    return Plugin_Handled;
} 

public Action:AFKTurnClientToSpe(client, args) 
{
	if(!IsPinned(client))
		CreateTimer(2.5, Timer_CheckAway, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}
public Action:Timer_CheckAway(Handle:Timer, any:client)
{
	ChangeClientTeam(client, 1); 
}




//玩家加入游戏
public OnClientConnected(client)
{
	if(!IsFakeClient(client))
	{
		PrintToChatAll("\x04 %N \x05正在爬进服务器",client);
	}
}

// 玩家离开游戏 
public OnClientDisconnect(client)
{
	if(!client || IsFakeClient(client) || (IsClientConnected(client) && !IsClientInGame(client))) return; //連線中尚未進來的玩家離線
	if(!IsFakeClient(client))
	{
		PrintToChatAll("\x04 %N \x05离开服务器",client);
	}
	if(client && !checkrealplayerinSV(client)) //檢查是否還有玩家以外的人還在伺服器或是連線中
	{
		delete COLD_DOWN_Timer;
		COLD_DOWN_Timer = CreateTimer(5.0, COLD_DOWN);
	}
}

public Action COLD_DOWN(Handle timer, any client)
{
	if(checkrealplayerinSV(0))
	{
		COLD_DOWN_Timer = null;
		return Plugin_Continue;
	}
	
	LogMessage("Last one player left the server, Restart server now");

	UnloadAccelerator();
	CreateTimer(3.0, CrashServer);

	COLD_DOWN_Timer = null;
	return Plugin_Continue;
}
bool checkrealplayerinSV(int client)
{
	for (int i = 1; i < MaxClients+1; i++)
		if(IsClientConnected(i) && !IsFakeClient(i) &&i !=client)
			return true;

	return false;
}
public void OnPluginEnd()
{
	delete COLD_DOWN_Timer;
}



public void OnMapEnd()
{
	delete COLD_DOWN_Timer;
}

//过图回复不满50血的血量
public ChangeMap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++){
		if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			new targetHealth = GetSurvivorPermHealth(client);
			if(targetHealth > 50)
			{
				L4D_SetPlayerReviveCount(client,0);
			}
			else{
				SetSurvivorPermHealth(client, 50);
				L4D_SetTempHealth(client,0);
				L4D_SetPlayerReviveCount(client,0);
			}
			
		}
	}

}
//秒妹回实血
public WitchKilled_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncap(client))
	{
		new maxhp = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		new targetHealth = GetSurvivorPermHealth(client) + 15;
		if(targetHealth > maxhp)
		{
			targetHealth = maxhp;
		}
		SetSurvivorPermHealth(client, targetHealth);
	}
}

//黑白提醒
public BlackReminder_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "subject"));
	int revivecount = L4D_GetPlayerReviveCount(client);
	if(revivecount==2)
		PrintToChatAll("\x05请注意，\x04 %N \x05已经黑白啦",client);
}


public Action:CrashServer(Handle:timer)
{
    SetCommandFlags("crash", GetCommandFlags("crash")&~FCVAR_CHEAT);
    ServerCommand("crash");
}

CrashMap()
{
    decl String:mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
}

//判断生还是否已经满人
bool:IsSuivivorTeamFull() 
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsFakeClient(i))
		{
			return false;
		}
	}
	return true;
}
//判断是否为生还者
stock bool:IsSurvivor(client) 
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2) 
	{
		return true;
	} 
	else 
	{
		return false;
	}
}



//判断生还者是否已经被控
stock bool:IsPinned(client) 
{
	new bool:bIsPinned = false;
	if (IsSurvivor(client)) 
	{
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

GetSurvivorPermHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

SetSurvivorPermHealth(client, health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}