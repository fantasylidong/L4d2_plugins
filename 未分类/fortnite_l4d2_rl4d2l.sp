/*  SM Fortnite Emotes Extended
 *
 *  Copyright (C) 2020 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

/* [CS:GO|CSS|L4D] Fortnite Emotes Extended version (dances and emotes)[25-Sep-2021]
 * https://forums.alliedmods.net/showthread.php?t=318981
 */

/* Camera code from [L4D1 & L4D2] Selfie Camera [v1.0.0 | 06-June-2021] by Marttt
 * https://forums.alliedmods.net/showthread.php?t=332884
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <readyup>

#pragma newdecls required

#define DEBUG_MODE 0

#define EF_BONEMERGE          0x001
#define EF_NOSHADOW           0x010
#define EF_BONEMERGE_FASTCULL 0x080
#define EF_NORECEIVESHADOW    0x040
#define EF_PARENT_ANIMATES    0x200
#define HIDEHUD_ALL        (1 << 2)
#define HIDEHUD_CROSSHAIR  (1 << 8)
#define CVAR_FLAGS     FCVAR_NOTIFY
#define MAX_EMOTE_ID 84


ConVar g_cvHidePlayers;

TopMenu hTopMenu;

ConVar g_cvFlagEmotesMenu;
ConVar g_cvFlagDancesMenu;
ConVar g_cvCooldown;
ConVar g_cvHideWeapons;
ConVar g_cvTeleportBack;
ConVar g_cvSpeed;

int g_iEmoteEnt[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

int g_EmotesTarget[MAXPLAYERS + 1] = {0, ...};

bool g_bClientDancing[MAXPLAYERS + 1] = {false, ...};
bool g_bRoundLive = false;


Handle CooldownTimers[MAXPLAYERS + 1];
bool g_bEmoteCooldown[MAXPLAYERS + 1] = {false, ...};

int g_iWeaponHandEnt[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

Handle g_EmoteForward;
Handle g_EmoteForward_Pre;
bool g_bHooked[MAXPLAYERS + 1] = {false, ...};

float g_fLastAngles[MAXPLAYERS + 1][3];
float g_fLastPosition[MAXPLAYERS + 1][3];

bool g_bLateLoaded = false;

static int gc_iCameraDistance = 100;
static int gc_iCameraEntRef[MAXPLAYERS+1] = { INVALID_ENT_REFERENCE , ... };

public Plugin myinfo = {
    name = "SM Fortnite Emotes Extended - L4D2 Version",
    author = "Kodua, Franc1sco franug, TheBO$$, Foxhound, Marttt, devilesk",
    description = "This plugin is for demonstration of some animations from Fortnite in L4D2",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public void OnPluginStart() {
    PrintDebug("[OnPluginStart] %i", g_bLateLoaded);

    LoadTranslations("common.phrases");
    LoadTranslations("fnemotes.phrases");

    RegConsoleCmd("sm_emotes", Command_Menu, "");
    RegConsoleCmd("sm_emote", Command_Menu, "");
    RegConsoleCmd("sm_emoterandom", Command_RandomEmote, "");
    RegConsoleCmd("sm_dances", Command_Menu, "");
    RegConsoleCmd("sm_dance", Command_Menu, "");
    RegConsoleCmd("sm_dancerandom", Command_RandomDance, "");
    RegAdminCmd("sm_setemotes", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]", "");
    RegAdminCmd("sm_setemote", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]", "");
    RegAdminCmd("sm_setdances", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]", "");
    RegAdminCmd("sm_setdance", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]", "");

    HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);

    /**
    	Convars
    **/

    g_cvCooldown = CreateConVar("sm_emotes_cooldown", "2.0", "Cooldown for emotes in seconds. -1 or 0 = no cooldown.", CVAR_FLAGS);
    g_cvFlagEmotesMenu = CreateConVar("sm_emotes_admin_flag_menu", "", "admin flag for emotes (empty for all players)", CVAR_FLAGS);
    g_cvFlagDancesMenu = CreateConVar("sm_dances_admin_flag_menu", "", "admin flag for dances (empty for all players)", CVAR_FLAGS);
    g_cvHideWeapons = CreateConVar("sm_emotes_hide_weapons", "1", "Hide weapons when dancing", CVAR_FLAGS);
    g_cvHidePlayers = CreateConVar("sm_emotes_hide_enemies", "1", "Hide enemy players when dancing", CVAR_FLAGS);
    g_cvTeleportBack = CreateConVar("sm_emotes_teleportonend", "0", "Teleport back to the exact position when he started to dance. (Some maps need this for teleport triggers)", CVAR_FLAGS);
    g_cvSpeed = CreateConVar("sm_emotes_speed", "0.80", "Sets the playback speed of the animation. default (1.0)", CVAR_FLAGS);

    AutoExecConfig(true, "fortnite_emotes_extended_l4d");

    /**
    	End Convars
    **/

    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)) {
        OnAdminMenuReady(topmenu);
    }

    g_EmoteForward = CreateGlobalForward("fnemotes_OnEmote", ET_Ignore, Param_Cell);
    g_EmoteForward_Pre = CreateGlobalForward("fnemotes_OnEmote_Pre", ET_Event, Param_Cell);

    if (g_bLateLoaded) {
    
    }
}
public void OnPluginEnd() {
    PrintDebug("[OnPluginEnd]");
    for (int i = 1; i <= MaxClients; i++) {
        ResetCamera(i);
        if (IsValidClient(i) && g_bClientDancing[i]) {
            StopEmote(i);
        }
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    g_bLateLoaded = late;
    RegPluginLibrary("fnemotes");
    CreateNative("fnemotes_IsClientEmoting", Native_IsClientEmoting);
    return APLRes_Success;
}

int Native_IsClientEmoting(Handle plugin, int numParams) {
    return g_bClientDancing[GetNativeCell(1)];
}

public void OnMapStart() {

    AddFileToDownloadsTable("models/player/custom_player/foxhound/fortnite_dances_emotes_ok.mdl");
    AddFileToDownloadsTable("models/player/custom_player/foxhound/fortnite_dances_emotes_ok.vvd");
    AddFileToDownloadsTable("models/player/custom_player/foxhound/fortnite_dances_emotes_ok.dx90.vtx");

    // this dont touch
    PrecacheModel("models/player/custom_player/foxhound/fortnite_dances_emotes_ok.mdl", true);

    g_bRoundLive = false;
}

public void OnClientPutInServer(int client) {
    ResetCamera(client);
    if (IsValidClient(client)) {
        int clientTeam = GetClientTeam(client);
        int moveType = GetEntityMoveType(client);
        PrintDebug("[OnClientPutInServer] client: %i %N, clientTeam: %i, moveType: %i", client, client, clientTeam, moveType);
        TerminateEmote(client);
        g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE;

        if (CooldownTimers[client] != null) {
            KillTimer(CooldownTimers[client]);
            CooldownTimers[client] = null;
        }
    }
    else if (IsValidClient(client, false)) {
        int clientTeam = GetClientTeam(client);
        int moveType = GetEntityMoveType(client);
        PrintDebug("[OnClientPutInServer] bot client: %i %N, clientTeam: %i, moveType: %i", client, client, clientTeam, moveType);
    }
}

public void OnClientDisconnect(int client) {
    PrintDebug("[OnClientDisconnect] client: %i %N", client, client);
    if (IsValidClient(client)) {
        TerminateEmote(client);
    }
    if (CooldownTimers[client] != null) {
        KillTimer(CooldownTimers[client]);
        CooldownTimers[client] = null;
        g_bEmoteCooldown[client] = false;
    }

    g_bHooked[client] = false;

    ResetCamera(client);
}

public void OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    ResetCamera(client);
    if (IsValidClient(client)) {
        PrintDebug("[OnPlayerDeath] client: %i %N", client, client);
        StopEmote(client);
    }
}

public void PlayerTeam_Event(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    int team = GetClientOfUserId(GetEventInt(event, "team"));
    int oldteam = GetClientOfUserId(GetEventInt(event, "oldteam"));
    int clientTeam = GetClientTeam(client);
    int moveType = GetEntityMoveType(client);
    if (IsValidClient(client)) {
        PrintDebug("[PlayerTeam_Event] client: %i %N, clientTeam: %i, team: %i, oldteam: %i, moveType: %i", client, client, clientTeam, team, oldteam, moveType);
        ResetCamera(client);
        StopEmote(client);
        RequestFrame(FixClient, client);
    }
    else if (IsValidClient(client, false)) {
        PrintDebug("[PlayerTeam_Event] bot client: %i %N, clientTeam: %i, team: %i, oldteam: %i, moveType: %i", client, client, clientTeam, team, oldteam, moveType);
        RequestFrame(FixClient, client);
    }
}

public void FixClient(any data) {
    int client = data;
    if (IsValidClient(client, false)) {
        int clientTeam = GetClientTeam(client);
        int moveType = GetEntityMoveType(client);
        PrintDebug("[FixClient] client: %i %N, clientTeam: %i, moveType: %i", client, client, clientTeam, moveType);
        if (clientTeam == 2 && GetEntityMoveType(client) == MOVETYPE_NONE) {
            PrintDebug("[FixClient] fixing client: %i %N, clientTeam: %i, moveType: %i", client, client, clientTeam, moveType);
            SetEntityMoveType(client, MOVETYPE_WALK);
        }
    }
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsSurvivor(client)) {
        return Plugin_Continue;
    }

    if (attacker != client) {
        PrintDebug("[Event_PlayerHurt] client: %i %N", client, client);
        ResetCamera(client);
        StopEmote(client);
    }

    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    g_bRoundLive = false;
}

