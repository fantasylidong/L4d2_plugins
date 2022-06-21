#pragma semicolon 1
#pragma newdecls required
#include <colors>
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
//#include <l4d2_saferoom_detect>

#define VERSION "1.0"
//#define DEBUG 0
// 头文件


#define CVAR_FLAG FCVAR_NOTIFY
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
// 特感种类
#define ZC_SPITTER 4
#define ZC_TANK 8
// 数据
#define NAV_MESH_HEIGHT 20.0
#define PLAYER_HEIGHT 72.0
#define PLAYER_CHEST 45.0
char sLogFile[PLATFORM_MAX_PATH] = "addons/sourcemod/logs/infected_control.txt";
// 插件基本信息，根据 GPL 许可证条款，需要修改插件请勿修改此信息！
public Plugin myinfo =
{
    name = "All Charger",
    author = "东",
    description = "所有特感全部生成为牛",
    version = VERSION,
    url = "http://github.com/fantasylidong/",
};

// Cvars
ConVar g_hSpawnDistanceMin, g_hSpawnDistanceMax, g_hTeleportSi, g_hTeleportDistance, g_hSiLimit, g_hSiInterval, g_hMaxPlayerZombies;
// Ints
int g_iSiLimit,iWaveTime,
g_iTeleCount[MAXPLAYERS + 1] = {0}, g_iTargetSurvivor = -1, g_iSpawnMaxCount = 0, g_iSurvivorNum = 0, g_iSurvivors[MAXPLAYERS + 1] = {0};
int iHunterLimit,iJockeyLimit,iChargerLimit,iSmokerLimit,iSpitterLimit,iBoomerLimit;
// ArraySpecial[6] = {0};
// Floats
float g_fSpawnDistanceMin, g_fSpawnDistanceMax, g_fTeleportDistance, g_fSiInterval;
// Bools
bool g_bTeleportSi, g_bIsLate = false;
// Handle
Handle g_hTeleHandle = INVALID_HANDLE;
// ArrayList
ArrayList aThreadHandle;

/* static char InfectedName[7][] =
{
	"none",
	"smoker",
	"boomer",
	"hunter",
	"spitter",
	"jockey",
	"charger"
}; */

public void OnPluginStart()
{
	// CreateConVar
	g_hSpawnDistanceMin = CreateConVar("inf_SpawnDistanceMin", "0.0", "特感复活离生还者最近的距离限制", CVAR_FLAG, true, 0.0);
	g_hSpawnDistanceMax = CreateConVar("inf_SpawnDistanceMax", "250.0", "特感复活离生还者最远的距离限制", CVAR_FLAG, true, g_hSpawnDistanceMin.FloatValue);
	g_hTeleportSi = CreateConVar("inf_TeleportSi", "1", "是否开启特感距离生还者一定距离将其传送至生还者周围", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hTeleportDistance = CreateConVar("inf_TeleportDistance", "800.0", "特感落后于最近的生还者超过这个距离则将它们传送", CVAR_FLAG, true, 0.0);
	g_hSiLimit = CreateConVar("l4d_infected_limit", "6", "一次刷出多少特感", CVAR_FLAG, true, 0.0);
	g_hSiInterval = CreateConVar("versus_special_respawn_interval", "16.0", "对抗模式下刷特时间控制", CVAR_FLAG, true, 0.0);
//	g_hSpawnMax = CreateConVar("spawn_count_max", "0", "此值记录特感找位次数，根据此值动态改变刷新距离", ~ CVAR_FLAG, true, 0.0);
	g_hMaxPlayerZombies = FindConVar("z_max_player_zombies");
	SetConVarInt(FindConVar("director_no_specials"), 1);
	// HookEvents
	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("player_death", evt_PlayerDeath, EventHookMode_PostNoCopy);
	HookEvent("round_start", evt_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_win", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", evt_RoundEnd, EventHookMode_PostNoCopy);
	// AddChangeHook
	g_hSpawnDistanceMax.AddChangeHook(ConVarChanged_Cvars);
	g_hSpawnDistanceMin.AddChangeHook(ConVarChanged_Cvars);
	g_hTeleportSi.AddChangeHook(ConVarChanged_Cvars);
	g_hTeleportDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hSiInterval.AddChangeHook(ConVarChanged_Cvars);
	g_hSiLimit.AddChangeHook(MaxPlayerZombiesChanged_Cvars);
	// ArrayList
	aThreadHandle = new ArrayList();
	// GetCvars
	GetCvars();
	// SetConVarBonus
	SetConVarBounds(g_hMaxPlayerZombies, ConVarBound_Upper, true, g_hSiLimit.FloatValue);
	// Debug
	RegAdminCmd("sm_startspawn", Cmd_StartSpawn, ADMFLAG_ROOT, "管理员重置刷特时钟");
}

// ***** 事件 *****
public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiTank(client)&&IsClientInGame(client) && IsFakeClient(client))
	{
		KickClient(client,"1vht模式不允许出现tank");
	}
}

