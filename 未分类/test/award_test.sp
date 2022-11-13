#pragma semicolon 1

#include <sourcemod>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))

public Plugin: myinfo = {
    name = "Award Test",
    author = "devilesk",
    description = "Test award event tracking",
    version = "0.1.0",
    url = ""
};

public OnPluginStart() {
    HookEvent("award_earned",               Event_AwardEarned,		EventHookMode_Post);
}

public Action: Event_AwardEarned (Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId( GetEventInt(event, "userid") );
    new award = GetEventInt(event, "award");
    //PrintToChatAll("%d earned award %d", client, award);
    if ( IS_VALID_SURVIVOR(client) && award == 67 ) {
        //PrintToChatAll("%d earned protect award", client);
    }
}