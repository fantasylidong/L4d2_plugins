#if defined _l4d2_playstats_tracking_included
 #endinput
#endif

#define _l4d2_playstats_tracking_included

#include <sourcemod>

/*
    Team / Bot tracking
    -------------------
*/
public Action: Event_PlayerTeam ( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !g_bTeamChanged ) {
        new newTeam = GetEventInt(event, "team");
        new oldTeam = GetEventInt(event, "oldteam");
        
        // only do checks for players moving from or to survivor team
        if ( newTeam != TEAM_SURVIVOR && oldTeam != TEAM_SURVIVOR ) { return; }
        
        g_bTeamChanged = true;
        CreateTimer( 0.5, Timer_TeamChanged, _, TIMER_FLAG_NO_MAPCHANGE );
    }
}

public Action: Timer_TeamChanged (Handle:timer) {
    g_bTeamChanged = false;
    UpdatePlayerCurrentTeam();
}

/*
    Tracking
    --------
*/
public Action: Event_PlayerHurt ( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !g_bPlayersLeftStart ) { return Plugin_Continue; }
    
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
    
    new damage = GetEventInt(event, "dmg_health");
    new attIndex, vicIndex;
    new type, zClass;
    
    // survivor to infected
    if ( IS_VALID_SURVIVOR(attacker) && IS_VALID_INFECTED(victim) ) {
        if ( damage < 1 ) { return Plugin_Continue; }
        
        attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return Plugin_Continue; }
        
        new dmgType = GetEventInt(event, "type");
        new hitgroup = GetEventInt(event, "hitgroup");
        zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        new storeA = -1, storeB = -1, storeC = -1;
        
        new weaponType = WPTYPE_NONE;
        if ( dmgType & DMG_BUCKSHOT ) {
            weaponType = WPTYPE_SHOTGUN;
        }
        else if ( dmgType & DMG_BULLET ) {
            decl String: weaponName[MAXWEAPNAME];
            GetClientWeapon( attacker, weaponName, MAXWEAPNAME );
            weaponType = GetWeaponTypeForClassname( weaponName );
        }
        
        if ( zClass >= ZC_SMOKER && zClass <= ZC_CHARGER ) {
            if ( g_bTankInGame ) {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plySIDamageTankUp] += damage;
            }
            
            switch ( weaponType ) {
                case WPTYPE_SHOTGUN: { storeA = plyHitsShotgun; storeB = plyHitsSIShotgun;  }
                case WPTYPE_SMG: {
                    storeA = plyHitsSmg;
                    storeB = plyHitsSISmg;
                    if ( hitgroup == HITGROUP_HEAD ) {
                        storeC = plyHeadshotsSmg;
                    }
                    else {
                        storeC = -1;
                    }
                }
                case WPTYPE_SNIPER: {
                    storeA = plyHitsSniper;
                    storeB = plyHitsSISniper;
                    if ( hitgroup == HITGROUP_HEAD ) {
                        storeC = plyHeadshotsSniper;
                    }
                    else {
                        storeC = -1;
                    }
                }
                case WPTYPE_PISTOL: {
                    storeA = plyHitsPistol;
                    storeB = plyHitsSIPistol;
                    if ( hitgroup == HITGROUP_HEAD ) {
                        storeC = plyHeadshotsPistol;
                    }
                    else {
                        storeC = -1;
                    }
                    // incapped: don't count hits
                    if ( IsPlayerIncapacitated(attacker) ) { storeA = -1; }
                }
            }
            
            g_strRoundData[g_iRound][g_iCurTeam][rndSIDamage] += damage;
            g_strRoundPlayerData[attIndex][g_iCurTeam][plySIDamage] += damage;
        }
        else if ( zClass == ZC_TANK && damage != 5000) // For some reason the last attacker does 5k damage?
        {
            
            if ( dmgType & DMG_CLUB || dmgType & DMG_SLASH ) {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyMeleesOnTank]++;
            }
            else {
                switch ( weaponType ) {
                    case WPTYPE_SHOTGUN: { storeA = plyHitsShotgun; storeB = plyHitsTankShotgun;  }
                    case WPTYPE_SMG: {     storeA = plyHitsSmg;     storeB = plyHitsTankSmg; }
                    case WPTYPE_SNIPER: {  storeA = plyHitsSniper;  storeB = plyHitsTankSniper; }
                    case WPTYPE_PISTOL: {
                            storeA = plyHitsPistol;  storeB = plyHitsTankPistol;
                            // incapped: don't count hits
                            if ( IsPlayerIncapacitated(attacker) ) { storeA = -1; }
                        }
                }
            }
            
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyTankDamage] += damage;
        }
        
        if ( storeA != -1 ) {
            g_strRoundPlayerData[attIndex][g_iCurTeam][storeA]++;
            g_strRoundPlayerData[attIndex][g_iCurTeam][storeB]++;
            if ( storeC != -1 ) {
                g_strRoundPlayerData[attIndex][g_iCurTeam][storeC]++;
                g_strRoundPlayerData[attIndex][g_iCurTeam][ (storeC+3) ]++;    // = headshotsSI<type>
            }
        }
    }
    // survivor to survivor
    else if ( IS_VALID_SURVIVOR(victim) && IS_VALID_SURVIVOR(attacker) && !IsFakeClient(attacker) ) {
        // friendly fire
        
        type = GetEventInt(event, "type");
        if ( damage < 1 ) { return Plugin_Continue; }
        
        attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return Plugin_Continue; }
        
        if ( attacker == victim ) {
            vicIndex = attIndex;
        }
        else {
            vicIndex = GetPlayerIndexForClient( victim );
            if ( vicIndex == -1 ) { return Plugin_Continue; }
        }
        
        // record amounts
        g_strRoundData[g_iRound][g_iCurTeam][rndFFDamageTotal] += damage;
        
        g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenTotal] += damage;
        g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenTotal] += damage;
        
        if ( attIndex == vicIndex ) {
            // damage to self
            g_strRoundPvPFFData[attIndex][g_iCurTeam][vicIndex] += damage;
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenSelf] += damage;
        }
        else if ( IsPlayerIncapacitated(victim) ) {
            // don't count incapped damage for 'ffgiven' / 'fftaken'
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenIncap] += damage;
            g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenIncap] += damage;
        }
        else {
            g_strRoundPvPFFData[attIndex][g_iCurTeam][vicIndex] += damage;
            g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGiven] += damage;
            if ( attIndex != vicIndex ) {
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTaken] += damage;
            }
            
            // which type to save it to?
            if ( type & DMG_BURN ) {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenFire] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenFire] += damage;
            }
            else if ( type & DMG_BUCKSHOT ) {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenPellet] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenPellet] += damage;
            }
            else if ( type & DMG_CLUB || type & DMG_SLASH ) {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenMelee] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenMelee] += damage;
            }
            else if ( type & DMG_BULLET ) {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenBullet] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenBullet] += damage;
            }
            else {
                g_strRoundPlayerData[attIndex][g_iCurTeam][plyFFGivenOther] += damage;
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyFFTakenOther] += damage;
            }
        }
        
    }
    // infected to survivor
    else if ( IS_VALID_SURVIVOR(victim) ) {
        vicIndex = GetPlayerIndexForClient( victim );
        if ( vicIndex == -1 ) { return Plugin_Continue; }
        new attackerent = GetEventInt(event, "attackerentid");
        
        if ( IS_VALID_INFECTED(attacker) ) {
            g_strRoundPlayerData[vicIndex][g_iCurTeam][plyDmgTaken] += damage;
            
            type = GetEventInt(event, "type");
            zClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
            
            attIndex = GetPlayerIndexForClient( attacker );
            if ( attIndex == -1 ) { return Plugin_Continue; }
            
            if ( zClass == ZC_TANK ) {
                if ( !IsPlayerIncapacitatedAtAll(victim) ) {
                    g_strRoundPvPInfDmgData[attIndex][g_iCurTeam][vicIndex] += damage;
                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgTank] += damage;
                    g_strRoundPlayerData[vicIndex][g_iCurTeam][plyDmgTakenTank] += damage;
                }
                else {
                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgTankIncap] += damage;
                }
            }
            else {
                g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgTotal] += damage;
                
                if ( !IsPlayerIncapacitatedAtAll(victim) ) {
                    g_strRoundPvPInfDmgData[attIndex][g_iCurTeam][vicIndex] += damage;
                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgUpright] += damage;
                    
                    if ( type & DMG_CLUB ) {
                        // scratches? (always DMG_CLUB), but check for rides etc
                        switch ( zClass ) {
                            case ZC_CHARGER: {
                                if (    GetEntPropEnt(attacker, Prop_Send, "m_carryVictim") == -1 &&
                                        GetEntPropEnt(attacker, Prop_Send, "m_pummelVictim") == -1 &&
                                        damage >= STUMBLE_DMG_THRESH
                                ) {
                                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratch] += damage;
                                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratchCharger] += damage;
                                }
                            }
                            case ZC_SMOKER: {
                                if ( GetEntPropEnt(attacker, Prop_Send, "m_tongueVictim") == -1 ) {
                                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratch] += damage;
                                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratchSmoker] += damage;
                                }
                            }
                            
                            case ZC_JOCKEY: {
                                if ( GetEntPropEnt(attacker, Prop_Send, "m_jockeyVictim") == -1 ) {
                                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratch] += damage;
                                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratchJockey] += damage;
                                }
                            }
                            
                            case ZC_HUNTER: {
                                if ( GetEntPropEnt(attacker, Prop_Send, "m_pounceVictim") == -1 ) {
                                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratch] += damage;
                                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratchHunter] += damage;
                                }
                            }
                            
                            case ZC_BOOMER: {
                                g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratch] += damage;
                                g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratchBoomer] += damage;
                            }
                            
                            case ZC_SPITTER: {
                                g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratch] += damage;
                                g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratchSpitter] += damage;
                            }
                            
                            default: {
                                g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgScratch] += damage;
                            }
                        }
                    }
                    else if ( type & (DMG_RADIATION | DMG_ENERGYBEAM) ) {
                        // spit (DMG_RADIATION / DMG_ENERGYBEAM ) and sometimes ( DMG_VEHICLE / DMG_FALL ) on top of it
                        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgSpit] += damage;
                    }
                    
                    if ( g_bTankInGame ) {
                        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgTankUp] += damage;
                    }
                }
            }
        }
        else if ( IsValidEntity(attackerent) && IsCommon(attackerent) ) {
            if ( !IsPlayerIncapacitatedAtAll(victim) ) {
                g_strRoundPlayerData[vicIndex][g_iCurTeam][plyDmgTakenCommon] += damage;

                // how much damage did a boomer 'do'
                if ( g_iBoomedBy[victim] ) {
                    attIndex = GetPlayerIndexForClient( g_iBoomedBy[victim] );
                    if ( attIndex == -1 ) { return Plugin_Continue; }
                    
                    g_strRoundPlayerData[vicIndex][g_iCurTeam][plyDmgTaken] += damage;
                    g_strRoundPlayerData[vicIndex][g_iCurTeam][plyDmgTakenBoom] += damage;
                    g_strRoundPvPInfDmgData[attIndex][g_iCurTeam][vicIndex] += damage;
                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgTotal] += damage;
                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgUpright] += damage;
                    g_strRoundPlayerInfData[attIndex][g_iCurTeam][infDmgBoom] += damage;
                }
            }
        }
    }
    
    return Plugin_Continue;
}

