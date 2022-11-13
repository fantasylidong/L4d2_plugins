#if defined _l4d2_playstats_file_included
 #endinput
#endif

#define _l4d2_playstats_file_included

#include <sourcemod>

/*
    File / DB writing
    -----------------
*/
// delayed so roundscores can be trusted
public Action: Timer_WriteStats ( Handle:timer, any:iTeam ) {
    WriteStatsToDB( iTeam, true );
}
// write round stats to a text file
stock WriteStatsToFile( iTeam, bool:bSecondHalf ) {
    if ( g_bModeCampaign ) { return; }

    new i, j;
    new bool: bFirstWrite;
    new String: sStats[MAX_QUERY_SIZE];
    new String: strTmpLine[512];
    decl String: sTmpTime[20];
    decl String: sTmpRoundNo[6];
    decl String: sTmpMap[64];
    
    // filename: <dir/> <date>_<time>_<roundno>_<mapname>.txt
    new String: path[128];
    
    // create the file
    if ( g_bModeCampaign || !bSecondHalf || !strlen(g_sStatsFile) ) {
        bFirstWrite = true;
        
        FormatTime( sTmpTime, sizeof(sTmpTime), "%Y-%m-%d_%H-%M" );
        IntToString( g_iRound, sTmpRoundNo, sizeof(sTmpRoundNo) );
        LeftPadString( sTmpRoundNo, sizeof(sTmpRoundNo), 4, true );
        GetCurrentMapLower( sTmpMap, sizeof(sTmpMap) );
        
        FormatEx( g_sStatsFile, sizeof(g_sStatsFile), "%s_%s_%s.txt", sTmpTime, sTmpRoundNo, sTmpMap );
    }
    
    // add directory to filename
    FormatEx( path, sizeof(path), "%s%s", DIR_OUTPUT, g_sStatsFile );
    BuildPath( Path_SM, path, PLATFORM_MAX_PATH, path );
    
    // build stats content
    if ( bFirstWrite ) {
        FormatEx( strTmpLine, sizeof(strTmpLine), "[Gameround:%i]\n", g_iRound );
        StrCat( sStats, sizeof(sStats), strTmpLine );
        
        FormatTime( sTmpTime, sizeof(sTmpTime), "%Y-%m-%d;%H:%M" );
        FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%s;%i;%s;%s;\n\n",
                g_iRound,
                sTmpTime,
                g_iTeamSize,
                g_sConfigName,
                sTmpMap
            );
        StrCat( sStats, sizeof(sStats), strTmpLine );
    }
    
    // round data
    FormatEx( strTmpLine, sizeof(strTmpLine), "[RoundHalf:%i]\n", bSecondHalf );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    // round lines, ";"-delimited: <roundhalf>;<team (A/B)>;<rndStat0>;<etc>;\n
    FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%s;", bSecondHalf, (iTeam == LTEAM_A) ? "A" : "B" );
    for ( i = 0; i <= MAXRNDSTATS; i++ ) {
        Format( strTmpLine, sizeof(strTmpLine), "%s%i;", strTmpLine, g_strRoundData[g_iRound][iTeam][i] );
    }
    Format( strTmpLine, sizeof(strTmpLine), "%s\n\n", strTmpLine );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    // progress data
    new Float: maxFlowDist = L4D2Direct_GetMapMaxFlowDistance();
    new Float: curFlowDist[MAXPLAYERS+1];
    new Float: farFlowDist[MAXPLAYERS+1];
    new clients = 0;
    for ( i = 1; i <= MaxClients; i++ ) {
        if ( !IS_VALID_SURVIVOR(i) ) { continue; }
        
        if ( clients < 4 ) {
            // GetEntPropFloat( i, Prop_Data, "m_farthestSurvivorFlowAtDeath" );     // this doesn't work/exist
            // instead, we're tracking it per character 0-3
            farFlowDist[clients] = g_fHighestFlow[clients];
        }
        curFlowDist[clients] = L4D2Direct_GetFlowDistance( i );
        clients++;
    }
    
    FormatEx( strTmpLine, sizeof(strTmpLine), "[Progress:%s]\n", (iTeam == LTEAM_A) ? "A" : "B" );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%s;%i;%i;%.2f;",
            g_bSecondHalf,
            (iTeam == LTEAM_A) ? "A" : "B",
            g_iSurvived[iTeam],
            L4D_GetVersusMaxCompletionScore(),
            maxFlowDist
        );
    
    for ( i = 0; i < clients; i++ ) {
        Format( strTmpLine, sizeof(strTmpLine), "%s%.2f;%.2f;",
                strTmpLine,
                (i < 4) ? farFlowDist[i] : 0.0,
                curFlowDist[i]
            );
    }
    Format( strTmpLine, sizeof(strTmpLine), "%s\n\n", strTmpLine );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    // player data
    FormatEx( strTmpLine, sizeof(strTmpLine), "[Players:%s]:\n", (iTeam == LTEAM_A) ? "A" : "B" );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    new iPlayerCount;
    for ( j = FIRST_NON_BOT; j < g_iPlayers; j++ ) {
        if ( g_iPlayerRoundTeam[iTeam][j] != iTeam ) { continue; }
        iPlayerCount++;
        
        // player lines, ";"-delimited: <#>;<index>;<steamid>;<plyStat0>;<etc>;\n
        FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%i;%s;", iPlayerCount, j, g_sPlayerId[j] );
        for ( i = 0; i <= MAXPLYSTATS; i++ ) {
            Format( strTmpLine, sizeof(strTmpLine), "%s%i;", strTmpLine, g_strRoundPlayerData[j][iTeam][i] );
        }
        Format( strTmpLine, sizeof(strTmpLine), "%s\n", strTmpLine );
        StrCat( sStats, sizeof(sStats), strTmpLine );
    }
    StrCat( sStats, sizeof(sStats), "\n" );
    
    // infected player data
    FormatEx( strTmpLine, sizeof(strTmpLine), "[InfectedPlayers:%s]:\n", (iTeam == LTEAM_A) ? "A" : "B" );
    StrCat( sStats, sizeof(sStats), strTmpLine );
    
    iPlayerCount = 0;
    for ( j = FIRST_NON_BOT; j < g_iPlayers; j++ ) {
        // opposite team!
        if ( g_iPlayerRoundTeam[iTeam][j] != (iTeam) ? 0 : 1 ) { continue; }
        
        // leave out players that were actually specs...
        if (    g_strRoundPlayerInfData[j][iTeam][infTimeStartPresent] == 0 && g_strRoundPlayerInfData[j][iTeam][infTimeStopPresent] == 0 ||
                g_strRoundPlayerInfData[j][iTeam][infSpawns] == 0 && g_strRoundPlayerInfData[j][iTeam][infTankPasses] == 0
        ) {
            continue;
        }
        iPlayerCount++;
        
        // player lines, ";"-delimited: <#>;<index>;<steamid>;<plyStat0>;<etc>;\n
        FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%i;%s;", iPlayerCount, j, g_sPlayerId[j] );
        for ( i = 0; i <= MAXINFSTATS; i++ ) {
            Format( strTmpLine, sizeof(strTmpLine), "%s%i;", strTmpLine, g_strRoundPlayerInfData[j][iTeam][i] );
        }
        Format( strTmpLine, sizeof(strTmpLine), "%s\n", strTmpLine );
        StrCat( sStats, sizeof(sStats), strTmpLine );
    }
    StrCat( sStats, sizeof(sStats), "\n" );
    
    // only print this once (after both rounds played)
    if ( !bFirstWrite ) {
        // scores (both rounds)
        FormatEx( strTmpLine, sizeof(strTmpLine), "[Scoring:]\n" );
        StrCat( sStats, sizeof(sStats), strTmpLine );

        // the scores don't match A/B logical teams, but first/second team to play survivor
        // this should be fixed now by checking the teams on the score-setting forward
        FormatEx( strTmpLine, sizeof(strTmpLine), "A;%i;%i;B;%i;%i;\n\n",
                g_iScores[LTEAM_A] - g_iFirstScoresSet[((g_bCMTSwapped)?1:0)],
                g_iScores[LTEAM_A],
                g_iScores[LTEAM_B] - g_iFirstScoresSet[((g_bCMTSwapped)?0:1)],
                g_iScores[LTEAM_B]
            );
        
        StrCat( sStats, sizeof(sStats), strTmpLine );
        
        
        // player names
        FormatEx( strTmpLine, sizeof(strTmpLine), "[PlayerNames:]:\n" );
        StrCat( sStats, sizeof(sStats), strTmpLine );
        
        iPlayerCount = 0;
        for ( j = FIRST_NON_BOT; j < g_iPlayers; j++ ) {
            if ( !strlen(g_sPlayerId[j]) || !strlen(g_sPlayerName[j]) ) { continue; }
            
            iPlayerCount++;
            
            // player lines, ";"-delimited: <#>;<steamid>;<name>\n  <= note: no ;
            FormatEx( strTmpLine, sizeof(strTmpLine), "%i;%s;%s\n", iPlayerCount, g_sPlayerId[j], g_sPlayerName[j] );
            StrCat( sStats, sizeof(sStats), strTmpLine );
        }
        StrCat( sStats, sizeof(sStats), "\n" );
    }
    
    // write to file
    new Handle: fh = OpenFile( path, "a" );
    
    if (fh == INVALID_HANDLE) {
        PrintDebug(0, "Error: could not write to file: '%s'.", path);
        return;
    }
    WriteFileString( fh, sStats, false );
    CloseHandle(fh);
    
    // write pretty tables?
    if ( GetConVarInt(g_hCvarWriteStats) > 1 ) {
        g_hStatsFile = OpenFile( path, "a" );
        if (g_hStatsFile == INVALID_HANDLE) {
            PrintDebug(0, "Error [table printing]: could not write to file: '%s'.", path);
            return;
        }
        
        // -2 = print to file (if open)
        AutomaticPrintPerClient( FILETABLEFLAGS, -2, iTeam );
        
        CloseHandle(g_hStatsFile);
    }
}