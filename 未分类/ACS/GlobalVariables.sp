// This is the location ACS looks for the map list config file
#define ACS_MAP_LIST_FILE_PATH      "configs/acs_map_list.txt"
// The currently know timestamp value for the map list file
int g_iUsedMapListFileModifiedTimeStamp = -1;

// Define Game Modes
int g_iGameMode = -1;   //Store the gamemode
#define GAMEMODE_UNKNOWN	        -1
#define GAMEMODE_COOP 		        0
#define GAMEMODE_VERSUS 	        1
#define GAMEMODE_SCAVENGE 	        2
#define GAMEMODE_SURVIVAL 	        3
#define GAMEMODE_VERSUS_SURVIVAL 	4

// Game Mode Map List Strings (corresponds to the above game modes order)
char g_strGameModeString[][] = {
    "CAMPAIGN", //GAMEMODE_COOP
    "CAMPAIGN", //GAMEMODE_VERSUS
    "SCAVENGE", //GAMEMODE_SCAVENGE
    "SURVIVAL", //GAMEMODE_SURVIVAL
    "SURVIVAL"  //GAMEMODE_VERSUS_SURVIVAL
};

// Define the wait time after round before changing to the next map in each game mode
// These must line up the game modes array
float g_fWaitTimeBeforeSwitch[] = {
    5.0,    // GAMEMODE_COOP
    3.0,    // GAMEMODE_VERSUS
    8.0,    // GAMEMODE_SCAVENGE
    5.0,    // GAMEMODE_SURVIVAL
    5.0     // GAMEMODE_VERSUS_SURVIVAL
};

// Miscellaneous config
#define REALLOW_ACS_MAP_CHANGE_DELAY        20.0    // Seconds, used to prevent multiple triggers for 1 round end
#define REALLOW_ROUND_END_INCREMENT_DELAY   20.0    // Seconds, used to prevent multiple triggers for 1 round end

#define SOUND_NEW_VOTE_START	"ui/Beep_SynthTone01.wav"
#define SOUND_NEW_VOTE_WINNER	"ui/alert_clink.wav"

//Global Variables
int g_iRoundEndCounter;				    // Round end event counter for versus
bool g_bStopACSChangeMap;               // 
bool g_bCanIncrementRoundEndCounter;    // Prevents incrementing the round end counter twice from multiple event triggers
int g_iCoopFinaleFailureCount;		    // Number of times the Survivors have lost the current finale
int g_iMaxCoopFinaleFailures = 4;	    // Amount of times Survivors can fail before ACS switches in coop
bool g_bFinaleWon;				        // Indicates whether a finale has be beaten or not
char g_strMapListFilePath[256]  = "";   // Path of the map file list

// Map List Rotation For All GameModes
#define MAX_TOTAL_MAP_COUNT                 200 // Defines how many maps can be added. Higher values increase memory footprint
#define MAP_LIST_COLUMN_COUNT               4
char g_strMapListArray[MAX_TOTAL_MAP_COUNT][MAP_LIST_COLUMN_COUNT][64];
// Map List Columns
#define MAP_LIST_COLUMN_GAMEMODE            0
#define MAP_LIST_COLUMN_MAP_DESCRIPTION     1
#define MAP_LIST_COLUMN_MAP_NAME_START      2
#define MAP_LIST_COLUMN_MAP_NAME_END        3
// Keep track of indexes that are relevant to the current game mode
int g_iMapsIndexStartForCurrentGameMode;
int g_iMapsIndexEndForCurrentGameMode;

// Map and Advertising display modes
#define DISPLAY_MODE_DISABLED	0
#define DISPLAY_MODE_HINT		1
#define DISPLAY_MODE_CHAT		2
#define DISPLAY_MODE_MENU		3

// Voting Variables
bool g_bVotingEnabled = true;						    // Tells if the voting system is on
int g_iVotingAdDisplayMode = DISPLAY_MODE_MENU;			// The way to advertise the voting system
float g_fVotingAdDelayTime = 1.0;						// Time to wait before showing advertising
bool g_bVoteWinnerSoundEnabled = true;					// Sound plays when vote winner changes
int g_iNextMapAdDisplayMode = DISPLAY_MODE_HINT;		// The way to advertise the next map
float g_fNextMapAdInterval = 600.0;						// Interval for ACS next map advertisement
bool g_bClientShownVoteAd[MAXPLAYERS + 1];				// If the client has seen the ad already
bool g_bClientVoted[MAXPLAYERS + 1];					// If the client has voted on a map
int g_iClientVote[MAXPLAYERS + 1];						// The value of the clients vote
int g_iWinningMapIndex;									// Winning map/campaign's index
int g_iWinningMapVotes;									// Winning map/campaign's number of votes

// Console Variables (CVars)
Handle g_hCVar_VotingEnabled			= INVALID_HANDLE;
Handle g_hCVar_VoteWinnerSoundEnabled	= INVALID_HANDLE;
Handle g_hCVar_VotingAdMode				= INVALID_HANDLE;
Handle g_hCVar_VotingAdDelayTime		= INVALID_HANDLE;
Handle g_hCVar_NextMapAdMode			= INVALID_HANDLE;
Handle g_hCVar_NextMapAdInterval		= INVALID_HANDLE;
Handle g_hCVar_MaxFinaleFailures		= INVALID_HANDLE;