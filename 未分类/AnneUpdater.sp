#pragma semicolon 1
#pragma newdecls required
// 头文件
#include <sourcemod>
#include <updater>
#define UPDATE_URL    "https://raw.githubusercontent.com/Caibiii/AnneServer/test/left4dead2/addons/sourcemod/Anne_Updater.txt"

// 插件基本信息，根据 GPL 许可证条款，需要修改插件请勿修改此信息！
public Plugin myinfo = 
{
	name 			= "Anne Plugins Auto Updater",
	author 			= "东",
	description 	= "自动更新Anne核心插件",
	version 		= "2022.07.08",
	url 			= "https://github.com/fantasylidong/"
}
public void OnPluginStart()
{
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}
public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}