#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>

#define MAX_MELEES sizeof(MeleeCommandNames)
#define MAX_GUNS sizeof(GunCommandNames)
#define MAX_SNIPERS sizeof(SniperCommandNames)
#define MAX_ITEMS sizeof(ItemCommandNames)

static const char MeleeCommandNames[][] =
{
	"sm_knife",
	"sm_baseball",
	//"sm_chainsaw",
	"sm_cricket",
	"sm_crowbar",
	//"sm_didgeridoo",
	"sm_guitar",
	"sm_fireaxe",
	"sm_fryingpan",
	"sm_golfclub",
	"sm_katana",
	"sm_machete",
	//"sm_riotshield",
	"sm_tonfa",
	"sm_shovel",
	"sm_pitchfork"
};

static const char LongMeleeWeaponNames[][] =
{
	"Knife",
	"Baseball Bat",
	//"Chainsaw",
	"Cricket Bat",
	"Crowbar",
	//"didgeridoo", // derp
	"Guitar",
	"Fireaxe",
	"Frying Pan",
	"Golf Club",
	"Katana",
	"Machete",
	//"Riot Shield",
	"Tonfa",
	"Shovel",
	"Pitchfork"
};

// Internal names for melee weapons
static const char MeleeWeaponNames[][] =
{
	"knife",
	"baseball_bat",
	//"chainsaw",
	"cricket_bat",
	"crowbar",
	//"didgeridoo",
	"electric_guitar",
	"fireaxe",
	"frying_pan",
	"golfclub",
	"katana",
	"machete",
	//"riotshield",
	"tonfa",
	"shovel",
	"pitchfork"
};

static const char GunCommandNames[][] =
{
	"sm_pump",
	"sm_chrome",
	"sm_uzi",
	"sm_mac",
	"sm_mp5",
	"sm_deagle"
};

static const char LongGunWeaponNames[][] =
{
	"Pump Shotgun",
	"Chrome Shotgun",
	"Uzi",
	"Mac-10",
	"Mp5",
	"Deagle"
};

// Internal names for gun weapons
static const char GunWeaponNames[][] =
{
	"pumpshotgun",
	"shotgun_chrome",
	"smg",
	"smg_silenced",
	"smg_mp5",
	"pistol_magnum"
};

static const char SniperCommandNames[][] =
{
	"sm_scout",
	"sm_awp"
};

static const char LongSniperWeaponNames[][] =
{
	"Scout",
	"AWP"
};

// Internal names for gun weapons
static const char SniperWeaponNames[][] =
{
	"sniper_scout",
	"sniper_awp"
};

static const char ItemCommandNames[][] =
{
	"sm_gnome",
	"sm_cola"
};

static const char LongItemWeaponNames[][] =
{
	"Gnome",
	"Cola Bottles"
};

// Internal names for items
static const char ItemWeaponNames[][] =
{
	"gnome",
	"cola_bottles"
};

StringMap
	g_hMeleeCommandMap,
	g_hGunCommandMap,
	g_hRequestLimitMap;

ConVar
	g_hRequestLimit;

bool
	g_bFromMainMenu[MAXPLAYERS+1],
	g_bRoundLive;

#define TRANSLATION_FILE "l4d2_weapon_request.phrases"
void LoadPluginTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "translations/" ... TRANSLATION_FILE ... ".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translations \"" ... TRANSLATION_FILE ... "\"");
	}
	LoadTranslations(TRANSLATION_FILE);
}

public void OnPluginStart()
{
	LoadPluginTranslations();
	
	g_hRequestLimitMap = new StringMap();
	g_hRequestLimit = CreateConVar("l4d_weapon_req_limit", "4", "", FCVAR_NOTIFY, true, 0.0);
	
	RegConsoleCmd("sm_w", Cmd_Weapon);
	RegConsoleCmd("sm_weapon", Cmd_Weapon);
	
	RegConsoleCmd("sm_melee", Cmd_Melee);
	RegConsoleCmd("sm_gun", Cmd_Gun);
	RegConsoleCmd("sm_t1", Cmd_Gun);
	RegConsoleCmd("sm_sniper", Cmd_Sniper);
	RegConsoleCmd("sm_item", Cmd_Item);
	
	for (int i = 0; i < MAX_MELEES; ++i)
	{
		RegConsoleCmd(MeleeCommandNames[i], Cmd_GiveMelee);
	}
	
	for (int i = 0; i < MAX_GUNS; ++i)
	{
		RegConsoleCmd(GunCommandNames[i], Cmd_GiveGun);
	}
	
	for (int i = 0; i < MAX_SNIPERS; ++i)
	{
		RegConsoleCmd(SniperCommandNames[i], Cmd_GiveGun);
	}
	
	for (int i = 0; i < MAX_SNIPERS; ++i)
	{
		RegConsoleCmd(ItemCommandNames[i], Cmd_GiveGun);
	}
	
	BuildCommandMap();
	
	//HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
}