// ***** 方法 *****
bool IsAiTank(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}
// 向量绘制
// #include "vector/vector_show.sp"

public Action Cmd_StartSpawn(int client, int args)
{
	if (L4D_HasAnySurvivorLeftSafeArea())
	{
		CreateTimer(0.1, SpawnFirstInfected);
		CPrintToChatAll("目前模式是全牛模式，牛的移动速度为350，冲刺速度为750，撞人缓冲时间2s");
		ResetInfectedNumber();
	}
	return Plugin_Continue;
}

// *********************
//		获取Cvar值
// *********************
void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void MaxPlayerZombiesChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iSiLimit = g_hSiLimit.IntValue;
	CreateTimer(0.1, MaxSpecialsSet);
}

void GetCvars()
{
	g_fSpawnDistanceMax = g_hSpawnDistanceMax.FloatValue;
	g_fSpawnDistanceMin = g_hSpawnDistanceMin.FloatValue;
	g_bTeleportSi = g_hTeleportSi.BoolValue;
	g_fTeleportDistance = g_hTeleportDistance.FloatValue;
	g_fSiInterval = g_hSiInterval.FloatValue;
	g_iSiLimit = g_hSiLimit.IntValue;
}

public Action MaxSpecialsSet(Handle timer)
{
	SetConVarBounds(g_hMaxPlayerZombies, ConVarBound_Upper, true, g_hSiLimit.FloatValue);
	g_hMaxPlayerZombies.IntValue = g_iSiLimit;
	return Plugin_Continue;
}

// *********************
//		    事件
// *********************
public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hTeleHandle != INVALID_HANDLE)
	{
		delete g_hTeleHandle;
		g_hTeleHandle = INVALID_HANDLE;
	}
	g_bIsLate = false;
	g_iSpawnMaxCount = 0;
	for (int hTimerHandle = aThreadHandle.Length - 1; hTimerHandle >= 0; hTimerHandle--)
	{
		KillTimer(aThreadHandle.Get(hTimerHandle));
		aThreadHandle.Erase(hTimerHandle);
	}
	aThreadHandle.Clear();
	iWaveTime=0;
	CreateTimer(0.1, MaxSpecialsSet);
	CreateTimer(3.0, SafeRoomReset, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void evt_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hTeleHandle != INVALID_HANDLE)
	{
		delete g_hTeleHandle;
		g_hTeleHandle = INVALID_HANDLE;
	}
	g_bIsLate = false;
	g_iSpawnMaxCount = 0;
	// 从 ArrayList 末端往前判断删除时钟，如果从前往后，因为 ArrayList 会通过前移后面的索引来填补前面擦除的空位，导致有时钟句柄无法擦除
	for (int hTimerHandle = aThreadHandle.Length - 1; hTimerHandle >= 0; hTimerHandle--)
	{
		KillTimer(aThreadHandle.Get(hTimerHandle));
		aThreadHandle.Erase(hTimerHandle);
	}
	aThreadHandle.Clear();
}

public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsInfectedBot(client))
	{
		if (GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_SPITTER)
		{
			CreateTimer(0.5, Timer_KickBot, client);
		}
	}
	g_iTeleCount[client] = 0;
}

