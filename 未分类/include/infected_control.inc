enum SpecialInfected
{
    Smoker = 1,
    Boomer,
    Hunter,
    Spitter,
    Jockey,
    Charger,
    Witch,
    Tank
};
char infected_name[][] = 
{
    "",
    "smoker",
    "boomer",
    "hunter",
    "spitter",
    "jockey",
    "charger"
};
Handle timertele;	
ConVar infected_spawn_interval;	//特感复活时间控制
ConVar z_infected_limit;		//特感最大数量参数
ConVar z_spawn_max;				//特感复活最大距离控制
//ConVar sb_escort;
bool is_late = false;			//特感复活开关之一
int SpawnMaxCount = 0; 			//特感复活数量及其复活开关控制之一
ArrayList thread_handle; 		//特感数量数组
int ArraySpecial[6];  			//特感类型数组
int TargetPlayer;
int survivors2[8];
int numSurvivors2= 0;
int TeleCount[MAXPLAYERS+1];	//特感传送次数计数
static const char CLASSNAME_INFECTED[] = "infected";
static const char CLASSNAME_WITCH[] = "witch";
static const char CLASSNAME_PHYSPROPS[] = "prop_physics";
//float TelePostion[3];
int HasAnyCountFull()
{
	int class1=0,class2=0,class3=0,class4=0,class5=0,class6=0,count=0,survivors[4],numSurvivors=0;
    for (int i = 1; i <= MaxClients; i++)
    {
		if(i <= 6)
		{
			int a = i - 1;
			char cvar[16];
			Format(cvar, 16, "z_%s_limit", infected_name[i]);
			if(FindConVar(cvar).IntValue == 0)
			{
				ArraySpecial[a] = 0;
			}
		}
        if (IsBotInfected(i) && IsPlayerAlive(i))
        {
			int type = GetEntProp(i, Prop_Send, "m_zombieClass");
			if(type <= 6)
			{
				count ++ ;
			}
			switch (type)
			{
				case 1:
				{
					class1++;
					char cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[type]);
					if(class1 >= FindConVar(cvar).IntValue)
					{
						ArraySpecial[0] = 0;
					}
				}
				case 2:
				{
					class2++;
					char cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[type]);
					if(class2 >= FindConVar(cvar).IntValue)
					{
						ArraySpecial[1] = 0;
					}
				}
				case 3:
				{
					class3++;
					char cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[type]);
					if(class3 >= FindConVar(cvar).IntValue)
					{
						ArraySpecial[2] = 0;
					}
				}
				case 4:
				{
					class4++;
					char cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[type]);
					if(class4 >= FindConVar(cvar).IntValue)
					{
						ArraySpecial[3] = 0;
					}
				}
				case 5:
				{
					class5++;
					char cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[type]);
					if(class5 >= FindConVar(cvar).IntValue)
					{
						ArraySpecial[4] = 0;
					}
				}
				case 6:
				{
					class6++;
					char cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[type]);
					if(class6 >= FindConVar(cvar).IntValue)
					{
						ArraySpecial[5] = 0;
					}
				}
			}
		}
			
		if(IsSurvivor(i) && !IsSurvivorPinned(i) && IsPlayerAlive(i)) 
		{
			is_late = true;
			if(numSurvivors < 4)
			{
				survivors[numSurvivors] = i;
				numSurvivors++;
			}
		}
		
	}
	//int target = TargetPlayer;
	if(numSurvivors > 0)
	{
		TargetPlayer = survivors[GetRandomInt(0, numSurvivors - 1)];
	}
	else
	{
		TargetPlayer = L4D_GetHighestFlowSurvivor();
		
	}
	return count;
}

//判断该坐标是否可以看到生还或者距离小于200码
bool PlayerVisibleTo(float spawnpos[3])
{
	float pos[3];
	numSurvivors2 = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsSurvivor(i) && IsPlayerAlive(i))
		{
			survivors2[numSurvivors2] = i;
			numSurvivors2++;
			GetClientEyePosition(i, pos);
			if(PosIsVisibleTo(i, spawnpos) || GetVectorDistance(spawnpos, pos) < 200.0)
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
	static Handle trace;
	trace = TR_TraceRayFilterEx(targetposition, vAngles, MASK_VISIBLE, RayType_Infinite, TracerayFilter, client);
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
			trace = TR_TraceRayFilterEx(spawnPos, vAngles, MASK_VISIBLE, RayType_Infinite, TracerayFilter, client);
			if(TR_DidHit(trace))
			{
				TR_GetEndPosition(vStart, trace);
				if((GetVectorDistance(spawnPos, vStart, false) + 75.0) >= GetVectorDistance(position, spawnPos))
				isVisible = true;
			}
			else
			{
				isVisible = true;
			}
		}
	}
	else
	{
		isVisible = true;
	}
	delete trace;
	return isVisible;
}