public Action: Event_InfectedHurt ( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
    if ( !IS_VALID_SURVIVOR(attacker) ) { return; }
    
    new attIndex = GetPlayerIndexForClient( attacker );
    if ( attIndex == -1 ) { return; }
    
    // catch damage done to witch
    new entity = GetEventInt(event, "entityid");
    new hitgroup = GetEventInt(event, "hitgroup");
    new dmgType = GetEventInt(event, "type");
    
    new storeA = -1, storeC = -1;
    
    new weaponType = WPTYPE_NONE;
    if ( dmgType & DMG_BUCKSHOT ) {
        weaponType = WPTYPE_SHOTGUN;
    }
    else if ( dmgType & DMG_BULLET ) {
        decl String: weaponName[MAXWEAPNAME];
        GetClientWeapon( attacker, weaponName, MAXWEAPNAME );
        weaponType = GetWeaponTypeForClassname( weaponName );
    }
    
    switch ( weaponType ) {
        case WPTYPE_SHOTGUN: { storeA = plyHitsShotgun; }
        case WPTYPE_SMG: {
            storeA = plyHitsSmg;
            if ( hitgroup == HITGROUP_HEAD ) {
                storeC = plyHeadshotsSmg;
            }
            else {
                storeC = -1;
            }
        }
        case WPTYPE_SNIPER: {
            storeA = plyHitsSniper;
            if ( hitgroup == HITGROUP_HEAD ) {
                storeC = plyHeadshotsSniper;
            }
            else {
                storeC = -1;
            }
        }
        case WPTYPE_PISTOL: {
            storeA = plyHitsPistol;
            if ( hitgroup == HITGROUP_HEAD ) {
                storeC = plyHeadshotsPistol;
            }
            else {
                storeC = -1;
            }
            // incapped: don't count hits
            if ( IsPlayerIncapacitated(attacker) ) { storeA = -1; }
        }
    }
    
    if ( storeA != -1 ) {
        g_strRoundPlayerData[attIndex][g_iCurTeam][storeA]++;
        if ( storeC != -1 ) {
            g_strRoundPlayerData[attIndex][g_iCurTeam][storeC]++;
        }
    }
    
    if ( IsWitch(entity) ) {
        new damage = GetEventInt(event, "amount");
        
        g_strRoundPlayerData[attIndex][g_iCurTeam][plyWitchDamage] += damage;
    }
}
public Action: Event_PlayerFallDamage ( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !g_bPlayersLeftStart ) { return Plugin_Continue; }
    
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    if ( !IS_VALID_SURVIVOR(victim) ) { return Plugin_Continue; }
    
    new damage = GetEventInt(event, "damage");
    new index = GetPlayerIndexForClient( victim );
    if ( index == -1 ) { return Plugin_Continue; }
    
    g_strRoundPlayerData[index][g_iCurTeam][plyFallDamage] += damage;
    
    return Plugin_Continue;
}

