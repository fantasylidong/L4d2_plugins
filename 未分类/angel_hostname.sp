/*
 * @Author:             派蒙
 * @Last Modified by:   派蒙
 * @Create Date:        2022-05-23 13:49:33
 * @Last Modified time: 2022-06-04 21:41:59
 * @Github:             http://github.com/PaimonQwQ
 */
#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sourcemod>
#include <SteamWorks>
#define VERSION "2022.06.04"

char
    g_sHostName[256];

ConVar
    g_hAngelSpawnLimit,
    g_hAngelSpawnInterval;

public Plugin myinfo =
{
    name = "AngelName",
    author = "我是派蒙啊",
    description = "AngelServer的名称管理",
    version = VERSION,
    url = "http://github.com/PaimonQwQ/L4D2-Plugins/AngelBeats"
};

public void OnPluginStart()
{
    g_hAngelSpawnLimit = FindConVar("angel_infected_limit");
    g_hAngelSpawnLimit.AddChangeHook(CVarEvent_OnDirectorChanged);
    g_hAngelSpawnInterval = FindConVar("angel_special_respawn_interval");
    g_hAngelSpawnInterval.AddChangeHook(CVarEvent_OnDirectorChanged);

    ChangeHostName();
}

public void OnGameFrame()
{
    SteamWorks_SetGameDescription("[Angel Beats!]");
}

public void CVarEvent_OnDirectorChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    ChangeHostName();
}

void ChangeHostName()
{
    char name[256];
    GetHostName();
    Format(name, 256, "%s[%d特/%d秒]", g_sHostName,
        g_hAngelSpawnLimit.IntValue, g_hAngelSpawnInterval.IntValue);
    FindConVar("hostname").SetString(name);
}

void GetHostName()
{
	KeyValues kv_hostname = new KeyValues("Angelbeats");
	ConVar cv_hostport = FindConVar("hostport");
    char hostFile[256];
    
    BuildPath(Path_SM, hostFile, 256, "configs/hostname/l4d2_hostname.txt");
    Handle file = OpenFile(hostFile, "rb");
    
    if (file)
    {
    	if (!kv_hostname.ImportFromFile(hostFile))
		{
			SetFailState("导入 %s 失败！", hostFile);
		}
    	char port[20];
		FormatEx(port, sizeof(port), "%d", cv_hostport.IntValue);
		kv_hostname.JumpToKey(port);
		kv_hostname.GetString("servername", g_sHostName, sizeof(g_sHostName), "AngleBeats Server");

        CloseHandle(file);
    }
}