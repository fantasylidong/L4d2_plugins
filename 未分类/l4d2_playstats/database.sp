#if defined _l4d2_playstats_database_included
 #endinput
#endif

#define _l4d2_playstats_database_included

#include <sourcemod>

InitDatabase() {
    GetConVarString(g_hCvarDatabaseConfig, g_sDatabaseConfig, sizeof(g_sDatabaseConfig));
    if (db != INVALID_HANDLE) {
        CloseHandle(db);
        db = INVALID_HANDLE;
    }
    db = SQL_Connect(g_sDatabaseConfig, false, errorBuffer, sizeof(errorBuffer));
    PrintDebug( 1, "[InitDatabase] g_sDatabaseConfig: %s", g_sDatabaseConfig );
    if (db == INVALID_HANDLE) {
        PrintToServer("Could not connect: %s", errorBuffer);
    }
    else {
        SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS `round` ( \
        `id` INT NOT NULL auto_increment, \
        `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
        `matchId` INT, \
        `round` INT, \
        `team` INT, \
        `map` varchar(64), \
        `deleted` BOOLEAN, \
        `isSecondHalf` BOOLEAN, \
        `teamIsA` BOOLEAN, \
        `teamARound` INT, \
        `teamATotal` INT, \
        `teamBRound` INT, \
        `teamBTotal` INT, \
        `survivorCount` INT, \
        `maxCompletionScore` INT, \
        `maxFlowDist` INT, \
        `rndRestarts` INT, \
        `rndPillsUsed` INT, \
        `rndKitsUsed` INT, \
        `rndDefibsUsed` INT, \
        `rndCommon` INT, \
        `rndSIKilled` INT, \
        `rndSIDamage` INT, \
        `rndSISpawned` INT, \
        `rndWitchKilled` INT, \
        `rndTankKilled` INT, \
        `rndIncaps` INT, \
        `rndDeaths` INT, \
        `rndFFDamageTotal` INT, \
        `rndStartTime` INT, \
        `rndEndTime` INT, \
        `rndStartTimePause` INT, \
        `rndStopTimePause` INT, \
        `rndStartTimeTank` INT, \
        `rndStopTimeTank` INT, \
        `configName` varchar(64), \
        PRIMARY KEY  (`id`) \
        );");
        
        SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS `survivor` ( \
        `id` INT NOT NULL auto_increment, \
        `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
        `matchId` INT, \
        `round` INT, \
        `team` INT, \
        `map` varchar(64), \
        `steamid` varchar(32), \
        `deleted` BOOLEAN, \
        `isSecondHalf` BOOLEAN, \
        `plyShotsShotgun` INT, \
        `plyShotsSmg` INT, \
        `plyShotsSniper` INT, \
        `plyShotsPistol` INT, \
        `plyHitsShotgun` INT, \
        `plyHitsSmg` INT, \
        `plyHitsSniper` INT, \
        `plyHitsPistol` INT, \
        `plyHeadshotsSmg` INT, \
        `plyHeadshotsSniper` INT, \
        `plyHeadshotsPistol` INT, \
        `plyHeadshotsSISmg` INT, \
        `plyHeadshotsSISniper` INT, \
        `plyHeadshotsSIPistol` INT, \
        `plyHitsSIShotgun` INT, \
        `plyHitsSISmg` INT, \
        `plyHitsSISniper` INT, \
        `plyHitsSIPistol` INT, \
        `plyHitsTankShotgun` INT, \
        `plyHitsTankSmg` INT, \
        `plyHitsTankSniper` INT, \
        `plyHitsTankPistol` INT, \
        `plyCommon` INT, \
        `plyCommonTankUp` INT, \
        `plySIKilled` INT, \
        `plySIKilledTankUp` INT, \
        `plySIDamage` INT, \
        `plySIDamageTankUp` INT, \
        `plyIncaps` INT, \
        `plyDied` INT, \
        `plySkeets` INT, \
        `plySkeetsHurt` INT, \
        `plySkeetsMelee` INT, \
        `plyLevels` INT, \
        `plyLevelsHurt` INT, \
        `plyPops` INT, \
        `plyCrowns` INT, \
        `plyCrownsHurt` INT, \
        `plyShoves` INT, \
        `plyDeadStops` INT, \
        `plyTongueCuts` INT, \
        `plySelfClears` INT, \
        `plyFallDamage` INT, \
        `plyDmgTaken` INT, \
        `plyDmgTakenBoom` INT, \
        `plyDmgTakenCommon` INT, \
        `plyDmgTakenTank` INT, \
        `plyBowls` INT, \
        `plyCharges` INT, \
        `plyDeathCharges` INT, \
        `plyFFGiven` INT, \
        `plyFFTaken` INT, \
        `plyFFHits` INT, \
        `plyTankDamage` INT, \
        `plyWitchDamage` INT, \
        `plyMeleesOnTank` INT, \
        `plyRockSkeets` INT, \
        `plyRockEats` INT, \
        `plyFFGivenPellet` INT, \
        `plyFFGivenBullet` INT, \
        `plyFFGivenSniper` INT, \
        `plyFFGivenMelee` INT, \
        `plyFFGivenFire` INT, \
        `plyFFGivenIncap` INT, \
        `plyFFGivenOther` INT, \
        `plyFFGivenSelf` INT, \
        `plyFFTakenPellet` INT, \
        `plyFFTakenBullet` INT, \
        `plyFFTakenSniper` INT, \
        `plyFFTakenMelee` INT, \
        `plyFFTakenFire` INT, \
        `plyFFTakenIncap` INT, \
        `plyFFTakenOther` INT, \
        `plyFFGivenTotal` INT, \
        `plyFFTakenTotal` INT, \
        `plyCarsTriggered` INT, \
        `plyJockeyRideDuration` INT, \
        `plyJockeyRideTotal` INT, \
        `plyClears` INT, \
        `plyAvgClearTime` INT, \
        `plyTimeStartPresent` INT, \
        `plyTimeStopPresent` INT, \
        `plyTimeStartAlive` INT, \
        `plyTimeStopAlive` INT, \
        `plyTimeStartUpright` INT, \
        `plyTimeStopUpright` INT, \
        `plyCurFlowDist` INT, \
        `plyFarFlowDist` INT, \
        `plyProtectAwards` INT, \
        PRIMARY KEY  (`id`) \
        );");
        
        SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS `infected` ( \
        `id` INT NOT NULL auto_increment, \
        `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
        `matchId` INT, \
        `round` INT, \
        `team` INT, \
        `map` varchar(64), \
        `steamid` varchar(32), \
        `deleted` BOOLEAN, \
        `isSecondHalf` BOOLEAN, \
        `infDmgTotal` INT, \
        `infDmgUpright` INT, \
        `infDmgTank` INT, \
        `infDmgTankIncap` INT, \
        `infDmgScratch` INT, \
        `infDmgScratchSmoker` INT, \
        `infDmgScratchBoomer` INT, \
        `infDmgScratchHunter` INT, \
        `infDmgScratchCharger` INT, \
        `infDmgScratchSpitter` INT, \
        `infDmgScratchJockey` INT, \
        `infDmgSpit` INT, \
        `infDmgBoom` INT, \
        `infDmgTankUp` INT, \
        `infHunterDPs` INT, \
        `infHunterDPDmg` INT, \
        `infJockeyDPs` INT, \
        `infDeathCharges` INT, \
        `infCharges` INT, \
        `infMultiCharges` INT, \
        `infBoomsSingle` INT, \
        `infBoomsDouble` INT, \
        `infBoomsTriple` INT, \
        `infBoomsQuad` INT, \
        `infBooms` INT, \
        `infBoomerPops` INT, \
        `infLedged` INT, \
        `infCommon` INT, \
        `infSpawns` INT, \
        `infSpawnSmoker` INT, \
        `infSpawnBoomer` INT, \
        `infSpawnHunter` INT, \
        `infSpawnCharger` INT, \
        `infSpawnSpitter` INT, \
        `infSpawnJockey` INT, \
        `infTankPasses` INT, \
        `infTankRockHits` INT, \
        `infCarsTriggered` INT, \
        `infJockeyRideDuration` INT, \
        `infJockeyRideTotal` INT, \
        `infTimeStartPresent` INT, \
        `infTimeStopPresent` INT, \
        PRIMARY KEY  (`id`) \
        );");
        
        SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS `matchlog` ( \
        `id` INT NOT NULL auto_increment, \
        `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
        `matchId` INT, \
        `map` varchar(64), \
        `deleted` BOOLEAN, \
        `result` INT, \
        `steamid` varchar(32), \
        `startedAt` INT, \
        `endedAt` INT, \
        `team` INT, \
        `configName` varchar(64), \
        PRIMARY KEY  (`id`) \
        );");
        
        SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS `pvp_ff` ( \
        `id` INT NOT NULL auto_increment, \
        `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
        `matchId` INT, \
        `round` INT, \
        `team` INT, \
        `map` varchar(64), \
        `steamid` varchar(32), \
        `deleted` BOOLEAN, \
        `isSecondHalf` BOOLEAN, \
        `victim` varchar(32), \
        `damage` INT, \
        PRIMARY KEY  (`id`) \
        );");
        
        SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS `pvp_infdmg` ( \
        `id` INT NOT NULL auto_increment, \
        `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
        `matchId` INT, \
        `round` INT, \
        `team` INT, \
        `map` varchar(64), \
        `steamid` varchar(32), \
        `deleted` BOOLEAN, \
        `isSecondHalf` BOOLEAN, \
        `victim` varchar(32), \
        `damage` INT, \
        PRIMARY KEY  (`id`) \
        );");
    }
}

