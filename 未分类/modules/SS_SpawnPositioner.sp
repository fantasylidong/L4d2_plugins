#pragma semicolon 1

#define PI 3.14159265359
#define UNINITIALISED_FLOAT -1.42424

#define BOUNDINGBOX_INFLATION_OFFSET 0.5
#define NAV_MESH_HEIGHT 20.0
#define DEBUG_DRAW_ELEVATION 100.0

#define COORD_X 0
#define COORD_Y 1
#define COORD_Z 2
#define X_MIN 0
#define X_MAX 1
#define Y_MIN 2
#define Y_MAX 3

#define PITCH 0
#define YAW 1
#define ROLL 2
#define MAX_ANGLE 89.0

#define INVALID_MESH 0
#define VALID_MESH 1
#define SPAWN_FAIL 2
#define WHITE 3
#define PURPLE 4

new g_AllSurvivors[MAXPLAYERS]; // MAXPLAYERS because who knows what survivor limit people may use
new Float:spawnBounds[4]; // denoted by minimum and maximum X and Y coordinates

new laserCache;

/*
 * Bibliography
 * - Epilimic's witch spawner code
 * - "Player-Teleport by Dr. HyperKiLLeR" (sm_gotoRevA.smx)
 * Thanks to Newteee for his repositioning algorithm
 */

SpawnPositioner_OnModuleStart() {
	hCvarSpawnPositionerMode = CreateConVar( "ss_spawnpositioner_mode", "3", "[ 0 = disabled, 1 = Radial Reposition only, 2 = Grid Reposition with Radial fallback, 3 = nav mesh spawning ]" );
	HookConVarChange( hCvarSpawnPositionerMode, ConVarChanged:SpawnPositionerMode );
	hCvarMaxSearchAttempts = CreateConVar( "ss_spawn_max_search_attempts", "500", "Max attempts to make per SI spawn to find an acceptable location to which to relocate them" );
	hCvarSpawnSearchHeight = CreateConVar( "ss_spawn_search_height", "50", "Attempts to find a valid spawn location will move down from this height relative to a survivor");
	hCvarSpawnProximityMin = CreateConVar( "ss_spawn_proximity_min", "500", "Closest an SI may spawn to a survivor", FCVAR_SS_ADDED, true, 1.0 );
	hCvarSpawnProximityMax = CreateConVar( "ss_spawn_proximity_max", "650", "Furthest an SI may spawn to a survivor", FCVAR_SS_ADDED, true, float(GetConVarInt(hCvarSpawnProximityMin)) );
	// N.B. the hCvarSpawnProximityFlow___ cvars are not a lower and upper bound;
	hCvarSpawnProximityFlowNoLOS = CreateConVar( "ss_spawn_proximity_flow_dist_no_LOS", "500", 
									"Closest spawns by flow distance; considered when there is no LOS on survivors" );
	hCvarSpawnProximityFlowLOS = CreateConVar( "ss_spawn_proximity_flow_dist_LOS", "900", 
									"Farthest spawns by flow distance; bounded by lowest straight line distance to survivor team" );
}

SpawnPositioner_OnModuleEnd() {
	ResetConVar( FindConVar("z_spawn_range") );
}

public SpawnPositionerMode() {
	if( GetConVarBool(hCvarSpawnPositionerMode) ) {
		ResetConVar( FindConVar("z_spawn_range") ); // default value is 1500
	} else {
		SetConVarInt( FindConVar("z_spawn_range"), 1000 ); // spawn SI closer as they are not being repositioned; no second chances for failed spawns
	}
}

/***********************************************************************************************************************************************************************************

                                     								DETERMINE POSITION
                                                                    
***********************************************************************************************************************************************************************************/

// Handles radial and grid spawning; Nav Mesh spawning is handled differently in SpawnQueue module and does not pass on to here.
AttemptSpawnAuto(L4D2_Infected:SIClass)
{
	if( CheckSurvivorsSeparated() )
	{
		RadialSpawn( SIClass, GetLeadSurvivor() );	
	}
	else if( GetConVarInt(hCvarSpawnPositionerMode) == 2 ) 
	{
		GridSpawn( SIClass );
	} 
	else 
	{ 
		RadialSpawn( SIClass, GetRandomSurvivor() );
	}
}

