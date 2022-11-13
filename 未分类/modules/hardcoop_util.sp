// Thanks to L4D2Util for many stock functions and enumerations

#pragma semicolon 1
#include <sourcemod>

#if defined HARDCOOP_UTIL_included
#endinput
#endif

#define HARDCOOP_UTIL_included

#define DEBUG_FLOW 0

#define TEAM_CLASS(%1) (%1 == ZC_SMOKER ? "smoker" : (%1 == ZC_BOOMER ? "boomer" : (%1 == ZC_HUNTER ? "hunter" :(%1 == ZC_SPITTER ? "spitter" : (%1 == ZC_JOCKEY ? "jockey" : (%1 == ZC_CHARGER ? "charger" : (%1 == ZC_WITCH ? "witch" : (%1 == ZC_TANK ? "tank" : "None"))))))))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define X_COORD 0
#define Y_COORD 1
#define Z_COORD 2

enum L4D2_Team {
    L4D2Team_Spectator = 1,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

enum L4D2_Infected {
    L4D2Infected_Smoker = 1,
    L4D2Infected_Boomer,
    L4D2Infected_Hunter,
    L4D2Infected_Spitter,
    L4D2Infected_Jockey,
    L4D2Infected_Charger,
    L4D2Infected_Witch,
    L4D2Infected_Tank
};

// alternative enumeration
// Special infected classes
enum ZombieClass {
    ZC_NONE = 0, 
    ZC_SMOKER, 
    ZC_BOOMER, 
    ZC_HUNTER, 
    ZC_SPITTER, 
    ZC_JOCKEY, 
    ZC_CHARGER, 
    ZC_WITCH, 
    ZC_TANK, 
    ZC_NOTINFECTED
};

// 0=Anywhere, 1=Behind, 2=IT, 3=Specials in front, 4=Specials anywhere, 5=Far Away, 6=Above
enum SpawnDirection {
    ANYWHERE = 0,
    BEHIND,
    IT,
    SPECIALS_IN_FRONT,
    SPECIALS_ANYWHERE,
    FAR_AWAY,
    ABOVE   
};

/***********************************************************************************************************************************************************************************

                                                                  		SURVIVORS
                                                                    
***********************************************************************************************************************************************************************************/

/**
 * Returns true if the player is currently on the survivor team. 
 *
 * @param client: client ID
 * @return bool
 */
stock bool:IsSurvivor(client) {
	if( IsValidClient(client) && L4D2_Team:GetClientTeam(client) == L4D2Team_Survivor ) {
		return true;
	} else {
		return false;
	}
}

stock bool:IsPinned(client) {
	new bool:bIsPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}


stock bool:IsPinningASurvivor(client) {
	new bool:isPinning = false;
	if( IsBotInfected(client) && IsPlayerAlive(client) ) {
		if( GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0 ) isPinning = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0 ) isPinning = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0 ) isPinning = true; // charger carrying
		if( GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 ) isPinning = true; // charger pounding
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0 ) isPinning = true; // jockey
	}
	return isPinning;
}

/**
 * @return: The highest %map completion held by a survivor at the current point in time
 */
stock GetMaxSurvivorCompletion() {
	new  flow;
	decl tmp_flow;
	decl Float:origin[3];
	for ( new client = 1; client <= MaxClients; client++ ) {
		if ( IsSurvivor(client) && IsPlayerAlive(client) ) {
			GetClientAbsOrigin(client, origin);
			tmp_flow = GetFlow(origin);
			flow = MAX(flow, tmp_flow);
		}
	}
	
	new current = RoundToNearest(flow * 100 / L4D2Direct_GetMapMaxFlowDistance());
		
		#if DEBUG_FLOW
			CPrintToChatAll( true, "Current: {blue}%d%%", current );
		#endif
		
	return current;
}

/**
 * @return: the farthest flow distance currently held by a survivor
 */
