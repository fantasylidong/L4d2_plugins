//自杀 加入 旁观指令
//记录玩家聊天记录
//服务器没人时自动重启及重启指令
//Tank血量根据玩家数量设置
//特感血量根据玩家数量进行调整
//地图CVAR可用CFG单独设置
//玩家加入和离开提示
//特感受伤设置
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <left4downtown>
#include <sdktools_functions>
new	String:logfilepath[256];
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define L4D_MAXHUMANS_LOBBY_OTHER 3
new Float:lastDisconnectTime;
public SR_PluginStart()
{
	//HookEvent("player_say", OnPlayerSay);
	BuildPath(Path_SM, logfilepath, sizeof(logfilepath), "server\\PlayerMessage.log");
	RegConsoleCmd("sm_join", AFKTurnClientToSurvivors);
	RegConsoleCmd("sm_jg", AFKTurnClientToSurvivors);
	RegAdminCmd("sm_restart", RestartServer, ADMFLAG_ROOT, "Kicks all clients and restarts server");
}
public Action RestartServer(client,args)
{
    CrashServer();
}
public void OnAutoConfigsBuffered()
{
	 char sMapConfig[128];
	 GetCurrentMap(sMapConfig, sizeof(sMapConfig));
         Format(sMapConfig, sizeof(sMapConfig), "cfg/sourcemod/map_cvars/%s.cfg", sMapConfig);
         if (FileExists(sMapConfig, true))
         {
                strcopy(sMapConfig, sizeof(sMapConfig), sMapConfig[4]);
                ServerCommand("exec \"%s\"", sMapConfig);
         }
} 

public Action:AFKTurnClientToSurvivors(client, args)
{ 
	if(!IsSuivivorTeamFull())
	{
		ClientCommand(client, "jointeam survivor");
		new bot = FindSurvivorBot();
		if (bot > 0)
		{
			new flags = GetCommandFlags("sb_takecontrol");
			SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
			FakeClientCommand(client, "sb_takecontrol");
			SetCommandFlags("sb_takecontrol", flags);
		}
	}
	return Plugin_Handled;
}
stock FindSurvivorBot()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 2)
		{
			return client;
		}
	}
	return -1;
}
public SR_ClientDisconnect(client) 
{  
	if (IsClientInGame(client) && IsFakeClient(client)) return;

	new Float:currenttime = GetGameTime();
	
	if (lastDisconnectTime == currenttime) return;
	
	CreateTimer(SCORE_DELAY_EMPTY_SERVER, IsNobodyConnected, currenttime);
	lastDisconnectTime = currenttime;
}
public Action:IsNobodyConnected(Handle:timer, any:timerDisconnectTime)
{
	if (timerDisconnectTime != lastDisconnectTime) return Plugin_Stop;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
			return  Plugin_Stop;
	}
	//CreateTimer(0.5,TimerRestartServer);
	MYSQL_INITIP();
	Update_DATAIP();
	CrashServer();
	return  Plugin_Stop;
}