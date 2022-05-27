//# vim: set filetype=cpp :

/*
ABM a SourceMod L4D2 Plugin
Copyright (C) 2016-2017  Victor "NgBUCKWANGS" Gonzalez

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the

Free Software Foundation, Inc.
51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1
#pragma newdecls required
#undef REQUIRE_EXTENSIONS
#include <left4dhooks>

#define PLUGIN_VERSION "0.1.98 Shadowysn"
#define LOGFILE "addons/sourcemod/logs/abm.log"  // TODO change this to DATE/SERVER FORMAT?

// This controls the edits needed for my own use. Usually set to 0 for public releases
#define SHADOWYSN_EDIT 0

Handle g_GameData = null;
ArrayList g_sQueue;
ArrayList g_iQueue;

// menu parameters
#define menuArgs g_menuItems[client]	 // Global argument tracking for the menu system
#define menuArg0 g_menuItems[client][0]  // GetItem(1...)
#define menuArg1 g_menuItems[client][1]  // GetItem(2...)
int g_menuItems[MAXPLAYERS + 1][2];

// menu tracking
#define g_callBacks g_menuStack[client]
ArrayStack g_menuStack[MAXPLAYERS + 1];
Function callBack;

char g_QKey[64];	  // holds players by STEAM_ID
StringMap g_QDB;	  // holds player records linked by STEAM_ID
StringMap g_QRecord;  // changes to an individual STEAM_ID mapping
StringMap g_QRtmp;	// temporary QRecord holder for checking records without changing the main
StringMap g_Cvars;	// locked cvars end up here

//char g_InfectedNames[6];
//char g_SurvivorNames[8];
//char g_SurvivorPaths[8];
ArrayList g_InfectedNames;
ArrayList g_SurvivorNames;
ArrayList g_SurvivorPaths;

#define MAX_INF_NAMESIZE 8
#define MAX_SURV_NAMESIZE 10
#define MAX_SURV_MDLSIZE 64

#define MODEL_BILL "models/survivors/survivor_namvet.mdl"
#define MODEL_ZOEY "models/survivors/survivor_teenangst.mdl"
#define MODEL_FRANCIS "models/survivors/survivor_biker.mdl"
#define MODEL_LOUIS "models/survivors/survivor_manager.mdl"

int g_OS;						   // 0: Linux, 1: Windows (Prevent crash on Windows /w Zoey)
char g_sB[512];					 // generic catch all string buffer
char g_pN[128];					 // a dedicated buffer to storing a players name
int g_client, g_tmpClient;		  // g_QDB client id
int g_target, g_tmpTarget;		  // g_QDB player (human or bot) id
int g_lastid, g_tmpLastid;		  // g_QDB client's last known bot id
int g_onteam, g_tmpOnteam = 1;	  // g_QDB client's team
bool g_queued, g_tmpQueued;		 // g_QDB client's takeover state
bool g_inspec, g_tmpInspec;		 // g_QDB check client's specator mode
bool g_status, g_tmpStatus;		 // g_QDB client life state
bool g_update, g_tmpUpdate;		 // g_QDB should we update this record?
char g_model[64], g_tmpModel[64];   // g_QDB client's model
float g_origin[3], g_tmpOrigin[3];  // g_QDB client's origin vector
int g_models[8];

Handle g_ADAssistant;			   // Tries to make sure the AD starts
Handle g_AD;						// Assistant Director Timer
int g_survivorSet;				  // 0 = l4d2 survivors, 4 = l4d1 survivors
bool g_survivorSetScan;			 // Check to discover the survivor set

bool g_IsVs;
bool g_IsCoop;
bool g_AssistedSpawning = false;
bool g_ADFreeze = true;
int g_ADInterval;

ConVar g_cvVersion;										 // abm_version
ConVar g_cvLogLevel; int g_LogLevel;						// abm_loglevel
ConVar g_cvMinPlayers; int g_MinPlayers;					// abm_minplayers
ConVar g_cvPrimaryWeapon; char g_PrimaryWeapon[64];		 // abm_primaryweapon
ConVar g_cvSecondaryWeapon; char g_SecondaryWeapon[64];	 // abm_secondaryweapon
ConVar g_cvThrowable; char g_Throwable[64];				 // abm_throwable
ConVar g_cvHealItem; char g_HealItem[64];				   // abm_healitem
ConVar g_cvConsumable; char g_Consumable[64];			   // abm_consumable
ConVar g_cvExtraPlayers; int g_ExtraPlayers;				// abm_extraplayers
ConVar g_cvTankChunkHp; int g_TankChunkHp;				  // abm_tankchunkhp
ConVar g_cvSpawnInterval; int g_SpawnInterval;			  // abm_spawninterval
ConVar g_cvAutoHard; int g_AutoHard;						// abm_autohard
ConVar g_cvUnlockSI; int g_UnlockSI;						// abm_unlocksi
ConVar g_cvJoinMenu; int g_JoinMenu;						// abm_joinmenu
ConVar g_cvTeamLimit; int g_TeamLimit;					  // abm_teamlimit
ConVar g_cvOfferTakeover; int g_OfferTakeover;			  // abm_offertakeover
ConVar g_cvStripKick; int g_StripKick;					  // abm_stripkick
ConVar g_cvKeepDead; int g_KeepDead;						// abm_keepdead
ConVar g_cvIdentityFix; int g_IdentityFix;				  // abm_identityfix
ConVar g_cvMaxSI; int g_MaxSI;							  // z_max_player_zombies

// L4D2 only
ConVar g_cvAutoModel; int g_AutoModel;					  // abm_automodel
ConVar g_cvZoey; int g_Zoey;							// abm_zoey

ConVar g_cvTankHealth;
ConVar g_cvDvarsHandle;
ConVar g_cvMaxSwitches;
ConVar g_cvGameMode;

static char g_DvarsOriginStr[2048];  // will get lost to an sm plugins reload abm
static bool g_DvarsCheck;

static bool g_isSequel = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() == Engine_Left4Dead)
	{
		return APLRes_Success;
	}
	else if (GetEngineVersion() == Engine_Left4Dead2)
	{
		g_isSequel = true;
		return APLRes_Success;
	}
	strcopy(error, err_max, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");
	return APLRes_SilentFailure;
}

public Plugin myinfo =
{
	name = "ABM",
	author = "Victor \"NgBUCKWANGS\" Gonzalez",
	description = "A 5+ Player Enhancement Plugin for L4D2",
	version = PLUGIN_VERSION,
	url = "https://gitlab.com/vbgunz/ABM"
}

public void OnPluginStart() {
	Echo(2, "OnPluginStart");

	g_GameData = LoadGameConfigFile("abm");
	if (g_GameData == null) {
		SetFailState("[ABM] Game data missing!");
	}
	
	g_InfectedNames = new ArrayList(MAX_INF_NAMESIZE, 3);
	g_SurvivorNames = new ArrayList(MAX_SURV_NAMESIZE, 4);
	g_SurvivorPaths = new ArrayList(MAX_SURV_MDLSIZE, 4);
	
	g_InfectedNames.SetString(0, "Boomer");
	g_InfectedNames.SetString(1, "Smoker");
	g_InfectedNames.SetString(2, "Hunter");
	
	if (g_isSequel)
	{
		g_InfectedNames.PushString("Spitter");
		g_InfectedNames.PushString("Jockey");
		g_InfectedNames.PushString("Charger");
		
		g_SurvivorNames.SetString(0, "Nick");
		g_SurvivorNames.SetString(1, "Rochelle");
		g_SurvivorNames.SetString(2, "Coach");
		g_SurvivorNames.SetString(3, "Ellis");
		g_SurvivorNames.PushString("Bill");
		g_SurvivorNames.PushString("Zoey");
		g_SurvivorNames.PushString("Francis");
		g_SurvivorNames.PushString("Louis");
		
		g_SurvivorPaths.SetString(0, "models/survivors/survivor_gambler.mdl");
		g_SurvivorPaths.SetString(1, "models/survivors/survivor_producer.mdl");
		g_SurvivorPaths.SetString(2, "models/survivors/survivor_coach.mdl");
		g_SurvivorPaths.SetString(3, "models/survivors/survivor_mechanic.mdl");
		g_SurvivorPaths.PushString(MODEL_BILL);
		g_SurvivorPaths.PushString(MODEL_ZOEY);
		g_SurvivorPaths.PushString(MODEL_FRANCIS);
		g_SurvivorPaths.PushString(MODEL_LOUIS);
	}
	else
	{
		g_SurvivorNames.SetString(0, "Bill");
		g_SurvivorNames.SetString(1, "Zoey");
		g_SurvivorNames.SetString(2, "Francis");
		g_SurvivorNames.SetString(3, "Louis");
		
		g_SurvivorPaths.SetString(0, MODEL_BILL);
		g_SurvivorPaths.SetString(1, MODEL_ZOEY);
		g_SurvivorPaths.SetString(2, MODEL_FRANCIS);
		g_SurvivorPaths.SetString(3, MODEL_LOUIS);
	}
	
	/*strcopy(g_InfectedNames[0], 6, "Boomer");
	strcopy(g_InfectedNames[1], 6, "Smoker");
	strcopy(g_InfectedNames[2], 6, "Hunter");
	if (!g_isSequel)
	{
		strcopy(g_SurvivorNames[0], 4, "Bill");
		strcopy(g_SurvivorNames[1], 4, "Zoey");
		strcopy(g_SurvivorNames[2], 7, "Francis");
		strcopy(g_SurvivorNames[3], 5, "Louis");
		
		strcopy(g_SurvivorPaths[0], 64, MODEL_BILL);
		strcopy(g_SurvivorPaths[1], 64, MODEL_ZOEY);
		strcopy(g_SurvivorPaths[2], 64, MODEL_FRANCIS);
		strcopy(g_SurvivorPaths[3], 64, MODEL_LOUIS);
	}
	else
	{
		strcopy(g_InfectedNames[3], 7, "Spitter");
		strcopy(g_InfectedNames[4], 6, "Jockey");
		strcopy(g_InfectedNames[5], 7, "Charger");
		
		strcopy(g_SurvivorNames[0], 4, "Nick");
		strcopy(g_SurvivorNames[1], 8, "Rochelle");
		strcopy(g_SurvivorNames[2], 5, "Coach");
		strcopy(g_SurvivorNames[3], 5, "Ellis");
		strcopy(g_SurvivorNames[4], 4, "Bill");
		strcopy(g_SurvivorNames[5], 4, "Zoey");
		strcopy(g_SurvivorNames[6], 7, "Francis");
		strcopy(g_SurvivorNames[7], 5, "Louis");
		
		strcopy(g_SurvivorPaths[0], 64, "models/survivors/survivor_gambler.mdl");
		strcopy(g_SurvivorPaths[1], 64, "models/survivors/survivor_producer.mdl");
		strcopy(g_SurvivorPaths[2], 64, "models/survivors/survivor_coach.mdl");
		strcopy(g_SurvivorPaths[3], 64, "models/survivors/survivor_mechanic.mdl");
		strcopy(g_SurvivorPaths[4], 64, MODEL_BILL);
		strcopy(g_SurvivorPaths[5], 64, MODEL_ZOEY);
		strcopy(g_SurvivorPaths[6], 64, MODEL_FRANCIS);
		strcopy(g_SurvivorPaths[7], 64, MODEL_LOUIS);
	}*/

	HookEvent("player_first_spawn", OnSpawnHook);
	HookEvent("player_spawn", OnAllSpawnHook);
	HookEvent("player_death", OnDeathHook, EventHookMode_Pre);
	HookEvent("player_disconnect", CleanQDBHook);
	HookEvent("player_afk", GoIdleHook);
	HookEvent("player_team", QTeamHook);
	HookEvent("player_bot_replace", QAfkHook);
	HookEvent("bot_player_replace", QBakHook);
	HookEvent("player_activate", PlayerActivateHook, EventHookMode_Pre);
	HookEvent("player_connect", PlayerActivateHook, EventHookMode_Pre);
	HookEvent("round_end", RoundFreezeEndHook, EventHookMode_Pre);
	HookEvent("mission_lost", RoundFreezeEndHook, EventHookMode_Pre);
	HookEvent("round_freeze_end", RoundFreezeEndHook, EventHookMode_Pre);
	HookEvent("map_transition", RoundFreezeEndHook, EventHookMode_Pre);
	HookEvent("round_start", RoundStartHook, EventHookMode_Pre);

	RegAdminCmd("abm", MainMenuCmd, ADMFLAG_GENERIC);
	RegAdminCmd("abm-menu", MainMenuCmd, ADMFLAG_GENERIC, "Menu: (Main ABM menu)");
	RegAdminCmd("abm-join", SwitchTeamCmd, ADMFLAG_GENERIC, "Menu/Cmd: <TEAM> | <ID> <TEAM>");
	RegAdminCmd("abm-takeover", SwitchToBotCmd, ADMFLAG_GENERIC, "Menu/Cmd: <ID> | <ID1> <ID2>");
	RegAdminCmd("abm-respawn", RespawnClientCmd, ADMFLAG_GENERIC, "Menu/Cmd: <ID> [ID]");
	RegAdminCmd("abm-model", AssignModelCmd, ADMFLAG_GENERIC, "Menu/Cmd: <MODEL> | <MODEL> <ID>");
	RegAdminCmd("abm-strip", StripClientCmd, ADMFLAG_GENERIC, "Menu/Cmd: <ID> [SLOT]");
	RegAdminCmd("abm-teleport", TeleportClientCmd, ADMFLAG_GENERIC, "Menu/Cmd: <ID1> <ID2>");
	RegAdminCmd("abm-cycle", CycleBotsCmd, ADMFLAG_GENERIC, "Menu/Cmd: <TEAM> | <ID> <TEAM>");
	RegAdminCmd("abm-reset", ResetCmd, ADMFLAG_GENERIC, "Cmd: (Use only in case of emergency)");
	RegAdminCmd("abm-info", QuickClientPrintCmd, ADMFLAG_GENERIC, "Cmd: (Print some diagnostic information)");
	RegAdminCmd("abm-mk", MkBotsCmd, ADMFLAG_GENERIC, "Cmd: <N|-N> <TEAM>");
	RegAdminCmd("abm-rm", RmBotsCmd, ADMFLAG_GENERIC, "Cmd: <TEAM> | <N|-N> <TEAM>");
	RegConsoleCmd("takeover", SwitchToBotCmd, "Menu/Cmd: <ID> | <ID1> <ID2>");
	RegConsoleCmd("joingame", SwitchTeamCmd, "Menu/Cmd: <TEAM> | <ID> <TEAM>");


	#if SHADOWYSN_EDIT
	RegConsoleCmd("sm_joingame", TempJoinGame, "Join the game.");
	#endif

	g_OS = GetOS();  // 0: Linux 1: Windows
	g_QDB = new StringMap();
	g_QRecord = new StringMap();
	g_QRtmp = new StringMap();
	g_Cvars = new StringMap();
	g_sQueue = new ArrayList(2);
	g_iQueue = new ArrayList(2);

	g_cvTankHealth = FindConVar("z_tank_health");
	if (g_isSequel) g_cvDvarsHandle = FindConVar("l4d2_directoroptions_overwrite");
	g_cvMaxSwitches = FindConVar("vs_max_team_switches");
	g_cvGameMode = FindConVar("mp_gamemode");
	HookConVarChange(g_cvGameMode, UpdateConVarsHook);
	UpdateGameMode();

	g_cvMaxSI = FindConVar("z_max_player_zombies");
	SetConVarBounds(g_cvMaxSI, ConVarBound_Lower, true, 1.0);
	SetConVarBounds(g_cvMaxSI, ConVarBound_Upper, true, 24.0);

	SetupCvar(g_cvVersion, "abm_version", PLUGIN_VERSION, "ABM plugin version");
	SetupCvar(g_cvLogLevel, "abm_loglevel", "0", "Development logging level 0: Off, 4: Max");
	SetupCvar(g_cvMinPlayers, "abm_minplayers", "4", "Pruning extra survivors stops at this size");
	SetupCvar(g_cvExtraPlayers, "abm_extraplayers", "0", "Extra survivors to start the round with");
	SetupCvar(g_cvTankChunkHp, "abm_tankchunkhp", "2500", "Health chunk per survivor on 5+ missions");
	SetupCvar(g_cvSpawnInterval, "abm_spawninterval", "36", "SI full team spawn in (5 x N)");
	SetupCvar(g_cvAutoHard, "abm_autohard", "0", "0: Off 1: Non-Vs > 4 2: Non-Vs >= 1");
	SetupCvar(g_cvUnlockSI, "abm_unlocksi", "0", "0: Off 1: Use Left 4 DHooks 2: Use VScript Director Options Unlocker");
	SetupCvar(g_cvJoinMenu, "abm_joinmenu", "1", "0: Off 1: Admins only 2: Everyone");
	SetupCvar(g_cvTeamLimit, "abm_teamlimit", "4", "Humans on team limit");
	SetupCvar(g_cvOfferTakeover, "abm_offertakeover", "0", "0: Off 1: Survivors 2: Infected 3: All");
	SetupCvar(g_cvStripKick, "abm_stripkick", "0", "0: Don't strip removed bots 1: Strip removed bots");
	SetupCvar(g_cvKeepDead, "abm_keepdead", "0", "0: The dead return alive 1: the dead return dead");
	SetupCvar(g_cvIdentityFix, "abm_identityfix", "0", "0: Do not assign identities 1: Assign identities");

	switch (g_isSequel)
	{
		case true:
		{
			SetupCvar(g_cvPrimaryWeapon, "abm_primaryweapon", "smg", "5+ survivor primary weapon");
			SetupCvar(g_cvSecondaryWeapon,"abm_secondaryweapon", "", "5+ survivor secondary weapon, leave empty for default pistol or put in \'pistol\' for duals");
			SetupCvar(g_cvThrowable, "abm_throwable", "", "5+ survivor throwable item");
			SetupCvar(g_cvHealItem, "abm_healitem", "", "5+ survivor healing item");
			SetupCvar(g_cvConsumable, "abm_consumable", "", "5+ survivor consumable item");
			
			SetupCvar(g_cvAutoModel, "abm_automodel", "0", "1: Full set of survivors 0: Map set of survivors");
			g_AutoModel = 0;
			
			char zoeyId[2];
			switch (g_OS)
			{
				case 0: zoeyId = "5";  // 5 is the real Zoey
				case 1: zoeyId = "1";  // Zoey crashes Windows servers, 1 is Rochelle
			}
	
			SetupCvar(g_cvZoey, "abm_zoey", zoeyId, "0:Nick 1:Rochelle 2:Coach 3:Ellis 4:Bill 5:Zoey 6:Francis 7:Louis");
		}
		case false:
		{
			SetupCvar(g_cvPrimaryWeapon, "abm_primaryweapon", "smg", "5+ survivor primary weapon");
			SetupCvar(g_cvSecondaryWeapon,"abm_secondaryweapon", "", "5+ survivor secondary weapon, leave empty for default pistol or put in \'pistol\' for duals");
			SetupCvar(g_cvThrowable, "abm_throwable", "", "5+ survivor throwable item");
			SetupCvar(g_cvHealItem, "abm_healitem", "", "5+ survivor healing item");
			SetupCvar(g_cvConsumable, "abm_consumable", "", "5+ survivor consumable item");
		}
	}

	// clean out client menu stacks
	for (int i = 1; i <= MaxClients; i++) {
		g_menuStack[i] = new ArrayStack(128);
	}

	// Register everyone that we can find
	for (int i = 1; i <= MaxClients; i++) {
		SetQRecord(i, true);
	}

	AddCommandListener(CmdIntercept, "z_spawn");
	AddCommandListener(CmdIntercept, "z_spawn_old");
	AddCommandListener(CmdIntercept, "z_add");
	AutoExecConfig(true, "abm");
	StartAD();
}

