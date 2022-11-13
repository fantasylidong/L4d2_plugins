#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>
#include <l4d2_direct>
#include <l4d2lib>
#include <colors>

#define HORDE_MIN_SIZE_AUDIAL_FEEDBACK	120
#define MAX_CHECKPOINTS					4

#define HORDE_SOUND	"/npc/mega_mob/mega_mob_incoming.wav"

new Handle:hCvarNoEventHordeDuringTanks;
new Handle:hCvarHordeCheckpointAnnounce;

new Address:pZombieManager = Address_Null;

new commonLimit;
new commonTotal;
new lastCheckpoint;

new bool:announcedInChat;
new bool:checkpointAnnounced[MAX_CHECKPOINTS];

public Plugin:myinfo = 
{
	name = "L4D2 Horde Equaliser Debug",
	author = "Visor (original idea by Sir), debug by devilesk",
	description = "Make certain event hordes finite",
	version = "3.0.5b",
	url = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart()
{
	new Handle:gamedata = LoadGameConfigFile("left4downtown.l4d2");
	if (!gamedata)
	{
		SetFailState("Left4Downtown2 gamedata missing or corrupt");
	}

	pZombieManager = GameConfGetAddress(gamedata, "ZombieManager");
	if (!pZombieManager)
	{
		SetFailState("Couldn't find the 'ZombieManager' address");
	}

	hCvarNoEventHordeDuringTanks = CreateConVar("l4d2_heq_no_tank_horde", "0", "Put infinite hordes on a 'hold up' during Tank fights");
	hCvarHordeCheckpointAnnounce = CreateConVar("l4d2_heq_checkpoint_sound", "1", "Play the incoming mob sound at checkpoints (each 1/4 of total commons killed off) to simulate L4D1 behaviour");

	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
    
    RegConsoleCmd("sm_debug_horde", Command_DebugHorde);
}

public Action:Command_DebugHorde(client, args)  {
    CPrintToChatAll("commonTotal: %i", commonTotal);
    CPrintToChatAll("IsInfiniteHordeActive: %i", IsInfiniteHordeActive());
}

public OnMapStart()
{
	commonLimit = L4D2_GetMapValueInt("horde_limit", -1);

	PrecacheSound(HORDE_SOUND);
}

public OnRoundStart()
{
	commonTotal = 0;
	lastCheckpoint = 0;
	announcedInChat = false;
	for (new i = 0; i < MAX_CHECKPOINTS; i++)
	{
		checkpointAnnounced[i] = false;
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	// TO-DO: Find a value that tells wanderers from active event commons?
	if (StrEqual(classname, "infected", false) && IsInfiniteHordeActive())
	{
        CPrintToChatAll("commonTotal: %i", commonTotal);
        CPrintToChatAll("hCvarNoEventHordeDuringTanks: %i", GetConVarBool(hCvarNoEventHordeDuringTanks));
        CPrintToChatAll("IsTankUp: %i", IsTankUp());
        CPrintToChatAll("HORDE_MIN_SIZE_AUDIAL_FEEDBACK: %i", HORDE_MIN_SIZE_AUDIAL_FEEDBACK);
		// Don't count in boomer hordes, alarm cars and wanderers during a Tank fight
		if (GetConVarBool(hCvarNoEventHordeDuringTanks) && IsTankUp())
		{
            CPrintToChatAll("Don't count in boomer hordes, alarm cars and wanderers during a Tank fight");
			return;
		}
		
		// Horde too small for audial feedback
		/*if (commonLimit < HORDE_MIN_SIZE_AUDIAL_FEEDBACK)
		{
            CPrintToChatAll("Horde too small for audial feedback");
			return;
		}*/
		
		// Our job here is done
		if (commonTotal >= commonLimit)
		{
            CPrintToChatAll("Our job here is done");
			return;
		}
		
		commonTotal++;
		if (GetConVarBool(hCvarHordeCheckpointAnnounce) && 
			(commonTotal >= ((lastCheckpoint + 1) * RoundFloat(float(commonLimit / MAX_CHECKPOINTS))))
		) {
			EmitSoundToAll(HORDE_SOUND);
			checkpointAnnounced[lastCheckpoint] = true;
			lastCheckpoint++;
		}
	}
}

public Action:L4D_OnSpawnMob(&amount)
{
	/////////////////////////////////////
	// - Called on Event Hordes.
	// - Called on Panic Event Hordes.
	// - Called on Natural Hordes.
	// - Called on Onslaught (Mini-finale or finale Scripts)

	// - Not Called on Boomer Hordes.
	// - Not Called on z_spawn mob.
	////////////////////////////////////
	
	// "Pause" the infinite horde during the Tank fight
	if (GetConVarBool(hCvarNoEventHordeDuringTanks) && IsTankUp() && IsInfiniteHordeActive())
	{
		SetPendingMobCount(0);
		amount = 0;
		return Plugin_Handled;
	}

	// Excluded map -- don't block any infinite hordes on this one
	if (commonLimit < 0)
	{
		return Plugin_Continue;
	}

	// If it's a "finite" infinite horde...
	if (IsInfiniteHordeActive())
	{
		if (!announcedInChat)
		{
			CPrintToChatAll("<{olive}DEBUG{default}> A {blue}finite event{default} of {olive}%i{default} commons has started! Rush or wait it out, the choice is yours!", commonLimit);
			announcedInChat = true;
		}
		
		// ...and it's overlimit...
		if (commonTotal >= commonLimit)
		{
			SetPendingMobCount(0);
			amount = 0;
			return Plugin_Handled;
		}
		// commonTotal += amount;
	}
	
	// ...or not.
	return Plugin_Continue;
}

bool:IsInfiniteHordeActive()
{
	new countdown = GetHordeCountdown();
	return (/*GetPendingMobCount() > 0 &&*/ countdown > -1 && countdown <= 10);
}

// GetPendingMobCount()
// {
	// return LoadFromAddress(pZombieManager + Address:528, NumberType_Int32);
// }

SetPendingMobCount(count)
{
	return StoreToAddress(pZombieManager + Address:528, count, NumberType_Int32);
}

GetHordeCountdown()
{
	return CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer()) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : -1;
}

bool:IsTankUp()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(i))
		{
			return true;
		}
	}
	return false;
}