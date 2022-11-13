#if defined _l4d2_playstats_game_included
 #endinput
#endif

#define _l4d2_playstats_game_included

#include <sourcemod>

/*
    Forwards from lgofnoc
    --------------------- */
public LGO_OnMatchModeStart( const String: sConfig[] ) {
    // ignore this map, match will start on next reload.
    g_bLoadSkipDone = false;
}

public OnConfigsExecuted() {
    g_iTeamSize = GetConVarInt( FindConVar("survivor_limit") );
    
    // currently loaded config?
    g_sConfigName = "";
    
    new Handle: tmpHandle = FindConVar("l4d_ready_cfg_name");
    if ( tmpHandle != INVALID_HANDLE ) {
        GetConVarString( tmpHandle, g_sConfigName, MAXMAP );
    }
    PrintDebug( 1, "OnConfigsExecuted %i", db == INVALID_HANDLE);
    InitDatabase();
    InitQueries();
}

// find a player
public OnClientPostAdminCheck( client ) {
    GetPlayerIndexForClient( client );
}

public OnClientDisconnect( client ) {
    g_iCookieValue[client] = 0;
    
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    new time = GetTime();
    // if paused, substract time so far from player's time in game
    if ( g_bPaused ) {
        time = g_iPauseStart;
    }
    
    // only note time for survivor team players
    if ( g_iPlayerRoundTeam[LTEAM_CURRENT][index] == g_iCurTeam ) {
        // survivor leaving
    
        // store time they left
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] = time;
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = time; }
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = time; }
    }
    else if ( g_iPlayerRoundTeam[LTEAM_CURRENT][index] == (g_iCurTeam) ? 0 : 1 ) {
        // infected leaving
        g_strRoundPlayerInfData[index][g_iCurTeam][infTimeStopPresent] = time;
    }
}

