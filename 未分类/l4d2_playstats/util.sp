#if defined _l4d2_playstats_util_included
 #endinput
#endif

#define _l4d2_playstats_util_included

#include <sourcemod>

/*
    Support
    -------
*/
stock GetCurrentTeamSurvivor() {
    // this is corrected if CMT has mixed the teams up to preserve playing order
    if ( g_bCMTSwapped ) {
        return !GameRules_GetProp("m_bAreTeamsFlipped");
    } else {
        return GameRules_GetProp("m_bAreTeamsFlipped");
    }
}
stock GetWeaponTypeForId ( weaponId ) {
    if ( weaponId == WP_PISTOL || weaponId == WP_PISTOL_MAGNUM ) {
        return WPTYPE_PISTOL;
    }
    else if (   weaponId == WP_SMG || weaponId == WP_SMG_SILENCED || weaponId == WP_SMG_MP5 ||
                weaponId == WP_RIFLE || weaponId == WP_RIFLE_DESERT || weaponId == WP_RIFLE_AK47 || weaponId == WP_RIFLE_SG552
    ) {
        return WPTYPE_SMG;
    }
    else if (   weaponId == WP_PUMPSHOTGUN || weaponId == WP_SHOTGUN_CHROME ||
                weaponId == WP_AUTOSHOTGUN || weaponId == WP_SHOTGUN_SPAS
    ) {
        return WPTYPE_SHOTGUN;
    }
    else if (   weaponId == WP_HUNTING_RIFLE || weaponId == WP_SNIPER_MILITARY  ||
                weaponId == WP_SNIPER_AWP || weaponId == WP_SNIPER_SCOUT
    ) {
        return WPTYPE_SNIPER;
    }
    
    return 0;
}
stock GetWeaponTypeForClassname ( const String:classname[] ) {
    new strWeaponType: weaponType;
    
    if ( !GetTrieValue(g_hTrieWeapons, classname, weaponType) ) {
        return WPTYPE_NONE;
    }
    
    return weaponType;
}
stock GetPlayerIndexForClient ( client ) {
    if ( !IS_VALID_INGAME(client) ) { return -1; }
    
    decl String: sSteamId[32];
    
    // fake clients:
    if ( IsFakeClient(client) ) {
        Format( sSteamId, sizeof( sSteamId ), "BOT_%i", GetPlayerCharacter(client) );
    }
    else {
        GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
    }
    
    return GetPlayerIndexForSteamId( sSteamId, client );
}
// if not found, stores the steamid for a new index, stores the name and safe name too
stock GetPlayerIndexForSteamId ( const String:steamId[], client=-1 ) {
    new pIndex = -1;
    
    if ( !GetTrieValue( g_hTriePlayers, steamId, pIndex ) ) {
        // add it
        pIndex = g_iPlayers;
        SetTrieValue( g_hTriePlayers, steamId, pIndex );
        
        // store steam id
        strcopy( g_sPlayerId[pIndex], 32, steamId );
        
        // store name
        if ( client != -1 ) {
            GetClientName( client, g_sPlayerName[pIndex], MAXNAME );
            strcopy( g_sPlayerNameSafe[pIndex], MAXNAME_TABLE, g_sPlayerName[pIndex] );
            stripUnicode( g_sPlayerNameSafe[pIndex], MAXNAME_TABLE );
        }
        
        g_iPlayers++;
        
        // safeguard
        if ( g_iPlayers >= MAXTRACKED ) {
            g_iPlayers = FIRST_NON_BOT;
        }
    }
    
    return pIndex;
}
stock GetPlayerCharacter ( client ) {
    new tmpChr = GetEntProp(client, Prop_Send, "m_survivorCharacter");
    
    // use models when incorrect character returned
    if ( tmpChr < 0 || tmpChr >= MAXCHARACTERS ) {
        decl String:model[256];
        GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
        
        if (StrContains(model, "gambler") != -1) {          tmpChr = 0; }
        else if (StrContains(model, "coach") != -1) {       tmpChr = 2; }
        else if (StrContains(model, "mechanic") != -1) {    tmpChr = 3; }
        else if (StrContains(model, "producer") != -1) {    tmpChr = 1; }
        else if (StrContains(model, "namvet") != -1) {      tmpChr = 0; }
        else if (StrContains(model, "teengirl") != -1) {    tmpChr = 1; }
        else if (StrContains(model, "biker") != -1) {       tmpChr = 3; }
        else if (StrContains(model, "manager") != -1) {     tmpChr = 2; }
        else {                                              tmpChr = 0; }
    }
    
    return tmpChr;
}
stock IsIndexSurvivor ( index, bool: bInfectedInstead = false ) {
    // assume bots are always survivors
    if ( index < FIRST_NON_BOT ) { return true; }
    
    new tmpind;
    for ( new client = 1; client <= MaxClients; client++ ) {
        if ( bInfectedInstead ) {
            if ( !IS_VALID_INFECTED(client) ) { continue; }
        } else {
            if ( !IS_VALID_SURVIVOR(client) ) { continue; }
        }
        
        tmpind = GetPlayerIndexForClient( client );
        if ( tmpind == index ) { return true; }
    }
    
    return false;
}
stock bool: IsWitch ( iEntity ) {
    if ( iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity) ) {
        decl String:strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        new strOEC: entType;
        
        if ( !GetTrieValue(g_hTrieEntityCreated, strClassName, entType) ) { return false; }
        
        return bool:(entType == OEC_WITCH);
    }
    return false;
}
stock bool: IsCommon ( iEntity ) {
    if ( iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity) ) {
        decl String:strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        new strOEC: entType;
        
        if ( !GetTrieValue(g_hTrieEntityCreated, strClassName, entType) ) { return false; }
        
        return bool:(entType == OEC_INFECTED);
    }
    return false;
}
stock bool: IsTankInGame() {
    for ( new client = 1; client <= MaxClients; client++ ) {
        if ( IS_VALID_INFECTED(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK) {
            return true;
        }
    }
    return false;
}
stock bool: IsPlayerIncapacitated ( client ) {
    return bool: GetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
}
stock bool: IsHangingFromLedge ( client ) {
    return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}
stock bool: IsPlayerIncapacitatedAtAll ( client ) {
    return bool: ( IsPlayerIncapacitated(client) || IsHangingFromLedge(client) );
}
stock bool: AreClientsConnected() {
    for (new i = 1; i <= MaxClients; i++) {
        if ( IS_VALID_INGAME(i) && !IsFakeClient(i) ) { return true; }
    }
    return false;
}
stock GetUprightSurvivors() {
    new count = 0;
    new incapcount = 0;
    
    for ( new client = 1; client <= MaxClients; client++ ) {
        if ( IS_VALID_SURVIVOR(client) && IsPlayerAlive(client) ) {
            if ( IsPlayerIncapacitatedAtAll(client) ) {
                incapcount++;
            } else {
                count++;
            }
        }
    }
    
    // if incapped in saferoom with upright survivors, counts as survival
    if ( count ) { count += incapcount; }
    
    return count;
}

/*
    General functions
    -----------------
*/

stock LeftPadString ( String:text[], maxlength, cutOff = 20, bool:bNumber = false ) {
    new String: tmp[maxlength];
    new safe = 0;   // just to make sure we're never stuck in an eternal loop
    
    strcopy( tmp, maxlength, text );
    
    if ( !bNumber ) {
        while ( strlen(tmp) < cutOff && safe < 1000 ) {
            Format( tmp, maxlength, " %s", tmp );
            safe++;
        }
    }
    else {
        while ( strlen(tmp) < cutOff && safe < 1000 ) {
            Format( tmp, maxlength, "0%s", tmp );
            safe++;
        }
    }
    
    strcopy( text, maxlength, tmp );
}

stock RightPadString ( String:text[], maxlength, cutOff = 20 ) {
    new String: tmp[maxlength];
    new safe = 0;   // just to make sure we're never stuck in an eternal loop
    
    strcopy( tmp, maxlength, text );
    
    while ( strlen(tmp) < cutOff && safe < 1000 ) {
        Format( tmp, maxlength, "%s ", tmp );
        safe++;
    }
    
    strcopy( text, maxlength, tmp );
}

stock FormatTimeAsDuration ( String:text[], maxlength, time, bool:bPad = true ) {
    new String: tmp[maxlength];
    
    if ( time < 1 ) { 
        Format( text, maxlength, "" );
        return;
    }
    
    if ( time > 3600 ) {
        new tmpHr = RoundToFloor( float(time) / 3600.0 );
        Format( tmp, maxlength, "%ih", tmpHr );
        time -= (tmpHr * 3600);
    }
    
    if ( time > 60 ) {
        if ( strlen( tmp ) ) {
            Format( tmp, maxlength, "%s ", tmp );
        }
        new tmpMin = RoundToFloor( float(time) / 60.0 );
        Format( tmp, maxlength, "%s%im",
                ( bPad && tmpMin < 10 ) ? " " : "" ,
                tmpMin
            );
        time -= (tmpMin * 60);
    }
    
    if ( time ) {
        Format( tmp, maxlength, "%s%s%s%is",
                tmp,
                strlen( tmp ) ? " " : "",
                ( bPad && time < 10 ) ? " " : "",
                time
            );
    }
    
    strcopy( text, maxlength, tmp );
}

stock FormatPercentage ( String:text[], maxlength, part, whole, bool: bDecimal = false ) {
    new String: strTmp[maxlength];
    
    if ( !whole || !part ) {
        FormatEx( strTmp, maxlength, "" );
        strcopy( text, maxlength, strTmp );
        return;
    }
    
    if ( bDecimal ) {
        new Float: fValue = float( part ) / float( whole ) * 100.0;
        FormatEx( strTmp, maxlength, "%3.1f", fValue );
    }
    else {
        new iValue = RoundFloat( float( part ) / float( whole ) * 100.0 );
        FormatEx( strTmp, maxlength, "%i", iValue );
    }
    
    strcopy( text, maxlength, strTmp );
}

stock CheckGameMode() {
    // check gamemode for 'coop'
    new String:tmpStr[24];
    GetConVarString( FindConVar("mp_gamemode"), tmpStr, sizeof(tmpStr) );
    
    if (    StrEqual(tmpStr, "coop", false)         ||
            StrEqual(tmpStr, "mutation4", false)    ||      // hard eight
            StrEqual(tmpStr, "mutation14", false)   ||      // gib fest
            StrEqual(tmpStr, "mutation20", false)   ||      // healing gnome
            StrEqual(tmpStr, "mutationrandomcoop", false)   // healing gnome
    ) {
        g_bModeCampaign = true;
        g_bModeScavenge = false;
    }
    else if ( StrEqual(tmpStr, "scavenge", false) ) {
        g_bModeCampaign = false;
        g_bModeScavenge = true;
    }
    else {
        g_bModeCampaign = false;
        g_bModeScavenge = false;
    }
}

stock stripUnicode ( String:testString[MAXNAME], maxLength = 20 ) {
    if ( maxLength < 1 ) { maxLength = MAXNAME; }
    
    decl String: tmpString[maxLength];
    strcopy( tmpString, maxLength, testString );
    
    new uni=0;
    new currentChar;
    new tmpCharLength = 0;
    
    for ( new i = 0; i < maxLength && tmpString[i] != 0; i++ ) {
        // estimate current character value
        if ( (tmpString[i]&0x80) == 0 ) 
        {
            // single byte character?
            currentChar = tmpString[i]; tmpCharLength = 0;
        }
        else if ( i < maxLength - 1 && ((tmpString[i]&0xE0) == 0xC0) && ((tmpString[i+1]&0xC0) == 0x80) ) 
        {
            // two byte character?
            currentChar=(tmpString[i++] & 0x1f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i] & 0x3f); 
            tmpCharLength = 1;
        }
        else if ( i < maxLength - 2 && ((tmpString[i]&0xF0) == 0xE0) && ((tmpString[i+1]&0xC0) == 0x80) && ((tmpString[i+2]&0xC0) == 0x80) ) {
            // three byte character?
            currentChar=(tmpString[i++] & 0x0f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i] & 0x3f);
            tmpCharLength = 2;
        }
        else if ( i < maxLength - 3 && ((tmpString[i]&0xF8) == 0xF0) && ((tmpString[i+1]&0xC0) == 0x80) && ((tmpString[i+2]&0xC0) == 0x80) && ((tmpString[i+3]&0xC0) == 0x80) ) {
            // four byte character?
            currentChar=(tmpString[i++] & 0x07); currentChar=currentChar<<6;
            currentChar+=(tmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(tmpString[i] & 0x3f);
            tmpCharLength = 3;
        }
        else 
        {
            currentChar = CHARTHRESHOLD + 1; // reaching this may be caused by bug in sourcemod or some kind of bug using by the user - for unicode users I do assume last ...
            tmpCharLength = 0;
        }
        
        // decide if character is allowed
        if (currentChar > CHARTHRESHOLD) {
            uni++;
            // replace this character
            // 95 = _, 32 = space
            for ( new j = tmpCharLength; j >= 0; j-- ) {
                tmpString[i - j] = 95; 
            }
        }
    }
    
    if ( strlen(tmpString) > maxLength ) {
        tmpString[maxLength] = 0;
    }
    
    strcopy( testString, maxLength, tmpString );
}

stock PrintDebug( debugLevel, const String:Message[], any:... ) {
    if (debugLevel <= GetConVarInt(g_hCvarDebug)) {
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 3);
        LogMessage(DebugBuff);
        //PrintToServer(DebugBuff);
    }
}

#define SIZE_OF_INT         2147483647 // without 0
stock Math_GetRandomInt(min, max)
{
    new random = GetURandomInt();

    if (random == 0) {
        random++;
    }

    return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}

public FilterColorCode(String:text[], maxlength) {
    ReplaceString(text, maxlength, "\x01", "");
    ReplaceString(text, maxlength, "\x03", "");
    ReplaceString(text, maxlength, "\x04", "");
    ReplaceString(text, maxlength, "\x05", "");
    PrintDebug(2, "[FilterColorCode] text: %s", text);
}