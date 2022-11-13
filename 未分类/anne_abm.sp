/************************************************
* Plugin name:		[L4D(2)] MultiSlots
* Plugin author:	SwiftReal
* 
* Based upon:
* - (L4D) Zombie Havoc by Bigbuck
* - (L4D2) Bebop by frool
* 
* Version 1.0
* 		- Initial Release
************************************************/

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

//#define PLUGIN_VERSION 				"1.0"
#define CVAR_FLAGS					FCVAR_PLUGIN|FCVAR_NOTIFY
#define DELAY_KICK_FAKECLIENT 		0.01
#define DELAY_KICK_NONEEDBOT 		5.0
#define DELAY_CHANGETEAM_NEWPLAYER 	1.5
#define TEAM_SPECTATORS 			1
#define TEAM_SURVIVORS 				2
#define TEAM_INFECTED				3
#define DAMAGE_EVENTS_ONLY			1
#define DAMAGE_YES					2
#define MAXSURVIVORS 				4

//new Handle:hMaxSurvivors
//new Handle:hMaxInfected
//new Handle:timer_SpawnTick = INVALID_HANDLE;
//new Handle:timer_SpecCheck = INVALID_HANDLE
//new Handle:hKickIdlers
new bool:gameStarted;
//new bool:gbVehicleLeaving
//new bool:gbPlayedAsSurvivorBefore[MAXPLAYERS+1]
//new bool:gbFirstItemPickedUp
//new bool:gbPlayerPickedUpFirstItem[MAXPLAYERS+1]
//new Float:vecLocationStart[3]
//new String:gMapName[128]
//new giIdleTicks[MAXPLAYERS+1]
//new SurvToSpec[MAXPLAYERS+1]
//new addbotsTimer[MAXPLAYERS + 1]

new clientTimeout[MAXPLAYERS + 1] = 0; // 加载超时时间
new countDown; // 倒计时

//new bool:isFirstRound; 
new bool:isClientLoading[MAXPLAYERS + 1] = false;
new bool:isCountDownEnd = false;

new bool:surClient[MAXPLAYERS + 1];


public Plugin:myinfo = 
{
	name 			= "[L4D(2)] MultiSlots",
	author 			= "SwiftReal, MI 5, yed_, Glide Loading, 海洋空氣",
	description 	= "Allows additional survivor/infected players in coop, versus, and survival",
	version 		= "1.0",
	url 			= "N/A"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	// This plugin will only work on L4D 1/2
	decl String:GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead", false) == -1)
		return APLRes_Failure; 
	return APLRes_Success; 
}