public OnMapStart() {
    g_bSecondHalf = false;
    
    CheckGameMode();
    
    if ( !g_bLoadSkipDone && ( g_bLGOAvailable || GetConVarBool(g_hCvarSkipMap) ) ) {
        // reset stats and unset cvar
        PrintDebug( 2, "OnMapStart: Resetting all stats (resetnextmap setting)... " );
        ResetStats( false, -1 );
        
        // this might not work (server might be resetting the resetnextmap var every time
        //  so also using the bool to make sure it only happens once
        SetConVarInt(g_hCvarSkipMap, 0);
        g_bLoadSkipDone = true;

        g_iFirstScoresSet[0] = 0;
        g_iFirstScoresSet[1] = 0;
        g_iFirstScoresSet[2] = 1;
    }
    else if ( g_bFirstLoadDone ) {
        // reset stats for previous round
        PrintDebug( 2, "OnMapStart: Reset stats for round (Timer_ResetStats)" );
        CreateTimer( STATS_RESET_DELAY, Timer_ResetStats, 1, TIMER_FLAG_NO_MAPCHANGE );
    }
    
    g_bFirstLoadDone = true;
    
    // start flow-check timer
    CreateTimer( FREQ_FLOWCHECK, Timer_SaveFlows, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
    
    // save map name (after onmapload resets, so it doesn't get deleted)
    GetCurrentMapLower( g_sMapName[g_iRound], MAXMAP );
    //PrintDebug( 2, "MapStart (round %i): %s ", g_iRound, g_sMapName[g_iRound] );
}

public OnMapEnd() {
    //PrintDebug(2, "MapEnd (round %i)", g_iRound);
    g_bInRound = false;
    g_iRound++;
    
    // if this was a finale, (and CMT is not loaded), end of game
    if ( !g_bCMTActive && !g_bModeCampaign && IsMissionFinalMap() ) {
        HandleGameEnd();
    }
}

public Event_MissionLostCampaign (Handle:hEvent, const String:name[], bool:dontBroadcast) {
    //PrintDebug( 2, "Event: MissionLost (times %i)", g_strGameData[gmFailed] + 1);
    g_strGameData[gmFailed]++;
    g_strRoundData[g_iRound][g_iCurTeam][rndRestarts]++;
    
    HandleRoundEnd( true );
}

public Event_RoundStart (Handle:hEvent, const String:name[], bool:dontBroadcast) {
    HandleRoundStart();
    CreateTimer( ROUNDSTART_DELAY, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE );
}
stock HandleRoundStart( bool:bLeftStart = false ) {
    //PrintDebug( 1, "HandleRoundStart (leftstart: %i): inround: %i", bLeftStart, g_bInRound);
    
    if ( g_bInRound ) { return; }
    
    g_bInRound = true;
    
    g_bPlayersLeftStart = bLeftStart;
    g_bTankInGame = false;
    g_bPaused = false;
    
    if ( bLeftStart ) {
        g_iCurTeam = ( g_bModeCampaign ) ? 0 : GetCurrentTeamSurvivor();
        ClearPlayerTeam( g_iCurTeam );
    }
}

// delayed, so we can trust GetCurrentTeamSurvivor()
public Action: Timer_RoundStart ( Handle:timer ) {
    // easier to handle: store current survivor team
    g_iCurTeam = ( g_bModeCampaign ) ? 0 : GetCurrentTeamSurvivor();
    
    // clear team for stats
    ClearPlayerTeam( g_iCurTeam );
    
    //PrintDebug( 2, "Event_RoundStart (roundhalf: %i: survivor team: %i (cur survivor: %i))", (g_bSecondHalf) ? 1 : 0, g_iCurTeam, GetCurrentTeamSurvivor() );
}

public Event_RoundEnd (Handle:hEvent, const String:name[], bool:dontBroadcast) {
    // called on versus round end
    // and mission failed coop
    HandleRoundEnd();
}

// do something when round ends (including for campaign mode)
stock HandleRoundEnd ( bool: bFailed = false ) {
    PrintDebug( 1, "HandleRoundEnd (failed: %i): inround: %i, current round: %i", bFailed, g_bInRound, g_iRound);

    // only do once
    if ( !g_bInRound ) { return; }
    
    // count survivors
    g_iSurvived[g_iCurTeam] = GetUprightSurvivors();
    
    // note end of tankfight
    if ( g_bTankInGame ) {
        HandleTankTimeEnd();
    }
    
    // set all 0 times to present
    SetRoundEndTimes();
    
    g_bInRound = false;
    
    if ( !g_bModeCampaign || !bFailed ) {
        // write stats for this roundhalf to file
        // do before addition, because these are round stats
        if ( GetConVarBool(g_hCvarWriteStats) ) {
            PrintDebug( 1, "[Stats] Writing stats to database started." );
            if ( g_bSecondHalf )  {
                CreateTimer( ROUNDEND_SCORE_DELAY, Timer_WriteStats, g_iCurTeam );
            } else {
                WriteStatsToDB( g_iCurTeam, false );
            }
        }
        else {
            PrintDebug( 1, "[Stats] Writing stats to database disabled." );
        }
        
        // only add stuff to total time if the round isn't ongoing
        HandleRoundAddition();
        
        if ( g_iLastRoundEndPrint == 0 || GetTime() - g_iLastRoundEndPrint > PRINT_REPEAT_DELAY ) {
            // false == no delay
            AutomaticRoundEndPrint( false );
        }
    }
    
    // if no-one is on the server anymore, reset the stats (keep it clean when no real game is going on) [safeguard]
    if ( (g_bModeCampaign || g_bSecondHalf) && !AreClientsConnected() ) {
        PrintDebug( 2, "HandleRoundEnd: Reset stats for entire game (no players on server)..." );
        ResetStats( false, -1 );
    }
    
    if ( !g_bModeCampaign ) {
        // prepare for storing 'previous scores' after second roundhalf's roundend
        if (g_bSecondHalf) {
            g_iFirstScoresSet[2] = 0;           // unset, so first scores A/B will be stored on next L4D_OnSetCampaignScores
        }

        g_bSecondHalf = true;
    }
    else {
        g_bFailedPrevious = bFailed;
    }
    
    g_bPlayersLeftStart = false;
}
// fix all 0-endtime values 
stock SetRoundEndTimes() {
    new i, j;
    new time = GetTime();
    
    // start-stop times (always pairs)  <, not <=, because per 2!
    for ( i = rndStartTime; i < MAXRNDSTATS; i += 2 ) {
        // set end
        if ( g_strRoundData[g_iRound][g_iCurTeam][i] && !g_strRoundData[g_iRound][g_iCurTeam][i+1] ) { g_strRoundData[g_iRound][g_iCurTeam][i+1] = time; }
    }
    
    // player data
    for ( j = 0; j < g_iPlayers; j++ ) {
        // start-stop times (always pairs)  <, not <=, because per 2!
        for ( i = plyTimeStartPresent; i < MAXPLYSTATS; i += 2 ) {
            if ( g_strRoundPlayerData[j][g_iCurTeam][i] && !g_strRoundPlayerData[j][g_iCurTeam][i+1] ) { g_strRoundPlayerData[j][g_iCurTeam][i+1] = time; }
        }
        for ( i = infTimeStartPresent; i < MAXINFSTATS; i += 2 ) {
            if ( g_strRoundPlayerInfData[j][g_iCurTeam][i] && !g_strRoundPlayerInfData[j][g_iCurTeam][i+1] ) { g_strRoundPlayerInfData[j][g_iCurTeam][i+1] = time; }
        }
    }
}

// add stuff from this round to the game/allround data arrays
stock HandleRoundAddition() {
    new i, j;
    
    PrintDebug( 1, "Handling round addition for round %i, roundhalf %i (team %s).", g_iRound, g_bSecondHalf, (g_iCurTeam == LTEAM_A) ? "A" : "B" );
    
    // also sets end time to NOW for any 'ongoing' times for round/player
    
    // round data
    for ( i = 0; i < _:rndStartTime; i++ ) {
        g_strAllRoundData[g_iCurTeam][i] += g_strRoundData[g_iRound][g_iCurTeam][i];
    }
    // start-stop times (always pairs)  <, not <=, because per 2!
    for ( i = rndStartTime; i < MAXRNDSTATS; i += 2 ) {
        if ( !g_strRoundData[g_iRound][g_iCurTeam][i] || !g_strRoundData[g_iRound][g_iCurTeam][i+1] ) { continue; }
        
        // set end
        if ( !g_strAllRoundData[g_iCurTeam][i] ) {
            g_strAllRoundData[g_iCurTeam][i] = g_strRoundData[g_iRound][g_iCurTeam][i];
            g_strAllRoundData[g_iCurTeam][i+1] = g_strRoundData[g_iRound][g_iCurTeam][i+1];
        } else {
            g_strAllRoundData[g_iCurTeam][i+1] += g_strRoundData[g_iRound][g_iCurTeam][i+1] - g_strRoundData[g_iRound][g_iCurTeam][i];
        }
    }
    
    // player data
    for ( j = 0; j < g_iPlayers; j++ ) {
        for ( i = 0; i < _:plyTimeStartPresent; i++ ) {
            g_strPlayerData[j][i] += g_strRoundPlayerData[j][g_iCurTeam][i];
        }
        // start-stop times (always pairs)  <, not <=, because per 2!
        for ( i = plyTimeStartPresent; i < MAXPLYSTATS; i += 2 ) {
            if ( !g_strRoundPlayerData[j][g_iCurTeam][i] || !g_strRoundPlayerData[j][g_iCurTeam][i+1] ) { continue; }
            
            if ( !g_strPlayerData[j][i] ) {
                g_strPlayerData[j][i] = g_strRoundPlayerData[j][g_iCurTeam][i];
                g_strPlayerData[j][i+1] = g_strRoundPlayerData[j][g_iCurTeam][i+1];
            } else {
                g_strPlayerData[j][i+1] += g_strRoundPlayerData[j][g_iCurTeam][i+1] - g_strRoundPlayerData[j][g_iCurTeam][i];
            }
        }
        
        // same for infected data
        for ( i = 0; i < _:infTimeStartPresent; i++ ) {
            g_strPlayerInfData[j][i] += g_strRoundPlayerInfData[j][g_iCurTeam][i];
        }
        for ( i = infTimeStartPresent; i < MAXINFSTATS; i += 2 ) {
            if ( !g_strRoundPlayerInfData[j][g_iCurTeam][i] || !g_strRoundPlayerInfData[j][g_iCurTeam][i+1] ) { continue; }
            
            if ( !g_strPlayerInfData[j][i] ) {
                g_strPlayerInfData[j][i] = g_strRoundPlayerInfData[j][g_iCurTeam][i];
                g_strPlayerInfData[j][i+1] = g_strRoundPlayerInfData[j][g_iCurTeam][i+1];
            } else {
                g_strPlayerInfData[j][i+1] += g_strRoundPlayerInfData[j][g_iCurTeam][i+1] - g_strRoundPlayerInfData[j][g_iCurTeam][i];
            }
        }
    }
}

public Event_MapTransition (Handle:hEvent, const String:name[], bool:dontBroadcast) {
    // campaign (ignore in versus)
    if ( g_bModeCampaign ) {
        HandleRoundEnd();
    }
}
public Event_FinaleWin (Handle:hEvent, const String:name[], bool:dontBroadcast) {
    // campaign (ignore in versus)
    if ( g_bModeCampaign ) {
        HandleRoundEnd();
        // finale needn't be the end of the game with custom map transitions
        if ( !g_bCMTActive ) {
            HandleGameEnd();
        }
    }
    //AutomaticGameEndPrint();
}

// do something when game/campaign ends (including for campaign mode)
stock HandleGameEnd() {
    PrintDebug( 2, "HandleGameEnd..." );
    
    // do automatic game end printing?
    
    // reset all stats
    ResetStats( false, -1 );
    g_bLoadSkipDone = false;
}
public OnRoundIsLive() {
    // only called if readyup is available
    RoundReallyStarting();
}

public Action: L4D_OnFirstSurvivorLeftSafeArea( client ) {
    // just as a safeguard (for campaign mode / failed rounds?)
    HandleRoundStart( true );
    
    // if no readyup, use this as the starting event
    if ( !g_bReadyUpAvailable ) {
        RoundReallyStarting();
    }
}

stock RoundReallyStarting() {
    g_bPlayersLeftStart = true;
    new time = GetTime();
    new i;
    
    // clear any lingering stats
    for ( i = 1; i <= MaxClients; i++ ) {
        g_iBoomedBy[i] = 0;
    }
    
    // clear furthest flow
    for ( i = 0; i < 4; i++ ) {
        g_fHighestFlow[i] = 0.0;
    }
    
    if ( !g_bGameStarted ) {
        g_bGameStarted = true;
        g_strGameData[gmStartTime] = time;
        // set start survivor time -- and tell this if we should take a round-failed-restart into account
        SetStartSurvivorTime( true, g_bFailedPrevious );
    }
    
    if ( g_bFailedPrevious && g_strRoundData[g_iRound][g_iCurTeam][rndEndTime] ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] = time - ( g_strRoundData[g_iRound][g_iCurTeam][rndEndTime] - g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] );
        g_strRoundData[g_iRound][g_iCurTeam][rndEndTime] = 0;
        g_bFailedPrevious = false;
    }
    else {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] = time;
    }
    // the conditional below would allow full round times including fails.. not doing that now
    //if ( !g_bModeCampaign || g_strRoundData[g_iRound][g_iCurTeam][rndRestarts] == 0 ) { }
    
    //PrintDebug( 2, "RoundReallyStarting (round %i: roundhalf: %i: survivor team: %i)", g_iRound, (g_bSecondHalf) ? 1 : 0, g_iCurTeam );
    
    // make sure the teams are still what we think they are
    UpdatePlayerCurrentTeam();
    SetStartSurvivorTime();
}

