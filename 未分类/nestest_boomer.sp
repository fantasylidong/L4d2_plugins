#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define L4D2 Nauseating Boomer
#define PLUGIN_VERSION "1.2"

#define STRING_LENGHT								56
#define ZOMBIECLASS_BOOMER 							2

static const String:GAMEDATA_FILENAME[]				= "L4D2_ViciousPlugins";
static const String:VELOCITY_ENTPROP[]					= "m_vecVelocity";
static const Float:SLAP_VERTICAL_MULTIPLIER			= 1.5;
static const Float:TRACE_TOLERANCE 					= 25.0;

// ===========================================
// Boomer Setup
// ===========================================

// =================================
// Bile Belly
// =================================

//Bools
new bool:isBileBelly = false;

//Handles
new Handle:cvarBileBelly;
new Handle:cvarBileBellyAmount;

// =================================
// Bile Blast
// =================================

//Bools
new bool:isBileBlast = false;

//Handles
new Handle:cvarBileBlast;
new Handle:cvarBileBlastInnerPower;
new Handle:cvarBileBlastOuterPower;
new Handle:cvarBileBlastInnerDamage;
new Handle:cvarBileBlastOuterDamage;
new Handle:cvarBileBlastInnerRange;
new Handle:cvarBileBlastOuterRange;

// =================================
// Bile Feet
// =================================

//Bools
new bool:isBileFeet = false;

//Handles
new Handle:cvarBileFeet;
new Handle:cvarBileFeetSpeed;
new Handle:cvarBileFeetTimer[MAXPLAYERS+1] = INVALID_HANDLE;

// =================================
// Bile Mask
// =================================

//Bools
new bool:isBileMask = false;
new bool:isBileMaskTilDry = false;

//Handles
new Handle:cvarBileMask;
new Handle:cvarBileMaskState;
new Handle:cvarBileMaskAmount;
new Handle:cvarBileMaskDuration;
new Handle:cvarBileMaskTimer[MAXPLAYERS + 1] = INVALID_HANDLE;


// =================================
// Bile Pimple
// =================================

//Bools
new bool:isBilePimple = false;

//Handles
new Handle:cvarBilePimple;
new Handle:cvarBilePimpleChance;
new Handle:cvarBilePimpleDamage;
new Handle:cvarBilePimpleRange;
new Handle:cvarBilePimpleTimer[MAXPLAYERS+1] = INVALID_HANDLE;

// =================================
// Bile Shower
// =================================

//Bools
new bool:isBileShower = false;
new bool:isBileShowerTimeout;

//Handles
new Handle:cvarBileShower;
new Handle:cvarBileShowerTimeout;
new Handle:cvarBileShowerTimer[MAXPLAYERS + 1] = INVALID_HANDLE;

// =================================
// Bile Swipe
// =================================

//Bools
new bool:isBileSwipe = false;

//Handles
new Handle:cvarBileSwipe;
new Handle:cvarBileSwipeChance;
new Handle:cvarBileSwipeDamage;
new Handle:cvarBileSwipeDuration;
new Handle:cvarBileSwipeTimer[MAXPLAYERS + 1] = INVALID_HANDLE;
new bileswipe[MAXPLAYERS+1];

// =================================
// Bile Throw
// =================================

//Bools
new bool:isBileThrow = false;

//Handles
new Handle:cvarBileThrow;
new Handle:cvarBileThrowCooldown;
new Handle:cvarBileThrowDamage;
new Handle:cvarBileThrowRange;

// =================================
// Explosive Diarrhea
// =================================

//Bools
new bool:isExplosiveDiarrhea = true;

//Handles
new Handle:cvarExplosiveDiarrhea;
new Handle:cvarExplosiveDiarrheaRange;

// =================================
// Flatulence
// =================================

//Bools
new bool:isFlatulence = true;

//Handles
new Handle:cvarFlatulence;
new Handle:cvarFlatulenceChance;
new Handle:cvarFlatulenceCooldown;
new Handle:cvarFlatulenceDamage;
new Handle:cvarFlatulenceDuration;
new Handle:cvarFlatulencePeriod;
new Handle:cvarFlatulenceRadius;
new Handle:cvarFlatulenceTimer[MAXPLAYERS+1] = INVALID_HANDLE;
new Handle:cvarFlatulenceTimerCloud[MAXPLAYERS+1] = INVALID_HANDLE;


// ===========================================
// Generic Setup
// ===========================================

//Handles
new Handle:PluginStartTimer = INVALID_HANDLE;
static Handle:sdkCallVomitOnPlayer = 	INVALID_HANDLE;
static Handle:sdkCallFling = 	INVALID_HANDLE;

//Floats
new Float:cooldownBileThrow[MAXPLAYERS+1] = 0.0;

//Strings
static laggedMovementOffset = 0;


// ===========================================
// Plugin Info
// ===========================================

public Plugin:myinfo = 
{
    name = "[L4D2] Nauseating Boomer",
    author = "Mortiegama",
    description = "Allows for unique Boomer abilities to spread its nauseating bile.",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?p=2094483#post2094483"
}

	//Special Thanks:
	//AtomicStryker - Boomer Bit** Slap:
	//https://forums.alliedmods.net/showthread.php?t=97952
	
	//Special Thanks:
	//AtomicStryker - Smoker Cloud Damage:
	//https://forums.alliedmods.net/showthread.php?t=97952

// ===========================================
// Plugin Start
// ===========================================

