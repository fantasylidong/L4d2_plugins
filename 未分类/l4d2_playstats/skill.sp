#if defined _l4d2_playstats_skill_included
 #endinput
#endif

#define _l4d2_playstats_skill_included

#include <sourcemod>

/*
    Skill Detect forwards
    ---------------------
*/
// m2 & deadstop
public OnSpecialShoved ( attacker, victim, zombieClass ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyShoves]++;
}
public OnHunterDeadstop ( attacker, victim ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyDeadStops]++;
}

// skeets
public OnSkeet ( attacker, victim ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeets]++;
}
public OnSkeetGL ( attacker, victim ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeets]++;
}
public OnSkeetHurt ( attacker, victim, damage ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsHurt]++;
}
public OnSkeetMelee ( attacker, victim ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsMelee]++;
}
public OnSkeetMeleeHurt ( attacker, victim, damage ) {
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsHurt]++;
}

public OnSkeetSniper ( attacker, victim ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeets]++;
}
public OnSkeetSniperHurt ( attacker, victim, damage ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySkeetsHurt]++;
}

// pops
public OnBoomerPop ( attacker, victim, shoveCount, Float:timeAlive ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new attIndex = GetPlayerIndexForClient( attacker );
    if ( attIndex == -1 ) { return; }
    
    g_strRoundPlayerData[attIndex][g_iCurTeam][plyPops]++;

    new vicIndex = GetPlayerIndexForClient( victim );
    if ( vicIndex == -1 ) { return; }

    g_strRoundPlayerInfData[vicIndex][g_iCurTeam][infBoomerPops]++;
}

// levels
public OnChargerLevel ( attacker, victim ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyLevels]++;
}
public OnChargerLevelHurt ( attacker, victim, damage ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyLevelsHurt]++;
}

// smoker clears
public OnTongueCut ( attacker, victim ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyTongueCuts]++;
}
public OnSmokerSelfClear ( attacker, victim, withShove ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plySelfClears]++;
}

// crowns
public OnWitchCrown ( attacker, damage ) {
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyCrowns]++;
}
public OnWitchDrawCrown ( attacker, damage, chipdamage ) {
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyCrownsHurt]++;
}
// tank rock
public OnTankRockEaten ( attacker, victim ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new vicIndex = GetPlayerIndexForClient( victim );
    if ( vicIndex == -1 ) { return; }
    
    g_strRoundPlayerData[vicIndex][g_iCurTeam][plyRockEats]++;
    
    new attIndex = GetPlayerIndexForClient( attacker );
    if ( attIndex == -1 ) { return; }
    
    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infTankRockHits]++;
}

public OnTankRockSkeeted ( attacker, victim ) {
    new vicIndex = GetPlayerIndexForClient( attacker );
    if ( vicIndex == -1 ) { return; }
    
    g_strRoundPlayerData[vicIndex][g_iCurTeam][plyRockSkeets]++;
}
// highpounces
public OnHunterHighPounce ( attacker, victim, actualDamage, Float:damage, Float:height, bool:bReportedHigh ) {
    if ( !bReportedHigh ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerInfData[index][g_iCurTeam][infHunterDPs]++;
    g_strRoundPlayerInfData[index][g_iCurTeam][infHunterDPDmg] += RoundToFloor( damage );
}
public OnJockeyHighPounce ( attacker, victim, Float:height, bool:bReportedHigh ) {
    if ( !bReportedHigh ) { return; }
    
    new index = GetPlayerIndexForClient( attacker );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerInfData[index][g_iCurTeam][infJockeyDPs]++;
}

public OnCarAlarmTriggered ( victim, attacker, reason ) {
    new vicIndex = GetPlayerIndexForClient( victim );
    if ( vicIndex == -1 ) { return; }

    g_strRoundPlayerData[vicIndex][g_iCurTeam][plyCarsTriggered]++;

    new attIndex = GetPlayerIndexForClient( attacker );
    if ( attIndex == -1 ) { return; }

    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infCarsTriggered] ++;
}

public OnBoomerVomitLanded ( attacker, boomCount ) {
    new attIndex = GetPlayerIndexForClient( attacker );
    if ( attIndex == -1 ) { return; }

    if ( boomCount == 1) {
        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infBoomsSingle] ++;
    }
    else if ( boomCount == 2) {
        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infBoomsDouble] ++;
    }
    else if ( boomCount == 3) {
        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infBoomsTriple] ++;
    }
    else if ( boomCount >= 4) {
        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infBoomsQuad] ++;
    }
}

// deathcharges
public OnDeathCharge ( attacker, victim, Float:height, Float:distance, bool:bCarried ) {
    new attIndex = GetPlayerIndexForClient( attacker );
    if ( attIndex == -1 ) { return; }

    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDeathCharges] ++;

    new vicIndex = GetPlayerIndexForClient( victim );
    if ( vicIndex == -1 ) { return; }

    g_strRoundPlayerData[vicIndex][g_iCurTeam][plyDeathCharges] ++;
}

// clears
public OnSpecialClear( clearer, pinner, pinvictim, zombieClass, Float:timeA, Float:timeB, bool:withShove ) {
    new Float: fClearTime = timeA;
    if ( zombieClass == ZC_CHARGER || zombieClass == ZC_SMOKER ) { fClearTime = timeB; }
    
    // ignore any that take longer than a minute to clear
    // also ignore self-clears
    if ( fClearTime < 0.0 || fClearTime == 0.0 || fClearTime > 60.0 || clearer == pinvictim ) { return; }
    
    new index = GetPlayerIndexForClient( clearer );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyAvgClearTime] = RoundFloat(
            ( float( g_strRoundPlayerData[index][g_iCurTeam][plyAvgClearTime] * g_strRoundPlayerData[index][g_iCurTeam][plyClears] ) + fClearTime * 1000.0 ) /
            float( g_strRoundPlayerData[index][g_iCurTeam][plyClears] + 1 )
        );
    g_strRoundPlayerData[index][g_iCurTeam][plyClears]++;
}