public void OnRoundLiveCountdownPre() {
    g_bRoundLive = true;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && g_bClientDancing[i]) {
            ResetCamera(i);
            StopEmote(i);
        }
    }
}

public Action Command_RandomEmote(int client, int args) {
    if (!IsValidClient(client))
        return Plugin_Handled;

    RandomEmote(client);

    return Plugin_Handled;
}

public Action Command_RandomDance(int client, int args) {
    if (!IsValidClient(client))
        return Plugin_Handled;

    RandomDance(client);

    return Plugin_Handled;
}

public Action Command_Menu(int client, int args) {
    if (!IsValidClient(client))
        return Plugin_Handled;


    char sBuffer[32];
    g_cvFlagEmotesMenu.GetString(sBuffer, sizeof(sBuffer));

    if (CheckAdminFlags(client, ReadFlagString(sBuffer))) {
        if (args == 1) {
            int amount = 1;
            char arg2[3];
            GetCmdArg(1, arg2, sizeof(arg2));
            if (StringToIntEx(arg2, amount) < 1 || StringToIntEx(arg2, amount) > MAX_EMOTE_ID) {
                CPrintToChat(client, "%t", "INVALID_EMOTE_ID");
                return Plugin_Handled;
            }
            PerformEmote(client, client, amount);
        }
        else {
            Menu_Dance(client);
        }
    } else CPrintToChat(client, "%t", "NO_DANCES_ACCESS_FLAG");

    return Plugin_Handled;
}

Action CreateEmote(int client, const char[] anim1, const char[] anim2, bool isLooped) {
    if (!IsValidClient(client)) return Plugin_Handled;
    PrintDebug("[CreateEmote] client: %i %N", client, client);

    if (g_EmoteForward_Pre != null) {
        Action res = Plugin_Continue;
        Call_StartForward(g_EmoteForward_Pre);
        Call_PushCell(client);
        Call_Finish(res);

        if (res != Plugin_Continue) {
            return Plugin_Handled;
        }
    }

    if (!IsPlayerAlive(client)) {
        CPrintToChat(client, "%t", "MUST_BE_ALIVE");
        return Plugin_Handled;
    }

    if (L4D_IsPlayerIncapacitated(client)) {
        CPrintToChat(client, "%t", "CANNOT_USE_NOW");
        return Plugin_Handled;
    }

    if (L4D_IsPlayerPinned(client)) {
        CPrintToChat(client, "%t", "CANNOT_USE_NOW");
        return Plugin_Handled;
    }

    if (!(GetEntityFlags(client) & FL_ONGROUND)) {
        CPrintToChat(client, "%t", "STAY_ON_GROUND");
        return Plugin_Handled;
    }

    if (CooldownTimers[client]) {
        CPrintToChat(client, "%t", "COOLDOWN_EMOTES");
        return Plugin_Handled;
    }

    if (StrEqual(anim1, "")) {
        CPrintToChat(client, "%t", "AMIN_1_INVALID");
        return Plugin_Handled;
    }

    if (g_iEmoteEnt[client] != INVALID_ENT_REFERENCE) StopEmote(client);

    if (GetEntityMoveType(client) == MOVETYPE_NONE) {
        CPrintToChat(client, "%t", "CANNOT_USE_NOW");
        return Plugin_Handled;
    }

    int EmoteEnt = CreateEntityByName("prop_dynamic");
    if (IsValidEntity(EmoteEnt)) {
        PrintDebug("[SetEntityMoveType] client: %i %N, MOVETYPE_NONE", client, client);
        SetEntityMoveType(client, MOVETYPE_NONE);
        //WeaponBlock(client);

        float vec[3],
            ang[3];
        GetClientAbsOrigin(client, vec);
        GetClientAbsAngles(client, ang);

        g_fLastPosition[client] = vec;
        g_fLastAngles[client] = ang;
        //int skin = -1;
        char emoteEntName[16];
        FormatEx(emoteEntName, sizeof(emoteEntName), "emoteEnt%i", GetRandomInt(1000000, 9999999));
        char model[PLATFORM_MAX_PATH];
        GetClientModel(client, model, sizeof(model));
        //skin = CreatePlayerModelProp(client, model);
        DispatchKeyValue(EmoteEnt, "targetname", emoteEntName);
        DispatchKeyValue(EmoteEnt, "model", "models/player/custom_player/foxhound/fortnite_dances_emotes_ok.mdl");
        DispatchKeyValue(EmoteEnt, "solid", "0");
        DispatchKeyValue(EmoteEnt, "rendermode", "0");

        ActivateEntity(EmoteEnt);
        DispatchSpawn(EmoteEnt);

        PrintDebug("[CreateEmote] client: %i %N, teleporting %i", client, client, EmoteEnt);
        TeleportEntity(EmoteEnt, vec, ang, NULL_VECTOR);

        SetVariantString(emoteEntName);
        int skin = 0;
        AcceptEntityInput(client, "SetParent", client, client, skin);
        PrintDebug("[AcceptEntityInput] client: %i %N, skin: %i", client, client, skin);

        g_iEmoteEnt[client] = EntIndexToEntRef(EmoteEnt);

        SetEntProp(client, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_NOSHADOW | EF_NORECEIVESHADOW | EF_BONEMERGE_FASTCULL | EF_PARENT_ANIMATES);

        if (StrEqual(anim2, "none", false)) {
            HookSingleEntityOutput(EmoteEnt, "OnAnimationDone", EndAnimation, true);
        } else {
            SetVariantString(anim2);
            AcceptEntityInput(EmoteEnt, "SetDefaultAnimation", -1, -1, 0);
        }

        SetVariantString(anim1);
        AcceptEntityInput(EmoteEnt, "SetAnimation", -1, -1, 0);

        if (g_cvSpeed.FloatValue != 1.0) SetEntPropFloat(EmoteEnt, Prop_Send, "m_flPlaybackRate", g_cvSpeed.FloatValue);

        CreateCamera(client);

        g_bClientDancing[client] = true;

        if (g_cvHidePlayers.BoolValue) {
            for (int i = 1; i <= MaxClients; i++)
                if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client) && !g_bHooked[i]) {
                    SDKHook(i, SDKHook_SetTransmit, SetTransmit);
                    g_bHooked[i] = true;
                }
        }

        if (g_cvCooldown.FloatValue > 0.0) {
            CooldownTimers[client] = CreateTimer(g_cvCooldown.FloatValue, ResetCooldown, client);
        }

        if (g_EmoteForward != null) {
            Call_StartForward(g_EmoteForward);
            Call_PushCell(client);
            Call_Finish();
        }

        if (isLooped) {}
    }
    PrintDebug("[CreateEmote] done client: %i %N", client, client);

    return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int & iButtons, int & iImpulse, float fVelocity[3], float fAngles[3], int & iWeapon) {
    //PrintDebug("[OnPlayerRunCmd] start client: %i %N", client, client);
    if (g_bClientDancing[client] && !(GetEntityFlags(client) & FL_ONGROUND)) {
        int clientTeam = GetClientTeam(client);
        int moveType = GetEntityMoveType(client);
        PrintDebug("[OnPlayerRunCmd] client: %i %N not on ground, clientTeam: %i, moveType: %i", client, client, clientTeam, moveType);
        ResetCamera(client);
        StopEmote(client);
    }

    static int iAllowedButtons = IN_BACK | IN_FORWARD | IN_MOVELEFT | IN_MOVERIGHT | IN_WALK | IN_SPEED | IN_SCORE;

    if (iButtons == 0) {
        MoveCamera(client);
        return Plugin_Continue;
    }

    if (g_iEmoteEnt[client] == INVALID_ENT_REFERENCE)
        return Plugin_Continue;

    if ((iButtons & iAllowedButtons) && !(iButtons & ~iAllowedButtons)) {
        MoveCamera(client);
        return Plugin_Continue;
    }

    PrintDebug("[OnPlayerRunCmd] client: %i %N other", client, client);
    ResetCamera(client);
    StopEmote(client);

    return Plugin_Continue;
}

void EndAnimation(const char[] output, int caller, int activator, float delay) {
    PrintDebug("[EndAnimation] caller: %i, activator %i", caller, activator);
    if (caller > 0) {
        activator = GetEmoteActivator(EntIndexToEntRef(caller));
        ResetCamera(activator);
        StopEmote(activator);
    }
}

int GetEmoteActivator(int iEntRefDancer) {
    if (iEntRefDancer == INVALID_ENT_REFERENCE)
        return 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (g_iEmoteEnt[i] == iEntRefDancer) {
            return i;
        }
    }
    return 0;
}

