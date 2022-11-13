/*======================================================================================
#################             A C S   C H A N G E   M A P              #################
======================================================================================*/

// Checks conditions to see if the map needs to be changed by ACS now
// If the map needs to be changed this will also change it
void ChangeMapIfNeeded()
{
	// Ensure the game mode has been set to a valid one before continuing
	if (IsGameModeValid(g_iGameMode) == false)
		return;
	
	// This is required because the Events can fire multiple times
	g_bStopACSChangeMap = true;
	CreateTimer(REALLOW_ACS_MAP_CHANGE_DELAY, TimerResetCanACSChangeMap);

	// Check to see if someone voted for a map, if so, then change to the winning map
	if (g_bVotingEnabled == true && g_iWinningMapVotes > 0 && g_iWinningMapIndex >= 0)
	{
		SetUpMapChange(g_iWinningMapIndex);
		return;
	}
	
	// If no player has chosen a map by voting, then set up the automatic map rotation cycle map
	SetUpMapChange(FindNextMapIndex());
}

// Set everything up for a delayed campaign/map change
void SetUpMapChange(int iMapIndex)
{
	// Ensure its a valid map
	if (IsMapIndexValid(iMapIndex) == false)
	{
		LogError("ACS Error: SetUpMapChange -> Invalid Map Index! %i", iMapIndex);
		return;
	}

	// Print Loading Message, must delay or it wont work with OnPZEndGamePanelMsg
	CreateTimer(0.1, Timer_PrintChangeMapMessages, iMapIndex);
	
	// Delayed call to change the map
	CreateTimer(g_fWaitTimeBeforeSwitch[g_iGameMode], Timer_ChangeMap, iMapIndex);
}

// Inform Server and Players that ACS is changing the Map
Action Timer_PrintChangeMapMessages(Handle timer, int iMapIndex)
{
	PrintToServer("\n\n[ACS] Loading %s\n\n", g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_DESCRIPTION]);
	PrintToChatAll("\x03[ACS] \x05Loading \x04%s", g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_DESCRIPTION]);

	return Plugin_Stop;
}

// Change campaign using its index
Action Timer_ChangeMap(Handle timer, int iMapIndex)
{
	ServerCommand("changelevel %s", g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_NAME_START]);

	return Plugin_Stop;
}

// This is required because the Events can fire multiple times
Action TimerResetCanACSChangeMap(Handle timer, int iData)
{
	g_bStopACSChangeMap = false;

	return Plugin_Stop;
}

// Finds the map list array index of the map the players are currently on
int FindCurrentMapIndex()
{
	if (g_iMapsIndexStartForCurrentGameMode == -1)
		return -1;

	// Get the current map from the game
	char strCurrentMap[32];
	GetCurrentMap(strCurrentMap, 32);	

	// Go through all maps and to find which map index it is on
	for(int iMapIndex = g_iMapsIndexStartForCurrentGameMode; iMapIndex <= g_iMapsIndexEndForCurrentGameMode; iMapIndex++)
		if (StrEqual(g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_NAME_END], strCurrentMap, false) == true)
			return iMapIndex;

	return -1;
}

// Finds the next map index item to know what map comes after the existing one
int FindNextMapIndex()
{
	int iCurrentMapIndex = FindCurrentMapIndex();
	if (iCurrentMapIndex == -1)
		return -1;

	int iNextCampaignMapIndex = iCurrentMapIndex + 1;				// Get the next campaign map index
	if (iNextCampaignMapIndex > g_iMapsIndexEndForCurrentGameMode)	// Check to see if its the end of the array. If so,
		iNextCampaignMapIndex = 0;									// set it to the first map index fro the game mode

	return iNextCampaignMapIndex;
}