InitQueries() {
    if (hRoundStmt != INVALID_HANDLE) {
        CloseHandle(hRoundStmt);
        hRoundStmt = INVALID_HANDLE;
    }
    if ( hRoundStmt == INVALID_HANDLE ) {
        hRoundStmt = SQL_PrepareQuery(db, "INSERT INTO round ( \
        id, \
        createdAt, \
        matchId, \
        round, \
        team, \
        map, \
        deleted, \
        isSecondHalf, \
        teamIsA, \
        teamARound, \
        teamATotal, \
        teamBRound, \
        teamBTotal, \
        survivorCount, \
        maxCompletionScore, \
        maxFlowDist, \
        configName, \
        rndRestarts, \
        rndPillsUsed, \
        rndKitsUsed, \
        rndDefibsUsed, \
        rndCommon, \
        rndSIKilled, \
        rndSIDamage, \
        rndSISpawned, \
        rndWitchKilled, \
        rndTankKilled, \
        rndIncaps, \
        rndDeaths, \
        rndFFDamageTotal, \
        rndStartTime, \
        rndEndTime, \
        rndStartTimePause, \
        rndStopTimePause, \
        rndStartTimeTank, \
        rndStopTimeTank \
        ) VALUES ( NULL, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,? \
        )", errorBuffer, sizeof(errorBuffer));

        if ( hRoundStmt == INVALID_HANDLE ) {
            PrintDebug( 1, "[Stats] Prepare round query failed. %s", errorBuffer );
        }
        else {
            PrintDebug( 1, "[Stats] Prepare round query success." );
        }
    }
    
    if (hSurvivorStmt != INVALID_HANDLE) {
        CloseHandle(hSurvivorStmt);
        hSurvivorStmt = INVALID_HANDLE;
    }
    if ( hSurvivorStmt == INVALID_HANDLE ) {
        hSurvivorStmt = SQL_PrepareQuery(db, "INSERT INTO survivor ( \
        id, \
        createdAt, \
        matchId, \
        round, \
        team, \
        map, \
        steamid, \
        deleted, \
        isSecondHalf, \
        plyShotsShotgun, \
        plyShotsSmg, \
        plyShotsSniper, \
        plyShotsPistol, \
        plyHitsShotgun, \
        plyHitsSmg, \
        plyHitsSniper, \
        plyHitsPistol, \
        plyHeadshotsSmg, \
        plyHeadshotsSniper, \
        plyHeadshotsPistol, \
        plyHeadshotsSISmg, \
        plyHeadshotsSISniper, \
        plyHeadshotsSIPistol, \
        plyHitsSIShotgun, \
        plyHitsSISmg, \
        plyHitsSISniper, \
        plyHitsSIPistol, \
        plyHitsTankShotgun, \
        plyHitsTankSmg, \
        plyHitsTankSniper, \
        plyHitsTankPistol, \
        plyCommon, \
        plyCommonTankUp, \
        plySIKilled, \
        plySIKilledTankUp, \
        plySIDamage, \
        plySIDamageTankUp, \
        plyIncaps, \
        plyDied, \
        plySkeets, \
        plySkeetsHurt, \
        plySkeetsMelee, \
        plyLevels, \
        plyLevelsHurt, \
        plyPops, \
        plyCrowns, \
        plyCrownsHurt, \
        plyShoves, \
        plyDeadStops, \
        plyTongueCuts, \
        plySelfClears, \
        plyFallDamage, \
        plyDmgTaken, \
        plyDmgTakenBoom, \
        plyDmgTakenCommon, \
        plyDmgTakenTank, \
        plyBowls, \
        plyCharges, \
        plyDeathCharges, \
        plyFFGiven, \
        plyFFTaken, \
        plyFFHits, \
        plyTankDamage, \
        plyWitchDamage, \
        plyMeleesOnTank, \
        plyRockSkeets, \
        plyRockEats, \
        plyFFGivenPellet, \
        plyFFGivenBullet, \
        plyFFGivenSniper, \
        plyFFGivenMelee, \
        plyFFGivenFire, \
        plyFFGivenIncap, \
        plyFFGivenOther, \
        plyFFGivenSelf, \
        plyFFTakenPellet, \
        plyFFTakenBullet, \
        plyFFTakenSniper, \
        plyFFTakenMelee, \
        plyFFTakenFire, \
        plyFFTakenIncap, \
        plyFFTakenOther, \
        plyFFGivenTotal, \
        plyFFTakenTotal, \
        plyCarsTriggered, \
        plyJockeyRideDuration, \
        plyJockeyRideTotal, \
        plyClears, \
        plyAvgClearTime, \
        plyTimeStartPresent, \
        plyTimeStopPresent, \
        plyTimeStartAlive, \
        plyTimeStopAlive, \
        plyTimeStartUpright, \
        plyTimeStopUpright, \
        plyCurFlowDist, \
        plyFarFlowDist, \
        plyProtectAwards \
        ) VALUES ( NULL, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,? \
        )", errorBuffer, sizeof(errorBuffer));

        if ( hSurvivorStmt == INVALID_HANDLE ) {
            PrintDebug( 1, "[Stats] Prepare survivor query failed. %s", errorBuffer );
        }
        else {
            PrintDebug( 1, "[Stats] Prepare survivor query success." );
        }
    }

    if (hInfectedStmt != INVALID_HANDLE) {
        CloseHandle(hInfectedStmt);
        hInfectedStmt = INVALID_HANDLE;
    }
    if ( hInfectedStmt == INVALID_HANDLE ) {
        hInfectedStmt = SQL_PrepareQuery(db, "INSERT INTO infected ( \
        id, \
        createdAt, \
        matchId, \
        round, \
        team, \
        map, \
        steamid, \
        deleted, \
        isSecondHalf, \
        infDmgTotal, \
        infDmgUpright, \
        infDmgTank, \
        infDmgTankIncap, \
        infDmgScratch, \
        infDmgScratchSmoker, \
        infDmgScratchBoomer, \
        infDmgScratchHunter, \
        infDmgScratchCharger, \
        infDmgScratchSpitter, \
        infDmgScratchJockey, \
        infDmgSpit, \
        infDmgBoom, \
        infDmgTankUp, \
        infHunterDPs, \
        infHunterDPDmg, \
        infJockeyDPs, \
        infDeathCharges, \
        infCharges, \
        infMultiCharges, \
        infBoomsSingle, \
        infBoomsDouble, \
        infBoomsTriple, \
        infBoomsQuad, \
        infBooms, \
        infBoomerPops, \
        infLedged, \
        infCommon, \
        infSpawns, \
        infSpawnSmoker, \
        infSpawnBoomer, \
        infSpawnHunter, \
        infSpawnCharger, \
        infSpawnSpitter, \
        infSpawnJockey, \
        infTankPasses, \
        infTankRockHits, \
        infCarsTriggered, \
        infJockeyRideDuration, \
        infJockeyRideTotal, \
        infTimeStartPresent, \
        infTimeStopPresent \
        ) VALUES ( NULL, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,?, \
            ?,?,?,?,?,?,?,?,?,? \
        )", errorBuffer, sizeof(errorBuffer));

        if ( hInfectedStmt == INVALID_HANDLE ) {
            PrintDebug( 1, "[Stats] Prepare infected query failed. %s", errorBuffer );
        }
        else {
            PrintDebug( 1, "[Stats] Prepare infected query success." );
        }
    }

    if (hMatchStmt != INVALID_HANDLE) {
        CloseHandle(hMatchStmt);
        hMatchStmt = INVALID_HANDLE;
    }
    if ( hMatchStmt == INVALID_HANDLE ) {
        hMatchStmt = SQL_PrepareQuery(db, "INSERT INTO matchlog ( \
        id, \
        createdAt, \
        matchId, \
        map, \
        deleted, \
        result, \
        steamid, \
        startedAt, \
        endedAt, \
        team, \
        configName \
        ) VALUES ( NULL, \
            ?,?,?,?,?,?,?,?,?,? \
        )", errorBuffer, sizeof(errorBuffer));

        if ( hMatchStmt == INVALID_HANDLE ) {
            PrintDebug( 1, "[Stats] Prepare match query failed. %s", errorBuffer );
        }
        else {
            PrintDebug( 1, "[Stats] Prepare match query success." );
        }
    }

    if (hPvPFFStmt != INVALID_HANDLE) {
        CloseHandle(hPvPFFStmt);
        hPvPFFStmt = INVALID_HANDLE;
    }
    if ( hPvPFFStmt == INVALID_HANDLE ) {
        hPvPFFStmt = SQL_PrepareQuery(db, "INSERT INTO pvp_ff ( \
        id, \
        createdAt, \
        matchId, \
        round, \
        team, \
        map, \
        steamid, \
        deleted, \
        isSecondHalf, \
        victim, \
        damage \
        ) VALUES ( NULL, \
            ?,?,?,?,?,?,?,?,?,? \
        )", errorBuffer, sizeof(errorBuffer));

        if ( hPvPFFStmt == INVALID_HANDLE ) {
            PrintDebug( 1, "[Stats] Prepare pvp ff query failed. %s", errorBuffer );
        }
        else {
            PrintDebug( 1, "[Stats] Prepare pvp ff query success." );
        }
    }

    if (hPvPInfDmgStmt != INVALID_HANDLE) {
        CloseHandle(hPvPInfDmgStmt);
        hPvPInfDmgStmt = INVALID_HANDLE;
    }
    if ( hPvPInfDmgStmt == INVALID_HANDLE ) {
        hPvPInfDmgStmt = SQL_PrepareQuery(db, "INSERT INTO pvp_infdmg ( \
        id, \
        createdAt, \
        matchId, \
        round, \
        team, \
        map, \
        steamid, \
        deleted, \
        isSecondHalf, \
        victim, \
        damage \
        ) VALUES ( NULL, \
            ?,?,?,?,?,?,?,?,?,? \
        )", errorBuffer, sizeof(errorBuffer));

        if ( hPvPInfDmgStmt == INVALID_HANDLE ) {
            PrintDebug( 1, "[Stats] Prepare pvp ff query failed. %s", errorBuffer );
        }
        else {
            PrintDebug( 1, "[Stats] Prepare pvp ff query success." );
        }
    }
}