/***********************************************************************************************************************************************************************************

                                             					GRID POSITIONING SYSTEM
                                                                    
***********************************************************************************************************************************************************************************/

/*
 * Reposition the SI to a random point on a 2D grid around the survivors. 
 */
GridSpawn( L4D2_Infected:SIClass ) {
	
	UpdateSpawnBounds();
	
	for( new i = 0; i < GetConVarInt(hCvarMaxSearchAttempts); i++ ) {
		new Float:searchPos[3];
		new Float:survivorPos[3];
		new closestSurvivor;
		
		// 'x' and 'y' for potential spawn point coordinates is selected with uniform RNG
		searchPos[COORD_X] = GetRandomFloat(spawnBounds[X_MIN], spawnBounds[X_MAX]);
		searchPos[COORD_Y] = GetRandomFloat(spawnBounds[Y_MIN], spawnBounds[Y_MAX]);
		// 'z' for potential spawn point coordinate is taken from just above the height of nearest survivor
		closestSurvivor = GetClosestSurvivor2D(searchPos[COORD_X], searchPos[COORD_Y]);
		GetClientAbsOrigin(closestSurvivor, survivorPos);
		searchPos[COORD_Z] = survivorPos[COORD_Z] + float( GetConVarInt(hCvarSpawnSearchHeight) );
		
		// Search down the vertical column from the generated [x, y ,z] coordinate for a valid spawn position
		new Float:direction[3];
		direction[PITCH] = MAX_ANGLE; // straight down
		direction[YAW] = 0.0;
		direction[ROLL] = 0.0;
		TR_TraceRay( searchPos, direction, MASK_ALL, RayType_Infinite );
		
		// found solid land below the [x, y, z] coordinate
		if( TR_DidHit() ) { 
			new Float:traceImpact[3];
			new Float:spawnPos[3];
			TR_GetEndPosition( traceImpact ); 
			spawnPos = traceImpact;
			spawnPos[COORD_Z] += NAV_MESH_HEIGHT; // from testing I presume the SI cannot spawn on the floor itself
			
			if ( IsValidSpawn(spawnPos) ) {
			
					#if DEBUG_POSITIONER
						DrawSpawnGrid();
						PrintToChatAll("[SS] SI Class %d GRID SPAWN, %d dist, ( %d attempts)", SIClass, RoundFloat(GetFlowDistToSurvivors(spawnPos)), i + 1);
						searchPos[COORD_Z] = DEBUG_DRAW_ELEVATION;
						DrawBeam( searchPos, spawnPos, VALID_MESH );
					#endif
				TriggerSpawn(SIClass, spawnPos, NULL_VECTOR); // all spawn conditions satisifed
				return;
				
			} else {

					#if DEBUG_POSITIONER
						DrawSpawnGrid();
						searchPos[COORD_Z] = DEBUG_DRAW_ELEVATION;
						DrawBeam( searchPos, spawnPos, INVALID_MESH );
					#endif
					
			}
		} 
 	}
 	// Could not find an acceptable spawn position
	LogMessage("[SS] FAILED to find a valid GRID SPAWN position for SI Class '%d' after %d attempts", SIClass, GetConVarInt(hCvarMaxSearchAttempts) ); 
	return;
 }
 
bool:IsValidSpawn(const Float:spawnPos[3]) {
	new bool:is_valid = false;
	new flow_dist_survivors;
	if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, GetRandomSurvivor()) ) {
		flow_dist_survivors = GetFlowDistToSurvivors(spawnPos);
		if ( HasSurvivorLOS(spawnPos) ) {
			new survivor_proximity = GetSurvivorProximity(spawnPos);
			if ( survivor_proximity > GetConVarInt(hCvarSpawnProximityMin) && flow_dist_survivors < GetConVarInt(hCvarSpawnProximityFlowLOS) ) { 
				is_valid = true;
			}
		} else { // try to keep spawn flow distance to survivors low if they are spawning outside of LOS
			if ( flow_dist_survivors < GetConVarInt(hCvarSpawnProximityFlowNoLOS) && flow_dist_survivors != -1 ) {
					
					#if DEBUG_POSITIONER
						PrintToChatAll("flow dist %d < cvar %d", flow_dist_survivors, GetConVarInt(hCvarSpawnProximityFlowNoLOS));
					#endif
				
				is_valid = true;
			}
		}
	}
	return is_valid;
}

