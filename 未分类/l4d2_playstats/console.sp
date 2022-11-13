#if defined _l4d2_playstats_console_included
 #endinput
#endif

#define _l4d2_playstats_console_included

#include <sourcemod>

stock BuildConsoleBufferGeneral ( bool:bTeam = true, iTeam = -1 ) {
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 24;
    new String: strTmp[9][s_len];
    new i, line;
    new bool: bDivider = false;
    new String: strTmpMap[20];
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    new tmpRoundTime;
    new startRound = ( g_iRound > MAXSHOWROUNDS ) ? g_iRound - MAXSHOWROUNDS : 0;
    
    //                      | ###. ############### | ###h ##m ##s | ##### | ###### |  ##### |  ##### | #### | ##### |    ###### |
    
    // game rounds
    for ( i = startRound; i <= g_iRound; i++ ) {
        // round header:
        strcopy( strTmpMap, sizeof(strTmpMap), g_sMapName[i] );
        RightPadString( strTmpMap, sizeof(strTmpMap), 15 );
        if ( strlen(strTmpMap) > 15 ) { Format(strTmpMap, 15, "%s", strTmpMap); }
        Format( strTmp[0], s_len, "%3d. %15s", i + 1, strTmpMap );
        
        // round time
        tmpRoundTime = 0;
        if ( g_strRoundData[i][team][rndStartTime] ) {
            if ( i == g_iRound ) {
                tmpRoundTime = GetFullRoundTime( true, bTeam, team );
            } else {
                tmpRoundTime = g_strRoundData[i][team][rndEndTime] - g_strRoundData[i][team][rndStartTime];
            }
            
            FormatTimeAsDuration( strTmp[1], s_len, tmpRoundTime );
            LeftPadString( strTmp[1], s_len, 12 );
        }
        else {
            Format( strTmp[1], s_len, "            " );
        }
        
        // si
        if ( g_strRoundData[i][team][rndSIKilled] ) {
            Format( strTmp[2], s_len, "%5d", g_strRoundData[i][team][rndSIKilled] );
        } else {
            Format( strTmp[2], s_len, "     " );
        }
        
        // common
        if ( g_strRoundData[i][team][rndCommon] ) {
            Format( strTmp[3], s_len, "%6d", g_strRoundData[i][team][rndCommon] );
        } else {
            Format( strTmp[3], s_len, "      " );
        }
        
        // deaths
        if ( g_strRoundData[i][team][rndDeaths] ) {
            Format( strTmp[4], s_len, "%6d", g_strRoundData[i][team][rndDeaths] );
        } else {
            Format( strTmp[4], s_len, "      " );
        }
        
        // incaps
        if ( g_strRoundData[i][team][rndIncaps] ) {
            Format( strTmp[5], s_len, "%6d", g_strRoundData[i][team][rndIncaps] );
        } else {
            Format( strTmp[5], s_len, "      " );
        }
        
        // kits
        if ( g_strRoundData[i][team][rndKitsUsed] ) {
            Format( strTmp[6], s_len, "%4d", g_strRoundData[i][team][rndKitsUsed] );
        } else {
            Format( strTmp[6], s_len, "    " );
        }
        
        // pills
        if ( g_strRoundData[i][team][rndPillsUsed] ) {
            Format( strTmp[7], s_len, "%6d", g_strRoundData[i][team][rndPillsUsed] );
        } else {
            Format( strTmp[7], s_len, "      " );
        }
        
        // restarts
        if ( g_strRoundData[i][team][rndRestarts] ) {
            Format( strTmp[8], s_len, "%8d", g_strRoundData[i][team][rndRestarts] );
        } else {
            Format( strTmp[8], s_len, "        " );
        }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            bDivider = true;
            line = -1;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        } else if ( line > 0 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
        }
        
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s%s| %20s | %12s | %5s | %6s | %6s | %6s | %4s | %6s | %8s |",
                g_sConsoleBuf[g_iConsoleBufChunks],
                ( bDivider ) ? "| -------------------- | ------------ | ----- | ------ | ------ | ------ | ---- | ------ | -------- |\n" : "",
                strTmp[0], strTmp[1], strTmp[2],
                strTmp[3], strTmp[4], strTmp[5],
                strTmp[6], strTmp[7], strTmp[8]
            );
        
        line++;
        if ( bDivider ) {
            line++;
            bDivider = false;
        }
    }
}

