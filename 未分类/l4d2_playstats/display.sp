#if defined _l4d2_playstats_display_included
 #endinput
#endif

#define _l4d2_playstats_display_included

#include <sourcemod>

// display general stats -- if round set, only for that round no.
stock DisplayStats( client = -1, bool:bRound = false, round = -1, bool:bTeam = true, iTeam = -1 ) {
    if ( round != -1 ) { round--; }
    
    decl String:bufBasicHeader[CONBUFSIZE];
    decl String: strTmp[24];
    decl String: strTmpA[24];
    new i, j;
    
    g_iConsoleBufChunks = 0;
    
    new team = g_iCurTeam;
    if ( iTeam != -1 ) { team = iTeam; }
    else if ( g_bSecondHalf && !g_bPlayersLeftStart ) { team = (team) ? 0 : 1; }
    
    // display all rounds / game summary
    
    // game info
    if ( g_bGameStarted ) {
        FormatTimeAsDuration( strTmp, sizeof(strTmp), GetTime() - g_strGameData[gmStartTime] );
        LeftPadString( strTmp, sizeof(strTmp), 14 );
    }
    else {
        Format( strTmp, sizeof(strTmp), " (not started)" );
    }
    
    // spawn/kill ratio
    FormatPercentage( strTmpA, sizeof(strTmpA), g_strAllRoundData[team][rndSIKilled], g_strAllRoundData[team][rndSISpawned], false ); // never a decimal
    LeftPadString( strTmpA, sizeof(strTmpA), 4 );
    
    Format(bufBasicHeader, CONBUFSIZE, "\n");
    Format(bufBasicHeader, CONBUFSIZE, "%s| General Stats                                    |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Time: %14s | Rounds/Fails: %4i /%5i |\n", bufBasicHeader,
            strTmp,
            g_iRound,
            g_strGameData[gmFailed]
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Kits/Pills:%3d /%4d | Kills:   %6i  specials |\n", bufBasicHeader,
            g_strAllRoundData[team][rndKitsUsed],
            g_strAllRoundData[team][rndPillsUsed],
            g_strAllRoundData[team][rndSIKilled]
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s| SI kill rate:  %4s%s |          %6i  commons  |\n",
            bufBasicHeader,
            strTmpA,
            ( g_strAllRoundData[team][rndSISpawned] ) ? "%%" : " ",
            g_strAllRoundData[team][rndCommon] 
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s| Deaths:       %6i |          %6i  witches  |\n", bufBasicHeader,
            g_strAllRoundData[team][rndDeaths],
            g_strAllRoundData[team][rndWitchKilled]
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s| Incaps:       %6i |          %6i  tanks    |\n", bufBasicHeader,
            g_strAllRoundData[team][rndIncaps],
            g_strAllRoundData[team][rndTankKilled]
        );
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------------|\n", bufBasicHeader);
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 ) {
                PrintToConsole(i, bufBasicHeader);
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
    }
    else if ( IS_VALID_INGAME( client ) ) {
        PrintToConsole(client, bufBasicHeader);
        
    }
    
    // round header
    Format( bufBasicHeader,
            CONBUFSIZE,
                                           "\n| General data per game round -- %11s                                                        |\n",
            ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
        );
    
    //                                    | ###. ############### | ###h ##m ##s | ##### | ###### |  ##### |  ##### | #### |  ##### |   ###### |
    Format(bufBasicHeader, CONBUFSIZE, "%s|---------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Round                | Time         | SI    | Common | Deaths | Incaps | Kits | Pills  | Restarts |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|--------------|-------|--------|--------|--------|------|--------|----------|", bufBasicHeader);
    
    // round data
    BuildConsoleBufferGeneral( bTeam, iTeam );
    
    if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
    if ( g_iConsoleBufChunks > -1 ) {
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                                     "%s\n|---------------------------------------------------------------------------------------------------|",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
    } else {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                     "%s\n| (nothing to display)                                                                              |%s",
                bufBasicHeader,
                                       "\n|---------------------------------------------------------------------------------------------------|"
            );
    }
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 ) {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) ) {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
}

