#pragma newdecls required
/**/
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4dstats>
#include <colors>
#include <l4d_hats>

#define PLUGIN_VERSION "1.0.0"
#define MAX_LINE_WIDTH 64

// 进行 MySQL 连接相关变量
Handle db = INVALID_HANDLE;
int ClientPoints[MAXPLAYERS + 1];
int ClientBlood[MAXPLAYERS + 1];
int ClientMelee[MAXPLAYERS + 1];
int ClientHat[MAXPLAYERS + 1];
int GlowType[MAXPLAYERS+1];
bool ClientFirstBuy[MAXPLAYERS + 1];
ConVar GaoJiRenJi;
bool valid=true;
bool IsStart=false;
int InfectedNumber=6;
ConVar g_InfectedNumber;
//new lastpoints[MAXPLAYERS + 1];

//枚举变量,修改武器消耗积分在此。
enum costweapon
{
	CostAmmo			=0,
	//手枪
	CostP220		    = 50,
	CostMagnum		    = 50,
	//冲锋枪
	CostUzi 		    = 50,
	CostSilenced 	    = 50,
	CostMP5 		    = 100,
	//步枪
	CostM16 		    = 200,
	CostAK47   		    = 200,
	CostSCAR 		    = 200,
	CostSG552 		    = 200,
	//连狙
	CostHunting 	    = 200,
	CostMilitary        = 200,
	//栓狙
	CostAWP 		    = 500,
	CostScout 		    = 300,
	//连喷
	CostAuto 		    = 200,
	CostSPAS 		    = 200,
	//单喷
	CostChromeShotgun   = 50,
	CostPumpShotgun     = 50,
	//特殊武器
	CostGrenadeLuanch   = 500,
	CostM60 			= 500,
	//医疗物品
	CostFirstAidKit		= 500,
	//药品
	CostAdren 			= 300,
	CostPills 			= 400,
	//升级附件
	CostGascan			= 200,
	CostGnome			= 500,
}
enum TEAM
{
    Team_Spectator = 1,
    Team_Survivor = 2,
    Team_Infected = 3
};
ConVar ReturnBlood;
//插件开始
public Plugin myinfo =
{
	name = "商店插件",
	author = "东",
	description = "购买游戏道具,幸存者轮廓，帽子保存",
	version = PLUGIN_VERSION,
	url = "http://sb.trygek.com:18443"
}

public bool IsSurvivor(int client)
{
    return (IsValidClient(client) && GetClientTeam(client) == view_as<int>(Team_Survivor));
}
public bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}

public void OnSetHat(int client, int index)
{
	if(FindConVar("l4d_hats_save").BoolValue)
		return;
	ClientHat[client] = index;
	ClientSaveToFileSave(client);
}


public Action L4D_OnHatLoadSave(int client, int &index, bool load)
{
	//PrintToConsoleAll("index:%d load:%d",index,load);
	//LogError("index:%d load:%d",index,load);
	if(load)
	{
		if(ClientHat[client] == 0)
			return Plugin_Continue;
		else
		{
			index = ClientHat[client];
			return Plugin_Changed;
		}
	}
	else
	{
		if(index == 0)
			return Plugin_Continue;
		else
		{
			ClientHat[client] = index;
			ClientSaveToFileSave(client);
			return Plugin_Continue;
		}
	}
}

//载入事件
public void OnMapStart()
{
	for(int i=1;i<MaxClients;i++){
		if(IsSurvivor(i))
			{
				ClientFirstBuy[i]=true;
				ClientPoints[i]=500;
			}
		else
			ClientPoints[i]=0;
		IsStart=false;
		valid=true;
	}
	//LogError("MapStart");
}

public void  OnPluginStart()
{
//	LoadTranslations("menu_shop.phrases.txt");
	HookEvent("round_start",EventRoundStart);
	HookEvent("player_death", EventReturnBlood);
	HookEvent("player_spawn", 	Event_Player_Spawn);
	HookEvent("mission_lost",EventMissionLost);
	HookEvent("map_transition", EventMapChange);
	HookEvent("player_afk", 	Event_PlayerAFK);
	//HookEvent("player_team", 	Event_PlayerTeam, EventHookMode_Pre);
	GaoJiRenJi=FindConVar("sb_fix_enabled");
	InfectedNumber=GetConVarInt(FindConVar("l4d_infected_limit"));
	g_InfectedNumber=FindConVar("l4d_infected_limit");
	g_InfectedNumber.AddChangeHook(ConVarChanged_Cvars);
	GaoJiRenJi.AddChangeHook(ConVarChanged_Cvars);
	ReturnBlood = CreateConVar("ReturnBlood", "0", "回血模式");
	RegConsoleCmd("sm_buy", BuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_ammo", BuyAmmo, "快速买子弹");
	RegConsoleCmd("sm_pen", BuyPen, "快速随机买一把单喷");
	RegConsoleCmd("sm_chr", BuyChr, "快速买一把二代单喷");
	RegConsoleCmd("sm_pum", BuyPum, "快速买一把一代单喷");
	RegConsoleCmd("sm_smg", BuySmg, "快速买smg");
	RegConsoleCmd("sm_uzi", BuyUzi, "快速买uzi");
	RegConsoleCmd("sm_pill", BuyPill, "快速买药");
	RegConsoleCmd("sm_rpg", BuyMenu, "打开购买菜单(只能在游戏中)");
	RegAdminCmd("sm_rpginfo", RpgInfo, ADMFLAG_ROOT ,"输出rpg人物信息");
	ConnectDB();
	for(int i=1;i<MaxClients;i++){
			ClientPoints[i]=500;
			ClientFirstBuy[i]=true;
	}
	//LogError("PluginStart");
}

// *********************
//		获取Cvar值
// *********************
void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(IsStart)
		{
			PrintToChatAll("\x04[RANK]判断额外积分所需变量发生变化，此局无法获得额外积分");
			valid=false;
		}
	InfectedNumber=GetConVarInt(FindConVar("l4d_infected_limit"));
}

