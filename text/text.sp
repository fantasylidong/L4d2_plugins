#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <steamworks>
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))

//#include <smlib>
//#define PLUGIN_VERSION	"2022-08"
ConVar
	g_hCvarInfectedTime,
	g_hCvarInfectedLimit,
	g_hCvarTankBhop,
	g_hCvarWeapon,
	g_hCvarCoop,
	g_hCvarPluginVersion;

int 
	CommonLimit,
	CommonTime,
	TankBhop,
	Weapon,
	MaxPlayers;
char PLUGIN_VERSION[32];

public void OnPluginStart()
{
	g_hCvarInfectedTime = FindConVar("versus_special_respawn_interval");
	g_hCvarInfectedLimit = FindConVar("l4d_infected_limit");
	g_hCvarTankBhop = FindConVar("ai_Tank_Bhop");
	g_hCvarWeapon = CreateConVar("ZonemodWeapon", "0", "", 0, false, 0.0, false, 0.0);
	g_hCvarPluginVersion = CreateConVar("AnnePluginVersion", "Latest", "Anne插件版本");
	HookConVarChange(g_hCvarInfectedTime, Cvar_InfectedTime);
	if(g_hCvarInfectedLimit != null)
	HookConVarChange(g_hCvarInfectedLimit, Cvar_InfectedLimit);
	if(g_hCvarTankBhop != null)
		HookConVarChange(g_hCvarTankBhop, CvarTankBhop);
	HookConVarChange(g_hCvarWeapon, CvarWeapon);
	HookConVarChange(g_hCvarPluginVersion, CvarPluginVersion);
	CommonTime = GetConVarInt(g_hCvarInfectedTime);
	CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
	if(g_hCvarTankBhop != null)
		TankBhop = GetConVarInt(g_hCvarTankBhop);
	Weapon = GetConVarInt(g_hCvarWeapon);
	RegConsoleCmd("sm_xx",InfectedStatus);
	g_hCvarCoop = CreateConVar("coopmode", "0");
	HookEvent("player_incapacitated_start", Incap_Event, EventHookMode_Post);
	HookEvent("player_incapacitated", Incap_Event, EventHookMode_Post);
	HookEvent("round_start", event_RoundStart);
	HookEvent("player_death", player_death, EventHookMode_Post);
	RegConsoleCmd("sm_zs", ZiSha);
	RegConsoleCmd("sm_kill", ZiSha);
	RegConsoleCmd("sm_killall", killall);
}
public Action player_death(Handle event, char[] name, bool dontBroadcast)
{
	if(IsTeamImmobilised())
	{
		SlaySurvivors();
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
	return Plugin_Continue;
}
public Action ZiSha(int client, int args)
{
	ForcePlayerSuicide(client);
	if(IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
	return Plugin_Handled;
}


public Action killall(int client, int args)
{
	SlaySurvivors();
	if(IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}	
	return Plugin_Handled;
}

public void SlaySurvivors() { //incap everyone
	for(int i=1; i<=MaxClients ; i++)
		if(IsValidPlayer(i,true,false) && GetClientTeam(i)==2)
			ForcePlayerSuicide(i);
}

public void Incap_Event(Handle event, char[] name, bool dontBroadcast)
{
	int  Incap = GetClientOfUserId(GetEventInt(event, "userid"));
	if(GetConVarBool(g_hCvarCoop))
	{
		ForcePlayerSuicide(Incap);
	}
	if(IsTeamImmobilised())
	{
		SlaySurvivors();
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
}


//离开安全门重新加载插件（理论上不应该在此插件完成）
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	ServerCommand("sm_startspawn");
	return Plugin_Continue;
}
public void Cvar_InfectedTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CommonTime = GetConVarInt(g_hCvarInfectedTime);
}
public void Cvar_InfectedLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
	char tags[64];
	GetConVarString(FindConVar("sv_tags"), tags, sizeof(tags));
	if (Weapon == 2 && CommonLimit< 10 && (StrContains(tags, "anne", false) != -1 || StrContains(tags, "allcharger", false) != -1 || StrContains(tags, "witchparty", false) != -1))
	{
		ServerCommand("sm_cvar ZonemodWeapon 0");
		PrintToChatAll("\x03因为不超过10特，AnneHappy+武器已经自动切换为AnneHappy武器");
	}
}
public void CvarTankBhop(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(g_hCvarTankBhop != null)
		TankBhop = GetConVarInt(g_hCvarTankBhop);
}

public void CvarPluginVersion(ConVar convar, const char[] oldValue, const char[] newValue)
{
	Format(PLUGIN_VERSION, sizeof(PLUGIN_VERSION), "%s", newValue);
	//strcopy(PLUGIN_VERSION, sizeof(PLUGIN_VERSION), newValue);
}