public OnPluginStart()
{
	// Create plugin version cvar and set it
	//CreateConVar("l4d_multislots_version", PLUGIN_VERSION, "L4D(2) MultiSlots version", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_REPLICATED)
	//SetConVarString(FindConVar("l4d_multislots_version"), PLUGIN_VERSION);
	
	// Register commands
	RegConsoleCmd("sm_addbot", AddBot, "Attempt to add and teleport a survivor bot");
	RegConsoleCmd("sm_join", JoinTeamAlt, "Moves you to the survivor team");
	RegConsoleCmd("sm_joingame", JoinTeamAlt, "Moves you to the survivor team");
	RegConsoleCmd("sm_jg", JoinTeamAlt, "Moves you to the survivor team");
	RegConsoleCmd("sm_spectate", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_spec", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_s", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_away", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_return", Return_Cmd, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
	RegConsoleCmd("sm_kill", Command_suicide);
	RegConsoleCmd("sm_die", Command_suicide);
	RegConsoleCmd("sm_stuck", Command_suicide);
	RegConsoleCmd("sm_suicide", Command_suicide);
	RegConsoleCmd("sm_zs", Command_suicide);
	
	// Register cvars
	/*
	hMaxSurvivors	= CreateConVar("l4d_multislots_max_survivors", "4", "How many survivors allowed?", CVAR_FLAGS, true, 1.0, true, 2.0)
	hMaxInfected	= CreateConVar("l4d_multislots_max_infected", "0", "How many infected allowed?", CVAR_FLAGS, true, 0.0, true, 2.0)
	hKickIdlers 	= CreateConVar("l4d_multislots_kickafk", "0", "Kick idle players? (0 = no  1 = player 5 min, admins kickimmune  2 = player 5 min, admins 10 min)", CVAR_FLAGS, true, 0.0, true, 2.0)
	*/
	
	// Hook events
	//HookEvent("item_pickup", evtRoundStartAndItemPickup)
	//HookEvent("player_left_start_area", evtPlayerLeftStart)
	//HookEvent("survivor_rescued", evtSurvivorRescued)
	HookEvent("round_start", evtRoundStart);
	HookEvent("finale_vehicle_leaving", evtFinaleVehicleLeaving);
	HookEvent("mission_lost", evtMissionLost);
	HookEvent("round_end", evtMissionLost);
	HookEvent("map_transition", evtMapTransition);
	//HookEvent("player_activate", evtPlayerActivate);
	HookEvent("bot_player_replace", evtPlayerReplacedBot);
	HookEvent("player_bot_replace", evtBotReplacedPlayer);
	HookEvent("player_team", evtPlayerTeam, EventHookMode_Pre);
	
	// Create or execute plugin configuration file
	//AutoExecConfig(true, "l4dmultislots");
	
}

public OnMapStart()
{
	//GetCurrentMap(gMapName, sizeof(gMapName))
	//FindLocationStart()
	TweakSettings();
	//gbFirstItemPickedUp = false
	gameStarted = false;
	SetConVarInt(FindConVar("god"),1);
	SetConVarInt(FindConVar("sv_infinite_ammo"),1);
	//KickBots();
	
	//isFirstRound = true;
	countDown = -1;
	isCountDownEnd = false;
	for (new i = 0; i <= MaxClients; i++)
	{
		isClientLoading[i] = true;
		clientTimeout[i] = 0;
	}
	
	PrecacheSound("npc/virgil/c3end52.wav");
	PrecacheSound("npc/virgil/beep_error01.wav");
	
	CreateTimer(1.0, LoadingTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT); // 开始无限循环判断是否全部加载完毕
}

public OnClientPutInServer(client)
{
	/*if(client)
	{
		//gbPlayedAsSurvivorBefore[client] = false
		//gbPlayerPickedUpFirstItem[client] = false
		//giIdleTicks[client] = 0
	}*/
	if (client < 1 || client > MaxClients || !isClientValid(client)) return;
	//KickBots();
	
	if (isCountDownStoppedOrRunning())
	{
		isClientLoading[client] = false;
		clientTimeout[client] = 0;
	}
	
	int survivorLimit = GetConVarInt(FindConVar("survivor_limit"));
	if (!gameStarted && TotalSurvivors() < survivorLimit)
	{
		SpawnFakeClientAndTeleport();
		//FakeClientCommand(client, "jointeam 2");
	}
}
/*
public OnClientDisconnect_Post(client)
{
	if(gameStarted) {
		CreateTimer(3.0, SlayBot);
	}
}*/

public OnClientDisconnect(client)
{
	isClientLoading[client] = false;
	clientTimeout[client] = 0;
}

/*
public OnClientDisconnect(client)
{
	gbPlayedAsSurvivorBefore[client] = false
	gbPlayerPickedUpFirstItem[client] = false
}*/

public OnMapEnd()
{
	//StopTimers();
	//gbVehicleLeaving = false
	//gbFirstItemPickedUp = false
}

////////////////////////////////////
// Callbacks
////////////////////////////////////
public Action:AddBot(client, args)
{
	if (!client || IsFakeClient(client)) return;
	if (TotalSurvivors() >= 4 && GetClientTeam(client) == 2) return;
	if (gameStarted) {
		PrintHintText(client, "玩家已出安全区域，暂时无法加入游戏。");
		return;
	}
	if (TotalSurvivors() > MAXSURVIVORS)      return;
	SpawnFakeClientAndTeleport();
}

public Action:JoinTeamAlt(client, args)
{
	if (!client || IsFakeClient(client) || GetClientTeam(client) == 2 || Survivors() > MAXSURVIVORS) return;
	if (gameStarted) {
		PrintHintText(client, "玩家已出安全区域，暂时无法加入游戏。");
		return;
	}
	//SpawnFakeClientAndTeleport();
	FakeClientCommand(client, "jointeam 2");
}

/*
public Action:JoinTeam(client, args)
{
	if(gameStarted == false)
	{
		if(!IsClientConnected(client))
			return Plugin_Handled
		
		if(IsClientInGame(client))
		{
			if(GetClientTeam(client) == TEAM_SURVIVORS)
			{	
				if(DispatchKeyValue(client, "classname", "player") == true)
				{
					PrintHintText(client, "你已经在生还者队伍中。")
				}
				else if((DispatchKeyValue(client, "classname", "info_survivor_position") == true) && !IsAlive(client))
				{
					PrintHintText(client, "你已经在生还者队伍中。")
				}
			}
			else if(bIsPlayerIdle(client))
			{
				PrintHintText(client, "你处于闲置状态，点击鼠标左键加入游戏。")
			}
			else
			{			
				if(TotalFreeBots() == 0)
				{
					SpawnFakeClientAndTeleport()
					
					CreateTimer(1.0, Timer_AutoJoinTeam, client, TIMER_REPEAT)				
				}
				else
					TakeOverBot(client, false)
			}
		}	
	}
	else
		PrintHintText(client, "玩家已出安全区域，暂时无法加入游戏。")
	return Plugin_Handled
}
*/
public Action:Spectate_Cmd(client, args)
{
	new String:text[128];
	decl String:spectator[1024];
	new team = GetClientTeam(client);
	if (team == 1)
	{
		PrintToChat(client, "\x04[AstMod] \x01你已经在旁观者队伍中.");
		return Plugin_Stop;
	}
	if (gameStarted && Survivors() == 1)
	{
		PrintToChat(client, "\x04[AstMod] \x03请先原地去世后再旁观.");
		return Plugin_Stop;
	}
	GetClientName(client, spectator, 1024);
	new Float:ccc = GetRandomFloat(0.0, 1.0) * 10;
	if (ccc >= 9.0)
		Format(text, 128, "决定休息一下.");
	else if (ccc >= 8.0)
		Format(text, 128, "逃跑至旁观者.");
	else if (ccc >= 7.0)
		Format(text, 128, "有急事说要先走了.");
	else if (ccc >= 6.0)
		Format(text, 128, "尿急去一下厕所.");
	else if (ccc >= 5.0)
		Format(text, 128, "的女朋友在旁边......");
	else if (ccc >= 4.0)
		Format(text, 128, "说先走一步了....");
	else if (ccc >= 3.0)
		Format(text, 128, "的老二有点痒去看了医生.");
	else if (ccc >= 2.0)
		Format(text, 128, "家有按摩妹突然到访....");
	else if (ccc >= 1.0)
		Format(text, 128, "被对面电到先闪了.");
	else Format(text, 128, "被队友气到旁观者.");
	PrintToChatAll("\x04[AstMod] \x03%s \x01%s", spectator, text);
	ChangeClientTeam(client, 1);
	return Plugin_Handled;
}

public Action:Return_Cmd(client, args)
{
	if (client > 0
			&& !gameStarted
			&& GetClientTeam(client) == 2)
	{
		ReturnPlayerToSaferoom(client, false);
	}
	return Plugin_Handled;
}

public Action:Command_suicide(client, args)
{   
	if(!client || !IsPlayerAlive(client))
		return Plugin_Handled;
	
	if(!gameStarted)
	{
		PrintToChat(client, "回合未开始！");
		return Plugin_Handled;
	}
	
	ForcePlayerSuicide(client);
	return Plugin_Handled;
}

////////////////////////////////////
// Events
////////////////////////////////////
/* public evtRoundStartAndItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!gbFirstItemPickedUp)
	{
		// alternative to round start...
		if(timer_SpecCheck == INVALID_HANDLE)
			timer_SpecCheck = CreateTimer(15.0, Timer_SpecCheck, _, TIMER_REPEAT)
		gbFirstItemPickedUp = true
	}
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(!gbPlayerPickedUpFirstItem[client] && !IsFakeClient(client))
	{
		// force setting client cvars here...
		//ForceClientCvars(client)
		gbPlayerPickedUpFirstItem[client] = true
		gbPlayedAsSurvivorBefore[client] = true
	}
} */
/* public evtPlayerActivate(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(client)
	{
		if((GetClientTeam(client) != TEAM_INFECTED) && (GetClientTeam(client) != TEAM_SURVIVORS) && !IsFakeClient(client) && !bIsPlayerIdle(client))
			CreateTimer(DELAY_CHANGETEAM_NEWPLAYER, Timer_AutoJoinTeam, client, TIMER_REPEAT)
	}
} */
/* public evtPlayerLeftStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(client)
	{
		if(IsClientConnected(client) && IsClientInGame(client))
		{
			if(GetClientTeam(client)==TEAM_SURVIVORS)
				gbPlayedAsSurvivorBefore[client] = true
		}
	}
} */

public Action:LoadingTimer(Handle:timer)
{
	if (isFinishedLoading())
	{
		countDown = 0;
		CreateTimer(1.0, StartTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		return Plugin_Stop;
	}
	else
	{
		for (new i = 0; i <= MaxClients; i++)
		{
			if (clientTimeout[i] >= 90)
			{
				KickClient(i, "连接超时。");
				isClientLoading[i] = false;
				clientTimeout[i] = 0;
			}
		}
		countDown = -1;
	}
	return Plugin_Continue;
}

public Action:StartTimer(Handle:timer)
{
	if (countDown++ >= 10)
	{
		countDown = 0;
		PrintHintTextToAll("Go!", 10 - countDown);
		isCountDownEnd = true;
		EmitSoundToAll("npc/virgil/c3end52.wav");
		//isFirstRound = false;
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("请等待：%d", 10 - countDown);
	}
	return Plugin_Continue;
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	if (!isFinishedLoading())
	{
		ReturnToSaferoom(client);
		EmitSoundToClient(client, "ui/beep_error01.wav");
		PrintHintTextToAll("等待其他玩家加载中...");
		return Plugin_Handled;
	}
	if (!isCountDownEnd)
	{
		ReturnToSaferoom(client);
		EmitSoundToClient(client, "ui/beep_error01.wav");
		return Plugin_Handled;
	}
	SetConVarInt(FindConVar("god"),0);
	SetConVarInt(FindConVar("sv_infinite_ammo"),0);
	KickBots();
	gameStarted = true;
	ResetInventory();
	SetConVarInt(FindConVar("director_no_survivor_bots"), 1);
	//SetConVarInt(FindConVar("survivor_limit"), Survivors());
	GiveStartPills();
	return Plugin_Continue;
}

public Action:evtPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new newteam = GetEventInt(event, "team");
	//new oldteam = GetEventInt(event, "oldteam")
	
	if (isClientValid(client))
	{
		if (gameStarted && newteam != TEAM_SPECTATORS)
		{
			//MoveToSpec(client);
			//PrintToChatAll("gameStarted && newteam != TEAM_SPECTATORS");
			//return Plugin_Handled;
			CreateTimer(0.1, MoveToSpecTimer, client);
		}
	}
	//return Plugin_Continue;
	/*if(newteam == TEAM_INFECTED || (gameStarted && newteam == TEAM_SURVIVORS)) 
	{
		//CreateTimer(0.1, OnTeamChangeDelay, client);
		MoveToSpec(client);
	}*/
	
/* 	if (newteam == TEAM_SPECTATORS && oldteam == TEAM_INFECTED)
	{
		//new String:PlayerName[100]
		//GetClientName(client, PlayerName, sizeof(PlayerName))
		//PrintToChatAll("\x01[\x04SM\x01] %s 加入了感染者", PlayerName)
		CreateTimer(1.0, Timer_AutoJoinTeam, client, TIMER_REPEAT)
		//giIdleTicks[client] = 0
		return
	} */
}

public Action:MoveToSpecTimer(Handle:timer, any:client)
{
	ChangeClientTeam(client, TEAM_SPECTATORS);
	//KickBots();
}

public Action:MoveToSurTimer(Handle:timer, any:client)
{
	//SpawnFakeClientAndTeleport();
	FakeClientCommand(client, "jointeam 2");
}

public OnGameFrame() {
	for (new i = 1; i <= MaxClients; i++)
	{
		if (isClientValid(i) && GetClientTeam(i) == TEAM_INFECTED) // 检查感染者
		{
			if (gameStarted)
			{
				CreateTimer(0.5, MoveToSpecTimer, i);
			}
			else
			{
				CreateTimer(0.5, MoveToSurTimer, i);
			}
		}
	}
}

public evtPlayerReplacedBot(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "player"));
	if(!client) return;
	if(GetClientTeam(client)!=TEAM_SURVIVORS || IsFakeClient(client)) return;
	
	//if(!gbPlayedAsSurvivorBefore[client])
	//{
		//ForceClientCvars(client)
		//gbPlayedAsSurvivorBefore[client] = true
		//giIdleTicks[client] = 0
		
	BypassAndExecuteCommand(client, "give", "health");

	SetEntityHealth(client, 100);
	SetEntityTempHealth(client, 0);
	//KickBots();
	//GiveMedkit(client)
	
	//decl String:PlayerName[100]
	//GetClientName(client, PlayerName, sizeof(PlayerName))
	//PrintToChatAll("\x04[SM] \x01%s 加入了生还者", PlayerName)
	//}
}