#if SHADOWYSN_EDIT
Action TempJoinGame(int client, int args)
{
	if (!IsClientValid(client)) {
		return Plugin_Handled;
	}
	
	int onteam = GetClientTeam(client);
	
	if (onteam < 2 || onteam > 4)
	{
		if (AddSurvivor())
		{
			CreateTimer(0.5, TempJoinGameTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	return Plugin_Handled;
}

Action TempJoinGameTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsClientValid(client)) return Plugin_Continue;
	
	SwitchTeam(client, 2);
	return Plugin_Continue;
}
#endif

void SetupCvar(Handle &cvHandle, char[] name, char[] value, char[] details) {
	Echo(2, "SetupCvar: %s %s %s", name, value, details);

	cvHandle = CreateConVar(name, value, details);
	HookConVarChange(cvHandle, UpdateConVarsHook);
	UpdateConVarsHook(cvHandle, value, value);
}

Action CmdIntercept(int client, const char[] cmd, int args) {
	Echo(2, "CmdIntercept: %d %s %d", client, cmd, args);

	if (g_AssistedSpawning) {
		GhostsModeProtector(0);
		RequestFrame(GhostsModeProtector, 1);
	}

	return Plugin_Continue;
}

public void OnMapStart() {
	Echo(2, "OnMapStart:");
	PrecacheModels();
}

public void OnMapEnd() {
	Echo(2, "OnMapEnd:");

	StopAD();
	StringMapSnapshot keys = g_QDB.Snapshot();
	g_iQueue.Clear();
	g_sQueue.Clear();

	for (int i; i < keys.Length; i++) {
		keys.GetKey(i, g_sB, sizeof(g_sB));
		g_QDB.GetValue(g_sB, g_QRecord);

		g_QRecord.GetValue("onteam", g_onteam);
		g_QRecord.GetValue("client", g_client);
		g_QRecord.GetValue("target", g_target);
		g_QRecord.SetValue("status",true,true);

		if (g_onteam >= 2) {
			g_QRecord.SetValue("inspec", false, true);
		}

		if (g_IsVs) {
			g_QRecord.SetString("model", "", true);
		}

		else if (g_onteam == 3) {
			SwitchToSpec(g_client);
			g_QRecord.SetValue("queued", true, true);
			g_QRecord.SetString("model", "", true);
		}
	}

	delete keys;
}

public void OnEntityCreated(int ent, const char[] clsName) {
	Echo(2, "OnEntityCreated: %d %s", ent, clsName);

	if (clsName[0] == 'f') {
		bool gClip = strncmp(clsName, "func_playerghostinfected_clip", 29, false) != 0;
		bool iClip = strncmp(clsName, "func_playerinfected_clip", 24, false) != 0;

		if (!(gClip && iClip)) {
			CreateTimer(2.0, KillEntTimer, EntIndexToEntRef(ent));
		}
	}

	else if (clsName[0] == 's' && strncmp(clsName, "survivor_bot", 12, false) == 0) {
		SDKHook(ent, SDKHook_SpawnPost, AutoModel);
	}
}

Action KillEntTimer(Handle timer, any ref) {
	Echo(2, "KillEntTimer: %d", ref);

	int ent = EntRefToEntIndex(ref);
	if (ent != INVALID_ENT_REFERENCE || IsEntityValid(ent)) {
		AcceptEntityInput(ent, "kill");
	}

	return Plugin_Stop;
}

bool checkScrVal = true;
void UpdateScriptValueCheck()
{ checkScrVal = true; }

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) {
	Echo(5, "L4D_OnGetScriptValueInt: %s, %d", key, retVal);

	// see UpdateConVarsHook "g_UnlockSI" for VScript Director Options Unlocker

	if (g_UnlockSI == 1) {
		int val = retVal;
		
		static int pinners = 1, supporters = 1;
		int surv_count = 0;
		if (checkScrVal)
		{
			checkScrVal = false;
			surv_count = CountTeamMates(2, 2, true);
			
			if (surv_count > 4)
			{
				supporters = RoundToFloor((surv_count/2.5)+0.0);
				pinners = RoundToFloor((surv_count/3)+0.0);
				/*if (surv_count % 2 != 0) 
				{
					pinners--;
				}*/
			}
			else
			{ surv_count = 0; pinners = 1; supporters = 1; }
		}

		if (strncmp(key, "MaxSpecials", 11) == 0) val = g_MaxSI;
		/*#if SHADOWYSN_EDIT
		else if (strncmp(key, "BoomerLimit", 11) == 0) val = 2;
		else if (strncmp(key, "SmokerLimit", 11) == 0) val = 2;
		else if (strncmp(key, "HunterLimit", 11) == 0) val = 2;
		else if (strncmp(key, "ChargerLimit", 12) == 0) val = 2;
		else if (strncmp(key, "SpitterLimit", 12) == 0) val = 2;
		else if (strncmp(key, "JockeyLimit", 11) == 0) val = 2;
		#else
		else if (strncmp(key, "BoomerLimit", 11) == 0) val = 4;
		else if (strncmp(key, "SmokerLimit", 11) == 0) val = 4;
		else if (strncmp(key, "HunterLimit", 11) == 0) val = 4;
		else if (strncmp(key, "ChargerLimit", 12) == 0) val = 4;
		else if (strncmp(key, "SpitterLimit", 12) == 0) val = 4;
		else if (strncmp(key, "JockeyLimit", 11) == 0) val = 4;
		#endif*/
		else if (strncmp(key, "BoomerLimit", 11) == 0) val = supporters;
		else if (strncmp(key, "SmokerLimit", 11) == 0) val = pinners;
		else if (strncmp(key, "HunterLimit", 11) == 0) val = pinners;
		else if (strncmp(key, "ChargerLimit", 12) == 0) val = pinners;
		else if (strncmp(key, "SpitterLimit", 12) == 0) val = supporters;
		else if (strncmp(key, "JockeyLimit", 11) == 0) val = pinners;

		//PrintToServer("surv_count: %i\nsupporters: %i\npinners: %i", surv_count, supporters, pinners);

		if (val != retVal) {
			retVal = val;
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

void RoundFreezeEndHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "RoundFreezeEndHook: %s", name);
	OnMapEnd();
}

void PlayerActivateHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "PlayerActivateHook: %s", name);

	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	PlayerActivate(client);
}

void PlayerActivate(int client) {
	Echo(2, "PlayerActivate: %d", client);

	if (GetQRecord(client)) {
		g_QRecord.SetString("model", "", true);
		StartAD();

		if (!g_IsVs && g_onteam == 3) {
			SwitchTeam(client, 3);
		}
	}
}

int GetRealClient(int client) {
	Echo(2, "GetRealClient: %d", client);

	if (IsClientValid(client, 0)) {
		if (HasEntProp(client, Prop_Send, "m_humanSpectatorUserID")) {
			int userid = GetEntProp(client, Prop_Send, "m_humanSpectatorUserID");
			int target = GetClientOfUserId(userid);

			if (IsClientValid(target)) {
				client = target;
			}

			else {
				for (int i = 1; i <= MaxClients; i++) {
					if (GetQRtmp(i) && g_tmpTarget == client) {
						client = i;
						break;
					}
				}
			}
		}
	}

	else {
		client = 0;
	}

	return client;
}

Action LifeCheckTimer(Handle timer, int target) {
	Echo(2, "LifeCheckTimer: %d", target);

	if (GetQRecord(GetRealClient(target))) {
		int status = IsPlayerAlive(target);

		switch (g_model[0] != EOS) {
			case true: AssignModel(target, g_model, g_IdentityFix);
			case false: {
				GetBotCharacter(target, g_model);
				g_QRecord.SetString("model", g_model, true);
				Echo(1, "--0: %N is model '%s'", g_client, g_model);
			}
		}

		g_QRecord.SetValue("status", status, true);
		AssignModel(g_client, g_model, g_IdentityFix);
	}
	return Plugin_Continue;
}

void OnAllSpawnHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "OnAllSpawnHook: %s", name);

	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	UpdateScriptValueCheck();
	if (IsClientValid(client)) {
		CreateTimer(0.5, LifeCheckTimer, client);
	}
}

void RoundStartHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "RoundStartHook: %s", name);
	StartAD();
	//CreateTimer(5.0, TempADTimer, _, TIMER_FLAG_NO_MAPCHANGE);

	for (int i = 1; i <= MaxClients; i++) {
		if (GetQRtmp(i)) {
			if (!g_IsVs && g_tmpOnteam == 3) {
				SwitchTeam(i, 3);
			}
		}
	}
}

/*Action TempADTimer(Handle timer) {
	if (g_AD == null) {
		StartAD();
	}
}*/

bool StopAD() {
	Echo(2, "StopAD");

	if (g_AD != null) {
		g_ADFreeze = true;
		g_AssistedSpawning = false;
		g_survivorSetScan = true;
		g_ADInterval = 0;

		KillTimer(g_AD); // delete causes errors?
		g_AD = null;
	}

	return g_AD == null;
}

bool StartAD(float interval=0.5) {
	Echo(2, "StartAD");

	if (g_ADAssistant == null) {
		g_ADAssistant = CreateTimer(0.1, StartADTimer, _, TIMER_REPEAT);
	}

	if (StopAD()) {
		g_AD = CreateTimer(interval, ADTimer, _, TIMER_REPEAT);
	}

	return g_AD != null;
}

Action StartADTimer(Handle timer) {
	Echo(6, "StartADTimer");

	if (g_AD == null) {
		StartAD();
		return Plugin_Continue;
	}

	g_ADAssistant = null;
	return Plugin_Stop;
}

bool AllClientsLoadedIn() {
	Echo(2, "AllClientsLoadedIn");

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && !IsClientInGame(i)) {
			return false;
		}
	}

	return true;
}

