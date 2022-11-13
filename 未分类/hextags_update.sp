#pragma semicolon 1
#pragma newdecls required
// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <steamworks>
char githuburl[PLATFORM_MAX_PATH] = "http://github.com/fantasylidong/anne/blob/zonemod/left4dead2/addons/sourcemod/configs/hextags.cfg";
char hextags[PLATFORM_MAX_PATH] = "addons/sourcemod/configss/hextags.cfg";
// 插件基本信息，根据 GPL 许可证条款，需要修改插件请勿修改此信息！
public Plugin myinfo = 
{
	name 			= "hextags file autoupdate",
	author 			= "东",
	description 	= "自动更新hextags文件",
	version 		= "2022.05.03",
	url 			= "https://github.com/fantasylidong/"
}
public void OnPluginStart()
{
    HTTP
}