public Action Timer_KickBot(Handle timer, int client)
{
	if (IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
	{
		Debug_Print("踢出特感%N",client);
		KickClient(client, "You are worthless and was kicked by console");
	}
	return Plugin_Continue;
}

// *********************
//		  功能部分
// *********************
public void OnGameFrame()
{
	/*
	// 根据情况动态调整 z_maxplayers_zombie 数值
	if (g_iSiLimit > g_hMaxPlayerZombies.IntValue)
	{
		CreateTimer(0.1, MaxSpecialsSet);
	}
	*/
	if (g_bIsLate && g_iSpawnMaxCount > 0)
	{
		HasAnyCountFull();
		if (g_iSiLimit > HasAnyCountFull())
		{		
			float fSpawnPos[3] = {0.0}, fSurvivorPos[3] = {0.0}, fDirection[3] = {0.0}, fEndPos[3] = {0.0}, fMins[3] = {0.0}, fMaxs[3] = {0.0},dist;	
			if (IsValidSurvivor(g_iTargetSurvivor))
			{
				// 根据指定生还者坐标，拓展刷新范围
				GetClientEyePosition(g_iTargetSurvivor, fSurvivorPos);
				g_fSpawnDistanceMax += 5.0;
				if(g_fSpawnDistanceMax < 500.0)
				{
					dist = 750.0;
					fMaxs[2] = fSurvivorPos[2] + 500.0;
				}
				else
				{
					dist = 250.0 + g_fSpawnDistanceMax;
					fMaxs[2] = fSurvivorPos[2] + g_fSpawnDistanceMax;
				}
				fMins[0] = fSurvivorPos[0] - g_fSpawnDistanceMax;
				fMaxs[0] = fSurvivorPos[0] + g_fSpawnDistanceMax;
				fMins[1] = fSurvivorPos[1] - g_fSpawnDistanceMax;
				fMaxs[1] = fSurvivorPos[1] + g_fSpawnDistanceMax;
//				fMaxs[2] = fSurvivorPos[2] + g_fSpawnDistanceMax;
				// 规定射线方向
				fDirection[0] = 90.0;
				fDirection[1] = fDirection[2] = 0.0;
				// 随机刷新位置
				fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
				fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
				fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
				// 找位条件，可视，是否在有效 NavMesh，是否卡住，否则先会判断是否在有效 Mesh 与是否卡住导致某些位置刷不出特感
				int count2=0;
				while (PlayerVisibleTo(fSpawnPos) || !IsOnValidMesh(fSpawnPos) || IsPlayerStuck(fSpawnPos))
				{
					count2++;
					if(count2 > 20)
					{
						break;
					}
					fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
					fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
					fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
					TR_TraceRay(fSpawnPos, fDirection, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
					if(TR_DidHit())
					{
						TR_GetEndPosition(fEndPos);
						if(!IsOnValidMesh(fEndPos))
						{
							fSpawnPos[2] = fSurvivorPos[2] + 20.0;
							TR_TraceRay(fSpawnPos, fDirection, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
							if(TR_DidHit())
							{
								TR_GetEndPosition(fEndPos);
								fSpawnPos = fEndPos;
								fSpawnPos[2] += 20.0;
							}
						}
						else
						{
							fSpawnPos = fEndPos;
							fSpawnPos[2] += 20.0;
						}
					}
				}
				if (count2<=20)
				{
					//Debug_Print("生还者看不到");
					// 生还数量为 4，循环 4 次，检测此位置到生还的距离是否小于 750 是则刷特，此处可以刷新 1 ~ g_iSiLimit 只特感，如果此处刷完，则上面的 SpawnSpecial 将不再刷特
					for (int count = 0; count < g_iSurvivorNum; count++)
					{
						int index = g_iSurvivors[count];
						GetClientEyePosition(index, fSurvivorPos);
						fSurvivorPos[2] -= 60.0;
						if (L4D2_VScriptWrapper_NavAreaBuildPath(fSpawnPos, fSurvivorPos, dist, false, false, TEAM_INFECTED, false) && GetVectorDistance(fSurvivorPos, fSpawnPos) > g_fSpawnDistanceMin)
						{
							int iZombieClass = IsBotTypeNeeded();
							if (iZombieClass > 0&&g_iSpawnMaxCount > 0)
							{
								int entityindex = L4D2_SpawnSpecial(iZombieClass, fSpawnPos, view_as<float>({0.0, 0.0, 0.0}));
								if (IsValidEntity(entityindex) && IsValidEdict(entityindex))
								{
									g_iSpawnMaxCount -= 1;
									addlimit(iZombieClass);
									print_type(iZombieClass,g_fSpawnDistanceMax);
								}
								/*
								if (SAFEDETECT_IsEntityInEndSaferoom(entityindex))
								{									
									//PrintToConsoleAll("[Infected-Spawn]：阳间模式：特感：%N，位置：%.2f，%.2f，%.2f，刷新在终点安全屋内，强制处死", entityindex, fSpawnPos[0], fSpawnPos[1], fSpawnPos[2]);
									g_iSpawnMaxCount += 1;
									dellimit(iZombieClass);
									ForcePlayerSuicide(entityindex);
									return;
								}
								*/
							}
						}
					}
				}
			}			
		}
	}
}
/*
public void dellimit(int iZombieClass){
	switch (iZombieClass)
	{
		case 1:
		{
			iSmokerLimit--;
		}
		case 2:
		{
			iBoomerLimit--;
		}
		case 3:
		{
			iHunterLimit--;
		}
		case 4:
		{
			iSpitterLimit--;
		}
		case 5:
		{
			iJockeyLimit--;
		}
		case 6:
		{
			iChargerLimit--;
		}
	}
}
*/

public void ResetInfectedNumber(){
	int iBoomers = 0, iSmokers = 0, iHunters = 0, iSpitters = 0, iJockeys = 0, iChargers = 0;
	for (int infected = 0; infected < MaxClients; infected++)
	{
		if (IsInfectedBot(infected) && IsPlayerAlive(infected)||IsGhost(infected))
		{
			int iZombieClass = GetEntProp(infected, Prop_Send, "m_zombieClass");
			switch (iZombieClass)
			{
				case 1:
				{
					iSmokers++;
				}
				case 2:
				{
					iBoomers++;
				}
				case 3:
				{
					iHunters++;
				}
				case 4:
				{
					iSpitters++;
				}
				case 5:
				{
					iJockeys++;
				}
				case 6:
				{
					iChargers++;
				}
			}
		}
	}
	iHunterLimit=iHunters;
	iSmokerLimit=iSmokers;
	iBoomerLimit=iBoomers;
	iSpitterLimit=iSpitters;
	iJockeyLimit=iJockeys;
	iChargerLimit=iChargers;
}

public void print_type(int iType,float g_fSpawnDistanceMax1){
	char sTime[32];
	FormatTime(sTime, sizeof(sTime), "%I-%M-%S", GetTime()); 
	int iBoomers = 0, iSmokers = 0, iHunters = 0, iSpitters = 0, iJockeys = 0, iChargers = 0;
	for (int infected = 0; infected < MaxClients; infected++)
	{
		if (IsInfectedBot(infected) && IsPlayerAlive(infected)||IsGhost(infected))
		{
			int iZombieClass = GetEntProp(infected, Prop_Send, "m_zombieClass");
			switch (iZombieClass)
			{
				case 1:
				{
					iSmokers++;
				}
				case 2:
				{
					iBoomers++;
				}
				case 3:
				{
					iHunters++;
				}
				case 4:
				{
					iSpitters++;
				}
				case 5:
				{
					iJockeys++;
				}
				case 6:
				{
					iChargers++;
				}
			}
		}
	}
	if (iType == 1)
	{
			Debug_Print("%s:生成一只Smoker，当前Smoker数量：%d,特感总数量 %d,找位最大单位距离：%f",sTime,iSmokers,iSmokers+iBoomers+iHunters+iSpitters+iJockeys+iChargers,g_fSpawnDistanceMax1);
	}
	else if (iType == 2)
	{
			Debug_Print("%s:生成一只Boomer，当前Boomer数量：%d,特感总数量 %d, 找位最大单位距离：%f",sTime,iBoomers,iSmokers+iBoomers+iHunters+iSpitters+iJockeys+iChargers,g_fSpawnDistanceMax1);
	}
	else if (iType == 3)
	{
			Debug_Print("%s:生成一只Hunter，当前Hunter数量：%d,特感总数量 %d, 找位最大单位距离：%f",sTime,iHunters,iSmokers+iBoomers+iHunters+iSpitters+iJockeys+iChargers,g_fSpawnDistanceMax1);
	}
	else if (iType == 4)
	{
			Debug_Print("%s:生成一只Spitter，当前Spitter数量：%d,特感总数量 %d, 找位最大单位距离：%f",sTime,iSpitters,iSmokers+iBoomers+iHunters+iSpitters+iJockeys+iChargers,g_fSpawnDistanceMax1);
	}
	else if (iType == 5)
	{
			Debug_Print("%s:生成一只Jockey，当前Jockey数量：%d,特感总数量 %d, 找位最大单位距离：%f",sTime,iJockeys,iSmokers+iBoomers+iHunters+iSpitters+iJockeys+iChargers,g_fSpawnDistanceMax1);
	}
	else if (iType == 6)
	{
			Debug_Print("%s:生成一只Charger，当前Charger数量：%d,特感总数量 %d, 找位最大单位距离：%f",sTime,iChargers,iSmokers+iBoomers+iHunters+iSpitters+iJockeys+iChargers,g_fSpawnDistanceMax1);
	}

}
public void addlimit(int iZombieClass){
	switch (iZombieClass)
	{
		case 1:
		{
			iSmokerLimit++;
		}
		case 2:
		{
			iBoomerLimit++;
		}
		case 3:
		{
			iHunterLimit++;
		}
		case 4:
		{
			iSpitterLimit++;
		}
		case 5:
		{
			iJockeyLimit++;
		}
		case 6:
		{
			iChargerLimit++;
		}
	}
}



// 初始 & 动态刷特时钟
public Action SpawnFirstInfected(Handle timer)
{
	if (!g_bIsLate)
	{
		g_bIsLate = true;
		if (g_hSiInterval.FloatValue > 9.0)
		{
			Handle aSpawnTimer = CreateTimer(g_fSiInterval + 8.0, SpawnNewInfected, _, TIMER_REPEAT);
			aThreadHandle.Push(aSpawnTimer);
			TriggerTimer(aSpawnTimer, true);
		}
		else
		{
			Handle aSpawnTimer = CreateTimer(g_fSiInterval + 4.0, SpawnNewInfected, _, TIMER_REPEAT);
			aThreadHandle.Push(aSpawnTimer);
			TriggerTimer(aSpawnTimer, true);
		}
		if (g_bTeleportSi)
		{
			g_hTeleHandle = CreateTimer(0.1, Timer_PositionSi, _, TIMER_REPEAT);
		}
	}
	return Plugin_Continue;
}


public Action SpawnNewInfected(Handle timer)
{
	char sTime[32];
	FormatTime(sTime, sizeof(sTime), "%I-%M-%S", GetTime()); 
	g_iSurvivorNum = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client) && IsPlayerAlive(client))
		{
			g_iSurvivors[g_iSurvivorNum] = client;
			g_iSurvivorNum += 1;
		}
	}
	if (g_bIsLate)
	{
		if (g_iSiLimit > aThreadHandle.Length)
		{
			if (g_hSiInterval.FloatValue > 9.0)
			{
				Handle aSpawnTimer = CreateTimer(g_fSiInterval + 8.0, SpawnNewInfected, _, TIMER_REPEAT);
				aThreadHandle.Push(aSpawnTimer);
				TriggerTimer(aSpawnTimer, true);
			}
			else
			{
				Handle aSpawnTimer = CreateTimer(g_fSiInterval + 4.0, SpawnNewInfected, _, TIMER_REPEAT);
				aThreadHandle.Push(aSpawnTimer);
				TriggerTimer(aSpawnTimer, true);
			}
		}
		// 其实这个删除没什么用，因为当 aThreadHandle.Length = g_iSiLimit 时，多出来的句柄将不会存入数组
		else if (g_iSiLimit < aThreadHandle.Length)
		{
			for (int iTimerIndex = 0; iTimerIndex < aThreadHandle.Length; iTimerIndex++)
			{
				if (timer == aThreadHandle.Get(iTimerIndex))
				{
					aThreadHandle.Erase(iTimerIndex);
					return Plugin_Stop;
				}
			}
		}
		g_fSpawnDistanceMax = 300.0;
		ResetInfectedNumber();

		g_iSpawnMaxCount += 1;
		if (g_iSiLimit == g_iSpawnMaxCount){
			iWaveTime++;
			Debug_Print("%s:开始第%d波刷特",sTime,iWaveTime);
		}
			
		// 当一定时间内刷不出特感，触发时钟使 g_iSpawnMaxCount 超过 g_iSiLimit 值时，最多允许刷出 g_iSiLimit + 2 只特感，防止连续刷 2-3 波的情况
		if (g_iSiLimit < g_iSpawnMaxCount)
		{

			g_iSpawnMaxCount = g_iSiLimit;
			
			Debug_Print("当前特感数量达到上限");
		}

	}
	return Plugin_Continue;
}

