#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>

#define CVAR_FLAGS					FCVAR_PLUGIN|FCVAR_NOTIFY

stock l4d2_gamemode()//檢查當前遊戲模式,返回： 1 = coop , 2 = versus, 3 = survival, 4 = scavenge
{
	new String:gmode[32];
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));

	if (StrEqual(gmode, "coop", false) || StrEqual(gmode, "realism", false))
		return 1; else 
	if (StrEqual(gmode, "versus", false) || StrEqual(gmode, "teamversus", false))
		return 2;
	if (StrEqual(gmode, "survival", false))
		return 3;
	if (StrEqual(gmode, "scavenge", false) || StrEqual(gmode, "teamscavenge", false))
		return 4; else
		return 0;
}

stock bool:CheckEnabled(Handle:_covar)//檢查一個ConVar的值，一般用於檢查開關
{
	if(GetConVarInt(_covar)==1)
		return true;
	return false;
}

stock bool:GameCheck() //檢查遊戲是否符合,返回真表示此插件可以用在此遊戲上
{
	decl String:GameName[16];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrEqual(GameName, "left4dead2"))
		return true;
	return false;
}

stock bool:IsAlive(client)
{
	if(!GetEntProp(client, Prop_Send, "m_lifeState"))
		return true;
	
	return false;
}