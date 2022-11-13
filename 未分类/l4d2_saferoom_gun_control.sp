#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>
#include <l4d2_saferoom_detect>

new     Handle:g_hKVData                = INVALID_HANDLE; //Handle for the KV data
new     Handle:g_hCvarKVPath            = INVALID_HANDLE; //Handle for the CVAR of the KV file path
new     Handle:g_hSafeAllowedWeapons    = INVALID_HANDLE; //adt_array for weapon spawns specified in the configs/saferoom_gun_control.txt
new     Handle:g_hWeaponSpawns          = INVALID_HANDLE; //adt_array for the names of weapon spawns we want to replace
new     Handle:g_hSafeSpawnEnts         = INVALID_HANDLE; //adt_array for the id's of weapon spawn entities in the safe room

public Plugin:myinfo = 
{
    name = "Saferoom Gun Control",
    author = "High Cookie and Standalone",
    description = "Attempts to replace existing weapon spawn entities with new weapon spawns specified in the config/saferoom_gun_control.txt",
    version = "1",
    url = ""
}

/***********************
   PLUGIN/GAME EVENTS
***********************/
public OnPluginStart()
{
    g_hCvarKVPath = CreateConVar(
            "sm_guncontrol_configpath",
            "configs/saferoom_gun_control.txt",
            "The path to the saferoom_gun_control.txt, default is the sourcemod configs folder.",
            FCVAR_SS_ADDED
        );
    
    PrepareWeaponSpawnArray();
}

public OnPluginEnd()
{
    CloseHandles();
    
    if (g_hWeaponSpawns != INVALID_HANDLE)
    {
        CloseHandle(g_hWeaponSpawns);
        g_hWeaponSpawns = INVALID_HANDLE;
    }
    
    if (g_hCvarKVPath != INVALID_HANDLE)
    {
        CloseHandle(g_hCvarKVPath);
        g_hCvarKVPath = INVALID_HANDLE;
    }
}

public OnRoundStart()
{
    CreateTimer( 1.1, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE );
}

//public Action:SwapWeaponSpawns(Handle:event, String:event_name[], bool:dontBroadcast)
public Action:Timer_DelayedOnRoundStart(Handle:timer)
{
    if (KV_Load())
    {
        KV_SwapGuns();
        CloseHandles();
    }
}

/***********************
   KEY-VALUES/HANDLES
***********************/
bool:KV_Load()
{
    decl String:filePath[PLATFORM_MAX_PATH];
    GetConVarString( g_hCvarKVPath, filePath, sizeof(filePath) );
    BuildPath(Path_SM, filePath, sizeof(filePath), filePath);
    
    g_hKVData = CreateKeyValues("SaferoomGunControl");
    
    if ( !FileToKeyValues(g_hKVData, filePath) )
    {
        LogError("[GUN CONTROL] Couldn't load Gun Control data! (file: %s)", filePath);
        CloseHandles();
        return false;
    }
    else
    {
        return true;
    }
}

public KV_SwapGuns()
{
    if ( g_hKVData == INVALID_HANDLE ) return false;

    new String: mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
    
    PrintToServer("%s", mapname);
    
    if ( !KvJumpToKey(g_hKVData, mapname) )
    { //No section for the map found
        if ( !KvJumpToKey(g_hKVData, "default") )
        { //No section for the map or default found.
            LogError("[GUN CONTROL] No map section found for %s and no default section found in KV file", mapname);
            return false;
        } 
    }
    
    if (KvGotoFirstSubKey(g_hKVData, false)) {
        decl String: valuebuffer[64];
        new count = 0, safeSpawnsCount, weaponId;
        
        BuildSafeWeaponSpawnEnts();
        
        safeSpawnsCount = GetArraySize(g_hSafeSpawnEnts);
        
        do
        {
            KvGetString(g_hKVData, NULL_STRING, valuebuffer, sizeof(valuebuffer));

            if (count < safeSpawnsCount)
            {
                weaponId = WeaponNameToId(valuebuffer);
                ConvertWeaponSpawn(GetArrayCell(g_hSafeSpawnEnts, count), weaponId);
                count++;
            }
            else 
            { //More weapons specified in the KV than there are weapon_spawns in the safe room
                break;
            }
        }
        while (KvGotoNextKey(g_hKVData, false));
        
        while (count < safeSpawnsCount) 
        { //Weapons spawns other than the ones specified in the KV exist, remove them.
            AcceptEntityInput(GetArrayCell(g_hSafeSpawnEnts, count), "Kill");
            count++;
        }
    }
    return true;
}

CloseHandles()
{
    if (g_hKVData != INVALID_HANDLE )
    {
        CloseHandle(g_hKVData);
        g_hKVData = INVALID_HANDLE;
    }
    
    if (g_hSafeAllowedWeapons != INVALID_HANDLE)
    {
        CloseHandle(g_hSafeAllowedWeapons);
        g_hSafeAllowedWeapons = INVALID_HANDLE;
    }
}

/***********************
        STOCKS
***********************/
//should hopefully gives less things to loop through when swapping weapon spawns, instead of looping through every entity multiple times.
stock BuildSafeWeaponSpawnEnts()
{
    decl String:classname[64];
    
    if (g_hSafeSpawnEnts == INVALID_HANDLE) 
    {
        g_hSafeSpawnEnts = CreateArray();
    }
    else 
    {
        ClearArray(g_hSafeSpawnEnts);
    }
    
    for (new i = 1; i < GetEntityCount(); i++)
    {
        if (!IsValidEntity(i)) { continue; }
        
        if (SAFEDETECT_IsEntityInStartSaferoom(i))
        {
            GetEdictClassname(i, classname, sizeof(classname));
            if (FindStringInArray(g_hWeaponSpawns, classname) != -1)
            {
                PushArrayCell(g_hSafeSpawnEnts, i);
            }
        }
    }
}

/***********************
          MISC
***********************/
PrepareWeaponSpawnArray()
{
    g_hWeaponSpawns = CreateArray(32);
    PushArrayString(g_hWeaponSpawns, "weapon_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_smg_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_smg_silenced_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_pumpshotgun_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_shotgun_chrome_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_hunting_rifle_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_sniper_military_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_rifle_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_rifle_ak47_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_rifle_desert_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_autoshotgun_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_shotgun_spas_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_rifle_m60_spawn");
    PushArrayString(g_hWeaponSpawns, "weapon_grenade_launcher_spawn");
}