// 开局重置特感状态
public Action SafeRoomReset(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsInfectedBot(client) && IsPlayerAlive(client))
		{
			g_iTeleCount[client] = 0;
		}
		if (IsValidSurvivor(client) && !IsPlayerAlive(client))
		{
			L4D_RespawnPlayer(client);
		}
	}
	return Plugin_Continue;
}

// *********************
//		   方法
// *********************
bool IsInfectedBot(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsValidSurvivor(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsOnValidMesh(float fReferencePos[3])
{
	Address pNavArea = L4D2Direct_GetTerrorNavArea(fReferencePos);
	if (pNavArea != Address_Null)
	{
		return true;
	}
	else
	{
		return false;
	}
}


//判断该坐标是否可以看到生还或者距离小于200码
bool PlayerVisibleTo(float spawnpos[3])
{
	float pos[3];
	g_iSurvivorNum = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidSurvivor(i) && IsPlayerAlive(i))
		{
			g_iSurvivors[g_iSurvivorNum] = i;
			g_iSurvivorNum++;
			GetClientEyePosition(i, pos);
			if(PosIsVisibleTo(i, spawnpos) || GetVectorDistance(spawnpos, pos) < 300.0)
			{
				return true;
			}
		}	
	}
	return false;
}

//判断从该坐标发射的射线是否击中目标
bool PosIsVisibleTo(int client, const float targetposition[3])
{
	float position[3], vAngles[3], vLookAt[3], spawnPos[3];
	GetClientEyePosition(client, position);
	MakeVectorFromPoints(targetposition, position, vLookAt);
	GetVectorAngles(vLookAt, vAngles);
	Handle trace = TR_TraceRayFilterEx(targetposition, vAngles, MASK_VISIBLE, RayType_Infinite, TraceFilter, client);
	bool isVisible;
	isVisible = false;
	if(TR_DidHit(trace))
	{
		static float vStart[3];
		TR_GetEndPosition(vStart, trace);
		if((GetVectorDistance(targetposition, vStart, false) + 75.0) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true;
		}
		else
		{
			spawnPos = targetposition;
			spawnPos[2] += 40.0;
			MakeVectorFromPoints(spawnPos, position, vLookAt);
			GetVectorAngles(vLookAt, vAngles);
			Handle trace2 = TR_TraceRayFilterEx(spawnPos, vAngles, MASK_VISIBLE, RayType_Infinite, TraceFilter, client);
			if(TR_DidHit(trace2))
			{
				TR_GetEndPosition(vStart, trace2);
				if((GetVectorDistance(spawnPos, vStart, false) + 75.0) >= GetVectorDistance(position, spawnPos))
				isVisible = true;
			}
			else
			{
				isVisible = true;
			}
			delete trace2;
//			CloseHandle(trace2);
		}
	}
	else
	{
		isVisible = true;
	}
	delete trace;
//	CloseHandle(trace);
	return isVisible;
}