// display mvp stats
stock DisplayStatsMVPChat( client, bool:bRound = true, bool:bTeam = true, iTeam = -1 ) {
    // make sure the MVP stats itself is called first, so the players are already sorted
    
    decl String:printBuffer[1024];
    decl String:tmpBuffer[512];
    new String:strLines[8][192];
    new i, j, x;
    
    printBuffer = GetMVPChatString( bRound, bTeam, iTeam );
    
    if ( client == -1 ) {
        PrintToServer("\x01%s", printBuffer);
    }

    // PrintToChatAll has a max length. Split it in to individual lines to output separately
    new intPieces = ExplodeString( printBuffer, "\n", strLines, sizeof(strLines), sizeof(strLines[]) );
    if ( client > 0 ) {
        for ( i = 0; i < intPieces; i++ ) {
            PrintToChat(client, "\x01%s", strLines[i]);
        }
    }
    else if ( client == 0 ) {
        for ( i = 0; i < intPieces; i++ ) {
            PrintToServer("\x01%s", strLines[i]);
        }
    }
    else {
        for ( j = 1; j <= MaxClients; j++ ) {
            for ( i = 0; i < intPieces; i++ ) {
                if ( !IS_VALID_INGAME( j ) || g_iCookieValue[j] != 0 ) { continue; }
                PrintToChat( j, "\x01%s", strLines[i] );
            }
        }
    }
    
    new iBrevityFlags = GetConVarInt(g_hCvarMVPBrevityFlags);
    
    new team = g_iCurTeam;
    if ( iTeam != -1 ) { team = iTeam; }
    else if ( g_bSecondHalf && !g_bPlayersLeftStart ) { team = (team) ? 0 : 1; }
    
    // find index for this client
    new index = -1;
    new found = -1;
    new listNumber = 0;
    
    // also find the three non-mvp survivors and tell them they sucked
    // tell them they sucked with SI
    if (    ( bRound && g_strRoundData[g_iRound][team][rndSIDamage] > 0 || !bRound && g_strAllRoundData[team][rndSIDamage] > 0 )
        &&  !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_SI)
    ) {
        // skip 0, since that is the MVP
        for ( i = 1; i < g_iTeamSize && i < g_iPlayers; i++ ) {
            index = g_iPlayerIndexSorted[SORT_SI][i];
            
            if ( index == -1 ) { break; }
            found = -1;
            for ( x = 1; x <= MaxClients; x++ ) {
                if ( IS_VALID_INGAME(x) ) {
                    if ( index == GetPlayerIndexForClient(x) ) { found = x; break; }
                }
            }
            if ( found == -1 ) { continue; }
            
            // only count survivors for the round in question
            if ( bRound && bTeam && g_iPlayerRoundTeam[team][i] != team ) { continue; }
            
            if ( listNumber && ( client == -1 || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) && g_iCookieValue[found] != -1 ) {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg,\x05 %d \x01kills)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plySIDamage] : g_strPlayerData[index][plySIDamage],
                            (bRound) ? g_strRoundPlayerData[index][team][plySIKilled] : g_strPlayerData[index][plySIKilled]
                        );
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - SI: #\x03%d \x01(dmg \x04%i%%\x01, kills \x04%i%%\x01)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[index][team][plySIDamage]) / float(g_strRoundData[g_iRound][team][rndSIDamage])) * 100) :
                                    ((float(g_strPlayerData[index][plySIDamage]) / float(g_strAllRoundData[team][rndSIDamage])) * 100) 
                                ),
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[index][team][plySIKilled]) / float(g_strRoundData[g_iRound][team][rndSIKilled])) * 100) :
                                    ((float(g_strPlayerData[index][plySIKilled]) / float(g_strAllRoundData[team][rndSIKilled])) * 100) 
                                )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - SI: #\x03%d \x01(\x05%d \x01dmg [\x04%i%%\x01],\x05 %d \x01kills [\x04%i%%\x01])",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plySIDamage] : g_strPlayerData[index][plySIDamage],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[index][team][plySIDamage]) / float(g_strRoundData[g_iRound][team][rndSIDamage])) * 100) :
                                    ((float(g_strPlayerData[index][plySIDamage]) / float(g_strAllRoundData[team][rndSIDamage])) * 100) 
                                ),
                            (bRound) ? g_strRoundPlayerData[index][team][plySIKilled] : g_strPlayerData[index][plySIKilled],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[index][team][plySIKilled]) / float(g_strRoundData[g_iRound][team][rndSIKilled])) * 100) : 
                                    ((float(g_strPlayerData[index][plySIKilled]) / float(g_strAllRoundData[team][rndSIKilled])) * 100) 
                                )
                        );
                }
                PrintToChat( found, "\x01%s", tmpBuffer );
            }
            
            listNumber++;
        }
    }

    // tell them they sucked with Common
    listNumber = 0;
    if (    ( bRound && g_strRoundData[g_iRound][team][rndCommon] || !bRound && g_strAllRoundData[team][rndCommon] )
        &&  !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_CI)
    ) {
        
        // skip 0, since that is the MVP
        for ( i = 1; i < g_iTeamSize && i < g_iPlayers; i++ ) {
            index = g_iPlayerIndexSorted[SORT_CI][i];
            
            if ( index == -1 ) { break; }
            found = -1;
            for ( x = 1; x <= MAXPLAYERS; x++ ) {
                if ( IS_VALID_INGAME(x) ) {
                    if ( index == GetPlayerIndexForClient(x) ) { found = x; break; }
                }
            }
            if ( found == -1 ) { continue; }
            
            // only count survivors for the round in question
            if ( bRound && bTeam && g_iPlayerRoundTeam[team][i] != team ) { continue; }
            
            if ( listNumber && ( client == -1 || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) && g_iCookieValue[found] != -1 ) {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - CI: #\x03%d \x01(\x05 %d \x01kills)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plyCommon] : g_strPlayerData[index][plyCommon]
                        );
                } else if (iBrevityFlags & BREV_ABSOLUTE) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - CI: #\x03%d \x01(kills \x04%i%%\x01)",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[index][team][plyCommon]) / float(g_strRoundData[g_iRound][team][rndCommon])) * 100) :
                                    ((float(g_strPlayerData[index][plyCommon]) / float(g_strAllRoundData[team][rndCommon])) * 100) 
                                )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] Your rank - CI: #\x03%d \x01(\x05 %d \x01kills [\x04%i%%\x01])",
                            (bRound) ? "" : " - Game",
                            (i+1),
                            (bRound) ? g_strRoundPlayerData[index][team][plyCommon] : g_strPlayerData[index][plyCommon],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[index][team][plyCommon]) / float(g_strRoundData[g_iRound][team][rndCommon])) * 100) :
                                    ((float(g_strPlayerData[index][plyCommon]) / float(g_strAllRoundData[team][rndCommon])) * 100) 
                                )
                        );
                }
                PrintToChat( found, "\x01%s", tmpBuffer );
            }
            
            listNumber++;
        }
    }
    
    // tell them they were better with FF
    listNumber = 0;
    if (    !(iBrevityFlags & BREV_RANK) && !(iBrevityFlags & BREV_FF) ) {
        // skip 0, since that is the LVP
        for ( i = 1; i < g_iTeamSize && i < g_iPlayers; i++ ) {
            index = g_iPlayerIndexSorted[SORT_FF][i];
            
            if ( index == -1 ) { break; }
            found = -1;
            for ( x = 1; x <= MaxClients; x++ ) {
                if ( IS_VALID_INGAME(x) ) {
                    if ( index == GetPlayerIndexForClient(x) ) { found = x; break; }
                }
            }
            if ( found == -1 ) { continue; }
            
            // only count survivors for the round in question
            if ( bRound && bTeam && g_iPlayerRoundTeam[team][i] != team ) { continue; }

            if ( bRound && !g_strRoundPlayerData[index][team][plyFFGiven] || !bRound && !g_strPlayerData[index][plyFFGiven] ) { continue; }
            
            if ( listNumber && ( client == -1 || client == found ) && IS_VALID_CLIENT(found) && !IsFakeClient(found) && g_iCookieValue[found] != -1 ) {
                Format(tmpBuffer, sizeof(tmpBuffer), "[LVP%s] Your rank - FF: #\x03%d \x01(\x05%d \x01dmg)",
                        (bRound) ? "" : " - Game",
                        (i+1),
                        (bRound) ? g_strRoundPlayerData[index][team][plyFFGiven] : g_strPlayerData[index][plyFFGiven]
                    );

                PrintToChat( found, "\x01%s", tmpBuffer );
            }
            
            listNumber++;
        }
    }
}