Action ADTimer(Handle timer) {
	Echo(6, "ADTimer");

	static int survivors, playQuota;
	survivors = CountTeamMates(2);

	if (survivors == 0) {
		return Plugin_Continue;
	}

	static bool takeover;
	takeover = !g_IsVs || (g_IsVs && !g_ADFreeze);
	playQuota = g_MinPlayers + g_ExtraPlayers;
	g_AssistedSpawning = false;

	for (int i = 1; i <= MaxClients; i++) {
		if (g_ADFreeze) {
			g_ADInterval = 0;

			if (CountTeamMates(2) >= 4 || AllClientsLoadedIn()) {
				while (CountTeamMates(2) < playQuota) {
					AddSurvivor();
				}

				if (AllClientsLoadedIn() && StartAD(5.0)) {
					RmBots(playQuota * -1, 2);
					g_ADFreeze = false;
				}
			}
		}

		if (IsClientValid(GetRealClient(i), 2, 0)) {
			if (IsPlayerAlive(i)) {
				_AutoModel(i);
			}
		}

		else if (GetQRtmp(i)) {

			//if (IsClientValid(g_tmpTarget, 2, 0)) {
			//	ResetClientSpecUserId(i, g_tmpTarget);
			//}

			if (!g_IsVs && g_tmpOnteam == 3) {
				g_AssistedSpawning = true;

				if (GetClientTeam(i) <= 1) {
					QueueUp(i, 3);
					SwitchTeam(i, 3);
				}
			}

			else if (!g_tmpInspec && GetClientTeam(i) <= 1) {
				if (takeover) {
					g_QRtmp.SetValue("onteam", 0,true);
					CreateTimer(0.1, TakeoverTimer, i);
				}
			}
		}
	}

	static int lastSize;
	bool autoWave;

	if (g_IsCoop) {
		if (lastSize != survivors) {
			lastSize = survivors;
			AutoSetTankHp();
			RegulateSI();
		}
	}

	// Auto difficulty here will not spawn SI in competitive modes.
	// SI are unlocked (without spawn) see L4D_OnGetScriptValueInt.

	switch (g_IsVs) {
		case true: autoWave = false;
		case false: autoWave = g_AutoHard == 2 || survivors > 4 && g_AutoHard == 1;
	}

	if (autoWave || g_AssistedSpawning) {
		if (g_SpawnInterval > 0) {
			if (g_ADInterval >= g_SpawnInterval) {
				if (g_ADInterval % g_SpawnInterval == 0) {
					Echo(2, " -- Assisting SI %d: Matching Full Team", g_ADInterval);
					MkBots(survivors * -1, 3);
				}

				else if (g_ADInterval % (g_SpawnInterval / 2) == 0) {
					Echo(2, " -- Assisting SI %d: Matching Half Team", g_ADInterval);
					MkBots((survivors / 2) * -1, 3);
				}
			}
		}
	}

	g_ADInterval++;
	return Plugin_Continue;
}

void UpdateConVarsHook(Handle convar, const char[] oldCv, const char[] newCv) {
	GetConVarName(convar, g_sB, sizeof(g_sB));
	Echo(2, "UpdateConVarsHook: %s %s %s", g_sB, oldCv, newCv);

	char name[32];
	char value[32];

	Format(name, sizeof(name), g_sB);
	Format(value, sizeof(value), "%s", newCv);
	TrimString(value);

	if (StrContains(newCv, "-l") == 0) {
		strcopy(value, sizeof(value), value[2]);
		TrimString(value);
		g_Cvars.SetString(name, value, true);
	}

	else if (StrContains(newCv, "-u") == 0) {
		strcopy(value, sizeof(value), value[2]);
		TrimString(value);
		g_Cvars.Remove(name);
	}

	g_Cvars.GetString(name, value, sizeof(value));
	if (strcmp(newCv, value) != 0) {
		SetConVarString(convar, value);
		return;
	}

	if (name[0] == 'a') {
		if (name[4] == 'a') {
			if (name[8] == 'h' && strcmp(name, "abm_autohard") == 0) {
				g_AutoHard = GetConVarInt(g_cvAutoHard);
				AutoSetTankHp();
			}

			else if (g_isSequel && name[8] == 'm' && strcmp(name, "abm_automodel") == 0) {
				g_AutoModel = GetConVarInt(g_cvAutoModel);
			}
		}

		else if (name[4] == 'c' && strcmp(name, "abm_consumable") == 0) {
			GetConVarString(g_cvConsumable, g_Consumable, sizeof(g_Consumable));
		}

		else if (name[4] == 'e' && strcmp(name, "abm_extraplayers") == 0) {
			g_ExtraPlayers = GetConVarInt(g_cvExtraPlayers);
		}

		else if (name[4] == 'h' && strcmp(name, "abm_healitem") == 0) {
			GetConVarString(g_cvHealItem, g_HealItem, sizeof(g_HealItem));
		}

		else if (name[4] == 'i' && strcmp(name, "abm_identityfix") == 0) {
			g_IdentityFix = GetConVarInt(g_cvIdentityFix);
		}

		else if (name[4] == 'j' && strcmp(name, "abm_joinmenu") == 0) {
			g_JoinMenu = GetConVarInt(g_cvJoinMenu);
		}

		else if (name[4] == 'k' && strcmp(name, "abm_keepdead") == 0) {
			g_KeepDead = GetConVarInt(g_cvKeepDead);
		}

		else if (name[4] == 'l' && strcmp(name, "abm_loglevel") == 0) {
			g_LogLevel = GetConVarInt(g_cvLogLevel);
		}

		else if (name[4] == 'm' && strcmp(name, "abm_minplayers") == 0) {
			g_MinPlayers = GetConVarInt(g_cvMinPlayers);
		}

		else if (name[4] == 'o' && strcmp(name, "abm_offertakeover") == 0) {
			g_OfferTakeover = GetConVarInt(g_cvOfferTakeover);
		}

		else if (name[4] == 'p' && strcmp(name, "abm_primaryweapon") == 0) {
			GetConVarString(g_cvPrimaryWeapon, g_PrimaryWeapon, sizeof(g_PrimaryWeapon));
		}

		else if (name[4] == 's') {
			if (name[5] == 'e' && strcmp(name, "abm_secondaryweapon") == 0) {
				GetConVarString(g_cvSecondaryWeapon, g_SecondaryWeapon, sizeof(g_SecondaryWeapon));
			}

			else if (name[5] == 'p' && strcmp(name, "abm_spawninterval") == 0) {
				g_SpawnInterval = GetConVarInt(g_cvSpawnInterval);
			}

			else if (name[5] == 't' && strcmp(name, "abm_stripkick") == 0) {
				g_StripKick = GetConVarInt(g_cvStripKick);
			}
		}

		else if (name[4] == 't') {
			if (name[5] == 'a' && strcmp(name, "abm_tankchunkhp") == 0) {
				g_TankChunkHp = GetConVarInt(g_cvTankChunkHp);
				AutoSetTankHp();
			}

			else if (name[5] == 'e' && strcmp(name, "abm_teamlimit") == 0) {
				g_TeamLimit = GetConVarInt(g_cvTeamLimit);
			}

			else if (name[5] == 'h' && strcmp(name, "abm_throwable") == 0) {
				GetConVarString(g_cvThrowable, g_Throwable, sizeof(g_Throwable));
			}
		}

		else if (name[4] == 'u' && strcmp(name, "abm_unlocksi") == 0) {
			g_UnlockSI = GetConVarInt(g_cvUnlockSI);
			RegulateSI();
		}

		else if (g_isSequel && name[4] == 'z' && strcmp(name, "abm_zoey") == 0) {
			g_Zoey = GetConVarInt(g_cvZoey);
		}
	}

	else if (name[0] == 'm' && strcmp(name, "mp_gamemode") == 0) {
		UpdateGameMode();
	}
}

int GetGameType() {
	Echo(2, "GetGameType");

	// 0: coop 1: versus 2: scavenge 3: survival
	GetConVarString(g_cvGameMode, g_sB, sizeof(g_sB));

	switch (g_sB[0]) {
		case 'c': {
			if (strcmp(g_sB, "coop") == 0) return 0;
			else if (strcmp(g_sB, "community1") == 0) return 0;  // Special Delivery
			else if (strcmp(g_sB, "community2") == 0) return 0;  // Flu Season
			else if (strcmp(g_sB, "community3") == 0) return 1;  // Riding My Survivor
			else if (strcmp(g_sB, "community4") == 0) return 3;  // Nightmare
			else if (strcmp(g_sB, "community5") == 0) return 0;  // Death's Door
		}

		case 'm': {
			if (strcmp(g_sB, "mutation1") == 0) return 0;		// Last Man on Earth
			else if (strcmp(g_sB, "mutation2") == 0) return 0;   // Headshot!
			else if (strcmp(g_sB, "mutation3") == 0) return 0;   // Bleed Out
			else if (strcmp(g_sB, "mutation4") == 0) return 0;   // Hard Eight
			else if (strcmp(g_sB, "mutation5") == 0) return 0;   // Four Swordsmen
			else if (strcmp(g_sB, "mutation7") == 0) return 0;   // Chainsaw Massacre
			else if (strcmp(g_sB, "mutation8") == 0) return 0;   // Ironman
			else if (strcmp(g_sB, "mutation9") == 0) return 0;   // Last Gnome on Earth
			else if (strcmp(g_sB, "mutation10") == 0) return 0;  // Room for One
			else if (strcmp(g_sB, "mutation11") == 0) return 1;  // Healthpackalypse
			else if (strcmp(g_sB, "mutation12") == 0) return 1;  // Realism Versus
			else if (strcmp(g_sB, "mutation13") == 0) return 2;  // Follow the Liter
			else if (strcmp(g_sB, "mutation14") == 0) return 0;  // Gib Fest
			else if (strcmp(g_sB, "mutation15") == 0) return 3;  // Versus Survival
			else if (strcmp(g_sB, "mutation16") == 0) return 0;  // Hunting Party
			else if (strcmp(g_sB, "mutation17") == 0) return 0;  // Lone Gunman
			else if (strcmp(g_sB, "mutation18") == 0) return 1;  // Bleed Out Versus
			else if (strcmp(g_sB, "mutation19") == 0) return 1;  // Taaannnkk!
			else if (strcmp(g_sB, "mutation20") == 0) return 0;  // Healing Gnome
		}

		case 'r': {
			if (strcmp(g_sB, "realism") == 0) return 0;
		}

		case 's': {
			if (strcmp(g_sB, "scavenge") == 0) return 2;
			else if (strcmp(g_sB, "survival") == 0) return 3;
		}

		case 't': {
			if (strcmp(g_sB, "teamscavenge") == 0) return 2;
			else if (strcmp(g_sB, "teamversus") == 0) return 1;
		}

		case 'v': {
			if (strcmp(g_sB, "versus") == 0) return 1;
		}
	}

	return -1;
}

void UpdateGameMode() {
	Echo(2, "UpdateGameMode");

	switch (GetGameType()) {
		case 0: {
			g_IsCoop = true;
			g_IsVs = false;
		}

		case 1, 2: {
			g_IsVs = true;
			g_IsCoop = false;
		}

		case 3: {
			g_IsVs = false;
			g_IsCoop = false;
		}
	}
}

void RegulateSI() {
	Echo(2, "RegulateSI");

	static int lastSISize;

	if (g_DvarsCheck && g_cvDvarsHandle != null) {
		if (g_UnlockSI == 2 && g_MaxSI > 4) {
			Format(g_sB, sizeof(g_sB), "MaxSpecials=%d;DominatorLimit=%d", g_MaxSI, g_MaxSI);
			SetConVarString(g_cvDvarsHandle, g_sB);

			if (lastSISize != g_MaxSI) {
				lastSISize = g_MaxSI;
			}
		}

		else {
			RestoreDvars();
			lastSISize = 0;
		}
	}
}

void RestoreDvars() {
	Echo(2, "RestoreDvars");

	if (g_DvarsCheck && g_cvDvarsHandle != null) {
		SetConVarString(g_cvDvarsHandle, g_DvarsOriginStr);
	}
}

void AutoSetTankHp() {
	Echo(2, "AutoSetTankHp");

	int tankHp;
	int teamSize = CountTeamMates(2);

	if (teamSize > 4 || g_AutoHard == 2) {
		tankHp = (teamSize-4) * g_TankChunkHp+6000;
	}

	#if SHADOWYSN_EDIT
	if (tankHp == 0)
	#else
	if (g_AutoHard == 0 || tankHp == 0)
	#endif
	{
		GetConVarDefault(g_cvTankHealth, g_sB, sizeof(g_sB));
		tankHp = StringToInt(g_sB);
	}

	SetConVarInt(g_cvTankHealth, tankHp);
}

public void OnConfigsExecuted() {
	Echo(2, "OnConfigsExecuted");

	if (!g_DvarsCheck) {
		g_DvarsCheck = true;

		if (g_cvDvarsHandle != null) {
			GetConVarString(g_cvDvarsHandle, g_DvarsOriginStr, sizeof(g_DvarsOriginStr));
			RegulateSI();
		}
	}

	/* TODO: look into also providing a simpler maintenance approach "abm_extend"?
	l4d2_tank_arena,l4d2_tank_challenge_15_rounds,l4d2_tank_challenge_20_rounds,\
	l4d2_tank_challenge_30_rounds,l4d2_tank_challenge,l4d2_tanksplayground_night,\
	l4d2_tanksplayground,tankyard:abm_unlocksi=0,abm_spawninterval=0,\
	abm_tankchunkhp=1000; */

	// extend the base cfg with a map specific cfg
	GetCurrentMap(g_sB, sizeof(g_sB));
	Format(g_sB, sizeof(g_sB), "cfg/sourcemod/abm/%s.cfg", g_sB);

	if (FileExists(g_sB, true)) {
		strcopy(g_sB, sizeof(g_sB), g_sB[4]);
		ServerCommand("exec \"%s\"", g_sB);
		Echo(1, "Extending ABM: %s", g_sB);
	}

	// some servers don't pick up on this automatically
	else if (FileExists("cfg/sourcemod/abm.cfg", true)) {
		ServerCommand("exec \"sourcemod/abm.cfg\"");
	}
}

public void OnClientPostAdminCheck(int client) {
	Echo(2, "OnClientPostAdminCheck: %d", client);

	if (!IsFakeClient(client)) {
		if (GetQRecord(client) && !g_update) {
			return;
		}

		if (IsAdmin(client) || !GetQRecord(client)) {
			SetQRecord(client, true);
		}

		else {
			int status = g_status;
			int onteam = g_onteam;

			if (SetQRecord(client, true) >= 0) {
				g_QRecord.SetValue("status", status, true);
				g_QRecord.SetValue("onteam", onteam, true);
			}
		}

		if (g_JoinMenu == 2 || g_JoinMenu == 1 && IsAdmin(client)) {
			GoIdle(client, 1);
			menuArg0 = client;
			SwitchTeamHandler(client, 1);
		}

		else if (CountTeamMates(2) >= 1) {
			CreateTimer(0.1, TakeoverTimer, client);
			CreateTimer(0.5, AutoIdleTimer, client, TIMER_REPEAT);
		}
	}
}