public void Event_PlayerAFK( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	DisableGlow( GetClientOfUserId( hEvent.GetInt("userid")) );
}
bool check=false;
public void Event_Player_Spawn(Event hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId( hEvent.GetInt( "userid" ));
	if( client && IsClientInGame( client ) && !check){
		check = true;
		CreateTimer( 0.3, PlayerSpawnTimer, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
	}
		
}

stock bool IsPlayerGhost( int client )
{
	if( GetEntProp( client, Prop_Send, "m_isGhost", 1 ) ) 
		return true;
	
	return false;
} 

public Action PlayerSpawnTimer( Handle hTimer, any UserID )
{
	int client = GetClientOfUserId( UserID );
	if( client <= 0 || IsClientConnected( client ) != true )
		return;
	
	if( GetClientTeam( client ) == 2 && IsPlayerGhost( client ) != true )
	{
		if(GlowType[client])
			GetAura(client,GlowType[client]);
		if(ClientHat[client])
			ServerCommand("sm_hatclient #%d %d", GetClientUserId(client), ClientHat[client]);
	}
	else if( GetClientTeam( client ) == 3 )
	{
		DisableGlow( client );
	}
	check = false;
}

public void Event_PlayerTeam(Event hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId (hEvent.GetInt("userid"));
	int iTeam = hEvent.GetInt("team");
	if( iTeam == 2 )
	{
		if(GlowType[client])
			GetAura(client,GlowType[client]);
		if(ClientHat[client])
			ServerCommand("sm_hatclient #%d %d", GetClientUserId(client), ClientHat[client]);
		//PrintToConsole(client,"sm_hatclient #%d %d", GetClientUserId(client), ClientHat[client]-1);
	}
	if( iTeam == 3 ) 
		DisableGlow( client );
}


public int GetSurvivorPermHealth(int client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth", 4, 0);
}

public int SetSurvivorPermHealth(int client, int health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health, 4, 0);
	return 0;
}

public int IsPlayerIncap(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated", 4, 0);
}

public Action EventMapChange(Handle event, const char []name, bool dontBroadcast){
	if(CheckAllMoney()&&valid)
		RewardScore();
	for(int i=1;i<MaxClients;i++){
		ClientPoints[i]=500;
		ClientFirstBuy[i]=true;
	}
	IsStart=false;
	valid=true;
}

public void RewardScore(){
	char pluginsname[64];
	int renji=0;
	GetConVarString(FindConVar("sv_tags"), pluginsname, sizeof(pluginsname));
	if(StrContains(pluginsname,"anne")==-1)
		return;
	renji=GetConVarInt(FindConVar("sb_fix_enabled"));
	if(renji){
		PrintToChatAll("\x04[RANK]由于开启了高级人机，不能获得额外过关积分");
		return;
	}
	if(valid){
			if(InfectedNumber==5)
				AddReward(200);
			if(InfectedNumber==6)
				AddReward(500);
			if(InfectedNumber==7)
				AddReward(800);
			if(InfectedNumber==8)
				AddReward(1100);
			if(InfectedNumber==9)
				AddReward(1500);
			if(InfectedNumber>9)
				AddReward(2000);
		}
	valid=true;
}

public void AddReward(int Score){
	for(int i=1;i<MaxClients;i++){
		if(IsSurvivor(i))
			ClientMapChangeWithoutBuyReward(i,Score);
	}
	PrintToChatAll("\x04[RANK]幸存者强势通过当前关卡，没花费任何B数，获得额外%d过关积分",Score);
}

public Action EventMissionLost(Handle event, const char []name, bool dontBroadcast){
	for(int i=1;i<MaxClients;i++){
				ClientPoints[i]=500;
				ClientFirstBuy[i]=true;
	}
	IsStart=false;
	valid=true;
}



public void EventReturnBlood(Handle event, const char []name, bool dontBroadcast){
	int victim = GetClientOfUserId(GetEventInt(event, "userid", 0));
	DisableGlow( victim );
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker", 0));
	int var2 = victim;
	if (MaxClients >= var2 && 1 <= var2)
	{
		if (GetClientTeam(victim) == 3)
		{
			if (IsSurvivor(attacker))
			{
					if (GetConVarBool(ReturnBlood))
					{
						int maxhp = GetEntProp(attacker, Prop_Data, "m_iMaxHealth", 4, 0);
						int targetHealth = GetSurvivorPermHealth(attacker);
						if(ClientBlood[attacker]>0)
							targetHealth += 2;
						if (targetHealth > maxhp)
						{
							targetHealth = maxhp;
						}
						if (!IsPlayerIncap(attacker))
						{
							SetSurvivorPermHealth(attacker, targetHealth);
						}
					}
			}
		}
	}
}

public void ConnectDB()
{
    if (SQL_CheckConfig("l4dstats"))
    {
        char Error[256];
        db = SQL_Connect("l4dstats", true, Error, sizeof(Error));

        if (db == INVALID_HANDLE)
            LogError("Failed to connect to database: %s", Error);
        else
            SendSQLUpdate("SET NAMES 'utf8mb4'");
    }
    else
        LogError("Database.cfg missing 'l4dstats' entry!");
}
public void SendSQLUpdate(char []query)
{
    if (db == INVALID_HANDLE)
        return;

    SQL_TQuery(db, SQLErrorCheckCallback, query);
}
public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char []error, any data)
{
    if (db == INVALID_HANDLE)
        return;

    if(!StrEqual("", error))
        LogError("SQL Error: %s", error);
}
public void OnClientPostAdminCheck(int client)
{
	ClientMelee[client]=0;
	ClientBlood[client]=0;
	ClientHat[client]=0;
	GlowType[client]=0;
	ClientFirstBuy[client]=true;
	ClientPoints[client]=500;
	ClientSaveToFileLoad(client);
	CreateTimer(1.0, CheckPlayer,client);
}