public OnPause() {
    if ( g_bPaused ) { return; }
    g_bPaused = true;
    
    new time = GetTime();
    
    g_iPauseStart = time;
    
    PrintDebug( 1, "Pause (start time: %i -- stored time: %i -- round start time: %i).", g_iPauseStart, g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause], g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] );
}

public OnUnpause() {
    g_bPaused = false;
    
    new time = GetTime();
    new pauseTime = time - g_iPauseStart;
    new client, index;
    
    // adjust remembered pause time
    if ( !g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause] || !g_strRoundData[g_iRound][g_iCurTeam][rndStopTimePause] ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause] = g_iPauseStart;
    }
    else {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause] = g_iPauseStart - (g_strRoundData[g_iRound][g_iCurTeam][rndStopTimePause] - g_strRoundData[g_iRound][g_iCurTeam][rndStartTimePause]);
    }
    g_strRoundData[g_iRound][g_iCurTeam][rndStopTimePause] = time;
    
    
    // when unpausing, substract the pause duration from round time -- can assume that round isn't over yet
    g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] += pauseTime;
    
    // same for tank, if it's up
    if ( g_bTankInGame ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank] += pauseTime;
    }
    
    // for each player in the current survivor team: substract too
    for ( client = 1; client <= MaxClients; client++ ) {
        if ( !IS_VALID_INGAME(client) ) { continue; }
        
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { continue; }
        
        if ( IS_VALID_SURVIVOR(client) ) {
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopPresent] )  {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartPresent] += pauseTime;
            }
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] )  {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] += pauseTime;
            }
            if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] )  {
                g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += pauseTime;
            }
        }
        else if ( IS_VALID_INFECTED(client) ) {
            if ( !g_strRoundPlayerInfData[index][g_iCurTeam][infTimeStopPresent] )  {
                g_strRoundPlayerInfData[index][g_iCurTeam][infTimeStartPresent] += pauseTime;
            }
        }
    }
    
    PrintDebug( 1, "Pause End (end time: %i -- pause duration: %i -- round start time: %i).", GetTime(), pauseTime, g_strRoundData[g_iRound][g_iCurTeam][rndStartTime] );
    
    g_iPauseStart = 0;
}

public Action: L4D_OnSetCampaignScores ( &scoreA, &scoreB ) {
    /* PrintDebug(0, "SetScores called: a:%d, b:%d -- half: %d -- currentsurvivorteam: %d -- cmt swapped: %d -- game swapped: %d",
            scoreA,
            scoreB,
            g_bSecondHalf,
            GetCurrentTeamSurvivor(),
            g_bCMTSwapped,
            GameRules_GetProp("m_bAreTeamsFlipped")
    ); */

    // take swapping into account
    
    if (g_bCMTSwapped) {
        g_iScores[LTEAM_B] = scoreA;
        g_iScores[LTEAM_A] = scoreB;
    } else {
        g_iScores[LTEAM_A] = scoreA;
        g_iScores[LTEAM_B] = scoreB;
    }

    // if first scores weren't set yet, we cannot trust the roundhalf or currentsurvivorteam values!
    // all we know is that order of the scores is as they were at the end of the last round
    if (g_iFirstScoresSet[2] == 0) {
        g_iFirstScoresSet[0] = scoreA;
        g_iFirstScoresSet[1] = scoreB;
        g_iFirstScoresSet[2] = 1;
    }

    return Plugin_Continue;
}