String: GetMVPChatString( bool:bRound = true, bool:bTeam = true, iTeam = -1 ) {
    decl String: printBuffer[1024];
    decl String: tmpBuffer[512];
    
    printBuffer = "";
    
    // SI damage already sorted, sort CI and FF too
    SortPlayersMVP( bRound, SORT_SI, bTeam, iTeam );
    SortPlayersMVP( bRound, SORT_CI, bTeam, iTeam );
    SortPlayersMVP( bRound, SORT_FF, bTeam, iTeam );
    
    // use current survivor team -- or previous team in second half before starting
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    // normally, topmost is the mvp
    new mvp_SI =        g_iPlayerIndexSorted[SORT_SI][0];
    new mvp_Common =    g_iPlayerIndexSorted[SORT_CI][0];
    new mvp_FF =        g_iPlayerIndexSorted[SORT_FF][0];
    
    // find first on the right team, if looking for 1 team and there is no team-specific sorting list
    if ( bTeam && !bRound ) {
        for ( new i = 0; i < g_iPlayers; i++ ) {
            if ( g_iPlayerRoundTeam[team][i] == team ) {
                mvp_SI = mvp_Common = mvp_FF = i;
                break;
            }
        }
    }
    
    new iBrevityFlags = GetConVarInt(g_hCvarMVPBrevityFlags);
    
    // if null data, set them to -1
    if ( g_iPlayers < 1 || bRound && !g_strRoundPlayerData[mvp_SI][team][plySIDamage]   || !bRound && !g_strPlayerData[mvp_SI][plySIDamage] )   { mvp_SI = -1; }
    if ( g_iPlayers < 1 || bRound && !g_strRoundPlayerData[mvp_Common][team][plyCommon] || !bRound && !g_strPlayerData[mvp_Common][plyCommon] ) { mvp_Common = -1; }
    if ( g_iPlayers < 1 || bRound && !g_strRoundPlayerData[mvp_FF][team][plyFFGiven]    || !bRound && !g_strPlayerData[mvp_FF][plyFFGiven] )    { mvp_FF = -1; }
    
    // report
    if ( mvp_SI == -1 && mvp_Common == -1 && !(iBrevityFlags & BREV_SI && iBrevityFlags & BREV_CI) ) {
        Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s]: (not enough action yet)\n", (bRound) ? "" : " - Game" );
        StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
    }
    else {
        if ( !(iBrevityFlags & BREV_SI) ) {
            if ( mvp_SI > -1 ) {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI:\x03 %s \x01(\x05%d \x01dmg,\x05 %d \x01kills)\n", 
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_SI],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIDamage] : g_strPlayerData[mvp_SI][plySIDamage],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIKilled] : g_strPlayerData[mvp_SI][plySIKilled]
                        );
                } else if ( iBrevityFlags & BREV_ABSOLUTE ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI:\x03 %s \x01(dmg \x04%i%%\x01, kills \x04%i%%\x01)\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_SI],
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[mvp_SI][team][plySIDamage]) / float(g_strRoundData[g_iRound][team][rndSIDamage])) * 100) :
                                    ((float(g_strPlayerData[mvp_SI][plySIDamage]) / float(g_strAllRoundData[team][rndSIDamage])) * 100) 
                                ),
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[mvp_SI][team][plySIKilled]) / float(g_strRoundData[g_iRound][team][rndSIKilled])) * 100) :
                                    ((float(g_strPlayerData[mvp_SI][plySIKilled]) / float(g_strAllRoundData[team][rndSIKilled])) * 100) 
                                )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI:\x03 %s \x01(\x05%d \x01dmg[\x04%i%%\x01],\x05 %d \x01kills [\x04%i%%\x01])\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_SI],
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIDamage] : g_strPlayerData[mvp_SI][plySIDamage],
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[mvp_SI][team][plySIDamage]) / float(g_strRoundData[g_iRound][team][rndSIDamage])) * 100) :
                                    ((float(g_strPlayerData[mvp_SI][plySIDamage]) / float(g_strAllRoundData[team][rndSIDamage])) * 100) 
                                ),
                            (bRound) ? g_strRoundPlayerData[mvp_SI][team][plySIKilled] : g_strPlayerData[mvp_SI][plySIKilled],
                            RoundFloat( (bRound) ?
                                    ((float(g_strRoundPlayerData[mvp_SI][team][plySIKilled]) / float(g_strRoundData[g_iRound][team][rndSIKilled])) * 100) :
                                    ((float(g_strPlayerData[mvp_SI][plySIKilled]) / float(g_strAllRoundData[team][rndSIKilled])) * 100) 
                                )
                        );
                }
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
            else {
                Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] SI: \x03(nobody)\x01\n", (bRound) ? "" : " - Game" );
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
        }
        
        if ( !(iBrevityFlags & BREV_CI) ) {
            // only print if there is a common mvp, and if they killed more than 0 commons
            //  safeguarded to only show if total common kills logged in scope
            if (    mvp_Common > -1
                &&  (bRound && g_strRoundData[g_iRound][team][rndCommon] || !bRound && g_strAllRoundData[team][rndCommon])
            ) {
                if ( iBrevityFlags & BREV_PERCENT ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] CI:\x03 %s \x01(\x05%d \x01common)\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_Common],
                            (bRound) ? g_strRoundPlayerData[mvp_Common][team][plyCommon] : g_strPlayerData[mvp_Common][plyCommon]
                        );
                } else if ( iBrevityFlags & BREV_ABSOLUTE ) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] CI:\x03 %s \x01(\x04%i%%\x01)\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_Common],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[mvp_Common][team][plyCommon]) / float(g_strRoundData[g_iRound][team][rndCommon])) * 100) :
                                    ((float(g_strPlayerData[mvp_Common][plyCommon]) / float(g_strAllRoundData[team][rndCommon])) * 100) 
                                )
                        );
                } else {
                    Format(tmpBuffer, sizeof(tmpBuffer), "[MVP%s] CI:\x03 %s \x01(\x05%d \x01common [\x04%i%%\x01])\n",
                            (bRound) ? "" : " - Game",
                            g_sPlayerName[mvp_Common],
                            (bRound) ? g_strRoundPlayerData[mvp_Common][team][plyCommon] : g_strPlayerData[mvp_Common][plyCommon],
                            RoundFloat( (bRound) ? 
                                    ((float(g_strRoundPlayerData[mvp_Common][team][plyCommon]) / float(g_strRoundData[g_iRound][team][rndCommon])) * 100) :
                                    ((float(g_strPlayerData[mvp_Common][plyCommon]) / float(g_strAllRoundData[team][rndCommon])) * 100) 
                                )
                        );
                }
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
        }
    }
    
    // FF
    if ( !(iBrevityFlags & BREV_FF) ) {
        if ( mvp_FF == -1 ) {
            Format(tmpBuffer, sizeof(tmpBuffer), "[LVP%s] FF: no friendly fire at all!\n",
                    (bRound) ? "" : " - Game"
                );
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
        else {
            Format(tmpBuffer, sizeof(tmpBuffer), "[LVP%s] FF:\x03 %s \x01(\x05%d \x01dmg)\n",
                        (bRound) ? "" : " - Game",
                        g_sPlayerName[mvp_FF],
                        (bRound) ? g_strRoundPlayerData[mvp_FF][team][plyFFGiven] : g_strPlayerData[mvp_FF][plyFFGiven]
                    );
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
    }
    
    return printBuffer;
}

stock DisplayStatsMVP( client, bool:bTank = false, bool:bMore = false, bool:bRound = true, bool:bTeam = true, iTeam = -1 ) {
    new i, j;
    new bool: bFooter = false;
    
    // get sorted players list
    SortPlayersMVP( bRound, SORT_SI, bTeam, iTeam );
    
    new bool: bTankUp = bool:( !g_bModeCampaign && IsTankInGame() && g_bInRound );
    
    // prepare buffer(s) for printing
    if ( !bTank || !bTankUp ) {
        BuildConsoleBufferMVP( bTank, bMore, bRound, bTeam, iTeam );
    }
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    decl String:bufBasicFooter[CONBUFSIZE];
    
    if ( bTank ) {
        if ( bTankUp ) {
            Format(bufBasicHeader, CONBUFSIZE, "\n| Survivor MVP Stats -- Tank Fight (not showing table, tank is still up...)    |\n");
            Format(bufBasicHeader, CONBUFSIZE, "%s|------------------------------------------------------------------------------|",    bufBasicHeader);
            g_iConsoleBufChunks = -1;
        }
        else {        
            Format(bufBasicHeader, CONBUFSIZE, "\n| Survivor MVP Stats -- Tank Fight -- %10s -- %11s                |\n",
                    ( bRound ) ? "This Round" : "ALL Rounds",
                    ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
                );
            Format(bufBasicHeader, CONBUFSIZE, "%s|------------------------------------------------------------------------------|\n",  bufBasicHeader);
            Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | SI during tank | CI d. tank | Melees | Rock skeet/eat |\n",  bufBasicHeader);
            Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|----------------|------------|--------|----------------|",    bufBasicHeader);
            
            if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
            if ( g_iConsoleBufChunks > -1 ) {
                Format( g_sConsoleBuf[g_iConsoleBufChunks],
                        CONBUFSIZELARGE,
                                             "%s\n|------------------------------------------------------------------------------|\n",
                        g_sConsoleBuf[g_iConsoleBufChunks]
                );
            } else {
                Format( bufBasicHeader,
                        CONBUFSIZE,
                                             "%s\n| (nothing to display)                                                         |%s",
                        bufBasicHeader,
                                               "\n|------------------------------------------------------------------------------|"
                );
            }
        }
    }
    else if ( bMore ) {
        Format(bufBasicHeader, CONBUFSIZE, "\n| Survivor MVP Stats -- More Stats -- %10s -- %11s                         |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        //                                                             ###h ##m ##s
        Format(bufBasicHeader, CONBUFSIZE,    "%s|---------------------------------------------------------------------------------------|\n",  bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Time Present  %%%% of rnd | Alive  | Upright |                    |\n",  bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE,    "%s|----------------------|------------------------|--------|---------|--------------------|",    bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                            "%s\n|---------------------------------------------------------------------------------------|\n",
                    g_sConsoleBuf[g_iConsoleBufChunks]
            );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                            "%s\n| (nothing to display)                                                                  |%s",
                    bufBasicHeader,
                                              "\n|---------------------------------------------------------------------------------------|"
            );
        }
    }
    else {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                           "\n| Survivor MVP Stats -- %10s -- %11s                                                        |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------------------------------------------------------------------------------|\n",   bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Specials   kills/dmg  | Commons         | Tank   | Witch  | FF    | Rcvd | Time |\n",   bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|-----------------------|-----------------|--------|--------|-------|------|------|",     bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                         "%s\n|--------------------------------------------------------------------------------------------------------|",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                   |%s",
                    bufBasicHeader,
                                           "\n|--------------------------------------------------------------------------------------------------------|"
                );
        }
        
        // print pause and tank time
        if ( g_iConsoleBufChunks > -1 ) {
            new const s_len = 24;
            new String: strTmp[3][s_len];
            new fullTime, tankTime, pauseTime;
            
            fullTime = GetFullRoundTime( bRound, bTeam, team );
            tankTime = GetFullRoundTime( bRound, bTeam, team, true );
            pauseTime = GetPauseTime( bRound, bTeam, team );
            
            if ( fullTime )  {
                FormatTimeAsDuration( strTmp[0], s_len, fullTime, false );
                RightPadString( strTmp[0], s_len, 13);
            } else {
                FormatEx( strTmp[0], s_len, "(not started)");
            }
            
            if ( tankTime )  {
                FormatTimeAsDuration( strTmp[1], s_len, tankTime, false );
                RightPadString( strTmp[1], s_len, 13);
            } else {
                FormatEx( strTmp[1], s_len, "             ");
            }
            
            if ( g_bPauseAvailable ) {
                if ( pauseTime )  {
                    FormatTimeAsDuration( strTmp[2], s_len, pauseTime, false );
                    RightPadString( strTmp[2], s_len, 13);
                } else {
                    FormatEx( strTmp[2], s_len, "             ");
                }
            } else {
                FormatEx( strTmp[2], s_len, "             ");
            }
            
            FormatEx( bufBasicFooter,
                    CONBUFSIZE,
                                            "| Round Duration:  %13s   %s  %13s   %s  %13s  |\n%s",
                    strTmp[0],
                    (tankTime) ? "Tank Fight Duration:" : "                    ",
                    strTmp[1],
                    (g_bPauseAvailable && pauseTime) ? "Pause Duration:" : "               ",
                    strTmp[2],
                                            "|--------------------------------------------------------------------------------------------------------|\n"
                );
            
            bFooter = true;
        }
    }
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            if ( bFooter ) {
                ReplaceString(bufBasicFooter, CONBUFSIZE, "%%", "%");
                WriteFileString( g_hStatsFile, bufBasicFooter, false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 ) {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
                if ( bFooter ) {
                    PrintToConsole(i, bufBasicFooter);
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer(g_sConsoleBuf[j] );
        }
        if ( bFooter ) {
            PrintToServer(bufBasicFooter);
        }
    }
    else if ( IS_VALID_INGAME( client ) ) {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
        if ( bFooter ) {
            PrintToConsole(client, bufBasicFooter);
        }
    }
}