stock BuildConsoleBufferSpecial ( bool:bRound = false, bool:bTeam = true, iTeam = -1 ) {
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 24;
    new String: strTmp[6][s_len];
    new i, x, line;
    new bool: bDivider = false;
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // Special skill stats
    for ( x = 0; x < g_iPlayers; x++ ) {
        i = g_iPlayerIndexSorted[SORT_SI][x];
        
        // also skip bots for this list
        if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
        
        // only show survivors for the round in question
        if ( !bTeam && bRound ) {
            team = g_iPlayerSortedUseTeam[SORT_SI][i];
        }
        if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
        
        // skeets:
        if (    bRound && (g_strRoundPlayerData[i][team][plySkeets] || g_strRoundPlayerData[i][team][plySkeetsHurt] || g_strRoundPlayerData[i][team][plySkeetsMelee]) ||
                !bRound && (g_strPlayerData[i][plySkeets] || g_strPlayerData[i][plySkeetsHurt] || g_strPlayerData[i][plySkeetsMelee])
        ) {
            Format( strTmp[0], s_len, "%4d /%4d /%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySkeets] : g_strPlayerData[i][plySkeets] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySkeetsHurt] : g_strPlayerData[i][plySkeetsHurt] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySkeetsMelee] : g_strPlayerData[i][plySkeetsMelee] )
                );
        } else {
            Format( strTmp[0], s_len, "                " );
        }
        
        // levels
        if (    bRound && (g_strRoundPlayerData[i][team][plyLevels] || g_strRoundPlayerData[i][team][plyLevelsHurt]) ||
                !bRound && (g_strPlayerData[i][plyLevels] || g_strPlayerData[i][plyLevelsHurt])
        ) {
            Format( strTmp[1], s_len, "%3d /%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyLevels] : g_strPlayerData[i][plyLevels] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyLevelsHurt] : g_strPlayerData[i][plyLevelsHurt] )
                );
        } else {
            Format( strTmp[1], s_len, "         " );
        }
        
        // crowns
        if (    bRound && (g_strRoundPlayerData[i][team][plyCrowns] || g_strRoundPlayerData[i][team][plyCrownsHurt]) ||
                !bRound && (g_strPlayerData[i][plyCrowns] || g_strPlayerData[i][plyCrownsHurt])
        ) {
            Format( strTmp[2], s_len, "%3d /%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyCrowns] : g_strPlayerData[i][plyCrowns] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyCrownsHurt] : g_strPlayerData[i][plyCrownsHurt] )
                );
        } else {
            Format( strTmp[2], s_len, "         " );
        }
        
        // pops
        if ( bRound && g_strRoundPlayerData[i][team][plyPops] || !bRound && g_strPlayerData[i][plyPops] ) {
            Format( strTmp[3], s_len, "%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyPops] : g_strPlayerData[i][plyPops] )
                );
        } else {
            Format( strTmp[3], s_len, "    " );
        }
        
        // cuts
        if (    bRound && (g_strRoundPlayerData[i][team][plyTongueCuts] || g_strRoundPlayerData[i][team][plySelfClears] ) ||
                !bRound && (g_strPlayerData[i][plyTongueCuts] || g_strPlayerData[i][plySelfClears] ) ) {
            Format( strTmp[4], s_len, "%4d /%5d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyTongueCuts] : g_strPlayerData[i][plyTongueCuts] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plySelfClears] : g_strPlayerData[i][plySelfClears] )
                );
        } else {
            Format( strTmp[4], s_len, "           " );
        }
        
        // deadstops & m2s
        if (    bRound && (g_strRoundPlayerData[i][team][plyShoves] || g_strRoundPlayerData[i][team][plyDeadStops]) ||
                !bRound && (g_strPlayerData[i][plyShoves] || g_strPlayerData[i][plyDeadStops])
        ) {
            Format( strTmp[5], s_len, "%4d /%4d",
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyDeadStops] : g_strPlayerData[i][plyDeadStops] ),
                    ( (bRound) ? g_strRoundPlayerData[i][team][plyShoves] : g_strPlayerData[i][plyShoves] )
                );
        } else {
            Format( strTmp[5], s_len, "          " );
        }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            bDivider = true;
            line = -1;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        } else if ( line > 0 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
        }
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s%s| %20s | %16s | %9s | %9s | %4s | %11s | %10s |",
                g_sConsoleBuf[g_iConsoleBufChunks],
                ( bDivider ) ? "| -------------------- | ---------------- | --------- | --------- | ---- | ----------- | ---------- |\n" : "",
                g_sPlayerNameSafe[i],
                strTmp[0], strTmp[1], strTmp[2],
                strTmp[3], strTmp[4], strTmp[5]
            );
        
        line++;
        if ( bDivider ) {
            line++;
            bDivider = false;
        }
    }
}