public Action CheckPlayer(Handle timer, int client)
{
	/*
	bool change = false;
	if(ClientHat[client])
	{
		if(GetUserAdmin(client) == INVALID_ADMIN_ID || l4dstats_IsTopPlayer(client,30) == 0)
		{
			ClientHat[client] = 0;
			change = true;
		}
		
	}
	if(GlowType[client])
	{
		if(GetUserAdmin(client) == INVALID_ADMIN_ID || l4dstats_IsTopPlayer(client,10) == 0)
		{
			GlowType[client] = 0;
			change = true;
		}
	}
	if(change)	
		ClientSaveToFileSave(client);
	*/
	if(!IsValidClient(client))
		return;
	if(GlowType[client] || ClientHat[client])
		SetPlayer(client);
}

public void SetPlayer(int client)
{
	if(IsValidClient(client) && GetClientTeam( client ) == 2 )
	{
		
		if(GlowType[client])
			GetAura(client,GlowType[client]);
		if(ClientHat[client])
			ServerCommand("sm_hatclient #%d %d", GetClientUserId(client), ClientHat[client]);
		//PrintToConsole(client,"sm_hatclient #%d %d", GetClientUserId(client), ClientHat[client]);
	}
}

public int BypassAndExecuteCommand(int client, char []strCommand, char []strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~ FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

public Action Timer_AutoGive(Handle timer, any client)
{
	if (ClientMelee[client] == 1)
	{
		BypassAndExecuteCommand(client, "give", "machete");
	}
	if (ClientMelee[client] == 2)
	{
		BypassAndExecuteCommand(client, "give", "fireaxe");
	}
	if (ClientMelee[client] == 3)
	{
		BypassAndExecuteCommand(client, "give", "knife");
	}
	if (ClientMelee[client] == 4)
	{
		BypassAndExecuteCommand(client, "give", "katana");
	}
	if (ClientMelee[client] == 5)
	{
		BypassAndExecuteCommand(client, "give", "pistol_magnum");
	}
	if (ClientMelee[client] == 6)
	{
		BypassAndExecuteCommand(client, "give", "electric_guitar");
	}
	if (ClientMelee[client] == 7)
	{
		BypassAndExecuteCommand(client, "give", "tonfa");
	}
	if (ClientMelee[client] == 8)
	{
		BypassAndExecuteCommand(client, "give", "pitchfork");
	}
	if (ClientMelee[client] == 9)
	{
		BypassAndExecuteCommand(client, "give", "shovel");
	}
	if (ClientMelee[client] == 10)
	{
		BypassAndExecuteCommand(client, "give", "pistol");
	}
	if (ClientMelee[client] == 11)
	{
		BypassAndExecuteCommand(client, "give", "frying_pan");
	}
	if (ClientMelee[client] == 12)
	{
		BypassAndExecuteCommand(client, "give", "crowbar");
	}		
}
public void ClientMapChangeWithoutBuyReward(int Client,int RewordScore){
	if(!IsValidClient(Client))
		return;
	char query[255];
	char SteamID[64];
	GetClientAuthId(Client, AuthId_Steam2,SteamID, sizeof(SteamID));
	if(StrEqual(SteamID,"BOT"))return;
	Format(query, sizeof(query), "UPDATE players SET points=points+%d WHERE steamid = '%s'",RewordScore, SteamID);	
	SendSQLUpdate(query);
	return;
}
public void ClientSaveToFileLoad(int Client)
{
	if(!IsValidClient(Client)&&IsFakeClient(Client))
		return;
	char query[255];
	char SteamID[64];
	GetClientAuthId(Client, AuthId_Steam2,SteamID, sizeof(SteamID));
	if(StrEqual(SteamID,"BOT"))return;
	Format(query, sizeof(query), "SELECT MELEE_DATA,BLOOD_DATA,HAT,GLOW FROM RPG WHERE steamid = '%s'", SteamID);	
	SQL_TQuery(db, ShowMelee, query, Client);
	return;
}

public void ClientSaveToFileCreate(int Client)
{
	if(!IsValidClient(Client)&&IsFakeClient(Client))
	return;
	char query[255];
	char SteamID[64];
	GetClientAuthId(Client, AuthId_Steam2,SteamID, sizeof(SteamID));
	if(StrEqual(SteamID,"BOT"))return;
	Format(query, sizeof(query), "INSERT INTO RPG (steamid,MELEE_DATA,BLOOD_DATA,HAT,GLOW)  VALUES ('%s',%d,%d,%d,%d)",SteamID,ClientMelee[Client],ClientBlood[Client],0,0 );	
	SendSQLUpdate(query);
	return;
}

public void ClientSaveToFileSave(int Client)
{
	if(!IsValidClient(Client)&&IsFakeClient(Client))
		return;
	char query[255];
	char SteamID[64];
	GetClientAuthId(Client, AuthId_Steam2,SteamID, sizeof(SteamID));
	if(StrEqual(SteamID,"BOT"))return;
	Format(query, sizeof(query), "UPDATE RPG SET MELEE_DATA=%d,BLOOD_DATA=%d,HAT=%d,GLOW=%d WHERE steamid = '%s'",ClientMelee[Client],ClientBlood[Client], ClientHat[Client], GlowType[Client], SteamID);	
	SendSQLUpdate(query);
	return;
}

//开局发近战能力武器
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	for(int i=1;i<MaxClients;i++)
		if(IsSurvivor(i))
		{
			CreateTimer(0.5, Timer_AutoGive, i, TIMER_FLAG_NO_MAPCHANGE);
		}
	IsStart=true;
	valid=true;
	return Plugin_Stop;
}


