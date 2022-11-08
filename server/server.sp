#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <left4dhooks>
#include <colors>
#undef REQUIRE_PLUGIN
#include <CreateSurvivorBot>


#define CVAR_FLAGS			FCVAR_NOTIFY
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define L4D_MAXHUMANS_LOBBY_OTHER 3
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))



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


ConVar hMaxSurvivors, hSurvivorsManagerEnable, hCvarAutoKickTank;
int iMaxSurvivors, iEnable, iAutoKickTankEnable;
public void OnPluginStart()
{
	AddNormalSoundHook(view_as<NormalSHook>(OnNormalSound));
	AddAmbientSoundHook(view_as<AmbientSHook>(OnAmbientSound));
	RegAdminCmd("sm_restartmap", RestartMap, ADMFLAG_ROOT, "restarts map");
	HookEvent("witch_killed", WitchKilled_Event);
	HookEvent("finale_win", ResetSurvivors);
	HookEvent("map_transition", ResetSurvivors);
	HookEvent("round_start", event_RoundStart);
	HookEvent("player_spawn", 	Event_PlayerSpawn);
	HookEvent("player_incapacitated", OnPlayerIncappedOrDeath);
	HookEvent("player_death", OnPlayerIncappedOrDeath);
	RegConsoleCmd("sm_setbot", SetBot);
	RegAdminCmd("sm_kicktank", KickMoreTankThanOne, ADMFLAG_KICK, "有多只tank得情况，随机踢至只有一只");
	SetConVarBounds(FindConVar("survivor_limit"), ConVarBound_Upper, true, 8.0);
	RegAdminCmd("sm_addbot", ADMAddBot, ADMFLAG_KICK, "Attempt to add a survivor bot (this bot will not be kicked by this plugin until someone takes over)");
	hSurvivorsManagerEnable = CreateConVar("l4d_multislots_survivors_manager_enable", "0", "Enable or Disable survivors manage",CVAR_FLAGS, true, 0.0, true, 1.0);
	hMaxSurvivors	= CreateConVar("l4d_multislots_max_survivors", "4", "Kick AI Survivor bots if numbers of survivors has exceeded the certain value. (does not kick real player, minimum is 4)", CVAR_FLAGS, true, 4.0, true, 8.0);
	hCvarAutoKickTank = CreateConVar("l4d_multislots_autokicktank", "0", "Auto kick tank when tank number above one", CVAR_FLAGS, true, 0.0, true, 1.0);
	hSurvivorsManagerEnable.AddChangeHook(ConVarChanged_Cvars);
	hMaxSurvivors.AddChangeHook(ConVarChanged_Cvars);
	hCvarAutoKickTank.AddChangeHook(ConVarChanged_Cvars);
	GetCvars();
}



public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void OnPlayerIncappedOrDeath(Handle event, char[] name, bool dontBroadcast) {
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
	for (int client = 1; client < MaxClients; client++) {
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
	for (int client = 1; client < (MAXPLAYERS + 1); client++) {
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
		return Plugin_Handled;
	
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



public Action SetBot(int client, int args) 
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
	return Plugin_Handled;
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

public Action OnNormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}

public Action OnAmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}

public Action RestartMap(int client,int args)
{
	CrashMap();
	return Plugin_Handled;
}

public void event_RoundStart(Handle event, char[] name, bool dontBroadcast)
{
	CreateTimer( 3.0, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE );
}

public Action Timer_DelayedOnRoundStart(Handle timer) 
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
	return Plugin_Continue;
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	SetConVarString(FindConVar("mp_gamemode"), "realism");
	return Plugin_Handled;
}

public Action ResetSurvivors(Handle event, char[] name, bool dontBroadcast)
{
	RestoreHealth();
	ResetInventory();
	return Plugin_Continue;
}

public Action L4D_OnFirstSurvivorLeftSafeArea() 
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
	SetBot(0,0);
	//SetGodMode(false);
	CreateTimer(0.5, Timer_AutoGive, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

stock void SetGodMode(bool canset)
{
	int flags = GetCommandFlags("god");
	SetCommandFlags("god", flags & ~ FCVAR_NOTIFY);
	SetConVarInt(FindConVar("god"), canset);
	SetCommandFlags("god", flags);
	SetConVarInt(FindConVar("sv_infinite_ammo"), canset);
}

public Action Timer_AutoGive(Handle timer) 
{
	for (int client = 1; client <= MaxClients; client++) 
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
				for (int i = 0; i < 1; i++) 
				{ 
					DeleteInventoryItem(client, i);		
				}
				BypassAndExecuteCommand(client, "give","smg_silenced");
				BypassAndExecuteCommand(client, "give","pistol_magnum");
			}
		}
	}
	return Plugin_Continue;
}

//秒妹回实血
public void WitchKilled_Event(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncap(client))
	{
		int maxhp = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		int targetHealth = GetSurvivorPermHealth(client) + 15;
		if(targetHealth > maxhp)
		{
			targetHealth = maxhp;
		}
		SetSurvivorPermHealth(client, targetHealth);
	}
}

void ResetInventory() 
{
	for (int client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			
			for (int i = 0; i < 5; i++) 
			{ 
				DeleteInventoryItem(client, i);		
			}
			BypassAndExecuteCommand(client, "give", "pistol");		
		}
	}		
}
void DeleteInventoryItem(int client, int slot) 
{
	int item = GetPlayerWeaponSlot(client, slot);
	if (item > 0) 
	{
		RemovePlayerItem(client, item);
	}	
}

void RestoreHealth() 
{
	for (int client = 1; client <= MaxClients; client++) 
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

void CrashMap()
{
    char mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
}

void BypassAndExecuteCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

//判断生还是否已经满人
stock bool IsSuivivorTeamFull() 
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsFakeClient(i))
		{
			return false;
		}
	}
	return true;
}
//判断是否为生还者
stock bool IsSurvivor(int client) 
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
stock bool IsValidPlayerInTeam(int client, int team)
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
stock bool IsValidPlayer(int client, bool AllowBot = true, bool AllowDeath = true)
{
	if (client < 1 || client > MaxClients)
		return false;
	if (!IsClientConnected(client) || !IsClientInGame(client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(client))
			return false;
	}

	if (!AllowDeath)
	{
		if (!IsPlayerAlive(client))
			return false;
	}	
	
	return true;
}

//判断生还者是否已经被控
stock bool IsPinned(int client) 
{
	bool bIsPinned = false;
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

stock int GetSurvivorPermHealth(int client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock void SetSurvivorPermHealth(int client, int health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

stock bool IsPlayerIncap(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}