// show 1 (randomly selected, but at least relevant) fact about the game
stock DisplayStatsFunFactChat( client, bool:bRound = true, bool:bTeam = true, iTeam = -1 ) {
    decl String:printBuffer[1024];
    new String:strLines[8][192];
    new i, j;
    
    printBuffer = GetFunFactChatString( bRound, bTeam, iTeam );
    
    // only print if we got something
    if ( !strlen(printBuffer) ) { return; }
    
    if ( client == -1 ) {
        PrintToServer("\x01%s", printBuffer);

        if (g_bDiscordScoreboardAvailable) {
            decl String:strippedBuffer[1024];
            strcopy(strippedBuffer, sizeof(strippedBuffer), printBuffer);
            FilterColorCode(strippedBuffer, sizeof(strippedBuffer));
            ReplaceString(strippedBuffer, sizeof(strippedBuffer), "\n", "");
            AddEmbed("Fun Fact", strippedBuffer, "", 1815868);
        }
    }

    // PrintToChatAll has a max length. Split it in to individual lines to output separately
    new intPieces = ExplodeString( printBuffer, "\n", strLines, sizeof(strLines), sizeof(strLines[]) );
    
    if ( client > 0 ) {
        for ( i = 0; i < intPieces; i++ ) {
            PrintToChat(client, "\x01%s", strLines[i]);
        }
    }
    else if ( client == 0 ) {
        for ( i = 0; i < intPieces; i++ ) {
            PrintToServer("\x01%s", strLines[i]);
        }
    }
    else {
        for ( j = 1; j <= MaxClients; j++ ) {
            for ( i = 0; i < intPieces; i++ ) {
                if ( !IS_VALID_INGAME( j ) || g_iCookieValue[j] != 0 ) { continue; }
                PrintToChat( j, "\x01%s", strLines[i] );
            }
        }
    }
}