stock BuildConsoleBufferInfected ( bool:bRound = false, bool:bTeam = true, iTeam = -1 ) {
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 24;
    new String: strTmp[6][s_len], String: strTmpA[s_len];
    new i, x, line;
    new bool: bDivider = false;
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    new time = GetTime();
    new fullTime = GetFullRoundTime( bRound, bTeam, team );
    new pauseTime = GetPauseTime( bRound, bTeam, team, true );  // current pause time only
    new presTime;
    
    // Special skill stats
    for ( x = 0; x < g_iPlayers; x++ ) {
        i = g_iPlayerIndexSorted[SORT_INF][x];
        
        // also skip bots for this list
        if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
        
        // only show survivors for the round in question
        if ( !bTeam && bRound ) {
            team = g_iPlayerSortedUseTeam[SORT_INF][i];
        }
        if ( !TableIncludePlayer(i, team, bRound, true, infDmgTotal, infSpawns) ) { continue; }     // reverse lookup this time
        
        // damage
        if (    bRound && (g_strRoundPlayerInfData[i][team][infDmgTotal]) ||
                !bRound && (g_strPlayerInfData[i][infDmgTotal])
        ) {
            Format( strTmp[0], s_len, "%5d / %5d",
                    ( (bRound) ? g_strRoundPlayerInfData[i][team][infDmgUpright] : g_strPlayerInfData[i][infDmgUpright] ),
                    ( (bRound) ? g_strRoundPlayerInfData[i][team][infDmgTotal] : g_strPlayerInfData[i][infDmgTotal] )
                );
        } else {
            Format( strTmp[0], s_len, "             " );
        }
        
        // commons
        if (    bRound && (g_strRoundPlayerInfData[i][team][infCommon]) ||
                !bRound && (g_strPlayerInfData[i][infCommon])
        ) {
            Format( strTmp[1], s_len, "  %5d",
                    ( (bRound) ? g_strRoundPlayerInfData[i][team][infCommon] : g_strPlayerInfData[i][infCommon] )
                );
        } else {
            Format( strTmp[1], s_len, "       " );
        }
        
        // hunter dps
        if (    bRound && (g_strRoundPlayerInfData[i][team][infHunterDPs]) ||
                !bRound && (g_strPlayerInfData[i][infHunterDPs])
        ) {
            Format( strTmp[2], s_len, "    %3d /%5d",
                    ( (bRound) ? g_strRoundPlayerInfData[i][team][infHunterDPs] : g_strPlayerInfData[i][infHunterDPs] ),
                    ( (bRound) ? g_strRoundPlayerInfData[i][team][infHunterDPDmg] : g_strPlayerInfData[i][infHunterDPDmg] )
                );
        } else {
            Format( strTmp[2], s_len, "              " );
        }
        
        // deathcharges
        if ( bRound && g_strRoundPlayerInfData[i][team][infDeathCharges] || !bRound && g_strPlayerInfData[i][infDeathCharges] ) {
            Format( strTmp[3], s_len, "   %4d",
                    ( (bRound) ? g_strRoundPlayerInfData[i][team][infDeathCharges] : g_strPlayerInfData[i][infDeathCharges] )
                );
        } else {
            Format( strTmp[3], s_len, "       " );
        }
        
        // spawns
        if ( bRound && g_strRoundPlayerInfData[i][team][infSpawns] || !bRound && g_strPlayerInfData[i][infSpawns] ) {
            Format( strTmp[4], s_len, "  %4d",
                    ( (bRound) ? g_strRoundPlayerInfData[i][team][infSpawns] : g_strPlayerInfData[i][infSpawns] )
                );
        } else {
            Format( strTmp[4], s_len, "      " );
        }
        
        // time (%)
        if ( bRound ) {
            if ( g_strRoundPlayerInfData[i][team][infTimeStartPresent] ) {
                presTime = ( (g_strRoundPlayerInfData[i][team][infTimeStopPresent]) ? g_strRoundPlayerInfData[i][team][infTimeStopPresent] : time ) - g_strRoundPlayerInfData[i][team][infTimeStartPresent];
            } else {
                presTime = 0;
            }
        } else {
            if ( g_strPlayerInfData[i][infTimeStartPresent] ) {
                presTime = ( (g_strPlayerInfData[i][infTimeStopPresent]) ? g_strPlayerInfData[i][infTimeStopPresent] : time ) - g_strPlayerInfData[i][infTimeStartPresent];
            } else {
                presTime = 0;
            }
        }
        presTime -= pauseTime;
        if (presTime < 0 ) { presTime = 0; }
        
        FormatPercentage( strTmpA, s_len, presTime, fullTime, false );  // never a decimal
        LeftPadString( strTmpA, s_len, 3 );
        FormatEx( strTmp[5], s_len, "%3s%s",
                strTmpA,
                ( presTime && fullTime ) ? "%%" : " "
            );
        
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            bDivider = true;
            line = -1;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        } else if ( line > 0 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
        }
        
        //                                                             ##### / #####     #####       ### / ####      ####     ####   ####
        //                                    | Name                 | Dmg  up / tot | Commons | Hunt DPs / dmg | DCharge | Spawns | Time |
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s%s| %20s | %13s | %7s | %14s | %7s | %6s | %4s |",
                g_sConsoleBuf[g_iConsoleBufChunks],
                ( bDivider ) ?               "| -------------------- | ------------- | ------- | -------------- | ------- | ------ | ---- |\n" : "",
                g_sPlayerNameSafe[i],
                strTmp[0], strTmp[1], strTmp[2],
                strTmp[3], strTmp[4], strTmp[5]
            );
        
        line++;
        if ( bDivider ) {
            line++;
            bDivider = false;
        }
    }
}

