//https://forums.alliedmods.net/showthread.php?t=228244
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <clientprefs>

#pragma newdecls required

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

char abilities[][] = {"", "Tongue", "Vomit", "Pounce", "Spit", "Jockey", "Charge"};
Handle g_hTextEnabledCookie;
Handle g_hSoundEnabledCookie;
bool g_bTextEnabled[MAXPLAYERS+1];
bool g_bSoundEnabled[MAXPLAYERS+1];
ConVar g_hSpitInterval;
ConVar g_hChargeInterval;

public Plugin myinfo =
{
	name = "SI Cooldown Alert",
	author = "devilesk",
	version = "1.1.0",
	description = "Tell SI how long their ability is on cooldown for after despawning.",
	url = "https://github.com/devilesk/rl4d2l-plugins"
}

public void OnPluginStart()
{
	g_hSpitInterval = FindConVar("z_spit_interval");
	g_hChargeInterval = FindConVar("z_charge_interval");
	g_hTextEnabledCookie = RegClientCookie("si_cooldown_alert_text", "0 = disabled, 1 = enable text notification", CookieAccess_Protected);
	g_hSoundEnabledCookie = RegClientCookie("si_cooldown_alert_sound", "0 = disabled, 1 = enable sound notification", CookieAccess_Protected);
	SetCookiePrefabMenu(g_hTextEnabledCookie, CookieMenu_OnOff_Int, "SI Cooldown Alert Text", CookieHandler);
	SetCookiePrefabMenu(g_hSoundEnabledCookie, CookieMenu_OnOff_Int, "SI Cooldown Alert Sound", CookieHandler);

	for (int i = 1; i <= MaxClients; i++)
	{
		// default values
		g_bTextEnabled[i] = true;
		g_bSoundEnabled[i] = true;

		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		
		OnClientCookiesCached(i);
	}
}

public void CookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen) {}

public void OnMapStart()
{
	PrecacheSound("buttons/blip1.wav");
	PrecacheSound("buttons/blip2.wav");
}

public void OnClientCookiesCached(int client)
{
	char sValue[8] = "";
	
	GetClientCookie(client, g_hTextEnabledCookie, sValue, sizeof(sValue));
	if (sValue[0] == '\0')
	{
		g_bTextEnabled[client] = true;
	}
	else
	{
		g_bTextEnabled[client] = StringToInt(sValue) > 0;
	}

	GetClientCookie(client, g_hSoundEnabledCookie, sValue, sizeof(sValue));
	if (sValue[0] == '\0')
	{
		g_bSoundEnabled[client] = true;
	}
	else
	{
		g_bSoundEnabled[client] = StringToInt(sValue) > 0;
	}
}

public void L4D_OnEnterGhostState(int client)
{
	if (!IsValidClient(client)) return;

	if (AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}
	else
	{
		g_bTextEnabled[client] = true;
		g_bSoundEnabled[client] = true;
	}

	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (ability <= 0) return;

	float timestamp = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
	float remainingtime = timestamp - GetGameTime();
	int class = GetEntProp(client, Prop_Send, "m_zombieClass");

	// fix bug where spitter gets 3600s cooldown if they're on a ladder and spit then despawn
	if (class == ZC_SPITTER)
	{
		float spit_interval = GetConVarFloat(g_hSpitInterval);
		if (remainingtime > spit_interval)
		{
			SetEntPropFloat(ability, Prop_Send, "m_duration", spit_interval);
			SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + spit_interval);
			remainingtime = spit_interval;
		}
	}
	// fix bug where charger gets 3600s cooldown if they death charge then despawn
	else if (class == ZC_CHARGER)
	{
		float charge_interval = GetConVarFloat(g_hChargeInterval);
		if (remainingtime > charge_interval)
		{
			SetEntPropFloat(ability, Prop_Send, "m_duration", charge_interval);
			SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + charge_interval);
			remainingtime = charge_interval;
		}
	}


	if (remainingtime >= 3)
		CreateTimer(remainingtime - 3.0, Timer_NotifyAbilitySound, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE );

	if (remainingtime >= 2)
		CreateTimer(remainingtime - 2.0, Timer_NotifyAbilitySound, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE );

	if (remainingtime >= 1)
	{

		if (g_bTextEnabled[client])
			CPrintToChat(client, "{default}%s ready in {green}%0.1fs{default}.", abilities[class], remainingtime);

		CreateTimer(remainingtime - 1.0, Timer_NotifyAbilitySound, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE );

		DataPack dp;
		CreateDataTimer(remainingtime, Timer_NotifyAbilityCooldown, dp, TIMER_FLAG_NO_MAPCHANGE );
		dp.WriteCell(GetClientUserId(client));
		dp.WriteCell(class);
	}
}

public Action Timer_NotifyAbilityCooldown(Handle timer, DataPack dp)
{
	dp.Reset();
	int client = GetClientOfUserId(dp.ReadCell());
	int class = dp.ReadCell();

	if (IsInfected(client) && IsPlayerAlive(client))
	{
		if (g_bTextEnabled[client])
			CPrintToChat(client, "{lightgreen}%s ready.", abilities[class]);
		if (g_bSoundEnabled[client])
			EmitSoundToClient(client, "buttons/blip2.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	}

	return Plugin_Stop;
}

public Action Timer_NotifyAbilitySound(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsInfected(client) && IsPlayerAlive(client) && g_bSoundEnabled[client])
		EmitSoundToClient(client, "buttons/blip1.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);

	return Plugin_Stop;
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

stock bool IsInfected(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 3;
}