public void CvarWeapon(ConVar convar, const char[] oldValue, const char[] newValue)
{
	Weapon = GetConVarInt(g_hCvarWeapon);
	char tags[64];
	GetConVarString(FindConVar("sv_tags"), tags, sizeof(tags));
	if (Weapon == 1)
	{
		ServerCommand("exec vote/weapon/zonemod.cfg");
	}
	else if (Weapon == 0)
	{
		ServerCommand("exec vote/weapon/AnneHappy.cfg");
	}
	else if (Weapon == 2)
	{
		if(CommonLimit >= 10 || (StrContains(tags, "alone", false) != -1) || (StrContains(tags, "1vht", false) != -1))
			ServerCommand("exec vote/weapon/AnneHappyPlus.cfg");
		else
		{
			PrintToChatAll("\x03因为不超过10特，无法使用AnneHappyPlus武器");
			ServerCommand("sm_cvar ZonemodWeapon 0");
		}
			
	}
}

public void OnGameFrame(){
	SteamWorks_SetGameDescription("电信Anne娱乐服,开心坐牢");
}

void printinfo(int client = 0, bool All = true){
	//FormatTime(sBuffer, sizeof(sBuffer), "%Y/%m/%d");
	char buffer[128];
	char buffer2[128];
	if(g_hCvarTankBhop != null){
		Format(buffer, sizeof(buffer), "\x03Tank连跳\x05[\x04%s\x05]", TankBhop > 0?"开启":"关闭");
		Format(buffer, sizeof(buffer), "%s \x03武器\x05[\x04%s\x05]", buffer, Weapon > 0?(Weapon > 1?"Anne+":"Zone"):"Anne");
	}else
	{
		Format(buffer, sizeof(buffer), "\x03武器\x05[\x04%s\x05]",  Weapon > 0?(Weapon > 1?"Anne+":"Zone"):"Anne");
	}
		
	if(PLUGIN_VERSION[0] == '\0')
	GetConVarString(g_hCvarPluginVersion, PLUGIN_VERSION, sizeof(PLUGIN_VERSION));
	Format(buffer, sizeof(buffer), "%s \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]", buffer, CommonLimit, CommonTime, PLUGIN_VERSION);
	int max_dist = GetConVarInt(FindConVar("inf_SpawnDistanceMin"));
	Format(buffer2, sizeof(buffer2), "\x03特感最近生成距离\x05[\x04%d\x05]", max_dist);
	if(FindConVar("inf_TeleportCheckTime") && FindConVar("inf_TeleportDistance")){
		int Teleport_CheckTime = GetConVarInt(FindConVar("inf_TeleportCheckTime"));
		int Teleport_distance = GetConVarInt(FindConVar("inf_TeleportDistance"));
		Format(buffer2, sizeof(buffer2), "%s \x03特感传送条件\x05[\x04%d单位%d秒\x05]", buffer2, Teleport_distance, Teleport_CheckTime);
	}
	if(FindConVar("ReturnBlood") && GetConVarInt(FindConVar("ReturnBlood"))>0)
		Format(buffer2, sizeof(buffer2), "%s \x03回血\x05[\x04开启\x05]", buffer2);
	if(FindConVar("ai_TankConsume") && GetConVarInt(FindConVar("ai_TankConsume"))>0)
		Format(buffer2, sizeof(buffer2), "%s \x03坦克消耗\x05[\x04开启\x05]");
	if(All){
		PrintToChatAll(buffer);
		PrintToChatAll(buffer2);
	}else
	{
		PrintToChat(client, buffer);
		PrintToChat(client, buffer2);
	}
}

public Action InfectedStatus(int Client, int args)
{ 
	printinfo(Client);
	return Plugin_Handled;
}
public void event_RoundStart(Handle event, char[] name, bool dontBroadcast)
{
	printinfo();
}
public void OnClientPutInServer(int Client)
{
	//FormatTime(sBuffer, sizeof(sBuffer), "%Y/%m/%d");
	if (IsValidPlayer(Client, false))
	{
		MaxPlayers ++ ;
		if(MaxPlayers >= 3)
		{
			L4D_LobbyUnreserve();
			ServerCommand("sm_cvar sv_allow_lobby_connect_only 0");
		}
		printinfo(Client, false);
	}
}
stock bool IsValidPlayer(int Client, bool AllowBot = true, bool AllowDeath = true)
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



bool IsTeamImmobilised() {
	//Check if there is still an upright survivor
	bool bIsTeamImmobilised = true;
	for (int client = 1; client < MaxClients; client++) {
		// If a survivor is found to be alive and neither pinned nor incapacitated
		// team is not immobilised.
		if (Survivor(client) && IsPlayerAlive(client) ) 
		{		
			if (!Incapacitated(client) ) 
			{		
				bIsTeamImmobilised = false;				
			} 
		}
	}
	return bIsTeamImmobilised;
}
stock bool Survivor(int i)
{
    return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}
stock bool Incapacitated(int client)
{
    bool bIsIncapped = false;
    if (Survivor(client)) 
	{
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) bIsIncapped = true;
		if (!IsPlayerAlive(client)) bIsIncapped = true;
	}
    return bIsIncapped;
}