public Action: Event_WitchKilled ( Handle:event, const String:name[], bool:dontBroadcast ) {
    g_strRoundData[g_iRound][g_iCurTeam][rndWitchKilled]++;
}

public Action: Event_PlayerDeath ( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    new index, attacker;
    
    if ( IS_VALID_SURVIVOR(client) ) {
        // survivor died
        
        g_strRoundData[g_iRound][g_iCurTeam][rndDeaths]++;
        
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        g_strRoundPlayerData[index][g_iCurTeam][plyDied]++;
        
        // store time they died
        new time = GetTime();
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = time;
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = time; }
    }
    else if ( IS_VALID_INFECTED(client) ) {
        // special infected died (check for tank)
        
        if ( GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK ) {
            // check if it really died
            CreateTimer( 0.1, Timer_CheckTankDeath, client );
        }
        else {
            attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
            
            if ( IS_VALID_SURVIVOR(attacker) ) {
                index = GetPlayerIndexForClient( attacker );
                if ( index == -1 ) { return; }
                
                g_strRoundData[g_iRound][g_iCurTeam][rndSIKilled]++;
                g_strRoundPlayerData[index][g_iCurTeam][plySIKilled]++;
                
                if ( g_bTankInGame )
                { 
                    g_strRoundPlayerData[index][g_iCurTeam][plySIKilledTankUp]++;
                }
            }
        }
    }
    else if ( !client ) {
        // common infected died (check for witch)
        
        new common = GetEventInt(event, "entityid");
        attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
        
        if ( IS_VALID_SURVIVOR(attacker) && !IsWitch(common) ) {
            
            index = GetPlayerIndexForClient( attacker );
            if ( index == -1 ) { return; }
            
            g_strRoundData[g_iRound][g_iCurTeam][rndCommon]++;
            g_strRoundPlayerData[index][g_iCurTeam][plyCommon]++;
            
            if ( g_bTankInGame ) {
                g_strRoundPlayerData[index][g_iCurTeam][plyCommonTankUp]++;
            }
        }
        else if ( IS_VALID_INFECTED(attacker) ) {
            index = GetPlayerIndexForClient( attacker );
            if ( index == -1 ) { return; }
            
            // infected killed a common
            g_strRoundPlayerInfData[index][g_iCurTeam][infCommon]++;
        }
    }
}
public Action: Timer_CheckTankDeath ( Handle:hTimer, any:client_oldTank ) {
    if ( !IsTankInGame() ) {
        // tank died
        g_strRoundData[g_iRound][g_iCurTeam][rndTankKilled]++;
        g_bTankInGame = false;
        
        // handle tank time up
        if ( g_bInRound ) {
            HandleTankTimeEnd();
        }
    }
}