void StopEmote(int client) {
    PrintDebug("[StopEmote] client: %i %N, %i", client, client, g_iEmoteEnt[client] == INVALID_ENT_REFERENCE);

    if (g_iEmoteEnt[client] == INVALID_ENT_REFERENCE)
        return;

    int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
    if (iEmoteEnt && iEmoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteEnt)) {
        char emoteEntName[50];
        GetEntPropString(iEmoteEnt, Prop_Data, "m_iName", emoteEntName, sizeof(emoteEntName));
        SetVariantString(emoteEntName);
        AcceptEntityInput(client, "ClearParent", iEmoteEnt, iEmoteEnt, 0);
        DispatchKeyValue(iEmoteEnt, "OnUser1", "!self,Kill,,1.0,-1");
        AcceptEntityInput(iEmoteEnt, "FireUser1");

        //if (g_cvTeleportBack.BoolValue)
        //    TeleportEntity(client, g_fLastPosition[client], g_fLastAngles[client], NULL_VECTOR);

        //WeaponUnblock(client);
        PrintDebug("[SetEntityMoveType] client: %i %N, MOVETYPE_WALK", client, client);
        SetEntityMoveType(client, MOVETYPE_WALK);

        g_iEmoteEnt[client] = INVALID_ENT_REFERENCE;
        g_bClientDancing[client] = false;
    } else {
        g_iEmoteEnt[client] = INVALID_ENT_REFERENCE;
        g_bClientDancing[client] = false;
    }
    PrintDebug("[StopEmote] done client: %i %N, %i", client, client, g_iEmoteEnt[client] == INVALID_ENT_REFERENCE);
}

void TerminateEmote(int client) {
    PrintDebug("[TerminateEmote] client: %i %N, %i", client, client, g_iEmoteEnt[client] == INVALID_ENT_REFERENCE);
    if (g_iEmoteEnt[client] == INVALID_ENT_REFERENCE)
        return;

    int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
    if (iEmoteEnt && iEmoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteEnt)) {
        char emoteEntName[50];
        GetEntPropString(iEmoteEnt, Prop_Data, "m_iName", emoteEntName, sizeof(emoteEntName));
        SetVariantString(emoteEntName);
        AcceptEntityInput(client, "ClearParent", iEmoteEnt, iEmoteEnt, 0);
        DispatchKeyValue(iEmoteEnt, "OnUser1", "!self,Kill,,1.0,-1");
        AcceptEntityInput(iEmoteEnt, "FireUser1");
    }
    g_iEmoteEnt[client] = INVALID_ENT_REFERENCE;
    g_bClientDancing[client] = false;
}

void WeaponBlock(int client) {
    SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
    SDKHook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);

    if (g_cvHideWeapons.BoolValue)
        SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);

    int iEnt = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    PrintDebug("[WeaponBlock] client: %i %N, iEnt: %i", client, client, iEnt);
    if (iEnt != -1) {
        g_iWeaponHandEnt[client] = EntIndexToEntRef(iEnt);

        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
    }
}

void WeaponUnblock(int client) {
    int clientTeam = GetClientTeam(client);
    PrintDebug("[WeaponUnblock] client: %i %N, clientTeam: %i, g_iWeaponHandEnt: %i, %i, %i", client, client, clientTeam, g_iWeaponHandEnt[client], IsPlayerAlive(client), g_iWeaponHandEnt[client] != INVALID_ENT_REFERENCE);
    SDKUnhook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
    SDKUnhook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);

    //Even if are not activated, there will be no errors
    SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);

    if (GetEmotePeople() == 0) {
        for (int i = 1; i <= MaxClients; i++)
            if (IsClientInGame(i) && g_bHooked[i]) {
                SDKUnhook(i, SDKHook_SetTransmit, SetTransmit);
                g_bHooked[i] = false;
            }
    }

    if (IsPlayerAlive(client) && g_iWeaponHandEnt[client] != INVALID_ENT_REFERENCE) {
        int iEnt = EntRefToEntIndex(g_iWeaponHandEnt[client]);
        PrintDebug("[WeaponUnblock] client: %i %N, iEnt: %i", client, client, iEnt);
        if (iEnt != INVALID_ENT_REFERENCE) {
            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iEnt);
        }
    }

    g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE;
}

Action WeaponCanUseSwitch(int client, int weapon) {
    return Plugin_Stop;
}

void OnPostThinkPost(int client) {
    SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
}

public Action SetTransmit(int entity, int client) {
    if (g_bRoundLive && g_bClientDancing[client] && IsPlayerAlive(client) && GetClientTeam(client) != GetClientTeam(entity)) return Plugin_Handled;

    return Plugin_Continue;
}

void SetCam(int client) {
    SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 99999.3);

    SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDEHUD_CROSSHAIR);
    
    //SendConVarValue(client, FindConVar("sv_cheats"), "1");

}

void ResetCam(int client) {
    SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 0.0);

    SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~HIDEHUD_CROSSHAIR);
}

public void CreateCamera(int client)
{
    PrintDebug("[CreateCamera] client: %i %N, %i", client, client, gc_iCameraEntRef[client] != INVALID_ENT_REFERENCE);
    int entity;
    if (gc_iCameraEntRef[client] != INVALID_ENT_REFERENCE)
    {
        entity = EntRefToEntIndex(gc_iCameraEntRef[client]);

        if (entity != INVALID_ENT_REFERENCE)
        {
            AcceptEntityInput(entity, "Disable");
            AcceptEntityInput(entity, "Kill");
        }

        gc_iCameraEntRef[client] = INVALID_ENT_REFERENCE;
    }
    else
    {
        float vEyeAng[3];
        GetClientEyeAngles(client, vEyeAng);
        vEyeAng[0] = 0.0;
        vEyeAng[2] = 0.0;

        PrintDebug("[CreateCamera] client: %i %N, teleporting", client, client);
        TeleportEntity(client, NULL_VECTOR, vEyeAng, NULL_VECTOR);
    }

    //NOTE: point_viewcontrol makes the player invunerable while enabled on camera, point_viewcontrol_survivor/point_viewcontrol_multiplayer don't.
    entity = CreateEntityByName("point_viewcontrol_survivor");
    gc_iCameraEntRef[client] = EntIndexToEntRef(entity);
    DispatchKeyValue(entity, "targetname", "l4d_selfie_camera");
    DispatchSpawn(entity);

    AcceptEntityInput(entity, "Enable", client);
}

public void MoveCamera(int client)
{
    if (IsValidClientIndex(client) && gc_iCameraEntRef[client] != INVALID_ENT_REFERENCE)
    {
        static float vPos[3];
        static float vDir[3];
        static float vAng[3];

        static int entity;
        entity = EntRefToEntIndex(gc_iCameraEntRef[client]);
    
        if (entity != INVALID_ENT_REFERENCE)
        {
            GetClientEyePosition(client, vPos);
            GetClientEyeAngles(client, vDir);
            GetAngleVectors(vDir, vAng, NULL_VECTOR, NULL_VECTOR);

            vPos[0] += (vAng[0] * gc_iCameraDistance);
            vPos[1] += (vAng[1] * gc_iCameraDistance);
            vPos[2] += (vAng[2] * gc_iCameraDistance);

            vDir[0] *= -1.0;
            vDir[1] += 180.0;
            vDir[2] = 0.0;

            PrintDebug("[MoveCamera] client: %i %N, teleporting %i", client, client, entity);
            TeleportEntity(entity, vPos, vDir, NULL_VECTOR);
        }
        else {
            gc_iCameraEntRef[client] = INVALID_ENT_REFERENCE;
        }
    }
}

public void ResetCamera(int client)
{
    if (!IsValidClientIndex(client))
        return;

    if (gc_iCameraEntRef[client] == INVALID_ENT_REFERENCE)
        return;

    static int entity;
    entity = EntRefToEntIndex(gc_iCameraEntRef[client]);

    if (entity != INVALID_ENT_REFERENCE)
    {
        AcceptEntityInput(entity, "Disable");
        AcceptEntityInput(entity, "Kill");
    }

    gc_iCameraEntRef[client] = INVALID_ENT_REFERENCE;
}

Action ResetCooldown(Handle timer, any client) {
    PrintDebug("[ResetCooldown]");
    CooldownTimers[client] = null;
    return Plugin_Stop;
}

