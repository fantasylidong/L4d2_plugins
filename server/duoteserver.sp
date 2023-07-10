#pragma semicolon 1
#pragma tabsize 0
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <colors>
#include <steamworks>
#undef REQUIRE_PLUGIN
#include <veterans>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define L4D_MAXHUMANS_LOBBY_OTHER 3
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))

bool g_bGroupSystemAvailable = false;

public void OnAllPluginsLoaded(){
	g_bGroupSystemAvailable = LibraryExists("veterans");
}
public void OnLibraryAdded(const char[] name)
{
    if ( StrEqual(name, "veterans") ) { g_bGroupSystemAvailable = true; }
}
public void OnLibraryRemoved(const char[] name)
{
    if ( StrEqual(name, "veterans") ) { g_bGroupSystemAvailable = false; }
}

new Handle:hCvarMotdUrl;
new Handle:hCvarIPUrl;
new Handle:hCvarMotdTitle;
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
	HookEvent("player_incapacitated", OnPlayerIncappedOrDeath);
	HookEvent("player_death", OnPlayerIncappedOrDeath);
	HookEvent("player_disconnect", PlayerDisconnect_Event, EventHookMode_Pre);
	RegConsoleCmd("sm_ip", ShowAnneServerIP);
	RegConsoleCmd("sm_web", ShowAnneServerWeb);
	RegConsoleCmd("sm_zs", ZiSha);
	RegConsoleCmd("sm_kill", ZiSha);
	hCvarMotdTitle = CreateConVar("sm_cfgmotd_title", "电信战役服");
    hCvarMotdUrl = CreateConVar("sm_cfgmotd_url", "http://sb.trygek.com:8880/l4d_stats/index.php");  // 以后更换为数据库控制
	hCvarIPUrl = CreateConVar("sm_cfgip_url", "http://sb.trygek.com:8880/index.php");	// 以后更换为数据库控制
}


public Action:PlayerDisconnect_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event,"userid"));

    if (!(1 <= client <= MaxClients))
        return Plugin_Handled;

    if (!IsClientInGame(client))
        return Plugin_Handled;

    if (IsFakeClient(client))
        return Plugin_Handled;

    new String:reason[64];
    new String:message[64];
    GetEventString(event, "reason", reason, sizeof(reason));

    if(StrContains(reason, "connection rejected", false) != -1)
    {
        Format(message,sizeof(message),"连接被拒绝");
    }
    else if(StrContains(reason, "timed out", false) != -1)
    {
        Format(message,sizeof(message),"超时");
    }
    else if(StrContains(reason, "by console", false) != -1)
    {
        Format(message,sizeof(message),"控制台退出");
    }
    else if(StrContains(reason, "by user", false) != -1)
    {
        Format(message,sizeof(message),"自己主动断开连接");
    }
    else if(StrContains(reason, "ping is too high", false) != -1)
    {
        Format(message,sizeof(message),"ping 太高了");
    }
    else if(StrContains(reason, "No Steam logon", false) != -1)
    {
        Format(message,sizeof(message),"no steam logon/ steam验证失败");
    }
    else if(StrContains(reason, "Steam account is being used in another", false) != -1)
    {
        Format(message,sizeof(message),"steam账号被顶");
    }
    else if(StrContains(reason, "Steam Connection lost", false) != -1)
    {
        Format(message,sizeof(message),"steam断线");
    }
    else if(StrContains(reason, "This Steam account does not own this game", false) != -1)
    {
        Format(message,sizeof(message),"没有这款游戏");
    }
    else if(StrContains(reason, "Validation Rejected", false) != -1)
    {
        Format(message,sizeof(message),"验证失败");
    }
    else if(StrContains(reason, "Certificate Length", false) != -1)
    {
        Format(message,sizeof(message),"certificate length");
    }
    else if(StrContains(reason, "Pure server", false) != -1)
    {
        Format(message,sizeof(message),"纯净服务器");
    }
    else
    {
        message = reason;
    }

    CPrintToChatAll("{green}%N {olive}离开了游戏 - 理由: [{green}%s{olive}]", client, message);
    return Plugin_Handled;
} 

//系统自带的玩家离开游戏提示(聊天提示：XXX 离开了游戏。)
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = true;
	return Plugin_Handled;
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

ShowMotdToPlayer(client)
{
	decl String:title[64], String:url[192];
    GetConVarString(hCvarMotdTitle, title, sizeof(title));
    GetConVarString(hCvarMotdUrl, url, sizeof(url));
    ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
}

public Action:ShowAnneServerIP(client, args) 
{
    decl String:title[64], String:url[192];
    GetConVarString(hCvarMotdTitle, title, sizeof(title));
    GetConVarString(hCvarIPUrl, url, sizeof(url));
	ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
}

public Action:ShowAnneServerWeb(client, args) 
{
    decl String:title[64], String:url[192];
    GetConVarString(hCvarMotdTitle, title, sizeof(title));
    GetConVarString(hCvarMotdUrl, url, sizeof(url));
	ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
}

public Action RestartMap(client,args)
{
	CrashMap();
	return Plugin_Handled;
}

public OnClientPutInServer(client)
{
	if(g_bGroupSystemAvailable){
		if(!Veterans_Get(client, view_as<TARGET_OPTION_INDEX>(GOURP_MEMBER))){
			ShowMotdToPlayer(client);
		}
	}else{
		ShowMotdToPlayer(client);
	}
}


public OnPlayerIncappedOrDeath(Handle event, char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	if(!client)
		return;
	if(!IsClientConnected(client) || !IsClientInGame(client))
	if((GetClientTeam(client) !=2))
		return;
	if(IsTeamImmobilised())
	{
		SlaySurvivors();
	}
}

public void OnGameFrame(){
	SteamWorks_SetGameDescription("电信战役多特服");
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



//过图回复不满50血的血量
public ChangeMap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++){
		if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			new targetHealth = GetSurvivorPermHealth(client);
			L4D_SetPlayerReviveCount(client, 0);
			if(targetHealth < 50)
			{
				SetSurvivorPermHealth(client, 50);
				L4D_SetTempHealth(client,0.0);
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

/**
 * @return: true if all survivors are either incapacitated or pinned
**/
bool IsTeamImmobilised() {
	bool bIsTeamImmobilised = true;
	for (new client = 1; client < MaxClients; client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			if (!L4D_IsPlayerIncapacitated(client) ) {		
				bIsTeamImmobilised = false;				
				break;
			} 
		} 
	}
	return bIsTeamImmobilised;
}

void SlaySurvivors() { //incap everyone
	for (new client = 1; client < (MAXPLAYERS + 1); client++) {
		if (IsSurvivor(client) && IsPlayerAlive(client)) {
			ForcePlayerSuicide(client);
		}
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