bool IsPlayerStuck(float fSpawnPos[3])
{
	bool IsStuck = true;
	float fMins[3] = {0.0}, fMaxs[3] = {0.0}, fNewPos[3] = {0.0};
	fNewPos = fSpawnPos;
	fNewPos[2] += 35.0;
	fMins[0] = fMins[1] = -16.0;
	fMins[2] = 0.0;
	fMaxs[0] = fMaxs[1] = 16.0;
	fMaxs[2] = 35.0;
	TR_TraceHullFilter(fSpawnPos, fNewPos, fMins, fMaxs, 147467, TraceFilter, _);
	IsStuck = TR_DidHit();
	return IsStuck;
}

bool TraceFilter(int entity, int contentsMask)
{
	if (entity || entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	else
	{
		static char sClassName[9];
		GetEntityClassname(entity, sClassName, sizeof(sClassName));
		if (strcmp(sClassName, "infected") == 0 || strcmp(sClassName, "witch") == 0|| strcmp(sClassName, "prop_physics") == 0)
		{
			return false;
		}
	}
	return true;
}

bool IsPinned(int client)
{
	bool bIsPinned = false;
	if (IsValidSurvivor(client) && IsPlayerAlive(client))
	{
		if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true;
	}		
	return bIsPinned;
}

bool IsPinningSomeone(int client)
{
	bool bIsPinning = false;
	if (IsInfectedBot(client))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0) bIsPinning = true;
	}
	return bIsPinning;
}

