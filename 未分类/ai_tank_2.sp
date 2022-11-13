#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>


public Plugin myinfo = 
{
	name 			= "Ai_Tank_Enhance2.0",
	author 			= "夜羽真白，东",
	description 	= "Tank 增强插件 2.0 版本",
	version 		= "2.0.1.0",
	url 			= "https://github.com/fantasylidong/CompetitiveWithAnne"
}

public void OnPluginStart()
{

	RegAdminCmd("sm_checkladder", CalculateLadderNum, ADMFLAG_ROOT, "测试当前地图有多少个梯子");

}


public Action CalculateLadderNum(int client, int args){
	int ent = -1, laddercount = 0;
	while((ent = FindEntityByClassname(ent, "func_simpleladder")) != -1) {
		if(IsValidEntity(ent)) {
			laddercount++;
		}
	}
	PrintToChatAll("本地图共有：%d 个梯子", laddercount);
	return Plugin_Handled;
}