Action AutoIdleTimer(Handle timer, int client) {
	Echo(2, "AutoIdleTimer: %d", client);

	if (g_IsVs || !IsClientValid(client)) {
		return Plugin_Stop;
	}

	static int onteam;
	onteam = GetClientTeam(client);

	if (onteam >= 2) {
		if (onteam == 2) {
			GoIdle(client, 0);
		}

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void GoIdleHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "GoIdleHook: %s", name);
	int player = GetEventInt(event, "player");
	int client = GetClientOfUserId(player);

	if (GetQRecord(client)) {
		switch (g_onteam) {
			case 2: GoIdle(client);
			case 3: SwitchTeam(client, 3);
		}
	}
}

void GoIdle(int client, int onteam=0) {
	Echo(2, "GoIdle: %d %d", client, onteam);

	if (GetQRecord(client)) {
		int spec_target;

		if (g_onteam == 2) {
			SwitchToSpec(client);
			SetHumanSpecSig(g_target, client);

			if (onteam == 1) {
				SwitchToSpec(client);
				Unqueue(client);
			}

			AssignModel(g_target, g_model, g_IdentityFix);
		}

		else {
			SwitchToSpec(client);
		}

		if (g_onteam == 3 && onteam <= 1) {
			g_QRecord.SetString("model", "", true);
		}

		switch (IsClientValid(g_target, 0, 0)) {
			case true: spec_target = g_target;
			case false: spec_target = GetSafeSurvivor(client);
		}

		if (IsClientValid(spec_target)) {
			SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", spec_target);
			SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
		}
	}
}

void CleanQDBHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "CleanQDBHook: %s", name);

	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	RemoveQDBKey(client);
	
	UpdateScriptValueCheck();
}

void RemoveQDBKey(int client) {
	Echo(2, "RemoveQDBKey: %d", client);

	if (GetQRecord(client)) {
		g_QRecord.SetValue("update", true, true);
		g_QRecord.SetString("model", "", true);

		if (g_onteam == 2) {
			int survivors = CountTeamMates(2);
			if (survivors > (g_MinPlayers + g_ExtraPlayers)) {
				CreateTimer(1.0, RmBotsTimer, 1);
			}
		}
	}
}

Action RmBotsTimer(Handle timer, int asmany) {
	Echo(4, "RmBotsTimer: %d", asmany);

	if (!g_IsVs) {
		RmBots(asmany, 2);
	}
	return Plugin_Continue;
}

bool IsAdmin(int client) {
	Echo(2, "IsAdmin: %d", client);
	return CheckCommandAccess(
		client, "generic_admin", ADMFLAG_GENERIC, false
	);
}

bool IsEntityValid(int ent) {
	Echo(2, "IsEntityValid: %d", ent);
	return (ent > MaxClients && ent <= 2048 && IsValidEntity(ent));
}

bool IsClientValid(int client, int onteam=0, int mtype=2) {
	Echo(4, "IsClientValid: %d, %d, %d", client, onteam, mtype);

	if (client >= 1 && client <= MaxClients) {
		if (IsClientConnected(client)) {
			if (IsClientInGame(client)) {

				if (onteam != 0 && GetClientTeam(client) != onteam) {
					return false;
				}

				switch (mtype) {
					case 0: return IsFakeClient(client);
					case 1: return !IsFakeClient(client);
				}

				return true;
			}
		}
	}

	return false;
}

bool IsClientTank(int client)
{
	int zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (zClass == (g_isSequel ? 8 : 4)) return true;
	return false;
}

bool CanClientTarget(int client, int target) {
	Echo(2, "CanClientTarget: %d %d", client, target);

	if (client == target) {
		return true;
	}

	else if (!IsClientValid(client) || !IsClientValid(target)) {
		return false;
	}

	else if (IsFakeClient(target)) {
		int manager = GetClientManager(target);

		if (manager != -1) {
			if (manager == 0) {
				return true;
			}

			else {
				return CanClientTarget(client, manager);
			}
		}
	}

	return CanUserTarget(client, target);
}

int GetPlayClient(int client) {
	Echo(3, "GetPlayClient: %d", client);

	if (GetQRecord(client)) {
		return g_target;
	}

	else if (IsClientValid(client)) {
		return client;
	}

	return -1;
}

int ClientHomeTeam(int client) {
	Echo(2, "ClientHomeTeam: %d", client);

	if (GetQRecord(client)) {
		return g_onteam;
	}

	else if (IsClientValid(client)) {
		return GetClientTeam(client);
	}

	return -1;
}

// ================================================================== //
// g_QDB MANAGEMENT
// ================================================================== //

bool SetQKey(int client) {
	Echo(3, "SetQKey: %d", client);

	if (IsClientValid(client, 0, 1)) {
		if (GetClientAuthId(client, AuthId_Steam2, g_QKey, sizeof(g_QKey), true)) {
			return true;
		}
	}

	return false;
}

bool GetQRtmp(int client) {
	Echo(3, "GetQRtmp: %d", client);

	bool result;
	static char QKey[64];
	QKey = g_QKey;

	if (SetQKey(client)) {
		if (g_QDB.GetValue(g_QKey, g_QRtmp)) {

			if (IsClientValid(client) && IsPlayerAlive(client)) {
				GetClientAbsOrigin(client, g_tmpOrigin);
				g_QRtmp.SetArray("origin", g_tmpOrigin, sizeof(g_tmpOrigin), true);
			}

			g_QRtmp.GetValue("client", g_tmpClient);
			g_QRtmp.GetValue("target", g_tmpTarget);
			g_QRtmp.GetValue("lastid", g_tmpLastid);
			g_QRtmp.GetValue("onteam", g_tmpOnteam);
			g_QRtmp.GetValue("queued", g_tmpQueued);
			g_QRtmp.GetValue("inspec", g_tmpInspec);
			g_QRtmp.GetValue("status", g_tmpStatus);
			g_QRtmp.GetValue("update", g_tmpUpdate);
			g_QRtmp.GetString("model", g_tmpModel, sizeof(g_tmpModel));

			if (g_tmpModel[0] == EOS || g_tmpOnteam == 3) {
				GetBotCharacter(g_tmpTarget, g_tmpModel);
				g_QRtmp.SetString("model", g_tmpModel, true);
			}

			Echo(1, "-t1: %N is model '%s'", client, g_tmpModel);
			result = true;
		}
	}

	g_QKey = QKey;
	return result;
}

bool GetQRecord(int client) {
	Echo(3, "GetQRecord: %d", client);

	if (SetQKey(client)) {
		if (g_QDB.GetValue(g_QKey, g_QRecord)) {

			if (IsClientValid(client) && IsPlayerAlive(client)) {
				GetClientAbsOrigin(client, g_origin);
				g_QRecord.SetArray("origin", g_origin, sizeof(g_origin), true);
			}

			g_QRecord.GetValue("client", g_client);
			g_QRecord.GetValue("target", g_target);
			g_QRecord.GetValue("lastid", g_lastid);
			g_QRecord.GetValue("onteam", g_onteam);
			g_QRecord.GetValue("queued", g_queued);
			g_QRecord.GetValue("inspec", g_inspec);
			g_QRecord.GetValue("status", g_status);
			g_QRecord.GetValue("update", g_update);
			g_QRecord.GetString("model", g_model, sizeof(g_model));

			if (g_model[0] == EOS || g_onteam == 3) {
				GetBotCharacter(g_target, g_model);
				g_QRecord.SetString("model", g_model, true);
			}

			Echo(1, "-n1: %N is model '%s'", client, g_model);
			return true;
		}
	}

	return false;
}

bool NewQRecord(int client) {
	Echo(3, "NewQRecord: %d", client);

	g_QRecord = new StringMap();

	GetClientAbsOrigin(client, g_origin);
	g_QRecord.SetArray("origin", g_origin, sizeof(g_origin), true);
	g_QRecord.SetValue("client", client, true);
	g_QRecord.SetValue("target", client, true);
	g_QRecord.SetValue("lastid", client, true);
	g_QRecord.SetValue("onteam", GetClientTeam(client), true);
	g_QRecord.SetValue("queued", false, true);
	g_QRecord.SetValue("inspec", false, true);
	g_QRecord.SetValue("status", true, true);
	g_QRecord.SetValue("update", false, true);
	g_QRecord.SetString("model", "", true);
	return true;
}

int SetQRecord(int client, bool update=false) {
	Echo(3, "SetQRecord: %d %d", client, update);

	int result = -1;

	if (SetQKey(client)) {
		if (g_QDB.GetValue(g_QKey, g_QRecord) && !update) {
			result = 0;
		}

		else if (NewQRecord(client)) {
			GetClientName(client, g_pN, sizeof(g_pN));
			Echo(0, "AUTH ID: %s, (%s) ADDED TO QDB.", g_QKey, g_pN);
			g_QDB.SetValue(g_QKey, g_QRecord, true);
			result = 1;
		}

		GetQRecord(client);
	}

	return result;
}

void QueueUp(int client, int onteam) {
	Echo(2, "QueueUp: %d %d", client, onteam);

	if (onteam >= 2 && GetQRecord(client)) {
		Unqueue(client);

		switch (onteam) {
			case 2: g_sQueue.Push(client);
			case 3: g_iQueue.Push(client);
		}

		g_QRecord.SetValue("target", client, true);
		g_QRecord.SetValue("inspec", false, true);
		g_QRecord.SetValue("onteam", onteam, true);
		g_QRecord.SetValue("queued", true, true);
	}
}

void Unqueue(int client) {
	Echo(2, "Unqueue: %d", client);

	if (GetQRecord(client)) {
		g_QRecord.SetValue("queued", false, true);

		int iLength = g_iQueue.Length;
		int sLength = g_sQueue.Length;

		if (iLength > 0) {
			for (int i = iLength - 1; i > -1; i--) {
				if (g_iQueue.Get(i) == client) {
					g_iQueue.Erase(i);
				}
			}
		}

		if (sLength > 0) {
			for (int i = sLength - 1; i > -1; i--) {
				if (g_sQueue.Get(i) == client) {
					g_sQueue.Erase(i);
				}
			}
		}
	}
}

void OnSpawnHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "OnSpawnHook: %s", name);

	int userid = GetEventInt(event, "userid");
	int target = GetClientOfUserId(userid);

	GetClientName(target, g_pN, sizeof(g_pN));
	if (g_pN[0] == 'A' && strncmp(g_pN, "ABMclient", 9) == 0) {
		return;
	}

	int onteam = GetClientTeam(target);
	int client;

	if (onteam == 3) {
		if (!g_IsVs) {
			if (g_AssistedSpawning) {
				if (IsClientTank(target)) {

					int j = 1;
					static int i = 1;

					for (; i <= MaxClients + 1; i++) {
						if (j++ == MaxClients + 1) {  // join 3 Tank requires +1
							return;
						}

						if (i > MaxClients) {
							i = 1;
						}

						if (GetQRecord(i) && g_onteam == 3 && !g_inspec) {
							if (!IsClientTank(i)) {
								client = i;
								i++;
								break;
							}
						}
					}

					switch (IsClientValid(client)) {
						case true: SwitchToBot(client, target);
						case false: CreateTimer(1.0, TankAssistTimer, target, TIMER_REPEAT);
					}
				}
			}

			if (g_iQueue.Length > 0) {
				SwitchToBot(g_iQueue.Get(0), target);
				return;
			}
		}
	}
	else if (onteam == 2) {
		// AutoModeling now takes place in OnEntityCreated
		CreateTimer(0.4, OnSpawnHookTimer, target);
		UpdateScriptValueCheck();
	}
}

Action TankAssistTimer(Handle timer, int client) {
	Echo(4, "TankAssistTimer: %d", client);

	/*
	* Human players on the infected team in modes that do not officially
	* support them, can get Tanks stuck in "stasis" until they die. This
	* function works around the issue by watching Tanks for movement. If
	* a Tank does not move in 11 seconds, it is replaced with another.
	*/

	float origin[3];
	static const float nullOrigin[3];
	static int times[MAXPLAYERS + 1] = {11, ...};
	static float origins[MAXPLAYERS + 1][3];
	static int i;

	if (IsClientValid(client)) {
		i = times[client]--;

		if (i == 11) {
			GetClientAbsOrigin(client, origins[client]);
			return Plugin_Continue;
		}

		else if (i >= 0) {
			GetClientAbsOrigin(client, origin);

			if (origin[0] == origins[client][0]) {
				if (i == 0) {
					TeleportEntity(client, nullOrigin, NULL_VECTOR, NULL_VECTOR);
					ForcePlayerSuicide(client);
					AddInfected("tank");
				}

				return Plugin_Continue;
			}
		}
	}

	i = times[client] = 11;
	return Plugin_Stop;
}

Action ForceSpawnTimer(Handle timer, int client) {
	Echo(4, "ForceSpawnTimer: %d", client);

	static int times[MAXPLAYERS + 1] = {20, ...};
	static int i;

	if (IsClientValid(client)) {
		i = times[client]--;

		if (!IsClientTank(client)) {
			i = times[client] = 20;
			return Plugin_Stop;
		}

		if (GetEntProp(client, Prop_Send, "m_isGhost") == 1) {
			if (i >= 1) {
				PrintHintText(client, "FORCING SPAWN IN: %d", i);
				return Plugin_Continue;
			}

			if (GetEntProp(client, Prop_Send, "m_ghostSpawnState") <= 2) {
				SetEntProp(client, Prop_Send, "m_isGhost", 0);
			}

			return Plugin_Continue;
		}

		if (GetClientTeam(client) == 3) {
			static int x;
			x = GetConVarInt(FindConVar("z_frustration"));
			SetEntProp(client, Prop_Send, "m_frustration",!x);
			PrintHintText(client, "KILL ALL HUMANS");
			SetEntProp(client, Prop_Send, "m_frustration", x);
		}
	}

	i = times[client] = 20;
	return Plugin_Stop;
}

Action OnSpawnHookTimer(Handle timer, any target) {
	Echo(2, "OnSpawnHookTimer: %d", target);

	if (g_sQueue.Length > 0) {
		SwitchToBot(g_sQueue.Get(0), target);
	}
	return Plugin_Continue;
}

void OnDeathHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(4, "OnDeathHook: %s", name);

	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	
	UpdateScriptValueCheck();

	if (GetQRecord(client) && !IsPlayerAlive(client)) {
		GetClientAbsOrigin(client, g_origin);
		g_QRecord.SetValue("target", client, true);
		g_QRecord.SetArray("origin", g_origin, sizeof(g_origin), true);
		g_QRecord.SetValue("status", false, true);
		bool offerTakeover;

		switch (g_onteam) {
			case 3: {
				g_QRecord.SetString("model", "", true);
				Echo(1, "--2: %N is model '%s'", client, "");

				if (!g_IsVs) {
					switch (g_OfferTakeover) {
						case 2, 3: {
							QueueUp(client, 3);
							GoIdle(client, 1);
							offerTakeover = true;
						}

						default: SwitchTeam(client, 3);
					}
				}
			}

			case 2: {
				switch (g_OfferTakeover) {
					case 1, 3: offerTakeover = true;
				}
			}
		}

		if (offerTakeover) {
			GenericMenuCleaner(client);
			menuArg0 = client;
			SwitchToBotHandler(client, 1);
		}
	}

	else if (GetQRecord(GetRealClient(client))) {
		g_QRecord.SetValue("status", false, true);
	}
}

void QTeamHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "QTeamHook: %s", name);

	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	int onteam = GetEventInt(event, "team");

	if (GetQRecord(client)) {
		if (onteam >= 2) {
			g_QRecord.SetValue("inspec", false, true);
			g_QRecord.SetValue("target", client, true);
			g_QRecord.SetValue("onteam", onteam, true);
			g_QRecord.SetValue("queued", false, true);

			// attempt to apply a model asap
			if (g_ADFreeze && onteam == 2 && g_model[0] != EOS) {
				Echo(1, "--9: Client %N Assigned Model %s ASAP", client, g_model);
				AssignModel(client, g_model, g_IdentityFix);
			}
		}

		if (onteam <= 1) { // cycling requires 0.2 or higher?
			CreateTimer(0.2, QTeamHookTimer, client);
		}
	}
}

Action QTeamHookTimer(Handle timer, int client) {
	Echo(2, "QTeamHookTimer: %d", client);

	if (GetQRecord(client) && !g_inspec) {
		if (g_onteam == 2) {
			if (IsClientValid(g_target) && g_target != client) {
				SetHumanSpecSig(g_target, client);
			}
		}
	}
	return Plugin_Continue;
}

void QAfkHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "QAfkHook: %s", name);

	int client = GetClientOfUserId(GetEventInt(event, "player"));
	int target = GetClientOfUserId(GetEventInt(event, "bot"));
	int clientTeam = GetClientTeam(client);
	int targetTeam = GetClientTeam(target);

	if (GetQRecord(client)) {
		int onteam = GetClientTeam(client);

		if (onteam == 2) {
			g_QRecord.SetValue("target", target, true);
			AssignModel(target, g_model, g_IdentityFix);
		}
	}

	if (targetTeam == 2 && IsClientValid(client)) {
		if (IsClientInKickQueue(client)) {
			if (client && target && clientTeam == targetTeam) {
				int safeClient = GetSafeSurvivor(target);
				RespawnClient(target, safeClient);
			}
		}
	}
}

void QBakHook(Handle event, const char[] name, bool dontBroadcast) {
	Echo(2, "QBakHook: %s", name);

	int client = GetClientOfUserId(GetEventInt(event, "player"));
	int target = GetClientOfUserId(GetEventInt(event, "bot"));

	if (GetQRecord(client)) {
		if (g_target != target) {
			g_QRecord.SetValue("lastid", target);
			g_QRecord.SetValue("target", client);
		}

		if (GetClientTeam(client) == 2) {
			AssignModel(client, g_model, g_IdentityFix);
		}
	}
}

// ================================================================== //
// UNORGANIZED AS OF YET
// ================================================================== //

void StripClient(int client) {
	Echo(2, "StripClient: %d", client);

	if (IsClientValid(client)) {
		if (GetClientTeam(client) == 2) {
			for (int i = 4; i >= 0; i--) {
				StripClientSlot(client, i);
			}
		}
	}
}

void StripClientSlot(int client, int slot) {
	Echo(2, "StripClientSlot: %d %d", client, slot);

	client = GetPlayClient(client);

	if (IsClientValid(client)) {
		if (GetClientTeam(client) == 2) {
			int ent = GetPlayerWeaponSlot(client, slot);
			if (IsEntityValid(ent)) {
				RemovePlayerItem(client, ent);
				AcceptEntityInput(ent,"kill");
			}
		}
	}
}

void RespawnClient(int client, int target=0) {
	Echo(2, "RespawnClient: %d %d", client, target);

	if (!IsClientValid(client)) {
		return;
	}

	else if (GetQRecord(client)) {
		if (g_onteam == 3) {
			Takeover(client, 3);
			return;
		}
	}

	client = GetPlayClient(client);
	target = GetPlayClient(target);
	bool weaponizePlayer = true;
	static const float pos0[3];
	static float pos1[3];
	pos1 = pos0;

	if (client != GetRealClient(target) && IsClientValid(target)) {
		GetClientAbsOrigin(target, pos1);
	}

	else if (GetQRtmp(client)) {
		pos1 = g_origin;
		if (pos1[0] != 0 && pos1[1] != 0 && pos1[2] != 0) {
			weaponizePlayer = false;
		}
	}

	if (pos1[0] != 0 && pos1[1] != 0 && pos1[2] != 0) {
		RoundRespawnSig(client);

		if (!g_ADFreeze && weaponizePlayer) {
			//QuickCheat(client, "give", g_PrimaryWeapon);
			//QuickCheat(client, "give", g_SecondaryWeapon);
			//QuickCheat(client, "give", g_Throwable);
			//QuickCheat(client, "give", g_HealItem);
			//QuickCheat(client, "give", g_Consumable);
			if (g_PrimaryWeapon[0] != '\0')
			{
				GiveWep(client, g_PrimaryWeapon);
			}
			if (g_SecondaryWeapon[0] != '\0')
			{
				int slot2 = GetPlayerWeaponSlot(client, 1);
				GiveWep(client, g_SecondaryWeapon, false, slot2);
			}
			if (g_Throwable[0] != '\0')
			{
				GiveWep(client, g_Throwable);
			}
			if (g_HealItem[0] != '\0')
			{
				GiveWep(client, g_HealItem);
			}
			if (g_Consumable[0] != '\0')
			{
				GiveWep(client, g_Consumable);
			}
		}

		TeleportEntity(client, pos1, NULL_VECTOR, NULL_VECTOR);
	}
}

void TeleportClient(int client, int target) {
	Echo(2, "TeleportClient: %d %d", client, target);

	float origin[3];
	client = GetPlayClient(client);
	target = GetPlayClient(target);

	if (IsClientValid(client) && IsClientValid(target)) {
		GetClientAbsOrigin(target, origin);
		TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
	}
}

int GetSafeSurvivor(int client) {
	Echo(2, "GetSafeSurvivor: %d", client);

	int last_survivor;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientValid(i) && i != client) {
			if (IsPlayerAlive(i) && GetClientTeam(i) == 2) {
				last_survivor = i;

				if (GetEntProp(i, Prop_Send, "m_isHangingFromLedge") == 0) {
					return i;
				}
			}
		}
	}

	return last_survivor;
}

bool AddSurvivor() {
	Echo(2, "AddSurvivor");

	if (GetClientCount(false) >= MaxClients - 1) {
		return false;
	}

	int i = CreateFakeClient("ABMclient2");
	bool result;

	if (IsClientValid(i)) {
		if (DispatchKeyValue(i, "classname", "SurvivorBot")) {
			ChangeClientTeam(i, 2);

			if (DispatchSpawn(i)) {
				result = true;
			}
		}

		KickClient(i);
	}

	return result;
}

bool AddInfected(char model[32]="", int version=0) {
	Echo(2, "AddInfected: %s %d", model, version);

	if (GetClientCount(false) >= MaxClients - 1) {
		return false;
	}

	CleanSIName(model);
	int i = CreateFakeClient("ABMclient3");

	if (IsClientValid(i)) {
		ChangeClientTeam(i, 3);
		//GhostsModeProtector(0);
		Format(g_sB, sizeof(g_sB), "%s auto area", model);

		switch (version) {
			case 0: QuickCheat(i, "z_spawn_old", g_sB);
			case 1: QuickCheat(i, "z_spawn", g_sB);
		}

		KickClient(i);
		//GhostsModeProtector(1);
		return true;
	}

	return false;
}

void GhostsModeProtector(int state) {
	Echo(2, "GhostsModeProtector: %d", state);
	// CAREFUL: 0 starts this function and you must close it with 1 or
	// risk breaking things. Close this with 1 immediately when done.

	// e.g.,
	// GhostsModeProtector(0);
	// z_spawn_old tank auto;
	// GhostsModeProtector(1);

	if (CountTeamMates(3, 1) == 0) {
		return;
	}

	static int ghosts[MAXPLAYERS + 1];

	switch (state) {
		case 0: {
			for (int i = 1; i <= MaxClients; i++) {
				if (GetQRtmp(i) && g_tmpOnteam == 3) {
					if (GetEntProp(i, Prop_Send, "m_isGhost") == 1) {
						SetEntProp(i, Prop_Send, "m_isGhost", 0);
						ghosts[i] = 1;
					}
				}
			}
		}

		case 1: {
			for (int i = 1; i <= MaxClients; i++) {
				if (ghosts[i] == 1) {
					SetEntProp(i, Prop_Send, "m_isGhost", 1);
					ghosts[i] = 0;
				}
			}
		}
	}
}

void CleanSIName(char model[32]) {
	Echo(2, "CleanSIName: %s", model);

	int i;
	static char tmpModel[32];

	if (model[0] != EOS) {
		for (i = 0; i < g_InfectedNames.Length; i++) {
			g_InfectedNames.GetString(i, tmpModel, MAX_INF_NAMESIZE);
			if (StrContains(tmpModel, model, false) == 0) {
				model = tmpModel;
				return;
			}
		}

		if (StrContains("Tank", model, false) == 0) {
			model = "Tank";
			return;
		}
	}

	i = GetRandomInt(0, g_InfectedNames.Length - 1);
	g_InfectedNames.GetString(i, model, MAX_INF_NAMESIZE);
}

void SwitchToSpec(int client, int onteam=1) {
	Echo(2, "SwitchToSpectator: %d %d", client, onteam);

	if (GetQRecord(client)) {
		// clearparent jockey bug switching teams (thanks to Lux)
		AcceptEntityInput(client, "clearparent");
		g_QRecord.SetValue("inspec", true, true);
		ChangeClientTeam(client, onteam);

		if (GetRealClient(g_target) == client) {
			if (g_onteam == 2) {
				AssignModel(g_target, g_model, g_IdentityFix);
			}

			if (HasEntProp(g_target, Prop_Send, "m_humanSpectatorUserID")) {
				SetEntProp(g_target, Prop_Send, "m_humanSpectatorUserID", 0);
			}
		}
	}
}

void QuickCheat(int client, const char[] cmd, const char[] arg) {
	Echo(2, "QuickCheat: %d %s %s", client, cmd, arg);

	int flags = GetCommandFlags(cmd);
	SetCommandFlags(cmd, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", cmd, arg);
	SetCommandFlags(cmd, flags);
}

int GiveWep(int client, const char[] wep, bool quick = false, int remove_wep = -1)
{
	char wep_str[64];
	strcopy(wep_str, sizeof(wep_str), wep);
	if (strncmp(wep_str, "weapon_", 7, false) != 0)
	{
		Format(wep_str, sizeof(wep_str), "weapon_%s", wep_str);
	}
	if (StrContains(wep_str, "_spawn", false) < 0)
	{
		Format(wep_str, sizeof(wep_str), "%s_spawn", wep_str);
	}
	
	int new_wep = CreateEntityByName(wep_str);
	if (!RealValidEntity(new_wep))
	{
		// If invalid and g_isSequel, the string may be for a melee weapon.
		if (!g_isSequel) return -1;
		
		new_wep = CreateEntityByName("weapon_melee_spawn");
		
		SetEntPropString(new_wep, Prop_Data, "m_iszMeleeWeapon", wep);
	}
	DispatchKeyValue(new_wep, "spawnflags", "2");
	DispatchKeyValue(new_wep, "count", "1");
	
	SetVariantString("OnUser1 !self:Kill::0.02:1");
	AcceptEntityInput(new_wep, "AddOutput");
	AcceptEntityInput(new_wep, "FireUser1");
	
	float pos[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);
	TeleportEntity(new_wep, pos, NULL_VECTOR, NULL_VECTOR);
	
	DispatchSpawn(new_wep);
	ActivateEntity(new_wep);
	
	if (!quick)
	{
		DataPack data = CreateDataPack();
		data.WriteCell(client);
		data.WriteCell(new_wep);
		RequestFrame(NewWep_RequestFrame, data);
	}
	else
	{ AcceptEntityInput(new_wep, "Use", client, new_wep); }
	
	if (RealValidEntity(remove_wep))
	{
		DataPack data2 = CreateDataPack();
		data2.WriteCell(client);
		data2.WriteCell(remove_wep);
		CreateTimer(0.01, RequestFrame_CheckForSecWep, data2, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return new_wep;
}

void NewWep_RequestFrame(DataPack data)
{
	data.Reset();
	int client = data.ReadCell();
	int new_wep = data.ReadCell();
	if (data != null)
	{ CloseHandle(data); }
	
	if (!IsValidClient(client) || !RealValidEntity(new_wep)) return;
	
	AcceptEntityInput(new_wep, "Use", client, new_wep);
}

Action RequestFrame_CheckForSecWep(Handle timer, DataPack data)
{
	data.Reset();
	int client = data.ReadCell();
	int remove_wep = data.ReadCell();
	if (data != null)
	{ CloseHandle(data); }
	
	if (!IsValidClient(client)) return Plugin_Continue;
	
	int slot2 = GetPlayerWeaponSlot(client, 1);
	
	if (RealValidEntity(remove_wep) && slot2 != remove_wep)
	{ AcceptEntityInput(remove_wep, "Kill"); }
	
	return Plugin_Continue;
}

bool RealValidEntity(int entity)
{
	if (entity <= 0 || !IsValidEntity(entity)) return false;
	return true;
}

bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}

void SwitchToBot(int client, int target, bool si_ghost=true) {
	Echo(2, "SwitchToBot: %d %d %d", client, target, si_ghost);

	if (IsClientValid(target, 0, 0)) {
		switch (GetClientTeam(target)) {
			case 2: TakeoverBotSig(client, target);
			case 3: TakeoverZombieBotSig(client, target, si_ghost);
		}
	}
}

void Takeover(int client, int onteam) {
	Echo(2, "Takeover: %d %d", client, onteam);

	if (GetQRecord(client)) {
		if (IsClientValid(g_target, 0, 0)) {
			if (client != g_target && GetClientTeam(g_target) == onteam) {
				SwitchToBot(client, g_target);
				return;
			}
		}

		int nextBot;
		nextBot = GetNextBot(onteam, 0, true);

		if (IsClientValid(nextBot)) {
			SwitchToBot(client, nextBot);
			return;
		}

		switch (onteam) {
			case 2: {
				if (g_KeepDead == 1 && !g_status) {
					if (g_onteam == 2 && CountTeamMates(2, 0) == 0) {
						ChangeClientTeam(client, 2);
						ForcePlayerSuicide(client);  // without this player may spawn if survivors are close to start
					}

					return;
				}

				QueueUp(client, 2);
				AddSurvivor();
			}

			case 3: {
				QueueUp(client, 3);
				AddInfected();
			}
		}
	}
}

Action TakeoverTimer(Handle timer, int client) {
	Echo(4, "TakeoverTimer: %d", client);

	if (CountTeamMates(2) <= 0) {
		return Plugin_Handled;
	}

	static int team2;
	static int team3;
	static int teamX;

	if (GetQRecord(client)) {
		if (GetClientTeam(client) >= 2) {
			return Plugin_Handled;
		}

		teamX = 2;
		if (g_onteam == 3) {
			teamX = 3;
		}

		if (g_IsVs && g_onteam <= 1) {
			team2 = CountTeamMates(2, 1);
			team3 = CountTeamMates(3, 1);

			if (team3 < team2) {
				teamX = 3;
			}
		}

		if (CountTeamMates(teamX, 1) < g_TeamLimit) {
			Takeover(client, teamX);
		}
	}

	return Plugin_Handled;
}

int CountTeamMates(int onteam, int mtype=2, bool aliveonly=false) {
	Echo(2, "CountTeamMates: %d %d", onteam, mtype);

	// mtype 0: counts only bots
	// mtype 1: counts only humans
	// mtype 2: counts all players on team

	static int clients, bots, humans;
	clients = bots = humans = 0;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientValid(i, onteam) && (!aliveonly || IsPlayerAlive(i))) {
			clients++;

			switch (IsFakeClient(GetRealClient(i))) {
				case true: bots++;
				case false: humans++;
			}
		}
	}

	if (onteam == 2 && clients > 0) {
		g_MaxSI = clients;
		SetConVarFloat(g_cvMaxSI, float(clients));
	}

	switch (mtype) {
		case 0: clients = bots;
		case 1: clients = humans;
	}

	return clients;
}