public Action EventRoundStart(Handle event, const char []name, bool dontBroadcast)
{
	for(int i=1;i<MaxClients;i++){
		ClientPoints[i]=500;
	}
	//LogError("RoundStart");
}

//检查client合法
int IsVaildClient(int client)
{
	if( client > 0 ) return 1;
	if( client < 64 ) return 1;
	if( IsClientInGame(client) ) return 1;
	if( GetClientTeam(client) == 2 ) return 1;
	else
    {
        return 0;
    }
}

//输出rpg任务信息动作
public Action RpgInfo(int client,int args)
{
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{
    	PrintToConsole(client,"melee:%d blood:%d glow:%d hat:%d", ClientMelee[client],ClientBlood[client],GlowType[client],ClientHat[client]);
	}
}

//购买菜单指令动作
public Action BuyMenu(int client,int args)
{
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{
    	BuildMenu(client);
	}
}
//快速买子弹指令
public Action BuyAmmo(int client,int args)
{
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{
    	RemovePoints(client,0,"ammo");
    	PrintToChatAll("\x04%N \x03快速的补充了子弹",client);
	}
}

//快速买喷子指令
public Action BuyPen(int client,int args)
{ 
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{
		if(ClientFirstBuy[client]){
			ClientFirstBuy[client]=false;
			if(GetRandomInt(0,1))
				RemovePoints(client,0,"pumpshotgun");
			else
				RemovePoints(client,0,"shotgun_chrome");
			PrintToChatAll("\x04%N \x03第一次随机白嫖一把喷子",client);
		}else if(ClientPoints[client]>49)
		{
			if(GetRandomInt(0,1))
				RemovePoints(client,50,"pumpshotgun");
			else
				RemovePoints(client,50,"shotgun_chrome");
			PrintToChatAll("\x04%N \x03快速花费50B数随机购买一把单喷",client);
		}else{
			PrintToChat(client,"\x03没钱你买个屁喷子，心里没点B数");
		}
	}
}

//快速买二代单喷指令
public Action BuyChr(int client,int args)
{ 
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{
		if(ClientFirstBuy[client]){
			ClientFirstBuy[client]=false;
			RemovePoints(client,0,"shotgun_chrome");
			PrintToChatAll("\x04%N \x03第一次白嫖一把二代单喷",client);
		}else if(ClientPoints[client]>49)
		{
			RemovePoints(client,50,"shotgun_chrome");
			PrintToChatAll("\x04%N \x03快速花费50B数购买一把二代单喷",client);
		}else{
			PrintToChat(client,"\x03没钱你买个屁喷子，心里没点B数");
		}
	}
}

//快速买pump指令
public Action BuyPum(int client,int args)
{ 
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{
		if(ClientFirstBuy[client]){
			ClientFirstBuy[client]=false;
			RemovePoints(client,0,"pumpshotgun");
			PrintToChatAll("\x04%N \x03第一次白嫖一把一代单喷",client);
		}else if(ClientPoints[client]>49)
		{
			RemovePoints(client,50,"pumpshotgun");
			PrintToChatAll("\x04%N \x03快速花费50B数随机购买一把一代单喷",client);
		}else{
			PrintToChat(client,"\x03没钱你买个屁喷子，心里没点B数");
		}
	}
}

//快速买机枪指令
public Action BuySmg(int client,int args)
{ 
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{ 
		if(ClientFirstBuy[client]){
			ClientFirstBuy[client]=false;
			RemovePoints(client,0,"smg_silenced");
			PrintToChatAll("\x04%N \x03第一次白嫖一把消音smg机枪",client);
		}else if(ClientPoints[client]>49)
		{
			RemovePoints(client,50,"smg_silenced");
			PrintToChatAll("\x04%N \x03快速花费50B数购买一把消音smg机枪",client);
		}else{
			PrintToChat(client,"\x03没钱你买个屁机枪，心里没点B数");
		}
	}
}

//快速买uzi指令
public Action BuyUzi(int client,int args)
{ 
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{ 
		if(ClientFirstBuy[client]){
			ClientFirstBuy[client]=false;
			RemovePoints(client,0,"smg");
			PrintToChatAll("\x04%N \x03第一次白嫖一把Uzi",client);
		}else if(ClientPoints[client]>49)
		{
			RemovePoints(client,50,"smg");
			PrintToChatAll("\x04%N \x03快速花费50B数随机购买一把Uzi机枪",client);
		}else{
			PrintToChat(client,"\x03没钱你买个屁机枪，心里没点B数");
		}
	}
}

//快速买药指令
public Action BuyPill(int client,int args)
{ 
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{
		if(RemovePoints(client,400,"pain_pills"))
		PrintToChatAll("\x04%N \x03快速花费400B数买了瓶药",client);
	}
}
//分数操作
public bool RemovePoints(int client, int costpoints,char bitem[64])
{
	int actuallypoints = ClientPoints[client] - costpoints;
	if(IsVaildClient(client) && actuallypoints >= 0)
	{	
		GiveItems(client,bitem);
		ClientPoints[client]=ClientPoints[client] - costpoints;
		return true;
	}
	else
	{
		PrintToChat(client,"\x03你自己心里没有点B数吗?");
		return false;
	}

}
//数据库操作返回数据
public void ShowMelee(Handle owner, Handle hndl, const char []error, any data)
{
    int client = data;

    if (!client || hndl == INVALID_HANDLE&&IsFakeClient(client))
        return;

    if (SQL_FetchRow(hndl)){
        ClientMelee[client] = SQL_FetchInt(hndl, 0);
        ClientBlood[client] = SQL_FetchInt(hndl, 1);
        ClientHat[client] = SQL_FetchInt(hndl, 2);
        GlowType[client] = SQL_FetchInt(hndl, 3);
		//PrintToChat(client,"\x03返回的ClientMelee：%d",ClientMelee[client]);
		//PrintToChat(client,"\x03返回的ClientBlood：%d",ClientBlood[client]);
		}
		else{
			PrintToChat(client,"\x04新用户，正在创建数据库",ClientBlood[client]);
			ClientSaveToFileCreate(client);
		}
}
//实现给予物品
public void GiveItems(int client, char bitem[64])
{
	int flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", bitem);
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}