/*public evtSurvivorRescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"))
	if(client)
	{	
		StripWeapons(client)
		BypassAndExecuteCommand(client, "give", "pistol_magnum")
		if(StrContains(gMapName, "c1m1", false) == -1)
			GiveWeapon(client)
	}
}*/

public evtFinaleVehicleLeaving(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if((GetClientTeam(i) == TEAM_SURVIVORS) && IsAlive(i))
			{
				SetEntProp(i, Prop_Data, "m_takedamage", DAMAGE_EVENTS_ONLY, 1);
				new Float:newOrigin[3] = { 0.0, 0.0, 0.0 };
				TeleportEntity(i, newOrigin, NULL_VECTOR, NULL_VECTOR);
				SetEntProp(i, Prop_Data, "m_takedamage", DAMAGE_YES, 1);
			}
		}
	}
	//StopTimers();
	//gbVehicleLeaving = true;
}

public evtMapTransition(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (isClientValid(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			StripWeapons(i);
			BypassAndExecuteCommand(i, "give", "pistol");
			SetEntityHealth(i, 100);
			SetEntityTempHealth(i, 0);
		}
	}
}


public evtMissionLost(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetConVarInt(FindConVar("director_no_survivor_bots"), 0);
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	/*if (Survivors() <= 4)
		SetConVarInt(FindConVar("survivor_limit"), 4);
	else 
		SetConVarInt(FindConVar("survivor_limit"), Survivors());*/
	SetConVarInt(FindConVar("director_no_survivor_bots"), 0);
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (isClientValid(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			surClient[i] = true;
		}
	}
}

public evtRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//gbFirstItemPickedUp = false;
	SetConVarInt(FindConVar("god"),1);
	SetConVarInt(FindConVar("sv_infinite_ammo"),1);
	SetConVarInt(FindConVar("director_no_survivor_bots"), 0);
	gameStarted = false;
	ReturnTeamToSaferoom(TEAM_SURVIVORS);
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (isClientValid(i) && surClient[i])
		{
			CreateTimer(0.5, MoveToSurTimer, i);
			surClient[i] = false;
		}
	}
	//KickBots();
}

public evtBotReplacedPlayer(Handle:event, const String:name[], bool:dontBroadcast)
{
	new ljbot = GetClientOfUserId(GetEventInt(event, "bot"));
	
	if(GetClientTeam(ljbot) == TEAM_SURVIVORS) {
		if(gameStarted) {
			if (!Survivors())
			{
				PrintToChatAll("\x04[AstMod] \x01检测到无玩家在生还者队伍中, 自动处死 AI.");
				ForcePlayerSuicide(ljbot);
			} else
			{
				//SetConVarInt(FindConVar("survivor_limit"), Survivors());
				KickClient(ljbot, "kick bots");
			}
		}
		//else CreateTimer(DELAY_KICK_NONEEDBOT, Timer_KickNoNeededBot, ljbot);
	}
}

