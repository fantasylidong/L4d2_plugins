new Handle:hSpawnTimer;
new Handle:hSpawnTimeMode;
new Handle:hSpawnTimeMin;
new Handle:hSpawnTimeMax;

new Handle:hCvarFrequencyBoomerAmbush;
new Handle:hTimerBoomer;

new Handle:hCvarIncapAllowance;

new Float:SpawnTimes[MAXPLAYERS];
new Float:IntervalEnds[NUM_TYPES_INFECTED];

new g_bHasSpawnTimerStarted = true;
new g_bHasBoomerTimerStarted = true;

SpawnTimers_OnModuleStart() {
	// Timer
	hSpawnTimeMin = CreateConVar("ss_time_min", "12.0", "The minimum auto spawn time (seconds) for infected", FCVAR_SS_ADDED, true, 0.0);
	hSpawnTimeMax = CreateConVar("ss_time_max", "15.0", "The maximum auto spawn time (seconds) for infected", FCVAR_SS_ADDED, true, 1.0);
	hSpawnTimeMode = CreateConVar("ss_time_mode", "1", "The spawn time mode [ 0 = RANDOMIZED | 1 = INCREMENTAL | 2 = DECREMENTAL ]", FCVAR_SS_ADDED, true, 0.0, true, 2.0);
	hCvarFrequencyBoomerAmbush = CreateConVar("ss_boomer_frequency", "7.0", "Roughly how often to attempt to ambush survivors with a boomer", FCVAR_SS_ADDED);
	HookConVarChange(hSpawnTimeMin, ConVarChanged:CalculateSpawnTimes);
	HookConVarChange(hSpawnTimeMax, ConVarChanged:CalculateSpawnTimes);
	HookConVarChange(hSpawnTimeMode, ConVarChanged:CalculateSpawnTimes);
	// Grace period
	hCvarIncapAllowance = CreateConVar( "ss_incap_allowance", "7", "Grace period(sec) per incapped survivor" );
	// sets SpawnTimeMin, SpawnTimeMax, and SpawnTimes[]
	SetSpawnTimes(); 
}

SpawnTimers_OnModuleEnd() {
	CloseHandle(hSpawnTimer);
}

/***********************************************************************************************************************************************************************************

                                                                           START TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

//never directly set hSpawnTimer, use this function for custom spawn times
StartCustomSpawnTimer(Float:time) {
	//prevent multiple timer instances
	EndSpawnTimer();
	//only start spawn timer if plugin is enabled
	g_bHasSpawnTimerStarted = true;
	hSpawnTimer = CreateTimer( time, SpawnInfectedAuto, TIMER_FLAG_NO_MAPCHANGE );
}

//special infected spawn timer based on time modes
StartSpawnTimer() {
	//prevent multiple timer instances
	EndSpawnTimer();
	//only start spawn timer if plugin is enabled
	new Float:time;
	
	if( GetConVarInt(hSpawnTimeMode) > 0 ) { //NOT randomization spawn time mode
		time = SpawnTimes[CountSpecialInfectedBots()]; //a spawn time based on the current amount of special infected
	} else { //randomization spawn time mode
		time = GetRandomFloat( GetConVarFloat(hSpawnTimeMin), GetConVarFloat(hSpawnTimeMax) ); //a random spawn time between min and max inclusive
	}
	g_bHasSpawnTimerStarted = true;
	hSpawnTimer = CreateTimer( time, SpawnInfectedAuto, TIMER_FLAG_NO_MAPCHANGE );
	
		#if DEBUG_TIMERS
			PrintToChatAll("[SS] New spawn timer | Mode: %d | SI: %d | Next: %.3f s", GetConVarInt(hSpawnTimeMode), CountSpecialInfectedBots(), time);
		#endif
}

StartBoomerTimer() {
	EndBoomerTimer();
	g_bHasBoomerTimerStarted = true;	
	new Float:avgFrequency = GetConVarFloat(hCvarFrequencyBoomerAmbush);
	hTimerBoomer = CreateTimer( GetRandomFloat(avgFrequency, avgFrequency + 2.0), Timer_BoomerAmbush, TIMER_FLAG_NO_MAPCHANGE );
	
		#if DEBUG_TIMERS
			PrintToChatAll("[SS] Boomer timer started");
		#endif
}

/***********************************************************************************************************************************************************************************

                                                                       SPAWN TIMER
                                                                    
***********************************************************************************************************************************************************************************/

