#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <infected_control>
public Plugin myinfo =
{
	name = "AnneServer InfectedSpawn",
	author = "Caibiii",
	description = "AnneServer InfectedSpawn",
	version = "2022.02.24",
	url = "https://github.com/Caibiii/AnneServer"
}
public void OnPluginStart()
{
    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_win", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_end", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", player_death, EventHookMode_PostNoCopy);
    infected_spawn_interval = CreateConVar("versus_special_respawn_interval", "16.0");
    z_infected_limit = CreateConVar("l4d_infected_limit", "4");
	//sb_escort = CreateConVar("sb_escort", "1");
	z_spawn_max = CreateConVar("z_spawn_max", "500");
    FindConVar("director_no_specials").SetInt(1);
	thread_handle = new ArrayList(1);
	RegAdminCmd("sm_startspawn", startspawn, ADMFLAG_ROOT, "restartspawn");
}
//admin指令，使用后若有人已离开安全门则开始刷特
public Action startspawn(int client,any args)
{
	if(L4D_HasAnySurvivorLeftSafeArea())
	{
		CreateTimer(0.5, SpawnFirstInfected);
	}
}
//hook事件：特感死亡（非口水）踢出服务端并重置传送次数
public void player_death(Event event, const char[] name, bool dont_broadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsBotInfected(client))
	{
		if(GetEntProp(client, Prop_Send, "m_zombieClass") != 4)
		{
			CreateTimer(0.5,kickbot,client);
		}
	}
	TeleCount[client] = 0;
}
public Action kickbot(Handle timer, any client)
{
	if (IsClientInGame(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client)) KickClient(client);
	}
}
//回合开始/结束清除传送时间句柄，并关闭特感复活
public void OnRoundStart(Event event, const char[] name, bool dont_broadcast)
{
	delete timertele;
	is_late = false;
    for (int i = 0; i < thread_handle.Length; i++)
    {
        KillTimer(thread_handle.Get(i));
        thread_handle.Erase(i);
	}
	CreateTimer(3.0,SafeRoomOthers, _, TIMER_FLAG_NO_MAPCHANGE);
}
public void OnRoundEnd(Event event, const char[] name, bool dont_broadcast)
{
	delete timertele;
	is_late = false;
    for (int i = 0; i < thread_handle.Length; i++)
    {
        KillTimer(thread_handle.Get(i));
        thread_handle.Erase(i);
	}
}
public Action SafeRoomOthers(Handle timer)
{
	for (int infectedBot = 1; infectedBot <= MaxClients; infectedBot++) 
	{
		if (IsBotInfected(infectedBot) && IsPlayerAlive(infectedBot)) 
		{
			TeleCount[infectedBot] = 0;
		}
		if(IsSurvivor(infectedBot) && !IsPlayerAlive(infectedBot))
		{
			L4D_RespawnPlayer(infectedBot);
		}
	}
}
//特感复活相关计时
public Action SpawnFirstInfected(Handle timer)
{
	if(!is_late)
	{
		is_late = true;
		if(infected_spawn_interval.FloatValue > 9.0)
		{	
			Handle time = CreateTimer(infected_spawn_interval.FloatValue + 8.0, SpawnNewInfected, _, TIMER_REPEAT);
			thread_handle.Push(time);
			TriggerTimer(time, true);
		}
		else
		{
			Handle time = CreateTimer(infected_spawn_interval.FloatValue + 4.0, SpawnNewInfected, _, TIMER_REPEAT);
			thread_handle.Push(time);
			TriggerTimer(time, true);
		}
		timertele = CreateTimer(1.0, Timer_PositionSI, _, TIMER_REPEAT);
	}
    return Plugin_Continue;
}
//特感复活相关计时
public Action SpawnNewInfected(Handle timer)
{
	if(is_late)
	{
		if (thread_handle.Length < z_infected_limit.IntValue)
		{
			if(infected_spawn_interval.FloatValue > 9.0)
			{	
				Handle time = CreateTimer(infected_spawn_interval.FloatValue + 8.0, SpawnNewInfected, _, TIMER_REPEAT);
				thread_handle.Push(time);
				TriggerTimer(time, true);
			}
			else
			{
				Handle time = CreateTimer(infected_spawn_interval.FloatValue + 4.0, SpawnNewInfected, _, TIMER_REPEAT);
				thread_handle.Push(time);
				TriggerTimer(time, true);
			}
		}
		else if(thread_handle.Length > z_infected_limit.IntValue)
		{
			for (int i = 0; i < thread_handle.Length; i++)
			{
				if (thread_handle.Get(i) == timer)
				{
					thread_handle.Erase(i);
					return Plugin_Stop;
				}
			}
		}
		z_spawn_max.IntValue = 250;
		ArraySpecial = {1,2,3,4,5,6}; 
		SpawnMaxCount += 1;
	}
	return Plugin_Continue;
}
//特感找位以及复活函数
public void OnGameFrame()
{
	if(is_late && SpawnMaxCount > 0)
	{
		if(HasAnyCountFull() >= z_infected_limit.IntValue)
		{
			//SpawnMaxCount = 0;
		}
		else
		{
			float spawnPos[3],survivorPos[3],direction[3],traceImpact[3],Mins[3],Maxs[3],dist;
			int infected_type = GetRandomInt(Smoker, Charger);
			GetClientEyePosition(TargetPlayer, survivorPos);
			z_spawn_max.FloatValue += 5;
			if(z_spawn_max.FloatValue < 500.0)
			{
				dist = 750.0;
				Maxs[2] = survivorPos[2] + 500.0;
			}
			else
			{
				dist = 250.0 + z_spawn_max.FloatValue;
				Maxs[2] = survivorPos[2] + z_spawn_max.FloatValue;
			}
			Mins[0] = survivorPos[0] - z_spawn_max.FloatValue;
			Maxs[0] = survivorPos[0] + z_spawn_max.FloatValue;
			Mins[1] = survivorPos[1] - z_spawn_max.FloatValue;
			Maxs[1] = survivorPos[1] + z_spawn_max.FloatValue;
			direction[0] = 90.0;
			direction[1] = 0.0;
			direction[2] = 0.0;
			spawnPos[0] = GetRandomFloat(Mins[0], Maxs[0]);
			spawnPos[1] = GetRandomFloat(Mins[1], Maxs[1]);
			spawnPos[2] = GetRandomFloat(survivorPos[2], Maxs[2]);
			int count2 = 0;
			while(!IsOnValidMesh(spawnPos) || IsPlayerStuck(spawnPos) || PlayerVisibleTo(spawnPos))
			{
				count2 ++;
				if(count2 > 50)
				{
					break;
				}
				spawnPos[0] = GetRandomFloat(Mins[0], Maxs[0]);
				spawnPos[1] = GetRandomFloat(Mins[1], Maxs[1]);
				spawnPos[2] = GetRandomFloat(survivorPos[2], Maxs[2]);
				TR_TraceRay(spawnPos, direction, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
				if(TR_DidHit())
				{
					TR_GetEndPosition(traceImpact);
					if(!IsOnValidMesh(traceImpact))
					{
						spawnPos[2] = survivorPos[2] + 20.0;
						TR_TraceRay(spawnPos, direction, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
						if(TR_DidHit())
						{
							TR_GetEndPosition(traceImpact);
							spawnPos = traceImpact;
							spawnPos[2] += 20.0;
						}
					}
					else
					{
						spawnPos = traceImpact;
						spawnPos[2] += 20.0;
					}
				}
			}
			if(count2 <= 50 )
			{
				for(int X = 0 ; X < numSurvivors2; X++)
				{
					int index = survivors2[X];
					int count = 0;
					GetClientEyePosition(index, survivorPos);
					survivorPos[2] -= 60.0;
					if(L4D2_VScriptWrapper_NavAreaBuildPath(spawnPos,survivorPos, dist, false, false, 3, false))
					{
						while(!IsSpecialInArray(ArraySpecial,infected_type) && count < 50)
						{
							infected_type = GetRandomInt(Smoker, Charger);
							count++;
						}
						if(count > 49)
						{
							infected_type = Hunter;
						}
						L4D2_SpawnSpecial(infected_type, spawnPos, {0.0, 0.0, 0.0});
						SpawnMaxCount -= 1;
						//PrintToChatAll("%i",SpawnMaxCount);
						break;
					}
				}
			}
		}
	}
}
public Action Timer_PositionSI(Handle timer)
{
	for (int infectedBot = 1; infectedBot <= MaxClients; infectedBot++) 
	{
		if (IsBotInfected(infectedBot) && IsPlayerAlive(infectedBot) && CanBeTP(infectedBot)) 
		{
			if(TeleCount[infectedBot] > 6 ) 
			{
				float pos2[3];
				GetClientEyePosition(infectedBot, pos2);
				if(!PlayerVisibleTo(pos2) && !IsPinningASurvivor(infectedBot))
				{
					SDKHook(infectedBot, SDKHook_PostThinkPost, UpdateThink);
					TeleCount[infectedBot] = 0;
				}
			}
			TeleCount[infectedBot] += 1;
		}
	}
	return Plugin_Continue;
}
public void UpdateThink(int infected_type)
{
	if(!IsValidClient(infected_type) || !IsPlayerAlive(infected_type))
	{
		return;
	}
	TeleCount[infected_type] = 0;
	static float pos2[3];
	GetClientEyePosition(infected_type, pos2);
	if((!PlayerVisibleTo(pos2) && !IsPinningASurvivor(infected_type)))			
	{
		float spawnPos[3],survivorPos[3],direction[3],traceImpact[3],Mins[3],Maxs[3];
		GetClientEyePosition(TargetPlayer, survivorPos);
		Mins[0] = survivorPos[0] - 500.0;
		Maxs[0] = survivorPos[0] + 500.0;
		Mins[1] = survivorPos[1] - 500.0;
		Maxs[1] = survivorPos[1] + 500.0;
		Maxs[2] = survivorPos[2] + 500.0;
		direction[0] = 90.0;
		direction[1] = 0.0;
		direction[2] = 0.0;
		spawnPos[0] = GetRandomFloat(Mins[0], Maxs[0]);
		spawnPos[1] = GetRandomFloat(Mins[1], Maxs[1]);
		spawnPos[2] = GetRandomFloat(survivorPos[2], Maxs[2]);
		int count2 = 0;
		while(!IsOnValidMesh(spawnPos) || IsPlayerStuck(spawnPos) || PlayerVisibleTo(spawnPos))
		{
			count2 ++;
			if(count2 > 50)
			{
				break;
			}
			spawnPos[0] = GetRandomFloat(Mins[0], Maxs[0]);
			spawnPos[1] = GetRandomFloat(Mins[1], Maxs[1]);
			spawnPos[2] = GetRandomFloat(survivorPos[2], Maxs[2]);
			TR_TraceRay(spawnPos, direction, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
			if(TR_DidHit())
			{
				TR_GetEndPosition(traceImpact);
				if(!IsOnValidMesh(traceImpact))
				{
					spawnPos[2] = survivorPos[2] + 20.0;
					TR_TraceRay(spawnPos, direction, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
					if(TR_DidHit())
					{
						TR_GetEndPosition(traceImpact);
						spawnPos = traceImpact;
						spawnPos[2] += 20.0;
					}
				}
				else
				{
					spawnPos = traceImpact;
					spawnPos[2] += 20.0;
				}
			}
		}
		if(count2 <= 50)
		{
			for(int X = 0 ; X < numSurvivors2; X++)
			{
				int index = survivors2[X];
				GetClientEyePosition(index, survivorPos);
				survivorPos[2] -= 60.0;
				if(L4D2_VScriptWrapper_NavAreaBuildPath(spawnPos,survivorPos, 800.0,false, false, 3, false))
				{
					//PrintToChatAll("触发传送成功");
					TeleportEntity(infected_type, spawnPos, NULL_VECTOR, NULL_VECTOR);
					SDKUnhook(infected_type, SDKHook_PostThinkPost, UpdateThink);
				}
			}
		}
	}
}
