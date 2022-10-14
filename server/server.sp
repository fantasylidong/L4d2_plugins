#pragma semicolon 1
#pragma tabsize 0
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <left4dhooks>
#include <colors>
#undef REQUIRE_PLUGIN
#include <CreateSurvivorBot>
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

enum ZombieClass
{
	ZC_SMOKER = 1,
	ZC_BOOMER,
	ZC_HUNTER,
	ZC_SPITTER,
	ZC_JOCKEY,
	ZC_CHARGER,
	ZC_WITCH,
	ZC_TANK
};

public Plugin myinfo = 
{
	name 			= "AnneServer Server Function",
	author 			= "def075, Caibiii，东",
	description 	= "Advanced Special Infected AI",
	version 		= "2022.10.09",
	url 			= "https://github.com/Caibiii/AnneServer"
}

new Handle:hCvarMotdTitle;
new Handle:hCvarMotdUrl;
new Handle:hCvarIPUrl;
ConVar hMaxSurvivors, hSurvivorsManagerEnable, hCvarAutoKickTank;
int iMaxSurvivors, iEnable, iAutoKickTankEnable;
public OnPluginStart()
{
	RegConsoleCmd("sm_away", AFKTurnClientToSpe);
	RegConsoleCmd("sm_afk", AFKTurnClientToSpe);
	RegConsoleCmd("sm_s", AFKTurnClientToSpe);
	RegAdminCmd("sm_restartmap", RestartMap, ADMFLAG_ROOT, "restarts map");
	AddCommandListener(Command_Setinfo, "jointeam");
	AddCommandListener(Command_Setinfo1, "chooseteam");
	AddNormalSoundHook(NormalSHook:OnNormalSound);
	AddAmbientSoundHook(AmbientSHook:OnAmbientSound);
	HookEvent("player_team", Event_PlayerTeam);	
	HookEvent("witch_killed", WitchKilled_Event);
	HookEvent("finale_win", ResetSurvivors);
	HookEvent("map_transition", ResetSurvivors);
	HookEvent("round_start", event_RoundStart);
	HookEvent("player_spawn", 	Event_PlayerSpawn);
	HookEvent("player_incapacitated", OnPlayerIncappedOrDeath);
	HookEvent("player_death", OnPlayerIncappedOrDeath);
	HookEvent("player_disconnect", PlayerDisconnect_Event, EventHookMode_Pre);
	RegConsoleCmd("sm_join", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_jg", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_ip", ShowAnneServerIP);
	RegConsoleCmd("sm_web", ShowAnneServerWeb);
	RegConsoleCmd("sm_setbot", SetBot);
	RegAdminCmd("sm_kicktank", KickMoreTankThanOne, ADMFLAG_KICK, "有多只tank得情况，随机踢至只有一只");
	SetConVarBounds(FindConVar("survivor_limit"), ConVarBound_Upper, true, 8.0);
	RegAdminCmd("sm_addbot", ADMAddBot, ADMFLAG_KICK, "Attempt to add a survivor bot (this bot will not be kicked by this plugin until someone takes over)");
	hSurvivorsManagerEnable = CreateConVar("l4d_multislots_survivors_manager_enable", "0", "Enable or Disable survivors manage",CVAR_FLAGS, true, 0.0, true, 1.0);
	hMaxSurvivors	= CreateConVar("l4d_multislots_max_survivors", "4", "Kick AI Survivor bots if numbers of survivors has exceeded the certain value. (does not kick real player, minimum is 4)", CVAR_FLAGS, true, 4.0, true, 8.0);
	hCvarAutoKickTank = CreateConVar("l4d_multislots_autokicktank", "0", "Auto kick tank when tank number above one", CVAR_FLAGS, true, 0.0, true, 1.0);
	hCvarMotdTitle = CreateConVar("sm_cfgmotd_title", "AnneHappy电信服");
    hCvarMotdUrl = CreateConVar("sm_cfgmotd_url", "http://sb.trygek.com:8880/l4d_stats/index.php");  // 以后更换为数据库控制
	hCvarIPUrl = CreateConVar("sm_cfgip_url", "http://sb.trygek.com:8880/index.php");	// 以后更换为数据库控制
	hSurvivorsManagerEnable.AddChangeHook(ConVarChanged_Cvars);
	hMaxSurvivors.AddChangeHook(ConVarChanged_Cvars);
	hCvarAutoKickTank.AddChangeHook(ConVarChanged_Cvars);
	GetCvars();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
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

void GetCvars()
{
	iEnable = hSurvivorsManagerEnable.IntValue;
	iMaxSurvivors = hMaxSurvivors.IntValue;
	iAutoKickTankEnable = hCvarAutoKickTank.IntValue;
	if(iEnable){
		if(GetSurvivorCount() < iMaxSurvivors)
		{
			for(int i=1, j = iMaxSurvivors - GetSurvivorCount(); i <= j; i++ )
			{
				SpawnFakeClient();
			}
		}else if(GetSurvivorCount() > iMaxSurvivors){
			for(int i=1, j = GetSurvivorCount() - iMaxSurvivors; i <= j; i++ )
			{
				if(!GetRandomSurvivor(-1,1))
				{
					ChangeClientTeam(GetRandomSurvivor(),1);
					KickClient(GetRandomSurvivor(-1,1));
				}
				else	
					KickClient(GetRandomSurvivor(-1,1));
			}
		}
	}
}

public void Event_PlayerSpawn(Event hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId( hEvent.GetInt( "userid" ));
	if( IsValidClient(client) && IsAiTank(client) &&iAutoKickTankEnable){
		KickMoreTank(true);
	}
		
}




////////////////////////////////////
// Callbacks
////////////////////////////////////
public Action ADMAddBot(int client, int args)
{
	if(client == 0)
		return Plugin_Continue;
	
	if(SpawnFakeClient() == true)
		PrintToChat(client, "\x04一个生还者Bot被生成.");
	else
		PrintToChat(client,  "\x04暂时无法生成生还者Bot.");
	
	return Plugin_Handled;
}

//踢出数量大于1的tank
public Action KickMoreTankThanOne(int client, int args)
{
	if(client == 0)
		return Plugin_Continue;
	
	KickMoreTank(false);
	
	return Plugin_Handled;
}

public void KickMoreTank(bool autoKick){
	int tankNum = 0, tank[32];
	for(int i = 0; i < MaxClients; i++){
		if( IsValidClient(i) && IsAiTank(i)){
			tank[tankNum++] = i;
		}
	}
	if(tankNum <= 1){
		if(!autoKick)
			PrintToChatAll("\x04一切正常还想踢克逃课？");
	}else{
		for(int i = tankNum - 1; i > 0; i--){
			KickClient(i, "过分了啊，一个克就够难了, %N 被踢出", tank[i]);
		}
		PrintToChatAll("\x04已经踢出多余的克");
	}
}
// 是否 ai 坦克
bool IsAiTank(int client)
{
	return view_as<bool>(GetInfectedClass(client) == view_as<int>(ZC_TANK) && IsFakeClient(client));
}

// 获取特感类型，成功返回特感类型，失败返回 0
stock int GetInfectedClass(int client)
{
	if (IsValidInfected(client))
	{
		return GetEntProp(client, Prop_Send, "m_zombieClass");
	}
	else
	{
		return 0;
	}
}

// 判断特感是否有效，有效返回 true，无效返回 false
stock bool IsValidInfected(int client)
{
	if (IsValidClient(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	else
	{
		return false;
	}
}


//try to spawn survivor
bool SpawnFakeClient()
{
	//check if there are any alive survivor in server
	int iAliveSurvivor = GetRandomSurvivor(1);
	if(iAliveSurvivor == 0)
		return false;
		
	// create fakeclient
	int fakeclient = CreateSurvivorBot();
	
	// if entity is valid
	if(fakeclient > 0 && IsClientInGame(fakeclient))
	{
		float teleportOrigin[3];
		GetClientAbsOrigin(iAliveSurvivor, teleportOrigin)	;
		TeleportEntity( fakeclient, teleportOrigin, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	
	return false;
}

public Action:SetBot(client, args) 
{
    if(iEnable){
		if(GetSurvivorCount() < iMaxSurvivors)
		{
			for(int i=1, j = iMaxSurvivors - GetSurvivorCount(); i <= j; i++ )
			{
				SpawnFakeClient();
			}
		}else if(GetSurvivorCount() > iMaxSurvivors){
			for(int i=1, j = GetSurvivorCount() - iMaxSurvivors; i <= j; i++ )
			{
				if(!GetRandomSurvivor(-1,1))
				{
					ChangeClientTeam(GetRandomSurvivor(),1);
					KickClient(GetRandomSurvivor(-1,1));
				}
				else	
					KickClient(GetRandomSurvivor(-1,1));
			}
		}
	}
}



/**
 * @brief Get survivor count.
 * 
 * @return          Survivor count.
 */
 
stock int GetSurvivorCount()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsSurvivor(i))
            count++;

    return count;
}
/*
//尸潮数量更改
public Action Timer_MobChange(Handle timer)
{
    FindConVar("z_common_limit").SetInt(6 * GetSurvivorCount());
    FindConVar("z_mega_mob_size").SetInt(9 * GetSurvivorCount());
    FindConVar("z_mob_spawn_min_size").SetInt(4 * GetSurvivorCount());
    FindConVar("z_mob_spawn_max_size").SetInt(4 * GetSurvivorCount());

    return Plugin_Stop;
}
*/


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




public void OnAutoConfigsBuffered()
{
	 char sMapConfig[128];
	 GetCurrentMap(sMapConfig, sizeof(sMapConfig));
     Format(sMapConfig, sizeof(sMapConfig), "cfg/sourcemod/map_cvars/%s.cfg", sMapConfig);
     if (FileExists(sMapConfig, true))
	 {
        strcopy(sMapConfig, sizeof(sMapConfig), sMapConfig[4]);
        ServerCommand("exec \"%s\"", sMapConfig);
     }
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

void checkbot(){
	int count=0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			count++;
		}
	}
	if(count==0)
	{
		while(count<=4){
			ServerCommand("sb_add");
			count++;
		}	
	}
}

public Action:AFKTurnClientToSurvivors(client, args)
{ 
	checkbot();
	if(!IsSuivivorTeamFull())
	{
		ClientCommand(client, "jointeam survivor");
	}
	return Plugin_Handled;
}

public Action RestartMap(client,args)
{
	CrashMap();
}

public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer( 3.0, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE );
}

public Action:Timer_DelayedOnRoundStart(Handle:timer) 
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
	char sMapConfig[128];
	GetCurrentMap(sMapConfig, sizeof(sMapConfig));
    Format(sMapConfig, sizeof(sMapConfig), "cfg/sourcemod/map_cvars/%s.cfg", sMapConfig);
    if (FileExists(sMapConfig, true))
    {
        strcopy(sMapConfig, sizeof(sMapConfig), sMapConfig[4]);
        ServerCommand("exec \"%s\"", sMapConfig);
    }
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	SetConVarString(FindConVar("mp_gamemode"), "realism");
	return Plugin_Handled;
}