// write round stats to database
stock WriteStatsToDB( iTeam, bool:bSecondHalf ) {
    if ( g_bModeCampaign ) { return; }

    if (db == INVALID_HANDLE) {
        PrintToServer("[Stats] DB is null");
        PrintDebug( 1, "[Stats] DB is null" );
        return;
    }
    PrintToServer("[Stats] Saving to database");
    PrintDebug( 1, "[Stats] Saving to database" );

    decl String: sTmpMap[64];
    GetCurrentMapLower( sTmpMap, sizeof(sTmpMap) );
    PrintDebug( 1, "[Stats] Map %s", sTmpMap );
    decl String: sTmpTime[20];
    FormatTime( sTmpTime, sizeof(sTmpTime), "%Y-%m-%d %H:%M:%S" );
    PrintDebug( 1, "[Stats] Time %s", sTmpTime );
    PrintDebug( 1, "[Stats] IsMissionFinalMap %i", IsMissionFinalMap() );
    PrintDebug( 1, "[Stats] bSecondHalf %i", bSecondHalf );

    decl String:cfgString[64];
    cfgString[0] = '\0';
    GetConVarString(g_hCvarCustomConfig, cfgString, sizeof(cfgString));
    PrintDebug( 1, "[Stats] g_hCvarCustomConfig %s", cfgString );
    
    new matchId = g_strRoundData[0][0][rndStartTime];
    new startedAt = MIN( g_strRoundData[0][0][rndStartTime], g_strRoundData[0][1][rndStartTime] );
    new endedAt = MAX( g_strRoundData[g_iRound][0][rndEndTime], g_strRoundData[g_iRound][1][rndEndTime] );
    new result = 0;
    
    // round data
    new i;
    if ( hRoundStmt == INVALID_HANDLE ) {
        PrintDebug( 1, "[Stats] Round query invalid." );
    }

    SQL_BindParamString(hRoundStmt, 0, sTmpTime, false);
    SQL_BindParamInt(hRoundStmt, 1, matchId, true);
    SQL_BindParamInt(hRoundStmt, 2, g_iRound, true);
    SQL_BindParamInt(hRoundStmt, 3, iTeam, true);
    SQL_BindParamString(hRoundStmt, 4, sTmpMap, false);
    SQL_BindParamInt(hRoundStmt, 5, 0, true);
    SQL_BindParamInt(hRoundStmt, 6, g_bSecondHalf, true);
    SQL_BindParamInt(hRoundStmt, 7, iTeam == LTEAM_A, true);
    SQL_BindParamInt(hRoundStmt, 8, g_iScores[LTEAM_A] - g_iFirstScoresSet[((g_bCMTSwapped)?1:0)], true);
    SQL_BindParamInt(hRoundStmt, 9, g_iScores[LTEAM_A], true);
    SQL_BindParamInt(hRoundStmt, 10, g_iScores[LTEAM_B] - g_iFirstScoresSet[((g_bCMTSwapped)?0:1)], true);
    SQL_BindParamInt(hRoundStmt, 11, g_iScores[LTEAM_B], true);
    SQL_BindParamInt(hRoundStmt, 12, g_iSurvived[iTeam], true);
    SQL_BindParamInt(hRoundStmt, 13, L4D_GetVersusMaxCompletionScore(), true);
    SQL_BindParamInt(hRoundStmt, 14, RoundFloat(L4D2Direct_GetMapMaxFlowDistance()), true);
    SQL_BindParamString(hRoundStmt, 15, cfgString, false);

    for ( i = 0; i <= MAXRNDSTATS; i++ ) {
        SQL_BindParamInt(hRoundStmt, i+16, g_strRoundData[g_iRound][iTeam][i], true);
    }
    if (!SQL_Execute(hRoundStmt)) {
        PrintToChatAll("[Stats] Failed to save round stats.");
    }
    
    // player data
    new j;
    new iPlayerCount = 0;
    for ( j = FIRST_NON_BOT; j < g_iPlayers; j++ ) {
        if ( g_iPlayerRoundTeam[iTeam][j] != iTeam ) { continue; }
        iPlayerCount++;

        SQL_BindParamString(hSurvivorStmt, 0, sTmpTime, false);
        SQL_BindParamInt(hSurvivorStmt, 1, matchId, true);
        SQL_BindParamInt(hSurvivorStmt, 2, g_iRound, true);
        SQL_BindParamInt(hSurvivorStmt, 3, iTeam, true);
        SQL_BindParamString(hSurvivorStmt, 4, sTmpMap, false);
        SQL_BindParamString(hSurvivorStmt, 5, g_sPlayerId[j], false);
        SQL_BindParamInt(hSurvivorStmt, 6, 0, true);
        SQL_BindParamInt(hSurvivorStmt, 7, g_bSecondHalf, true);

        for ( i = 0; i <= MAXPLYSTATS; i++ ) {
            SQL_BindParamInt(hSurvivorStmt, i+8, g_strRoundPlayerData[j][iTeam][i], true);
        }
        if (!SQL_Execute(hSurvivorStmt)) {
            PrintToChatAll("[Stats] Failed to save survivor stats for %s.", g_sPlayerId[j]);
            PrintDebug(1, "[Stats] Failed to save survivor stats for %s.", g_sPlayerId[j]);
        }
        
        if (IsMissionFinalMap() && bSecondHalf) {
            if (g_iScores[iTeam] > g_iScores[(iTeam) ? 0 : 1]) {
                result = 1;
            }
            else if (g_iScores[iTeam] < g_iScores[(iTeam) ? 0 : 1]) {
                result = -1;
            }
            else {
                result = 0;
            }
            WriteMatchLogToDB(sTmpTime, matchId, sTmpMap, result, g_sPlayerId[j], startedAt, endedAt, iTeam, cfgString);
        }
    }

    // infected player data
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

        SQL_BindParamString(hInfectedStmt, 0, sTmpTime, false);
        SQL_BindParamInt(hInfectedStmt, 1, matchId, true);
        SQL_BindParamInt(hInfectedStmt, 2, g_iRound, true);
        SQL_BindParamInt(hInfectedStmt, 3, iTeam, true);
        SQL_BindParamString(hInfectedStmt, 4, sTmpMap, false);
        SQL_BindParamString(hInfectedStmt, 5, g_sPlayerId[j], false);
        SQL_BindParamInt(hInfectedStmt, 6, 0, true);
        SQL_BindParamInt(hInfectedStmt, 7, g_bSecondHalf, true);
        
        for ( i = 0; i <= MAXINFSTATS; i++ ) {
            SQL_BindParamInt(hInfectedStmt, i+8, g_strRoundPlayerInfData[j][iTeam][i], true);
        }
        if (!SQL_Execute(hInfectedStmt)) {
            PrintToChatAll("[Stats] Failed to save infected stats for %s.", g_sPlayerId[j]);
            PrintDebug(1, "[Stats] Failed to save infected stats for %s.", g_sPlayerId[j]);
        }
        
        if (IsMissionFinalMap() && bSecondHalf) {
            if (g_iScores[iTeam] < g_iScores[(iTeam) ? 0 : 1]) {
                result = 1;
            }
            else if (g_iScores[iTeam] > g_iScores[(iTeam) ? 0 : 1]) {
                result = -1;
            }
            else {
                result = 0;
            }
            WriteMatchLogToDB(sTmpTime, matchId, sTmpMap, result, g_sPlayerId[j], startedAt, endedAt, (iTeam) ? 0 : 1, cfgString);
        }
    }

    // player ff data
    iPlayerCount = 0;
    for ( j = FIRST_NON_BOT; j < g_iPlayers; j++ ) {
        if ( g_iPlayerRoundTeam[iTeam][j] != iTeam ) { continue; }
        iPlayerCount++;

        SQL_BindParamString(hPvPFFStmt, 0, sTmpTime, false);
        SQL_BindParamInt(hPvPFFStmt, 1, matchId, true);
        SQL_BindParamInt(hPvPFFStmt, 2, g_iRound, true);
        SQL_BindParamInt(hPvPFFStmt, 3, iTeam, true);
        SQL_BindParamString(hPvPFFStmt, 4, sTmpMap, false);
        SQL_BindParamString(hPvPFFStmt, 5, g_sPlayerId[j], false);
        SQL_BindParamInt(hPvPFFStmt, 6, 0, true);
        SQL_BindParamInt(hPvPFFStmt, 7, g_bSecondHalf, true);

        for ( i = FIRST_NON_BOT; i < g_iPlayers; i++ ) {
            SQL_BindParamString(hPvPFFStmt, 8, g_sPlayerId[i], false);
            SQL_BindParamInt(hPvPFFStmt, 9, g_strRoundPvPFFData[j][iTeam][i], true);
            if (!SQL_Execute(hPvPFFStmt)) {
                PrintToChatAll("[Stats] Failed to save player ff stats for %s to %s.", g_sPlayerId[j], g_sPlayerId[i]);
                PrintDebug(1, "[Stats] Failed to save player ff stats for %s to %s.", g_sPlayerId[j], g_sPlayerId[i]);
            }
        }
    }

    // player infdmg data
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

        SQL_BindParamString(hPvPInfDmgStmt, 0, sTmpTime, false);
        SQL_BindParamInt(hPvPInfDmgStmt, 1, matchId, true);
        SQL_BindParamInt(hPvPInfDmgStmt, 2, g_iRound, true);
        SQL_BindParamInt(hPvPInfDmgStmt, 3, iTeam, true);
        SQL_BindParamString(hPvPInfDmgStmt, 4, sTmpMap, false);
        SQL_BindParamString(hPvPInfDmgStmt, 5, g_sPlayerId[j], false);
        SQL_BindParamInt(hPvPInfDmgStmt, 6, 0, true);
        SQL_BindParamInt(hPvPInfDmgStmt, 7, g_bSecondHalf, true);
        
        for ( i = FIRST_NON_BOT; i < g_iPlayers; i++ ) {
            SQL_BindParamString(hPvPInfDmgStmt, 8, g_sPlayerId[i], false);
            SQL_BindParamInt(hPvPInfDmgStmt, 9, g_strRoundPvPInfDmgData[j][iTeam][i], true);
            if (!SQL_Execute(hPvPInfDmgStmt)) {
                PrintToChatAll("[Stats] Failed to save pvp inf dmg stats for %s to %s.", g_sPlayerId[j], g_sPlayerId[i]);
                PrintDebug(1, "[Stats] Failed to save pvp inf dmg stats for %s to %s.", g_sPlayerId[j], g_sPlayerId[i]);
            }
        }
    }

    if (IsMissionFinalMap() && bSecondHalf) {
        if (g_bSystem2Loaded) {
            char cmd[256];
            char fCmd[256];
            if (GetMatchEndScriptCmd(cmd, sizeof(cmd))) {
                Format(fCmd, sizeof(fCmd), cmd, matchId);
                PrintDebug(1, "[Stats] Executing match end cmd: %s.", fCmd);
                System2_ExecuteThreaded(ExecuteCallback, fCmd);
            }
            else {
                PrintDebug(1, "[Stats] Match end cmd not found.");
            }
        }
        else {
            PrintDebug( 1, "[Stats] system2 library not loaded. Match end cmd won't execute." );
        }
    }
}