public OnPluginStart()
{
	CreateConVar("l4d_nbm_version", PLUGIN_VERSION, "Nauseating Boomer Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	// ======================================
	// Boomer Ability: Bile Belly
	// ======================================
	cvarBileBelly = CreateConVar("l4d_nbm_bilebelly", "1", "Enables Bile Belly ability: Due to the bulbous bile filled belly, it is hard to cause direct damage to the Boomer. (Def 1)");
	cvarBileBellyAmount = CreateConVar("l4d_nbm_bilebellyamount", "0.5", "Percent of damage the Boomer avoids thanks to it's belly. (Def 0.5)");
	
	// ======================================
	// Boomer Ability: Bile Blast
	// ======================================
	cvarBileBlast = CreateConVar("l4d_nbm_bileblast", "1", "Enables Bile Blast ability: Due to bile and methane building up, when the Boomer dies the pressure releases causing a shockwave to damage and send Survivors flying. (Def 1)");
	cvarBileBlastInnerPower = CreateConVar("l4d_nbm_bileblastinnerpower", "200.0", "Power behind the inner range of Bile Blast. (Def 200.0)");
	cvarBileBlastOuterPower = CreateConVar("l4d_nbm_bileblastouterpower", "100.0", "Power behind the outer range of Bile Blast. (Def 100.0)");
	cvarBileBlastInnerDamage = CreateConVar("l4d_nbm_bileblastinnerdamage", "15", "Amount of damage caused in the inner range of Bile Blast. (Def 15)");
	cvarBileBlastOuterDamage = CreateConVar("l4d_nbm_bileblastouterdamage", "5", "Amount of damage caused in the outer range of Bile Blast. (Def 5)");
	cvarBileBlastInnerRange = CreateConVar("l4d_nbm_bileblastinnerrange", "250.0", "Range the inner blast radius will extend from Bile Blast. (Def 200.0)");
	cvarBileBlastOuterRange = CreateConVar("l4d_nbm_bileblastouterrange", "400.0", "Range the outer blast radius will extend from Bile Blast. (Def 300.0)");
	
	// ======================================
	// Boomer Ability: Bile Feet
	// ======================================
	cvarBileFeet = CreateConVar("l4d_nbm_bilefeet", "1", "Enables Bile Feet ability: A slick coating of bile on its body allows the Boomer to move with increased speed. (Def 1)");
	cvarBileFeetSpeed = CreateConVar("l4d_nbm_bilefeetspeed", "1.5", "How much does Bile Feet increase the Boomer movement speed. (Def 1.5)");
	
	// ======================================
	// Boomer Ability: Bile Mask
	// ======================================
	cvarBileMask = CreateConVar("l4d_nbm_bilemask", "1", "Enables Bile Mask ability: When covered in bile, the Survivors entire view (HUD) is completely covered. (Def 1)");
	cvarBileMaskState = CreateConVar("l4d_nbm_bilemaskstate", "1", "Duration HUD Remains Hidden (0 = Cvar Set Duration, 1 = Until Bile Dries). (Def 1)");
	cvarBileMaskAmount = CreateConVar("l4d_nbm_bilemaskamount", "200", "Amount of visibility covered by the Boomer's bile (0 = None, 255 = Total). (Def 200)");
	cvarBileMaskDuration = CreateConVar("l4d_nbm_bilemaskduration", "-1", "How long is the HUD hidden for after vomit (-1 = Until Dry, 0< is period of time). (Def -1)");

	// ======================================
	// Boomer Ability: Bile Pimple
	// ======================================
	cvarBilePimple = CreateConVar("l4d_nbm_bilepimple", "1", "Enables Bile Pimple ability: At any moment one of the Boomer's Bile filled Pimples could pop and spray any Survivor nearby. (Def 1)");
	cvarBilePimpleChance = CreateConVar("l4d_nbm_bilepimplechance", "5", "Chance that a Survivor will be hit with Bile from an exploding Pimple. (Def 5)(5 = 5%)");
	cvarBilePimpleDamage = CreateConVar("l4d_nbm_bilepimpledamage", "10", "Amount of damage the Bile from an exploding Pimple will cause. (Def 10)");
	cvarBilePimpleRange = CreateConVar("l4d_nbm_bilepimplerange", "500.0", "Distance Bile will reach from an Exploding Pimple. (Def 500.0)");

	// ======================================
	// Boomer Ability: Bile Shower
	// ======================================
	cvarBileShower = CreateConVar("l4d_nbm_bileshower", "1", "Enables Bile Shower ability: When the Boomer vomits on something, it will summon a larger mob of common infected. (Def 1)");
	cvarBileShowerTimeout = CreateConVar("l4d_nbm_bileshowertimeout", "10", "How many seconds must a Boomer wait before summoning another mob. (Def 10)");
	
	// ======================================
	// Boomer Ability: Bile Swipe
	// ======================================	
	cvarBileSwipe = CreateConVar("l4d_nbm_bileswipe", "1", "Enables Bile Swipe ability: Due to the Boomer's sharp bile covered claws, it has a chance of inflicting burning bile wounds to survivors. (Def 1)");
	cvarBileSwipeChance = CreateConVar("l4d_nbm_bileswipechance", "100", "Chance that the Boomer's claws will cause a burning bile wound. (100 = 100%) (Def 100)");
	cvarBileSwipeDuration = CreateConVar("l4d_nbm_bileswipeduration", "10", "For how many seconds does the Bile Swipe last. (Def 10)");
	cvarBileSwipeDamage = CreateConVar("l4d_nbm_bileswipedamage", "1", "How much damage is inflicted by Bile Swipe each second. (Def 1)");

	// ======================================
	// Boomer Ability: Bile Throw
	// ======================================
	cvarBileThrow = CreateConVar("l4d_nbm_bilethrow", "1", "Enables Bile Throw ability: The Boomer spits into its hand and throws globs of vomit at Survivors it can see. (Def 1)");
	cvarBileThrowCooldown = CreateConVar("l4d_nbm_bilethrowcooldown", "8.0", "Period of time before Bile Throw can be used again. (Def 8.0)");
	cvarBileThrowDamage = CreateConVar("l4d_nbm_bilethrowdamage", "10", "Amount of damage the Bile Throw deals to Survivors that are hit. (Def 10)");
	cvarBileThrowRange = CreateConVar("l4d_nbm_bilethrowrange", "700", "Distance the Boomer is able to throw Bile. (Def 700)");

	// ======================================
	// Boomer Ability: Explosive Diarrhea
	// ======================================
	cvarExplosiveDiarrhea = CreateConVar("l4d_nbm_explosivediarrhea", "1", "Enables Explosive Diarrhea ability: The pressure of the bile inside its body cause the Boomer to fire out both ends when vomiting. (Def 1)");
	cvarExplosiveDiarrheaRange = CreateConVar("l4d_nbm_explosivediarrhearange", "100", "Distance the diarrhea can travel behind the Boomer. (Def 100)");
	
	// ======================================
	// Boomer Ability: Flatulence
	// ======================================
	cvarFlatulence = CreateConVar("l4d_nbm_flatulence", "1", "Enables Flatulence ability: Due to excess bile in it's body, the Boomer will on occassion expel a bile gas that causes damage to anyone standing inside the cloud. (Def 1)", FCVAR_PLUGIN);
	cvarFlatulenceChance = CreateConVar("l4d_nbm_flatulencechance", "20", "Chance that those affected by the Flatulence cloud will be biled. (20 = 20%) (Def 20)", FCVAR_PLUGIN);
	cvarFlatulenceCooldown = CreateConVar("l4d_nbm_flatulencecooldown", "60.0", "Period of time between Flatulence farts. (Def 60.0)", FCVAR_PLUGIN);
	cvarFlatulenceDamage = CreateConVar("l4d_nbm_flatulencedamage", "5", "Amount of damage caused to Survivors standing in a Flatulence cloud. (Def 5)", FCVAR_PLUGIN);
	cvarFlatulenceDuration = CreateConVar("l4d_nbm_flatulenceduration", "10.0", "Period of time the Flatulence cloud persists. (Def 10.0)", FCVAR_PLUGIN);
	cvarFlatulencePeriod = CreateConVar("l4d_nbm_flatulenceperiod", "2.0", "Frequency that standing in the Flatulence cloud will cause damage. (Def 2.0)", FCVAR_PLUGIN);
	cvarFlatulenceRadius = CreateConVar("l4d_nbm_flatulenceradius", "100.0", "Radius that the Flatulence cloud will cover. (Def 100.0)", FCVAR_PLUGIN);
	
	// ======================================
	// Hook Events
	// ======================================
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("ability_use", Event_AbilityUse);
	
	AutoExecConfig(true, "plugin.L4D2.NauseatingBoomer");
	PluginStartTimer = CreateTimer(3.0, OnPluginStart_Delayed);
	
	new Handle:ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
	laggedMovementOffset = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");
	
	// ======================================
	// Prep SDK Calls
	// ======================================
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkCallVomitOnPlayer = EndPrepSDKCall();
	
	if (sdkCallVomitOnPlayer == INVALID_HANDLE)
	{
		SetFailState("Cant initialize OnVomitedUpon SDKCall");
		return;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallFling = EndPrepSDKCall();
	
	if (sdkCallFling == INVALID_HANDLE)
	{
		SetFailState("Cant initialize Fling SDKCall");
		return;
	}
	
	CloseHandle(ConfigFile);
}

// ===========================================
// Plugin Start Delayed
// ===========================================

public Action:OnPluginStart_Delayed(Handle:timer)
{	
	if (GetConVarInt(cvarBileBlast))
	{
		isBileBlast = true;
	}
	
	if (GetConVarInt(cvarBileFeet))
	{
		isBileFeet = true;
	}
	
	if (GetConVarInt(cvarBilePimple))
	{
		isBilePimple = true;
	}
	
	if (GetConVarInt(cvarBileBelly))
	{
		isBileBelly = true;
	}
	
	if (GetConVarInt(cvarBileMask))
	{
		isBileMask = true;
	}

	if (GetConVarInt(cvarBileMaskState))
	{
		isBileMaskTilDry = true;
	}

	if (GetConVarInt(cvarBilePimple))
	{
		isBilePimple = true;
	}
	
	if (GetConVarInt(cvarBileShower))
	{
		isBileShower = true;
	}

	if (GetConVarInt(cvarBileSwipe))
	{
		isBileSwipe = true;
	}
	
	if (GetConVarInt(cvarBileThrow))
	{
		isBileThrow = true;
	}
	
	if (GetConVarInt(cvarExplosiveDiarrhea))
	{
		isExplosiveDiarrhea = true;
	}
	
	if (GetConVarInt(cvarFlatulence))
	{
		isFlatulence = true;
	}
	
	if(PluginStartTimer != INVALID_HANDLE)
	{
 		KillTimer(PluginStartTimer);
		PluginStartTimer = INVALID_HANDLE;
	}
		
	return Plugin_Stop;
}

// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================            BOOMER            =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

// ===========================================
// Boomer Setup Events
// ===========================================

public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:Event_PlayerSpawn (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	
	if (IsValidBoomer(client))
	{
		// =================================
		// Boomer Ability: Bile Feet
		// =================================		
		if (isBileFeet)
		{
			BoomerAbility_BileFeet(client);
			
		}

		// =================================
		// Boomer Ability: Bile Pimple
		// =================================
		if (isBilePimple)
		{
			BoomerAbility_BilePimple(client);
			
		}
		
		// =================================
		// Boomer Ability: Flatulence
		// =================================
		if (isFlatulence)
		{
			BoomerAbility_Flatulence(client);
		}
	}
}

public Event_PlayerDeath (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidDeadBoomer(client))
	{
		// =================================
		// Boomer Ability: Bile Blast
		// =================================
		if (isBileBlast)
		{
			BoomerAbility_BileBlast(client);
		}
	}
}

public Action:Event_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	// ====================================
	// Boomer Ability: Explosive Diarrhea
	// ====================================
	if (isExplosiveDiarrhea)
	{
		BoomerAbility_ExplosiveDiarrhea(client);
	}
}

