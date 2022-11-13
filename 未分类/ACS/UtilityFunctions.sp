// Check that ACS knows the game mode provided by the parameter
bool IsGameModeValid(int iGameMode)
{
	if (iGameMode != GAMEMODE_UNKNOWN)
		return true;
	
	LogError("ACS Error: Invalid Game Mode!");
	return false;
}

// Check if the current map is the last in the campaign if not in the Scavenge game mode
bool OnFinaleOrScavengeOrSurvivalMap()
{
	if (g_iGameMode == GAMEMODE_SCAVENGE ||
		g_iGameMode == GAMEMODE_SURVIVAL ||
		g_iGameMode == GAMEMODE_VERSUS_SURVIVAL)
		return true;
	
	// Get the current map from the game
	char strCurrentMap[32];
	GetCurrentMap(strCurrentMap,32);

	// Run through all the maps, if the current map is a last campaign map, return true
	for (int iMapIndex = g_iMapsIndexStartForCurrentGameMode; iMapIndex <= g_iMapsIndexEndForCurrentGameMode; iMapIndex++)
		if (StrEqual(strCurrentMap, g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_NAME_END], false) == true)
			return true;
	
	return false;
}

// Check that the map index corresponds to an actual valid map
bool IsMapIndexValid(int iMapIndex)
{
	if (iMapIndex < 0 || IsMapValid(g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_NAME_START]) == false)
		return false;
	
	return true;
}

// This is for the infinite game modes, namely coop and survival.
// It will keep track of how many rounds end took place so it 
// knows when to force a switch to the next campaign/map
int IncrementRoundEndCounter()
{
	// Ensure that this is not fired multiple times for the same round
	if (g_bCanIncrementRoundEndCounter == false)
		return g_iRoundEndCounter;
	
	g_bCanIncrementRoundEndCounter = false;
	CreateTimer(REALLOW_ROUND_END_INCREMENT_DELAY, TimerResetCanIncrementRoundEndCounter, _, TIMER_FLAG_NO_MAPCHANGE);

	return ++g_iRoundEndCounter;
}

// This is required because the RoundEnd can fire multiple times
Action TimerResetCanIncrementRoundEndCounter(Handle timer, int iData)
{
	g_bCanIncrementRoundEndCounter = true;

	return Plugin_Stop;
}

// Find the current Game Mode and store it into this plugin
// Returns true if the game mode has changed.
bool FindGameMode()
{
	// This will say if the game mode has changed since last time it was checked
	int iOldGameMode = g_iGameMode;

	// Get the gamemode string from the game
	char strGameMode[20];
	GetConVarString(FindConVar("mp_gamemode"), strGameMode, sizeof(strGameMode));
	
	// Set the global gamemode int for this plugin
	if(StrEqual(strGameMode, "coop"))
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "realism"))
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode,"versus"))
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "teamversus"))
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "scavenge"))
		g_iGameMode = GAMEMODE_SCAVENGE;
	else if(StrEqual(strGameMode, "teamscavenge"))
		g_iGameMode = GAMEMODE_SCAVENGE;
	else if(StrEqual(strGameMode, "survival"))
		g_iGameMode = GAMEMODE_SURVIVAL;
	else if(StrEqual(strGameMode, "mutation1"))		//Last Man On Earth
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation2"))		//Headshot!
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation3"))		//Bleed Out
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation4"))		//Hard Eight
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation5"))		//Four Swordsmen
		g_iGameMode = GAMEMODE_COOP;
	//else if(StrEqual(strGameMode, "mutation6"))	//Nothing here
	//	g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation7"))		//Chainsaw Massacre
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation8"))		//Ironman
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation9"))		//Last Gnome On Earth
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation10"))	//Room For One
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation11"))	//Healthpackalypse!
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation12"))	//Realism Versus
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation13"))	//Follow the Liter
		g_iGameMode = GAMEMODE_SCAVENGE;
	else if(StrEqual(strGameMode, "mutation14"))	//Gib Fest
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation15"))	//Versus Survival
		g_iGameMode = GAMEMODE_VERSUS_SURVIVAL;
	else if(StrEqual(strGameMode, "mutation16"))	//Hunting Party
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation17"))	//Lone Gunman
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation18"))	//Bleed Out Versus
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation19"))	//Taaannnkk!
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation20"))	//Healing Gnome
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "community1"))	//Special Delivery
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "community2"))	//Flu Season
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "community3"))	//Riding My Survivor
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "community4"))	//Nightmare
		g_iGameMode = GAMEMODE_SURVIVAL;
	else if(StrEqual(strGameMode, "community5"))	//Death's Door
		g_iGameMode = GAMEMODE_COOP;
	else
		g_iGameMode = GAMEMODE_UNKNOWN;

	// This will say if the game mode has changed since last time it was checked
	if (iOldGameMode == g_iGameMode)
		return false;

	return true;
}