public Action:ResetSurvivors(Handle:event, const String:name[], bool:dontBroadcast)
{
	RestoreHealth();
	ResetInventory();
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

	if(client > 0 && IsClientConnected(client) && !IsFakeClient(client))
	{
		//ServerCommand("sm_addbot2");
		CreateTimer(3.0, Timer_CheckDetay, client, TIMER_FLAG_NO_MAPCHANGE);
	}

}


public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetEventInt(event, "userid");
	new target = GetClientOfUserId(Client);
	new team = GetEventInt(event, "team");
	new bool:disconnect = GetEventBool(event, "disconnect");
	if (IsValidPlayer(target) && !disconnect && team == 3)
	{
		if(!IsFakeClient(target))
		{
			CreateTimer(0.5, Timer_CheckDetay2, target, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	//CreateTimer(0.1, Timer_MobChange, 0, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action:Timer_CheckDetay(Handle:Timer, any:client)
{
	if(IsValidPlayerInTeam(client, 3))
	{
		ChangeClientTeam(client, 1); 
	}
}

public Action:Timer_CheckDetay2(Handle:Timer, any:client)
{
	ChangeClientTeam(client, 1); 
}
/*
public Action:Timer_ReStartMap(Handle:Timer, any:client)
{
	new humans = GetHumanCount();
	if(humans > g_ServerMaxSurvivor)
	{	
		PrintToChatAll("[检测到未知错误.即将重启地图]");
		ServerCommand("sm_restartmap");
	}
}
*/
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

public Action:L4D_OnFirstSurvivorLeftSafeArea() 
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
	SetBot(0,0);
	CreateTimer(0.5, Timer_AutoGive, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

public Action:Timer_AutoGive(Handle:timer) 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			//增加死亡玩家复活
			if(!IsPlayerAlive(client))
				L4D_RespawnPlayer(client);
			BypassAndExecuteCommand(client, "give","pain_pills"); 
			BypassAndExecuteCommand(client, "give","health"); 
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
			if(IsFakeClient(client))
			{
				for (new i = 0; i < 1; i++) 
				{ 
					DeleteInventoryItem(client, i);		
				}
				BypassAndExecuteCommand(client, "give","smg_silenced");
				BypassAndExecuteCommand(client, "give","pistol_magnum");
			}
		}
	}
}
//玩家加入游戏
public OnClientConnected(client)
{
	if(!IsFakeClient(client))
	{
		PrintToChatAll("\x04 %N \x05正在爬进服务器",client);
	}
}
/*
// 玩家离开游戏 
public OnClientDisconnect(client)
{
	if(!client || IsFakeClient(client) || (IsClientConnected(client) && !IsClientInGame(client))) return; //連線中尚未進來的玩家離線
	if(!IsFakeClient(client))
	{
		PrintToChatAll("\x04 %N \x05离开服务器",client);
	}
}
*/


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

public Action:OnNormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}

