#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = {
    name = "Stripper Dump All",
    author = "devilesk",
    description = "Executes stripper_dump on all maps.",
    version = "0.1.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

Handle g_map_array = null;
int g_map_serial = -1;
int g_map_count = 0;
int g_current_map = 0;

public OnPluginStart() {
    LoadMapList();
}

public OnMapStart() {
    if (g_current_map < g_map_count) {
        char map_name[PLATFORM_MAX_PATH];
        GetArrayString(g_map_array, g_current_map, map_name, sizeof(map_name));
        LogMessage("OnMapStart. g_current_map: %i, g_map_count: %i, map: %s", g_current_map, g_map_count, map_name);
        ServerCommand("stripper_dump");
        DataPack data;
        CreateDataTimer(3.0, Timer_ChangeMap, data);
        data.WriteString(map_name);
        g_current_map++;
    }
}

int LoadMapList()
{
    Handle map_array;
    
    if ((map_array = ReadMapList(g_map_array,
            g_map_serial,
            "sm_map menu",
            MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER))
        != null)
    {
        g_map_array = map_array;
    }
    
    if (g_map_array == null)
    {
        return 0;
    }
    
    g_map_count = GetArraySize(g_map_array);
    
    return g_map_count;
}

public Action Timer_ChangeMap(Handle hTimer, DataPack dp)
{
    char map[PLATFORM_MAX_PATH];
    
    if (dp == null)
    {
        if (!GetNextMap(map, sizeof(map)))
        {
            //No passed map and no set nextmap. fail!
            return Plugin_Stop;    
        }
    }
    else
    {
        dp.Reset();
        dp.ReadString(map, sizeof(map));
    }
    
    ForceChangeLevel(map, "Stripper Dump");
    
    return Plugin_Stop;
}