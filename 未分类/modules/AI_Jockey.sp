#pragma semicolon 1

enum Angle_Vector {
	Pitch = 0,
	Yaw,
	Roll
};

new Handle:hCvarJockeyLeapRange; // vanilla cvar

//new Handle:hCvarHopActivationProximity; // custom cvar

// Leaps
new bool:bCanLeap[MAXPLAYERS];
//new bool:bDoNormalJump[MAXPLAYERS]; // used to alternate pounces and normal jumps
 // shoved jockeys will stop hopping

new Handle:hCvarJockeyStumbleRadius; // stumble radius of jockey ride

// Bibliography: "hunter pounce push" by "Pan XiaoHai & Marcus101RR & AtomicStryker"

public Jockey_OnModuleStart() {
	// CONSOLE VARIABLES
	// jockeys will move to attack survivors within this range
	hCvarJockeyLeapRange = FindConVar("z_jockey_leap_range");
	SetConVarInt(hCvarJockeyLeapRange, 1000); 
	
	// proximity when plugin will start forcing jockeys to hop
	//hCvarHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "500", "How close a jockey will approach before it starts hopping");
	
	// Jockey stumble
	HookEvent("jockey_ride", OnJockeyRide, EventHookMode_Pre); 
	hCvarJockeyStumbleRadius = CreateConVar("ai_jockey_stumble_radius", "50", "Stumble radius of a jockey landing a ride");
}

public Jockey_OnModuleEnd() {
	ResetConVar(hCvarJockeyLeapRange);
}

/***********************************************************************************************************************************************************************************

																	HOPS: ALTERNATING LEAP AND JUMP

***********************************************************************************************************************************************************************************/

public Action:Jockey_OnPlayerRunCmd(jockey, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, bool:hasBeenShoved) 
{
	new flags = GetEntityFlags(jockey);
		// Get the player velocity:
		new Float:fVelocity[3];
		GetEntPropVector(jockey, Prop_Data, "m_vecVelocity", fVelocity);
		new Float:currentspeed = SquareRoot(Pow(fVelocity[0],2.0)+Pow(fVelocity[1],2.0));
		//PrintCenterTextAll("jockey Speed: %.1f", currentspeed);
		
		// Get Angle of jockey
		decl Float:clientEyeAngles[3];
		GetClientEyeAngles(jockey,clientEyeAngles);
		
		// LOS and survivor proximity
		new Float:jockeyPos[3];
		GetClientAbsOrigin(jockey, jockeyPos);
		new iSurvivorsProximity = GetSurvivorProximity(jockeyPos);
		new bool:bHasSight = bool:GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats"); //Line of sight to survivors
		// Near survivors
		if( bHasSight && (600 > iSurvivorsProximity > 250) && currentspeed > 200.0 ) 
		{ 
			
			if (flags & FL_ONGROUND) 
			{
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				
				if(buttons & IN_FORWARD) 
				{
					Client_Push( jockey, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}	
				
				if(buttons & IN_BACK) {
					//clientEyeAngles[1] += 180.0;
					Client_Push( jockey, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
						
				if(buttons & IN_MOVELEFT) {
					//clientEyeAngles[1] += 90.0;
					Client_Push( jockey, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
						
				if(buttons & IN_MOVERIGHT) {
					//clientEyeAngles[1] += -90.0;
					Client_Push( jockey, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
				
			}
			
			//Block Jumping and Crouching when on ladder
			if (GetEntityMoveType(jockey) & MOVETYPE_LADDER)
			{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}

	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																	DEACTIVATING HOP DURING SHOVES

***********************************************************************************************************************************************************************************/

// Enable hopping on spawned jockeys
public Action:Jockey_OnSpawn(botJockey) {
	bCanLeap[botJockey] = true;
	return Plugin_Handled;
}

// Disable hopping when shoved
public Jockey_OnShoved(botJockey) {
	bCanLeap[botJockey] = false;
	new leapCooldown = GetConVarInt(FindConVar("z_jockey_leap_again_timer"));
	CreateTimer( float(leapCooldown), Timer_LeapCooldown, any:botJockey, TIMER_FLAG_NO_MAPCHANGE) ;
}

public Action:Timer_LeapCooldown(Handle:timer, any:jockey) {
	bCanLeap[jockey] = true;
}

/***********************************************************************************************************************************************************************************

																		JOCKEY STUMBLE

***********************************************************************************************************************************************************************************/

public OnJockeyRide(Handle:event, const String:name[], bool:dontBroadcast) {	
	if (IsCoop()) {
		new attacker = GetClientOfUserId(GetEventInt(event, "userid"));  
		new victim = GetClientOfUserId(GetEventInt(event, "victim"));  
		if(attacker > 0 && victim > 0) {
			StumbleBystanders(victim, attacker);
		} 
	}	
}

bool:IsCoop() {
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	return (!StrEqual(GameName, "versus", false) && !StrEqual(GameName, "scavenge", false));
}

StumbleBystanders( pinnedSurvivor, pinner ) {
	decl Float:pinnedSurvivorPos[3];
	decl Float:pos[3];
	decl Float:dir[3];
	GetClientAbsOrigin(pinnedSurvivor, pinnedSurvivorPos);
	new radius = GetConVarInt(hCvarJockeyStumbleRadius);
	for( new i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i) ) {
			if( i != pinnedSurvivor && i != pinner && !IsPinned(i) ) {
				GetClientAbsOrigin(i, pos);
				SubtractVectors(pos, pinnedSurvivorPos, dir);
				if( GetVectorLength(dir) <= float(radius) ) {
					NormalizeVector( dir, dir ); 
					L4D_StaggerPlayer( i, pinnedSurvivor, dir );
				}
			}
		} 
	}
}

stock Float:modulus(Float:a, Float:b) {
	while(a > b)
		a -= b;
	return a;
}