public Action:SpawnInfectedAuto(Handle:timer) {
	g_bHasSpawnTimerStarted = false; 
	// Grant grace period before allowing a wave to spawn if there are incapacitated survivors
	new numIncappedSurvivors = 0;
	for (new i = 1; i <= MaxClients; i++ ) {
		if( IsSurvivor(i) && IsIncapacitated(i) && !IsPinned(i) ) {
			numIncappedSurvivors++;			
		}
	}
	if( numIncappedSurvivors > 0 && numIncappedSurvivors != GetConVarInt(FindConVar("survivor_limit")) ) { // grant grace period
		new gracePeriod = numIncappedSurvivors * GetConVarInt(hCvarIncapAllowance);
		CreateTimer( float(gracePeriod), Timer_GracePeriod, _, TIMER_FLAG_NO_MAPCHANGE );
		CPrintToChatAll("{olive}[{default}SS{olive}]{default} {blue}%d{default}s {olive}grace period{default} was granted because of {blue}%d{default} incapped survivor(s)", gracePeriod, numIncappedSurvivors);
	} else { // spawn immediately
		GenerateAndExecuteSpawnQueue();
	}
	// Start timer for next spawn group
	StartSpawnTimer();
	return Plugin_Handled;
}

public Action:Timer_BoomerAmbush(Handle:timer) {
	g_bHasBoomerTimerStarted = false;
	// Spawn_NavMesh(L4D2Infected_Boomer); // rewriting spawn function
	StartBoomerTimer();	
}

public Action:Timer_GracePeriod(Handle:timer) {
	GenerateAndExecuteSpawnQueue();
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                        END TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

EndSpawnTimer() {
	if( g_bHasSpawnTimerStarted ) {
		if( hSpawnTimer != INVALID_HANDLE ) {
			CloseHandle(hSpawnTimer);
			hSpawnTimer = INVALID_HANDLE;
		}
		g_bHasSpawnTimerStarted = false;
		
			#if DEBUG_TIMERS
				PrintToChatAll("[SS] Ending spawn timer.");
			#endif
		
	}
}

EndBoomerTimer() {
	if ( g_bHasBoomerTimerStarted ) {
		if ( hTimerBoomer != INVALID_HANDLE ) {
			CloseHandle(hTimerBoomer);
			hTimerBoomer = INVALID_HANDLE;			
		}
		g_bHasBoomerTimerStarted = false;
		
			#if DEBUG_TIMERS
				PrintToChatAll("[SS] Ending boomer timer.");
			#endif
	}
}

/***********************************************************************************************************************************************************************************

                                                                    	UTILITY
                                                                    
***********************************************************************************************************************************************************************************/

SetSpawnTimes() {
	new Float:fSpawnTimeMin = GetConVarFloat(hSpawnTimeMin);
	new Float:fSpawnTimeMax = GetConVarFloat(hSpawnTimeMax);
	if( fSpawnTimeMin > fSpawnTimeMax ) { //SpawnTimeMin cannot be greater than SpawnTimeMax
		SetConVarFloat( hSpawnTimeMin, fSpawnTimeMax ); //set back to appropriate limit
	} else if( fSpawnTimeMax < fSpawnTimeMin ) { //SpawnTimeMax cannot be less than SpawnTimeMin
		SetConVarFloat(hSpawnTimeMax, fSpawnTimeMin ); //set back to appropriate limit
	} else {
		CalculateSpawnTimes(); //must recalculate spawn time table to compensate for min change
	}
}

public CalculateSpawnTimes() {
	new iSILimit =  GetConVarInt(hSILimit);
	new Float:fSpawnTimeMin = GetConVarFloat(hSpawnTimeMin);
	new Float:fSpawnTimeMax = GetConVarFloat(hSpawnTimeMax);
	if( iSILimit > 1 && GetConVarInt(hSpawnTimeMode) > 0 ) {
		new Float:unit = ( (fSpawnTimeMax - fSpawnTimeMin) / (iSILimit - 1) );
		switch( GetConVarInt(hSpawnTimeMode) ) {
			case 1: { // incremental spawn time mode			
				SpawnTimes[0] = fSpawnTimeMin;
				for( int i = 1; i < MAXPLAYERS; i++ ) {
					if( i < iSILimit ) {
						SpawnTimes[i] = SpawnTimes[i-1] + unit;
					} else {
						SpawnTimes[i] = fSpawnTimeMax;
					}
				}
			}
			case 2: { // decremental spawn time mode			
				SpawnTimes[0] = fSpawnTimeMax;
				for( int i = 1; i < MAXPLAYERS; i++ ) {
					if (i < iSILimit) {
						SpawnTimes[i] = SpawnTimes[i-1] - unit;
					} else {
						SpawnTimes[i] = fSpawnTimeMax;
					}
				}
			}
			//randomized spawn time mode does not use time tables
		}	
	} else { //constant spawn time for if SILimit is 1
		SpawnTimes[0] = fSpawnTimeMax;
	}
	
		#if DEBUG_TIMERS
			for (int i = 1; i < NUM_TYPES_INFECTED; i++) {
				LogMessage("%d : %.5f s", i, SpawnTimes[i]);
			}
		#endif
}