String: GetFunFactChatString( bool:bRound = true, bool:bTeam = true, iTeam = -1 ) {
    decl String: printBuffer[1024];
    
    printBuffer = "";
    
    // use current survivor team -- or previous team in second half before starting
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    new i, j;
    new wTotal = 0;
    new wPicks[256];
    
    new wTypeHighPly[FFACT_MAXTYPES+1];
    new wTypeHighVal[FFACT_MAXTYPES+1];
    new wTypeHighTeam[FFACT_MAXTYPES+1];
    
    // for each type, check whether / and how weighted
    new wTmp = 0;
    new highest, value, property, minval, maxval;
    new bool:bInf;
    
    for ( i = 0; i <= FFACT_MAXTYPES; i++ ) {
        wTmp = 0;
        wTypeHighPly[i] = -1;
        wTypeHighTeam[i] = team;
        bInf = false;
        
        switch (i) {
            case FFACT_TYPE_CROWN: {
                property = plyCrowns;
                minval = FFACT_MIN_CROWN;
                maxval = FFACT_MAX_CROWN;
            }
            case FFACT_TYPE_DRAWCROWN: {
                property = plyCrownsHurt;
                minval = FFACT_MIN_DRAWCROWN;
                maxval = FFACT_MAX_DRAWCROWN;
            }
            case FFACT_TYPE_SKEETS: {
                property = plySkeets;
                minval = FFACT_MIN_SKEET;
                maxval = FFACT_MAX_SKEET;
            }
            case FFACT_TYPE_MELEESKEETS: {
                property = plySkeetsMelee;
                minval = FFACT_MIN_MELEESKEET;
                maxval = FFACT_MAX_MELEESKEET;
            }
            case FFACT_TYPE_M2: {
                property = plyShoves;
                minval = FFACT_MIN_M2;
                maxval = FFACT_MAX_M2;
            }
            case FFACT_TYPE_MELEETANK: {
                property = plyMeleesOnTank;
                minval = FFACT_MIN_MELEETANK;
                maxval = FFACT_MAX_MELEETANK;
            }
            case FFACT_TYPE_CUT: {
                property = plyTongueCuts;
                minval = FFACT_MIN_CUT;
                maxval = FFACT_MAX_CUT;
            }
            case FFACT_TYPE_POP: {
                property = plyPops;
                minval = FFACT_MIN_POP;
                maxval = FFACT_MAX_POP;
            }
            case FFACT_TYPE_DEADSTOP: {
                property = plyDeadStops;
                minval = FFACT_MIN_DEADSTOP;
                maxval = FFACT_MAX_DEADSTOP;
            }
            case FFACT_TYPE_LEVELS: {
                property = plyLevels;
                minval = FFACT_MIN_LEVEL;
                maxval = FFACT_MAX_LEVEL;
            }
            
            case FFACT_TYPE_HUNTERDP: {
                bInf = true;
                property = infHunterDPs;
                minval = FFACT_MIN_HUNTERDP;
                maxval = FFACT_MAX_HUNTERDP;
            }
            case FFACT_TYPE_JOCKEYDP: {
                bInf = true;
                property = infJockeyDPs;
                minval = FFACT_MIN_JOCKEYDP;
                maxval = FFACT_MAX_JOCKEYDP;
            }
            case FFACT_TYPE_DCHARGE: {
                bInf = true;
                property = infDeathCharges;
                minval = FFACT_MIN_DCHARGE;
                maxval = FFACT_MAX_DCHARGE;
            }
            case FFACT_TYPE_SCRATCH: {
                bInf = true;
                property = infDmgScratch;
                minval = FFACT_MIN_SCRATCH;
                maxval = FFACT_MAX_SCRATCH;
            }
            case FFACT_TYPE_BOOMDMG: {
                bInf = true;
                property = infDmgBoom;
                minval = FFACT_MIN_BOOMDMG;
                maxval = FFACT_MAX_BOOMDMG;
            }
            case FFACT_TYPE_SPITDMG: {
                bInf = true;
                property = infDmgSpit;
                minval = FFACT_MIN_SPITDMG;
                maxval = FFACT_MAX_SPITDMG;
            }
        }
        
        highest = GetPlayerWithHighestValue( property, bRound, bTeam, team, bInf );
        if ( highest == -1 ) { continue; }
        
        if ( bInf ) {
            if ( bRound && bTeam ) {
                value = g_strRoundPlayerInfData[highest][team][property];
            } else {
                if ( g_strRoundPlayerInfData[highest][LTEAM_A][property] > g_strRoundPlayerInfData[highest][LTEAM_B][property] ) {
                    value = g_strRoundPlayerInfData[highest][LTEAM_A][property];
                    wTypeHighTeam[i] = LTEAM_A;
                } else {
                    value = g_strRoundPlayerInfData[highest][LTEAM_B][property];
                    wTypeHighTeam[i] = LTEAM_B;
                }
            }
        }
        else {
            if ( bRound && bTeam ) {
                value = g_strRoundPlayerData[highest][team][property];
            } else {
                if ( g_strRoundPlayerData[highest][LTEAM_A][property] > g_strRoundPlayerData[highest][LTEAM_B][property] ) {
                    value = g_strRoundPlayerData[highest][LTEAM_A][property];
                    wTypeHighTeam[i] = LTEAM_A;
                } else {
                    value = g_strRoundPlayerData[highest][LTEAM_B][property];
                    wTypeHighTeam[i] = LTEAM_B;
                }
            }
        }
        
        if ( value > minval ) {
            wTypeHighPly[i] = highest;
            wTypeHighVal[i] = value;
            // weight for this fact
            if ( value >= maxval ) {
                wTmp = FFACT_MAX_WEIGHT;
            } else {
                wTmp = RoundFloat(  float(value - minval) / float(maxval - minval) * float(FFACT_MAX_WEIGHT) ) + 1;
            }
        }
        
        if ( wTmp ) {
            for ( j = 0; j < wTmp; j++ ) { wPicks[wTotal+j] = i; }
            wTotal += wTmp;
        }
    }
    
    if ( !wTotal ) { return printBuffer; }
    
    // pick one, format it
    new wPick = Math_GetRandomInt( 0, wTotal-1 );
    wPick = wPicks[wPick];
    
    switch (wPick) {
        case FFACT_TYPE_CROWN: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01crowned \x05%d \x01witches.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_DRAWCROWN: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01draw-crowned \x05%d \x01witches.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_SKEETS: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01skeeted \x05%d \x01hunters.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_MELEESKEETS: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01skeeted \x05%d \x01hunter%s with a melee weapon.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick],
                ( wTypeHighVal[wPick] == 1 ) ? "" : "s"
            );
        }
        case FFACT_TYPE_M2: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01shoved \x05%d \x01special infected.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_MELEETANK: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01got \x05%d \x01melee swings on the tank.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_CUT: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01cut \x05%d \x01tongue cuts.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_POP: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01popped \x05%d \x01boomers.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_DEADSTOP: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01deadstopped \x05%d \x01hunters.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_LEVELS: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01fully leveled \x05%d \x01chargers.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        
        // infected
        case FFACT_TYPE_HUNTERDP: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01landed \x05%d \x01highpounces with hunters.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_JOCKEYDP: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01landed \x05%d \x01highpounces with jockeys.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_DCHARGE: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01death-charged \x05%d \x01 survivor%s.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick],
                ( wTypeHighVal[wPick] == 1 ) ? "" : "s"
            );
        }
        case FFACT_TYPE_SCRATCH: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01did a total of \x05%d \x01damage by scratching (standing) survivors.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_BOOMDMG: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01got a total of \x05%d \x01damage by common hits on boomed (standing) survivors.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
        case FFACT_TYPE_SPITDMG: {
            Format(printBuffer, sizeof(printBuffer), "[%s fact] \x04%s \x01did a total of \x05%d \x01spit-damage on (standing) survivors.\n",
                (bRound) ? "Round" : "Game",
                g_sPlayerName[ wTypeHighPly[wPick] ],
                wTypeHighVal[wPick]
            );
        }
    }
    
    return printBuffer;
}