int GetClientManager(int target) {
	Echo(4, "GetClientManager: %d", target);

	int result = -1;
	target = GetRealClient(target);

	if (IsClientValid(target)) {
		switch (IsFakeClient(target)) {
			case false: result = target;
			case true: result = 0;
		}
	}

	return result;
}

int GetNextBot(int onteam, int start=1, bool alive=false) {
	Echo(2, "GetNextBot: %d %d %d", onteam, start, alive);

	static int bot, j;
	bot = 0;
	j = start;

	if (onteam == 3) {
		alive = true;
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (j > 32) {
			j = 1;
		}

		if (IsClientValid(j, onteam, 0)) {
			if (GetClientManager(j) == 0) {
				if (onteam == 2) {
					bot = j;
				}

				if (alive && IsPlayerAlive(j)) {
					return j;
				}

				else if (!alive) {
					return j;
				}
			}
		}

		j++;
	}

	return bot;
}

void CycleBots(int client, int onteam) {
	Echo(2, "CycleBots: %d %d", client, onteam);

	if (onteam <= 1) {
		return;
	}

	if (GetQRecord(client)) {
		int bot = GetNextBot(onteam, g_lastid, true);
		if (IsClientValid(bot, onteam, 0)) {
			SwitchToBot(client, bot, false);
		}
	}
}

void SwitchTeam(int client, int onteam, char model[32]="") {
	Echo(2, "SwitchTeam: %d %d", client, onteam);

	if (GetQRecord(client)) {
		if (GetClientTeam(client) >= 2) {
			if (onteam == 2 && onteam == g_onteam) {
				return;  // keep survivors from rejoining survivors
			}
		}

		if (g_onteam == 2 && onteam <= 1) {
			if (IsClientValid(g_target, 0, 0)) {
				SwitchToBot(client, g_target);
			}
		}

		switch (onteam) {
			case 0: GoIdle(client, 0);
			case 1: GoIdle(client, 1);
			//case 4: ChangeClientTeam(client, 4);
			default: {
				if (onteam <= 3 && onteam >= 2) {
					if (g_onteam != onteam) {
						GoIdle(client, 1);
					}

					g_QRecord.SetValue("queued", true, true);
					g_QRecord.SetValue("onteam", onteam, true);

					if (onteam == 3) {
						if (g_IsVs) {  // see if a proper way to get on team 2 exist
							static int switches;  // A Lux idea
							switches = GetConVarInt(g_cvMaxSwitches);
							SetConVarInt(g_cvMaxSwitches, 9999);
							ChangeClientTeam(client, onteam);
							SetConVarInt(g_cvMaxSwitches, switches);
							return;
						}

						switch (g_model[0] != EOS) {
							case true: Format(model, sizeof(model), "%s", g_model);
							case false: CleanSIName(model);
						}

						QueueUp(client, 3);
						AddInfected(model, 1);
						return;
					}

					Takeover(client, onteam);
				}
			}
		}
	}
}

Action MkBotsCmd(int client, int args) {
	Echo(2, "MkBotsCmd: %d", client);

	switch (args) {
		case 2: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			int asmany = StringToInt(g_sB);
			GetCmdArg(2, g_sB, sizeof(g_sB));
			int onteam = StringToInt(g_sB);

			if (onteam >= 2 || onteam <= 3) {
				MkBots(asmany, onteam);
			}
		}
	}
	
	return Plugin_Handled;
}

void MkBots(int asmany, int onteam) {
	Echo(2, "MkBots: %d %d", asmany, onteam);

	if (asmany < 0) {
		asmany = asmany * -1 - CountTeamMates(onteam);
	}

	float rate;
	DataPack pack = new DataPack();

	switch (onteam) {
		case 2: rate = 0.2;
		case 3: rate = 0.4;
	}

	CreateDataTimer(rate, MkBotsTimer, pack, TIMER_REPEAT);
	pack.WriteCell(asmany);
	pack.WriteCell(onteam);
}

Action MkBotsTimer(Handle timer, Handle pack) {
	Echo(2, "MkBotsTimer");

	static int i;

	ResetPack(pack);
	int asmany = ReadPackCell(pack);
	int onteam = ReadPackCell(pack);

	if (i++ < asmany) {
		switch (onteam) {
			case 2: AddSurvivor();
			case 3: AddInfected();
		}

		return Plugin_Continue;
	}

	i = 0;
	return Plugin_Stop;
}

Action RmBotsCmd(int client, int args) {
	Echo(2, "RmBotsCmd: %d", client);

	int asmany;
	int onteam;

	switch (args) {
		case 1: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			onteam = StringToInt(g_sB);
			asmany = MaxClients;
		}

		case 2: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			asmany = StringToInt(g_sB);
			GetCmdArg(2, g_sB, sizeof(g_sB));
			onteam = StringToInt(g_sB);
		}
	}

	if (onteam >= 2 || onteam <= 3) {
		RmBots(asmany, onteam);
	}
	
	return Plugin_Handled;
}

void RmBots(int asmany, int onteam) {
	Echo(2, "RmBots: %d %d", asmany, onteam);

	int j;

	if (onteam == 0) {
		onteam = asmany;
		asmany = MaxClients;
	}

	else if (asmany == -0) {
		return;
	}

	else if (asmany < 0) {
		asmany += CountTeamMates(onteam);
		if (asmany <= 0) {
			return;
		}
	}

	for (int i = MaxClients; i >= 1; i--) {
		if (GetClientManager(i) == 0 && GetClientTeam(i) == onteam) {

			j++;
			if (g_StripKick == 1) {
				StripClient(i);
			}

			KickClient(i);

			if (j >= asmany) {
				break;
			}
		}
	}
}

// ================================================================== //
// MODEL FEATURES
// ================================================================== //


void AutoModel(int client) {
	Echo(5, "AutoModel: %d", client);
	RequestFrame(_AutoModel, client);
}

void _AutoModel(int client) {
	Echo(5, "_AutoModel: %d", client);

	if (IsClientValid(client, 2)) {
		SDKUnhook(client, SDKHook_SpawnPost, AutoModel);
	}

	if (g_AutoModel && IsClientValid(client, 2)) {
		static int realClient;
		realClient = GetRealClient(client);
		if (GetQRecord(realClient) && g_model[0] != EOS) {
			return;
		}

		static int set, survivors, character;
		set = GetSurvivorSet(client);
		GetAllSurvivorModels(client);

		survivors = CountTeamMates(2);
		character = g_models[GetClientModelIndex(client)];
		if (character == 0 || character < survivors / 8) {
			return;
		}

		char temp_str[MAX_SURV_NAMESIZE];
		for (int i = 0; i < 4; i++) {
			for (int index = set; index < sizeof(g_models); index++) {
				if (g_models[index] <= i) {
					g_models[index]++;
					g_SurvivorNames.GetString(index, temp_str, MAX_SURV_NAMESIZE);
					AssignModel(client, temp_str, g_IdentityFix);
					i = 4;  // we want to fall through
					break;
				}

				if (set != 0 && index + 1 == sizeof(g_models)) {
					index=-1; set=0;
				}
			}
		}
	}
}

int GetSurvivorSet(int client) {
	Echo(6, "GetSurvivorSet: %d", client);
	
	if (g_isSequel)
	{
		if (g_survivorSetScan && IsClientValid(client, 2)) {
			g_survivorSetScan = false;
			g_survivorSet = GetClientModelIndex(client);
	
			switch (g_survivorSet >= 0 && g_survivorSet <= 3) {
				case true: g_survivorSet = 0;  // l4d2 survivor set
				case false: g_survivorSet = 4;  // l4d1 survivor set
			}
		}
	}
	else
	{ g_survivorSet = 0; }

	return g_survivorSet;
}

void GetAllSurvivorModels(int client=-1) {
	Echo(2, "GetAllSurvivorModels");

	static int index;
	static const int models[8];
	g_models = models;

	for (int i = 1; i <= MaxClients; i++) {
		if (client == i) {
			continue;
		}

		index = -1;

		if (GetQRecord(i) && g_onteam == 2 && g_model[0] != EOS) {
			index = GetModelIndexByName(g_model, 2);
		}

		else if (IsClientValid(i, 2, 0) && GetRealClient(i) == i) {
			index = GetClientModelIndex(i);
		}

		if (index >= 0) {
			g_models[index]++;
		}
	}
}

void PrecacheModels() {
	Echo(2, "PrecacheModels");

	char temp_str[MAX_SURV_MDLSIZE];
	for (int i = 0; i < sizeof(g_SurvivorPaths); i++) {
		g_SurvivorPaths.GetString(i, temp_str, MAX_SURV_MDLSIZE);
		
		PrecacheModel(temp_str);
	}
}

void AssignModel(int client, char [] model, int identityFix) {
	Echo(2, "AssignModel: %d %s %d", client, model, identityFix);

	if (identityFix == 1 && IsClientValid(client, 2)) {
		if (IsClientsModel(client, model)) {
			return;
		}

		int i = GetModelIndexByName(model);
		int realClient = GetRealClient(client);

		if (i >= 0 && i < g_SurvivorPaths.Length) {
			if (g_isSequel)
			{
				switch (i == 5)
				{
					case true: SetEntProp(client, Prop_Send, "m_survivorCharacter", g_Zoey);
					case false: SetEntProp(client, Prop_Send, "m_survivorCharacter", i);
				}
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_survivorCharacter", i);
			}
			
			char temp_str[MAX_SURV_NAMESIZE], temp_str_2[MAX_SURV_MDLSIZE];
			g_SurvivorNames.GetString(i, temp_str, MAX_SURV_NAMESIZE);
			g_SurvivorPaths.GetString(i, temp_str_2, MAX_SURV_MDLSIZE);
			SetEntityModel(client, temp_str_2);
			Format(g_pN, sizeof(g_pN), "%s", temp_str);

			if (IsFakeClient(client)) {
				SetClientInfo(client, "name", g_pN);
			}

			if (GetQRecord(realClient)) {
				g_QRecord.SetString("model", g_pN, true);
				Echo(1, "--4: %N is model '%s'", realClient, g_pN);
			}
		}
	}
}

int GetClientModelIndex(int client) {
	Echo(3, "GetClientModelIndex: %d", client);

	if (!IsClientValid(client)) {
		return -2;
	}

	char modelName[64];

	GetEntPropString(client, Prop_Data, "m_ModelName", modelName, sizeof(modelName));
	char temp_str[MAX_SURV_MDLSIZE];
	for (int i = 0; i < g_SurvivorPaths.Length; i++) {
		g_SurvivorPaths.GetString(i, temp_str, MAX_SURV_MDLSIZE);
		
		if (strcmp(modelName, temp_str, false) == 0) {
			return i;
		}
	}

	return -1;
}

int GetModelIndexByName(char [] name, int onteam=2) {
	Echo(2, "GetModelIndexByName: %s %d", name, onteam);

	if (onteam == 2) {
		char temp_str[MAX_SURV_NAMESIZE];
		for (int i; i < g_SurvivorNames.Length; i++) {
			g_SurvivorNames.GetString(i, temp_str, MAX_SURV_NAMESIZE);
			
			if (StrContains(name, temp_str, false) != -1) {
				return i;
			}
		}
	}

	else if (onteam == 3) {
		char temp_str[MAX_INF_NAMESIZE];
		for (int i; i < g_InfectedNames.Length; i++) {
			g_InfectedNames.GetString(i, temp_str, MAX_INF_NAMESIZE);
			if (StrContains(temp_str, name, false) != -1) {
				return i;
			}
		}
	}

	return -1;
}

bool IsClientsModel(int client, char [] name) {
	Echo(2, "IsClientsModel: %d %s", client, name);

	int modelIndex = GetClientModelIndex(client);
	char temp_str[MAX_SURV_NAMESIZE];
	g_SurvivorNames.GetString(modelIndex, temp_str, MAX_SURV_NAMESIZE);
	Format(g_sB, sizeof(g_sB), "%s", temp_str);
	return (strcmp(name, g_sB) == 0);
}

void GetBotCharacter(int client, char strBuffer[64]) {
	Echo(2, "GetBotCharacter: %d", client);

	if (IsClientValid(client)) {
		strBuffer = "";

		switch (GetClientTeam(client)) {
			case 2: GetSurvivorCharacter(client, strBuffer);
			case 3: GetInfectedCharacter(client, strBuffer);
		}
	}
}

void GetSurvivorCharacter(int client, char strBuffer[64]) {
	Echo(2, "GetSurvivorCharacter: %d %s", client, strBuffer);

	GetEntPropString(client, Prop_Data, "m_ModelName", g_sB, sizeof(g_sB));
	for (int i = 0; i < g_SurvivorPaths.Length; i++) {
		char temp_str_2[MAX_SURV_MDLSIZE];
		g_SurvivorPaths.GetString(i, temp_str_2, MAX_SURV_MDLSIZE);
		if (strcmp(temp_str_2, g_sB, false) == 0) {
			char temp_str[MAX_SURV_NAMESIZE];
			g_SurvivorNames.GetString(i, temp_str, MAX_SURV_NAMESIZE);
			Format(strBuffer, sizeof(strBuffer), temp_str);
			break;
		}
	}
}

