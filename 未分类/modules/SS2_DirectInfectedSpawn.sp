/*
	The base functionality of this code was written by ShadowSyn, using ProdigySim's gamedata
	(https://forums.alliedmods.net/showthread.php?t=320849)
	- The program flow has been restructured to support a spawn function that can be passed position and angular coordinates
	- The spawn commands have been rewritten for debugging purposes
	- version cvar and game engine checking have been removed
	- set g_isSequel = true, as this is written purely for L4D2
*/
#include <adminmenu>

#pragma semicolon 1

TopMenu hTopMenu;

// Infected models
#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"
#define MODEL_TANK "models/infected/hulk.mdl"
#define MODEL_WITCH "models/infected/witch.mdl"
#define MODEL_WITCHBRIDE "models/infected/witch_bride.mdl"

#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

#define GAMEDATA "spawn_infected_nolimit"

#define DIRECTOR_CLASS "info_director"
#define DIRECTOR_ENT "plugin_director_ent_do_not_use"
#define BRIDE_WITCH_TARGETNAME "plugin_dzs_bride"

Handle hConf = null;

static Handle hCreateSmoker = null;
#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
#define SIG_CreateSmoker_LINUX "@_Z22NextBotCreatePlayerBotI6SmokerEPT_PKc"
#define SIG_CreateSmoker_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x10"
static Handle hCreateBoomer = null;
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
#define SIG_CreateBoomer_LINUX "@_Z22NextBotCreatePlayerBotI6BoomerEPT_PKc"
#define SIG_CreateBoomer_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x30"
static Handle hCreateHunter = null;
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
#define SIG_CreateHunter_LINUX "@_Z22NextBotCreatePlayerBotI6HunterEPT_PKc"
#define SIG_CreateHunter_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\xD0"
static Handle hCreateSpitter = null;
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
#define SIG_CreateSpitter_LINUX "@_Z22NextBotCreatePlayerBotI7SpitterEPT_PKc"
#define SIG_CreateSpitter_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x00"
static Handle hCreateJockey = null;
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
#define SIG_CreateJockey_LINUX "@_Z22NextBotCreatePlayerBotI6JockeyEPT_PKc"
#define SIG_CreateJockey_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x70\\x90"
static Handle hCreateCharger = null;
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
#define SIG_CreateCharger_LINUX "@_Z22NextBotCreatePlayerBotI7ChargerEPT_PKc"
#define SIG_CreateCharger_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\x40"
static Handle hCreateTank = null;
#define NAME_CreateTank "NextBotCreatePlayerBot<Tank>"
#define SIG_CreateTank_LINUX "@_Z22NextBotCreatePlayerBotI4TankEPT_PKc"
#define SIG_CreateTank_WINDOWS "\\x55\\x8B\\x2A\\x83\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x57\\x8B\\x2A\\x2A\\x68\\xF0"

#define SIG_L4D1CreateSmoker_WINDOWS "\\x83\\x2A\\x2A\\x56\\x57\\x68\\x20\\xED"
#define SIG_L4D1CreateBoomer_WINDOWS "\\x83\\x2A\\x2A\\x56\\x57\\x68\\x10"
#define SIG_L4D1CreateHunter_WINDOWS "\\x83\\x2A\\x2A\\x56\\x57\\x68\\x20\\x35"
#define SIG_L4D1CreateTank_WINDOWS "\\x83\\x2A\\x2A\\x56\\x57\\x68\\x80"

/*static Handle hRoundRespawn = null;
#define NAME_RoundRespawn "CTerrorPlayer::RoundRespawn"
#define SIG_RoundRespawn_LINUX "@_ZN13CTerrorPlayer12RoundRespawnEv"
#define SIG_RoundRespawn_WINDOWS "\\x56\\x8B\\x2A\\xE8\\xD8\\x16"
#define SIG_L4D1RoundRespawn_WINDOWS "\\x56\\x8B\\x2A\\xE8\\x18\\x04"*/

static Handle hInfectedAttackSurvivorTeam = null;
#define NAME_InfectedAttackSurvivorTeam "Infected::AttackSurvivorTeam"
#define SIG_InfectedAttackSurvivorTeam_LINUX "@_ZN8Infected18AttackSurvivorTeamEv"
#define SIG_InfectedAttackSurvivorTeam_WINDOWS "\\x56\\x2A\\x2A\\x2A\\x2A\\xE1\\x1C"