// display player accuracy stats: details => tank/si/etc
stock DisplayStatsAccuracy( client, bool:bDetails = false, bool:bRound = false, bool:bTeam = true, bool:bSorted = true, iTeam = -1 ) {
    new i, j;
    
    // sorting
    if ( !bSorted ) {
        SortPlayersMVP( bRound, SORT_SI, bTeam, iTeam );
    }
    
    // prepare buffer(s) for printing
    BuildConsoleBufferAccuracy( bDetails, bRound, bTeam, iTeam );
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    
    if ( bDetails ) {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                           "\n| Accuracy -- Details -- %10s -- %11s                 hits on SI;  headshots on SI;  hits on tank |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Shotgun             | SMG / Rifle         | Sniper              | Pistol              |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------|---------------------|---------------------|---------------------|", bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                         "%s\n|--------------------------------------------------------------------------------------------------------------|",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                         |%s",
                    bufBasicHeader,
                                           "\n|--------------------------------------------------------------------------------------------------------------|"
                );
        }
    }
    else {
        Format(bufBasicHeader, CONBUFSIZE, "\n| Accuracy Stats -- %10s -- %11s       hits (pellets/bullets);  acc prc;  headshots prc (of hits) |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Shotgun buckshot    | SMG / Rifle  acc hs | Sniper       acc hs | Pistol       acc hs |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------------|---------------------|---------------------|---------------------|", bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                         "%s\n|--------------------------------------------------------------------------------------------------------------|",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                         |%s",
                    bufBasicHeader,
                                           "\n|--------------------------------------------------------------------------------------------------------------|"
                );
        }

    }
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 ) {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) ) {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
}

// display special skill stats
stock DisplayStatsSpecial( client, bool:bRound = true, bool:bTeam = true, bool:bSorted = false, iTeam = -1 ) {
    new i, j;
    
    // sorting
    if ( !bSorted ) {
        SortPlayersMVP( bRound, SORT_SI, bTeam, iTeam );
    }
    
    // prepare buffer(s) for printing
    BuildConsoleBufferSpecial( bRound, bTeam, iTeam );
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    
    Format( bufBasicHeader,
            CONBUFSIZE,
                                           "\n| Special -- %10s -- %11s       skts(full/hurt/melee); lvl(full/hurt); crwn(full/draw) |\n",
            ( bRound ) ? "This Round" : "ALL Rounds",
            ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
        );
    if ( !g_bSkillDetectLoaded ) {
        Format(bufBasicHeader, CONBUFSIZE, "%s| ( skill_detect library not loaded: most of these stats won't be tracked )                         |\n", bufBasicHeader);
    }
    //                                                             #### / ### / ###   ### / ###    ### / ###   ### / ###   ####   #### / ####
    Format(bufBasicHeader, CONBUFSIZE, "%s|---------------------------------------------------------------------------------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Skeets  fl/ht/ml | Levels    | Crowns    | Pops | Cuts / Self | DSs / M2s  |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|------------------|-----------|-----------|------|-------------|------------|", bufBasicHeader);
    
    if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
    if ( g_iConsoleBufChunks > -1 ) {
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                                     "%s\n|---------------------------------------------------------------------------------------------------|",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
    } else {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                     "%s\n| (nothing to display)                                                                              |%s",
                bufBasicHeader,
                                       "\n|---------------------------------------------------------------------------------------------------|"
            );
    }
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 ) {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) ) {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
}

// display infected skill stats
stock DisplayStatsInfected( client, bool:bRound = true, bool:bTeam = true, bool:bSorted = false, iTeam = -1 ) {
    new i, j;
    
    // sorting
    if ( !bSorted ) {
        SortPlayersMVP( bRound, SORT_INF, bTeam, iTeam );
    }
    
    // prepare buffer(s) for printing
    BuildConsoleBufferInfected( bRound, bTeam, iTeam );
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    
    Format( bufBasicHeader,
            CONBUFSIZE,
                                           "\n| Infected -- %10s -- %11s                                                     |\n",
            ( bRound ) ? "This Round" : "ALL Rounds",
            ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
        );
    if ( !g_bSkillDetectLoaded ) {
        Format(bufBasicHeader, CONBUFSIZE, "%s| ( skill_detect library not loaded: most of these stats won't be tracked )                |\n", bufBasicHeader);
    }
    //                                                              ##### / #####    #####       ### / ####      ####     ####   ####
    Format(bufBasicHeader, CONBUFSIZE, "%s|-------------------------------------------------------------------------------------------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Dmg  up / tot | Commons | Hunt DPs / dmg | DCharge | Spawns | Time |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------------|---------|----------------|---------|--------|------|", bufBasicHeader);
    
    if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
    if ( g_iConsoleBufChunks > -1 ) {
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                                     "%s\n|-------------------------------------------------------------------------------------------|",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
    } else {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                     "%s\n| (nothing to display)                                                                      |%s",
                bufBasicHeader,
                                       "\n|-------------------------------------------------------------------------------------------|"
            );
    }
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 ) {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) ) {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
}