public Event_PlayerNowIt (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// ====================================
	// Boomer Ability: Bile Shower
	// ====================================
	if (isBileShower && !isBileShowerTimeout)
	{
		BoomerAbility_BileShower(client);
	}

	// ====================================
	// Boomer Ability: Explosive Mask
	// ====================================
	if (isBileMask)
	{
		BoomerAbility_BileMask(client);
	}
}

public Event_PlayerNotIt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// ====================================
	// Boomer Ability: Bile Mask
	// ====================================
	if (isBileMask && isBileMaskTilDry)
	{
		BoomerAbility_BileMaskDry(client);
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (IsValidBoomer(attacker) && IsValidClient(victim) && GetClientTeam(victim) == 2)
	{
		// =================================
		// Boomer Ability: Bile Swipe
		// =================================
		decl String:weapon[64];
		GetClientWeapon(attacker, weapon, sizeof(weapon));
		
		if (isBileSwipe && StrEqual(weapon, "weapon_boomer_claw"))
		{
			BoomerAbility_BileSwipe(victim, attacker);
		}
	}

	if (IsValidClient(attacker) && GetClientTeam(attacker) == 2 && IsValidBoomer(victim))
	{
		// =================================
		// Boomer Ability: Bile Belly
		// =================================
		// Description: Due to the bolbous bile filled belly, it is hard to cause direct damage to the Boomer.
		if(isBileBelly)
		{
			new Float:damagemod = GetConVarFloat(cvarBileBellyAmount);
				
			if (FloatCompare(damagemod, 1.0) != 0)
			{
				damage = damage * damagemod;
			}
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	// ====================================
	// Boomer Ability: Bile Throw
	// ====================================
	if(buttons & IN_ATTACK2 && isBileThrow)
	{
		BoomerAbility_BileThrow(client);
	}
}




// ===========================================
// Boomer Ability: Bile Blast
// ===========================================
// Description: Due to bile and methane building up, when the Boomer dies the pressure releases causing a shockwave to damage and send Survivors flying.

public BoomerAbility_BileBlast(client)
{
	for (new victim=1; victim<=MaxClients; victim++)
	{
		if (IsValidClient(victim) && GetClientTeam(victim) != 3  && !IsSurvivorPinned(client))
		{
			decl Float:s_pos[3];
			GetClientEyePosition(client, s_pos);
			decl Float:targetVector[3];
			decl Float:distance;
			new Float:range1 = GetConVarFloat(cvarBileBlastInnerRange);
			new Float:range2 = GetConVarFloat(cvarBileBlastOuterRange);
			GetClientEyePosition(victim, targetVector);
			distance = GetVectorDistance(targetVector, s_pos);
			//PrintToChatAll("Distance: %f.", distance);
			
			if (distance < range1)
			{
				decl Float:HeadingVector[3], Float:AimVector[3];
				new Float:power = GetConVarFloat(cvarBileBlastInnerPower);
				
				GetClientEyeAngles(client, HeadingVector);
				AimVector[0] = FloatMul( Cosine( DegToRad(HeadingVector[1])  ) , power);
				AimVector[1] = FloatMul( Sine( DegToRad(HeadingVector[1])  ) , power);
				
				decl Float:current[3];
				GetEntPropVector(victim, Prop_Data, VELOCITY_ENTPROP, current);
				
				decl Float:resulting[3];
				resulting[0] = FloatAdd(current[0], AimVector[0]);	
				resulting[1] = FloatAdd(current[1], AimVector[1]);
				resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
				
				new damage = GetConVarInt(cvarBileBlastInnerDamage);
				DamageHook(client, victim, damage);

				new Float:incaptime = 3.0;
				SDKCall(sdkCallFling, victim, resulting, 76, client, incaptime); //76 is the 'got bounced' animation in L4D2
			}
				
			if (distance < range2 && distance > range1)
			{
				decl Float:HeadingVector[3], Float:AimVector[3];
				new Float:power = GetConVarFloat(cvarBileBlastOuterPower);
				
				GetClientEyeAngles(client, HeadingVector);
				AimVector[0] = FloatMul( Cosine( DegToRad(HeadingVector[1])  ) , power);
				AimVector[1] = FloatMul( Sine( DegToRad(HeadingVector[1])  ) , power);
				
				decl Float:current[3];
				GetEntPropVector(victim, Prop_Data, VELOCITY_ENTPROP, current);
				
				decl Float:resulting[3];
				resulting[0] = FloatAdd(current[0], AimVector[0]);	
				resulting[1] = FloatAdd(current[1], AimVector[1]);
				resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
				
				new damage = GetConVarInt(cvarBileBlastOuterDamage);
				DamageHook(client, victim, damage);
				
				new Float:incaptime = 3.0;
				SDKCall(sdkCallFling, victim, resulting, 76, client, incaptime); //76 is the 'got bounced' animation in L4D2
			}
		}
	}
}




// ===========================================
// Boomer Ability: Bile Feet
// ===========================================
// Description: A slick coating of bile on its body allows the Boomer to move with increased speed.

public Action:BoomerAbility_BileFeet(client)
{
	cvarBileFeetTimer[client] = CreateTimer(0.5, Timer_BoomerBileFeet, client);
}

public Action:Timer_BoomerBileFeet(Handle:timer, any:client) 
{
	if (IsValidClient(client))
	{
		PrintHintText(client, "Bile Feet has granted you increased movement speed!");
		SetEntDataFloat(client, laggedMovementOffset, 1.0*GetConVarFloat(cvarBileFeetSpeed), true);
		SetConVarFloat(FindConVar("z_vomit_fatigue"),0.0,false,false);
	}
	
	if(cvarBileFeetTimer[client] != INVALID_HANDLE)
	{
 		KillTimer(cvarBileFeetTimer[client]);
		cvarBileFeetTimer[client] = INVALID_HANDLE;
	}
		
	return Plugin_Stop;	
}




// ===========================================
// Boomer Ability: Bile Mask
// ===========================================
// Description: When covered in bile, the Survivors entire view (HUD) is completely covered. 

public BoomerAbility_BileMask(client)
{
	if (IsValidClient(client))
	{
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetConVarInt(cvarBileMaskAmount));
	
		if (!isBileMaskTilDry)
		{
			cvarBileMaskTimer[client] = CreateTimer(GetConVarFloat(cvarBileMaskDuration), Timer_BileMask, client);
		}
	}
}

public Action:Timer_BileMask(Handle:timer, any:client) 
{
	BoomerAbility_BileMaskDry(client);

	if(cvarBileMaskTimer[client] != INVALID_HANDLE)
	{
		KillTimer(cvarBileMaskTimer[client]);
		cvarBileMaskTimer[client] = INVALID_HANDLE;
	}	
	
	return Plugin_Stop;	
}

public BoomerAbility_BileMaskDry(client)
{
	if (IsValidClient(client))
	{	
		SetEntProp(client, Prop_Send, "m_iHideHUD", 0);
	}
}




// ===========================================
// Boomer Ability: Bile Pimple
// ===========================================
// Description: At any moment one of the Boomer's Bile filled Pimples could pop and spray any Survivor nearby.

public Action:BoomerAbility_BilePimple(client)
{
	cvarBilePimpleTimer[client] = CreateTimer(0.5, Timer_BilePimple, client, TIMER_REPEAT);
}

public Action:Timer_BilePimple(Handle:timer, any:client)
{
	if (!IsValidBoomer(client) || GetClientTeam(client) != 3)
	{
		if (cvarBilePimpleTimer[client] != INVALID_HANDLE)
		{
			KillTimer(cvarBilePimpleTimer[client]);
			cvarBilePimpleTimer[client] = INVALID_HANDLE;
		}	
	
		return Plugin_Stop;
	}

	for (new victim=1; victim<=MaxClients; victim++)
	
	if (IsValidClient(victim) && GetClientTeam(victim) == 2)
	{
		new BilePimpleChance = GetRandomInt(0, 99);
		new BilePimplePercent = (GetConVarInt(cvarBilePimpleChance));
		
		if (BilePimpleChance < BilePimplePercent)
		{
			decl Float:v_pos[3];
			GetClientEyePosition(victim, v_pos);		
			decl Float:targetVector[3];
			decl Float:distance;
			new Float:range = GetConVarFloat(cvarBilePimpleRange);
			GetClientEyePosition(client, targetVector);
			distance = GetVectorDistance(targetVector, v_pos);
			//PrintToChatAll("Distance: %f Client: %n", distance, victim);
			
			if (distance <= range)
			{
				new damage = GetConVarInt(cvarBilePimpleDamage);
				DamageHook(client, victim, damage);
			}
		}
	}
	
	return Plugin_Continue;
}




// ===========================================
// Boomer Ability: Bile Shower
// ===========================================
// Description: When the Boomer vomits on something, it has a chance to summon a larger mob of common infected.

public BoomerAbility_BileShower(client)
{
	if (IsValidBoomer(client) && !isBileShowerTimeout)
	{
		isBileShowerTimeout = true;
		cvarBileShowerTimer[client] = CreateTimer(GetConVarFloat(cvarBileShowerTimeout), Timer_BileShower, client);
		new flags = GetCommandFlags("z_spawn_old");
		SetCommandFlags("z_spawn_old", flags & ~FCVAR_CHEAT);
		FakeClientCommand(client,"z_spawn_old mob auto");
		SetCommandFlags("z_spawn_old", flags|FCVAR_CHEAT);
	}
}

public Action:Timer_BileShower(Handle:timer, any:client)
{
	isBileShowerTimeout = false;
	
	if(cvarBileShowerTimer[client] != INVALID_HANDLE)
	{
		KillTimer(cvarBileShowerTimer[client]);
		cvarBileShowerTimer[client] = INVALID_HANDLE;
	}	

	return Plugin_Stop;	
}




// ===========================================
// Boomer Ability: Bile Swipe
// ===========================================
// Description: Due to the Boomer's sharp bile covered claws, it has a chance of inflicting burning bile wounds to survivors.

public BoomerAbility_BileSwipe(victim, attacker)
{
	new BileSwipeChance = GetRandomInt(0, 99);
	new BileSwipePercent = (GetConVarInt(cvarBileSwipeChance));

	if (IsValidClient(victim) && GetClientTeam(victim) == 2 && BileSwipeChance < BileSwipePercent)
	{
		PrintHintText(victim, "The Boomer has coated you with stomach bile acid!");
		
		if(bileswipe[victim] <= 0)
		{
			bileswipe[victim] = (GetConVarInt(cvarBileSwipeDuration));
			
			new Handle:dataPack = CreateDataPack();
			cvarBileSwipeTimer[victim] = CreateDataTimer(1.0, Timer_BileSwipe, dataPack, TIMER_REPEAT);
			WritePackCell(dataPack, victim);
			WritePackCell(dataPack, attacker);
		}
	}
}

public Action:Timer_BileSwipe(Handle:timer, any:dataPack) 
{
	ResetPack(dataPack);
	new victim = ReadPackCell(dataPack);
	new attacker = ReadPackCell(dataPack);

	if (IsValidClient(victim))
	{
		if(bileswipe[victim] <= 0)
		{
			if (cvarBileSwipeTimer[victim] != INVALID_HANDLE)
			{
				KillTimer(cvarBileSwipeTimer[victim]);
				cvarBileSwipeTimer[victim] = INVALID_HANDLE;
			}
			
			return Plugin_Stop;
		}

		new damage = GetConVarInt(cvarBileSwipeDamage);
		DamageHook(victim, attacker, damage);	
		
		if(bileswipe[victim] > 0) 
		{
			bileswipe[victim] -= 1;
		}
	}
			
	return Plugin_Continue;
}




// ===========================================
// Boomer Ability: Bile Throw
// ===========================================
// Description: The Boomer spits into its hand and throws globs of vomit at Survivors it can see.

public Action:BoomerAbility_BileThrow(client)
{
	if (IsValidBoomer(client) && !IsPlayerGhost(client) && IsBileThrowReady(client))
	{
		new Float:range = GetConVarFloat(cvarBileThrowRange);
		for (new victim=1; victim<=MaxClients; victim++)
		
		if (IsValidClient(victim) && GetClientTeam(victim) == 2 && ClientViews(client, victim, range))
		{
			decl Float:attackerPos[3];
			decl Float:victimPos[3];
			GetClientEyePosition(client, attackerPos);
			GetClientEyePosition(victim, victimPos);
			ShowParticle(attackerPos, "boomer_vomit", 3.0);	
			ShowParticle(victimPos, "boomer_explode", 3.0);	
			SDKCall(sdkCallVomitOnPlayer, victim, client, true);
			cooldownBileThrow[client] = GetEngineTime();
			new damage = GetConVarInt(cvarBileThrowDamage);
			DamageHook(victim, client, damage);			
		}
	}
}
		
		
		

// ===========================================
// Boomer Ability: Explosive Diarrhea
// ===========================================
// Description: The pressure of the bile inside its body cause the Boomer to fire out both ends when vomiting.

public Action:BoomerAbility_ExplosiveDiarrhea(client)
{
	if (IsValidBoomer(client))
	{
		new Float:range = GetConVarFloat(cvarExplosiveDiarrheaRange);
		for (new victim=1; victim<=MaxClients; victim++)
			
		if (IsValidClient(victim) && GetClientTeam(victim) == 2 && ClientViewsReverse(client, victim, range))
		{
			decl Float:attackerPos[3];
			decl Float:victimPos[3];
			GetClientEyePosition(client, attackerPos);
			GetClientEyePosition(victim, victimPos);
			ShowParticle(attackerPos, "boomer_vomit", 3.0);	
			ShowParticle(victimPos, "boomer_explode", 3.0);	
			SDKCall(sdkCallVomitOnPlayer, victim, client, true);
		}
	}
}
	
	
	
	
// ===========================================
// Boomer Ability: Flatulence
// ===========================================
// Description: Due to excess bile in it's body, the Boomer will on occassion expel a bile gas that causes damage to anyone standing inside the cloud.

public Action:BoomerAbility_Flatulence(client)
{
	Prepare_Flatulence(client);
	new Float:time = GetConVarFloat(cvarFlatulenceCooldown);
	cvarFlatulenceTimer[client] = CreateTimer(time, Timer_Flatulence, client, TIMER_REPEAT);
}

public Action:Timer_Flatulence(Handle:timer, any:client)
{
	if (!IsValidBoomer(client) || IsPlayerGhost(client))
	{
		if (cvarFlatulenceTimer[client] != INVALID_HANDLE)
		{
			KillTimer(cvarFlatulenceTimer[client]);
			cvarFlatulenceTimer[client] = INVALID_HANDLE;
		}	
	
		return Plugin_Stop;
	}
	
	Prepare_Flatulence(client);
	
	return Plugin_Continue;
}
	
public Action:Prepare_Flatulence(client)
{	
	decl Float:vecPos[3];
	GetClientAbsOrigin(client, vecPos);
	
	new Float:targettime = GetEngineTime() + GetConVarFloat(cvarFlatulenceDuration);
	ShowParticle(vecPos, "smoker_smokecloud", targettime);

	new Handle:dataPack = CreateDataPack();
	WritePackCell(dataPack, client);
	WritePackFloat(dataPack, vecPos[0]);
	WritePackFloat(dataPack, vecPos[1]);
	WritePackFloat(dataPack, vecPos[2]);
	WritePackFloat(dataPack, targettime);
	
	new Float:time = GetConVarFloat(cvarFlatulencePeriod);
	cvarFlatulenceTimerCloud[client] = CreateTimer(time, Timer_FlatulenceCloud, dataPack, TIMER_REPEAT);
}

public Action:Timer_FlatulenceCloud(Handle:timer, Handle:dataPack)
{
	ResetPack(dataPack);
	new client = ReadPackCell(dataPack);
	decl Float:vecPos[3];
	vecPos[0] = ReadPackFloat(dataPack);
	vecPos[1] = ReadPackFloat(dataPack);
	vecPos[2] = ReadPackFloat(dataPack);
	new Float:targettime = ReadPackFloat(dataPack);
	
	if (targettime - GetEngineTime() < 0 )
	{
		KillTimer(cvarFlatulenceTimerCloud[client]);
		cvarFlatulenceTimerCloud[client] = INVALID_HANDLE;
	
		return Plugin_Stop;
	}

	decl Float:targetVector[3];
	decl Float:distance;
	new Float:radiussetting = GetConVarFloat(cvarFlatulenceRadius);
	
	for (new victim=1; victim<=MaxClients; victim++)
	{
		if (IsValidClient(victim) && GetClientTeam(victim) == 2)
		{
			GetClientEyePosition(victim, targetVector);
			distance = GetVectorDistance(targetVector, vecPos);
			
			if (distance > radiussetting
			|| !IsVisibleTo(vecPos, targetVector)) continue;

			PrintHintText(victim, "You're suffering from a Boomer's fart cloud!");
			
			new damage = GetConVarInt(cvarFlatulenceDamage);
			DamageHook(victim, client, damage);
			
			new FlatulenceChance = GetRandomInt(0, 99);
			new FlatulencePercent = (GetConVarInt(cvarFlatulenceChance));

			if (FlatulenceChance < FlatulencePercent)
			{
				SDKCall(sdkCallVomitOnPlayer, victim, client, true);
			}

		}
	}

	return Plugin_Continue;
}





// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================        GENERIC CALLS         =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

public Action:DamageHook(victim, attacker, damage)
{
	decl Float:victimPos[3], String:strDamage[16], String:strDamageTarget[16];
			
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	
	new entPointHurt = CreateEntityByName("point_hurt");
	if(!entPointHurt) return;

	// Config, create point_hurt
	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
	DispatchSpawn(entPointHurt);
	
	// Teleport, activate point_hurt
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (attacker && attacker < MaxClients && IsClientInGame(attacker)) ? attacker : -1);
	
	// Config, delete point_hurt
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	RemoveEdict(entPointHurt);
}