#define SIG_L4D1InfectedAttackSurvivorTeam_WINDOWS "\\x80\\xB9\\x99"

#define SPAWN_CMD "sm_dzspawn"
char spawnCmdDescription[128];
#define SPAWN_MENU_CMD "sm_mdzs"
char spawnMenuCmdDescription[128];

static bool g_isSequel = true;

/***********************************************************************************************************************************************************************************
     																			INITIALISATION                        
***********************************************************************************************************************************************************************************/

DirectInfectedSpawn_OnPluginStart()
{
	Format(spawnCmdDescription, sizeof(spawnCmdDescription), "%s <zombie> - Spawn a special infected, bypassing the limit enforced by the game.", SPAWN_CMD);
	Format(spawnMenuCmdDescription, sizeof(spawnMenuCmdDescription), "%s - Open a menu to spawn a special infected, bypassing the limit enforced by the game.", SPAWN_MENU_CMD);
	
	RegAdminCmd( SPAWN_CMD, Command_Spawn, ADMFLAG_CHEATS, spawnCmdDescription);
	RegAdminCmd( SPAWN_MENU_CMD, Command_SpawnMenu, ADMFLAG_CHEATS, spawnMenuCmdDescription);
	
	HookEvent("witch_harasser_set", witch_harasser_set, EventHookMode_Post);
	HookEvent("witch_killed", witch_killed, EventHookMode_Post);
	
	GetGamedata();
}

void CheckandPrecacheModel(const char[] model)
{
	if (!IsModelPrecached(model))
	{
		PrecacheModel(model, true);
	}
}

DirectInfectedSpawn_OnMapStart()
{
	CheckandPrecacheModel(MODEL_SMOKER);
	CheckandPrecacheModel(MODEL_BOOMER);
	CheckandPrecacheModel(MODEL_HUNTER);
	if (g_isSequel)
	{
		CheckandPrecacheModel(MODEL_SPITTER);
		CheckandPrecacheModel(MODEL_JOCKEY);
		CheckandPrecacheModel(MODEL_CHARGER);
		CheckandPrecacheModel(MODEL_WITCHBRIDE);
	}
	CheckandPrecacheModel(MODEL_TANK);
	CheckandPrecacheModel(MODEL_WITCH);
}

/***********************************************************************************************************************************************************************************
																				SPAWN CMD / SPAWN MENU                         
***********************************************************************************************************************************************************************************/

