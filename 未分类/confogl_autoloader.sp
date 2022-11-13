#pragma semicolon 1
#pragma newdecls required
// 头文件
#include <sourcemod>


// 插件基本信息，根据 GPL 许可证条款，需要修改插件请勿修改此信息！
public Plugin myinfo = 
{
	name 			= "Auto loader default plugins config",
	author 			= "东",
	description 	= "服务器完全重启后自动加载AnneHappy配置",
	version 		= "2022.07.10",
	url 			= "https://github.com/fantasylidong/anne"
}

ConVar hAutoloaderConfig, g_hsvtags;
public void OnPluginStart()
{
    g_hsvtags = FindConVar("sv_tags");
	CreateConVar("confogl_loader_ver", "1.0", "Version of confogl autoloader plugin.", 0, false, 0.0, false, 0.0);
	hAutoloaderConfig = CreateConVar("confogl_autoloader_config", "AnneHappy", "Config to launch with the autoloader", 0, false, 0.0, false, 0.0);
	RegAdminCmd("sm_startmode", SetStartMode, ADMFLAG_CONFIG, "Set confogl Start mode");
	//HookConVarChange(g_hGameMode, ConVarChange_GameMode);
}
public Action SetStartMode(int client, int args)
{
	char sTags[64];
	GetConVarString(g_hsvtags, sTags, 64);
	if(!(StrContains(sTags, "anne", false) || StrContains(sTags, "1vht", false) || StrContains(sTags, "allcharger", false) || StrContains(sTags, "alone", false) || StrContains(sTags, "coop", false) || StrContains(sTags, "witchparty", false) || StrContains(sTags, "realism", false)))
		ExecuteConfig();
}
/*
public void ConVarChange_GameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(oldValue, newValue, true))
	{
		ExecuteConfig();
	}
}
*/

void ExecuteConfig()
{
	char sCommandBuffer[256];
	char sConfigBuffer[256];
	GetConVarString(hAutoloaderConfig, sConfigBuffer, 256);
	Format(sCommandBuffer, 256, "sm_forcematch %s", sConfigBuffer);
	ServerCommand(sCommandBuffer);
}