stock Float:GetFarthestSurvivorFlow() {
	new Float:farthest_flow = 0.0;
	decl Float:origin[3];
	for (new client = 1; client <= MaxClients; client++) {
        if ( IsSurvivor(client) && IsPlayerAlive(client) ) {
            GetClientAbsOrigin(client, origin);
            new Float:flow = GetFlow(origin);
            if ( flow > farthest_flow ) {
            	farthest_flow = flow;
            }
        }
    }
	return farthestFlow;
}

/**
 * @return: the farthest flow distance currently held by a survivor
 */
int GetRearSurvivorFlow() 
{
	int lowestMapFlow = -1; // initialise to impossible value
	for ( int thisClient = 1; thisClient <= MAXPLAYERS; ++thisClient )
	{
		if ( IsSurvivor(thisClient) && IsPlayerAlive(thisClient) )
		{
			new Float:thisSurvivorsOrigin[3];
			char survivorName[32];
			GetClientName(thisClient, survivorName, sizeof(survivorName));
			if ( GetClientAbsOrigin(thisClient, thisSurvivorsOrigin) )
			{
				int thisFlow = GetFlow(thisSurvivorsOrigin);
				if ( thisFlow <= 0 )
				{
					PrintToServer("GetRearSurvivorFlow(): Survivor %s returning invalid flow %f", survivorName, thisFlow);
					continue;
				}
				if ( lowestMapFlow == -1 || thisFlow < lowestMapFlow )
				{
					lowestMapFlow = thisFlow;
				}
			}
			else
			{
				PrintToServer("GetRearSurvivorFlow(): Failed to find position for %s", survivorName);
			}
		}
	}
	return lowestMapFlow;
}

/**
 * Returns the average flow distance covered by each survivor
 */
stock Float:GetAverageSurvivorFlow() {
    new survivor_count = 0;
    new Float:total_flow = 0.0;
    decl Float:origin[3];
    for (new client = 1; client <= MaxClients; client++) {
        if ( IsSurvivor(client) && IsPlayerAlive(client) ) {
            survivor_count++;
            GetClientAbsOrigin(client, origin);
            new Float:client_flow = GetFlow(origin);
            if ( GetFlow(origin) != -1.0 ) {
            	total_flow++;
            }
        }
    }
    return FloatDiv(totalFlow, float(survivor_count));
}

/**
 * Returns the flow distance from given point to closest alive survivor. 
 * Returns -1.0 if either the given point or the survivors as a whole are not upon a valid nav mesh
 */
stock GetFlowDistToSurvivors(const Float:pos[3]) {
	new spawnpoint_flow;
	new lowest_flow_dist = -1;
	
	spawnpoint_flow = GetFlow(pos);
	if ( spawnpoint_flow == -1) {
		return -1;
	}
	
	for ( new j = 0; j < MaxClients; j++ ) {
		if ( IsSurvivor(j) && IsPlayerAlive(j) ) {
			new Float:origin[3];
			new flow_dist;
			
			GetClientAbsOrigin(j, origin);
			flow_dist = GetFlow(origin);
			
			// have we found a new valid(i.e. != -1) lowest flow_dist
			if ( flow_dist != -1 && FloatCompare(FloatAbs(float(flow_dist) - float(spawnpoint_flow)), float(lowest_flow_dist)) ==  -1 ) {
				lowest_flow_dist = flow_dist;
			}
		}
	}
	
	return lowest_flow_dist;
}

/**
 * Returns the flow distance of a given point
 */
 stock GetFlow(const Float:o[3]) {
 	new Float:origin[3]; //non constant var
 	origin[0] = o[0];
 	origin[1] = o[1];
 	origin[2] = o[2];
 	decl Address:pNavArea;
 	pNavArea = L4D2Direct_GetTerrorNavArea(origin);
 	if ( pNavArea != Address_Null ) {
 		return RoundToNearest(L4D2Direct_GetTerrorNavAreaFlow(pNavArea));
 	} else {
 		return -1;
 	}
 }
 