public Action:FlingHook(victim, attacker, Float:power)
{
	decl Float:HeadingVector[3], Float:AimVector[3];
	
	GetClientEyeAngles(attacker, HeadingVector);
		
	AimVector[0] = FloatMul( Cosine( DegToRad(HeadingVector[1])  ) , power);
	AimVector[1] = FloatMul( Sine( DegToRad(HeadingVector[1])  ) , power);
			
	decl Float:current[3];
	GetEntPropVector(victim, Prop_Data, VELOCITY_ENTPROP, current);
			
	decl Float:resulting[3];
	resulting[0] = FloatAdd(current[0], AimVector[0]);	
	resulting[1] = FloatAdd(current[1], AimVector[1]);
	resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
	
	new Float:incaptime = 3.0;
	//L4D2_Fling(victim, resulting, attacker);
	SDKCall(sdkCallFling, victim, resulting, 76, attacker, incaptime); //76 is the 'got bounced' animation in L4D2
}

// ----------------------------------------------------------------------------
// ClientViews()
// ----------------------------------------------------------------------------
stock bool:ClientViews(Viewer, Target, Float:fMaxDistance=0.0, Float:fThreshold=0.73)
{
	// Retrieve view and target eyes position
	decl Float:fViewPos[3];   GetClientEyePosition(Viewer, fViewPos);
	decl Float:fViewAng[3];   GetClientEyeAngles(Viewer, fViewAng);
	decl Float:fViewDir[3];
	decl Float:fTargetPos[3]; GetClientEyePosition(Target, fTargetPos);
	decl Float:fTargetDir[3];
	decl Float:fDistance[3];

	// Calculate view direction
	fViewAng[0] = fViewAng[2] = 0.0;
	GetAngleVectors(fViewAng, fViewDir, NULL_VECTOR, NULL_VECTOR);

	// Calculate distance to viewer to see if it can be seen.
	fDistance[0] = fTargetPos[0]-fViewPos[0];
	fDistance[1] = fTargetPos[1]-fViewPos[1];
	fDistance[2] = 0.0;
	new Float:fMinDistance = 100.0;
	
	if (fMaxDistance != 0.0)
	{
		if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) >= (fMaxDistance*fMaxDistance))
			return false;
	}
	
	if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) < (fMinDistance*fMinDistance))
			return false;

	// Check dot product. If it's negative, that means the viewer is facing
	// backwards to the target.
	NormalizeVector(fDistance, fTargetDir);
	if (GetVectorDotProduct(fViewDir, fTargetDir) < fThreshold) return false;

	// Now check if there are no obstacles in between through raycasting
	new Handle:hTrace = TR_TraceRayFilterEx(fViewPos, fTargetPos, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, ClientViewsFilter);
	if (TR_DidHit(hTrace)) { CloseHandle(hTrace); return false; }
	CloseHandle(hTrace);

	// Done, it's visible
	return true;
}