stock HandleTankTimeEnd() {
    g_strRoundData[g_iRound][g_iCurTeam][rndStopTimeTank] = GetTime();
}

public Action: Event_TankSpawned( Handle:hEvent, const String:name[], bool:dontBroadcast ) {
    //new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    g_bTankInGame = true;
    new time = GetTime();
    
    if ( !g_bInRound ) { return; }
    
    // note time
    if ( !g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank] ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank] = time;
    }
    else if ( g_strRoundData[g_iRound][g_iCurTeam][rndStopTimeTank] ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank] = time - (g_strRoundData[g_iRound][g_iCurTeam][rndStopTimeTank] - g_strRoundData[g_iRound][g_iCurTeam][rndStartTimeTank]);
        g_strRoundData[g_iRound][g_iCurTeam][rndStopTimeTank] = 0;
    }
    // else, keep starttime, it's two+ tanks at the same time...
    
    // store passes
    new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    if ( !IS_VALID_INGAME(client) || IsFakeClient(client) ) { return; }
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    g_strRoundPlayerInfData[index][g_iCurTeam][infTankPasses]++;
}

public Action: Event_PlayerIncapped (Handle:event, const String:name[], bool:dontBroadcast) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    
    if ( IS_VALID_SURVIVOR(client) ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndIncaps]++;
        
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        g_strRoundPlayerData[index][g_iCurTeam][plyIncaps]++;
        
        // store time they incapped (if they weren't already)
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = GetTime(); }
    }
}