//检查通关后是不是钱都是满的
public bool CheckAllMoney(){
	for(int i=1;i<=MaxClients;i++)
	{
		if(IsValidClient(i)&&IsSurvivor(i)&&!IsFakeClient(i)&&ClientPoints[i]!=500){
			PrintToChatAll("\x04本回合使用了B数没有通关额外积分");
			return false;
		}

	}
	return true;	
}
//创建购买菜单>>主菜单
/*public void BuildMenu定义的是这个菜单的具体内容，包括标题，选项。
以下都是各个菜单的东西，不用修改。
*/
public void BuildMenu(int client)
{
	if( IsVaildClient(client) )
	{
		char binfo[255];
		Menu menu = new Menu(TopMenu);

		FormatEx(binfo, sizeof(binfo), "☆☆购物商店☆☆\n—————————\n当前B数：%d\n—————————",ClientPoints[client], client);	//玩家积分：
		menu.SetTitle(binfo);

		//FormatEx(binfo, sizeof(binfo),  "购买枪械", client);	//武器
		FormatEx(binfo, sizeof(binfo), "购买枪械", client);
		menu.AddItem("gun", binfo);

		FormatEx(binfo, sizeof(binfo),  "购买补给", client); //补给
		menu.AddItem("supply", binfo);

		FormatEx(binfo, sizeof(binfo),  "出门近战技能", client); //技能菜单
		menu.AddItem("ability", binfo);
		if (GetConVarBool(ReturnBlood)){
			FormatEx(binfo, sizeof(binfo),  "回血技能", client); //技能菜单
			menu.AddItem("Blood", binfo);
		}
		if(l4dstats_IsTopPlayer(client,30) || GetUserAdmin(client)!= INVALID_ADMIN_ID)
		{
			FormatEx(binfo, sizeof(binfo),  "帽子菜单", client); //帽子菜单
			menu.AddItem("Hat", binfo);
		}
		if(l4dstats_IsTopPlayer(client,10)|| GetUserAdmin(client)!= INVALID_ADMIN_ID)
		{
			FormatEx(binfo, sizeof(binfo),  "生还者轮廓", client); //生还者轮廓菜单
			menu.AddItem("Survivor_glow", binfo);
		}
		
		
		menu.Display(client, 20);

	}
}
/*public int TopMenu定义的是选择了某个选项之后的动作*/
public int TopMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char bitem[64];
			menu.GetItem(param2, bitem, sizeof(bitem));
			if( StrEqual(bitem, "gun") )
				gun(param1);
			else if( StrEqual(bitem, "supply") )
				supply(param1);
			else if( StrEqual(bitem, "ability") )
				ability(param1);
			else if( StrEqual(bitem, "Blood") )
				Blood(param1);
			else if( StrEqual(bitem, "Hat") )
				Hat(param1);
			else if( StrEqual(bitem, "Survivor_glow") )
				Survivor_glow(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}