UpdateSpawnBounds() {
	// Grid will have coords (min X, min Y), (min X, max Y), (max X, min Y), (max X, max Y)
	spawnBounds[X_MIN] = UNINITIALISED_FLOAT, spawnBounds[Y_MIN] = UNINITIALISED_FLOAT;
	spawnBounds[X_MAX] = UNINITIALISED_FLOAT, spawnBounds[Y_MAX] = UNINITIALISED_FLOAT;
	for( new i = 1; i < MaxClients; i++ ) {
		if( IsSurvivor(i) && IsPlayerAlive(i) ) {
			new Float:pos[3];
			GetClientAbsOrigin(i, pos);
			// Check min
			spawnBounds[X_MIN] = CheckMinCoord( spawnBounds[X_MIN], pos[COORD_X] );
			spawnBounds[Y_MIN] = CheckMinCoord( spawnBounds[Y_MIN], pos[COORD_Y] );
			// Check max
			spawnBounds[X_MAX] = CheckMaxCoord( spawnBounds[X_MAX], pos[COORD_X] );
			spawnBounds[Y_MAX] = CheckMaxCoord( spawnBounds[Y_MAX], pos[COORD_Y] );
		}
	}
	// Extend a border around grid
	new Float:borderWidth = float( GetConVarInt(hCvarSpawnProximityMax) );
	spawnBounds[X_MIN] -= borderWidth;
	spawnBounds[Y_MIN] -= borderWidth;
	spawnBounds[X_MAX] += borderWidth;
	spawnBounds[Y_MAX] += borderWidth;
}

Float:CheckMinCoord( Float:oldMin, Float:checkValue ) {
	if( checkValue < oldMin || oldMin == UNINITIALISED_FLOAT ) {
		return checkValue;
	} else {
		return oldMin;
	}
}

Float:CheckMaxCoord( Float:oldMax, Float:checkValue ) {
	if( checkValue > oldMax || oldMax == UNINITIALISED_FLOAT ) {
		return checkValue;
	} else {
		return oldMax;
	}
}

stock DrawSpawnGrid() {
	new Float:xMin = spawnGrid[X_MIN];
	new Float:xMax = spawnGrid[X_MAX];
	new Float:yMin = spawnGrid[Y_MIN];
	new Float:yMax = spawnGrid[Y_MAX];
	new Float:z = DEBUG_DRAW_ELEVATION;
	new Float:bottomLeft[3]; 
	bottomLeft[0] = xMin;
	bottomLeft[1] = yMin;
	bottomLeft[2] = z;
	new Float:topLeft[3];
	topLeft[0] = xMin;
	topLeft[1] = yMax;
	topLeft[2] = z;
	new Float:topRight[3];
	topRight[0] = xMax;
	topRight[1] = yMax;
	new Float:bottomRight[3]; 
	bottomRight[0] = xMax;
	bottomRight[1] = yMin;
	bottomLeft[2] = z;
	topRight[2] = z;
	DrawBeam( bottomLeft, topLeft, PURPLE );  
	DrawBeam( topLeft, topRight, PURPLE ); 
	DrawBeam( topRight, bottomRight, PURPLE );  
	DrawBeam( bottomRight, bottomLeft, PURPLE );  
}

/***********************************************************************************************************************************************************************************

                                             					RADIAL POSITIONING SYSTEM
                                                                    
***********************************************************************************************************************************************************************************/

/*
 * Reposition the SI to a point on the circumference of a circle [spawn_proximity] from a survivor; respects distance to all survivors
 * Always spawns SI at [ss_spawn_proximity_min] distance to survivors
 */
