#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
//#include <smlib>
#define PLUGIN_VERSION	"2022-05"
new Handle: g_hCvarInfectedTime = INVALID_HANDLE;
new Handle: g_hCvarInfectedLimit = INVALID_HANDLE;
new Handle: g_hCvarTankBhop = INVALID_HANDLE;
new Handle: g_hCvarWeapon = INVALID_HANDLE;
new Handle:hCvarCoop;
new CommonLimit; 
new CommonTime; 
new TankBhop;
new Weapon;
new MaxPlayers;
//String:sBuffer[256];
public OnPluginStart()
{
	g_hCvarInfectedTime = FindConVar("versus_special_respawn_interval");
	g_hCvarInfectedLimit = FindConVar("l4d_infected_limit");
	g_hCvarTankBhop = FindConVar("ai_Tank_Bhop");
	g_hCvarWeapon = CreateConVar("ZonemodWeapon", "0", "", 0, false, 0.0, false, 0.0);
	HookConVarChange(g_hCvarInfectedTime, Cvar_InfectedTime);
	HookConVarChange(g_hCvarInfectedLimit, Cvar_InfectedLimit);
	HookConVarChange(g_hCvarTankBhop, CvarTankBhop);
	HookConVarChange(g_hCvarWeapon, CvarWeapon);
	CommonTime = GetConVarInt(g_hCvarInfectedTime);
	CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
	TankBhop = GetConVarInt(g_hCvarTankBhop);
	Weapon = GetConVarInt(g_hCvarWeapon);
	RegConsoleCmd("sm_xx",InfectedStatus);
	hCvarCoop = CreateConVar("coopmode", "0");
	HookEvent("player_incapacitated_start",Incap_Event);
	HookEvent("player_incapacitated",Incap_Event);
	HookEvent("round_start", event_RoundStart);
	HookEvent("player_death", player_death);
	RegConsoleCmd("sm_zs", ZiSha);
	RegConsoleCmd("sm_kill", ZiSha);
}
public Action:player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
	return Plugin_Continue;
}
public Action:ZiSha(client, args)
{
	ForcePlayerSuicide(client);
	if(IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
	return Plugin_Handled;
}

public Incap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new Incap = GetClientOfUserId(GetEventInt(event, "userid"));
	if(bool:GetConVarBool(hCvarCoop))
	{
		ForcePlayerSuicide(Incap);
	}
	if(IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
}
//离开安全门重新加载插件（理论上不应该在此插件完成）
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	ReloadPlugins();
}
public Cvar_InfectedTime( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	CommonTime = GetConVarInt(g_hCvarInfectedTime);
	ReloadPlugins();
}
public Cvar_InfectedLimit( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	CommonLimit = GetConVarInt(g_hCvarInfectedLimit);
}
public CvarTankBhop( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	TankBhop = GetConVarInt(g_hCvarTankBhop);
}
public CvarWeapon( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	Weapon = GetConVarInt(g_hCvarWeapon);
	if (Weapon>0)
	{
		ServerCommand("exec vote/weapon/zonedmod.cfg");
	}
	else
	{
		ServerCommand("exec vote/weapon/AnneHappy.cfg");
	}
}
public Action:InfectedStatus(Client, args)
{ 
	//FormatTime(sBuffer, sizeof(sBuffer), "%Y/%m/%d");
	if(TankBhop > 0)
	{
		if( Weapon > 0)
		{
			PrintToChatAll("\x03Tank连跳\x05[\x04开启\x05] \x03武器\x05[\x04Zone\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
		}
		else
		{
			PrintToChatAll("\x03Tank连跳\x05[\x04开启\x05] \x03武器\x05[\x04Anne\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
		}
	}
	else
	{
		if( Weapon > 0)
		{
			PrintToChatAll("\x03Tank连跳\x05[\x04关闭\x05] \x03武器\x05[\x04Zone\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
		}
		else
		{
			PrintToChatAll("\x03Tank连跳\x05[\x04关闭\x05] \x03武器\x05[\x04Anne\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
		}
	}
	if(GetConVarInt(FindConVar("ReturnBlood"))>0)
		PrintToChatAll("\x03回血\x05[\x04开启\x05]");
	if(GetConVarInt(FindConVar("ai_TankConsume"))>0)
			PrintToChatAll("\x03坦克消耗\x05[\x04开启\x05]");
	return Plugin_Handled;
}
public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//FormatTime(sBuffer, sizeof(sBuffer), "%Y/%m/%d");
	if(TankBhop > 0)
	{
		if( Weapon > 0)
		{
			PrintToChatAll("\x03Tank连跳\x05[\x04开启\x05] \x03武器\x05[\x04Zone\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
		}
		else
		{
			PrintToChatAll("\x03Tank连跳\x05[\x04开启\x05] \x03武器\x05[\x04Anne\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
		}
	}
	else
	{
		if( Weapon > 0)
		{
			PrintToChatAll("\x03Tank连跳\x05[\x04关闭\x05] \x03武器\x05[\x04Zone\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
		}
		else
		{
			PrintToChatAll("\x03Tank连跳\x05[\x04关闭\x05]\x03武器\x05[\x04Anne\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
		}
	}
	if(GetConVarInt(FindConVar("ReturnBlood"))>0)
		PrintToChatAll("\x03回血\x05[\x04开启\x05]");
	if(GetConVarInt(FindConVar("ai_TankConsume"))>0)
		PrintToChatAll("\x03坦克消耗\x05[\x04开启\x05]");
}
public OnClientPutInServer(Client)
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
		if(TankBhop > 0)
		{
			if( Weapon > 0)
			{
				PrintToChatAll("\x03Tank连跳\x05[\x04开启\x05] \x03武器\x05[\x04Zone\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
			}
			else
			{
				PrintToChatAll("\x03Tank连跳\x05[\x04开启\x05] \x03武器\x05[\x04Anne\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
			}
		}
		else
		{
			if( Weapon > 0)
			{
				PrintToChatAll("\x03Tank连跳\x05[\x04关闭\x05] \x03武器\x05[\x04Zone\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
			}
			else
			{
				PrintToChatAll("\x03Tank连跳\x05[\x04关闭\x05]\x03武器\x05[\x04Anne\x05] \x03特感\x05[\x04%i特%i秒\x05] \x03电信服\x05[\x04%s\x05]",CommonLimit,CommonTime,PLUGIN_VERSION);
			}
		}
		if(GetConVarInt(FindConVar("ReturnBlood"))>0)
			PrintToChatAll("\x03回血\x05[\x04开启\x05]");
		if(GetConVarInt(FindConVar("ai_TankConsume"))>0)
			PrintToChatAll("\x03坦克消耗\x05[\x04开启\x05]");
	}
}
stock bool:IsValidPlayer(Client, bool:AllowBot = true, bool:AllowDeath = true)
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

ReloadPlugins()
{
	ServerCommand("sm plugins load_unlock");
	ServerCommand("sm plugins reload optional/infected_control_test.smx");
	//ServerCommand("sm plugins reload optional/l4d2_storm.smx");
	ServerCommand("sm plugins load_lock");
	ServerCommand("sm_startspawn");
	
}

bool:IsTeamImmobilised() {
	//Check if there is still an upright survivor
	new bool:bIsTeamImmobilised = true;
	for (new client = 1; client < MaxClients; client++) {
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
stock bool:Survivor(i)
{
    return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}
stock bool:Incapacitated(client)
{
    new bool:bIsIncapped = false;
	if ( Survivor(client) ) {
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) bIsIncapped = true;
		if (!IsPlayerAlive(client)) bIsIncapped = true;
	}
	return bIsIncapped;
}