stock BuildConsoleBufferAccuracy ( bool:details = false, bool:bRound = false, bool:bTeam = true, iTeam = -1 ) {
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 24;
    new String: strTmp[5][s_len], String: strTmpA[s_len], String: strTmpB[s_len];
    new i, line;
    new bool: bDivider = false;
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // 1234567890123456789
    // ##### /##### ###.#%
    //   ##### ##### #####     details
    
    if ( details ) {
        // Accuracy - details
        for ( i = 0; i < g_iPlayers; i++ ) {
            // also skip bots for this list
            if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // shotgun:
            if ( bRound && g_strRoundPlayerData[i][team][plyHitsShotgun] || !bRound && g_strPlayerData[i][plyHitsShotgun] ) {
                Format( strTmp[0], s_len, "%7d     %7d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSIShotgun] : g_strPlayerData[i][plyHitsSIShotgun] ),
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsTankShotgun] : g_strPlayerData[i][plyHitsTankShotgun] )
                    );
            } else {
                Format( strTmp[0], s_len, "                   " );
            }
            
            // smg:
            if ( bRound && g_strRoundPlayerData[i][team][plyHitsSmg] || !bRound && g_strPlayerData[i][plyHitsSmg] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSISmg] ) / float( g_strRoundPlayerData[i][team][plyHitsSISmg] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSISmg] ) / float( g_strPlayerData[i][plyHitsSISmg] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[1], s_len, "%6d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSISmg] : g_strPlayerData[i][plyHitsSISmg] ),
                        strTmpA,
                        ( (bRound) ?  g_strRoundPlayerData[i][team][plyHitsTankSmg] : g_strPlayerData[i][plyHitsTankSmg] )
                    );
            } else {
                Format( strTmp[1], s_len, "                   " );
            }
            
            // sniper:
            if ( bRound && g_strRoundPlayerData[i][team][plyHitsSniper] || !bRound && g_strPlayerData[i][plyHitsSniper] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSISniper] ) / float( g_strRoundPlayerData[i][team][plyHitsSISniper] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSISniper] ) / float( g_strPlayerData[i][plyHitsSISniper] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[2], s_len, "%6d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSISniper] : g_strPlayerData[i][plyHitsSISniper] ),
                        strTmpA,
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsTankSniper] : g_strPlayerData[i][plyHitsTankSniper] )
                    );
            } else {
                Format( strTmp[2], s_len, "                   " );
            }
            
            // pistols:
            if ( bRound && g_strRoundPlayerData[i][team][plyHitsPistol] || !bRound && g_strPlayerData[i][plyHitsPistol] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSIPistol] ) / float( g_strRoundPlayerData[i][team][plyHitsSIPistol] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSIPistol] ) / float( g_strPlayerData[i][plyHitsSIPistol] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[3], s_len, "%6d %5s%%%% %5d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSIPistol] : g_strPlayerData[i][plyHitsSIPistol] ),
                        strTmpA,
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsTankPistol] : g_strPlayerData[i][plyHitsTankPistol] )
                    );
            } else {
                Format( strTmp[3], s_len, "                   " );
            }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            } else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %19s | %19s | %19s | %19s |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | ------------------- | ------------------- | ------------------- | ------------------- |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2], strTmp[3]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
    else {
        // Accuracy - normal
        for ( i = 0; i < g_iPlayers; i++ ) {
            // also skip bots for this list
            if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // shotgun:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsShotgun] || !bRound && g_strPlayerData[i][plyShotsShotgun] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsShotgun] ) / float( g_strRoundPlayerData[i][team][plyShotsShotgun] ) * 100.0);
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsShotgun] ) / float( g_strPlayerData[i][plyShotsShotgun] ) * 100.0); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                Format( strTmp[0], s_len, "%7d      %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsShotgun] : g_strPlayerData[i][plyHitsShotgun] ),
                        strTmpA
                    );
            } else {
                Format( strTmp[0], s_len, "                   " );
            }
            
            // smg:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsSmg] || !bRound && g_strPlayerData[i][plyShotsSmg] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsSmg] ) / float( g_strRoundPlayerData[i][team][plyShotsSmg] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsSmg] ) / float( g_strPlayerData[i][plyShotsSmg] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) { FormatEx( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSmg] ) / float( g_strRoundPlayerData[i][team][plyHitsSmg] - g_strRoundPlayerData[i][team][plyHitsTankSmg] ) * 100.0 );
                } else {        FormatEx( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSmg] ) / float( g_strPlayerData[i][plyHitsSmg] - g_strPlayerData[i][plyHitsTankSmg] ) * 100.0 ); }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[1], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSmg] : g_strPlayerData[i][plyHitsSmg] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[1], s_len, "                   " );
            }
            
            // sniper:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsSniper] || !bRound && g_strPlayerData[i][plyShotsSniper] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsSniper] ) / float( g_strRoundPlayerData[i][team][plyShotsSniper] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsSniper] ) / float( g_strPlayerData[i][plyShotsSniper] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) { FormatEx( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsSniper] ) / float( g_strRoundPlayerData[i][team][plyHitsSniper] - g_strRoundPlayerData[i][team][plyHitsTankSniper] ) * 100.0 );
                } else {        FormatEx( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsSniper] ) / float( g_strPlayerData[i][plyHitsSniper] - g_strPlayerData[i][plyHitsTankSniper] ) * 100.0 ); }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[2], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsSniper] : g_strPlayerData[i][plyHitsSniper] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[2], s_len, "                   " );
            }
            
            // pistols:
            if ( bRound && g_strRoundPlayerData[i][team][plyShotsPistol] || !bRound && g_strPlayerData[i][plyShotsPistol] ) {
                if ( bRound ) { FormatEx( strTmpA, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHitsPistol] ) / float( g_strRoundPlayerData[i][team][plyShotsPistol] ) * 100.0 );
                } else {        FormatEx( strTmpA, s_len, "%3.1f", float( g_strPlayerData[i][plyHitsPistol] ) / float( g_strPlayerData[i][plyShotsPistol] ) * 100.0 ); }
                while (strlen(strTmpA) < 5) { Format(strTmpA, s_len, " %s", strTmpA); }
                if ( bRound ) { FormatEx( strTmpB, s_len, "%3.1f", float( g_strRoundPlayerData[i][team][plyHeadshotsPistol] ) / float( g_strRoundPlayerData[i][team][plyHitsPistol] - g_strRoundPlayerData[i][team][plyHitsTankPistol] ) * 100.0 );
                } else {        FormatEx( strTmpB, s_len, "%3.1f", float( g_strPlayerData[i][plyHeadshotsPistol] ) / float( g_strPlayerData[i][plyHitsPistol] - g_strPlayerData[i][plyHitsTankPistol] ) * 100.0 ); }
                while (strlen(strTmpB) < 5) { Format(strTmpB, s_len, " %s", strTmpB); }
                Format( strTmp[3], s_len, "%5d %5s%%%% %5s%%%%",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyHitsPistol] : g_strPlayerData[i][plyHitsPistol] ),
                        strTmpA,
                        strTmpB
                    );
            } else {
                Format( strTmp[3], s_len, "                   " );
            }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            } else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %19s | %19s | %19s | %19s |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | ------------------- | ------------------- | ------------------- | ------------------- |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2], strTmp[3]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
}

