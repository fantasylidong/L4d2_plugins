#pragma semicolon 1
#include <sourcemod>
#include <colors>
#include <ripext>
#define VALVEURL "ISteamUserStats/GetUserStatsForGame/v0002/?appid=550"
#define VALVEKEY "XXXXXXXXXXXXXXXXXXXXXXXXX"
int player_time[MAXPLAYERS+1]=0;
public Plugin:myinfo =  
{
	name = "l4d2 时长获取",
	author = "HUANG",
	description = "l4d2 时长获取", 
	version = "1.01 Release",
	url = "evilback.cn"
}
public OnPluginStart()
{
	RegConsoleCmd("sm_display", Player_Time);
	HookEvent("player_disconnect", Event_PlayerDisconnect,EventHookMode_Pre); 
}
public Action:Player_Time(client,args)
{
decl String:id[30];
for (new i=1;i<=MaxClients;i++)
{
	if (IsClientConnected(i) && IsClientInGame(i))
	{
	
		GetClientAuthId(i,AuthId_Steam2,id,sizeof(id));
		if (!StrEqual(id, "BOT"))
			if(player_time[i]!=0)
				CPrintToChatAll("{red}%N真实游戏时长为%d小时%d分钟",i,player_time[i]/3600,player_time[i]/60%60);
			else 
				CPrintToChatAll("{red}%N真实游戏时长 Unkown",i); 
	}
}
}
public OnClientPostAdminCheck(int client)
{
	decl String:URL[1024];
	decl String:id64[64];
	GetClientAuthId(client,AuthId_SteamID64,id64,sizeof(id64));
	if(StrEqual(id64,"STEAM_ID_STOP_IGNORING_RETVALS")) return;
	HTTPClient httpClient = new HTTPClient("http://api.steampowered.com");
	Format(URL,sizeof(URL),"%s&key=%s&steamid=%s",VALVEURL,VALVEKEY,id64);
	PrintToServer("%s",URL);
	httpClient.Get(URL,OnReceived,client);
}
public void OnReceived(HTTPResponse response, int i)
{
	decl String:buff[50];
	if (response.Data == null) {
        PrintToServer("Invalid JSON response");
		player_time[i]=0;
		CPrintToChatAll("{red}%N加入了游戏，真实游戏时长 Unkown",i); 
        return;  
    }
	JSONObject json=view_as<JSONObject>response.Data;
	json=view_as<JSONObject>json.Get("playerstats");
	JSONArray jsonarray=view_as<JSONArray>json.Get("stats");
	for(int j=0;j<jsonarray.Length;j++)
	{
		json=view_as<JSONObject>jsonarray.Get(j);
		json.GetString("name",buff,sizeof(buff));
		if(StrEqual(buff,"Stat.TotalPlayTime.Total"))		
		{
			PrintToServer("%N--获取成功,时间为\n%d",i,json.GetInt("value"));
			player_time[i]=json.GetInt("value");
			CPrintToChatAll("{red}【提示】%N加入了游戏，他的真实游戏时长为%d小时%d分钟",i,player_time[i]/3600,player_time[i]/60%60);
		}
	}
	//json=view_as<JSONObject>jsonarray.Get(0);

}
public Action:Event_PlayerDisconnect(Handle:event, String:event_name[], bool:dontBroadcast)
{
	decl String:id[40];
	int client=GetClientOfUserId(GetEventInt(event,"userid"));
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	if ((StrEqual(id, "BOT"))) return Plugin_Continue;
	player_time[client]=0;	
	return Plugin_Continue;
}