public Action:SlayBot(Handle:timer)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsFakeClient(i))
		{
			if (!Survivors())
			{
				PrintToChatAll("\x04[SM] \x01检测到无玩家在生还者队伍中, 自动处死 AI.");
				ForcePlayerSuicide(i);
			}
			else
			{
				KickClient(i, "kick bots");
				//SetConVarInt(FindConVar("survivor_limit"), Survivors());
			}
		}
	}
}

////////////////////////////////////
// timers
////////////////////////////////////
/*
public Action:Timer_SpawnTick(Handle:timer)
{
	new iTotalSurvivors = TotalSurvivors();
	if(iTotalSurvivors >= 1)
	{
		timer_SpawnTick = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	for(; iTotalSurvivors < 1; iTotalSurvivors++)
		SpawnFakeClient();
	
	return Plugin_Continue;
}
*/
/*
public Action:Timer_SpecCheck(Handle:timer)
{
	if(gbVehicleLeaving) return Plugin_Stop
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if((GetClientTeam(i) == TEAM_SPECTATORS) && !IsFakeClient(i))
			{
				
				if(!bIsPlayerIdle(i))
				{
					new String:PlayerName[100]
					GetClientName(i, PlayerName, sizeof(PlayerName))
					PrintToChat(i, "\x01[\x04SM\x01] %s, 输入 \x03!join\x01 加入生还者队伍", PlayerName)
				}
				
				switch(GetConVarInt(hKickIdlers))
				{
					case 0: {}
					case 1:
					{
						if(GetUserFlagBits(i) == 0)
						{
							giIdleTicks[i]++
							if(giIdleTicks[i] == 20)
								KickClient(i, "玩家闲置超过5分钟。")
						}
					}
					case 2:
					{
						giIdleTicks[i]++
						if(GetUserFlagBits(i) == 0)
						{
							if(giIdleTicks[i] == 20)
								KickClient(i, "玩家闲置超过5分钟。")
						}
						else
						{
							if(giIdleTicks[i] == 40)
								KickClient(i, "管理员闲置超过10分钟。")
						}
					}
				}
			}
		}
	}	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))		
		{
			if((GetClientTeam(i) == TEAM_SURVIVORS) && !IsFakeClient(i) && !IsAlive(i))
			{
				new String:PlayerName[100]
				GetClientName(i, PlayerName, sizeof(PlayerName))
				PrintToChat(i, "\x01[\x04SM\x01] %s, please wait to be revived or rescued", PlayerName)
			}
		}
	}
	return Plugin_Continue
}
*/

// Personally add
/* public Action:Timer_AutoJoinTeam(Handle:timer, any:client)
{
	if(client == 0 || !IsClientConnected(client))
		return Plugin_Stop
	
	if(IsClientInGame(client))
	{
		if(GetClientTeam(client) == TEAM_SURVIVORS)
			return Plugin_Stop
		if(bIsPlayerIdle(client))
			return Plugin_Stop
		
		JoinTeamAlt(client, 0)
	}
	return Plugin_Continue
} */