stock BuildConsoleBufferMVP ( bool:bTank = false, bool: bMore = false, bool:bRound = true, bool:bTeam = true, iTeam = -1 ) {
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 24;
    new String: strTmp[7][s_len], String: strTmpA[s_len], String: strTmpB[s_len];
    new i, x, line;
    new bool: bDivider = false;
    
    new time = GetTime();
    new fullTime, presTime, aliveTime, upTime, pauseTime;
    
    // current logical survivor team?
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // prepare time for comparison to full round
    if ( !bTank ) {
        fullTime = GetFullRoundTime( bRound, bTeam, team );
        pauseTime = GetPauseTime( bRound, bTeam, team, true );  // current pause time only
    }
    
    if ( bTank ) {
        // MVP - tank related
        
        for ( x = 0; x < g_iPlayers; x++ ) {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            //if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // si damage
            if ( bRound && g_strRoundPlayerData[i][team][plySIKilledTankUp] || !bRound && g_strPlayerData[i][plySIKilledTankUp] ) {
                FormatEx( strTmp[0], s_len, "%5d %8d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plySIKilledTankUp] : g_strPlayerData[i][plySIKilledTankUp] ),
                        ( (bRound) ? g_strRoundPlayerData[i][team][plySIDamageTankUp] : g_strPlayerData[i][plySIDamageTankUp] )
                    );
            } else { FormatEx( strTmp[0], s_len, "              " ); }
            
            // commons
            if ( bRound && g_strRoundPlayerData[i][team][plyCommonTankUp] || !bRound && g_strPlayerData[i][plyCommonTankUp] ) {
                FormatEx( strTmp[1], s_len, "  %8d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyCommonTankUp] : g_strPlayerData[i][plyCommonTankUp] )
                    );
            } else { FormatEx( strTmp[1], s_len, "          " ); }
            
            // melee on tank
            if ( bRound && g_strRoundPlayerData[i][team][plyMeleesOnTank] || !bRound && g_strPlayerData[i][plyMeleesOnTank] ) {
                FormatEx( strTmp[2], s_len, "%6d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyMeleesOnTank] : g_strPlayerData[i][plyMeleesOnTank] )
                    );
            } else { FormatEx( strTmp[2], s_len, "      " ); }
            
            // rock skeets / eats       ----- / -----
            if ( bRound && (g_strRoundPlayerData[i][team][plyRockSkeets] || g_strRoundPlayerData[i][team][plyRockEats]) ||
                !bRound && (g_strPlayerData[i][plyRockSkeets] || g_strPlayerData[i][plyRockEats])
            ) {
                FormatEx( strTmp[3], s_len, " %5d /%6d",
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyRockSkeets] : g_strPlayerData[i][plyRockSkeets] ),
                        ( (bRound) ? g_strRoundPlayerData[i][team][plyRockEats] : g_strPlayerData[i][plyRockEats] )
                    );
            } else { FormatEx( strTmp[3], s_len, "              " ); }
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            } else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %14s | %10s | %6s | %14s |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | -------------- | ---------- | ------ | -------------- |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2], strTmp[3]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
    else if ( bMore ) {
        // MVP - more ( time / pinned )
        for ( x = 0; x < g_iPlayers; x++ ) {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            //if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // time present
            if ( bRound ) {
                if ( g_strRoundPlayerData[i][team][plyTimeStartPresent] ) {
                    presTime = ( (g_strRoundPlayerData[i][team][plyTimeStopPresent]) ? g_strRoundPlayerData[i][team][plyTimeStopPresent] : time ) - g_strRoundPlayerData[i][team][plyTimeStartPresent];
                } else {
                    presTime = 0;
                }
            } else {
                if ( g_strPlayerData[i][plyTimeStartPresent] ) {
                    presTime = ( (g_strPlayerData[i][plyTimeStopPresent]) ? g_strPlayerData[i][plyTimeStopPresent] : time ) - g_strPlayerData[i][plyTimeStartPresent];
                } else {
                    presTime = 0;
                }
            }
            presTime -= pauseTime;
            if (presTime < 0 ) { presTime = 0; }
            
            FormatPercentage( strTmpA, s_len, presTime, fullTime, false );  // never a decimal
            LeftPadString( strTmpA, s_len, 7 );
            FormatEx( strTmpA, s_len, "%7s%s",
                    strTmpA,
                    ( presTime ) ? "%%" : " "
                );
            
            if ( fullTime && presTime )  {
                FormatTimeAsDuration( strTmpB, s_len, presTime );
                LeftPadString( strTmpB, s_len, 13 );
            } else {
                Format( strTmpB, s_len, "             ");
            }
            Format( strTmp[0], s_len, "%13s %8s", strTmpB, strTmpA );
            
            // time alive
            if ( bRound ) {
                if ( g_strRoundPlayerData[i][team][plyTimeStartAlive] ) {
                    aliveTime = ( (g_strRoundPlayerData[i][team][plyTimeStopAlive]) ? g_strRoundPlayerData[i][team][plyTimeStopAlive] : time ) - g_strRoundPlayerData[i][team][plyTimeStartAlive];
                } else {
                    aliveTime = 0;
                }
            } else {
                if ( g_strPlayerData[i][plyTimeStartAlive] ) {
                    aliveTime = ( (g_strPlayerData[i][plyTimeStopAlive]) ? g_strPlayerData[i][plyTimeStopAlive] : time ) - g_strPlayerData[i][plyTimeStartAlive];
                } else {
                    aliveTime = 0;
                }
            }
            aliveTime -= pauseTime;
            if (aliveTime < 0 ) { aliveTime = 0; }
            
            FormatPercentage( strTmpA, s_len, aliveTime, presTime, false );  // never a decimal
            LeftPadString( strTmpA, s_len, 5 );
            FormatEx( strTmp[1], s_len, "%5s%s",
                    strTmpA,
                    ( presTime ) ? "%%" : " "
                );
            
            // time upright
            if ( bRound ) {
                if ( g_strRoundPlayerData[i][team][plyTimeStartUpright] ) {
                    upTime = ( (g_strRoundPlayerData[i][team][plyTimeStopUpright]) ? g_strRoundPlayerData[i][team][plyTimeStopUpright] : time ) - g_strRoundPlayerData[i][team][plyTimeStartUpright];
                } else {
                    upTime = 0;
                }
            } else {
                if ( g_strPlayerData[i][plyTimeStartUpright] ) {
                    upTime = ( (g_strPlayerData[i][plyTimeStopUpright]) ? g_strPlayerData[i][plyTimeStopUpright] : time ) - g_strPlayerData[i][plyTimeStartUpright];
                } else {
                    upTime = 0;
                }
            }
            upTime -= pauseTime;
            if (upTime < 0 ) { upTime = 0; }
            
            FormatPercentage( strTmpA, s_len, upTime, presTime, false );  // never a decimal
            LeftPadString( strTmpA, s_len, 6 );
            FormatEx( strTmp[2], s_len, "%6s%s",
                    strTmpA,
                    ( presTime ) ? "%%" : " "
                );
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            } else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %22s | %6s | %7s |                    |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | ---------------------- | ------ | ------- |                    |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
    else {
        // MVP normal
        
        new bool: bPrcDecimal = GetConVarBool(g_hCvarDetailPercent);
        new bool: bTankUp = bool:( !g_bModeCampaign && (!bTeam || team == g_iCurTeam) && g_bInRound && IsTankInGame() );
        
        for ( x = 0; x < g_iPlayers; x++ ) {
            i = g_iPlayerIndexSorted[SORT_SI][x];
            
            // also skip bots for this list?
            if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
            
            // only show survivors for the round in question
            if ( !bTeam && bRound ) {
                team = g_iPlayerSortedUseTeam[SORT_SI][i];
            }
            if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
            
            // si damage
            if ( bRound && g_strRoundPlayerData[i][team][plySIDamage] || !bRound && g_strPlayerData[i][plySIDamage] ) {
                FormatPercentage( strTmpA, s_len,
                        ( bRound ) ? g_strRoundPlayerData[i][team][plySIDamage] : g_strPlayerData[i][plySIDamage],
                        ( bRound ) ? g_strRoundData[g_iRound][team][rndSIDamage] : g_strAllRoundData[team][rndSIDamage],
                        bPrcDecimal
                    );
                LeftPadString( strTmpA, s_len, 5 );
                
                Format( strTmp[0], s_len, "%4d %8d  %5s%s",
                        (bRound) ? g_strRoundPlayerData[i][team][plySIKilled] : g_strPlayerData[i][plySIKilled],
                        (bRound) ? g_strRoundPlayerData[i][team][plySIDamage] : g_strPlayerData[i][plySIDamage],
                        strTmpA,
                        ( bRound && g_strRoundPlayerData[i][team][plySIDamage] || !bRound && g_strPlayerData[i][plySIDamage] ) ? "%%" : " "
                    );
            } else {
                FormatEx( strTmp[0], s_len, "                     " );
            }
            
            // commons
            if ( bRound && g_strRoundPlayerData[i][team][plyCommon] || !bRound && g_strPlayerData[i][plyCommon] ) {
                FormatPercentage( strTmpA, s_len,
                        ( bRound ) ? g_strRoundPlayerData[i][team][plyCommon] : g_strPlayerData[i][plyCommon],
                        ( bRound ) ? g_strRoundData[g_iRound][team][rndCommon] : g_strAllRoundData[team][rndCommon],
                        bPrcDecimal
                    );
                LeftPadString( strTmpA, s_len, 5 );
                
                FormatEx( strTmp[1], s_len, "%7d  %5s%s",
                        (bRound) ? g_strRoundPlayerData[i][team][plyCommon] : g_strPlayerData[i][plyCommon],
                        strTmpA,
                        ( bRound && g_strRoundPlayerData[i][team][plyCommon] || !bRound && g_strPlayerData[i][plyCommon] ) ? "%%" : " "
                    );
            } else {
                FormatEx( strTmp[1], s_len, "               " );
            }
            
            // tank
            if ( bTankUp ) {
                // hide 
                FormatEx( strTmp[2], s_len, "%s", "hidden" );
            } else {
                if ( bRound && g_strRoundPlayerData[i][team][plyTankDamage] || !bRound && g_strPlayerData[i][plyTankDamage] ) {
                    FormatEx( strTmp[2], s_len, "%6d",
                            (bRound) ? g_strRoundPlayerData[i][team][plyTankDamage] : g_strPlayerData[i][plyTankDamage]
                        );
                } else { FormatEx( strTmp[2], s_len, "      " ); }
            }
            
            // witch
            if ( bRound && g_strRoundPlayerData[i][team][plyWitchDamage] || !bRound && g_strPlayerData[i][plyWitchDamage] ) {
                FormatEx( strTmp[3], s_len, "%6d",
                        (bRound) ? g_strRoundPlayerData[i][team][plyWitchDamage] : g_strPlayerData[i][plyWitchDamage]
                    );
            } else { FormatEx( strTmp[3], s_len, "      " ); }
            
            // ff
            if ( bRound && g_strRoundPlayerData[i][team][plyFFGiven] || !bRound && g_strPlayerData[i][plyFFGiven] ) {
                FormatEx( strTmp[4], s_len, "%5d",
                        (bRound) ? g_strRoundPlayerData[i][team][plyFFGiven] : g_strPlayerData[i][plyFFGiven]
                    );
            } else { FormatEx( strTmp[4], s_len, "     " ); }
            
            // damage received
            if ( bRound && g_strRoundPlayerData[i][team][plyDmgTaken] || !bRound && g_strPlayerData[i][plyDmgTaken] ) {
                FormatEx( strTmp[5], s_len, "%4d",
                        (bRound) ? g_strRoundPlayerData[i][team][plyDmgTaken] : g_strPlayerData[i][plyDmgTaken]
                    );
            } else { FormatEx( strTmp[5], s_len, "    " ); }
            
            // time (%)
            if ( bRound ) {
                if ( g_strRoundPlayerData[i][team][plyTimeStartPresent] ) {
                    presTime = ( (g_strRoundPlayerData[i][team][plyTimeStopPresent]) ? g_strRoundPlayerData[i][team][plyTimeStopPresent] : time ) - g_strRoundPlayerData[i][team][plyTimeStartPresent];
                } else {
                    presTime = 0;
                }
            } else {
                if ( g_strPlayerData[i][plyTimeStartPresent] ) {
                    presTime = ( (g_strPlayerData[i][plyTimeStopPresent]) ? g_strPlayerData[i][plyTimeStopPresent] : time ) - g_strPlayerData[i][plyTimeStartPresent];
                } else {
                    presTime = 0;
                }
            }
            presTime -= pauseTime;
            if (presTime < 0 ) { presTime = 0; }
            
            FormatPercentage( strTmpA, s_len, presTime, fullTime, false );  // never a decimal
            LeftPadString( strTmpA, s_len, 3 );
            FormatEx( strTmp[6], s_len, "%3s%s",
                    strTmpA,
                    ( presTime && fullTime ) ? "%%" : " "
                );
            
            // cut into chunks:
            if ( line >= MAXLINESPERCHUNK ) {
                bDivider = true;
                line = -1;
                g_iConsoleBufChunks++;
                g_sConsoleBuf[g_iConsoleBufChunks] = "";
            }
            else if ( line > 0 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
            }
            
            // Format the basic stats
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                    "%s%s| %20s | %21s | %15s | %6s | %6s | %5s | %4s | %4s |",
                    g_sConsoleBuf[g_iConsoleBufChunks],
                    ( bDivider ) ? "| -------------------- | --------------------- | --------------- | ------ | ------ | ----- | ---- | ---- |\n" : "",
                    g_sPlayerNameSafe[i],
                    strTmp[0], strTmp[1], strTmp[2],
                    strTmp[3], strTmp[4], strTmp[5],
                    strTmp[6]
                );
            
            line++;
            if ( bDivider ) {
                line++;
                bDivider = false;
            }
        }
    }
}