Action Command_SpawnMenu(int client, any args)
{
	if (client == 0)  
	{ 
		ReplyToCommand(client, "[SM] Menu is in-game only."); 
		return Plugin_Handled; 
	}
	
	Handle menu = CreateMenu(SpawnMenu_Handler);
	SetMenuTitle(menu, "Direct ZSpawn Menu");
	AddMenuItem(menu, "Smoker", "Smoker");
	AddMenuItem(menu, "Boomer", "Boomer");
	AddMenuItem(menu, "Hunter", "Hunter");
	if (g_isSequel)
	{
		AddMenuItem(menu, "Jockey", "Jockey");
		AddMenuItem(menu, "Spitter", "Spitter");
		AddMenuItem(menu, "Charger", "Charger");
	}
	AddMenuItem(menu, "Tank", "Tank");
	AddMenuItem(menu, "Witch", "Witch");
	if (g_isSequel)
	{ AddMenuItem(menu, "witch_bride", "Bride Witch"); }
	AddMenuItem(menu, "", "Common");
	AddMenuItem(menu, "chase", "Chasing Common");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int SpawnMenu_Handler(Handle menu, MenuAction action, int client, int param) 
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char zombie[12];
			GetMenuItem(menu, param, zombie, sizeof(zombie));
			SpawnLOS(client, zombie);
			Command_SpawnMenu(client, 0);
		}
		case MenuAction_Cancel:
		{
			if (param == MenuCancel_ExitBack && hTopMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

Action Command_Spawn(int client, any args)
{
	// Validating parameters
	if (!IsValidClient(client))
	{
		ReplyToCommand(client, "[SM] Invalid client! Unable to get position and angles!");
		return Plugin_Handled;
	}
	if (args > 1)
	{
		ReplyToCommand(client, "[SM] Usage: %s", spawnCmdDescription);
		return Plugin_Handled;
	}
	// Call SpawnLOS
	char zombie[128];
	GetCmdArg(1, zombie, sizeof(zombie));	
	KickDeadInfectedBots(client); 
	SpawnLOS(client, zombie);
	return Plugin_Handled;
}

void SpawnLOS (int client, const char[] zombie)
{
	// Spawn where survivor is looking
	float pos[3], ang[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, ang);
	TR_TraceRayFilter(pos, ang, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitPlayers, client);
	if(TR_DidHit(null))
	{
		TR_GetEndPosition(pos); // update desired location to where trace ray made a collision
	}
	else
	{
		PrintToChat(client, "[SM] Vector out of world geometry. Teleporting on origin instead");
	}
	ang[0] = 0.0;ang[2] = 0.0;
	int spawnedClient = CreateInfected(zombie, pos, ang);
	if (!IsValidEntity(spawnedClient)) 
	{
		LogError("SpawnLOS() function failed and returned %d", spawnedClient);	
	}	
}
bool TraceRayDontHitPlayers(int entity, int mask, any data)
{
	if(IsValidClient(data))
	{
		return false;
	}
	return true;
}

/***********************************************************************************************************************************************************************************
MECHANISM: TriggerSpawn() -> ProcessSpawn() -> CreateInfected()
TriggerSpawn()		- Uses SI class numbers for brevity, position and eye angles
ProcessSpawn()		- Translates class numbers to names
CreateInfected()	- Uses SI names(to differentiate witch and witch bride)
					- hooks directly into the inbuilt spawn commands
***********************************************************************************************************************************************************************************/

// Does not perform spawning; handles timing of spawn event 
void TriggerSpawn( L4D2_Infected:desiredClass, float pos[3], float ang[3])
{
	int kick = KickDeadInfectedBots();
	if (kick <= 0) // spawn immediately without delay
    {
   		ProcessSpawn(L4D2_Infected:desiredClass, pos, ang);
	} 
	else { // spawn on short delay
		DataPack data = CreateDataPack();
		data.WriteCell(_:desiredClass);
		data.WriteFloat(pos[0]);
		data.WriteFloat(pos[1]);
		data.WriteFloat(pos[2]);
		data.WriteFloat(ang[0]);
		data.WriteFloat(pos[1]);
		data.WriteFloat(pos[2]);
		CreateTimer(0.01, Timer_CreateInfected, data);
	}	
}

Action Timer_CreateInfected(Handle timer, DataPack data)
{
	int desiredClass;
	float pos[3];
	float ang[3];
	
	// Read data pack
	data.Reset();
	desiredClass = data.ReadCell(); 
	for (int i = 0; i < 3; ++i) // pos[3]
	{
		pos[i] = data.ReadCell();
	}
	for (int i = 0; i < 3; ++i) // ang[3]
	{
		ang[i] = data.ReadCell();
	}
	// Close data pack if necessary
	if (data != null)
	{ 
		CloseHandle(data);
	}
	
	ProcessSpawn(L4D2_Infected:desiredClass, pos, ang);
}

void ProcessSpawn (L4D2_Infected:desiredClass, float pos[3], float ang[3])
{
	int spawnedClient;
	switch (desiredClass)
	{
		case (L4D2Infected_Smoker):
		{
			spawnedClient = CreateInfected("smoker", pos, ang);
		}
		case (L4D2Infected_Boomer):
		{
			spawnedClient = CreateInfected("boomer", pos, ang);
		}
		case (L4D2Infected_Hunter):
		{
			spawnedClient = CreateInfected("hunter", pos, ang);
		}
		case (L4D2Infected_Spitter):
		{
			spawnedClient = CreateInfected("spitter", pos, ang);
		}
		case (L4D2Infected_Jockey):
		{
			spawnedClient = CreateInfected("jockey", pos, ang);
		}
		case (L4D2Infected_Charger):
		{
			spawnedClient = CreateInfected("charger", pos, ang);
		}
		case (L4D2Infected_Witch):
		{
			spawnedClient = CreateInfected("witch", pos, ang);
		}
		case (L4D2Infected_Tank):
		{
			spawnedClient = CreateInfected("tank", pos, ang);
		}
		default:
		{
			LogError("Spawn function was passed invalid class number %d", _:desiredClass);
		}		
	}
	if (!IsValidEntity(spawnedClient))
	{
		LogError("[ SS2_DirectInfectedSpawn ] - Failed to spawn SI class %d at position [%f, %f, %f]", _:desiredClass, pos[0], pos[1], pos[2]);
	}	
}

int CreateInfected(const char[] zomb, float[3] pos, float[3] ang)
{
	int bot = -1;	
	if (StrEqual(zomb, "witch", false) || (g_isSequel && StrEqual(zomb, "witch_bride", false)))
	{
		int witch = CreateEntityByName("witch");
		TeleportEntity(witch, pos, ang, NULL_VECTOR);
		DispatchSpawn(witch);
		ActivateEntity(witch);
		if (g_isSequel && StrEqual(zomb, "witch_bride", false))
		{
			SetEntityModel(witch, MODEL_WITCHBRIDE);
			//AssignPanicToWitch(witch);
			DispatchKeyValue(witch, "targetname", BRIDE_WITCH_TARGETNAME);
		}
		return witch;
	}
	else if (StrEqual(zomb, "smoker", false))
	{
		bot = SDKCall(hCreateSmoker, "Smoker");
		if (IsValidClient(bot)) SetEntityModel(bot, MODEL_SMOKER);
	}
	else if (StrEqual(zomb, "boomer", false))
	{
		bot = SDKCall(hCreateBoomer, "Boomer");
		if (IsValidClient(bot)) SetEntityModel(bot, MODEL_BOOMER);
	}
	else if (StrEqual(zomb, "hunter", false))
	{
		bot = SDKCall(hCreateHunter, "Hunter");
		if (IsValidClient(bot)) SetEntityModel(bot, MODEL_HUNTER);
	}
	else if (StrEqual(zomb, "spitter", false) && g_isSequel)
	{
		bot = SDKCall(hCreateSpitter, "Spitter");
		if (IsValidClient(bot)) SetEntityModel(bot, MODEL_SPITTER);
	}
	else if (StrEqual(zomb, "jockey", false) && g_isSequel)
	{
		bot = SDKCall(hCreateJockey, "Jockey");
		if (IsValidClient(bot)) SetEntityModel(bot, MODEL_JOCKEY);
	}
	else if (StrEqual(zomb, "charger", false) && g_isSequel)
	{
		bot = SDKCall(hCreateCharger, "Charger");
		if (IsValidClient(bot)) SetEntityModel(bot, MODEL_CHARGER);
	}
	else if (StrEqual(zomb, "tank", false))
	{
		bot = SDKCall(hCreateTank, "Tank");
		if (IsValidClient(bot)) SetEntityModel(bot, MODEL_TANK);
	}
	else
	{
		int infected = CreateEntityByName("infected");
		TeleportEntity(infected, pos, ang, NULL_VECTOR);
		DispatchSpawn(infected);
		ActivateEntity(infected);
		if (StrContains(zomb, "chase", false) > -1)
		{ CreateTimer(0.4, Timer_Chase, infected); }
		return infected;
	}
	
	if (IsValidClient(bot))
	{
		ChangeClientTeam(bot, 3);
		//SDKCall(hRoundRespawn, bot);
		SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
		SetEntProp(bot, Prop_Send, "movetype", 2);
		SetEntProp(bot, Prop_Send, "deadflag", 0);
		SetEntProp(bot, Prop_Send, "m_lifeState", 0);
		//SetEntProp(bot, Prop_Send, "m_fFlags", 129);
		SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
		SetEntProp(bot, Prop_Send, "m_zombieState", 0);
		DispatchSpawn(bot);
		ActivateEntity(bot);
		
		DataPack data = CreateDataPack();
		data.WriteFloat(pos[0]);
		data.WriteFloat(pos[1]);
		data.WriteFloat(pos[2]);
		data.WriteFloat(ang[1]);
		data.WriteCell(bot);
		RequestFrame(RequestFrame_SetPos, data); 
	}
	
	return bot;
}

Action Timer_Chase(Handle timer, int infected)
{
	if (!IsValidEntity(infected)) return;
	char class[64];
	GetEntityClassname(infected, class, sizeof(class));
	if (!StrEqual(class, "infected", false)) return;
	SDKCall(hInfectedAttackSurvivorTeam, infected);
}

void RequestFrame_SetPos(DataPack data)
{
	data.Reset();
	float pos0 = data.ReadFloat();
	float pos1 = data.ReadFloat();
	float pos2 = data.ReadFloat();
	float ang1 = data.ReadFloat();
	int bot = data.ReadCell();
	if (data != null)
	{ CloseHandle(data); }
	
	float pos[3];pos[0]=pos0;pos[1]=pos1;pos[2]=pos2;
	float ang[3];ang[0]=0.0;ang[1]=ang1;ang[2]=0.0;
	
	TeleportEntity(bot, pos, ang, NULL_VECTOR);
}

int KickDeadInfectedBots(int client=-1)
{
	int kicked_Bots = 0;
	for (int loopclient = 1; loopclient <= MaxClients; loopclient++)
	{
		if (!IsValidClient(loopclient)) continue;
		if (!IsInfected(loopclient) || !IsFakeClient(loopclient) || IsPlayerAlive(loopclient)) continue;
		KickClient(loopclient);
		kicked_Bots += 1;
	}
	if (kicked_Bots > 0 && IsValidClient(client))
	{ 
		PrintToChat(client, "Kicked %i bots.", kicked_Bots);
	}
	return kicked_Bots;
}

void GetGamedata()
{
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(filePath) )
	{
		hConf = LoadGameConfigFile(GAMEDATA); // For some reason this doesn't return null even for invalid files, so check they exist first.
	}
	else
	{
		PrintToServer("[SM] %s unable to get %s.txt gamedata file. Generating...", PLUGIN_NAME, GAMEDATA); 
		Handle fileHandle = OpenFile(filePath, "w");
		if (fileHandle == null)
		{ SetFailState("[SM] Couldn't generate gamedata file!"); }
		
		WriteFileLine(fileHandle, "\"Games\"");
		WriteFileLine(fileHandle, "{");
		WriteFileLine(fileHandle, "	\"left4dead\"");
		WriteFileLine(fileHandle, "	{");
		WriteFileLine(fileHandle, "		\"Signatures\"");
		WriteFileLine(fileHandle, "		{");
		/*
		WriteFileLine(fileHandle, "			\"%s\"", NAME_RoundRespawn);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_RoundRespawn_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1RoundRespawn_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_RoundRespawn_LINUX);
		WriteFileLine(fileHandle, "			}");
		*/
		WriteFileLine(fileHandle, "			\"%s\"", NAME_InfectedAttackSurvivorTeam);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_InfectedAttackSurvivorTeam_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1InfectedAttackSurvivorTeam_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_InfectedAttackSurvivorTeam_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateSmoker);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateSmoker_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1CreateSmoker_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateSmoker_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateBoomer);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateBoomer_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1CreateBoomer_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateBoomer_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateHunter);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateHunter_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1CreateHunter_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateHunter_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateTank);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateTank_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_L4D1CreateTank_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateTank_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "		}");
		WriteFileLine(fileHandle, "	}");
		WriteFileLine(fileHandle, "	\"left4dead2\"");
		WriteFileLine(fileHandle, "	{");
		WriteFileLine(fileHandle, "		\"Signatures\"");
		WriteFileLine(fileHandle, "		{");
		/*
		WriteFileLine(fileHandle, "			\"%s\"", NAME_RoundRespawn);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_RoundRespawn_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_RoundRespawn_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_RoundRespawn_LINUX);
		WriteFileLine(fileHandle, "			}");
		*/
		WriteFileLine(fileHandle, "			\"%s\"", NAME_InfectedAttackSurvivorTeam);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_InfectedAttackSurvivorTeam_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_InfectedAttackSurvivorTeam_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_InfectedAttackSurvivorTeam_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateSmoker);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateSmoker_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateSmoker_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateSmoker_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateBoomer);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateBoomer_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateBoomer_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateBoomer_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateHunter);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateHunter_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateHunter_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateHunter_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateSpitter);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateSpitter_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateSpitter_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateSpitter_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateJockey);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateJockey_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateJockey_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateJockey_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateCharger);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateCharger_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateCharger_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateCharger_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "			\"%s\"", NAME_CreateTank);
		WriteFileLine(fileHandle, "			{");
		WriteFileLine(fileHandle, "				\"library\"	\"server\"");
		WriteFileLine(fileHandle, "				\"linux\"	\"%s\"", SIG_CreateTank_LINUX);
		WriteFileLine(fileHandle, "				\"windows\"	\"%s\"", SIG_CreateTank_WINDOWS);
		WriteFileLine(fileHandle, "				\"mac\"		\"%s\"", SIG_CreateTank_LINUX);
		WriteFileLine(fileHandle, "			}");
		WriteFileLine(fileHandle, "		}");
		WriteFileLine(fileHandle, "	}");
		WriteFileLine(fileHandle, "}");
		
		CloseHandle(fileHandle);
		hConf = LoadGameConfigFile(GAMEDATA);
		if (hConf == null)
		{ SetFailState("[SM] Failed to load auto-generated gamedata file!"); }
		
		PrintToServer("[SM] %s successfully generated %s.txt gamedata file!", PLUGIN_NAME, GAMEDATA);
	}
	PrepSDKCall();
}