/**
 * Returns true if the player is incapacitated. 
 *
 * @param client client ID
 * @return bool
 */
stock bool:IsIncapacitated(client) {
    return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

/**
 * Finds the closest survivor excluding a given survivor 
 * @param referenceClient: compares survivor distances to this client
 * @param excludeSurvivor: ignores this survivor
 * @return: the entity index of the closest survivor
**/
stock GetClosestSurvivor( Float:referencePos[3], excludeSurvivor = -1 ) {
	new Float:survivorPos[3];
	new closestSurvivor = GetRandomSurvivor();	
	if ( !IsValidClient(closestSurvivor) ) 
	{
		LogError("GetClosestSurvivor([%f, %f, %f], %d) = invalid client %d", referencePos[0], referencePos[1], referencePos[2], excludeSurvivor, closestSurvivor);
		return -1;
	}
	GetClientAbsOrigin( closestSurvivor, survivorPos );
	new iClosestAbsDisplacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );
	for (new client = 1; client <= MAXPLAYERS; client++) {
		if( IsSurvivor(client) && IsPlayerAlive(client) && client != excludeSurvivor ) {
			GetClientAbsOrigin( client, survivorPos );
			new displacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );			
			if( displacement < iClosestAbsDisplacement || iClosestAbsDisplacement < 0 ) { 
				iClosestAbsDisplacement = displacement;
				closestSurvivor = client;
			}
		}
	}
	return closestSurvivor;
}

/**
 * Returns the distance of the closest survivor or a specified survivor to a 2D point on the horizontal plane
 * @param gridPos - from where we are measuring the distance to survivors
 * @return: the closest survivor on the horizontal 2D plane
 */
stock GetClosestSurvivor2D(float x_coord, float y_coord) 
{
	new Float:proximity = -1.0;
	new closestSurvivor = GetRandomSurvivor();
	if ( !IsValidClient(closestSurvivor) ) 
	{
		LogError("GetClosestSurvivor2D(%f, %f) - Unable to find any survivors", x_coord, y_coord);
	}		
	for( new j = 1; j <= MAXPLAYERS; j++ ) {
		if( IsSurvivor(j) && IsPlayerAlive(j) ) {
			new Float:survivorPos[3];
			GetClientAbsOrigin( j, survivorPos );
			// Pythagoras
			new Float:survivorDistance = SquareRoot( Pow(survivorPos[X_COORD] - x_coord, 2.0) + Pow(survivorPos[Y_COORD] - y_coord, 2.0) );
			if( survivorDistance < proximity || proximity == -1.0 ) {
				proximity = survivorDistance;
				closestSurvivor = j;
			}
		}
	}
	return closestSurvivor;
}

/**
 * Returns the distance of the closest survivor or a specified survivor
 * @param referenceClient: the client from which to measure distance to survivor
 * @param specificSurvivor: the index of the survivor to be measured, -1 to search for distance to closest survivor
 * @return: the distance
 */
stock GetSurvivorProximity( const Float:rp[3], specificSurvivor = -1 ) {
	
	new targetSurvivor;
	new Float:targetSurvivorPos[3];
	new Float:referencePos[3]; // non constant var
	referencePos[0] = rp[0];
	referencePos[1] = rp[1];
	referencePos[2] = rp[2];
	
	if( specificSurvivor > 0 && IsSurvivor(specificSurvivor) ) { // specified survivor
		targetSurvivor = specificSurvivor;		
	} else { // closest survivor		
		targetSurvivor = GetClosestSurvivor( referencePos );
	}
	
	GetEntPropVector( targetSurvivor, Prop_Send, "m_vecOrigin", targetSurvivorPos );
	return RoundToNearest( GetVectorDistance(referencePos, targetSurvivorPos) );
}
/*
/** @return: the index to a random survivor 
stock GetRandomSurvivor() {
	// Initialise
	new survivors[MAXPLAYERS];
	for ( int i = 0; i < MAXPLAYERS; ++i )
	{
		survivors[i] = -1;	
	}
	// Fill array with survivor client numbers
	new numSurvivors = 0;
	for( new i = 1; i <= MAXPLAYERS; i++ ) {
		if( IsSurvivor(i) && IsPlayerAlive(i) ) {
		    survivors[numSurvivors] = i;
		    numSurvivors++;
		}
	}
	// Return a random survivor
	return survivors[GetRandomInt(0, numSurvivors - 1)];
}
/*
/***********************************************************************************************************************************************************************************

                                                                   	SPECIAL INFECTED 
                                                                    
***********************************************************************************************************************************************************************************/