RadialSpawn( L4D2_Infected:SIClass, survivorTarget ) {
	new bool:spawnSuccess = false;
	new Float:survivorPos[3];
	new Float:rayEnd[3];
	new Float:spawnPos[3] = {-1.0, -1.0, -1.0};
	for( new i = 0; i < GetConVarInt(hCvarMaxSearchAttempts); i++ ) {		
		// Fire a ray at a random angle around the survivor
		GetClientAbsOrigin(survivorTarget, survivorPos); 
		new Float:spawnSearchAngle = GetRandomFloat(0.0, 2.0 * PI);
		rayEnd[0] = survivorPos[0] + Sine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximityMin);
		rayEnd[1] = survivorPos[1] + Cosine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximityMin);
		rayEnd[2] = survivorPos[2] + GetConVarInt(hCvarSpawnSearchHeight);
		// Search down the vertical column from the ray's' endpoint for a valid spawn position
		new Float:direction[3];
		direction[PITCH] = MAX_ANGLE; // straight down
		direction[YAW] = 0.0;
		direction[ROLL] = 0.0;
		TR_TraceRay( rayEnd, direction, MASK_ALL, RayType_Infinite );
		if( TR_DidHit() ) {
			new Float:traceImpact[3];
			TR_GetEndPosition( traceImpact );
			spawnPos = traceImpact;
			spawnPos[COORD_Z] += NAV_MESH_HEIGHT; // from testing I presume the SI cannot spawn on the floor itself
			// Have to use the size of a survivor to estimate if SI will get stuck, 
			// as with recent update to this plugin, the SI do not get repositioned but are spawned directly into the decided position
			if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, GetRandomSurvivor()) && GetSurvivorProximity(spawnPos) > GetConVarInt(hCvarSpawnProximityMin) ) {
						
					#if DEBUG_POSITIONER
						LogMessage("[SS] ( %d attempts ) Found a valid RADIAL SPAWN position for SI Class '%d'", i, SIClass);
						DrawBeam( survivorPos, rayEnd, VALID_MESH );
						DrawBeam( rayEnd, spawnPos, VALID_MESH ); 
					#endif
						
				TriggerSpawn(SIClass, spawnPos, NULL_VECTOR); 
				spawnSuccess = true;
				break;
					
			} else {
			
					#if DEBUG_POSITIONER
						DrawBeam( survivorPos, rayEnd, INVALID_MESH );
						DrawBeam( rayEnd, spawnPos, WHITE ); 
					#endif
					
			}
		}
	}
		
	// Could not find an acceptable spawn position
	if(!spawnSuccess) {
		LogMessage("[SS] FAILED to find a valid RADIAL SPAWN position for infected class '%d' after %d attempts", SIClass, GetConVarInt(hCvarMaxSearchAttempts) ); 
	}		
}

/* Determine if the lead survivor is too far ahead of the rear survivor, using the [spawn_proximity] cvar 
 * @return: a random survivor or a survivor that is rushing too far ahead in front
 */
bool:CheckSurvivorsSeparated() {
	// Lead survivor position
	new leadSurvivor = GetLeadSurvivor();
	new Float:leadSurvivorPos[3];
	if( IsSurvivor(leadSurvivor) ) {
		GetClientAbsOrigin( leadSurvivor, leadSurvivorPos );
	}
	// Rear survivor position
	new rearSurvivor = GetRearSurvivor();
	new Float:rearSurvivorPos[3];
	if( IsSurvivor(rearSurvivor) ) {
		GetClientAbsOrigin( rearSurvivor, rearSurvivorPos );
	}
	// Is the leading player too far ahead?
	if( GetVectorDistance( leadSurvivorPos, rearSurvivorPos ) > float(2 * GetConVarInt(hCvarSpawnProximityMax)) ) {
		return true;
	} else {
		return false;
	}
}

/***********************************************************************************************************************************************************************************

                                                                      UTILITY	
                                                                    
***********************************************************************************************************************************************************************************/
	
stock bool:HasSurvivorLOS( const Float:pos[3] ) {
	new bool:hasLOS = false;
	for( new i = 1; i < MaxClients; ++i ) {
		if( IsSurvivor(i) && IsPlayerAlive(i) ) {
			new Float:origin[3];
			GetClientAbsOrigin(i, origin);
			TR_TraceRay( pos, origin, MASK_ALL, RayType_EndPoint );
			if( !TR_DidHit() ) {
				hasLOS = true;
				break;
			}
		}	
	}
	return hasLOS;
}

