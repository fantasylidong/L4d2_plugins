#pragma newdecls required
/**/
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4dstats>
#include <colors>
#include <l4d_hats>
#include <hextags>

#define PLUGIN_VERSION "1.0.0"
#define MAX_LINE_WIDTH 64

// 进行 MySQL 连接相关变量
Handle db = INVALID_HANDLE;
enum struct PlayerStruct{
	int ClientPoints;
	int ClientBlood;
	int ClientMelee;
	int ClientHat;
	int GlowType;
	bool ClientFirstBuy;
	bool Check;
	bool CanBuy;
	CustomTags tags;
}
PlayerStruct player[MAXPLAYERS + 1];
bool IsAllowBigGun = false;

ConVar
	AllowBigGun;

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

//插件开始
public Plugin myinfo =
{
	name = "商店插件",
	author = "东",
	description = "购买游戏道具,幸存者轮廓，帽子保存",
	version = PLUGIN_VERSION,
	url = "http://sb.trygek.com:18443"
}
/*
//Startup
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//API
	RegPluginLibrary("rpg");
	CreateNative("rpg_HaveOwnTags", Native_HaveOwnTags);
}

//API
public int Native_HaveOwnTags(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return IsNullString(player[client].tags.ChatTag);
}
*/
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
	player[client].ClientHat = index;
	ClientSaveToFileSave(client);
}


public Action L4D_OnHatLoadSave(int client, int &index, bool load)
{
	//PrintToConsoleAll("index:%d load:%d",index,load);
	//LogError("index:%d load:%d",index,load);
	if(load)
	{
		if(player[client].ClientHat == 0)
			return Plugin_Continue;
		else
		{
			index = player[client].ClientHat;
			return Plugin_Changed;
		}
	}
	else
	{
		if(index == 0)
			return Plugin_Continue;
		else
		{
			player[client].ClientHat = index;
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
				player[i].ClientFirstBuy=true;
				player[i].CanBuy=true;
				player[i].ClientPoints=500;
			}
		else
			player[i].ClientPoints=0;
	}
}

