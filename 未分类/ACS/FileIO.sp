// Create a new map list file based on the default map names in MapNames.sp
void CreateNewMapListFileIfDoesNotExist()
{
	SetACSMapListFilePath();

	// Make sure the file doesn't already
	// exist before overwriting it
	if (FileExists(g_strMapListFilePath))
		return;

	WriteDefaultMapListToFile();

	// Store the file last updated timestamp value to check if its been modified later
	g_iUsedMapListFileModifiedTimeStamp = GetACSMapListFileTimeStampValue();
}

// Set up the path that the map list config file will be using
void SetACSMapListFilePath()
{	
	BuildPath(Path_SM, g_strMapListFilePath, PLATFORM_MAX_PATH, ACS_MAP_LIST_FILE_PATH);
}

// Returns a time stamp for the last time the ACS Map List file was modified
int GetACSMapListFileTimeStampValue()
{
	return GetFileTime(g_strMapListFilePath, FileTime_LastChange);
}

// Create the map list config file and populate it with the default
// values specified inside of the map list array in MapNames.sp
void WriteDefaultMapListToFile()
{
	// Check that the path is set up
	if (strlen(g_strMapListFilePath) < 1)
	{
		LogError("ACS Error: g_strMapListFilePath not set!");
		return;
	}

	// Open the file, if failed to do so, close the handle
	Handle hFile = OpenFile(g_strMapListFilePath, "w");
	if (hFile == null)
	{
		LogError("ACS Error: Unable to open and write to map list file path!");
		CloseHandle(hFile);
		return;
	}

	// Write the ACS config file description and column header info
	WriteConfigFileDescriptionInfo(hFile);

	// Loop through the default map list array and build the strings
	// to write each line into the the map list config file
	char strBuffer[256], strCurrentGameMode[64];
	strCurrentGameMode = "";
	for (int i=0; i < sizeof(g_strDefaultMapListArray); i++)
	{
		strBuffer = "";

		for(int j=0; j < MAP_LIST_COLUMN_COUNT; j++)
		{
			// Detect a game mode change and add a comment
			if (j == MAP_LIST_COLUMN_GAMEMODE && 
				StrEqual(strCurrentGameMode, g_strDefaultMapListArray[i][j]) == false)
			{
				strCurrentGameMode = g_strDefaultMapListArray[i][j];
				WriteFileLine(hFile, "\n// %s MAPS", strCurrentGameMode);
			}

			// Add the column to the buffer
			StrCat(strBuffer, sizeof(strBuffer), g_strDefaultMapListArray[i][j]);

			// Add the comma delimiter only if it there are more items
			if (j != MAP_LIST_COLUMN_COUNT - 1 &&
				(j == MAP_LIST_COLUMN_MAP_NAME_START && 
				strlen(g_strDefaultMapListArray[i][MAP_LIST_COLUMN_MAP_NAME_END]) == 0) == false)
				StrCat(strBuffer, sizeof(strBuffer), ", ");
		}

		WriteFileLine(hFile, strBuffer);
	}
	
	// Close the handle to the file
	CloseHandle(hFile);
}