//thanks "[L4D2] Glow Survivor" author King_OXO  url = "https://forums.alliedmods.net/showthread.php?t=332956"
//创建购买菜单>>主菜单--生还者轮廓菜单
public void Survivor_glow(int client)
{
	if( IsVaildClient(client) )
	{
		Menu menu = new Menu(VIPAuraMenuHandler);
		menu.SetTitle("生还者轮廓\n——————————");

	    menu.AddItem("option0", "关闭\n ", GlowType[client] == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option1", "绿色", GlowType[client] == 1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option2", "蓝色", GlowType[client] == 2 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option3", "藍紫色", GlowType[client] == 3 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option4", "青色", GlowType[client] == 4 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option5", "橘黄色", GlowType[client] == 5 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option6", "红色", GlowType[client] == 6 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option7", "灰色", GlowType[client] == 7 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option8", "黄色", GlowType[client] == 8 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option9", "酸橙色", GlowType[client] == 9 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option10", "栗色", GlowType[client] == 10 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option11", "藍綠色", GlowType[client] == 11 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option12", "粉红色", GlowType[client] == 12 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option13", "紫色", GlowType[client] == 13 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option14", "白色", GlowType[client] == 14 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    DumpAdminCache(AdminCache_Admins,true);
	    DumpAdminCache(AdminCache_Groups,true);
	    if(l4dstats_IsTopPlayer(client,3)|| GetUserAdmin(client).HasFlag(ADMFLAG_GENERIC))
	    	menu.AddItem("option15", "金黄色", GlowType[client] == 15 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    if(l4dstats_IsTopPlayer(client,1)|| GetUserAdmin(client).ImmunityLevel == 100)
	    	menu.AddItem("option16", "彩虹色", GlowType[client] == 16 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		
	    menu.ExitButton = true;
	    menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int VIPAuraMenuHandler(Menu menu, MenuAction action, int param1, int param2) 
{
    switch (action) 
    {
        case MenuAction_End:
            delete menu;
        case MenuAction_Select: 
        {
            GetAura(param1, param2);
            ClientSaveToFileSave(param1);
            //SetCookie(param1, cookie, param2);
			
            Survivor_glow( param1 );
        }
    }

    return 0;
}

void GetAura(int client, int id) 
{
    switch (id) 
    {
        case 0: 
        {    
            DisableGlow( client );
            GlowType[client] = id;
//          PrintToChat(client, "\x05你 have turned off the Glow");
            return;
        }
        case 1: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 0 + (255 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04绿色 \x01!");
        }
        case 2: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 7 + (19 * 256) + (250 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04蓝色 \x01!");
        }
        case 3: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 249 + (19 * 256) + (250 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04蓝紫色 \x01!");
        }
        case 4: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 66 + (250 * 256) + (250 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04青色 \x01!");
        }
        case 5: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 249 + (155 * 256) + (84 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04橘黄色 \x01!");
        }
        case 6: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 255 + (0 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04红色 \x01!");
        }
        case 7: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 50 + (50 * 256) + (50 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04灰色 \x01!");
        }
        case 8: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 255 + (255 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04黄色 \x01!");
        }
        case 9: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 128 + (255 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04酸橙色 \x01!");
        }
        case 10: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 128 + (0 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04栗色 \x01!");
        }
        case 11: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 0 + (128 * 256) + (128 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04藍綠色 \x01!");
        }
        case 12:
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 255 + (0 * 256) + (150 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04粉红色 \x01!");
        }
        case 13:
        {        
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 155 + (0 * 256) + (255 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04紫色 \x01!");
        }
        case 14: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", -1 + (-1 * 256) + (-1 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04白色 \x01!");
        }
        case 15: 
        {
            SetEntProp(client, Prop_Send, "m_glowColorOverride", 255 + (155 * 256) + (0 * 65536));
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04金黄色 \x01!");
        }
        case 16: 
        {
            SDKHook(client, SDKHook_PreThink, RainbowPlayer);
            CPrintToChat(client, "\x05你 \x04将轮廓颜色改为\x01: \x04彩虹色 \x01!");
        }
    }

    if (0 <= id <= 15) 
    {
        SetEntProp(client, Prop_Send, "m_iGlowType", 3);
        SetEntProp(client, Prop_Send, "m_nGlowRange", 99999);
        SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 0);
		
        SDKUnhook(client, SDKHook_PreThink, RainbowPlayer);
    }
    
    GlowType[client] = id;
    
}

void DisableGlow( int client )
{
	if( IsValidClient( client ))
	{		
		SetEntProp( client, Prop_Send, "m_iGlowType", 0 );
		SetEntProp( client, Prop_Send, "m_bFlashing", 0 );
		SetEntProp( client, Prop_Send, "m_nGlowRange",0 );
		SetEntProp( client, Prop_Send, "m_glowColorOverride", 0 );
		
		SDKUnhook( client, SDKHook_PreThink, RainbowPlayer );
	}
}

public Action RainbowPlayer(int client)
{
	if( IsValidClient( client ) != true || IsPlayerAlive(client) != true || GetClientTeam( client ) == 3 )
	{
		SDKUnhook(client, SDKHook_PreThink, RainbowPlayer);
		
		if( GetClientTeam( client ) == 3 )
		{
			SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
			SetEntProp(client, Prop_Send, "m_iGlowType", 0);
		}
		
		return;
	}
    
	SetEntProp(client, Prop_Send, "m_glowColorOverride", RoundToNearest(Cosine((GetGameTime() * 8.0) + client + 1) * 127.5 + 127.5) + (RoundToNearest(Cosine((GetGameTime() * 8.0) + client + 3) * 127.5 + 127.5) * 256) + (RoundToNearest(Cosine((GetGameTime() * 8.0) + client + 5) * 127.5 + 127.5) * 65536));
	SetEntProp(client, Prop_Send, "m_iGlowType", 3);
	SetEntProp(client, Prop_Send, "m_nGlowRange", 99999);
	SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 0);
}


//创建购买菜单>>主菜单--帽子菜单
public void Hat(int client)
{
	ClientCommand(client,"sm_hats");	
}

//创建购买菜单>>主菜单--主武器类型
public void gun(int client)
{
	if( IsVaildClient(client) )
	{
		char binfo[64];
		Menu menu = new Menu(gun_back);
		menu.SetTitle("当前B数：%i \n——————————",ClientPoints[client]);
		
		FormatEx(binfo, sizeof(binfo),  "子弹 %dB数",CostAmmo, client);
		menu.AddItem("ammo", binfo);
		
		if(ClientFirstBuy[client]){
			FormatEx(binfo, sizeof(binfo), "马格南 %dB数",0, client);
			menu.AddItem("pistol_magnum", binfo);
			FormatEx(binfo, sizeof(binfo), "Uzi %dB数",0, client);
			menu.AddItem("smg", binfo);

			FormatEx(binfo, sizeof(binfo), "消音smg %dB数",0,client);
			menu.AddItem("smg_silenced", binfo);
		
			FormatEx(binfo, sizeof(binfo), "一代单发霰弹枪 %dB数",0, client);
			menu.AddItem("pumpshotgun", binfo);

			FormatEx(binfo, sizeof(binfo), "二代单发霰弹枪 %dB数",0, client);
			menu.AddItem("shotgun_chrome", binfo);
			
			FormatEx(binfo, sizeof(binfo), "普通小手枪 %dB数",0, client);
			menu.AddItem("pistol", binfo);
		}else{
			FormatEx(binfo, sizeof(binfo), "马格南 %dB数",CostMagnum, client);
			menu.AddItem("pistol_magnum", binfo);
			FormatEx(binfo, sizeof(binfo),  "Uzi %dB数",CostUzi, client);
			menu.AddItem("smg", binfo);

			FormatEx(binfo, sizeof(binfo), "消音smg %dB数",CostSilenced,client);
			menu.AddItem("smg_silenced", binfo);
		
			FormatEx(binfo, sizeof(binfo),  "一代单发霰弹枪 %dB数",CostPumpShotgun, client);
			menu.AddItem("pumpshotgun", binfo);

			FormatEx(binfo, sizeof(binfo),  "二代单发霰弹枪 %dB数",CostPumpShotgun, client);
			menu.AddItem("shotgun_chrome", binfo);
			
			FormatEx(binfo, sizeof(binfo),"普通小手枪 %dB数",CostP220, client);
			menu.AddItem("pistol", binfo);
		}
		
		FormatEx(binfo, sizeof(binfo),  "mp5机枪 %dB数",CostMP5, client);
		menu.AddItem("smg_mp5", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "一代连发霰弹枪 %dB数",CostAuto, client);
		menu.AddItem("autoshotgun", binfo);

		FormatEx(binfo, sizeof(binfo),  "二代连发霰弹枪 %dB数",CostAuto, client);
		menu.AddItem("shotgun_spas", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "m16步枪 %dB数",CostM16, client);
		menu.AddItem("rifle", binfo);

		FormatEx(binfo, sizeof(binfo),  "ak47步枪 %dB数",CostAK47, client);
		menu.AddItem("rifle_ak47", binfo);

		FormatEx(binfo, sizeof(binfo),  "sg552步枪 %dB数",CostSG552, client);
		menu.AddItem("rifle_sg552", binfo);

		FormatEx(binfo, sizeof(binfo),  "scar步枪 %dB数",CostSCAR, client);
		menu.AddItem("rifle_desert", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "一代连狙 %dB数",CostHunting, client);
		menu.AddItem("hunting_rifle", binfo);

		FormatEx(binfo, sizeof(binfo),  "二代连狙 %dB数",CostMilitary, client);
		menu.AddItem("sniper_military", binfo);

		FormatEx(binfo, sizeof(binfo),  "鸟狙 %dB数",CostScout, client);
		menu.AddItem("sniper_scout", binfo);

		FormatEx(binfo, sizeof(binfo),  "AWP狙击枪 %dB数",CostAWP, client);
		menu.AddItem("sniper_awp", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "m60 %dB数",CostM60, client);
		menu.AddItem("rifle_m60", binfo);

		FormatEx(binfo, sizeof(binfo),  "榴弹发射器 %dB数",CostGrenadeLuanch, client);
		menu.AddItem("grenade_launcher", binfo);
		
		menu.Display(client, 20);
	}
}



public int gun_back(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char bitem[64];
			menu.GetItem(param2, bitem, sizeof(bitem));
			if( StrEqual(bitem, "smg") )
			{
				int costpoints = CostUzi;
				if(ClientFirstBuy[param1]){
					ClientFirstBuy[param1]=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"Uzi",ClientPoints[param1]);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostUzi,"Uzi",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "smg_silenced") )
			{
				
				int costpoints = CostSilenced;
				if(ClientFirstBuy[param1]){
					ClientFirstBuy[param1]=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"消音smg",ClientPoints[param1]);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostSilenced,"消音smg",ClientPoints[param1]);
			}				
			else if( StrEqual(bitem, "smg_mp5") )
			{
				
				int costpoints = CostMP5;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostMP5,"mp5",ClientPoints[param1]);
			}	
			else if( StrEqual(bitem, "rifle") ){
				//
				int costpoints = CostM16;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostM16,"m16步枪",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "rifle_ak47") ){
				int costpoints = CostAK47;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostAK47,"ak47步枪",ClientPoints[param1]);
			}
				
			else if( StrEqual(bitem, "rifle_sg552") ){
				int costpoints = CostSG552;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostSG552,"sg552步枪",ClientPoints[param1]);
			}
				
			else if( StrEqual(bitem, "rifle_desert") ){
				int costpoints = CostSCAR;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostSCAR,"scar步枪",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "pumpshotgun") ){
				int costpoints = CostPumpShotgun;
				
				if(ClientFirstBuy[param1]){
					ClientFirstBuy[param1]=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"一代单喷",ClientPoints[param1]);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostPumpShotgun,"一代单喷",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "shotgun_chrome") ){
				int costpoints = CostChromeShotgun;
				if(ClientFirstBuy[param1]){
					ClientFirstBuy[param1]=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"二代单喷",ClientPoints[param1]);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostChromeShotgun,"二代单喷",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "autoshotgun") ){
				int costpoints = CostAuto;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostAuto,"一代连喷",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "shotgun_spas") ){
				int costpoints = CostSPAS;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostSPAS,"二代连喷",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "hunting_rifle") ){
				int costpoints = CostHunting;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostHunting,"一代连狙",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "sniper_military") ){
				int costpoints = CostMilitary;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostMilitary,"二代连狙",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "sniper_scout") ){
				int costpoints = CostScout;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostScout,"鸟狙",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "sniper_awp") ){
				int costpoints = CostAWP;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostAWP,"AWP狙击枪",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "rifle_m60") ){
				int costpoints = CostM60;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostM60,"m60",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "grenade_launcher") ){
				int costpoints = CostGrenadeLuanch;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostGrenadeLuanch,"榴弹发射器",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "pistol") ){			
				int costpoints = CostP220;
				if(ClientFirstBuy[param1]){
					ClientFirstBuy[param1]=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"小手枪",ClientPoints[param1]);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostP220,"小手枪",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "pistol_magnum") ){
				
				int costpoints = CostMagnum;
				if(ClientFirstBuy[param1]){
					ClientFirstBuy[param1]=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"马格南",ClientPoints[param1]);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostMagnum,"马格南",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "ammo") ){
				int costpoints = CostAmmo;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03免费补充了子弹",param1,CostAmmo,"子弹",ClientPoints[param1]);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}


//创建购买菜单>>主菜单--医疗物品/药品
public void supply(int client)
{
	if( IsVaildClient(client) )
	{
		char binfo[64];
		Menu menu = new Menu(supply_back);
		menu.SetTitle("医疗物品\n——————————");

		FormatEx(binfo, sizeof(binfo),  "药丸 %dB数",CostPills, client);
		menu.AddItem("pain_pills", binfo);

		FormatEx(binfo, sizeof(binfo),  "肾上腺素 %dB数",CostAdren, client);
		menu.AddItem("adrenaline", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "医疗包 %dB数",CostFirstAidKit,client);
		menu.AddItem("first_aid_kit", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "油桶 %dB数",CostGascan, client);
		menu.AddItem("gascan", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "治疗小侏儒 %dB数",CostGnome, client);
		menu.AddItem("weapon_gnome", binfo);

		menu.Display(client, 20);
	}
}
public int supply_back(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char bitem[64];
			menu.GetItem(param2, bitem, sizeof(bitem));
			if( StrEqual(bitem, "first_aid_kit") ){				
				int costpoints = CostFirstAidKit;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostFirstAidKit,"医疗包",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "pain_pills") ){				
				int costpoints = CostPills;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostPills,"药丸",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "adrenaline") ){				
				int costpoints = CostAdren;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostAdren,"肾上腺素",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "gascan") ){
				
				int costpoints = CostGascan;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostGascan,"油桶",ClientPoints[param1]);
			}
			else if( StrEqual(bitem, "weapon_gnome") ){
				
				int costpoints = CostGnome;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostGnome,"治疗小侏儒",ClientPoints[param1]);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}