//判断发射的射线击中的目标类型
public bool TracerayFilter(int entity, int contentMask) 
{
	if (entity <= MaxClients)
	{
		return false;
	}
	char class[128];
	GetEdictClassname(entity, class, sizeof(class));
	if (StrEqual(class, CLASSNAME_INFECTED, .caseSensitive = false)
	|| StrEqual(class, CLASSNAME_WITCH, .caseSensitive = false)
	|| StrEqual(class, CLASSNAME_PHYSPROPS, .caseSensitive = false))
	{
		return false;
	}
	return true;
}
//判断该坐标是否在地图NAV上
bool IsOnValidMesh(float pos[3])
{
	Address pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(pos);
	if (pNavArea != Address_Null)
	{
		return true;
	}
	else
	{
		return false;
	}	
}
//判断client是否有效以及是否在游戏内
bool IsValidClient(int client) 
{
    if( client > 0 && client <= MaxClients && IsClientInGame(client) ) 
	{
    	return true;
    } 
	else 
	{
    	return false;
    }    
}
/*
//判断client是否卡住
bool IsPlayerStuck(float vPos[3])
{
	float vAng1[3], vAng2[3];
	vAng1[0] = vPos[0] - 15.0;
	vAng1[1] = vPos[1] + 15.0;
	vAng1[2] = vPos[2] + 100.0;
	vAng2[0] = vPos[0] + 15.0;
	vAng2[1] = vPos[1] - 15.0;
	vAng2[2] = vPos[2];
	TR_TraceRay(vAng1, vAng2, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint);
	if (TR_DidHit())
	{
		return true;
	}
	vAng1[0] = vPos[0] - 15.0;
	vAng1[1] = vPos[1] - 15.0;
	vAng1[2] = vPos[2];
	vAng2[0] = vPos[0] + 15.0;
	vAng2[1] = vPos[1] + 15.0;
	vAng2[2] = vPos[2] + 100.0;
	TR_TraceRay(vAng1, vAng2, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint);
	if (TR_DidHit())
	{
		return true;
	}
	return false;
}
*/
bool IsPlayerStuck(float pos[3])
{
	bool isStuck = true;
	float mins[3], maxs[3], pos2[3];
	pos2[0] = pos[0];
	pos2[1] = pos[1];
	pos2[2] = pos[2] + 35.0;
	mins[0] = -16.0;
	mins[1] = -16.0;
	mins[2] = 0.0;
	maxs[0] = 16.0;
	maxs[1] = 16.0;
	maxs[2] = 35.0;
	TR_TraceHullFilter(pos, pos2, mins, maxs, MASK_NPCSOLID_BRUSHONLY, TracerayFilter);
	isStuck = TR_DidHit();
	return isStuck;
}

//判断生还者是否被控或已经倒地
bool IsSurvivorPinned(int client) 
{
	if (IsSurvivor(client))
	{
		if( GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) return true;
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) return true;
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) return true;
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) return true;
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) return true;
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) return true;
	}		
	return false;
}
//判断特感数量是否控到生还
bool IsPinningASurvivor(int client) 
{
	if( IsBotInfected(client) && IsPlayerAlive(client) ) 
	{
		if( GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0 ) return true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0 ) return true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0 ) return true; // charger carrying
		if( GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 ) return true; // charger pounding
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0 ) return true; // jockey
	}
	return false;
}

//判断该特感是否数组里
bool IsSpecialInArray(int Array[6], int infected_type)
{
    for(int i = 0; i < 6; i++)
	{
		if(infected_type == Array[i])
		{
			return true;
		}
	}
	return false;
}
//判断client是否为有效的生还者
bool IsSurvivor(int client)
{
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2) return true;
    return false;
}
//判断client是否为有效的感染者
bool IsBotInfected(int client)
{
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3) return true;
    return false;
}
//判断该client是否符合传送条件
bool CanBeTP(int client)
{
	if (!IsClientInGame(client) || !IsFakeClient(client))return false;
	if (GetClientTeam(client) != 3 || !IsPlayerAlive(client))return false;
	if(GetEntProp(client, Prop_Send, "m_zombieClass") == 8)return false;
	return true;
}

public Action L4D_OnShovedBySurvivor(int client, int victim, const float vecDir[3])
{
	if (IsSpitter(victim))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action L4D2_OnEntityShoved(int client, int entity, int weapon, float vecDir[3], bool bIsHighPounce)
{
	if (IsSpitter(client))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

bool IsInfected(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

bool IsSpitter(int client)  
{
	if (!IsInfected(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 4)
		return false;

	return true;
}