public Action: Event_PlayerRevived (Handle:event, const String:name[], bool:dontBroadcast) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "subject") );
    
    if ( IS_VALID_SURVIVOR(client) ) {
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        if ( !IsPlayerIncapacitatedAtAll(client) && IsPlayerAlive(client) && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += GetTime() - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
        }
    }
}

// rescue closets in coop
public Action: Event_SurvivorRescue (Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId( GetEventInt(event, "victim") );
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    // if they were dead, they're alive now! magic.
    new time = GetTime();
    if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] )  {
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive];
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = 0;
    }
    if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] )  {
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
        g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
    }
}

// ledgegrabs
public Action: Event_PlayerLedged (Handle:event, const String:name[], bool:dontBroadcast) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    
    if ( IS_VALID_SURVIVOR(client) ) {
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        // store time they incapped (if they weren't already)
        if ( !g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] ) { g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = GetTime(); }
        
        new causer = GetClientOfUserId( GetEventInt(event, "causer") );
        if ( IS_VALID_INFECTED(causer) ) {
            new attIndex = GetPlayerIndexForClient( causer );
            if ( attIndex == -1 ) { return; }
            
            g_strRoundPlayerInfData[attIndex][g_iCurTeam][infLedged] ++;
        }
    }
}

public Action: Event_PlayerLedgeRelease (Handle:event, const String:name[], bool:dontBroadcast) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    
    if ( IS_VALID_SURVIVOR(client) ) {
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        if ( !IsPlayerIncapacitatedAtAll(client) && IsPlayerAlive(client) && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] ) {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += GetTime() - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
        }
    }
}