stock bool:ClientViewsReverse(Viewer, Target, Float:fMaxDistance=0.0, Float:fThreshold=0.73)
{
	// Retrieve view and target eyes position
	decl Float:fViewPos[3];   GetClientEyePosition(Viewer, fViewPos);
	decl Float:fViewAng[3];   GetClientEyeAngles(Viewer, fViewAng);
	decl Float:fViewDir[3];
	decl Float:fTargetPos[3]; GetClientEyePosition(Target, fTargetPos);
	decl Float:fTargetDir[3];
	decl Float:fDistance[3];

	// Calculate view direction
	fViewAng[0] = fViewAng[2] = 0.0;
	GetAngleVectors(fViewAng, fViewDir, NULL_VECTOR, NULL_VECTOR);

	// Calculate distance to viewer to see if it can be seen.
	fDistance[0] = fTargetPos[0]-fViewPos[0];
	fDistance[1] = fTargetPos[1]-fViewPos[1];
	fDistance[2] = 0.0;
	new Float:fMinDistance = 100.0;
	
	if (fMaxDistance != 0.0)
	{
		if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) >= (fMaxDistance*fMaxDistance))
			return false;
	}
	
	if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) < (fMinDistance*fMinDistance))
			return false;

	// Check dot product. If it's negative (> fThreshold), that means the viewer is facing
	// backwards to the target.
	NormalizeVector(fDistance, fTargetDir);
	if (GetVectorDotProduct(fViewDir, fTargetDir) > fThreshold) return false;

	// Now check if there are no obstacles in between through raycasting
	new Handle:hTrace = TR_TraceRayFilterEx(fViewPos, fTargetPos, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, ClientViewsFilter);
	if (TR_DidHit(hTrace)) { CloseHandle(hTrace); return false; }
	CloseHandle(hTrace);

	// Done, it's visible
	return true;
}