Handle SpecInfo = INVALID_HANDLE;
public void OnMapStart(){
	if(SpecInfo == INVALID_HANDLE)
		SpecInfo = CreateTimer(60.0, PrintSpecInfo, true);
}

public void OnMapEnd(){
	if(SpecInfo != INVALID_HANDLE)
	{
		CloseHandle(SpecInfo);
		SpecInfo = INVALID_HANDLE;
	}
}

public Action PrintSpecInfo(Handle timer, bool repeat)
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsValidClient(i) && GetClientTeam(i) == 2)
			CPrintToChat(i, "%t", "advertise");
	if(repeat)
		CreateTimer(60.0, PrintSpecInfo, true);
}

void BuildCommandMap()
{
	g_hMeleeCommandMap = new StringMap();
	for (int i = 0;
		i < MAX_MELEES;
		g_hMeleeCommandMap.SetString(MeleeCommandNames[i], MeleeWeaponNames[i]), ++i) {}
	
	g_hGunCommandMap = new StringMap();
	for (int i = 0;
		i < MAX_GUNS;
		g_hGunCommandMap.SetString(GunCommandNames[i], GunWeaponNames[i]), ++i) {}
	for (int i = 0;
		i < MAX_SNIPERS;
		g_hGunCommandMap.SetString(SniperCommandNames[i], SniperWeaponNames[i]), ++i) {}
	for (int i = 0;
		i < MAX_ITEMS;
		g_hGunCommandMap.SetString(ItemCommandNames[i], ItemWeaponNames[i]), ++i) {}
}