// display tables of survivor friendly fire given/taken
stock DisplayStatsFriendlyFire ( client, bool:bRound = true, bool:bTeam = true, bool:bSorted = false, iTeam = -1 ) {
    new i, j;
    // iTeam: -1: current survivor team, 0/1: specific team
    
    // sorting
    if ( !bSorted ) {
        SortPlayersMVP( true, SORT_FF, bTeam, iTeam );
    }
    
    new team = ( iTeam != -1 ) ? iTeam : ( ( g_bSecondHalf && !g_bPlayersLeftStart ) ? ( (g_iCurTeam) ? 0 : 1 ) : g_iCurTeam );
    
    decl String:bufBasicHeader[CONBUFSIZE];
    
    // only show tables if there is FF damage
    new bool:bNoStatsToShow = true;
    if ( bRound ) {
        if ( bTeam ) {
            if ( g_strRoundData[g_iRound][team][rndFFDamageTotal] ) { bNoStatsToShow = false; }
        } else {
            if ( g_strRoundData[g_iRound][LTEAM_A][rndFFDamageTotal] || g_strRoundData[g_iRound][LTEAM_B][rndFFDamageTotal] ) { bNoStatsToShow = false; }
        }
    }
    else {
        if ( bTeam ) {
            if ( g_strAllRoundData[team][rndFFDamageTotal] ) { bNoStatsToShow = false; }
        } else {
            if ( g_strAllRoundData[LTEAM_A][rndFFDamageTotal] || g_strAllRoundData[LTEAM_B][rndFFDamageTotal] ) { bNoStatsToShow = false; }
        }
    }
    
    if ( bNoStatsToShow ) {
        Format(bufBasicHeader, CONBUFSIZE, "\nFF: No Friendly Fire done, not showing table.");
        g_iConsoleBufChunks = -1;
    }
    else {
        // prepare buffer(s) for printing
        BuildConsoleBufferFriendlyFireGiven( bRound, bTeam, iTeam );
        
        // friendly fire -- given
        Format( bufBasicHeader,
                CONBUFSIZE,
                                           "\n| Friendly Fire -- Given / Offenders -- %10s -- %11s                                      |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
        Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Total   || Shotgun | Bullets | Melee  | Fire   | On Incap | Other  || to Self |\n", bufBasicHeader);
        Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|", bufBasicHeader);
        
        if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
        if ( g_iConsoleBufChunks > -1 ) {
            Format( g_sConsoleBuf[g_iConsoleBufChunks],
                    CONBUFSIZELARGE,
                                         "%s\n|--------------------------------||---------------------------------------------------------||---------|",
                    g_sConsoleBuf[g_iConsoleBufChunks]
                );
        } else {
            Format( bufBasicHeader,
                    CONBUFSIZE,
                                         "%s\n| (nothing to display)                                                                                 |%s",
                    bufBasicHeader,
                                           "\n|------------------------------------------------------------------------------------------------------|"
                );
        }
    }

    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 ) {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) ) {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
    
    if ( bNoStatsToShow ) { return; }
    BuildConsoleBufferFriendlyFireTaken( bRound, bTeam, iTeam );
    
    // friendly fire -- taken
    Format(     bufBasicHeader,
                CONBUFSIZE,
                                       "\n| Friendly Fire -- Received / Victims -- %10s -- %11s                                     |\n",
                ( bRound ) ? "This Round" : "ALL Rounds",
                ( bTeam ) ? ( (team == LTEAM_A) ? "Team A     " : "Team B     " ) : "ALL Players"
            );
    Format(bufBasicHeader, CONBUFSIZE, "%s|--------------------------------||---------------------------------------------------------||---------|\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s| Name                 | Total   || Shotgun | Bullets | Melee  | Fire   | Incapped | Other  || Fall    |\n", bufBasicHeader);
    Format(bufBasicHeader, CONBUFSIZE, "%s|----------------------|---------||---------|---------|--------|--------|----------|--------||---------|", bufBasicHeader);
    
    if ( !strlen(g_sConsoleBuf[g_iConsoleBufChunks]) ) { g_iConsoleBufChunks--; }
    if ( g_iConsoleBufChunks > -1 ) {
        Format( g_sConsoleBuf[g_iConsoleBufChunks],
                CONBUFSIZELARGE,
                                     "%s\n|--------------------------------||---------------------------------------------------------||---------|\n",
                g_sConsoleBuf[g_iConsoleBufChunks]
            );
    } else {
        Format( bufBasicHeader,
                CONBUFSIZE,
                                     "%s\n| (nothing to display)                                                                                 |%s",
                bufBasicHeader,
                                       "\n|------------------------------------------------------------------------------------------------------|"
            );
    }
    
    
    if ( client == -2 ) {
        if ( g_hStatsFile != INVALID_HANDLE ) {
            ReplaceString(bufBasicHeader, CONBUFSIZE, "%%", "%");
            WriteFileString( g_hStatsFile, bufBasicHeader, false );
            WriteFileString( g_hStatsFile, "\n", false );
            for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                ReplaceString(g_sConsoleBuf[j], CONBUFSIZELARGE, "%%", "%");
                WriteFileString( g_hStatsFile, g_sConsoleBuf[j], false );
                WriteFileString( g_hStatsFile, "\n", false );
            }
            WriteFileString( g_hStatsFile, "\n", false );
        }
    }
    else if ( client == -1 ) {
        // print to all
        for ( i = 1; i <= MaxClients; i++ ) {
            if ( IS_VALID_INGAME( i ) && g_iCookieValue[i] == 0 ) {
                PrintToConsole(i, bufBasicHeader);
                for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
                    PrintToConsole( i, g_sConsoleBuf[j] );
                }
            }
        }
    }
    else if ( client == 0 ) {
        // print to server
        PrintToServer(bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToServer( g_sConsoleBuf[j] );
        }
    }
    else if ( IS_VALID_INGAME( client ) ) {
        PrintToConsole(client, bufBasicHeader);
        for ( j = 0; j <= g_iConsoleBufChunks; j++ ) {
            PrintToConsole( client, g_sConsoleBuf[j] );
        }
    }
}

/*
    Automatic display
    -----------------
*/
stock AutomaticRoundEndPrint ( bool:doDelay = true ) {
    // remember that we printed it this second
    g_iLastRoundEndPrint = GetTime();
    
    new Float:fDelay = ROUNDEND_DELAY;
    if ( g_bModeScavenge ) { fDelay = ROUNDEND_DELAY_SCAV; }
    
    if ( doDelay ) {
        CreateTimer( fDelay, Timer_AutomaticRoundEndPrint, _, TIMER_FLAG_NO_MAPCHANGE );
    }
    else {
        Timer_AutomaticRoundEndPrint(INVALID_HANDLE);
    }
}

public Action: Timer_AutomaticRoundEndPrint ( Handle:timer ) {
    new iFlags = GetConVarInt( ( g_bModeCampaign ) ? g_hCvarAutoPrintCoop : g_hCvarAutoPrintVs );
    
    // do automatic prints (only for clients that don't have cookie flags set)
    AutomaticPrintPerClient( iFlags, -1 );

    // for each client that has a cookie set, do the relevant reports
    for ( new client = 1; client <= MaxClients; client++ ) {
        if ( g_iCookieValue[client] > 0 ) {
            AutomaticPrintPerClient( g_iCookieValue[client], client );
        }
    }
}