public Action:OnAmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}

ResetInventory() 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			
			for (new i = 0; i < 5; i++) 
			{ 
				DeleteInventoryItem(client, i);		
			}
			BypassAndExecuteCommand(client, "give", "pistol");
			
		}
	}		
}
DeleteInventoryItem(client, slot) 
{
	new item = GetPlayerWeaponSlot(client, slot);
	if (item > 0) 
	{
		RemovePlayerItem(client, item);
	}	
}
/*
FindSurvivorBot()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 2)
		{
			return client;
		}
	}
	return -1;
}
*/
RestoreHealth() 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			BypassAndExecuteCommand(client, "give","health");
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
		}
	}
}
public Action:CrashServer(Handle:timer)
{
	//LogError("无人连接服务器，crash服务器");
    SetCommandFlags("crash", GetCommandFlags("crash")&~FCVAR_CHEAT);
    ServerCommand("crash");
}

CrashMap()
{
    decl String:mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
}
/*
GetHumanCount()
{
	new humans = 0;
	new i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			humans++;
		}
	}
	return humans;
}
*/
BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
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
//判断是否为玩家再队伍里
bool:IsValidPlayerInTeam(client,team)
{
	if(IsValidPlayer(client))
	{
		if(GetClientTeam(client)==team)
		{
			return true;
		}
	}
	return false;
}
bool:IsValidPlayer(Client, bool:AllowBot = true, bool:AllowDeath = true)
{
	if (Client < 1 || Client > MaxClients)
		return false;
	if (!IsClientConnected(Client) || !IsClientInGame(Client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(Client))
			return false;
	}

	if (!AllowDeath)
	{
		if (!IsPlayerAlive(Client))
			return false;
	}	
	
	return true;
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