GetLeadSurvivor() {
	// Find the farthest flow held by a survivor
	new Float:farthestFlow = -1.0;
	new leadSurvivor = -1;
	for( new i = 1; i < MaxClients; i++ ) {
		if( IsSurvivor(i) && IsPlayerAlive(i) ) {
			new Float:origin[3];
			GetClientAbsOrigin(i, origin);
			new Address:pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if( pNavArea != Address_Null ) {
				new Float:tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				if( tmp_flow > farthestFlow || farthestFlow == -1.0 ) {
					farthestFlow = tmp_flow;
					leadSurvivor = i;
				}
			}
		}
	}
	return leadSurvivor;
}

GetRearSurvivor() {
	// Find the farthest flow held by a survivor
	new Float:lowestFlow = -1.0;
	new rearSurvivor = -1;
	for( new i = 1; i < MaxClients; i++ ) {
		if( IsSurvivor(i) && IsPlayerAlive(i) ) {
			new Float:origin[3];
			GetClientAbsOrigin(i, origin);
			new Address:pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if( pNavArea != Address_Null ) {
				new Float:tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				if( tmp_flow < lowestFlow || lowestFlow == -1.0 ) {
					lowestFlow = tmp_flow;
					rearSurvivor = i;
				}
			}
		}
	}
	return rearSurvivor;
}

bool:IsPlayerStuck( const Float:pos[3], client) {
	new bool:isStuck = true;
	if( IsValidClient(client) ) {
		new Float:mins[3];
		new Float:maxs[3];		
		GetClientMins(client, mins);
		GetClientMaxs(client, maxs);
		
		// inflate the sizes just a little bit
		for( new i = 0; i < sizeof(mins); i++ ) {
		    mins[i] -= BOUNDINGBOX_INFLATION_OFFSET;
		    maxs[i] += BOUNDINGBOX_INFLATION_OFFSET;
		}
		
		TR_TraceHullFilter(pos, pos, mins, maxs, MASK_ALL, TraceEntityFilterPlayer, client);
		isStuck = TR_DidHit();
	}
	return isStuck;
}  

// filter out players, since we can't get stuck on them
public bool:TraceEntityFilterPlayer(entity, contentsMask) {
    return entity <= 0 || entity > MaxClients;
}  

/** @return: the last array index of g_AllSurvivors holding a valid survivor */
stock CacheSurvivors() {
	new j = 0;
	for( new i = 0; i < MAXPLAYERS; i++ ) {
		if( IsSurvivor(i) ) {
		    g_AllSurvivors[j] = i;
		    j++;
		}
	}
	return (j - 1);
}

stock bool:IsOnValidMesh(const Float:position[3]) {
	new Float:pos[3];
	pos[0] = position[0]; 
	pos[1] = position[1]; 
	pos[2] = position[2]; 
	new Address:pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(pos);
	if (pNavArea != Address_Null) { 
		return true;
	} else {
		return false;
	}
}

stock DrawBeam( Float:startPos[3], Float:endPos[3], spawnResult ) {
	laserCache = PrecacheModel("materials/sprites/laserbeam.vmt");
	new Color[5][4]; 
	Color[VALID_MESH] = {0, 255, 0, 75}; // green
	Color[INVALID_MESH] = {255, 0, 0, 75}; // red
	Color[SPAWN_FAIL] = {255, 140, 0, 75}; // orange
	Color[WHITE] = {255, 255, 255, 75}; // white
	Color[PURPLE] = {128, 0, 128, 75}; // purple
	new Float:beamDuration = 5.0;
	TE_SetupBeamPoints(startPos, endPos, laserCache, 0, 1, 1, beamDuration, 5.0, 5.0, 4, 0.0, Color[spawnResult], 0);
	new iSurvivors[MaxClients];
	new iNumSurvivors = 0;
	for( new i = 1; i < MaxClients; i++ ) {
		if( IsSurvivor(i) && !IsFakeClient(i) ) {
			iSurvivors[iNumSurvivors] = i;
			iNumSurvivors++;
		}
	}
	TE_Send( iSurvivors, iNumSurvivors ); 
}