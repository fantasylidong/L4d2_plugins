/*======================================================================================
#################                     E V E N T S                      #################
======================================================================================*/

void SetUpEvents()
{
    // Hook the game events
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("finale_win", Event_FinaleWin);
	HookEvent("player_disconnect", Event_PlayerDisconnect);

	// This one is important. It is used to intercept the end of game vote panel
	// as well as capture when the map should be switched for all the game modes other
	// than Coop and Survival.
	// https://wiki.alliedmods.net/User_messages was very helpful here
	HookUserMessage(GetUserMessageId("PZEndGamePanelMsg"), OnPZEndGamePanelMsg, true);
	// Hook the Return to Lobby events
	HookUserMessage(GetUserMessageId("VotePass"), OnDisconnectToLobby, true);
	HookUserMessage(GetUserMessageId("DisconnectToLobby"), OnDisconnectToLobby, true);
}

public void OnMapStart()
{
	//Execute config file
	char strFileName[64];
	Format(strFileName, sizeof(strFileName), "Automatic_Campaign_Switcher_%s", PLUGIN_VERSION);
	AutoExecConfig(true, strFileName);

	// Check if the Maps List File has changed, if so reload it into the Map List Array
	int iNewMapListFileTimeStamp = GetACSMapListFileTimeStampValue();
	if (iNewMapListFileTimeStamp > 0 && 
		iNewMapListFileTimeStamp > g_iUsedMapListFileModifiedTimeStamp)
		SetupMapListArrayFromFile();
	
	// Set the game mode
	bool bGameModeChanged = FindGameMode();

	// If the game mode has changed, it needs to adjust the index range to match 
	// the game mode so that other functions know which maps to look at.
	if (bGameModeChanged == true)
		SetCurrentMapIndexRangeForCurrentGameMode();
	
	// Precache models (This fixes missing Witch model on "The Passing")
	if(IsModelPrecached("models/infected/witch.mdl") == false)
		PrecacheModel("models/infected/witch.mdl");
	if(IsModelPrecached("models/infected/witch_bride.mdl") == false)
		PrecacheModel("models/infected/witch_bride.mdl");

	// Precache sounds
	PrecacheSound(SOUND_NEW_VOTE_START);
	PrecacheSound(SOUND_NEW_VOTE_WINNER);
	
	g_iRoundEndCounter = 0;			//Reset the round end counter on every map start
	g_bCanIncrementRoundEndCounter = true;
	g_iCoopFinaleFailureCount = 0;	//Reset the amount of Survivor failures
	g_bFinaleWon = false;			//Reset the finale won variable
	ResetAllVotes();				//Reset every player's vote
}

//Event fired when the Survivors leave the start area
public Action Event_PlayerLeftStartArea(Handle hEvent, const char[] strName, bool bDontBroadcast)
{
	if(g_bVotingEnabled == true && OnFinaleOrScavengeOrSurvivalMap() == true)
		CreateTimer(g_fVotingAdDelayTime, Timer_DisplayVoteAdToAll, _, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

//Event fired when the Round Ends
public Action Event_RoundEnd(Handle hEvent, const char[] strName, bool bDontBroadcast)
{
	//Check to see if on a finale map, if so change to the next campaign after two rounds
	switch (g_iGameMode)
	{
		//If in Coop and on a finale, check to see if the survivors have lost the max amount of times
		case GAMEMODE_COOP:
		{
			if (OnFinaleOrScavengeOrSurvivalMap() == true &&
				g_iMaxCoopFinaleFailures > 0 && 
				g_bFinaleWon == false &&
				++g_iCoopFinaleFailureCount >= g_iMaxCoopFinaleFailures)
				ChangeMapIfNeeded();
		}
		//If in Survival, check to see if round ends have reached the max amount of times
		case GAMEMODE_SURVIVAL:
		{
			// This uses round end counter to check the rounds
			// This can be fired multiple times, and this function helps handle that
			if (IncrementRoundEndCounter() >= 2)	
				ChangeMapIfNeeded();
		}
	}
	return Plugin_Continue;
}

//Event fired when a finale is won
public Action Event_FinaleWin(Handle hEvent, const char[] strName, bool bDontBroadcast)
{
	g_bFinaleWon = true;	//This is used so that the finale does not switch twice if this event
							//happens to land on a max failure count as well as this
	
	//Change to the next campaign
	if(g_iGameMode == GAMEMODE_COOP)
		ChangeMapIfNeeded();
	
	return Plugin_Continue;
}

//Event fired when a player disconnects from the server
public Action Event_PlayerDisconnect(Handle hEvent, const char[] strName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(iClient	< 1)
		return Plugin_Continue;
	
	//Reset the client's votes
	g_bClientVoted[iClient] = false;
	g_iClientVote[iClient] = -1;
	
	//Check to see if there is a new vote winner
	SetTheCurrentVoteWinner();
	
	return Plugin_Continue;
}


// This event is responsible for most of the map transitions in every game mode except 
// for Coop and Survival where it is not triggered because they can continue forever.
// It also intercepts the vote to play with the team again or return to lobby
public Action OnPZEndGamePanelMsg(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	// Only change the map one time, this is attached to a 
	// cool down timer after the map was just changed by ACS
	if (g_bStopACSChangeMap == true)
		return Plugin_Handled;

	ChangeMapIfNeeded();

	return Plugin_Handled;
}

// This function was written by MasterMind420 preventing the Return to Lobby issue
public Action OnDisconnectToLobby(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	static bool bAllowDisconnect;

	char sBuffer[64];
	BfReadString(bf, sBuffer, sizeof(sBuffer));

	if (StrContains(sBuffer, "vote_passed_return_to_lobby") > -1)
	{
		bAllowDisconnect = true;
		return Plugin_Continue;
	}
	else if (StrContains(sBuffer, "vote_passed") > -1)
		return Plugin_Continue;

	if (bAllowDisconnect)
	{
		bAllowDisconnect = false;
		return Plugin_Continue;
	}

	return Plugin_Handled;
}