/*======================================================================================
#################            A C S   A D V E R T I S I N G             #################
======================================================================================*/

Action Timer_AdvertiseNextMap(Handle timer)
{
	//Display the ACS next map advertisement to everyone
	if(g_iNextMapAdDisplayMode != DISPLAY_MODE_DISABLED)
		DisplayNextMapToAll();
	
	return Plugin_Continue;
}

void DisplayNextMapToAll()
{
	// Find the next maps index to use to display the map to the players
	// If there is a winner to the vote get the winner index, otherwise get the next map index in rotation
	int iMapIndex = g_iWinningMapIndex >= 0 ? g_iWinningMapIndex : FindNextMapIndex();

	// Ensure its a valid map first
	// Note: Do not log an error because expected to fail on non-specified maps, like mid campaign maps
	if (IsMapIndexValid(iMapIndex) == false)
		return;

	// Display the message
	DisplayNextMapMessage(
		(g_iGameMode == GAMEMODE_COOP || g_iGameMode == GAMEMODE_VERSUS) ? 
		"The next campaign is currently " : 
		"The next map is currently ",
		g_strMapListArray[iMapIndex][MAP_LIST_COLUMN_MAP_DESCRIPTION]);
}

void DisplayNextMapMessage(const char[] strMessage, const char[] strMapName)
{
	//Display the map that is currently winning the vote to all the players using hint text
	if(g_iNextMapAdDisplayMode == DISPLAY_MODE_HINT)
		PrintHintTextToAll("%s%s", strMessage, strMapName);
	//Display the map that is currently winning the vote to all the players using chat text with colors
	else if(g_iNextMapAdDisplayMode == DISPLAY_MODE_CHAT)
		PrintToChatAll("\x03[ACS] \x05%s\x04%s", strMessage, strMapName);
}