bool CanBeTeleport(int client)
{
	if (IsInfectedBot(client) && IsClientInGame(client)&& IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_TANK)
	{
		return true;
	}
	else
	{
		return false;
	}
}

//5秒内以0.1s检测一次，49次没被看到，就可以传送了
public Action Timer_PositionSi(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if(CanBeTeleport(client)){
			float fSelfPos[3] = {0.0};
			GetClientEyePosition(client, fSelfPos);
			if (!PlayerVisibleTo(fSelfPos))
			{
				if (g_iTeleCount[client] > 49)
				{
					Debug_Print("%N开始传送",client);
					if (!PlayerVisibleTo(fSelfPos) && !IsPinningSomeone(client))
					{
						SDKHook(client, SDKHook_PostThinkPost, SDK_UpdateThink);
						g_iTeleCount[client] = 0;
					}
				}
				g_iTeleCount[client] += 1;
			}
			else{
				g_iTeleCount[client] = 0;
			}
		}
		
	}
	return Plugin_Continue;
}

bool IsSpitter(int client)
{
	if (IsInfectedBot(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_SPITTER)
	{
		g_iTeleCount[client] = 50;//给予spitter立即传送的权限
		return true;
	}
	else
	{
		return false;
	}
}

int HasAnyCountFull()
{
	int  iSurvivors[4] = {0}, iSurvivorIndex = 0, FurthestAlivePlayer=0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client) && IsPlayerAlive(client) && !IsPinned(client) && !L4D_IsPlayerIncapacitated(client))
		{
			g_bIsLate = true;
			if (iSurvivorIndex < 4)
			{
				if(FurthestAlivePlayer==0)
					FurthestAlivePlayer=client;
				else if(L4D2Direct_GetFlowDistance(client)>L4D2Direct_GetFlowDistance(FurthestAlivePlayer))
					FurthestAlivePlayer=client;
				iSurvivors[iSurvivorIndex] = client;
				iSurvivorIndex += 1;
			}
		}
	}
	if (iSurvivorIndex > 0)
	{
		g_iTargetSurvivor = iSurvivors[GetRandomInt(0, iSurvivorIndex - 1)];
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client) && IsPlayerAlive(client))
		{
			if(client == FurthestAlivePlayer)
				continue;
			if(FurthestAlivePlayer == 0)
				break;
			float abs[3],abs2[3];
			GetClientAbsOrigin(client,abs);
			GetClientAbsOrigin(FurthestAlivePlayer,abs2);
			if(GetVectorDistance(abs,abs2)>1500.0)
			{
				g_iTargetSurvivor =FurthestAlivePlayer;
				break;
			}
		}
	}
	return iHunterLimit+iSmokerLimit+iBoomerLimit+iSpitterLimit+iJockeyLimit+iChargerLimit;
}

