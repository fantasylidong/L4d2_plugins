#pragma semicolon 1
#pragma newdecls required
#include <colors>
#include <sdktools>
#include <l4d2tools>
#include <left4dhooks>

#define VERSION "1.0"

public Plugin myinfo =
{
    name = "All Charger",
    author = "东",
    description = "所有特感全部生成为牛",
    version = VERSION,
    url = "http://github.com/fantasylidong/",
};

int
	serverSpawnTime=16,
	serverMaxInfectedCount = 0;
	

ConVar
	serverSpawnTimeConvar,
	serverMaxInfectedConvar;


public void OnPluginStart()
{
	serverSpawnTimeConvar= FindConVar("versus_special_respawn_interval");
	serverSpawnTime=GetConVarInt(serverSpawnTimeConvar);
	serverMaxInfectedConvar= FindConVar("l4d_infected_limit");
	serverMaxInfectedCount= GetConVarInt(serverMaxInfectedConvar);
	HookConVarChange(serverMaxInfectedConvar, CvarEvent_MaxInfectedChange);	
	HookConVarChange(serverSpawnTimeConvar, CvarEvent_SpawnTimeChange);	
	SetConVarInt(FindConVar("z_smoker_limit"), 0);
	SetConVarInt(FindConVar("z_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_hunter_limit"), 0);
	SetConVarInt(FindConVar("z_spitter_limit"), 0);
	SetConVarInt(FindConVar("z_jockey_limit"), 0);
	SetConVarInt(FindConVar("z_charger_limit"), serverMaxInfectedCount);
	SetChargerAbility();
}

                /*  ########################################
                            SourceModHookEvent:START==>
                ########################################    */


//玩家离开安全屋
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	SetChargerAbility();
	SetAllCharger();
	CreateTimer(0.5,SpawnCharger);
}

public Action SpawnCharger(Handle timer){
	float vPos[3];
	float vAng[3];
	KickPreviousSI();
	for(int i=0;i<serverMaxInfectedCount;i++){
		vPos[0] = GetRandomFloat(10.0, 150.0);
		vPos[1] = GetRandomFloat(10.0, 150.0);
		vPos[2] = GetRandomFloat(10.0, 150.0);
		vAng[0] = GetRandomFloat(10.0, 150.0);
		vAng[1] = GetRandomFloat(10.0, 150.0);
		vAng[2] = GetRandomFloat(10.0, 150.0);
		L4D2_SpawnSpecial(6,vPos,vAng);
	}
	CreateTimer(serverSpawnTime,SpawnCharger);
}
void KickPreviousSI(){
	for(int i=1;i<=MaxClients;i++)
	 if(IsInfected(i))KickClient(i);
}

void SetChargerAbility(){
	SetConVarInt(FindConVar("z_charge_max_speed"), 750);
	SetConVarInt(FindConVar("z_charge_start_speed"), 350);
	SetConVarInt(FindConVar("z_claw_hit_pitch_max"), 30);
	SetConVarInt(FindConVar("z_charge_interval"), 1);
}

void SetAllCharger(){
	SetConVarInt(FindConVar("z_smoker_limit"), 0);
	SetConVarInt(FindConVar("z_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_hunter_limit"), 0);
	SetConVarInt(FindConVar("z_spitter_limit"), 0);
	SetConVarInt(FindConVar("z_jockey_limit"), 0);
	SetConVarInt(FindConVar("z_charger_limit"), serverMaxInfectedCount);
}
                /*  ########################################
                        <==ConsoleCommandHookEvent:END
                ########################################    */


                /*  ########################################
                            MyHookEvent:START==>
                ########################################    */

//回合开始事件
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	 CPrintToChatAll("{lightgreen}请注意：目前模式为{orange}全牛模式{lightgreen}，牛的冲锋速度加1.5倍（750），撞后缓冲1秒，行走速度350，伤害增加!");
	 CreateTimer(serverSpawnTime,SpawnCharger);
}




                /*  ########################################
                            <==MyHookEvent:END
                ########################################    */


                /*  ########################################
                            ConVarEvent:START==>
                ########################################    */


//感染者数量更改
public void CvarEvent_MaxInfectedChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    serverMaxInfectedCount = GetConVarInt(serverMaxInfectedConvar);
    SetAllCharger();
}

//感染者刷新时间修改
public void CvarEvent_SpawnTimeChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    serverSpawnTime = GetConVarInt(serverSpawnTimeConvar);
    SetAllCharger();
}