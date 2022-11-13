/*======================================================================================
#################              V O T I N G   S Y S T E M               #################
======================================================================================*/

/*======================================================================================
###############                   V O T E   M E N U                       ##############
======================================================================================*/

// Timer to show the menu to the players if they have not voted yet
public Action Timer_DisplayVoteAdToAll(Handle timer, int iData)
{
	if (g_bVotingEnabled == false || OnFinaleOrScavengeOrSurvivalMap() == false)
		return Plugin_Stop;
	
	// Loop through each player and show them the ACS advertisement based on the display mode
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(g_bClientShownVoteAd[iClient] == false && g_bClientVoted[iClient] == false && IsClientInGame(iClient) == true && IsFakeClient(iClient) == false)
		{
			switch(g_iVotingAdDisplayMode)
			{
				case DISPLAY_MODE_MENU: VoteMenuDraw(iClient);
				case DISPLAY_MODE_HINT: PrintHintText(iClient, "To vote for the next map, type: !mapvote\nTo see all the votes, type: !mapvotes");
				case DISPLAY_MODE_CHAT: PrintToChat(iClient, "\x03[ACS] \x05To vote for the next map, type: \x04!mapvote\n           \x05To see all the votes, type: \x04!mapvotes");
			}
			
			g_bClientShownVoteAd[iClient] = true;
		}
	}
	
	return Plugin_Stop;
}

// Draw the menu for voting
public Action VoteMenuDraw(int iClient)
{
	if (iClient < 1 || 
		IsClientInGame(iClient) == false ||
		IsFakeClient(iClient) == true)
		return Plugin_Handled;
	
	// Create the menu
	Menu menu = CreateMenu(VoteMenuHandler);
	
	// Give the player the option of not choosing a map
	AddMenuItem(menu, "option1", "I Don't Care");
	
	// Set the wording to be more accurate based on game mode
	if(g_iGameMode == GAMEMODE_COOP || g_iGameMode == GAMEMODE_VERSUS)
		SetMenuTitle(menu, "Vote for the next campaign\n ");
	else
		SetMenuTitle(menu, "Vote for the next map\n ");

	// Populate the menu with the maps in rotation for the corresponding game mode index range
	for(int iMapIndex = g_iMapsIndexStartForCurrentGameMode; iMapIndex <= g_iMapsIndexEndForCurrentGameMode; iMapIndex++)
		AddMenuItem(menu, g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_DESCRIPTION], g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_DESCRIPTION]);
	
	// Add an exit button
	SetMenuExitButton(menu, true);
	
	// And finally, show the menu to the client
	DisplayMenu(menu, iClient, MENU_TIME_FOREVER);
	
	// Play a sound to indicate that the user can vote on a map
	EmitSoundToClient(iClient, SOUND_NEW_VOTE_START);
	
	return Plugin_Handled;
}

// Handle the menu selection the client chose for voting
public int VoteMenuHandler(Menu menu, MenuAction action, int iClient, int iItemNum)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if(action == MenuAction_Select) 
	{
		g_bClientVoted[iClient] = true;
		
		// Set the players current vote
		if(iItemNum == 0)
			g_iClientVote[iClient] = -1;
		else
			g_iClientVote[iClient] = g_iMapsIndexStartForCurrentGameMode + iItemNum - 1;
			
		// Check to see if theres a new winner to the vote
		SetTheCurrentVoteWinner();
		
		// Display the appropriate message to the voter
		if(iItemNum == 0)
			PrintHintText(iClient, "You did not vote.\nTo vote, type: !mapvote");
		else
			PrintHintText(iClient, 
				"You voted for %s.\n- To change your vote, type: !mapvote\n- To see all the votes, type: !mapvotes",
				g_strMapListArray[g_iMapsIndexStartForCurrentGameMode + iItemNum - 1][MAP_LIST_COLUMN_MAP_DESCRIPTION]);
	}
}

/*======================================================================================
#########       M I S C E L L A N E O U S   V O T E   F U N C T I O N S        #########
======================================================================================*/

// Resets all the votes for every player
void ResetAllVotes()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_bClientVoted[iClient] = false;
		g_iClientVote[iClient] = -1;
		
		// Reset so that the player can see the advertisement
		g_bClientShownVoteAd[iClient] = false;
	}
	
	// Reset the winning map to NULL
	g_iWinningMapIndex = -1;
	g_iWinningMapVotes = 0;
}

// Tally up all the votes and set the current winner
void SetTheCurrentVoteWinner()
{	
	// Store the current winner to see if there is a change
	int iOldWinningMapIndex = g_iWinningMapIndex;
	
	// Loop through all maps and get the highest voted map
	int[] iMapVotes = new int[MAX_TOTAL_MAP_COUNT];
	int iCurrentlyWinningMapVoteCounts = 0;
	bool bSomeoneHasVoted = false;
	
	for(int iMap = g_iMapsIndexStartForCurrentGameMode; iMap <= g_iMapsIndexEndForCurrentGameMode; iMap++)
	{
		iMapVotes[iMap] = 0;
		
		// Tally votes for the current map
		for(int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			if(g_iClientVote[iPlayer] == iMap)
				iMapVotes[iMap]++;
		
		// Check if there is at least one vote, if so set the bSomeoneHasVoted to true
		if(bSomeoneHasVoted == false && iMapVotes[iMap] > 0)
			bSomeoneHasVoted = true;
		
		// Check if the current map has more votes than the currently highest voted map
		if(iMapVotes[iMap] > iCurrentlyWinningMapVoteCounts)
		{
			iCurrentlyWinningMapVoteCounts = iMapVotes[iMap];
			
			g_iWinningMapIndex = iMap;
			g_iWinningMapVotes = iMapVotes[iMap];
		}
	}
	
	// If no one has voted, reset the winning map index and votes
	// This is only for if someone votes then their vote is removed
	if(bSomeoneHasVoted == false)
	{
		g_iWinningMapIndex = -1;
		g_iWinningMapVotes = 0;
	}
	
	// If the vote winner has changed then display the new winner to all the players
	if (g_iWinningMapIndex > -1 && iOldWinningMapIndex != g_iWinningMapIndex)
	{
		// Send sound notification to all players
		if(g_bVoteWinnerSoundEnabled == true)
			for(int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
				if(IsClientInGame(iPlayer) == true && IsFakeClient(iPlayer) == false)
					EmitSoundToClient(iPlayer, SOUND_NEW_VOTE_WINNER);
		
		// Show message to all the players of the new vote winner
		PrintToChatAll("\x03[ACS] \x04%s \x05is now winning the vote.", 
			g_strMapListArray[g_iWinningMapIndex][MAP_LIST_COLUMN_MAP_DESCRIPTION]);
	}
}