// ----------------------------------------------------------------------------
// ClientViewsFilter()
// ----------------------------------------------------------------------------
public bool:ClientViewsFilter(Entity, Mask, any:Junk)
{
	if (Entity >= 1 && Entity <= MaxClients) return false;
	return true;
} 

public ShowParticle(Float:victimPos[3], String:particlename[], Float:time)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, victimPos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
	} 
}
 
public PrecacheParticle(String:particlename[])
{
	new particle = CreateEntityByName("info_particle_system");
	
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:DeleteParticles(Handle:timer, any:particle)
{
	if (IsValidEntity(particle))
	{
		decl String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "kill");
			RemoveEdict(particle);
		}
	}
}

static bool:IsVisibleTo(Float:position[3], Float:targetposition[3])
{
	decl Float:vAngles[3], Float:vLookAt[3];
	
	MakeVectorFromPoints(position, targetposition, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace
	
	// execute Trace
	new Handle:trace = TR_TraceRayFilterEx(position, vAngles, MASK_SHOT, RayType_Infinite, _TraceFilter);
	
	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		decl Float:vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint
		
		if ((GetVectorDistance(position, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true; // if trace ray lenght plus tolerance equal or bigger absolute distance, you hit the target
		}
	}
	else
	{
		LogError("Tracer Bug: Player-Zombie Trace did not hit anything, WTF");
		isVisible = true;
	}
	CloseHandle(trace);
	
	return isVisible;
}

public bool:_TraceFilter(entity, contentsMask)
{
	if (!entity || !IsValidEntity(entity)) // dont let WORLD, or invalid entities be hit
	{
		return false;
	}
	
	return true;
}




// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================          BOOL CALLS          =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

public IsValidClient(client)
{
	if (client <= 0)
		return false;
		
	if (client > MaxClients)
		return false;
		
	if (!IsClientInGame(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	return true;
}

public IsValidDeadClient(client)
{
	if (client <= 0)
		return false;
		
	if (client > MaxClients)
		return false;
		
	if (!IsClientInGame(client))
		return false;
		
	if (IsPlayerAlive(client))
		return false;

	return true;
}

public IsValidBoomer(client)
{
	if (IsValidClient(client))
	{
		new class = GetEntProp(client, Prop_Send, "m_zombieClass");
		
		if (class == ZOMBIECLASS_BOOMER)
			return true;
	}
	
	return false;
}

public IsValidDeadBoomer(client)
{
	if (IsValidDeadClient(client))
	{
		new class = GetEntProp(client, Prop_Send, "m_zombieClass");
		
		if (class == ZOMBIECLASS_BOOMER)
			return true;
	}
	
	return false;
}

public IsPlayerOnFire(client)
{
	if (IsValidClient(client))
	{
		if (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONFIRE) return true;
		else return false;
	}
	else return false;
}

public IsPlayerGhost(client)
{
	if (IsValidClient(client))
	{
		if (GetEntProp(client, Prop_Send, "m_isGhost")) return true;
		else return false;
	}
	else return false;
}

public IsSurvivorPinned(client)
{
	new attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	if (attacker > 0 && attacker != client)
		return true;
		
	attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
	if (attacker > 0 && attacker != client)
		return true;
		
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (attacker > 0 && attacker != client)
		return true;
		
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0 && attacker != client)
		return true;
		
	attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if (attacker > 0 && attacker != client)
		return true;
		
	return false;
}

public IsBileThrowReady(client)
{
	return ((GetEngineTime() - cooldownBileThrow[client]) > GetConVarFloat(cvarBileThrowCooldown));
}