// set iTeam to -2 to force printing for all players (where possible) (-1 = current team) - setting client to -2 prints to file (and never needs a delay)
stock AutomaticPrintPerClient( iFlags, client = -1, iTeam = -1, bool: bNoDelay = false, bool:bPreSorted = false, bool:bSortedRound = false, bool:bSortedGame = false ) {
    // prints automatic stuff, optionally for one client only
    new bool: bSorted;
    new bool: bSortedForGame;
    
    if ( bPreSorted ) {
        bSorted = bSortedRound;
        bSortedForGame = bSortedGame;
    }
    else {
        bSorted = (iFlags & AUTO_MVPCON_ROUND) || (iFlags & AUTO_MVPCON_GAME) || (iFlags & AUTO_MVPCON_TANK) || (iFlags & AUTO_MVPCON_MORE_ROUND);
        bSortedForGame = false;
    }
    
    new Float: fDelay, bool: bAddDelay, iDelayedFlags; 
    new Handle: pack[6];
    
    new bool: bTeam = true;
    
    if ( iTeam == -2 ) {
        // force for all
        bTeam = false;
        iTeam = -1;
    }
    else if ( iTeam == -1 ) {
        // force current team
        iTeam = g_iCurTeam;
    }
    
    if ( client == -2 ) {
        bNoDelay = true;
    }
    
    // mvp
    if ( iFlags & AUTO_MVPCON_ROUND ) {
        bAddDelay = true;
        DisplayStatsMVP(client, false, false, true, bTeam, iTeam );
    }
    if ( iFlags & AUTO_MVPCON_GAME ) {
        bAddDelay = true;
        DisplayStatsMVP(client, false, false, false, bTeam, iTeam );
        bSortedForGame = true;
    }
    
    // send delayed prints
    if ( iDelayedFlags ) {
        pack[4] = CreateDataPack();
        WritePackCell( pack[4], iDelayedFlags );
        WritePackCell( pack[4], client );
        WritePackCell( pack[4], iTeam );
        WritePackCell( pack[4], (bSorted) ? 1 : 0 );
        WritePackCell( pack[4], (bSortedForGame) ? 1 : 0 );
        CreateTimer( fDelay, Timer_DelayedPrint, pack[4] );
        iDelayedFlags = 0;
    }
    if ( bAddDelay ) {
        fDelay += PRINT_DELAY_INC;
        bAddDelay = false;
    }
    
    if ( iFlags & AUTO_MVPCON_MORE_ROUND ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_MVPCON_MORE_ROUND;
        } else {
            DisplayStatsMVP(client, false, true, true, bTeam, iTeam );
        }
        
    }
    if ( iFlags & AUTO_MVPCON_MORE_GAME ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_MVPCON_MORE_GAME;
        } else {
            DisplayStatsMVP(client, false, true, false, bTeam, iTeam );
        }
        bSortedForGame = true;
    }
    
    if ( iFlags & AUTO_MVPCON_TANK ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_MVPCON_TANK;
        } else {
            DisplayStatsMVP(client, true, false, true, bTeam, iTeam );
        }
    }
    
    // send delayed prints
    if ( iDelayedFlags ) {
        pack[0] = CreateDataPack();
        WritePackCell( pack[0], iDelayedFlags );
        WritePackCell( pack[0], client );
        WritePackCell( pack[0], iTeam );
        WritePackCell( pack[0], (bSorted) ? 1 : 0 );
        WritePackCell( pack[0], (bSortedForGame) ? 1 : 0 );
        CreateTimer( fDelay, Timer_DelayedPrint, pack[0] );
        iDelayedFlags = 0;
    }
    if ( bAddDelay ) {
        fDelay += PRINT_DELAY_INC;
        bAddDelay = false;
    }
    
    if ( iFlags & AUTO_MVPCHAT_ROUND ) {
        if ( !bSorted || bSortedForGame ) {
            // not sorted yet, sort for SI [round]
            SortPlayersMVP( true, SORT_SI );
            bSorted = true;
        }
        DisplayStatsMVPChat(client, true);
    }
    if ( iFlags & AUTO_MVPCHAT_GAME ) {
        if ( !bSorted || !bSortedForGame ) {
            // not sorted yet, sort for SI
            bSortedForGame = true;
            SortPlayersMVP( false, SORT_SI );
            bSorted = true;
        }
        DisplayStatsMVPChat(client, false);
    }
    
    // fun fact
    if ( iFlags & AUTO_FUNFACT_ROUND ) {
        DisplayStatsFunFactChat( client, true, bTeam, iTeam );
    }
    if ( iFlags & AUTO_FUNFACT_GAME ) {
        DisplayStatsFunFactChat( client, false, bTeam, iTeam );
    }
    
    
    // special / skill
    if ( iFlags & AUTO_SKILLCON_ROUND ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_SKILLCON_ROUND;
        } else {
            DisplayStatsSpecial(client, true, bTeam, false, iTeam );
        }
    }
    if ( iFlags & AUTO_SKILLCON_GAME ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_SKILLCON_GAME;
        } else {
            DisplayStatsSpecial(client, false, bTeam, false, iTeam );
        }
    }
    
    // send delayed prints
    if ( iDelayedFlags ) {
        pack[1] = CreateDataPack();
        WritePackCell( pack[1], iDelayedFlags );
        WritePackCell( pack[1], client );
        WritePackCell( pack[1], iTeam );
        WritePackCell( pack[1], (bSorted) ? 1 : 0 );
        WritePackCell( pack[1], (bSortedForGame) ? 1 : 0 );
        CreateTimer( fDelay, Timer_DelayedPrint, pack[1] );
        iDelayedFlags = 0;
    }
    if ( bAddDelay ) {
        fDelay += PRINT_DELAY_INC;
        bAddDelay = false;
    }
    
    
    // infected
    if ( iFlags & AUTO_INFCON_ROUND ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_INFCON_ROUND;
        } else {
            DisplayStatsInfected(client, true, bTeam, false, iTeam );
        }
    }
    if ( iFlags & AUTO_INFCON_GAME ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_INFCON_GAME;
        } else {
            DisplayStatsInfected(client, false, bTeam, false, iTeam );
        }
    }
    
    // send delayed prints
    if ( iDelayedFlags ) {
        pack[5] = CreateDataPack();
        WritePackCell( pack[5], iDelayedFlags );
        WritePackCell( pack[5], client );
        WritePackCell( pack[5], iTeam );
        WritePackCell( pack[5], (bSorted) ? 1 : 0 );
        WritePackCell( pack[5], (bSortedForGame) ? 1 : 0 );
        CreateTimer( fDelay, Timer_DelayedPrint, pack[5] );
        iDelayedFlags = 0;
    }
    if ( bAddDelay ) {
        fDelay += PRINT_DELAY_INC;
        bAddDelay = false;
    }
    
    // ff
    if ( iFlags & AUTO_FFCON_ROUND ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_FFCON_ROUND;
        } else {
            DisplayStatsFriendlyFire(client, true, bTeam, (bSorted && !bSortedForGame), iTeam );
        }
    }
    if ( iFlags & AUTO_FFCON_GAME ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_FFCON_GAME;
        } else {
            DisplayStatsFriendlyFire(client, false, bTeam, (bSorted && bSortedForGame), iTeam );
        }
    }
    
    // send delayed prints
    if ( iDelayedFlags ) {
        pack[2] = CreateDataPack();
        WritePackCell( pack[2], iDelayedFlags );
        WritePackCell( pack[2], client );
        WritePackCell( pack[2], iTeam );
        WritePackCell( pack[2], (bSorted) ? 1 : 0 );
        WritePackCell( pack[2], (bSortedForGame) ? 1 : 0 );
        CreateTimer( fDelay, Timer_DelayedPrint, pack[2] );
        iDelayedFlags = 0;
    }
    if ( bAddDelay ) {
        fDelay += PRINT_DELAY_INC;
        bAddDelay = false;
    }
    
    // accuracy
    if ( iFlags & AUTO_ACCCON_ROUND ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_ACCCON_ROUND;
        } else {
            DisplayStatsAccuracy(client, false, true, bTeam, (bSorted && !bSortedForGame), iTeam );
        }
    }
    if ( iFlags & AUTO_ACCCON_GAME ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_ACCCON_GAME;
        } else {
            DisplayStatsAccuracy(client, false, false, bTeam, (bSorted && bSortedForGame), iTeam );
        }
    }
    if ( iFlags & AUTO_ACCCON_MORE_ROUND ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_ACCCON_MORE_ROUND;
        } else {
            DisplayStatsAccuracy(client, true, true, bTeam, (bSorted && !bSortedForGame), iTeam );
        }
    }
    if ( iFlags & AUTO_ACCCON_MORE_GAME ) {
        bAddDelay = true;
        if ( !bNoDelay && fDelay > 0.0 ) {
            iDelayedFlags += AUTO_ACCCON_MORE_GAME;
        } else {
            DisplayStatsAccuracy(client, true, false, bTeam, (bSorted && bSortedForGame), iTeam );
        }
    }
    
    // send delayed prints
    if ( iDelayedFlags ) {
        pack[3] = CreateDataPack();
        WritePackCell( pack[3], iDelayedFlags );
        WritePackCell( pack[3], client );
        WritePackCell( pack[3], iTeam );
        WritePackCell( pack[3], (bSorted) ? 1 : 0 );
        WritePackCell( pack[3], (bSortedForGame) ? 1 : 0 );
        CreateTimer( fDelay, Timer_DelayedPrint, pack[3] );
        iDelayedFlags = 0;
    }
    if ( bAddDelay ) {
        fDelay += PRINT_DELAY_INC;
        bAddDelay = false;
    }
    
    // to do:
    // - inf
}

public Action: Timer_DelayedPrint( Handle:timer, Handle:pack ) {
    ResetPack( pack );
    new flags = ReadPackCell( pack );
    new client = ReadPackCell( pack );
    new team = ReadPackCell( pack );
    new bool: bSortedRound = bool:( ReadPackCell( pack ) );
    new bool: bSortedGame = bool:( ReadPackCell( pack ) );
    CloseHandle( pack );
    
    // send non-recursive print call ('first' true must be set for no further delays)
    AutomaticPrintPerClient( flags, client, team, true, true, bSortedRound, bSortedGame );
}