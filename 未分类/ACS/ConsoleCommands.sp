/*======================================================================================
################            C O N S O L E   C O M M A N D S             ################
======================================================================================*/

void SetupConsoleCommands()
{
    //Register custom console commands
	RegConsoleCmd("mapvote", 	MapVote);
	RegConsoleCmd("votemap", 	MapVote);
	RegConsoleCmd("votemaps", 	MapVote);
	RegConsoleCmd("acs", 		MapVote);
	RegConsoleCmd("acsvote", 	MapVote);
	RegConsoleCmd("voteacs", 	MapVote);
	RegConsoleCmd("mapvotes", 	DisplayCurrentVotes);
	RegConsoleCmd("acsvotes", 	DisplayCurrentVotes);
	RegConsoleCmd("votesacs", 	DisplayCurrentVotes);
	RegConsoleCmd("votes", 		DisplayCurrentVotes);
}

// Command that a player can use to vote/revote for a map/campaign
Action MapVote(int iClient, int args)
{
	if (g_bVotingEnabled == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05Voting has been disabled on this server.");
		return;
	}
	
	if (OnFinaleOrScavengeOrSurvivalMap() == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05Voting is only enabled on a Scavenge, Survival, or Finale maps.");
		return;
	}
	
	// Open the vote menu for the client if they aren't using the server console
	if (iClient < 1)
		PrintToServer("You cannot vote for a map from the server console, use the in-game chat");
	else
		VoteMenuDraw(iClient);
}

// Command that a player can use to see the total votes for all maps/campaigns
Action DisplayCurrentVotes(int iClient, int args)
{
	if (g_bVotingEnabled == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05Voting has been disabled on this server.");
		return;
	}
	
	if (OnFinaleOrScavengeOrSurvivalMap() == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05Voting is only enabled on a Scavenge, Survival, or Finale maps.");
		return;
	}
	
	// Display to the client the current winning map
	if(g_iWinningMapIndex > -1)
		PrintToChat(iClient, "\x03[ACS] \x05Currently winning the vote: \x04%s", 
			g_strMapListArray[g_iWinningMapIndex][MAP_LIST_COLUMN_MAP_DESCRIPTION]);
	else
		PrintToChat(iClient, "\x03[ACS] \x05No one has voted yet.");
	
	// Loop through all maps and display the ones that have votes
	int[] iMapVotes = new int[MAX_TOTAL_MAP_COUNT];
	for(int iMapIndex = g_iMapsIndexStartForCurrentGameMode; iMapIndex <= g_iMapsIndexEndForCurrentGameMode; iMapIndex++)
	{
		iMapVotes[iMapIndex] = 0;
		
		// Tally votes for the current map
		for(int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			if(g_iClientVote[iPlayer] == iMapIndex)
				iMapVotes[iMapIndex]++;
		
		// Display this particular map and its amount of votes it has to the client
		if(iMapVotes[iMapIndex] > 0)
			PrintToChat(iClient, "\x04          %s: \x05%i vote%s",
			g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_DESCRIPTION], 
			iMapVotes[iMapIndex],
			iMapVotes[iMapIndex] == 1 ? "" : "s");
	}
}