void GetInfectedCharacter(int client, char strBuffer[64]) {
	Echo(2, "GetInfectedCharacter: %d %s", client, strBuffer);

	switch (GetEntProp(client, Prop_Send, "m_zombieClass")) {
		case 1: strBuffer = "Smoker";
		case 2: strBuffer = "Boomer";
		case 3: strBuffer = "Hunter";
		case 4: { if (g_isSequel) strBuffer = "Spitter"; }
		case 5: { g_isSequel ? (strBuffer = "Jockey") : (strBuffer = "Tank"); }
		case 6: { if (g_isSequel) strBuffer = "Charger"; }
		case 8: { if (g_isSequel) strBuffer = "Tank"; }
	}
}

// ================================================================== //
// BLACK MAGIC SIGNATURES. SOME SPOOKY SHIT.
// ================================================================== //

int GetOS() {
	Echo(2, "GetOS");
	return GameConfGetOffset(g_GameData, "OS");
}

void RoundRespawnSig(int client) {
	Echo(2, "RoundRespawnSig: %d", client);

	static Handle hRoundRespawn;
	if (hRoundRespawn == null) {
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "RoundRespawn");
		hRoundRespawn = EndPrepSDKCall();
	}

	if (hRoundRespawn != null) {
		SDKCall(hRoundRespawn, client);
	}

	else {
		PrintToChat(client, "[ABM] RoundRespawnSig Signature broken.");
		SetFailState("[ABM] RoundRespawnSig Signature broken.");
	}
}

void SetHumanSpecSig(int bot, int client) {
	Echo(2, "SetHumanSpecSig: %d %d", bot, client);

	static Handle hSpec;
	if (hSpec == null) {
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "SetHumanSpec");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		hSpec = EndPrepSDKCall();
	}

	if (IsClientValid(client) && IsClientValid(bot)) {
		if (hSpec != null) {
			SDKCall(hSpec, bot, client);
			ResetClientSpecUserId(client, bot);
		}

		else {
			PrintToChat(client, "[ABM] SetHumanSpecSig Signature broken.");
			SetFailState("[ABM] SetHumanSpecSig Signature broken.");
		}
	}
}

void ResetClientSpecUserId(int client, int target) {
	Echo(2, "ResetClientSpecUserId: %d %d", client, target);

	if (!IsClientValid(client) || !IsClientValid(target)) {
		return;
	}

	static int spec, userid;
	userid = GetClientUserId(client);

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientValid(i, 2, 0)) {
			if (HasEntProp(i, Prop_Send, "m_humanSpectatorUserID")) {
				spec = GetEntProp(i, Prop_Send, "m_humanSpectatorUserID");
				if (userid == spec && i != target) {
					SetEntProp(i, Prop_Send, "m_humanSpectatorUserID", 0);
				}
			}
		}
	}
}

void State_TransitionSig(int client, int mode) {
	Echo(2, "State_TransitionSig: %d %d", client, mode);

	static Handle hSpec;
	if (hSpec == null) {
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "State_Transition");
		PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
		hSpec = EndPrepSDKCall();
	}

	if (hSpec != null) {
		SDKCall(hSpec, client, mode);  // mode 8, press 8 to get closer
	}

	else {
		PrintToChat(client, "[ABM] State_TransitionSig Signature broken.");
		SetFailState("[ABM] State_TransitionSig Signature broken.");
	}
}

bool TakeoverBotSig(int client, int target) {
	Echo(2, "TakeoverBotSig: %d %d", client, target);

	if (!GetQRecord(client)) {
		return false;
	}

	static Handle hSwitch;

	if (hSwitch == null) {
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "TakeOverBot");
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		hSwitch = EndPrepSDKCall();
	}

	if (hSwitch != null) {
		if (IsClientInKickQueue(target)) {
			KickClient(target);
		}

		else if (IsClientValid(target, 2, 0)) {
			SwitchToSpec(client);

			if (GetRealClient(target) != client) {
				GetBotCharacter(target, g_model);
				g_QRecord.SetString("model", g_model, true);
				Echo(1, "--5: %N is model '%s'", client, g_model);
			}

			SetHumanSpecSig(target, client);
			SDKCall(hSwitch, client, true);

			Unqueue(client);
			g_QRecord.SetValue("status", true, true);
			return true;
		}
	}

	else {
		PrintToChat(client, "[ABM] TakeoverBotSig Signature broken.");
		SetFailState("[ABM] TakeoverBotSig Signature broken.");
	}

	g_QRecord.SetValue("lastid", target, true);
	if (GetClientTeam(client) == 1) {
		g_QRecord.SetValue("queued", true, true);
		QueueUp(client, 2);
	}

	return false;
}

bool TakeoverZombieBotSig(int client, int target, bool si_ghost) {
	Echo(2, "TakeoverZombieBotSig: %d %d %d", client, target, si_ghost);

	if (!GetQRecord(client)) {
		return false;
	}

	static Handle hSwitch;

	if (hSwitch == null) {
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_GameData, SDKConf_Signature, "TakeOverZombieBot");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		hSwitch = EndPrepSDKCall();
	}

	if (hSwitch != null) {
		if (IsClientInKickQueue(target)) {
			KickClient(target);
		}

		else if (IsClientValid(target, 3, 0) && IsPlayerAlive(target)) {
			SwitchToSpec(client);
			SDKCall(hSwitch, client, target);
			GetBotCharacter(target, g_model);
			g_QRecord.SetString("model", g_model, true);
			Echo(1, "--6: %N is model '%s'", client, g_model);

			if (si_ghost) {
				State_TransitionSig(client, 8);
				if (IsClientTank(client)) {
					CreateTimer(1.0, ForceSpawnTimer, client, TIMER_REPEAT);
				}
			}

			Unqueue(client);
			g_QRecord.SetValue("status", true, true);
			g_AssistedSpawning = true;
			return true;
		}
	}

	else {
		PrintToChat(client, "[ABM] TakeoverZombieBotSig Signature broken.");
		SetFailState("[ABM] TakeoverZombieBotSig Signature broken.");
	}

	g_QRecord.SetValue("lastid", target, true);
	if (GetClientTeam(client) == 1) {
		g_QRecord.SetValue("queued", true, true);
		QueueUp(client, 3);
	}

	return false;
}

// ================================================================== //
// PUBLIC INTERFACE AND MENU HANDLERS
// ================================================================== //

Action TeleportClientCmd(int client, int args) {
	Echo(2, "TeleportClientCmd: %d", client);

	int level;

	switch (args) {
		case 1: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg1 = StringToInt(g_sB);
		}

		case 2: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg0 = StringToInt(g_sB);
			GetCmdArg(2, g_sB, sizeof(g_sB));
			menuArg1 = StringToInt(g_sB);
		}
	}

	if (args) {
		level = 2;
	}

	TeleportClientHandler(client, level);
	return Plugin_Handled;
}

// TeleportClientHandler needs public otherwise it won't pass RegMenuHandler
public void TeleportClientHandler(int client, int level) {
	Echo(2, "TeleportClientHandler: %d %d", client, level);

	if (!RegMenuHandler(client, "TeleportClientHandler", level, 0)) {
		return;
	}

	switch (level) {
		case 0: TeamMatesMenu(client, "Teleport Client", 2, 1);
		case 1: {
			GetClientName(menuArg0, g_sB, sizeof(g_sB));
			Format(g_sB, sizeof(g_sB), "%s: Teleporting", g_sB);
			TeamMatesMenu(client, g_sB, 2, 1);
		}

		case 2: {
			if (CanClientTarget(client, menuArg0)) {
				if (GetClientTeam(menuArg0) <= 1) {
					menuArg0 = GetPlayClient(menuArg0);
				}

				TeleportClient(menuArg0, menuArg1);
			}

			GenericMenuCleaner(client);
		}
	}
}

Action SwitchTeamCmd(int client, int args) {
	Echo(2, "SwitchTeamCmd: %d", client);

	int level;

	char model[32];
	GetCmdArg(args, model, sizeof(model));
	int result = StringToInt(model);
	CleanSIName(model);

	if (args == 1 || args == 2 && result == 0) {
		menuArg0 = client;
		GetCmdArg(1, g_sB, sizeof(g_sB));
		menuArg1 = StringToInt(g_sB);
	}

	else if (args >= 2) {
		GetCmdArg(1, g_sB, sizeof(g_sB));
		menuArg0 = StringToInt(g_sB);
		GetCmdArg(2, g_sB, sizeof(g_sB));
		menuArg1 = StringToInt(g_sB);
	}

	if (args) {
		level = 2;
	}

	else if (!IsAdmin(client)) {
		menuArg0 = client;
		level = 1;
	}

	if (menuArg1 == 3 && GetQRecord(menuArg0)) {
		CleanSIName(model);
		g_QRecord.SetString("model", model, true);
		Echo(1, "--7: %N is model '%s'", menuArg0, model);
	}

	SwitchTeamHandler(client, level);
	return Plugin_Handled;
}

// SwitchTeamHandler needs public otherwise it won't pass RegMenuHandler
public void SwitchTeamHandler(int client, int level) {
	Echo(2, "SwitchTeamHandler: %d %d", client, level);

	if (!RegMenuHandler(client, "SwitchTeamHandler", level, 0)) {
		return;
	}

	switch (level) {
		case 0: TeamMatesMenu(client, "Switch Client's Team", 1);
		case 1: {
			GetClientName(menuArg0, g_sB, sizeof(g_sB));
			Format(g_sB, sizeof(g_sB), "%s: Switching", g_sB);
			TeamsMenu(client, g_sB);
		}

		case 2: {
			if (CanClientTarget(client, menuArg0)) {
				if (!IsAdmin(client) && menuArg1 == 3) {
					GenericMenuCleaner(client);
					return;
				}

				SwitchTeam(menuArg0, menuArg1);
			}

			GenericMenuCleaner(client);
		}
	}
}

Action AssignModelCmd(int client, int args) {
	Echo(2, "AssignModelCmd: %d", client);

	int level;

	switch (args) {
		case 1: {
			menuArg0 = client;
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg1 = GetModelIndexByName(g_sB);
		}

		case 2: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg1 = GetModelIndexByName(g_sB);
			GetCmdArg(2, g_sB, sizeof(g_sB));
			menuArg0 = StringToInt(g_sB);
		}
	}

	if (args) {
		level = 2;
	}

	AssignModelHandler(client, level);
	return Plugin_Handled;
}

// AssignModelHandler needs public otherwise it won't pass RegMenuHandler
public void AssignModelHandler(int client, int level) {
	Echo(2, "AssignModelHandler: %d %d", client, level);

	if (!RegMenuHandler(client, "AssignModelHandler", level, 0)) {
		return;
	}

	switch (level) {
		case 0: TeamMatesMenu(client, "Change Client's Model", 2, 0, false);
		case 1: {
			GetClientName(menuArg0, g_sB, sizeof(g_sB));
			Format(g_sB, sizeof(g_sB), "%s: Modeling", g_sB);
			ModelsMenu(client, g_sB);
		}

		case 2: {
			if (CanClientTarget(client, menuArg0)) {
				if (GetClientTeam(menuArg0) <= 1) {
					menuArg0 = GetPlayClient(menuArg0);
				}
				
				char temp_str[MAX_SURV_NAMESIZE];
				g_SurvivorNames.GetString(menuArg1, temp_str, MAX_SURV_NAMESIZE);
				AssignModel(menuArg0, temp_str, 1);
			}

			GenericMenuCleaner(client);
		}
	}
}

Action SwitchToBotCmd(int client, int args) {
	Echo(2, "SwitchToBotCmd: %d", client);

	int level;

	switch (args) {
		case 1: {
			menuArg0 = client;
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg1 = StringToInt(g_sB);
		}

		case 2: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg0 = StringToInt(g_sB);
			GetCmdArg(2, g_sB, sizeof(g_sB));
			menuArg1 = StringToInt(g_sB);
		}
	}

	if (args) {
		level = 2;
	}

	else if (!IsAdmin(client)) {
		menuArg0 = client;
		level = 1;
	}

	SwitchToBotHandler(client, level);
	return Plugin_Handled;
}

// SwitchToBotHandler needs public otherwise it won't pass RegMenuHandler
public void SwitchToBotHandler(int client, int level) {
	Echo(2, "SwitchToBotHandler: %d %d", client, level);

	int homeTeam = ClientHomeTeam(client);
	if (!RegMenuHandler(client, "SwitchToBotHandler", level, 0)) {
		return;
	}

	switch (level) {
		case 0: TeamMatesMenu(client, "Takeover Bot", 1);
		case 1: {
			GetClientName(menuArg0, g_sB, sizeof(g_sB));
			Format(g_sB, sizeof(g_sB), "%s: Takeover", g_sB);
			TeamMatesMenu(client, g_sB, 0, 0, true, false, homeTeam);
		}

		case 2: {
			if (CanClientTarget(client, menuArg0)) {
				if (IsClientValid(menuArg1)) {
					if (homeTeam != 3 && GetClientTeam(menuArg1) == 3) {
						if (!IsAdmin(client)) {
							GenericMenuCleaner(client);
							return;
						}
					}

					if (GetClientManager(menuArg1) == 0) {
						SwitchToBot(menuArg0, menuArg1, false);
					}
				}
			}

			GenericMenuCleaner(client);
		}
	}
}

Action RespawnClientCmd(int client, int args) {
	Echo(2, "RespawnClientCmd: %d", client);

	int level;

	switch (args) {
		case 1: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg0 = StringToInt(g_sB);
			menuArg1 = menuArg0;
		}

		case 2: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg0 = StringToInt(g_sB);
			GetCmdArg(2, g_sB, sizeof(g_sB));
			menuArg1 = StringToInt(g_sB);
		}
	}

	if (args) {
		level = 2;
	}

	RespawnClientHandler(client, level);
	return Plugin_Handled;
}

// RespawnClientHandler needs public otherwise it won't pass RegMenuHandler
public void RespawnClientHandler(int client, int level) {
	Echo(2, "RespawnClientHandler: %d %d", client, level);

	if (!RegMenuHandler(client, "RespawnClientHandler", level, 0)) {
		return;
	}

	switch (level) {
		case 0: TeamMatesMenu(client, "Respawn Client");
		case 1: {
			GetClientName(menuArg0, g_sB, sizeof(g_sB));
			Format(g_sB, sizeof(g_sB), "%s: Respawning", g_sB);
			TeamMatesMenu(client, g_sB);
		}

		case 2: {
			if (CanClientTarget(client, menuArg0)) {
				if (GetClientTeam(menuArg0) <= 1) {
					menuArg0 = GetPlayClient(menuArg0);
				}

				RespawnClient(menuArg0, menuArg1);
			}

			GenericMenuCleaner(client);
		}
	}
}