public Action:Timer_KickNoNeededBot(Handle:timer, any:bot)
{
	if((TotalSurvivors() <= 1))
		return Plugin_Handled;
	
	if(IsClientConnected(bot) && IsClientInGame(bot))
	{
		if(GetClientTeam(bot) == TEAM_INFECTED)
			return Plugin_Handled;
		
		decl String:BotName[100];
		GetClientName(bot, BotName, sizeof(BotName));
		if(StrEqual(BotName, "FakeClient", true))
			return Plugin_Handled;
		
		if(!bHasIdlePlayer(bot))
		{
			StripWeapons(bot);
			KickClient(bot, "Kicking No Needed Bot");
		}
	}	
	return Plugin_Handled;
}

public Action:Timer_KickFakeBot(Handle:timer, any:fakeclient)
{
	if(IsClientConnected(fakeclient))
	{
		KickClient(fakeclient, "Kicking FakeClient");
		return Plugin_Stop;
	}	
	return Plugin_Continue;
}

// Personally add
public KickBots()
{
	new i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i))
		{
			KickClient(i,"kick bots");
		}
		i++;
	}
}

public GiveStartPills()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (isClientValid(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			BypassAndExecuteCommand(i, "give", "pain_pills");
		}
	}
}

public ResetInventory() {
	for (new client = 1; client <= MaxClients; client++) {
		if ( isClientValid(client) && GetClientTeam(client) == TEAM_SURVIVORS ) {
			// Reset survivor inventories so they only hold dual pistols
			for (new i = 3; i < 5; i++) { 
				DeleteInventoryItem(client, i);		
			}
		}
	}		
}

DeleteInventoryItem(client, slot) {
	new item = GetPlayerWeaponSlot(client, slot);
	if (item > 0) {
		RemovePlayerItem(client, item);
	}	
}

////////////////////////////////////
// publics
////////////////////////////////////
public TweakSettings()
{
	/*
	new Handle:hMaxSurvivorsLimitCvar = FindConVar("survivor_limit")
	SetConVarBounds(hMaxSurvivorsLimitCvar,  ConVarBound_Lower, true, 1.0)
	SetConVarBounds(hMaxSurvivorsLimitCvar, ConVarBound_Upper, true, 4.0)
	SetConVarInt(hMaxSurvivorsLimitCvar, GetConVarInt(hMaxSurvivors))
	
	new Handle:hMaxInfectedLimitCvar = FindConVar("z_max_player_zombies")
	SetConVarBounds(hMaxInfectedLimitCvar,  ConVarBound_Lower, true, 1.0)
	SetConVarBounds(hMaxInfectedLimitCvar, ConVarBound_Upper, true, 2.0)
	SetConVarInt(hMaxInfectedLimitCvar, GetConVarInt(hMaxInfected))
	*/
	SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000) ;// allow spawning bots at any time
}

/*
public FindLocationStart()
{
new ent
decl Float:vecLocation[3]

if(StrContains(gMapName, "m1_", false) != -1)
{
// search for a survivor spawnpoint if first map of campaign
ent = -1
while((ent = FindEntityByClassname(ent, "info_survivor_position")) != -1)
{
if(IsValidEntity(ent))
{
GetEntPropVector(ent, Prop_Send, "m_vecOrigin", vecLocation)
vecLocationStart = vecLocation
break
}
}
}
else
{
// Search for a locked exit door,
ent = -1
while((ent = FindEntityByClassname(ent, "prop_door_rotating_checkpoint")) != -1)
{
if(IsValidEntity(ent))
{
if(GetEntProp(ent, Prop_Send, "m_bLocked") == 1)
{
GetEntPropVector(ent, Prop_Send, "m_vecOrigin", vecLocation)
vecLocationStart = vecLocation
break
}
}
}
}
}*/