void SetupMapListArrayFromFile()
{
	SetACSMapListFilePath();

	// Check to make sure the file doesn't already exist
	if (FileExists(g_strMapListFilePath) == false)
		return;

	// Clear out any previous maps from the storage array
	EmptyTheCurrentMapListArrayInfo();

	// Open the file
	Handle hFile = OpenFile(g_strMapListFilePath, "rt");
	if (hFile == null)
	{
		LogError("ACS Error: Unable to open and read map list file path!");
		CloseHandle(hFile);
		return;
	}

	// Read each line from the file and store its info into the global map list array
	char strLine[100 * MAP_LIST_COLUMN_COUNT], strLineItems[MAP_LIST_COLUMN_COUNT][64];
	int iCurrentArrayRow;
	while(IsEndOfFile(hFile) == false && ReadFileLine(hFile, strLine, sizeof(strLine)))
	{
		// Remove any white space
		TrimString(strLine);

		// Ensure there is some data before going further with this line
		if (strlen(strLine) <= 2)
			continue;

		// If the line is a comment then return
		if (strLine[0] == '/' && strLine[1] == '/')
			continue;

		// Reset all the strings
		for (int iItemIndex = 0; iItemIndex < MAP_LIST_COLUMN_COUNT; iItemIndex++)
			strLineItems[iItemIndex] = "";
		
		// Split each item in the line to separate each column
		ExplodeString(strLine, ",", strLineItems, sizeof(strLineItems), sizeof(strLineItems[]));

		// Remove any white space from all the columns
		for (int iItemIndex = 0; iItemIndex < MAP_LIST_COLUMN_COUNT; iItemIndex++)
			TrimString(strLineItems[iItemIndex]);

		// If there are not enough delimited data columns for the line skip it
		if (strlen(strLineItems[MAP_LIST_COLUMN_GAMEMODE]) <= 1 || 
			strlen(strLineItems[MAP_LIST_COLUMN_MAP_DESCRIPTION]) <= 1 || 
			strlen(strLineItems[MAP_LIST_COLUMN_MAP_NAME_START]) <= 1)
			continue;

		// If there is no specified end map, set this columns value to the start map's value
		if (strlen(strLineItems[MAP_LIST_COLUMN_MAP_NAME_END]) <= 1)
			strcopy(strLineItems[MAP_LIST_COLUMN_MAP_NAME_END], 
					sizeof(strLineItems[]),
					strLineItems[MAP_LIST_COLUMN_MAP_NAME_START]);

		// Store all the lines map list info into the global array list
		for (int iItemIndex = 0; iItemIndex < MAP_LIST_COLUMN_COUNT; iItemIndex++)
			g_strMapListArray[iCurrentArrayRow][iItemIndex] = strLineItems[iItemIndex];

		// PrintToServer("g_strMapListArray: %s		%s		%s		%s", g_strMapListArray[iCurrentArrayRow][0], g_strMapListArray[iCurrentArrayRow][1], g_strMapListArray[iCurrentArrayRow][2], g_strMapListArray[iCurrentArrayRow][3]);

		iCurrentArrayRow++;
	}

	// Close the handle to the file
	CloseHandle(hFile);

	// Store the file last updated timestamp value to check if its been modified later
	g_iUsedMapListFileModifiedTimeStamp = GetACSMapListFileTimeStampValue();

	// For debugging the config file
	PrintTheCurrentMapListArrayInfo();
}

// Prints the actual array to the console
// This is useful when editing the map list config file
public void PrintTheCurrentMapListArrayInfo()
{
	PrintToServer("\n =======================================================================================");
	PrintToServer("  ACS %s Maps Listing", PLUGIN_VERSION);
	PrintToServer("  Config Location: %s", g_strMapListFilePath);
	PrintToServer(" =======================================================================================");

	char strBuffer[256];
	for (int i=0; i < sizeof(g_strMapListArray); i++)
	{
		strBuffer = "";

		for(int j=0; j < sizeof(g_strMapListArray[]); j++)
		{
			// Skip of theres no data for this column
			if (strlen(g_strMapListArray[i][j]) == 0)
				continue;

			StrCat(strBuffer, sizeof(strBuffer), g_strMapListArray[i][j]);
			if(j != sizeof(g_strMapListArray[]) - 1)
				StrCat(strBuffer, sizeof(strBuffer), ", ");
		}

		// Skip of theres no data for this row
		if (strlen(strBuffer) == 0)
			continue;

		PrintToServer(" %3i: %s", i, strBuffer);
	}

	PrintToServer(" =======================================================================================\n");
}

// Remove all values from the array to have a fresh start when recreating it
void EmptyTheCurrentMapListArrayInfo()
{
	for (int i=0; i < sizeof(g_strMapListArray); i++)
		for(int j=0; j < sizeof(g_strMapListArray[]); j++)
			g_strMapListArray[i][j][0] = 0;
}

// This sets up the global index ranges
// These ranges used in several areas mainly to minimize the search scope 
// when finding map indexes as well as to know what map comes next for the 
// game mode when cycling back to the first
void SetCurrentMapIndexRangeForCurrentGameMode()
{
	// Reset the values
	g_iMapsIndexStartForCurrentGameMode = -1;
	g_iMapsIndexEndForCurrentGameMode = -1;

	for (int i=0; i < sizeof(g_strMapListArray); i++)
	{
		// Ensure the game mode for this index in the map list array matches the current one, or skip this one
		if (StrEqual(g_strMapListArray[i][MAP_LIST_COLUMN_GAMEMODE], g_strGameModeString[g_iGameMode], false) == false)
			continue;

		// Set the Start index, only if not already set
		if (g_iMapsIndexStartForCurrentGameMode == -1)
			g_iMapsIndexStartForCurrentGameMode = i;
		
		// Keep setting this because each time will be higher
		g_iMapsIndexEndForCurrentGameMode = i;
	}
}