/**
 * @return: the special infected class of the client
 */
stock L4D2_Infected:GetInfectedClass(client) {
    return L4D2_Infected:GetEntProp(client, Prop_Send, "m_zombieClass");
}

stock bool IsInfected(int client) {
	if (!IsValidClient(client)) return false;
	if (GetClientTeam(client) == _:L4D2_Infected) return true;
	return false;
}

/**
 * @return: true if client is a special infected bot
 */
stock bool:IsBotInfected(client) {
    // Check the input is valid
    if (!IsValidClient(client))return false;
    
    // Check if player is a bot on the infected team
    if (IsInfected(client) && IsFakeClient(client)) {
        return true;
    }
    return false; // otherwise
}

stock bool:IsBotHunter(client) {
	return (IsBotInfected(client) && GetInfectedClass(client) == L4D2_Infected:L4D2Infected_Hunter);
}

stock bool:IsBotCharger(client) {
	return (IsBotInfected(client) && GetInfectedClass(client) == L4D2_Infected:L4D2Infected_Charger);
}

stock bool:IsBotJockey(client) {
	return (IsBotInfected(client) && GetInfectedClass(client) == L4D2_Infected:L4D2Infected_Jockey);
}

// @return: the number of a particular special infected class alive in the game
stock CountSpecialInfectedClass(ZombieClass:targetClass) {
    new count = 0;
    for (new i = 1; i < MaxClients; i++) {
        if ( IsBotInfected(i) && IsPlayerAlive(i) && !IsClientInKickQueue(i) ) {
            new playerClass = GetEntProp(i, Prop_Send, "m_zombieClass");
            if (playerClass == _:targetClass) {
                count++;
            }
        }
    }
    return count;
}

// @return: the total special infected bots alive in the game
stock CountSpecialInfectedBots() {
    new count = 0;
    for (new i = 1; i < MaxClients; i++) {
        if (IsBotInfected(i) && IsPlayerAlive(i)) {
            count++;
        }
    }
    return count;
}

/***********************************************************************************************************************************************************************************

                                                                       		TANK
                                                                    
***********************************************************************************************************************************************************************************/

/**
 *@return: true if client is a tank
 */
stock bool:IsTank(client) {
    return IsClientConnected(client)
        && L4D2_Team:GetClientTeam(client) == L4D2Team_Infected
        && GetInfectedClass(client) == L4D2Infected_Tank;
}

/**
 * Searches for a player who is in control of a tank.
 *
 * @param iTankClient client index to begin searching from
 * @return client ID or -1 if not found
 */
stock FindTankClient(iTankClient) {
    for (new i = iTankClient < 0 ? 1 : iTankClient+1; i < MaxClients+1; i++) {
        if (IsTank(i)) {
            return i;
        }
    }
    
    return -1;
}

/**
 * Is there a tank currently in play?
 *
 * @return bool
 */
stock bool:IsTankInPlay() {
    return bool:(FindTankClient(-1) != -1);
}

stock bool:IsBotTank(client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	if (L4D2_Team:GetClientTeam(client) == L4D2_Team:L4D2Team_Infected) {
		new L4D2_Infected:zombieClass = L4D2_Infected:GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == L4D2_Infected:L4D2Infected_Tank) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; // otherwise
}