/*
int HasAnyCountFull()
{
	int iInfectedCount = 0, iSurvivors[4] = {0}, iSurvivorIndex = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsInfectedBot(client) && IsPlayerAlive(client)&&IsGhost(client))
		{
			int iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
			if (iZombieClass <= 6)
			{
				iInfectedCount += 1;
			}
		}
		if (IsValidSurvivor(client) && IsPlayerAlive(client) && !IsPinned(client))
		{
			g_bIsLate = true;
			if (iSurvivorIndex < 4)
			{
				iSurvivors[iSurvivorIndex] = client;
				iSurvivorIndex += 1;
			}
		}
	}
	if (iSurvivorIndex > 0)
	{
		g_iTargetSurvivor = iSurvivors[GetRandomInt(0, iSurvivorIndex - 1)];
	}
	else
	{
		g_iTargetSurvivor = L4D_GetHighestFlowSurvivor();
	}
	return iInfectedCount;
}
*/

// 传送落后特感
public void SDK_UpdateThink(int client)
{
	if (IsInfectedBot(client) && IsPlayerAlive(client))
	{
		g_iTeleCount[client] = 0;
		HardTeleMode(client);
			
	}
}




void HardTeleMode(int client)
{
	static float fEyePos[3] = {0.0}, fSelfEyePos[3] = {0.0};
	GetClientEyePosition(client, fEyePos);
	if (!PlayerVisibleTo(fEyePos) && !IsPinningSomeone(client))
	{
		float fSpawnPos[3] = {0.0}, fSurvivorPos[3] = {0.0}, fDirection[3] = {0.0}, fEndPos[3] = {0.0}, fMins[3] = {0.0}, fMaxs[3] = {0.0};
		if (IsValidSurvivor(g_iTargetSurvivor))
		{
			GetClientEyePosition(g_iTargetSurvivor, fSurvivorPos);
			GetClientEyePosition(client, fSelfEyePos);
			fMins[0] = fSurvivorPos[0] - 500;
			fMaxs[0] = fSurvivorPos[0] + 500;
			fMins[1] = fSurvivorPos[1] - 500;
			fMaxs[1] = fSurvivorPos[1] + 500;
			fMaxs[2] = fSurvivorPos[2] + 500;
			fDirection[0] = 90.0;
			fDirection[1] = fDirection[2] = 0.0;
			fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
			fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
			fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
//			fVisiblePos[0] =fSpawnPos[0];
//			fVisiblePos[1] =fSpawnPos[1];
//			fVisiblePos[2] =fSpawnPos[2];
			int count2=0;
			
			while (PlayerVisibleTo(fSpawnPos) || !IsOnValidMesh(fSpawnPos) || IsPlayerStuck(fSpawnPos))
			{
				count2 ++;
				if(count2 > 50)
				{
					break;
				}
				fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
				fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
				fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
				TR_TraceRay(fSpawnPos, fDirection, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
				if(TR_DidHit())
				{
					TR_GetEndPosition(fEndPos);
					if(!IsOnValidMesh(fEndPos))
					{
						fSpawnPos[2] = fSurvivorPos[2] + 20.0;
						TR_TraceRay(fSpawnPos, fDirection, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
						if(TR_DidHit())
						{
							TR_GetEndPosition(fEndPos);
							fSpawnPos = fEndPos;
							fSpawnPos[2] += 20.0;
						}
					}
					else
					{
						fSpawnPos = fEndPos;
						fSpawnPos[2] += 20.0;
					}
				}
			}
			if (count2<=50)
			{
				for (int count = 0; count < g_iSurvivorNum; count++)
				{
					int index = g_iSurvivors[count];
					if (IsClientInGame(index))
					{
						GetClientEyePosition(index, fSurvivorPos);
						fSurvivorPos[2] -= 60.0;
						if (L4D2_VScriptWrapper_NavAreaBuildPath(fSpawnPos, fSurvivorPos, g_fTeleportDistance, false, false, TEAM_INFECTED, false) && GetVectorDistance(fSelfEyePos, fSpawnPos) > g_fTeleportDistance && GetVectorDistance(fSelfEyePos, fSpawnPos) > g_fSpawnDistanceMin)
						{
							TeleportEntity(client, fSpawnPos, NULL_VECTOR, NULL_VECTOR);
							SDKUnhook(client, SDKHook_PostThinkPost, SDK_UpdateThink);
							return;
						}
					}
				}
			}
		}
	}
}
stock bool IsGhost(int client)
{
    return (IsValidClient(client) && view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost")));
}
stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}
//如果有人倒地或者被控且还有刷新机会，立即刷spitter打伤害
public bool SpitterSpawn(){
	bool spitter=false;
	bool pin=false;
	for(int i=1;i<=MaxClients;i++){
		if(IsValidSurvivor(i))
			if(IsPinned(i)||L4D_IsPlayerIncapacitated(i))
				pin=true;
		if(IsSpitter(i))
			spitter=true;
	}
	if(!spitter&&pin)
			return true;
	return false;
}

// 返回在场特感数量，根据 z_%s_limit 限制每种特感上限
int IsBotTypeNeeded()
{
	return 6;
	//ResetInfectedNumber();
	if(SpitterSpawn())
	{
		if ((iSpitterLimit < GetConVarInt(FindConVar("z_spitter_limit"))))
		{
					return 4;
		}
	}
	int iType = GetURandomIntRange(1, 7);
	if (iType == 1)
	{
		if ((iSmokerLimit < GetConVarInt(FindConVar("z_smoker_limit"))))
		{
//			iSmokerLimit++;
			return 1;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 2)
	{
		if ((iBoomerLimit < GetConVarInt(FindConVar("z_boomer_limit"))))
		{
	//		iBoomerLimit++;
			return 2;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 3)
	{
		if ((iHunterLimit < GetConVarInt(FindConVar("z_hunter_limit"))))
		{
		//	iHunterLimit++;
			return 3;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 4)
	{
		if ((iSpitterLimit < GetConVarInt(FindConVar("z_spitter_limit"))))
		{
			if(g_iSpawnMaxCount>4)
				IsBotTypeNeeded();
			else 
				{
			//		iSpitterLimit++;
					return 4;
				}
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 5)
	{
		if ((iJockeyLimit < GetConVarInt(FindConVar("z_jockey_limit"))))
		{
			//iJockeyLimit++;
			return 5;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 6)
	{
		if ((iChargerLimit < GetConVarInt(FindConVar("z_charger_limit"))))
		{
			//iChargerLimit++;
			return 6;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	return 0;
}

int GetURandomIntRange(int min, int max)
{
	return (GetURandomInt() & (max - min + 1)) + min;
}

stock bool Debug_Print(char[] format, any ...)
{
	#if defined DEBUG
	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), format, 2);
	Format(sBuffer, sizeof(sBuffer), "[%s] %s", "DEBUG", sBuffer);
//	PrintToChatAll(sBuffer);
	PrintToConsoleAll(sBuffer);
	LogToFile(sLogFile, sBuffer);
	return true;
	#else
	return false;
	#endif
}