void LoadStringFromAdddress(Address addr, char[] buffer, int maxlength) {
	int i = 0;
	while(i < maxlength) {
		char val = LoadFromAddress(addr + view_as<Address>(i), NumberType_Int8);
		if(val == 0) {
			buffer[i] = 0;
			break;
		}
		buffer[i] = val;
		i++;
	}
	buffer[maxlength - 1] = 0;
}

Handle PrepCreateBotCallFromAddress(Handle hSiFuncTrie, const char[] siName) {
	Address addr;
	StartPrepSDKCall(SDKCall_Static);
	if (!GetTrieValue(hSiFuncTrie, siName, addr) || !PrepSDKCall_SetAddress(addr))
	{
		SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", siName);
		return null;
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	return EndPrepSDKCall();	
}

void PrepWindowsCreateBotCalls(Address jumpTableAddr) {
	Handle hInfectedFuncs = CreateTrie();
	// We have the address of the jump table, starting at the first PUSH instruction of the
	// PUSH mem32 (5 bytes)
	// CALL rel32 (5 bytes)
	// JUMP rel8 (2 bytes)
	// repeated pattern.
	
	// Each push is pushing the address of a string onto the stack. Let's grab these strings to identify each case.
	// "Hunter" / "Smoker" / etc.
	for(int i = 0; i < 7; i++) {
		// 12 bytes in PUSH32, CALL32, JMP8.
		Address caseBase = jumpTableAddr + view_as<Address>(i * 12);
		Address siStringAddr = view_as<Address>(LoadFromAddress(caseBase + view_as<Address>(1), NumberType_Int32));
		static char siName[32];
		LoadStringFromAdddress(siStringAddr, siName, sizeof(siName));

		Address funcRefAddr = caseBase + view_as<Address>(6); // 2nd byte of call, 5+1 byte offset.
		int funcRelOffset = LoadFromAddress(funcRefAddr, NumberType_Int32);
		Address callOffsetBase = caseBase + view_as<Address>(10); // first byte of next instruction after the CALL instruction
		Address nextBotCreatePlayerBotTAddr = callOffsetBase + view_as<Address>(funcRelOffset);
		PrintToServer("Found NextBotCreatePlayerBot<%s>() @ %08x", siName, nextBotCreatePlayerBotTAddr);
		SetTrieValue(hInfectedFuncs, siName, nextBotCreatePlayerBotTAddr);
	}

	hCreateSmoker = PrepCreateBotCallFromAddress(hInfectedFuncs, "Smoker");
	if (hCreateSmoker == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSmoker); return; }

	hCreateBoomer = PrepCreateBotCallFromAddress(hInfectedFuncs, "Boomer");
	if (hCreateBoomer == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateBoomer); return; }

	hCreateHunter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Hunter");
	if (hCreateHunter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateHunter); return; }

	hCreateTank = PrepCreateBotCallFromAddress(hInfectedFuncs, "Tank");
	if (hCreateTank == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateTank); return; }
	
	hCreateSpitter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Spitter");
	if (hCreateSpitter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSpitter); return; }
	
	hCreateJockey = PrepCreateBotCallFromAddress(hInfectedFuncs, "Jockey");
	if (hCreateJockey == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateJockey); return; }

	hCreateCharger = PrepCreateBotCallFromAddress(hInfectedFuncs, "Charger");
	if (hCreateCharger == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateCharger); return; }
}