Action Cmd_Weapon(int client, int args)
{
	if (!client) return Plugin_Continue;
	
	if (IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		Menu menu = new Menu(WeaponMenuHandler);
		menu.SetTitle("%T", "Weapon Manu Title", client);
		
		char buffer[256];
		FormatEx(buffer, sizeof(buffer), "%T (!melee)", "Melee", client);
		menu.AddItem("sm_melee", buffer);
		FormatEx(buffer, sizeof(buffer), "%T (!gun)", "Gun", client);
		menu.AddItem("sm_gun", buffer);
		FormatEx(buffer, sizeof(buffer), "%T (!sniper)", "Sniper", client);
		menu.AddItem("sm_sniper", buffer);
		FormatEx(buffer, sizeof(buffer), "%T (!item)", "Item", client);
		menu.AddItem("sm_item", buffer);
		
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

int WeaponMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_bFromMainMenu[param1] = true;
			char info[16];
			menu.GetItem(param2, info, sizeof(info));
			FakeClientCommand(param1, "%s", info);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

Action Cmd_Melee(int client, int args)
{
	if (!client) return Plugin_Continue;
	
	if (IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		Menu menu = new Menu(SecondMenuHandler);
		menu.SetTitle("%T", "Melee Menu Title", client);
		
		char buffer[64];
		for (int i = 0; i < MAX_MELEES; ++i)
		{
			FormatEx(buffer, sizeof(buffer), "%T (!%s)", LongMeleeWeaponNames[i], client, MeleeCommandNames[i][3]);
			menu.AddItem(MeleeCommandNames[i], buffer);
		}
		
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

Action Cmd_Gun(int client, int args)
{
	if (!client) return Plugin_Continue;
	
	if (IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		Menu menu = new Menu(SecondMenuHandler);
		menu.SetTitle("%T", "Gun Menu Title", client);
		
		char buffer[64];
		for (int i = 0; i < MAX_GUNS; ++i)
		{
			FormatEx(buffer, sizeof(buffer), "%T (!%s)", LongGunWeaponNames[i], client, GunCommandNames[i][3]);
			menu.AddItem(GunCommandNames[i], buffer);
		}
		
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

Action Cmd_Sniper(int client, int args)
{
	if (!client) return Plugin_Continue;
	
	if (IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		Menu menu = new Menu(SecondMenuHandler);
		menu.SetTitle("%T", "Sniper Menu Title", client);
		
		char buffer[64];
		for (int i = 0; i < MAX_SNIPERS; ++i)
		{
			FormatEx(buffer, sizeof(buffer), "%T (!%s)", LongSniperWeaponNames[i], client, SniperCommandNames[i][3]);
			menu.AddItem(SniperCommandNames[i], buffer);
		}
		
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

Action Cmd_Item(int client, int args)
{
	if (!client) return Plugin_Continue;
	
	if (IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		Menu menu = new Menu(SecondMenuHandler);
		menu.SetTitle("%T", "Item Menu Title", client);
		
		char buffer[64];
		for (int i = 0; i < MAX_ITEMS; ++i)
		{
			FormatEx(buffer, sizeof(buffer), "%T (!%s)", LongItemWeaponNames[i], client, ItemCommandNames[i][3]);
			menu.AddItem(ItemCommandNames[i], buffer);
		}
		
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

int SecondMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[16];
			menu.GetItem(param2, info, sizeof(info));
			FakeClientCommand(param1, "%s", info);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_Exit && g_bFromMainMenu[param1])
			{
				g_bFromMainMenu[param1] = false;
				Cmd_Weapon(param1, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

Action Cmd_GiveMelee(int client, int args)
{
	if (!client) return Plugin_Continue;
	
	if (IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		if (TestClientRequest(client))
		{
			char buffer[32];
			GetCmdArg(0, buffer, sizeof(buffer));
			
			char sName[32];
			if (g_hMeleeCommandMap.GetString(buffer, sName, sizeof(sName)))
			{
				GiveMelee(client, sName);
			}
		}
	}
	
	return Plugin_Handled;
}

Action Cmd_GiveGun(int client, int args)
{
	if (!client) return Plugin_Continue;
	
	if (IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		if (TestClientRequest(client))
		{
			char buffer[32];
			GetCmdArg(0, buffer, sizeof(buffer));
			
			char sName[32];
			if (g_hGunCommandMap.GetString(buffer, sName, sizeof(sName)))
			{
				GiveCommand(client, sName);
			}
		}
	}
	
	return Plugin_Handled;
}

bool TestClientRequest(int client)
{
	if (g_bRoundLive)
	{
		CPrintToChat(client, "%t", "TestClientRequest_RoundLive");
		return false;
	}
	
	if (g_hRequestLimit.IntValue == 0)
	{
		return true;
	}
	
	char auth[65];
	if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
	{
		if (IsClientInGame(client))
			CPrintToChat(client, "%t", "TestClientRequest_AuthId");
		
		return false;
	}
	
	int count = g_hRequestLimit.IntValue;
	if (g_hRequestLimitMap.GetValue(auth, count))
	{
		if (count == 0)
		{
			CPrintToChat(client, "%t", "TestClientRequest_ChanceOut");
			return false;
		}
	}
	
	g_hRequestLimitMap.SetValue(auth, --count);
	CPrintToChat(client, "%t", "TestClientRequest_Remaining", count, g_hRequestLimit.IntValue);
	return true;
}

bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientConnected(client) || !IsClientInGame(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}


public void OnClientPutInServer(int client)
{
	g_bFromMainMenu[client] = false;
	if(IsValidClient(client) && GetClientTeam(client) == 2)
	{
		//修改时间
		CreateTimer(30.0, Advertise, client);
	}
}

public Action Advertise(Handle timer, int client)
{
	//修改广告参数
	CPrintToChat(client, "%t", "advertise", client);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundLive = false;
	g_hRequestLimitMap.Clear();
}

public void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	int team = event.GetInt("team");
	if(IsValidClient(client) && team == 2)
	{
		//修改时间
		CreateTimer(30.0, Advertise, client);
	}
}

void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundLive = true;
}

void GiveMelee(int client, const char[] sScriptName)
{
	int entity = CreateEntityByName("weapon_melee");
	if (!IsValidEntity(entity)) return;
	DispatchKeyValue(entity, "melee_script_name", sScriptName);
	float origin[3];
	GetClientEyePosition(client, origin);
	TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	EquipPlayerWeapon(client, entity);
}

void GiveCommand(int client, const char[] sArg)
{
	int flags = GetCommandFlags("give");
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", sArg);
	SetCommandFlags("give", flags);
}

