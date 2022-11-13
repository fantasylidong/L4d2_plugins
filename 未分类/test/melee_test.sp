#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "Melee Test",
    author = "devilesk",
    description = "Melee Test.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public OnPluginStart() {
	RegConsoleCmd("sm_meleetest", Command_MeleeTest);
}

public Action:Command_MeleeTest(client, args)  {
    // kill all held gnomes
    decl String:weapon_name[64];
	decl String:sName[128];
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2) {
            GetClientWeapon(i, weapon_name, sizeof(weapon_name));
			new secondary = GetPlayerWeaponSlot(client, 1);
			if (GetMeleeWeaponNameFromEntity(secondary, sName, sizeof(sName))) {
				PrintToChatAll("%s %s", weapon_name, sName);
			}
        }
    }
}

stock bool:GetMeleeWeaponNameFromEntity(entity, String:buffer[], length) {
    decl String:classname[64];
    if (! GetEdictClassname(entity, classname, sizeof(classname)))
    {
        return false;
    }

    if (StrEqual(classname, "weapon_melee"))
    {
        GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", buffer, length);
        return true;
    }

    return false;
}

stock PrintDebug(const String:Message[], any:...) {
    if (GetConVarBool(g_hCvarDebug)) {
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
    }
}