void PrepL4D2CreateBotCalls() {
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateSpitter))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSpitter); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateSpitter = EndPrepSDKCall();
		if (hCreateSpitter == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSpitter); return; }
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateJockey))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateJockey); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateJockey = EndPrepSDKCall();
		if (hCreateJockey == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateJockey); return; }
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateCharger))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateCharger); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateCharger = EndPrepSDKCall();
		if (hCreateCharger == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateCharger); return; }
}

void PrepL4D1CreateBotCalls() {
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateSmoker))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSmoker); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateSmoker = EndPrepSDKCall();
	if (hCreateSmoker == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSmoker); return; }
	
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateBoomer))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateBoomer); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateBoomer = EndPrepSDKCall();
	if (hCreateBoomer == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateBoomer); return; }
	
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateHunter))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateHunter); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateHunter = EndPrepSDKCall();
	if (hCreateHunter == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateHunter); return; }
	
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateTank))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateTank); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateTank = EndPrepSDKCall();
	if (hCreateTank == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateTank); return; }
}

void PrepSDKCall()
{
	if (hConf == null)
	{ SetFailState("Unable to find %s.txt gamedata.", GAMEDATA); return; }
	
	Address replaceWithBot = GameConfGetAddress(hConf, "NextBotCreatePlayerBot.jumptable");
	
	if (replaceWithBot != Address_Null && LoadFromAddress(replaceWithBot, NumberType_Int8) == 0x68) {
		// We're on L4D2 and linux
		PrepWindowsCreateBotCalls(replaceWithBot);
	}
	else
	{
		if (g_isSequel)
		{
			PrepL4D2CreateBotCalls();
		}
		else
		{ delete hCreateSpitter; delete hCreateJockey; delete hCreateCharger; }
	
		PrepL4D1CreateBotCalls();
	}
	
	/*StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_RoundRespawn))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_RoundRespawn); return; }
	hRoundRespawn = EndPrepSDKCall();
	if (hRoundRespawn == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_RoundRespawn); return; }*/
	
	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_InfectedAttackSurvivorTeam))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_InfectedAttackSurvivorTeam); return; }
	hInfectedAttackSurvivorTeam = EndPrepSDKCall();
	if (hInfectedAttackSurvivorTeam == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_InfectedAttackSurvivorTeam); return; }
}