Action Menu_Dance(int client) {
    Menu menu = new Menu(MenuHandler1);

    char title[65];
    Format(title, sizeof(title), "%T:", "TITLE_MAIM_MENU", client);
    menu.SetTitle(title);

    AddTranslatedMenuItem(menu, "", "RANDOM_EMOTE", client);
    AddTranslatedMenuItem(menu, "", "RANDOM_DANCE", client);
    AddTranslatedMenuItem(menu, "", "EMOTES_LIST", client);
    AddTranslatedMenuItem(menu, "", "DANCES_LIST", client);

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

int MenuHandler1(Menu menu, MenuAction action, int param1, int param2) {
    switch (action) {
        case MenuAction_Select: {
            int client = param1;

            switch (param2) {
                case 0: {
                    RandomEmote(client);
                    Menu_Dance(client);
                }
                case 1: {
                    RandomDance(client);
                    Menu_Dance(client);
                }
                case 2:
                    EmotesMenu(client);
                case 3:
                    DancesMenu(client);
            }
        }
        case MenuAction_End: {
            delete menu;
        }
    }
    return 0;
}


Action EmotesMenu(int client) {
    char sBuffer[32];
    g_cvFlagEmotesMenu.GetString(sBuffer, sizeof(sBuffer));

    if (!CheckAdminFlags(client, ReadFlagString(sBuffer))) {
        CPrintToChat(client, "%t", "NO_EMOTES_ACCESS_FLAG");
        return Plugin_Handled;
    }
    Menu menu = new Menu(MenuHandlerEmotes);

    char title[65];
    Format(title, sizeof(title), "%T:", "TITLE_EMOTES_MENU", client);
    menu.SetTitle(title);

    AddTranslatedMenuItem(menu, "1", "Emote_Fonzie_Pistol", client);
    AddTranslatedMenuItem(menu, "2", "Emote_Bring_It_On", client);
    AddTranslatedMenuItem(menu, "3", "Emote_ThumbsDown", client);
    AddTranslatedMenuItem(menu, "4", "Emote_ThumbsUp", client);
    AddTranslatedMenuItem(menu, "5", "Emote_Celebration_Loop", client);
    AddTranslatedMenuItem(menu, "6", "Emote_BlowKiss", client);
    AddTranslatedMenuItem(menu, "7", "Emote_Calculated", client);
    AddTranslatedMenuItem(menu, "8", "Emote_Confused", client);
    AddTranslatedMenuItem(menu, "9", "Emote_Chug", client);
    AddTranslatedMenuItem(menu, "10", "Emote_Cry", client);
    AddTranslatedMenuItem(menu, "11", "Emote_DustingOffHands", client);
    AddTranslatedMenuItem(menu, "12", "Emote_DustOffShoulders", client);
    AddTranslatedMenuItem(menu, "13", "Emote_Facepalm", client);
    AddTranslatedMenuItem(menu, "14", "Emote_Fishing", client);
    AddTranslatedMenuItem(menu, "15", "Emote_Flex", client);
    AddTranslatedMenuItem(menu, "16", "Emote_golfclap", client);
    AddTranslatedMenuItem(menu, "17", "Emote_HandSignals", client);
    AddTranslatedMenuItem(menu, "18", "Emote_HeelClick", client);
    AddTranslatedMenuItem(menu, "19", "Emote_Hotstuff", client);
    AddTranslatedMenuItem(menu, "20", "Emote_IBreakYou", client);
    AddTranslatedMenuItem(menu, "21", "Emote_IHeartYou", client);
    AddTranslatedMenuItem(menu, "22", "Emote_Kung-Fu_Salute", client);
    AddTranslatedMenuItem(menu, "23", "Emote_Laugh", client);
    AddTranslatedMenuItem(menu, "24", "Emote_Luchador", client);
    AddTranslatedMenuItem(menu, "25", "Emote_Make_It_Rain", client);
    AddTranslatedMenuItem(menu, "26", "Emote_NotToday", client);
    AddTranslatedMenuItem(menu, "27", "Emote_RockPaperScissor_Paper", client);
    AddTranslatedMenuItem(menu, "28", "Emote_RockPaperScissor_Rock", client);
    AddTranslatedMenuItem(menu, "29", "Emote_RockPaperScissor_Scissor", client);
    AddTranslatedMenuItem(menu, "30", "Emote_Salt", client);
    AddTranslatedMenuItem(menu, "31", "Emote_Salute", client);
    AddTranslatedMenuItem(menu, "32", "Emote_SmoothDrive", client);
    AddTranslatedMenuItem(menu, "33", "Emote_Snap", client);
    AddTranslatedMenuItem(menu, "34", "Emote_StageBow", client);
    AddTranslatedMenuItem(menu, "35", "Emote_Wave2", client);
    AddTranslatedMenuItem(menu, "36", "Emote_Yeet", client);

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

int MenuHandlerEmotes(Menu menu, MenuAction action, int client, int param2) {
    switch (action) {
        case MenuAction_Select: {
            char info[16];
            if (menu.GetItem(param2, info, sizeof(info))) {
                int iParam2 = StringToInt(info);

                switch (iParam2) {
                    case 1:
                        CreateEmote(client, "Emote_Fonzie_Pistol", "none", false);
                    case 2:
                        CreateEmote(client, "Emote_Bring_It_On", "none", false);
                    case 3:
                        CreateEmote(client, "Emote_ThumbsDown", "none", false);
                    case 4:
                        CreateEmote(client, "Emote_ThumbsUp", "none", false);
                    case 5:
                        CreateEmote(client, "Emote_Celebration_Loop", "", false);
                    case 6:
                        CreateEmote(client, "Emote_BlowKiss", "none", false);
                    case 7:
                        CreateEmote(client, "Emote_Calculated", "none", false);
                    case 8:
                        CreateEmote(client, "Emote_Confused", "none", false);
                    case 9:
                        CreateEmote(client, "Emote_Chug", "none", false);
                    case 10:
                        CreateEmote(client, "Emote_Cry", "none", false);
                    case 11:
                        CreateEmote(client, "Emote_DustingOffHands", "none", true);
                    case 12:
                        CreateEmote(client, "Emote_DustOffShoulders", "none", true);
                    case 13:
                        CreateEmote(client, "Emote_Facepalm", "none", false);
                    case 14:
                        CreateEmote(client, "Emote_Fishing", "none", false);
                    case 15:
                        CreateEmote(client, "Emote_Flex", "none", false);
                    case 16:
                        CreateEmote(client, "Emote_golfclap", "none", false);
                    case 17:
                        CreateEmote(client, "Emote_HandSignals", "none", false);
                    case 18:
                        CreateEmote(client, "Emote_HeelClick", "none", false);
                    case 19:
                        CreateEmote(client, "Emote_Hotstuff", "none", false);
                    case 20:
                        CreateEmote(client, "Emote_IBreakYou", "none", false);
                    case 21:
                        CreateEmote(client, "Emote_IHeartYou", "none", false);
                    case 22:
                        CreateEmote(client, "Emote_Kung-Fu_Salute", "none", false);
                    case 23:
                        CreateEmote(client, "Emote_Laugh", "Emote_Laugh_CT", false);
                    case 24:
                        CreateEmote(client, "Emote_Luchador", "none", false);
                    case 25:
                        CreateEmote(client, "Emote_Make_It_Rain", "none", false);
                    case 26:
                        CreateEmote(client, "Emote_NotToday", "none", false);
                    case 27:
                        CreateEmote(client, "Emote_RockPaperScissor_Paper", "none", false);
                    case 28:
                        CreateEmote(client, "Emote_RockPaperScissor_Rock", "none", false);
                    case 29:
                        CreateEmote(client, "Emote_RockPaperScissor_Scissor", "none", false);
                    case 30:
                        CreateEmote(client, "Emote_Salt", "none", false);
                    case 31:
                        CreateEmote(client, "Emote_Salute", "none", false);
                    case 32:
                        CreateEmote(client, "Emote_SmoothDrive", "none", false);
                    case 33:
                        CreateEmote(client, "Emote_Snap", "none", false);
                    case 34:
                        CreateEmote(client, "Emote_StageBow", "none", false);
                    case 35:
                        CreateEmote(client, "Emote_Wave2", "none", false);
                    case 36:
                        CreateEmote(client, "Emote_Yeet", "none", false);

                }
            }
            menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
        }
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_Dance(client);
            }
        }
    }
    return 0;
}