// items used
public Action: Event_DefibUsed (Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId( GetEventInt(event, "subject") );
    
    g_strRoundData[g_iRound][g_iCurTeam][rndDefibsUsed]++;
    
    if ( IS_VALID_SURVIVOR(client) ) {
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        new time = GetTime();
        if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] )  {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartAlive] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive];
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopAlive] = 0;
        }
        if ( g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] && g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] )  {
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStartUpright] += time - g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright];
            g_strRoundPlayerData[index][g_iCurTeam][plyTimeStopUpright] = 0;
        }
    }
}
public Action: Event_HealSuccess (Handle:event, const String:name[], bool:dontBroadcast) {
    g_strRoundData[g_iRound][g_iCurTeam][rndKitsUsed]++;
}
public Action: Event_PillsUsed (Handle:event, const String:name[], bool:dontBroadcast) {
    g_strRoundData[g_iRound][g_iCurTeam][rndPillsUsed]++;
}
public Action: Event_AdrenUsed (Handle:event, const String:name[], bool:dontBroadcast) {
    g_strRoundData[g_iRound][g_iCurTeam][rndPillsUsed]++;
}

// keep track of shots fired
public Action: Event_WeaponFire (Handle:event, const String:name[], bool:dontBroadcast) {
    if ( !g_bPlayersLeftStart ) { return; }
    
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    if ( !IS_VALID_SURVIVOR(client) || IsPlayerIncapacitated(client) ) { return; }
    
    new index = GetPlayerIndexForClient( client );
    if ( index == -1 ) { return; }
    
    new weaponId = GetEventInt(event, "weaponid");
    
    if ( weaponId == WP_PISTOL || weaponId == WP_PISTOL_MAGNUM ) {
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsPistol]++;
    }
    else if (   weaponId == WP_SMG         || weaponId == WP_SMG_SILENCED || weaponId == WP_SMG_MP5    ||
                weaponId == WP_RIFLE       || weaponId == WP_RIFLE_DESERT || weaponId == WP_RIFLE_AK47 ||
                weaponId == WP_RIFLE_SG552 || weaponId == WP_RIFLE_M60
    ) {
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsSmg]++;
    }
    else if (   weaponId == WP_PUMPSHOTGUN || weaponId == WP_SHOTGUN_CHROME ||
                weaponId == WP_AUTOSHOTGUN || weaponId == WP_SHOTGUN_SPAS
    ) {
        // get pellets
        new count = GetEventInt(event, "count");
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsShotgun] += count;
    }
    else if (   weaponId == WP_HUNTING_RIFLE || weaponId == WP_SNIPER_MILITARY ||
                weaponId == WP_SNIPER_AWP    || weaponId == WP_SNIPER_SCOUT
    ) {
        g_strRoundPlayerData[index][g_iCurTeam][plyShotsSniper]++;
    }
    /* else if (weaponId == WP_MELEE) {
        //g_strRoundPlayerData[index][g_iCurTeam][plyShotsMelee]++;
    } */
    
    // ignore otherwise
}

// spawncount
public Action: Event_PlayerSpawn (Handle:hEvent, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId( GetEventInt(hEvent, "userid") );
    if ( !IS_VALID_INFECTED(client) ) { return; }
    
    new zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    
    if ( zClass >= ZC_SMOKER && zClass <= ZC_CHARGER ) {
        g_strRoundData[g_iRound][g_iCurTeam][rndSISpawned]++;
        
        new index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        g_strRoundPlayerInfData[index][g_iCurTeam][infSpawns]++;
        
        switch ( zClass ) {
            case ZC_SMOKER:     { g_strRoundPlayerInfData[index][g_iCurTeam][infSpawnSmoker]++; }
            case ZC_BOOMER:     { g_strRoundPlayerInfData[index][g_iCurTeam][infSpawnBoomer]++; }
            case ZC_HUNTER:     { g_strRoundPlayerInfData[index][g_iCurTeam][infSpawnHunter]++; }
            case ZC_SPITTER:    { g_strRoundPlayerInfData[index][g_iCurTeam][infSpawnSpitter]++; }
            case ZC_JOCKEY:     { g_strRoundPlayerInfData[index][g_iCurTeam][infSpawnJockey]++; }
            case ZC_CHARGER:    { g_strRoundPlayerInfData[index][g_iCurTeam][infSpawnCharger]++; }
        }
    }
}