/***********************************************************************************************************************************************************************************
     																			UTIL                     
***********************************************************************************************************************************************************************************/

void witch_harasser_set(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (!IsValidEntity(witch) || witch <= 0) return;
	
	char witchName[64];
	GetEntPropString(witch, Prop_Data, "m_iName", witchName, sizeof(witchName));
	if (!StrEqual(witchName, BRIDE_WITCH_TARGETNAME, false)) return;
	
	int dir_ent = CheckForDirectorEnt();
	if (!IsValidEntity(dir_ent) || dir_ent <= 0) return;
	
	PrintToServer("Bride startled");
	
	DispatchKeyValue(witch, "targetname", "");
	AcceptEntityInput(dir_ent, "ForcePanicEvent");
}

void witch_killed(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (!IsValidEntity(witch) || witch <= 0) return;
	
	char witchName[64];
	GetEntPropString(witch, Prop_Data, "m_iName", witchName, sizeof(witchName));
	if (!StrEqual(witchName, BRIDE_WITCH_TARGETNAME, false)) return;
	
	int dir_ent = CheckForDirectorEnt();
	if (!IsValidEntity(dir_ent) || dir_ent <= 0) return;
	
	//if (!event.GetBool("oneshot")) return;
	
	PrintToServer("Bride killed");
	
	DispatchKeyValue(witch, "targetname", "");
	AcceptEntityInput(dir_ent, "ForcePanicEvent");
}

int CheckForDirectorEnt()
{
	int result = FindEntityByClassname(-1, DIRECTOR_CLASS);
	if (!IsValidEntity(result) || result <= 0)
	{
		result = CreateEntityByName(DIRECTOR_CLASS);
		DispatchSpawn(result);
		ActivateEntity(result);
	}
	return result;
}