Action DancesMenu(int client) {
    char sBuffer[32];
    g_cvFlagDancesMenu.GetString(sBuffer, sizeof(sBuffer));

    if (!CheckAdminFlags(client, ReadFlagString(sBuffer))) {
        CPrintToChat(client, "%t", "NO_DANCES_ACCESS_FLAG");
        return Plugin_Handled;
    }
    Menu menu = new Menu(MenuHandlerDances);

    char title[65];
    Format(title, sizeof(title), "%T:", "TITLE_DANCES_MENU", client);
    menu.SetTitle(title);

    AddTranslatedMenuItem(menu, "1", "DanceMoves", client);
    AddTranslatedMenuItem(menu, "2", "Emote_Mask_Off_Intro", client);
    AddTranslatedMenuItem(menu, "3", "Emote_Zippy_Dance", client);
    AddTranslatedMenuItem(menu, "4", "ElectroShuffle", client);
    AddTranslatedMenuItem(menu, "5", "Emote_AerobicChamp", client);
    AddTranslatedMenuItem(menu, "6", "Emote_Bendy", client);
    AddTranslatedMenuItem(menu, "7", "Emote_BandOfTheFort", client);
    AddTranslatedMenuItem(menu, "8", "Emote_Boogie_Down_Intro", client);
    AddTranslatedMenuItem(menu, "9", "Emote_Capoeira", client);
    AddTranslatedMenuItem(menu, "10", "Emote_Charleston", client);
    AddTranslatedMenuItem(menu, "11", "Emote_Chicken", client);
    AddTranslatedMenuItem(menu, "12", "Emote_Dance_NoBones", client);
    AddTranslatedMenuItem(menu, "13", "Emote_Dance_Shoot", client);
    AddTranslatedMenuItem(menu, "14", "Emote_Dance_SwipeIt", client);
    AddTranslatedMenuItem(menu, "15", "Emote_Dance_Disco_T3", client);
    AddTranslatedMenuItem(menu, "16", "Emote_DG_Disco", client);
    AddTranslatedMenuItem(menu, "17", "Emote_Dance_Worm", client);
    AddTranslatedMenuItem(menu, "18", "Emote_Dance_Loser", client);
    AddTranslatedMenuItem(menu, "19", "Emote_Dance_Breakdance", client);
    AddTranslatedMenuItem(menu, "20", "Emote_Dance_Pump", client);
    AddTranslatedMenuItem(menu, "21", "Emote_Dance_RideThePony", client);
    AddTranslatedMenuItem(menu, "22", "Emote_Dab", client);
    AddTranslatedMenuItem(menu, "23", "Emote_EasternBloc_Start", client);
    AddTranslatedMenuItem(menu, "24", "Emote_FancyFeet", client);
    AddTranslatedMenuItem(menu, "25", "Emote_FlossDance", client);
    AddTranslatedMenuItem(menu, "26", "Emote_FlippnSexy", client);
    AddTranslatedMenuItem(menu, "27", "Emote_Fresh", client);
    AddTranslatedMenuItem(menu, "28", "Emote_GrooveJam", client);
    AddTranslatedMenuItem(menu, "29", "Emote_guitar", client);
    AddTranslatedMenuItem(menu, "30", "Emote_Hillbilly_Shuffle_Intro", client);
    AddTranslatedMenuItem(menu, "31", "Emote_Hiphop_01", client);
    AddTranslatedMenuItem(menu, "32", "Emote_Hula_Start", client);
    AddTranslatedMenuItem(menu, "33", "Emote_InfiniDab_Intro", client);
    AddTranslatedMenuItem(menu, "34", "Emote_Intensity_Start", client);
    AddTranslatedMenuItem(menu, "35", "Emote_IrishJig_Start", client);
    AddTranslatedMenuItem(menu, "36", "Emote_KoreanEagle", client);
    AddTranslatedMenuItem(menu, "37", "Emote_Kpop_02", client);
    AddTranslatedMenuItem(menu, "38", "Emote_LivingLarge", client);
    AddTranslatedMenuItem(menu, "39", "Emote_Maracas", client);
    AddTranslatedMenuItem(menu, "40", "Emote_PopLock", client);
    AddTranslatedMenuItem(menu, "41", "Emote_PopRock", client);
    AddTranslatedMenuItem(menu, "42", "Emote_RobotDance", client);
    AddTranslatedMenuItem(menu, "43", "Emote_T-Rex", client);
    AddTranslatedMenuItem(menu, "44", "Emote_TechnoZombie", client);
    AddTranslatedMenuItem(menu, "45", "Emote_Twist", client);
    AddTranslatedMenuItem(menu, "46", "Emote_WarehouseDance_Start", client);
    AddTranslatedMenuItem(menu, "47", "Emote_Wiggle", client);
    AddTranslatedMenuItem(menu, "48", "Emote_Youre_Awesome", client);

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

int MenuHandlerDances(Menu menu, MenuAction action, int client, int param2) {
    switch (action) {
        case MenuAction_Select: {
            char info[16];
            if (menu.GetItem(param2, info, sizeof(info))) {
                int iParam2 = StringToInt(info);

                switch (iParam2) {
                    case 1:
                        CreateEmote(client, "DanceMoves", "none", false);
                    case 2:
                        CreateEmote(client, "Emote_Mask_Off_Intro", "Emote_Mask_Off_Loop", true);
                    case 3:
                        CreateEmote(client, "Emote_Zippy_Dance", "none", true);
                    case 4:
                        CreateEmote(client, "ElectroShuffle", "none", true);
                    case 5:
                        CreateEmote(client, "Emote_AerobicChamp", "none", true);
                    case 6:
                        CreateEmote(client, "Emote_Bendy", "none", true);
                    case 7:
                        CreateEmote(client, "Emote_BandOfTheFort", "none", true);
                    case 8:
                        CreateEmote(client, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", true);
                    case 9:
                        CreateEmote(client, "Emote_Capoeira", "none", false);
                    case 10:
                        CreateEmote(client, "Emote_Charleston", "none", true);
                    case 11:
                        CreateEmote(client, "Emote_Chicken", "none", true);
                    case 12:
                        CreateEmote(client, "Emote_Dance_NoBones", "none", true);
                    case 13:
                        CreateEmote(client, "Emote_Dance_Shoot", "none", true);
                    case 14:
                        CreateEmote(client, "Emote_Dance_SwipeIt", "none", true);
                    case 15:
                        CreateEmote(client, "Emote_Dance_Disco_T3", "none", true);
                    case 16:
                        CreateEmote(client, "Emote_DG_Disco", "none", true);
                    case 17:
                        CreateEmote(client, "Emote_Dance_Worm", "none", false);
                    case 18:
                        CreateEmote(client, "Emote_Dance_Loser", "Emote_Dance_Loser_CT", true);
                    case 19:
                        CreateEmote(client, "Emote_Dance_Breakdance", "none", false);
                    case 20:
                        CreateEmote(client, "Emote_Dance_Pump", "none", true);
                    case 21:
                        CreateEmote(client, "Emote_Dance_RideThePony", "none", false);
                    case 22:
                        CreateEmote(client, "Emote_Dab", "none", false);
                    case 23:
                        CreateEmote(client, "Emote_EasternBloc_Start", "Emote_EasternBloc", true);
                    case 24:
                        CreateEmote(client, "Emote_FancyFeet", "Emote_FancyFeet_CT", true);
                    case 25:
                        CreateEmote(client, "Emote_FlossDance", "none", true);
                    case 26:
                        CreateEmote(client, "Emote_FlippnSexy", "none", false);
                    case 27:
                        CreateEmote(client, "Emote_Fresh", "none", true);
                    case 28:
                        CreateEmote(client, "Emote_GrooveJam", "none", true);
                    case 29:
                        CreateEmote(client, "Emote_guitar", "none", true);
                    case 30:
                        CreateEmote(client, "Emote_Hillbilly_Shuffle_Intro", "Emote_Hillbilly_Shuffle", true);
                    case 31:
                        CreateEmote(client, "Emote_Hiphop_01", "Emote_Hip_Hop", true);
                    case 32:
                        CreateEmote(client, "Emote_Hula_Start", "Emote_Hula", true);
                    case 33:
                        CreateEmote(client, "Emote_InfiniDab_Intro", "Emote_InfiniDab_Loop", true);
                    case 34:
                        CreateEmote(client, "Emote_Intensity_Start", "Emote_Intensity_Loop", true);
                    case 35:
                        CreateEmote(client, "Emote_IrishJig_Start", "Emote_IrishJig", true);
                    case 36:
                        CreateEmote(client, "Emote_KoreanEagle", "none", true);
                    case 37:
                        CreateEmote(client, "Emote_Kpop_02", "none", true);
                    case 38:
                        CreateEmote(client, "Emote_LivingLarge", "none", true);
                    case 39:
                        CreateEmote(client, "Emote_Maracas", "none", true);
                    case 40:
                        CreateEmote(client, "Emote_PopLock", "none", true);
                    case 41:
                        CreateEmote(client, "Emote_PopRock", "none", true);
                    case 42:
                        CreateEmote(client, "Emote_RobotDance", "none", true);
                    case 43:
                        CreateEmote(client, "Emote_T-Rex", "none", false);
                    case 44:
                        CreateEmote(client, "Emote_TechnoZombie", "none", true);
                    case 45:
                        CreateEmote(client, "Emote_Twist", "none", true);
                    case 46:
                        CreateEmote(client, "Emote_WarehouseDance_Start", "Emote_WarehouseDance_Loop", true);
                    case 47:
                        CreateEmote(client, "Emote_Wiggle", "none", true);
                    case 48:
                        CreateEmote(client, "Emote_Youre_Awesome", "none", false);
                }
            }
            menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
        }
        case MenuAction_Cancel: {
            if (param2 == MenuCancel_ExitBack) {
                Menu_Dance(client);
            }
        }
    }
    return 0;
}

void RandomEmote(int i) {
    char sBuffer[32];
    g_cvFlagEmotesMenu.GetString(sBuffer, sizeof(sBuffer));

    if (!CheckAdminFlags(i, ReadFlagString(sBuffer))) {
        CPrintToChat(i, "%t", "NO_EMOTES_ACCESS_FLAG");
        return;
    }

    int number = GetRandomInt(1, 36);

    switch (number) {
        case 1:
            CreateEmote(i, "Emote_Fonzie_Pistol", "none", false);
        case 2:
            CreateEmote(i, "Emote_Bring_It_On", "none", false);
        case 3:
            CreateEmote(i, "Emote_ThumbsDown", "none", false);
        case 4:
            CreateEmote(i, "Emote_ThumbsUp", "none", false);
        case 5:
            CreateEmote(i, "Emote_Celebration_Loop", "", false);
        case 6:
            CreateEmote(i, "Emote_BlowKiss", "none", false);
        case 7:
            CreateEmote(i, "Emote_Calculated", "none", false);
        case 8:
            CreateEmote(i, "Emote_Confused", "none", false);
        case 9:
            CreateEmote(i, "Emote_Chug", "none", false);
        case 10:
            CreateEmote(i, "Emote_Cry", "none", false);
        case 11:
            CreateEmote(i, "Emote_DustingOffHands", "none", true);
        case 12:
            CreateEmote(i, "Emote_DustOffShoulders", "none", true);
        case 13:
            CreateEmote(i, "Emote_Facepalm", "none", false);
        case 14:
            CreateEmote(i, "Emote_Fishing", "none", false);
        case 15:
            CreateEmote(i, "Emote_Flex", "none", false);
        case 16:
            CreateEmote(i, "Emote_golfclap", "none", false);
        case 17:
            CreateEmote(i, "Emote_HandSignals", "none", false);
        case 18:
            CreateEmote(i, "Emote_HeelClick", "none", false);
        case 19:
            CreateEmote(i, "Emote_Hotstuff", "none", false);
        case 20:
            CreateEmote(i, "Emote_IBreakYou", "none", false);
        case 21:
            CreateEmote(i, "Emote_IHeartYou", "none", false);
        case 22:
            CreateEmote(i, "Emote_Kung-Fu_Salute", "none", false);
        case 23:
            CreateEmote(i, "Emote_Laugh", "Emote_Laugh_CT", false);
        case 24:
            CreateEmote(i, "Emote_Luchador", "none", false);
        case 25:
            CreateEmote(i, "Emote_Make_It_Rain", "none", false);
        case 26:
            CreateEmote(i, "Emote_NotToday", "none", false);
        case 27:
            CreateEmote(i, "Emote_RockPaperScissor_Paper", "none", false);
        case 28:
            CreateEmote(i, "Emote_RockPaperScissor_Rock", "none", false);
        case 29:
            CreateEmote(i, "Emote_RockPaperScissor_Scissor", "none", false);
        case 30:
            CreateEmote(i, "Emote_Salt", "none", false);
        case 31:
            CreateEmote(i, "Emote_Salute", "none", false);
        case 32:
            CreateEmote(i, "Emote_SmoothDrive", "none", false);
        case 33:
            CreateEmote(i, "Emote_Snap", "none", false);
        case 34:
            CreateEmote(i, "Emote_StageBow", "none", false);
        case 35:
            CreateEmote(i, "Emote_Wave2", "none", false);
        case 36:
            CreateEmote(i, "Emote_Yeet", "none", false);
    }

}

void RandomDance(int i) {
    char sBuffer[32];
    g_cvFlagDancesMenu.GetString(sBuffer, sizeof(sBuffer));

    if (!CheckAdminFlags(i, ReadFlagString(sBuffer))) {
        CPrintToChat(i, "%t", "NO_DANCES_ACCESS_FLAG");
        return;
    }
    int number = GetRandomInt(1, 48);

    switch (number) {
        case 1:
            CreateEmote(i, "DanceMoves", "none", false);
        case 2:
            CreateEmote(i, "Emote_Mask_Off_Intro", "Emote_Mask_Off_Loop", true);
        case 3:
            CreateEmote(i, "Emote_Zippy_Dance", "none", true);
        case 4:
            CreateEmote(i, "ElectroShuffle", "none", true);
        case 5:
            CreateEmote(i, "Emote_AerobicChamp", "none", true);
        case 6:
            CreateEmote(i, "Emote_Bendy", "none", true);
        case 7:
            CreateEmote(i, "Emote_BandOfTheFort", "none", true);
        case 8:
            CreateEmote(i, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", true);
        case 9:
            CreateEmote(i, "Emote_Capoeira", "none", false);
        case 10:
            CreateEmote(i, "Emote_Charleston", "none", true);
        case 11:
            CreateEmote(i, "Emote_Chicken", "none", true);
        case 12:
            CreateEmote(i, "Emote_Dance_NoBones", "none", true);
        case 13:
            CreateEmote(i, "Emote_Dance_Shoot", "none", true);
        case 14:
            CreateEmote(i, "Emote_Dance_SwipeIt", "none", true);
        case 15:
            CreateEmote(i, "Emote_Dance_Disco_T3", "none", true);
        case 16:
            CreateEmote(i, "Emote_DG_Disco", "none", true);
        case 17:
            CreateEmote(i, "Emote_Dance_Worm", "none", false);
        case 18:
            CreateEmote(i, "Emote_Dance_Loser", "Emote_Dance_Loser_CT", true);
        case 19:
            CreateEmote(i, "Emote_Dance_Breakdance", "none", false);
        case 20:
            CreateEmote(i, "Emote_Dance_Pump", "none", true);
        case 21:
            CreateEmote(i, "Emote_Dance_RideThePony", "none", false);
        case 22:
            CreateEmote(i, "Emote_Dab", "none", false);
        case 23:
            CreateEmote(i, "Emote_EasternBloc_Start", "Emote_EasternBloc", true);
        case 24:
            CreateEmote(i, "Emote_FancyFeet", "Emote_FancyFeet_CT", true);
        case 25:
            CreateEmote(i, "Emote_FlossDance", "none", true);
        case 26:
            CreateEmote(i, "Emote_FlippnSexy", "none", false);
        case 27:
            CreateEmote(i, "Emote_Fresh", "none", true);
        case 28:
            CreateEmote(i, "Emote_GrooveJam", "none", true);
        case 29:
            CreateEmote(i, "Emote_guitar", "none", true);
        case 30:
            CreateEmote(i, "Emote_Hillbilly_Shuffle_Intro", "Emote_Hillbilly_Shuffle", true);
        case 31:
            CreateEmote(i, "Emote_Hiphop_01", "Emote_Hip_Hop", true);
        case 32:
            CreateEmote(i, "Emote_Hula_Start", "Emote_Hula", true);
        case 33:
            CreateEmote(i, "Emote_InfiniDab_Intro", "Emote_InfiniDab_Loop", true);
        case 34:
            CreateEmote(i, "Emote_Intensity_Start", "Emote_Intensity_Loop", true);
        case 35:
            CreateEmote(i, "Emote_IrishJig_Start", "Emote_IrishJig", true);
        case 36:
            CreateEmote(i, "Emote_KoreanEagle", "none", true);
        case 37:
            CreateEmote(i, "Emote_Kpop_02", "none", true);
        case 38:
            CreateEmote(i, "Emote_LivingLarge", "none", true);
        case 39:
            CreateEmote(i, "Emote_Maracas", "none", true);
        case 40:
            CreateEmote(i, "Emote_PopLock", "none", true);
        case 41:
            CreateEmote(i, "Emote_PopRock", "none", true);
        case 42:
            CreateEmote(i, "Emote_RobotDance", "none", true);
        case 43:
            CreateEmote(i, "Emote_T-Rex", "none", false);
        case 44:
            CreateEmote(i, "Emote_TechnoZombie", "none", true);
        case 45:
            CreateEmote(i, "Emote_Twist", "none", true);
        case 46:
            CreateEmote(i, "Emote_WarehouseDance_Start", "Emote_WarehouseDance_Loop", true);
        case 47:
            CreateEmote(i, "Emote_Wiggle", "none", true);
        case 48:
            CreateEmote(i, "Emote_Youre_Awesome", "none", false);
    }
}


Action Command_Admin_Emotes(int client, int args) {
    if (args < 1) {
        CPrintToChat(client, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");
        return Plugin_Handled;
    }

    char arg[65];
    GetCmdArg(1, arg, sizeof(arg));

    int amount = 1;
    if (args > 1) {
        char arg2[3];
        GetCmdArg(2, arg2, sizeof(arg2));
        if (StringToIntEx(arg2, amount) < 1 || StringToIntEx(arg2, amount) > MAX_EMOTE_ID) {
            CPrintToChat(client, "%t", "INVALID_EMOTE_ID");
            return Plugin_Handled;
        }
    }

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(
            arg,
            client,
            target_list,
            MAXPLAYERS,
            COMMAND_FILTER_ALIVE,
            target_name,
            sizeof(target_name),
            tn_is_ml)) <= 0) {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }


    for (int i = 0; i < target_count; i++) {
        PerformEmote(client, target_list[i], amount);
    }

    return Plugin_Handled;
}

void PerformEmote(int client, int target, int amount) {
    switch (amount) {
        case 1:
            CreateEmote(target, "Emote_Fonzie_Pistol", "none", false);
        case 2:
            CreateEmote(target, "Emote_Bring_It_On", "none", false);
        case 3:
            CreateEmote(target, "Emote_ThumbsDown", "none", false);
        case 4:
            CreateEmote(target, "Emote_ThumbsUp", "none", false);
        case 5:
            CreateEmote(target, "Emote_Celebration_Loop", "", false);
        case 6:
            CreateEmote(target, "Emote_BlowKiss", "none", false);
        case 7:
            CreateEmote(target, "Emote_Calculated", "none", false);
        case 8:
            CreateEmote(target, "Emote_Confused", "none", false);
        case 9:
            CreateEmote(target, "Emote_Chug", "none", false);
        case 10:
            CreateEmote(target, "Emote_Cry", "none", false);
        case 11:
            CreateEmote(target, "Emote_DustingOffHands", "none", true);
        case 12:
            CreateEmote(target, "Emote_DustOffShoulders", "none", true);
        case 13:
            CreateEmote(target, "Emote_Facepalm", "none", false);
        case 14:
            CreateEmote(target, "Emote_Fishing", "none", false);
        case 15:
            CreateEmote(target, "Emote_Flex", "none", false);
        case 16:
            CreateEmote(target, "Emote_golfclap", "none", false);
        case 17:
            CreateEmote(target, "Emote_HandSignals", "none", false);
        case 18:
            CreateEmote(target, "Emote_HeelClick", "none", false);
        case 19:
            CreateEmote(target, "Emote_Hotstuff", "none", false);
        case 20:
            CreateEmote(target, "Emote_IBreakYou", "none", false);
        case 21:
            CreateEmote(target, "Emote_IHeartYou", "none", false);
        case 22:
            CreateEmote(target, "Emote_Kung-Fu_Salute", "none", false);
        case 23:
            CreateEmote(target, "Emote_Laugh", "Emote_Laugh_CT", false);
        case 24:
            CreateEmote(target, "Emote_Luchador", "none", false);
        case 25:
            CreateEmote(target, "Emote_Make_It_Rain", "none", false);
        case 26:
            CreateEmote(target, "Emote_NotToday", "none", false);
        case 27:
            CreateEmote(target, "Emote_RockPaperScissor_Paper", "none", false);
        case 28:
            CreateEmote(target, "Emote_RockPaperScissor_Rock", "none", false);
        case 29:
            CreateEmote(target, "Emote_RockPaperScissor_Scissor", "none", false);
        case 30:
            CreateEmote(target, "Emote_Salt", "none", false);
        case 31:
            CreateEmote(target, "Emote_Salute", "none", false);
        case 32:
            CreateEmote(target, "Emote_SmoothDrive", "none", false);
        case 33:
            CreateEmote(target, "Emote_Snap", "none", false);
        case 34:
            CreateEmote(target, "Emote_StageBow", "none", false);
        case 35:
            CreateEmote(target, "Emote_Wave2", "none", false);
        case 36:
            CreateEmote(target, "Emote_Yeet", "none", false);
        case 37:
            CreateEmote(target, "DanceMoves", "none", false);
        case 38:
            CreateEmote(target, "Emote_Mask_Off_Intro", "Emote_Mask_Off_Loop", true);
        case 39:
            CreateEmote(target, "Emote_Zippy_Dance", "none", true);
        case 40:
            CreateEmote(target, "ElectroShuffle", "none", true);
        case 41:
            CreateEmote(target, "Emote_AerobicChamp", "none", true);
        case 42:
            CreateEmote(target, "Emote_Bendy", "none", true);
        case 43:
            CreateEmote(target, "Emote_BandOfTheFort", "none", true);
        case 44:
            CreateEmote(target, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", true);
        case 45:
            CreateEmote(target, "Emote_Capoeira", "none", false);
        case 46:
            CreateEmote(target, "Emote_Charleston", "none", true);
        case 47:
            CreateEmote(target, "Emote_Chicken", "none", true);
        case 48:
            CreateEmote(target, "Emote_Dance_NoBones", "none", true);
        case 49:
            CreateEmote(target, "Emote_Dance_Shoot", "none", true);
        case 50:
            CreateEmote(target, "Emote_Dance_SwipeIt", "none", true);
        case 51:
            CreateEmote(target, "Emote_Dance_Disco_T3", "none", true);
        case 52:
            CreateEmote(target, "Emote_DG_Disco", "none", true);
        case 53:
            CreateEmote(target, "Emote_Dance_Worm", "none", false);
        case 54:
            CreateEmote(target, "Emote_Dance_Loser", "Emote_Dance_Loser_CT", true);
        case 55:
            CreateEmote(target, "Emote_Dance_Breakdance", "none", false);
        case 56:
            CreateEmote(target, "Emote_Dance_Pump", "none", true);
        case 57:
            CreateEmote(target, "Emote_Dance_RideThePony", "none", false);
        case 58:
            CreateEmote(target, "Emote_Dab", "none", false);
        case 59:
            CreateEmote(target, "Emote_EasternBloc_Start", "Emote_EasternBloc", true);
        case 60:
            CreateEmote(target, "Emote_FancyFeet", "Emote_FancyFeet_CT", true);
        case 61:
            CreateEmote(target, "Emote_FlossDance", "none", true);
        case 62:
            CreateEmote(target, "Emote_FlippnSexy", "none", false);
        case 63:
            CreateEmote(target, "Emote_Fresh", "none", true);
        case 64:
            CreateEmote(target, "Emote_GrooveJam", "none", true);
        case 65:
            CreateEmote(target, "Emote_guitar", "none", true);
        case 66:
            CreateEmote(target, "Emote_Hillbilly_Shuffle_Intro", "Emote_Hillbilly_Shuffle", true);
        case 67:
            CreateEmote(target, "Emote_Hiphop_01", "Emote_Hip_Hop", true);
        case 68:
            CreateEmote(target, "Emote_Hula_Start", "Emote_Hula", true);
        case 69:
            CreateEmote(target, "Emote_InfiniDab_Intro", "Emote_InfiniDab_Loop", true);
        case 70:
            CreateEmote(target, "Emote_Intensity_Start", "Emote_Intensity_Loop", true);
        case 71:
            CreateEmote(target, "Emote_IrishJig_Start", "Emote_IrishJig", true);
        case 72:
            CreateEmote(target, "Emote_KoreanEagle", "none", true);
        case 73:
            CreateEmote(target, "Emote_Kpop_02", "none", true);
        case 74:
            CreateEmote(target, "Emote_LivingLarge", "none", true);
        case 75:
            CreateEmote(target, "Emote_Maracas", "none", true);
        case 76:
            CreateEmote(target, "Emote_PopLock", "none", true);
        case 77:
            CreateEmote(target, "Emote_PopRock", "none", true);
        case 78:
            CreateEmote(target, "Emote_RobotDance", "none", true);
        case 79:
            CreateEmote(target, "Emote_T-Rex", "none", false);
        case 80:
            CreateEmote(target, "Emote_TechnoZombie", "none", true);
        case 81:
            CreateEmote(target, "Emote_Twist", "none", true);
        case 82:
            CreateEmote(target, "Emote_WarehouseDance_Start", "Emote_WarehouseDance_Loop", true);
        case 83:
            CreateEmote(target, "Emote_Wiggle", "none", true);
        case 84:
            CreateEmote(target, "Emote_Youre_Awesome", "none", false);
        default:
            CPrintToChat(client, "%t", "INVALID_EMOTE_ID");
    }
}

public void OnAdminMenuReady(Handle aTopMenu) {
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

    /* Block us from being called twice */
    if (topmenu == hTopMenu) {
        return;
    }

    /* Save the Handle */
    hTopMenu = topmenu;

    /* Find the "Player Commands" category */
    TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

    if (player_commands != INVALID_TOPMENUOBJECT) {
        hTopMenu.AddItem("sm_setemotes", AdminMenu_Emotes, player_commands, "sm_setemotes", ADMFLAG_SLAY);
    }
}

void AdminMenu_Emotes(TopMenu topmenu,
    TopMenuAction action,
    TopMenuObject object_id,
    int param,
    char[] buffer,
    int maxlength) {
    if (action == TopMenuAction_DisplayOption) {
        Format(buffer, maxlength, "%T", "EMOTE_PLAYER", param);
    } else if (action == TopMenuAction_SelectOption) {
        DisplayEmotePlayersMenu(param);
    }
}

void DisplayEmotePlayersMenu(int client) {
    Menu menu = new Menu(MenuHandler_EmotePlayers);

    char title[65];
    Format(title, sizeof(title), "%T:", "EMOTE_PLAYER", client);
    menu.SetTitle(title);
    menu.ExitBackButton = true;

    AddTargetsToMenu(menu, client, true, true);

    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_EmotePlayers(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_End) {
        delete menu;
    } else if (action == MenuAction_Cancel) {
        if (param2 == MenuCancel_ExitBack && hTopMenu) {
            hTopMenu.Display(param1, TopMenuPosition_LastCategory);
        }
    } else if (action == MenuAction_Select) {
        char info[32];
        int userid, target;

        menu.GetItem(param2, info, sizeof(info));
        userid = StringToInt(info);

        if ((target = GetClientOfUserId(userid)) == 0) {
            CPrintToChat(param1, "[SM] %t", "Player no longer available");
        } else if (!CanUserTarget(param1, target)) {
            CPrintToChat(param1, "[SM] %t", "Unable to target");
        } else {
            g_EmotesTarget[param1] = userid;
            DisplayEmotesAmountMenu(param1);
            return 0; // Return, because we went to a new menu and don't want the re-draw to occur.
        }

        /* Re-draw the menu if they're still valid */
        if (IsClientInGame(param1) && !IsClientInKickQueue(param1)) {
            DisplayEmotePlayersMenu(param1);
        }
    }

    return 0;
}

void DisplayEmotesAmountMenu(int client) {
    Menu menu = new Menu(MenuHandler_EmotesAmount);

    char title[65];
    Format(title, sizeof(title), "%T: %N", "SELECT_EMOTE", client, GetClientOfUserId(g_EmotesTarget[client]));
    menu.SetTitle(title);
    menu.ExitBackButton = true;

    AddTranslatedMenuItem(menu, "1", "Emote_Fonzie_Pistol", client);
    AddTranslatedMenuItem(menu, "2", "Emote_Bring_It_On", client);
    AddTranslatedMenuItem(menu, "3", "Emote_ThumbsDown", client);
    AddTranslatedMenuItem(menu, "4", "Emote_ThumbsUp", client);
    AddTranslatedMenuItem(menu, "5", "Emote_Celebration_Loop", client);
    AddTranslatedMenuItem(menu, "6", "Emote_BlowKiss", client);
    AddTranslatedMenuItem(menu, "7", "Emote_Calculated", client);
    AddTranslatedMenuItem(menu, "8", "Emote_Confused", client);
    AddTranslatedMenuItem(menu, "9", "Emote_Chug", client);
    AddTranslatedMenuItem(menu, "10", "Emote_Cry", client);
    AddTranslatedMenuItem(menu, "11", "Emote_DustingOffHands", client);
    AddTranslatedMenuItem(menu, "12", "Emote_DustOffShoulders", client);
    AddTranslatedMenuItem(menu, "13", "Emote_Facepalm", client);
    AddTranslatedMenuItem(menu, "14", "Emote_Fishing", client);
    AddTranslatedMenuItem(menu, "15", "Emote_Flex", client);
    AddTranslatedMenuItem(menu, "16", "Emote_golfclap", client);
    AddTranslatedMenuItem(menu, "17", "Emote_HandSignals", client);
    AddTranslatedMenuItem(menu, "18", "Emote_HeelClick", client);
    AddTranslatedMenuItem(menu, "19", "Emote_Hotstuff", client);
    AddTranslatedMenuItem(menu, "20", "Emote_IBreakYou", client);
    AddTranslatedMenuItem(menu, "21", "Emote_IHeartYou", client);
    AddTranslatedMenuItem(menu, "22", "Emote_Kung-Fu_Salute", client);
    AddTranslatedMenuItem(menu, "23", "Emote_Laugh", client);
    AddTranslatedMenuItem(menu, "24", "Emote_Luchador", client);
    AddTranslatedMenuItem(menu, "25", "Emote_Make_It_Rain", client);
    AddTranslatedMenuItem(menu, "26", "Emote_NotToday", client);
    AddTranslatedMenuItem(menu, "27", "Emote_RockPaperScissor_Paper", client);
    AddTranslatedMenuItem(menu, "28", "Emote_RockPaperScissor_Rock", client);
    AddTranslatedMenuItem(menu, "29", "Emote_RockPaperScissor_Scissor", client);
    AddTranslatedMenuItem(menu, "30", "Emote_Salt", client);
    AddTranslatedMenuItem(menu, "31", "Emote_Salute", client);
    AddTranslatedMenuItem(menu, "32", "Emote_SmoothDrive", client);
    AddTranslatedMenuItem(menu, "33", "Emote_Snap", client);
    AddTranslatedMenuItem(menu, "34", "Emote_StageBow", client);
    AddTranslatedMenuItem(menu, "35", "Emote_Wave2", client);
    AddTranslatedMenuItem(menu, "36", "Emote_Yeet", client);
    AddTranslatedMenuItem(menu, "37", "DanceMoves", client);
    AddTranslatedMenuItem(menu, "38", "Emote_Mask_Off_Intro", client);
    AddTranslatedMenuItem(menu, "39", "Emote_Zippy_Dance", client);
    AddTranslatedMenuItem(menu, "40", "ElectroShuffle", client);
    AddTranslatedMenuItem(menu, "41", "Emote_AerobicChamp", client);
    AddTranslatedMenuItem(menu, "42", "Emote_Bendy", client);
    AddTranslatedMenuItem(menu, "43", "Emote_BandOfTheFort", client);
    AddTranslatedMenuItem(menu, "44", "Emote_Boogie_Down_Intro", client);
    AddTranslatedMenuItem(menu, "45", "Emote_Capoeira", client);
    AddTranslatedMenuItem(menu, "46", "Emote_Charleston", client);
    AddTranslatedMenuItem(menu, "47", "Emote_Chicken", client);
    AddTranslatedMenuItem(menu, "48", "Emote_Dance_NoBones", client);
    AddTranslatedMenuItem(menu, "49", "Emote_Dance_Shoot", client);
    AddTranslatedMenuItem(menu, "50", "Emote_Dance_SwipeIt", client);
    AddTranslatedMenuItem(menu, "51", "Emote_Dance_Disco_T3", client);
    AddTranslatedMenuItem(menu, "52", "Emote_DG_Disco", client);
    AddTranslatedMenuItem(menu, "53", "Emote_Dance_Worm", client);
    AddTranslatedMenuItem(menu, "54", "Emote_Dance_Loser", client);
    AddTranslatedMenuItem(menu, "55", "Emote_Dance_Breakdance", client);
    AddTranslatedMenuItem(menu, "56", "Emote_Dance_Pump", client);
    AddTranslatedMenuItem(menu, "57", "Emote_Dance_RideThePony", client);
    AddTranslatedMenuItem(menu, "58", "Emote_Dab", client);
    AddTranslatedMenuItem(menu, "59", "Emote_EasternBloc_Start", client);
    AddTranslatedMenuItem(menu, "60", "Emote_FancyFeet", client);
    AddTranslatedMenuItem(menu, "61", "Emote_FlossDance", client);
    AddTranslatedMenuItem(menu, "62", "Emote_FlippnSexy", client);
    AddTranslatedMenuItem(menu, "63", "Emote_Fresh", client);
    AddTranslatedMenuItem(menu, "64", "Emote_GrooveJam", client);
    AddTranslatedMenuItem(menu, "65", "Emote_guitar", client);
    AddTranslatedMenuItem(menu, "66", "Emote_Hillbilly_Shuffle_Intro", client);
    AddTranslatedMenuItem(menu, "67", "Emote_Hiphop_01", client);
    AddTranslatedMenuItem(menu, "68", "Emote_Hula_Start", client);
    AddTranslatedMenuItem(menu, "69", "Emote_InfiniDab_Intro", client);
    AddTranslatedMenuItem(menu, "70", "Emote_Intensity_Start", client);
    AddTranslatedMenuItem(menu, "71", "Emote_IrishJig_Start", client);
    AddTranslatedMenuItem(menu, "72", "Emote_KoreanEagle", client);
    AddTranslatedMenuItem(menu, "73", "Emote_Kpop_02", client);
    AddTranslatedMenuItem(menu, "74", "Emote_LivingLarge", client);
    AddTranslatedMenuItem(menu, "75", "Emote_Maracas", client);
    AddTranslatedMenuItem(menu, "76", "Emote_PopLock", client);
    AddTranslatedMenuItem(menu, "77", "Emote_PopRock", client);
    AddTranslatedMenuItem(menu, "78", "Emote_RobotDance", client);
    AddTranslatedMenuItem(menu, "79", "Emote_T-Rex", client);
    AddTranslatedMenuItem(menu, "80", "Emote_TechnoZombie", client);
    AddTranslatedMenuItem(menu, "81", "Emote_Twist", client);
    AddTranslatedMenuItem(menu, "82", "Emote_WarehouseDance_Start", client);
    AddTranslatedMenuItem(menu, "83", "Emote_Wiggle", client);
    AddTranslatedMenuItem(menu, "84", "Emote_Youre_Awesome", client);

    menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_EmotesAmount(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_End) {
        delete menu;
    } else if (action == MenuAction_Cancel) {
        if (param2 == MenuCancel_ExitBack && hTopMenu) {
            hTopMenu.Display(param1, TopMenuPosition_LastCategory);
        }
    } else if (action == MenuAction_Select) {
        char info[32];
        int amount;
        int target;

        menu.GetItem(param2, info, sizeof(info));
        amount = StringToInt(info);

        if ((target = GetClientOfUserId(g_EmotesTarget[param1])) == 0) {
            CPrintToChat(param1, "[SM] %t", "Player no longer available");
        } else if (!CanUserTarget(param1, target)) {
            CPrintToChat(param1, "[SM] %t", "Unable to target");
        } else {
            char name[MAX_NAME_LENGTH];
            GetClientName(target, name, sizeof(name));

            PerformEmote(param1, target, amount);
        }

        /* Re-draw the menu if they're still valid */
        if (IsClientInGame(param1) && !IsClientInKickQueue(param1)) {
            DisplayEmotePlayersMenu(param1);
        }
    }

    return 0;
}

void AddTranslatedMenuItem(Menu menu,
    const char[] opt,
        const char[] phrase, int client) {
    char buffer[128];
    Format(buffer, sizeof(buffer), "%T", phrase, client);
    menu.AddItem(opt, buffer);
}

stock bool IsValidClient(int client, bool nobots = true) {
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client))) {
        return false;
    }
    return IsClientInGame(client);
}