Action CycleBotsCmd(int client, int args) {
	Echo(2, "CycleBotsCmd: %d", client);

	int level;

	switch (args) {
		case 1: {
			menuArg0 = client;
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg1 = StringToInt(g_sB);
		}

		case 2: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg0 = StringToInt(g_sB);
			GetCmdArg(2, g_sB, sizeof(g_sB));
			menuArg1 = StringToInt(g_sB);
		}
	}

	if (args) {
		if (menuArg1 > 3 || menuArg1 < 2) {
			return Plugin_Handled;
		}

		level = 2;
	}

	CycleBotsHandler(client, level);
	return Plugin_Handled;
}

// CycleBotsHandler needs public otherwise it won't pass RegMenuHandler
public void CycleBotsHandler(int client, int level) {
	Echo(2, "CycleBotsHandler: %d %d", client, level);

	if (!RegMenuHandler(client, "CycleBotsHandler", level, 0)) {
		return;
	}

	switch (level) {
		case 0: TeamMatesMenu(client, "Cycle Client", 1);
		case 1: {
			GetClientName(menuArg0, g_sB, sizeof(g_sB));
			Format(g_sB, sizeof(g_sB), "%s: Cycling", g_sB);
			TeamsMenu(client, g_sB, false);
		}

		case 2: {
			if (CanClientTarget(client, menuArg0)) {
				if (!IsAdmin(client) && menuArg1 == 3) {
					GenericMenuCleaner(client);
					return;
				}

				CycleBots(menuArg0, menuArg1);
				menuArg1 = 0;
			}

			CycleBotsHandler(client, 1);
		}
	}
}

Action StripClientCmd(int client, int args) {
	Echo(2, "StripClientCmd: %d", client);

	int target;
	int level;

	switch (args) {
		case 1: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			target = StringToInt(g_sB);
			target = GetPlayClient(target);

			if (CanClientTarget(client, target)) {
				StripClient(target);
			}

			return Plugin_Handled;
		}

		case 2: {
			GetCmdArg(1, g_sB, sizeof(g_sB));
			menuArg0 = StringToInt(g_sB);
			GetCmdArg(2, g_sB, sizeof(g_sB));
			menuArg1 = StringToInt(g_sB);
		}
	}

	if (args) {
		level = 2;
	}

	StripClientHandler(client, level);
	return Plugin_Handled;
}

// StripClientHandler needs public otherwise it won't pass RegMenuHandler
public void StripClientHandler(int client, int level) {
	Echo(2, "StripClientHandler: %d %d", client, level);

	if (!RegMenuHandler(client, "StripClientHandler", level, 0)) {
		return;
	}

	switch (level) {
		case 0: TeamMatesMenu(client, "Strip Client", 2, 1);
		case 1: {
			GetClientName(menuArg0, g_sB, sizeof(g_sB));
			Format(g_sB, sizeof(g_sB), "%s: Stripping", g_sB);
			InvSlotsMenu(client, menuArg0, g_sB);
		}

		case 2: {
			if (CanClientTarget(client, menuArg0)) {
				if (GetClientTeam(menuArg0) <= 1) {
					menuArg0 = GetPlayClient(menuArg0);
				}

				StripClientSlot(menuArg0, menuArg1);
				menuArg1 = 0;
				StripClientHandler(client, 1);
			}
		}
	}
}

Action ResetCmd(int client, int args) {
	Echo(2, "ResetCmd: %d", client);

	for (int i = 1; i <= MaxClients; i++) {
		GenericMenuCleaner(i);
		if (GetQRecord(i)) {
			CancelClientMenu(i, true, null);
		}
	}
	
	return Plugin_Handled;
}

bool RegMenuHandler(int client, char [] handler, int level, int clearance=0) {
	Echo(2, "RegMenuHandler: %d %s %d %d", client, handler, level, clearance);

	g_callBacks.PushString(handler);
	if (!IsAdmin(client) && level <= clearance) {
		GenericMenuCleaner(client);
		return false;
	}

	return true;
}

Action MainMenuCmd(int client, int args) {
	Echo(2, "MainMenuCmd: %d", client);

	GenericMenuCleaner(client);
	MainMenuHandler(client, 0);
	return Plugin_Handled;
}

// MainMenuHandler needs public otherwise it won't pass RegMenuHandler
public void MainMenuHandler(int client, int level) {
	Echo(2, "MainMenuHandler: %d %d", client, level);

	if (!RegMenuHandler(client, "MainMenuHandler", level, 0)) {
		return;
	}

	int cmd = menuArg0;
	menuArg0 = 0;

	char title[32];
	Format(title, sizeof(title), "ABM Menu %s", PLUGIN_VERSION);

	switch (level) {
		case 0: MainMenu(client, title);
		case 1: {
			switch (cmd) {
				case 0: TeleportClientCmd(client, 0);
				case 1: SwitchTeamCmd(client, 0);
				case 2: AssignModelCmd(client, 0);
				case 3: SwitchToBotCmd(client, 0);
				case 4: RespawnClientCmd(client, 0);
				case 5: CycleBotsCmd(client, 0);
				case 6: StripClientCmd(client, 0);
			}
		}
	}
}

// ================================================================== //
// MENUS BACKBONE
// ================================================================== //

void GenericMenuCleaner(int client, bool clearStack=true) {
	Echo(2, "GenericMenuCleaner: %d %d", client, clearStack);

	for (int i = 0; i < sizeof(g_menuItems[]); i++) {
		g_menuItems[client][i] = 0;
	}

	if (clearStack == true) {
		if (g_callBacks != null) {
			delete g_callBacks;
		}

		g_callBacks = new ArrayStack(128);
	}
}

int GenericMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	Echo(2, "GenericMenuHandler: %d %d", param1, param2);

	int client = param1;
	int i;  // -1;
	char sB[128];

	if (IsClientValid(param1)) {
		for (i = 0; i < sizeof(g_menuItems[]); i++) {
			if (menuArgs[i] == 0) {
				break;
			}
		}
	}

	switch (action) {
		case MenuAction_Select: {
			menu.GetItem(param2, g_sB, sizeof(g_sB));
			menuArgs[i] = StringToInt(g_sB);
			i = i + 1;
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				if (i > 0) {
					i = i - 1;
					menuArgs[i] = 0;
				}

				else if (i == 0) {

					if (g_callBacks.Empty) {
						GenericMenuCleaner(param1);
						return 0;
					}

					g_callBacks.PopString(g_sB, sizeof(g_sB));
					GenericMenuCleaner(param1, false);

					while (!g_callBacks.Empty) {
						g_callBacks.PopString(sB, sizeof(sB));

						if (strcmp(g_sB, sB) != 0) {
							g_callBacks.PushString(sB);
							break;
						}
					}

					if (g_callBacks.Empty) {
						GenericMenuCleaner(param1);
						return 0;
					}
				}
			}

			else {
				return 0;
			}
		}

		case MenuAction_End: {
			delete menu;
			return 0;
		}
	}

	if (g_callBacks == null || g_callBacks.Empty) {
		GenericMenuCleaner(param1);
		return 0;
	}

	g_callBacks.PopString(g_sB, sizeof(g_sB));
	callBack = GetFunctionByName(null, g_sB);

	Call_StartFunction(null, callBack);
	Call_PushCell(param1);
	Call_PushCell(i);
	Call_Finish();
	return 0;
}

// ================================================================== //
// MENUS
// ================================================================== //

void MainMenu(int client, char [] title) {
	Echo(2, "MainMenu: %d %s", client, title);

	Menu menu = new Menu(GenericMenuHandler);
	menu.SetTitle(title);
	menu.AddItem("0", "Teleport Client");  // "Telespiznat");	// teleport
	menu.AddItem("1", "Switch Client Team");  //"Swintootle");	// switch team
	menu.AddItem("2", "Change Client Model");  //"Changdangle");	// makeover
	menu.AddItem("3", "Switch Client Bot");  //"Inbosnachup");	// takeover
	menu.AddItem("4", "Respawn Client");  //"Respiggle");		// respawn
	menu.AddItem("5", "Cycle Client");  //"Cycolicoo");		// cycle
	menu.AddItem("6", "Strip Client");  //"Upsticky");		// strip
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, 120);
}

void InvSlotsMenu(int client, int target, char [] title) {
	Echo(2, "InvSlotsMenu: %d %d %s", client, target, title);

	int ent;
	char weapon[64];
	Menu menu = new Menu(GenericMenuHandler);
	menu.SetTitle(title);

	for (int i; i < 5; i++) {
		IntToString(i, g_sB, sizeof(g_sB));
		ent = GetPlayerWeaponSlot(target, i);

		if (IsEntityValid(ent)) {
			GetEntityClassname(ent, weapon, sizeof(weapon));
			menu.AddItem(g_sB, weapon);
		}
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, 120);
}

void ModelsMenu(int client, char [] title) {
	Echo(2, "ModelsMenu: %d %s", client, title);

	Menu menu = new Menu(GenericMenuHandler);
	menu.SetTitle(title);

	char temp_str[MAX_SURV_NAMESIZE];
	for (int i; i < g_SurvivorNames.Length; i++) {
		g_SurvivorNames.GetString(i, temp_str, MAX_SURV_NAMESIZE);
		
		IntToString(i, g_sB, sizeof(g_sB));
		menu.AddItem(g_sB, temp_str);
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, 120);
}

void TeamsMenu(int client, char [] title, bool all=true) {
	Echo(2, "TeamsMenu: %d %s %d", client, title, all);

	Menu menu = new Menu(GenericMenuHandler);
	menu.SetTitle(title);

	if (all) {
		menu.AddItem("0", "Idler");
		menu.AddItem("1", "Spectator");
	}

	menu.AddItem("2", "Survivor");
	if (IsAdmin(client)) {
		menu.AddItem("3", "Infected");
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, 120);
}

void TeamMatesMenu(int client, char [] title, int mtype=2, int target=0, bool incDead=true,
			bool repeat=false, int homeTeam=0) {
	Echo(2, "TeamMatesMenu: %d %s %d %d %d %d %d", client, title, mtype, target, incDead, repeat, homeTeam);

	Menu menu = new Menu(GenericMenuHandler);
	menu.SetTitle(title);
	int isAdmin = IsAdmin(client);
	char health[32];
	bool mflag = false;
	int isAlive;
	int playClient;
	int bossClient;
	int targetClient;
	int manager;

	for (int i = 1; i <= MaxClients; i++) {
		bossClient = i;
		playClient = i;

		if (GetQRecord(i)) {

			if (mtype == 0) {
				continue;
			}

			if (mtype == 1 || mtype == 2) {
				mflag = true;
			}

			if (IsClientValid(g_target) && g_target != i) {
				isAlive = IsPlayerAlive(g_target);
				playClient = g_target;
			}

			else {
				isAlive = IsPlayerAlive(i);
			}
		}

		else if (IsClientValid(i)) {
			isAlive = IsPlayerAlive(i);

			if (mtype == 0 || mtype == 2) {
				mflag = true;
			}

			manager = GetClientManager(i);

			if (manager != 0) {
				if (target == 0 || !repeat) {
					mflag = false;
					continue;
				}

				bossClient = manager;
			}
		}

		else {
			continue;
		}

		// at this point the client is valid.
		// bossClient is the human (if there is one)
		// playClient is the bot (or human if not idle)

		if (!isAlive && !incDead) {
			continue;
		}
		
		if (GetClientTeam(playClient) != homeTeam && !isAdmin) {
			continue;
		}

		switch (target) {
			case 0: targetClient = bossClient;
			case 1: targetClient = playClient;
		}

		if (mflag) {
			mflag = false;

			int hp = GetClientHealth(playClient);
			
			Format(health, sizeof(health), "%i", hp);
			if (!IsPlayerAlive(playClient)) {
				Format(health, sizeof(health), "DEAD");
			}

			else if (GetEntProp(playClient, Prop_Send, "m_isIncapacitated")) {
				Format(health, sizeof(health), "DOWN %i", hp);
			}

			GetClientName(bossClient, g_pN, sizeof(g_pN));
			Format(g_pN, sizeof(g_pN), "%s  (%s)", g_pN, health);
			IntToString(targetClient, g_sB, sizeof(g_sB));

			switch (bossClient == client && menu.ItemCount > 0) {
				case false: menu.AddItem(g_sB, g_pN);
				case true: menu.InsertItem(0, g_sB, g_pN);
			}
		}
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, 120);
}

// ================================================================== //
// MISC STUFF USEFUL FOR TROUBLESHOOTING
// ================================================================== //

void Echo(int level, char [] format, any ...) {
	static char g_dB[512];

	if (g_LogLevel >= level) {
		VFormat(g_dB, sizeof(g_dB), format, 3);
		LogToFile(LOGFILE, g_dB);
		PrintToServer("%s", g_dB);
	}
}

void QDBCheckCmd(int client) {
	Echo(2, "QDBCheckCmd");

	PrintToConsole(client, "-- STAT: QDB Size is %d", g_QDB.Size);
	PrintToConsole(client, "-- MinPlayers is %d", g_MinPlayers);

	for (int i = 1; i <= MaxClients; i++) {
		if (GetQRtmp(i)) {
			PrintToConsole(client, "\n -");
			GetClientName(i, g_pN, sizeof(g_pN));

			float x = g_origin[0];
			float y = g_origin[1];
			float z = g_origin[2];

			PrintToConsole(client, " - Name: %s", g_pN);
			PrintToConsole(client, " - Origin: {%d.0, %d.0, %d.0}", x, y, z);
			PrintToConsole(client, " - Status: %d", g_tmpStatus);
			PrintToConsole(client, " - Client: %d", g_tmpClient);
			PrintToConsole(client, " - Target: %d", g_tmpTarget);
			PrintToConsole(client, " - LastId: %d", g_tmpLastid);
			PrintToConsole(client, " - OnTeam: %d", g_tmpOnteam);
			PrintToConsole(client, " - Queued: %d", g_tmpQueued);
			PrintToConsole(client, " - InSpec: %d", g_tmpInspec);
			PrintToConsole(client, " - Model: %s", g_tmpModel);
			PrintToConsole(client, " -\n");
		}
	}
}

Action QuickClientPrintCmd(int client, int args) {
	Echo(2, "QuickClientPrintCmd: %d", client);

	int onteam;
	int state;
	int manager;

	PrintToConsole(client, "\nTeam\tState\tId\tManager\tName");

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientValid(i)) {
			manager = i;
			GetClientName(i, g_pN, sizeof(g_pN));
			onteam = GetClientTeam(i);
			state = IsPlayerAlive(i);


			if (IsFakeClient(i)) {
				manager = GetClientManager(i);
			}

			PrintToConsole(client,
				"%d, \t%d, \t%d, \t%d, \t%s", onteam, state, i, manager, g_pN
			);
		}
	}

	QDBCheckCmd(client);
	
	return Plugin_Handled;
}