/* public TakeOverBot(client, bool:completely)
{
	if (!IsClientInGame(client)) return
	if (GetClientTeam(client) == TEAM_SURVIVORS) return
	if (IsFakeClient(client)) return
	
	new bot = FindBotToTakeOver()	
	if (bot==0)
	{
		//PrintHintText(client, "生还者队伍已满！")
		return
	}
	
	static Handle:hSetHumanSpec
	if (hSetHumanSpec == INVALID_HANDLE)
	{
		new Handle:hGameConf		
		hGameConf = LoadGameConfigFile("l4dmultislots")
		
		StartPrepSDKCall(SDKCall_Player)
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "SetHumanSpec")
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer)
		hSetHumanSpec = EndPrepSDKCall()
	}
	
	static Handle:hTakeOverBot
	if (hTakeOverBot == INVALID_HANDLE)
	{
		new Handle:hGameConf		
		hGameConf = LoadGameConfigFile("l4dmultislots")
		
		StartPrepSDKCall(SDKCall_Player)
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "TakeOverBot")
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain)
		hTakeOverBot = EndPrepSDKCall()
	}
	
	if(completely)
	{
		SDKCall(hSetHumanSpec, bot, client)
		SDKCall(hTakeOverBot, client, true)
	}
	else
	{
		SDKCall(hSetHumanSpec, bot, client)
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5)
		FakeClientCommand(client, "jointeam 2")
	}
	
	return
} */

/* public FindBotToTakeOver()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i))
			{
				if (IsFakeClient(i) && GetClientTeam(i)==TEAM_SURVIVORS && IsAlive(i) && !bHasIdlePlayer(i))
					return i
			}
		}
	}
	return 0
} */

public SetEntityTempHealth(client, hp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	new Float:newOverheal = hp * 1.0; // prevent tag mismatch
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

public BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

public StripWeapons(client) // strip all items from client
{
	new itemIdx;
	for (new pslot = 0; pslot <= 3; pslot++)
	{
		if((itemIdx = GetPlayerWeaponSlot(client, pslot)) != -1)
		{  
			RemovePlayerItem(client, itemIdx);
			RemoveEdict(itemIdx);
		}
	}
}
/*
public GiveWeapon(client) // give client random weapon
{
	switch(GetRandomInt(0,6))
	{
		case 0: BypassAndExecuteCommand(client, "give", "smg")
		case 1: BypassAndExecuteCommand(client, "give", "smg_silenced")
	}	
	BypassAndExecuteCommand(client, "give", "ammo")
}

public GiveMedkit(client)
{
	new ent = GetPlayerWeaponSlot(client, 3)
	if(IsValidEdict(ent))
	{
		new String:sClass[128]
		GetEdictClassname(ent, sClass, sizeof(sClass))
		if(!StrEqual(sClass, "weapon_pain_pills", false))
		{
			RemovePlayerItem(client, ent)
			RemoveEdict(ent)
			BypassAndExecuteCommand(client, "give", "pain_pills")
		}
	}
	else
	{
		BypassAndExecuteCommand(client, "give", "pain_pills")
	}
}
*/
/*
public ForceClientCvars(client)
{
ClientCommand(client, "cl_glow_item_far_r 0.0")
ClientCommand(client, "cl_glow_item_far_g 0.7")
ClientCommand(client, "cl_glow_item_far_b 0.2")
}*/

public TotalSurvivors() // total survivors, including players
{
	new count = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVORS))
				count++;
		}
	}
	return count;
}

public Survivors() // survivor players
{
	new count = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && !IsFakeClient(i))
				count++;
		}
	}
	return count;
}

public HumanConnected()
{
	new count = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if(!IsFakeClient(i))
				count++;
		}
	}
	return count;
}

public TotalFreeBots() // total bots (excl. IDLE players)
{
	new count = 0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if(IsFakeClient(i) && GetClientTeam(i)==TEAM_SURVIVORS)
			{
				if(!bHasIdlePlayer(i))
					count++;
			}
		}
	}
	return count;
}
/*
public StopTimers()
{
	if (timer_SpawnTick != INVALID_HANDLE)
	{
		KillTimer(timer_SpawnTick);
		timer_SpawnTick = INVALID_HANDLE;
	}
	
}*/