// boom tracking
public Action: Event_PlayerBoomed (Handle:event, const String:name[], bool:dontBroadcast) {
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
    
    if ( IS_VALID_SURVIVOR(victim) && IS_VALID_INFECTED(attacker) ) {
        g_iBoomedBy[victim] = attacker;
        
        new attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return; }
        
        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infBooms] ++;
    }
}
public Action: Event_PlayerUnboomed (Handle:event, const String:name[], bool:dontBroadcast) {
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    g_iBoomedBy[victim] = 0;
}

public Action: Event_ChargerCarryStart (Handle:event, const String:name[], bool:dontBroadcast) {
    new victim = GetClientOfUserId( GetEventInt(event, "victim") );
    new attacker = GetClientOfUserId( GetEventInt(event, "userid") );
    new attIndex, vicIndex;
    if ( IS_VALID_SURVIVOR(victim) && IS_VALID_INFECTED(attacker) ) {
        attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return; }
        
        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infCharges] ++;
        
        vicIndex = GetPlayerIndexForClient( victim );
        if ( vicIndex == -1 ) { return; }
        
        g_strRoundPlayerData[vicIndex][g_iCurTeam][plyCharges] ++;
    }
}

public Action: Event_ChargerImpact (Handle:event, const String:name[], bool:dontBroadcast) {
    new victim = GetClientOfUserId( GetEventInt(event, "victim") );
    new attacker = GetClientOfUserId( GetEventInt(event, "userid") );
    new attIndex, vicIndex;
    if ( IS_VALID_SURVIVOR(victim) && IS_VALID_INFECTED(attacker) ) {
        attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return; }
        
        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infMultiCharges] ++;
        
        vicIndex = GetPlayerIndexForClient( victim );
        if ( vicIndex == -1 ) { return; }
        
        g_strRoundPlayerData[vicIndex][g_iCurTeam][plyBowls] ++;
    }
}

public Action: Event_JockeyRide (Handle:event, const String:name[], bool:dontBroadcast) {
    new victim = GetClientOfUserId( GetEventInt(event, "victim") );
    new attacker = GetClientOfUserId( GetEventInt(event, "userid") );
    new attIndex, vicIndex;
    if ( IS_VALID_SURVIVOR(victim) && IS_VALID_INFECTED(attacker) ) {
        attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return; }
        
        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infJockeyRideTotal] ++;
        
        vicIndex = GetPlayerIndexForClient( victim );
        if ( vicIndex == -1 ) { return; }
        
        g_strRoundPlayerData[vicIndex][g_iCurTeam][plyJockeyRideTotal] ++;
    }
}

public Action: Event_JockeyRideEnd (Handle:event, const String:name[], bool:dontBroadcast) {
    new victim = GetClientOfUserId( GetEventInt(event, "victim") );
    new attacker = GetClientOfUserId( GetEventInt(event, "userid") );
    new attIndex, vicIndex;
    if ( IS_VALID_SURVIVOR(victim) && IS_VALID_INFECTED(attacker) ) {
        new duration = RoundFloat(GetEventFloat(event, "ride_length") * 1000.0);
        
        attIndex = GetPlayerIndexForClient( attacker );
        if ( attIndex == -1 ) { return; }
        
        g_strRoundPlayerInfData[attIndex][g_iCurTeam][infJockeyRideDuration] += duration;
        
        vicIndex = GetPlayerIndexForClient( victim );
        if ( vicIndex == -1 ) { return; }
        
        g_strRoundPlayerData[vicIndex][g_iCurTeam][plyJockeyRideDuration] += duration;
    }
}

public Action: Event_AwardEarned (Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    new award = GetEventInt(event, "award");
    new index;
    if ( IS_VALID_SURVIVOR(client) && award == 67 ) {
        index = GetPlayerIndexForClient( client );
        if ( index == -1 ) { return; }
        
        g_strRoundPlayerData[index][g_iCurTeam][plyProtectAwards]++;
    }
}