/***********************************************************************************************************************************************************************************

                                                                   			MISC
                                                                    
***********************************************************************************************************************************************************************************/

/**
 * Executes a cheat command through a dummy client
 *
 * @param command: The command to execute
 * @param argument1: Optional argument for command
 * @param argument2: Optional argument for command
 * @param dummyName: The name to use for the dummy client 
 *
**/
stock CheatCommand( String:commandName[], String:argument1[] = "", String:argument2[] = "", bool:doUseCommandBot = false ) {
    new flags = GetCommandFlags(commandName);       
    if ( flags != INVALID_FCVAR_FLAGS ) {
		new commandDummy = -1;
		if( doUseCommandBot ) {
			// Search for an existing bot named '[CommandBot]'
			for( new i = 1; i < MAXPLAYERS; i++ ) {
				if( IsValidClient(i) && IsClientInGame(i) && IsFakeClient(i) ) {
					new String:clientName[32];
					GetClientName( i, clientName, sizeof(clientName) );
					if( StrContains( clientName, "[CommandBot]", true ) != -1 ) {
						commandDummy = i;
					}
				}  		
			}
			// Create a command bot if necessary
			if ( !IsValidClient(commandDummy) || IsClientInKickQueue(commandDummy) ) { // Command bot may have been kicked by SMAC_Antispam.smx
			    commandDummy = CreateFakeClient("[CommandBot]");
			    if( IsValidClient(commandDummy) ) {
			    	ChangeClientTeam(commandDummy, _:L4D2Team_Spectator);	
			    } else {
			    	commandDummy = GetRandomSurvivor(); // wanted to use a bot, but failed; last resort
			    }			
			}
		} else {
			commandDummy = GetRandomSurvivor();
		}
		
		// Execute command
		if ( IsValidClient(commandDummy) ) {
		    new originalUserFlags = GetUserFlagBits(commandDummy);
		    new originalCommandFlags = GetCommandFlags(commandName);            
		    SetUserFlagBits(commandDummy, ADMFLAG_ROOT); 
		    SetCommandFlags(commandName, originalCommandFlags ^ FCVAR_CHEAT);               
		    FakeClientCommand(commandDummy, "%s %s %s", commandName, argument1, argument2);
		    SetCommandFlags(commandName, originalCommandFlags);
		    SetUserFlagBits(commandDummy, originalUserFlags);            
		} else {
			new String:pluginName[128];
			GetPluginFilename( INVALID_HANDLE, pluginName, sizeof(pluginName) );        
			LogError( "%s could not find or create a client through which to execute cheat command %s", pluginName, commandName );
		}   
    }
}

// Executes vscript code through the "script" console command
stock ScriptCommand(const String:arguments[], any:...) {
    // format vscript input
    new String:vscript[PLATFORM_MAX_PATH];
    VFormat(vscript, sizeof(vscript), arguments, 2);
    
    // Execute vscript input
    CheatCommand("script", vscript, "");
}

// Sets the spawn direction for SI, relative to the survivors
// Yet to test whether map specific scripts override this option, and if so, how to rewrite this script line
stock SetSpawnDirection(SpawnDirection:direction) {
    ScriptCommand("g_ModeScript.DirectorOptions.PreferredSpecialDirection<-%i", _:direction);   
}

/**
 * Returns true if the client ID is valid
 *
 * @param client: client ID
 * @return bool
 */

stock bool IsValidClient(int client, bool replaycheck = false) {
	if ( client <= 0 || client > MaxClients ) return false;
	if ( !IsClientInGame(client) ) return false;
	if (replaycheck) 
	{
		if ( IsClientSourceTV(client) || IsClientReplay(client) ) return false;
	}
	return true;
}

stock bool:IsGenericAdmin(client) {
	return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false); 
}

// Kick dummy bot 
public Action:Timer_KickBot(Handle:timer, any:client) {
	if ( IsClientConnected(client) && !IsClientInKickQueue(client) && IsFakeClient(client) ) {
		KickClient(client);
	}
}