public void  OnPluginStart()
{
//	LoadTranslations("menu_shop.phrases.txt");
	HookEvent("round_start",EventRoundStart);
	HookEvent("player_spawn", 	Event_Player_Spawn);
	HookEvent("mission_lost",EventMissionLost);
	HookEvent("map_transition", EventMapChange);
	HookEvent("player_afk", 	Event_PlayerAFK);
	//HookEvent("player_team", 	Event_PlayerTeam, EventHookMode_Pre);
	RegConsoleCmd("sm_buy", BuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_ammo", BuyAmmo, "快速买子弹");
	RegConsoleCmd("sm_pen", BuyPen, "快速随机买一把单喷");
	RegConsoleCmd("sm_chr", BuyChr, "快速买一把二代单喷");
	RegConsoleCmd("sm_pum", BuyPum, "快速买一把一代单喷");
	RegConsoleCmd("sm_smg", BuySmg, "快速买smg");
	RegConsoleCmd("sm_uzi", BuyUzi, "快速买uzi");
	RegConsoleCmd("sm_pill", BuyPill, "快速买药");
	RegConsoleCmd("sm_setch", SetCH, "设置自定义称号");
	RegConsoleCmd("sm_applytags", ApplyTags, "佩戴自定义称号");
	RegConsoleCmd("sm_rpg", BuyMenu, "打开购买菜单(只能在游戏中)");
	RegAdminCmd("sm_rpginfo", RpgInfo, ADMFLAG_ROOT ,"输出rpg人物信息");
	AllowBigGun = CreateConVar("rpg_allow_biggun", "0", "商店是否允许购买大枪", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AllowBigGun.AddChangeHook(ConVarChanged_Cvars);
	for(int i=1;i<MaxClients;i++){
			player[i].ClientPoints=500;
			player[i].ClientFirstBuy=true;
			player[i].CanBuy=true;
	}
}

// *********************
//		获取Cvar值
// *********************
void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(AllowBigGun.IntValue)
		IsAllowBigGun = true;
	else
		IsAllowBigGun = false;
}

public void OnConfigsExecuted()
{

	// Init MySQL connections
	if (!ConnectDB())
	{
		SetFailState("Connecting to database failed. Read error log for further details.");
		return;
	}
}



public void Event_PlayerAFK( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	DisableGlow( GetClientOfUserId( hEvent.GetInt("userid")) );
}

public void Event_Player_Spawn(Event hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId( hEvent.GetInt( "userid" ));
	if( client && IsClientInGame( client ) && !player[client].Check){
		player[client].Check = true;
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
		if(player[client].GlowType)
			GetAura(client,player[client].GlowType);
		if(player[client].ClientHat)
			ServerCommand("sm_hatclient #%d %d", GetClientUserId(client), player[client].ClientHat);
	}
	else if( GetClientTeam( client ) == 3 )
	{
		DisableGlow( client );
	}
	player[client].Check = false;
}

public void Event_PlayerTeam(Event hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId (hEvent.GetInt("userid"));
	int iTeam = hEvent.GetInt("team");
	if( iTeam == 2 )
	{
		if(player[client].GlowType)
			GetAura(client,player[client].GlowType);
		if(player[client].ClientHat)
			ServerCommand("sm_hatclient #%d %d", GetClientUserId(client), player[client].ClientHat);
		//PrintToConsole(client,"sm_hatclient #%d %d", GetClientUserId(client), player[client].ClientHat-1);
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
	for(int i=1;i<MaxClients;i++){
		player[i].ClientPoints=500;
		player[i].ClientFirstBuy=true;
		player[i].CanBuy=true;
	}
}



public Action EventMissionLost(Handle event, const char []name, bool dontBroadcast){
	for(int i=1;i<MaxClients;i++){
				player[i].ClientPoints=500;
				player[i].ClientFirstBuy=true;
				player[i].CanBuy=true;
	}
}



public bool ConnectDB()
{
	if (db != INVALID_HANDLE)
		return true;

	if (SQL_CheckConfig("l4dstats"))
	{
		char Error[256];
		db = SQL_Connect("l4dstats", true, Error, sizeof(Error));

		if (db == INVALID_HANDLE)
		{
			LogError("Failed to connect to database: %s", Error);
			CloseHandle(db);
			return false;
		}
		else if (!SQL_SetCharset(db,"utf8mb4"))
		{
			if (SQL_GetError(db, Error, sizeof(Error)))
				LogError("Failed to update encoding to utf8mb4: %s", Error);
			else
				LogError("Failed to update encoding to utf8mb4: unknown");
			CloseHandle(db);
		}

	}
	else
	{
		LogError("Databases.cfg missing '%s' entry!", "l4dstats");
		CloseHandle(db);
		return false;
	}

	return true;
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
	if(!IsValidClient(client) || IsFakeClient(client))
		return;
	player[client].ClientMelee = 0;
	player[client].ClientBlood = 0;
	player[client].ClientHat = 0;
	player[client].GlowType = 0;
	player[client].ClientFirstBuy = true;
	player[client].CanBuy=true;
	player[client].ClientPoints = 500;
	player[client].Check = false;
	ClientSaveToFileLoad(client);
	CreateTimer(3.0, CheckPlayer, client);
	CreateTimer(10.0, SetClientTag, client);
}

public Action SetClientTag(Handle timer, int client)
{
	if(!IsValidClient(client) || IsFakeClient(client))
		return;
	if(player[client].tags.ChatTag[0] != '\0')
	{
		SetTags(client,player[client].tags.ChatTag);
		//LogError("称号名字：%s",player[client].tags.ChatTag);
	}
}

public Action CheckPlayer(Handle timer, int client)
{
	if(!IsValidClient(client))
		return;
	/*
	bool change = false;
	DumpAdminCache(AdminCache_Admins,true);
	DumpAdminCache(AdminCache_Groups,true);
	if(player[client].ClientHat)
	{
		if(GetUserAdmin(client) != INVALID_ADMIN_ID || l4dstats_IsTopPlayer(client,50) )
		{
		}
		else
		{
			player[client].ClientHat = 0;
			change = true;
		}
		
	}
	if(player[client].GlowType)
	{
		if(GetUserAdmin(client) != INVALID_ADMIN_ID || l4dstats_IsTopPlayer(client,20) )
		{
			
		}
		else
		{
			player[client].GlowType = 0;
			change = true;
		}
	}
	if(change)	
		ClientSaveToFileSave(client);
	*/
	if(player[client].GlowType || player[client].ClientHat)
		SetPlayer(client);
}

public void SetPlayer(int client)
{
	if(IsValidClient(client) && GetClientTeam( client ) == 2 )
	{
		
		if(player[client].GlowType)
			GetAura(client,player[client].GlowType);
		if(player[client].ClientHat)
			ServerCommand("sm_hatclient #%d %d", GetClientUserId(client), player[client].ClientHat);
			
		//PrintToConsole(client,"sm_hatclient #%d %d", GetClientUserId(client), player[client].ClientHat);
		
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
	if (player[client].ClientMelee == 1)
	{
		BypassAndExecuteCommand(client, "give", "machete");
	}
	if (player[client].ClientMelee == 2)
	{
		BypassAndExecuteCommand(client, "give", "fireaxe");
	}
	if (player[client].ClientMelee == 3)
	{
		BypassAndExecuteCommand(client, "give", "knife");
	}
	if (player[client].ClientMelee == 4)
	{
		BypassAndExecuteCommand(client, "give", "katana");
	}
	if (player[client].ClientMelee == 5)
	{
		BypassAndExecuteCommand(client, "give", "pistol_magnum");
	}
	if (player[client].ClientMelee == 6)
	{
		BypassAndExecuteCommand(client, "give", "electric_guitar");
	}
	if (player[client].ClientMelee == 7)
	{
		BypassAndExecuteCommand(client, "give", "tonfa");
	}
	if (player[client].ClientMelee == 8)
	{
		BypassAndExecuteCommand(client, "give", "pitchfork");
	}
	if (player[client].ClientMelee == 9)
	{
		BypassAndExecuteCommand(client, "give", "shovel");
	}
	if (player[client].ClientMelee == 10)
	{
		BypassAndExecuteCommand(client, "give", "pistol");
	}
	if (player[client].ClientMelee == 11)
	{
		BypassAndExecuteCommand(client, "give", "frying_pan");
	}
	if (player[client].ClientMelee == 12)
	{
		BypassAndExecuteCommand(client, "give", "crowbar");
	}		
}
public void ClientMapChangeWithoutBuyReward(int Client,int RewordScore){
	if(!IsValidClient(Client) || IsFakeClient(Client))
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
	if(!IsValidClient(Client) || IsFakeClient(Client))
		return;
	char query[255];
	char SteamID[64];
	GetClientAuthId(Client, AuthId_Steam2,SteamID, sizeof(SteamID));
	if(StrEqual(SteamID,"BOT"))return;
	Format(query, sizeof(query), "SELECT MELEE_DATA,BLOOD_DATA,HAT,GLOW,CHATTAG FROM RPG WHERE steamid = '%s'", SteamID);	
	SQL_TQuery(db, ShowMelee, query, Client);
	return;
}

public void ClientSaveToFileCreate(int Client)
{
	if(!IsValidClient(Client) || IsFakeClient(Client))
	return;
	char query[255];
	char SteamID[64];
	GetClientAuthId(Client, AuthId_Steam2,SteamID, sizeof(SteamID));
	if(StrEqual(SteamID,"BOT"))return;
	Format(query, sizeof(query), "INSERT INTO RPG (steamid,MELEE_DATA,BLOOD_DATA,HAT,GLOW)  VALUES ('%s',%d,%d,%d,%d)",SteamID,player[Client].ClientMelee,player[Client].ClientBlood,0 );	
	SendSQLUpdate(query);
	return;
}

public void ClientSaveToFileSave(int Client)
{
	if(!IsValidClient(Client) || IsFakeClient(Client))
		return;
	char query[255];
	char SteamID[64];
	GetClientAuthId(Client, AuthId_Steam2,SteamID, sizeof(SteamID));
	if(StrEqual(SteamID,"BOT"))return;
	Format(query, sizeof(query), "UPDATE RPG SET MELEE_DATA=%d,BLOOD_DATA=%d,HAT=%d,GLOW=%d WHERE steamid = '%s'",player[Client].ClientMelee,player[Client].ClientBlood, player[Client].ClientHat, player[Client].GlowType, SteamID);	
	SendSQLUpdate(query);
	return;
}

public void ClientTagsSaveToFileSave(int Client)
{
	if(!IsValidClient(Client) || IsFakeClient(Client))
		return;
	char query[255];
	char SteamID[64];
	GetClientAuthId(Client, AuthId_Steam2,SteamID, sizeof(SteamID));
	if(StrEqual(SteamID,"BOT"))return;
	CPrintToChat(Client,"\x04你的称号更新成功，新称号为：\x03%s",player[Client].tags.ChatTag);
	Format(query, sizeof(query), "UPDATE RPG SET CHATTAG='%s' WHERE steamid = '%s'",player[Client].tags.ChatTag, SteamID);	
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
	return Plugin_Stop;
}


public Action EventRoundStart(Handle event, const char []name, bool dontBroadcast)
{
	for(int i=1;i<MaxClients;i++){
		player[i].ClientPoints=500;
	}
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
    	PrintToConsole(client,"melee:%d blood:%d glow:%d hat:%d", player[client].ClientMelee,player[client].ClientBlood,player[client].GlowType,player[client].ClientHat);
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
    	GiveItems(client,"ammo");
    	PrintToChatAll("\x04%N \x03 补充了子弹",client);
	}
}

//快速买喷子指令
public Action BuyPen(int client,int args)
{ 
	if(IsVaildClient(client) && IsPlayerAlive(client)  )
	{
		if(player[client].ClientFirstBuy){
			player[client].ClientFirstBuy=false;
			bool result = false;
			if(GetRandomInt(0,1))
				result = RemovePoints(client,0,"pumpshotgun");
			else
				result = RemovePoints(client,0,"shotgun_chrome");
			if(result)
			PrintToChatAll("\x04%N \x03第一次随机白嫖一把喷子",client);
		}else if(player[client].ClientPoints>49)
		{
			bool result = false;
			if(GetRandomInt(0,1))
				result = RemovePoints(client,0,"pumpshotgun");
			else
				result = RemovePoints(client,0,"shotgun_chrome");
			if(result)
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
		if(player[client].ClientFirstBuy){
			player[client].ClientFirstBuy=false;
			if(RemovePoints(client,0,"shotgun_chrome"))
			PrintToChatAll("\x04%N \x03第一次白嫖一把二代单喷",client);
		}else if(player[client].ClientPoints>49)
		{
			if(RemovePoints(client,50,"shotgun_chrome"))
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
		if(player[client].ClientFirstBuy){
			player[client].ClientFirstBuy=false;
			if(RemovePoints(client,0,"pumpshotgun"))
			PrintToChatAll("\x04%N \x03第一次白嫖一把一代单喷",client);
		}else if(player[client].ClientPoints>49)
		{
			if(RemovePoints(client,50,"pumpshotgun"))
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
		if(player[client].ClientFirstBuy){
			player[client].ClientFirstBuy=false;
			if(RemovePoints(client,0,"smg_silenced"))
			PrintToChatAll("\x04%N \x03第一次白嫖一把消音smg机枪",client);
		}else if(player[client].ClientPoints>49)
		{
			if(RemovePoints(client,50,"smg_silenced"))
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
		if(player[client].ClientFirstBuy){
			player[client].ClientFirstBuy=false;
			if(RemovePoints(client,0,"smg"))
			PrintToChatAll("\x04%N \x03第一次白嫖一把Uzi",client);
		}else if(player[client].ClientPoints>49)
		{
			if(RemovePoints(client,50,"smg"))
			PrintToChatAll("\x04%N \x03快速花费50B数随机购买一把Uzi机枪",client);
		}else{
			PrintToChat(client,"\x03没钱你买个屁机枪，心里没点B数");
		}
	}
}

//佩戴自定义称号
public Action ApplyTags(int client,int args)
{
	if(player[client].tags.ChatTag[0] != '\0')
		SetTags(client,player[client].tags.ChatTag);
	else
		CPrintToChat(client,"\x04你必须先用\x03!setch \"你想要的称号名字\" \x04设置好你的自定义称号");
}

//设置称号指令
public Action SetCH(int client,int args)
{ 
	if(l4dstats_GetClientScore(client) < 500000)
	{
		ReplyToCommand(client,"你得积分小于50w，不能自定义称号");
		return Plugin_Handled;
	}
	if(args!=1){
		ReplyToCommand(client,"\x03错误参数，使用方式为!setch \"你想要的称号名字\"");
		return Plugin_Handled;
	}
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		ReplyToCommand(client,"\x03错误index");
		return Plugin_Handled;
	}
    GetCmdArg(1, player[client].tags.ChatTag, 24);
    
    if(IsNullString(player[client].tags.ChatTag) || strlen(player[client].tags.ChatTag) == 0 || player[client].tags.ChatTag[0] == '\0')
    {
    	ReplyToCommand(client,"\x03错误名字长度");
    	return Plugin_Handled;
    }
    
    SetTags(client,player[client].tags.ChatTag);
    /*
    char temp[32];
    Format(temp,sizeof(temp),"<%s>",player[client].tags.ChatTag);
    HexTags_SetClientTag(client, ScoreTag, temp);
    Format(temp,sizeof(temp),"{green}<%s>",player[client].tags.ChatTag);
	HexTags_SetClientTag(client, ChatTag, temp);
    HexTags_SetClientTag(client, ChatColor, "{teamcolor}");
    HexTags_SetClientTag(client, NameColor, "{lightgreen}");
    */
    ClientTagsSaveToFileSave(client);
	return Plugin_Handled;
}

public void SetTags(int client, char[] tagsname)
{
	char temp[32];
    Format(temp,sizeof(temp),"<%s>", tagsname);
    HexTags_SetClientTag(client, ScoreTag, temp);
    Format(temp,sizeof(temp),"{green}<%s>", tagsname);
	HexTags_SetClientTag(client, ChatTag, temp);
    HexTags_SetClientTag(client, ChatColor, "{teamcolor}");
    HexTags_SetClientTag(client, NameColor, "{lightgreen}");
    //ClientSaveToFileSave(client);
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

public Action ResetBuy(Handle timer, int client)
{
	player[client].CanBuy = true;
}

//分数操作
public bool RemovePoints(int client, int costpoints,char bitem[64])
{
	if(!player[client].CanBuy)
	{
		PrintToChat(client,"\x03商店技能冷却中(冷却时间15s)");
		return false;
	}
	int actuallypoints = player[client].ClientPoints - costpoints;
	if(IsVaildClient(client) && actuallypoints >= 0)
	{	
		GiveItems(client,bitem);
		player[client].ClientPoints=player[client].ClientPoints - costpoints;
		player[client].CanBuy = false;
		CreateTimer(15.0, ResetBuy, client, TIMER_FLAG_NO_MAPCHANGE);
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
        player[client].ClientMelee = SQL_FetchInt(hndl, 0);
        player[client].ClientBlood = SQL_FetchInt(hndl, 1);
        player[client].ClientHat = SQL_FetchInt(hndl, 2);
        player[client].GlowType = SQL_FetchInt(hndl, 3);
        SQL_FetchString(hndl, 4, player[client].tags.ChatTag, 24);
		//PrintToChat(client,"\x03返回的ClientMelee：%d",player[client].ClientMelee);
		//PrintToChat(client,"\x03返回的ClientBlood：%d",player[client].ClientBlood);
		}
		else{
			PrintToChat(client,"\x04新用户，正在创建数据库",player[client].ClientBlood);
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
		if(IsValidClient(i)&&IsSurvivor(i)&&!IsFakeClient(i)&&player[i].ClientPoints!=500){
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

		FormatEx(binfo, sizeof(binfo), "☆☆购物商店☆☆\n—————————\n当前B数：%d\n—————————",player[client].ClientPoints, client);	//玩家积分：
		menu.SetTitle(binfo);

		//FormatEx(binfo, sizeof(binfo),  "购买枪械", client);	//武器
		FormatEx(binfo, sizeof(binfo), "购买枪械", client);
		menu.AddItem("gun", binfo);

		FormatEx(binfo, sizeof(binfo),  "购买补给", client); //补给
		menu.AddItem("supply", binfo);

		FormatEx(binfo, sizeof(binfo),  "出门近战技能", client); //技能菜单
		menu.AddItem("ability", binfo);

		FormatEx(binfo, sizeof(binfo),  "称号菜单", client); //称号菜单
		menu.AddItem("ChatTags", binfo);
		
		FormatEx(binfo, sizeof(binfo),  "帽子菜单", client); //帽子菜单
		menu.AddItem("Hat", binfo);
		
		if(l4dstats_IsTopPlayer(client,20)|| GetUserAdmin(client)!= INVALID_ADMIN_ID)
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
			else if( StrEqual(bitem, "ChatTags") )
				ChatTags(param1);
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

	    menu.AddItem("option0", "关闭\n ", player[client].GlowType == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option1", "绿色", player[client].GlowType == 1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option2", "蓝色", player[client].GlowType == 2 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option3", "藍紫色", player[client].GlowType == 3 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option4", "青色", player[client].GlowType == 4 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option5", "橘黄色", player[client].GlowType == 5 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option6", "红色", player[client].GlowType == 6 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option7", "灰色", player[client].GlowType == 7 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option8", "黄色", player[client].GlowType == 8 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option9", "酸橙色", player[client].GlowType == 9 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option10", "栗色", player[client].GlowType == 10 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option11", "藍綠色", player[client].GlowType == 11 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option12", "粉红色", player[client].GlowType == 12 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option13", "紫色", player[client].GlowType == 13 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    menu.AddItem("option14", "白色", player[client].GlowType == 14 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    DumpAdminCache(AdminCache_Admins,true);
	    DumpAdminCache(AdminCache_Groups,true);
	    if(l4dstats_IsTopPlayer(client,3)|| GetUserAdmin(client).HasFlag(ADMFLAG_GENERIC))
	    	menu.AddItem("option15", "金黄色", player[client].GlowType == 15 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	    if(l4dstats_IsTopPlayer(client,1)|| GetUserAdmin(client).ImmunityLevel == 100)
	    	menu.AddItem("option16", "彩虹色", player[client].GlowType == 16 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		
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
            player[client].GlowType = id;
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
    
    player[client].GlowType = id;
    
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

//创建购买菜单>>主菜单--称号菜单
public void ChatTags(int client)
{
	//ClientCommand(client,"Cmd_ReloadTags");
	//ApplyTags(client,0);
	ClientCommand(client,"sm_ch");	
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
		menu.SetTitle("当前B数：%i \n——————————",player[client].ClientPoints);
		
		FormatEx(binfo, sizeof(binfo),  "子弹 %dB数",CostAmmo, client);
		menu.AddItem("ammo", binfo);
		
		if(player[client].ClientFirstBuy){
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
		
		if(!IsAllowBigGun)
		{
			menu.Display(client, 20);
			return;
		}
		
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
				if(player[param1].ClientFirstBuy){
					player[param1].ClientFirstBuy=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"Uzi",player[param1].ClientPoints);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostUzi,"Uzi",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "smg_silenced") )
			{
				
				int costpoints = CostSilenced;
				if(player[param1].ClientFirstBuy){
					player[param1].ClientFirstBuy=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"消音smg",player[param1].ClientPoints);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostSilenced,"消音smg",player[param1].ClientPoints);
			}				
			else if( StrEqual(bitem, "smg_mp5") )
			{
				
				int costpoints = CostMP5;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostMP5,"mp5",player[param1].ClientPoints);
			}	
			else if( StrEqual(bitem, "rifle") ){
				//
				int costpoints = CostM16;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostM16,"m16步枪",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "rifle_ak47") ){
				int costpoints = CostAK47;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostAK47,"ak47步枪",player[param1].ClientPoints);
			}
				
			else if( StrEqual(bitem, "rifle_sg552") ){
				int costpoints = CostSG552;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostSG552,"sg552步枪",player[param1].ClientPoints);
			}
				
			else if( StrEqual(bitem, "rifle_desert") ){
				int costpoints = CostSCAR;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostSCAR,"scar步枪",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "pumpshotgun") ){
				int costpoints = CostPumpShotgun;
				
				if(player[param1].ClientFirstBuy){
					player[param1].ClientFirstBuy=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"一代单喷",player[param1].ClientPoints);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostPumpShotgun,"一代单喷",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "shotgun_chrome") ){
				int costpoints = CostChromeShotgun;
				if(player[param1].ClientFirstBuy){
					player[param1].ClientFirstBuy=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"二代单喷",player[param1].ClientPoints);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostChromeShotgun,"二代单喷",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "autoshotgun") ){
				int costpoints = CostAuto;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostAuto,"一代连喷",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "shotgun_spas") ){
				int costpoints = CostSPAS;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostSPAS,"二代连喷",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "hunting_rifle") ){
				int costpoints = CostHunting;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostHunting,"一代连狙",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "sniper_military") ){
				int costpoints = CostMilitary;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostMilitary,"二代连狙",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "sniper_scout") ){
				int costpoints = CostScout;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostScout,"鸟狙",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "sniper_awp") ){
				int costpoints = CostAWP;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostAWP,"AWP狙击枪",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "rifle_m60") ){
				int costpoints = CostM60;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostM60,"m60",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "grenade_launcher") ){
				int costpoints = CostGrenadeLuanch;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostGrenadeLuanch,"榴弹发射器",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "pistol") ){			
				int costpoints = CostP220;
				if(player[param1].ClientFirstBuy){
					player[param1].ClientFirstBuy=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"小手枪",player[param1].ClientPoints);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostP220,"小手枪",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "pistol_magnum") ){
				
				int costpoints = CostMagnum;
				if(player[param1].ClientFirstBuy){
					player[param1].ClientFirstBuy=false;
					RemovePoints(param1, 0, bitem);
					PrintToChatAll("\x04%N\x03第一次白嫖了一把%s，还剩%d的B数",param1,"马格南",player[param1].ClientPoints);
				}
				else if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostMagnum,"马格南",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "ammo") ){
				ClientCommand(param1,"sm_ammo");
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
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostFirstAidKit,"医疗包",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "pain_pills") ){				
				int costpoints = CostPills;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostPills,"药丸",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "adrenaline") ){				
				int costpoints = CostAdren;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostAdren,"肾上腺素",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "gascan") ){
				
				int costpoints = CostGascan;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostGascan,"油桶",player[param1].ClientPoints);
			}
			else if( StrEqual(bitem, "weapon_gnome") ){
				
				int costpoints = CostGnome;
				if(RemovePoints(param1, costpoints, bitem))
				PrintToChatAll("\x04%N\x03B数-%d,购买了%s，还剩%d的B数",param1,CostGnome,"治疗小侏儒",player[param1].ClientPoints);
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
		menu.SetTitle("选择出门近战,当前为%d\n——————————",player[client].ClientMelee);
		
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
				player[param1].ClientMelee=1;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为砍刀");
			}
			else if( StrEqual(bitem, "fireaxe") ){
				player[param1].ClientMelee=2;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为消防斧");
			}
			else if( StrEqual(bitem, "knife") ){
				player[param1].ClientMelee=3;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为小刀");
			}
			else if( StrEqual(bitem, "katana") ){
				player[param1].ClientMelee=4;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为武士刀");
			}
			else if( StrEqual(bitem, "pistol_magnum") ){
				player[param1].ClientMelee=5;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为马格南");
			}
			else if( StrEqual(bitem, "electric_guitar") ){
				player[param1].ClientMelee=6;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为电吉他");
			}
			else if( StrEqual(bitem, "tonfa") ){
				player[param1].ClientMelee=7;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为警棍");
			}
			else if( StrEqual(bitem, "pitchfork") ){
				player[param1].ClientMelee=8;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为草叉");
			}
			else if( StrEqual(bitem, "shovel") ){
				player[param1].ClientMelee=9;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为铲子");
			}
			else if( StrEqual(bitem, "pistol") ){
				player[param1].ClientMelee=10;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为小手枪");
			}else if( StrEqual(bitem, "frying_pan") ){
				player[param1].ClientMelee=11;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04您的出门近战武器设为平底锅");
			}else if( StrEqual(bitem, "crowbar") ){
				player[param1].ClientMelee=12;
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
		if(player[client].ClientBlood)
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
				
				player[param1].ClientBlood=1;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04你已经开启了杀特回血，杀一只特感回2滴血，不超过血量上限");
			}
			else {				
				player[param1].ClientBlood=0;
				ClientSaveToFileSave(param1);
				PrintToChat(param1,"\x04你已经关闭了杀特回血.");
			}
		}
		case MenuAction_End:
			delete menu;
	}
}