bool CheckAdminFlags(int client, int iFlag) {
    int iUserFlags = GetUserFlagBits(client);
    return (iUserFlags & ADMFLAG_ROOT || (iUserFlags & iFlag) == iFlag);
}

int GetEmotePeople() {
    int count;
    for (int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i) && g_bClientDancing[i])
            count++;

    return count;
}

bool IsSurvivor(int client) {
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

public int CreatePlayerModelProp(int client, char[] sModel) {
    return 0;
}

bool IsValidClientIndex(int client)
{
    return (1 <= client <= MaxClients);
}

stock void ReplaceColor(char[] message, int maxLen) {
    ReplaceString(message, maxLen, "{default}", "\x01");
    ReplaceString(message, maxLen, "{darkred}", "\x04");
    ReplaceString(message, maxLen, "{olive}", "\x05");
}

stock void CPrintToChat(int iClient, const char[] format, any ...)
{
    char buffer[192];
    SetGlobalTransTarget(iClient);
    VFormat(buffer, sizeof(buffer), format, 3);
    ReplaceColor(buffer, sizeof(buffer));
    PrintToChat(iClient, "\x01%s", buffer);
}

stock void PrintDebug(const char[] Message, any ...)
{
#if DEBUG_MODE
    char DebugBuff[256];
    VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
    LogMessage(DebugBuff);
    PrintToChatAll(DebugBuff);
#endif
}