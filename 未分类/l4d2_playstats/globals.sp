#if defined _l4d2_playstats_globals_included
 #endinput
#endif

#define _l4d2_playstats_globals_included

#include <sourcemod>

new     bool:   g_bLateLoad             = false;
new     bool:   g_bFirstLoadDone        = false;                                        // true after first onMapStart
new     bool:   g_bLoadSkipDone         = false;                                        // true after skipping the _resetnextmap for stats

new     bool:   g_bLGOAvailable         = false;                                        // whether lgofnoc is loaded
new     bool:   g_bReadyUpAvailable     = false;
new     bool:   g_bPauseAvailable       = false;
new     bool:   g_bSkillDetectLoaded    = false;
new     bool:   g_bSystem2Loaded        = false;
new     bool:   g_bDiscordScoreboardAvailable = false;

new     bool:   g_bCMTActive            = false;                                        // whether custom map transitions is running a mapset
new     bool:   g_bCMTSwapped           = false;                                        // whether A/B teams have been swapped

new     bool:   g_bModeCampaign         = false;
new     bool:   g_bModeScavenge         = false;

new     Handle: g_hCookiePrint          = INVALID_HANDLE;
new             g_iCookieValue          [MAXPLAYERS+1];                                 // if a cookie is set for a client, this is its value

new     Handle: g_hCvarDatabaseConfig   = INVALID_HANDLE;
new     Handle: g_hCvarDebug            = INVALID_HANDLE;
new     Handle: g_hCvarMVPBrevityFlags  = INVALID_HANDLE;
new     Handle: g_hCvarAutoPrintVs      = INVALID_HANDLE;
new     Handle: g_hCvarAutoPrintCoop    = INVALID_HANDLE;
new     Handle: g_hCvarShowBots         = INVALID_HANDLE;
new     Handle: g_hCvarDetailPercent    = INVALID_HANDLE;
new     Handle: g_hCvarWriteStats       = INVALID_HANDLE;
new     Handle: g_hCvarSkipMap          = INVALID_HANDLE;
new     Handle: g_hCvarCustomConfig     = INVALID_HANDLE;

new     bool:   g_bGameStarted          = false;
new     bool:   g_bInRound              = false;
new     bool:   g_bTeamChanged          = false;                                        // to only do a teamcheck if a check is not already pending
new     bool:   g_bTankInGame           = false;
new     bool:   g_bPlayersLeftStart     = false;
new     bool:   g_bSecondHalf           = false;                                        // second roundhalf in a versus round
new     bool:   g_bFailedPrevious       = false;                                        // whether the previous attempt was a failed campaign mode round
new             g_iRound                = 0;
new             g_iCurTeam              = LTEAM_A;                                      // current logical team
new             g_iTeamSize             = 4;
new             g_iLastRoundEndPrint    = 0;                                            // when the last automatic print was shown
new             g_iSurvived             [2];                                            // just for stats: how many survivors that round (0 = wipe)

new     bool:   g_bPaused               = false;                                        // whether paused with pause.smx
new             g_iPauseStart           = 0;                                            // time the current pause started

new             g_iScores               [2];                                            // scores for both teams, as currently known
new             g_iFirstScoresSet       [3];                                            // scores when first set for a new map (index 3 = 0 if not yet set)

new             g_iBoomedBy             [MAXPLAYERS+1];                                 // if someone is boomed, by whom?

new             g_iPlayerIndexSorted    [MAXSORTS][MAXTRACKED];                         // used to create a sorted list
new             g_iPlayerSortedUseTeam  [MAXSORTS][MAXTRACKED];                         // after sorting: which team to use as the survivor team for player
new             g_iPlayerRoundTeam      [3][MAXTRACKED];                                // which team is the player 0 = A, 1 = B, -1 = no team; [2] = current survivor round; [0]/[1] = team A / B (anyone who was ever on it)
new             g_iPlayerGameTeam       [2][MAXTRACKED];                                // for entire game for team A / B if the player was ever on it

new             g_strGameData           [strGameData];
new             g_strAllRoundData       [2][strRoundData];                              // rounddata for ALL rounds, per team
new             g_strRoundData          [MAXROUNDS][2][strRoundData];                   // rounddata per game round, per team
new             g_strPlayerData         [MAXTRACKED][strPlayerData];
new             g_strRoundPlayerData    [MAXTRACKED][2][strPlayerData];                 // player data per team
new             g_strPlayerInfData      [MAXTRACKED][strPlayerData];
new             g_strRoundPlayerInfData [MAXTRACKED][2][strPlayerData];                 // player data for infected action per team (team is survivor team! -- when infected player was on opposite team)

new             g_strRoundPvPFFData     [MAXTRACKED][2][MAXTRACKED];                    // pvp ff data per team
new             g_strRoundPvPInfDmgData    [MAXTRACKED][2][MAXTRACKED];                    // pvp dmg data per team

new     Handle: g_hTriePlayers                                      = INVALID_HANDLE;   // trie for getting player index
new     Handle: g_hTrieWeapons                                      = INVALID_HANDLE;   // trie for getting weapon type (from classname)
new     Handle: g_hTrieEntityCreated                                = INVALID_HANDLE;   // trie for getting classname of entity created

new     Float:  g_fHighestFlow          [4];                                            // highest flow a survivor was seen to have in the round (per character 0-3)
new     String: g_sPlayerName           [MAXTRACKED][MAXNAME];
new     String: g_sPlayerNameSafe       [MAXTRACKED][MAXNAME];                          // version of name without unicode characters
new     String: g_sPlayerId             [MAXTRACKED][32];                               // steam id
new     String: g_sMapName              [MAXROUNDS][MAXMAP];
new     String: g_sConfigName           [MAXMAP];
new             g_iPlayers                                          = 0;


new     String: g_sConsoleBuf           [MAXCHUNKS][CONBUFSIZELARGE];
new             g_iConsoleBufChunks                                 = 0;

new     String: g_sStatsFile            [MAXNAME];                                      // name for the statsfile we should write to
new     Handle: g_hStatsFile;                                                           // handle for a statsfile that we write tables to

new String:errorBuffer[255];
new Handle:db = INVALID_HANDLE;
new Handle:hRoundStmt = INVALID_HANDLE;
new Handle:hSurvivorStmt = INVALID_HANDLE;
new Handle:hInfectedStmt = INVALID_HANDLE;
new Handle:hMatchStmt = INVALID_HANDLE;
new Handle:hPvPFFStmt = INVALID_HANDLE;
new Handle:hPvPInfDmgStmt = INVALID_HANDLE;
new String:g_sDatabaseConfig[64];