public void ExecuteCallback(bool success, const char[] command, System2ExecuteOutput output, any data) {
    if (!success || output.ExitStatus != 0) {
        PrintToServer("[Stats] Couldn't execute commands %s successfully", command);
        PrintDebug(1, "[Stats] Couldn't execute commands %s successfully", command);
    } else {
        char outputString[128];
        output.GetOutput(outputString, sizeof(outputString));
        PrintToServer("[Stats] Output of the command %s: %s", command, outputString);
        PrintDebug(1, "[Stats] Output of the command %s: %s", command, outputString);
    }
}

bool GetMatchEndScriptCmd(char[] cmd, int iLength)
{
    KeyValues kv = new KeyValues("l4d2_playstats");

    char sFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/l4d2_playstats.cfg");

    if (!FileExists(sFile))
    {
        PrintDebug(1, "[Stats] GetMatchEndScriptCmd \"%s\" not found!", sFile);
        return false;
    }

    kv.ImportFromFile(sFile);

    if (!kv.JumpToKey("match_end_script_cmd", false))
    {
        PrintDebug(1, "[Stats] GetMatchEndScriptCmd Can't find \"match_end_script_cmd\" in \"%s\"!", sFile);
        delete kv;
        return false;
    }
    kv.GetString(NULL_STRING, cmd, iLength);
    delete kv;
    return true;
}

stock WriteMatchLogToDB(const String: sTmpTime[], matchId, const String: sTmpMap[], result, const String: sSteamId[], startedAt, endedAt, iTeam, const String: sConfigName[]) {
    SQL_BindParamString(hMatchStmt, 0, sTmpTime, false);
    SQL_BindParamInt(hMatchStmt, 1, matchId, true);
    SQL_BindParamString(hMatchStmt, 2, sTmpMap, false);
    SQL_BindParamInt(hMatchStmt, 3, 0, true);
    SQL_BindParamInt(hMatchStmt, 4, result, true);
    SQL_BindParamString(hMatchStmt, 5, sSteamId, false);
    SQL_BindParamInt(hMatchStmt, 6, startedAt, true);
    SQL_BindParamInt(hMatchStmt, 7, endedAt, true);
    SQL_BindParamInt(hMatchStmt, 8, iTeam, true);
    SQL_BindParamString(hMatchStmt, 9, sConfigName, false);

    if (!SQL_Execute(hMatchStmt)) {
        PrintToChatAll("[Stats] Failed to save matchlog stats.");
        PrintDebug(1, "[Stats] Failed to save matchlog stats.");
    }
}