stock BuildConsoleBufferFriendlyFireGiven ( bool:bRound = true, bool:bTeam = true, iTeam = -1 ) {
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 15;
    decl String:strPrint[FFTYPE_MAX][s_len];
    new i, x, line;
    new bool: bDivider = false;
    
    // current logical survivor team?
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // GIVEN
    for ( x = 0; x < g_iPlayers; x++ ) {
        i = g_iPlayerIndexSorted[SORT_FF][x];
        
        // also skip bots for this list?
        if ( i < FIRST_NON_BOT ) { continue; }  // never show bots here, they never do FF
        
        // only show survivors for the round in question
        if ( !bTeam && bRound ) {
            team = g_iPlayerSortedUseTeam[SORT_FF][i];
        }
        if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
        
        // skip any row where total of given and taken is 0
        if ( bRound && !g_strRoundPlayerData[i][team][plyFFGivenTotal] && !g_strRoundPlayerData[i][team][plyFFTakenTotal] ||
            !bRound && !g_strPlayerData[i][plyFFGivenTotal] && !g_strPlayerData[i][plyFFTakenTotal]
        ) {
            continue;
        }
        
        // prepare print
        if ( !bRound && g_strPlayerData[i][plyFFGivenTotal] || bRound && g_strRoundPlayerData[i][team][plyFFGivenTotal] ) {
                    FormatEx(strPrint[FFTYPE_TOTAL],      s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenTotal] : g_strRoundPlayerData[i][team][plyFFGivenTotal] );
        } else {    FormatEx(strPrint[FFTYPE_TOTAL],      s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenPellet] || bRound && g_strRoundPlayerData[i][team][plyFFGivenPellet] ) {
                    FormatEx(strPrint[FFTYPE_PELLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenPellet] : g_strRoundPlayerData[i][team][plyFFGivenPellet] );
        } else {    FormatEx(strPrint[FFTYPE_PELLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenBullet] || bRound && g_strRoundPlayerData[i][team][plyFFGivenBullet] ) {
                    FormatEx(strPrint[FFTYPE_BULLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenBullet] : g_strRoundPlayerData[i][team][plyFFGivenBullet] );
        } else {    FormatEx(strPrint[FFTYPE_BULLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenMelee] || bRound && g_strRoundPlayerData[i][team][plyFFGivenMelee] ) {
                    FormatEx(strPrint[FFTYPE_MELEE],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFGivenMelee] : g_strRoundPlayerData[i][team][plyFFGivenMelee] );
        } else {    FormatEx(strPrint[FFTYPE_MELEE],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenFire] || bRound && g_strRoundPlayerData[i][team][plyFFGivenFire] ) {
                    FormatEx(strPrint[FFTYPE_FIRE],       s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFGivenFire] : g_strRoundPlayerData[i][team][plyFFGivenFire] );
        } else {    FormatEx(strPrint[FFTYPE_FIRE],       s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenIncap] || bRound && g_strRoundPlayerData[i][team][plyFFGivenIncap] ) {
                    FormatEx(strPrint[FFTYPE_INCAP],      s_len, "%8d", (!bRound) ? g_strPlayerData[i][plyFFGivenIncap] : g_strRoundPlayerData[i][team][plyFFGivenIncap] );
        } else {    FormatEx(strPrint[FFTYPE_INCAP],      s_len, "        " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenOther] || bRound && g_strRoundPlayerData[i][team][plyFFGivenOther] ) {
                    FormatEx(strPrint[FFTYPE_OTHER],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFGivenOther] : g_strRoundPlayerData[i][team][plyFFGivenOther] );
        } else {    FormatEx(strPrint[FFTYPE_OTHER],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFGivenSelf] || bRound && g_strRoundPlayerData[i][team][plyFFGivenSelf] ) {
                    FormatEx(strPrint[FFTYPE_SELF],       s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFGivenSelf] : g_strRoundPlayerData[i][team][plyFFGivenSelf] );
        } else {    FormatEx(strPrint[FFTYPE_SELF],       s_len, "       " ); }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            bDivider = true;
            line = -1;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        } else if ( line > 0 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
        }
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |",
                g_sConsoleBuf[g_iConsoleBufChunks],
                ( bDivider ) ? "| -------------------- | ------- || ------- | ------- | ------ | ------ | -------- | ------ || ------- |\n" : "",
                g_sPlayerNameSafe[i],
                strPrint[FFTYPE_TOTAL],
                strPrint[FFTYPE_PELLET], strPrint[FFTYPE_BULLET], strPrint[FFTYPE_MELEE],
                strPrint[FFTYPE_FIRE], strPrint[FFTYPE_INCAP], strPrint[FFTYPE_OTHER],
                strPrint[FFTYPE_SELF]
            );
        
        line++;
        if ( bDivider ) {
            line++;
            bDivider = false;
        }
    }
}

