#pragma semicolon 1

#include <sourcemod>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

enum strWeaponType {
    WPTYPE_NONE,
    WPTYPE_SHOTGUN,
    WPTYPE_SMG,
    WPTYPE_SNIPER,
    WPTYPE_PISTOL
};

#define DMG_GENERIC             0               // generic damage was done
#define DMG_CRUSH               (1 << 0)        // crushed by falling or moving object. 
#define DMG_BULLET              (1 << 1)        // shot
#define DMG_SLASH               (1 << 2)        // cut, clawed, stabbed
#define DMG_BURN                (1 << 3)        // heat burned
#define DMG_BLAST               (1 << 6)        // explosive blast damage
#define DMG_CLUB                (1 << 7)        // crowbar, punch, headbutt
#define DMG_BUCKSHOT            (1 << 29)       // not quite a bullet. Little, rounder, different. 

public Plugin: myinfo = {
    name = "Bullet Test",
    author = "devilesk",
    description = "Test bullet FF event tracking",
    version = "0.1.0",
    url = ""
};

public OnPluginStart() {
     HookEvent("player_hurt",                Event_PlayerHurt,				EventHookMode_Post);
}

public Action: Event_PlayerHurt ( Handle:event, const String:name[], bool:dontBroadcast ) {
    
    new victim = GetClientOfUserId( GetEventInt(event, "userid") );
    new attacker = GetClientOfUserId( GetEventInt(event, "attacker") );
    
    new damage = GetEventInt(event, "dmg_health");
    new type;
    
    if ( IS_VALID_SURVIVOR(victim) && IS_VALID_SURVIVOR(attacker) && !IsFakeClient(attacker) ) {
        // friendly fire
        
        type = GetEventInt(event, "type");
        if ( damage < 1 ) { return Plugin_Continue; }
       
        // which type to save it to?
        if ( type & DMG_BURN ) {
            PrintToChatAll("ff burn");
        }
        else if ( type & DMG_BUCKSHOT ) {
            PrintToChatAll("ff pellet");
        }
        else if ( type & DMG_CLUB || type & DMG_SLASH ) {
            PrintToChatAll("ff melee");
        }
        else if ( type & DMG_BULLET ) {
            PrintToChatAll("ff bullet");
        }
        else {
            PrintToChatAll("ff other");
        }
        PrintToChatAll("type: %d", type);
    }

    return Plugin_Continue;
}