////////////////////////////////////
// bools
////////////////////////////////////
/*
bool:SpawnFakeClient()
{
	if (gameStarted) return false;
	new bool:fakeclientKicked = false;
	
	// create fakeclient
	new fakeclient = 0;
	fakeclient = CreateFakeClient("FakeClient");
	
	// if entity is valid
	if(fakeclient != 0)
	{
		// move into survivor team
		ChangeClientTeam(fakeclient, TEAM_SURVIVORS);
		
		// check if entity classname is survivorbot
		if(DispatchKeyValue(fakeclient, "classname", "survivorbot") == true)
		{
			// spawn the client
			if(DispatchSpawn(fakeclient) == true)
			{	
				// kick the fake client to make the bot take over
				CreateTimer(DELAY_KICK_FAKECLIENT, Timer_KickFakeBot, fakeclient, TIMER_REPEAT);
				fakeclientKicked = true;
			}
		}			
		// if something went wrong, kick the created FakeClient
		if(fakeclientKicked == false)
			KickClient(fakeclient, "Kicking FakeClient");
	}	
	return fakeclientKicked;
}
*/
bool:SpawnFakeClientAndTeleport()
{
	if (gameStarted) return false;
	
	new bool:fakeclientKicked = false;
	
	// create fakeclient
	new fakeclient = CreateFakeClient("FakeClient");
	
	// if entity is valid
	if(fakeclient != 0)
	{
		// move into survivor team
		ChangeClientTeam(fakeclient, TEAM_SURVIVORS);
		
		// check if entity classname is survivorbot
		if(DispatchKeyValue(fakeclient, "classname", "survivorbot") == true)
		{
			// spawn the client
			if(DispatchSpawn(fakeclient) == true)
			{
				// teleport client to the position of any active alive player
				for (new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVORS) && !IsFakeClient(i) && IsAlive(i) && i != fakeclient)
					{						
						// get the position coordinates of any active alive player
						new Float:teleportOrigin[3];
						GetClientAbsOrigin(i, teleportOrigin);
						TeleportEntity(fakeclient, teleportOrigin, NULL_VECTOR, NULL_VECTOR)					;	
						break;
					}
				}
				
				StripWeapons(fakeclient);
				BypassAndExecuteCommand(fakeclient, "give", "pistol");
				//BypassAndExecuteCommand(fakeclient, "give", "smg_silenced");
				
				// kick the fake client to make the bot take over
				//KickClient(fakeclient, "Kicking FakeClient");
				CreateTimer(DELAY_KICK_FAKECLIENT, Timer_KickFakeBot, fakeclient, TIMER_REPEAT);
				fakeclientKicked = true;
			}
		}			
		// if something went wrong, kick the created FakeClient
		if(fakeclientKicked == false)
			KickClient(fakeclient, "Kicking FakeClient");
	}	
	return fakeclientKicked;
}

bool:bHasIdlePlayer(client)
{
    new iIdler = GetClientOfUserId(GetEntData(client, FindSendPropInfo("SurvivorBot", "m_humanSpectatorUserID"))); 
    if (iIdler) 
    {
        if (IsClientInGame(iIdler) && !IsFakeClient(iIdler) && (GetClientTeam(iIdler) != 2)) 
            return true; 
    }
    return false; 
}

/* bool:bIsPlayerIdle(client) 
{ 
    for (new iPlayer = 1; iPlayer <= MaxClients; iPlayer++) 
    {
        if (!IsClientConnected(iPlayer) || !IsClientInGame(iPlayer) || GetClientTeam(iPlayer) != 2 || !IsFakeClient(iPlayer) || !bHasIdlePlayer(iPlayer)) 
            continue

        new iIdler = GetClientOfUserId(GetEntData(iPlayer, FindSendPropInfo("SurvivorBot", "m_humanSpectatorUserID")))
        if (iIdler == client) 
            return true
    }
    return false
}  */

bool:IsAlive(client)
{
	if(!GetEntProp(client, Prop_Send, "m_lifeState"))
		return true;
	return false;
}

/*
bool:IsNobodyAtStart()
{
for(new i = 1; i <= MaxClients; i++)
{
if(IsClientConnected(i) && IsClientInGame(i))
{
if((GetClientTeam(i) == TEAM_SURVIVORS) && !IsFakeClient(i) && IsAlive(i))
{
decl Float:vecLocationPlayer[3]
GetClientAbsOrigin(i, vecLocationPlayer)
if(GetVectorDistance(vecLocationStart, vecLocationPlayer, false) < 750)
	return false
}
}
}
return true
}*/

ReturnPlayerToSaferoom(client, bool:flagsSet = true)
{
	new warp_flags;
	new give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		FakeClientCommand(client, "give health");
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}
}

ReturnTeamToSaferoom(team)
{
	new warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	new give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			ReturnPlayerToSaferoom(client, true);
		}
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

ReturnToSaferoom(client)
{
	new warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	new give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	if (IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		ReturnPlayerToSaferoom(client, true);
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

bool:isAnyClientLoading()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (isClientLoading[i]) return true;
	}

	return false;
}

bool:isFinishedLoading()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if (!IsClientInGame(i) && !IsFakeClient(i))
			{
				clientTimeout[i]++;
				if (isClientLoading[i])
				{
					if (clientTimeout[i] == 1)
					{
						isClientLoading[i] = true;
					}
				}
				
				if (clientTimeout[i] == 90)
				{
					isClientLoading[i] = false;
				}
			}
			else
			{
				isClientLoading[i] = false;
			}
		}
		
		else isClientLoading[i] = false;
	}
	
	return !isAnyClientLoading();
}

bool:isClientValid(client)
{ 	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	if (!IsClientInGame(client)) return false;
	if (IsFakeClient(client)) return false;
	return true;
}

bool:isCountDownStoppedOrRunning()
{
	return countDown != 0;
}