//创建购买菜单>>主菜单--技能界面
public void ability(int client)
{
	if( IsVaildClient(client) )
	{
		char binfo[64];
		Menu menu = new Menu(ability_back);
		menu.SetTitle("选择出门近战,当前为%d\n——————————",ClientMelee[client]);
		
		FormatEx(binfo, sizeof(binfo),  "砍刀", client);
		menu.AddItem("machete", binfo);

		FormatEx(binfo, sizeof(binfo),  "消防斧", client);
		menu.AddItem("fireaxe", binfo);

		FormatEx(binfo, sizeof(binfo),  "小刀", client);
		menu.AddItem("knife", binfo);

		FormatEx(binfo, sizeof(binfo),  "武士刀", client);
		menu.AddItem("katana", binfo);

		FormatEx(binfo, sizeof(binfo),  "马格南", client);
		menu.AddItem("pistol_magnum", binfo);

		FormatEx(binfo, sizeof(binfo),  "电吉他", client);
		menu.AddItem("electric_guitar", binfo);

		FormatEx(binfo, sizeof(binfo),  "警棍", client);
		menu.AddItem("tonfa", binfo);

		FormatEx(binfo, sizeof(binfo),  "草叉", client);
		menu.AddItem("pitchfork", binfo);

		FormatEx(binfo, sizeof(binfo),  "铲子", client);
		menu.AddItem("shovel", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "普通小手枪", client);
		menu.AddItem("pistol", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "平底锅", client);
		menu.AddItem("frying_pan", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "撬棍", client);
		menu.AddItem("crowbar", binfo);
		
		menu.Display(client, 20);
	}
}
public int ability_back(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char bitem[64];
			menu.GetItem(param2, bitem, sizeof(bitem));
			if( StrEqual(bitem, "machete") ){		
				ClientMelee[param1]=1;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为砍刀");
			}
			else if( StrEqual(bitem, "fireaxe") ){
				ClientMelee[param1]=2;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为消防斧");
			}
			else if( StrEqual(bitem, "knife") ){
				ClientMelee[param1]=3;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为小刀");
			}
			else if( StrEqual(bitem, "katana") ){
				ClientMelee[param1]=4;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为武士刀");
			}
			else if( StrEqual(bitem, "pistol_magnum") ){
				ClientMelee[param1]=5;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为马格南");
			}
			else if( StrEqual(bitem, "electric_guitar") ){
				ClientMelee[param1]=6;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为电吉他");
			}
			else if( StrEqual(bitem, "tonfa") ){
				ClientMelee[param1]=7;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为警棍");
			}
			else if( StrEqual(bitem, "pitchfork") ){
				ClientMelee[param1]=8;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为草叉");
			}
			else if( StrEqual(bitem, "shovel") ){
				ClientMelee[param1]=9;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为铲子");
			}
			else if( StrEqual(bitem, "pistol") ){
				ClientMelee[param1]=10;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为小手枪");
			}else if( StrEqual(bitem, "frying_pan") ){
				ClientMelee[param1]=11;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为平底锅");
			}else if( StrEqual(bitem, "crowbar") ){
				ClientMelee[param1]=12;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为撬棍");
			}else{
				PrintToChat(param1,"\x03您的出门近战武器设置失败，超出限制");
			}
		}
		case MenuAction_End:
			delete menu;
	}
}
//创建购买菜单>>主菜单--技能界面
public void Blood(int client)
{
	if( IsVaildClient(client) )
	{
		char binfo[64];
		Menu menu = new Menu(Blood_back);
		if(ClientBlood[client])
			menu.SetTitle("是否开启杀特回血,当前状态：是\n——————————");
		else
			menu.SetTitle("是否开启杀特回血,当前状态：否\n——————————");
		FormatEx(binfo, sizeof(binfo),  "是", client);
		menu.AddItem("Yes", binfo);

		FormatEx(binfo, sizeof(binfo),  "否", client);
		menu.AddItem("No", binfo);
		menu.Display(client, 20);
	}
}
public int Blood_back(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char bitem[64];
			menu.GetItem(param2, bitem, sizeof(bitem));
			if( StrEqual(bitem, "Yes") ){
				
				ClientBlood[param1]=1;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04你已经开启了杀特回血，杀一只特感回2滴血，不超过血量上限");
			}
			else {				
				ClientBlood[param1]=0;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04你已经关闭了杀特回血.");
			}
		}
		case MenuAction_End:
			delete menu;
	}
}