stock BuildConsoleBufferFriendlyFireTaken ( bool:bRound = true, bool:bTeam = true, iTeam = -1 ) {
    g_iConsoleBufChunks = 0;
    g_sConsoleBuf[0] = "";
    
    new const s_len = 15;
    decl String:strPrint[FFTYPE_MAX][s_len];
    new i, x, line;
    new bool: bDivider = false;
    
    // current logical survivor team?
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // TAKEN
    for ( x = 0; x < g_iPlayers; x++ ) {
        i = g_iPlayerIndexSorted[SORT_FF][x];
                
        // also skip bots for this list?
        //if ( i < FIRST_NON_BOT && !GetConVarBool(g_hCvarShowBots) ) { continue; }
        
        // only show survivors for the round in question
        if ( !bTeam && bRound ) {
            team = g_iPlayerSortedUseTeam[SORT_SI][i];
        }
        if ( !TableIncludePlayer(i, team, bRound) ) { continue; }
        
        // skip any row where total of given and taken is 0
        if ( bRound && !g_strRoundPlayerData[i][team][plyFFGivenTotal] && !g_strRoundPlayerData[i][team][plyFFTakenTotal] ||
            !bRound && !g_strPlayerData[i][plyFFGivenTotal] && !g_strPlayerData[i][plyFFTakenTotal]
        ) {
            continue;
        }
        
        // prepare print
        if ( !bRound && g_strPlayerData[i][plyFFTakenTotal] || bRound && g_strRoundPlayerData[i][team][plyFFTakenTotal] ) {
                    FormatEx(strPrint[FFTYPE_TOTAL],      s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFTakenTotal] : g_strRoundPlayerData[i][team][plyFFTakenTotal] );
        } else {    FormatEx(strPrint[FFTYPE_TOTAL],      s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenPellet] || !bRound && g_strRoundPlayerData[i][team][plyFFTakenPellet] ) {
                    FormatEx(strPrint[FFTYPE_PELLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFTakenPellet] : g_strRoundPlayerData[i][team][plyFFTakenPellet] );
        } else {    FormatEx(strPrint[FFTYPE_PELLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenBullet] || bRound && g_strRoundPlayerData[i][team][plyFFTakenBullet] ) {
                    FormatEx(strPrint[FFTYPE_BULLET],     s_len, "%7d", (!bRound) ? g_strPlayerData[i][plyFFTakenBullet] : g_strRoundPlayerData[i][team][plyFFTakenBullet] );
        } else {    FormatEx(strPrint[FFTYPE_BULLET],     s_len, "       " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenMelee] || bRound && g_strRoundPlayerData[i][team][plyFFTakenMelee] ) {
                    FormatEx(strPrint[FFTYPE_MELEE],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFTakenMelee] : g_strRoundPlayerData[i][team][plyFFTakenMelee] );
        } else {    FormatEx(strPrint[FFTYPE_MELEE],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenFire] || bRound && g_strRoundPlayerData[i][team][plyFFTakenFire] ) {
                    FormatEx(strPrint[FFTYPE_FIRE],       s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFTakenFire] : g_strRoundPlayerData[i][team][plyFFTakenFire] );
        } else {    FormatEx(strPrint[FFTYPE_FIRE],       s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenIncap] || bRound && g_strRoundPlayerData[i][team][plyFFTakenIncap] ) {
                    FormatEx(strPrint[FFTYPE_INCAP],      s_len, "%8d", (!bRound) ? g_strPlayerData[i][plyFFTakenIncap] : g_strRoundPlayerData[i][team][plyFFTakenIncap] );
        } else {    FormatEx(strPrint[FFTYPE_INCAP],      s_len, "        " ); }
        if ( !bRound && g_strPlayerData[i][plyFFTakenOther] || bRound && g_strRoundPlayerData[i][team][plyFFTakenOther] ) {
                    FormatEx(strPrint[FFTYPE_OTHER],      s_len, "%6d", (!bRound) ? g_strPlayerData[i][plyFFTakenOther] : g_strRoundPlayerData[i][team][plyFFTakenOther] );
        } else {    FormatEx(strPrint[FFTYPE_OTHER],      s_len, "      " ); }
        if ( !bRound && g_strPlayerData[i][plyFallDamage] || bRound && g_strRoundPlayerData[i][team][plyFallDamage] ) {
                    FormatEx(strPrint[FFTYPE_SELF],       s_len, "%7d", (!bRound) ? g_strRoundPlayerData[i][team][plyFallDamage] : g_strPlayerData[i][plyFallDamage] );
        } else {    FormatEx(strPrint[FFTYPE_SELF],       s_len, "       " ); }
        
        // cut into chunks:
        if ( line >= MAXLINESPERCHUNK ) {
            bDivider = true;
            line = -1;
            g_iConsoleBufChunks++;
            g_sConsoleBuf[g_iConsoleBufChunks] = "";
        } else if ( line > 0 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks], CONBUFSIZELARGE, "%s\n", g_sConsoleBuf[g_iConsoleBufChunks] );
        }
        
        // Format the basic stats
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                "%s%s| %20s | %7s || %7s | %7s | %6s | %6s | %8s | %6s || %7s |",
                g_sConsoleBuf[g_iConsoleBufChunks],
                ( bDivider ) ? "| -------------------- | ------- || ------- | ------- | ------ | ------ | -------- | ------ || ------- |\n" : "",
                g_sPlayerNameSafe[i],
                strPrint[FFTYPE_TOTAL],
                strPrint[FFTYPE_PELLET], strPrint[FFTYPE_BULLET], strPrint[FFTYPE_MELEE],
                strPrint[FFTYPE_FIRE], strPrint[FFTYPE_INCAP], strPrint[FFTYPE_OTHER],
                strPrint[FFTYPE_SELF]
            );
        
        line++;
        if ( bDivider ) {
            line++;
            bDivider = false;
        }
    }
}