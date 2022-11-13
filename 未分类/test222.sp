 public PlVers:__version =
{
	version = 5,
	filevers = "1.10.0.6494",
	date = "02/24/2022",
	time = "23:40:32"
};
new Float:NULL_VECTOR[3];
new String:NULL_STRING[4];
public Extension:__ext_core =
{
	name = "Core",
	file = "core",
	autoload = 0,
	required = 0,
};
new MaxClients;
public Extension:__ext_sdktools =
{
	name = "SDKTools",
	file = "sdktools.ext",
	autoload = 1,
	required = 1,
};
public Extension:__ext_sdkhooks =
{
	name = "SDKHooks",
	file = "sdkhooks.ext",
	autoload = 1,
	required = 1,
};
new String:L4D2WeaponName[57][];
new String:L4D2WeaponWorldModel[57][];
new String:L4DResourceName[7][];
new StringMap:g_hWeaponNameTrie = 1952867692;
new EngineVersion:g_iEngine = 1952867692;
public SharedPlugin:__pl_l4dh =
{
	name = "left4dhooks",
	file = "left4dhooks.smx",
	required = 1,
};
new String:infected_name[7][] =
{
	"",
	"smoker",
	"boomer",
	"hunter",
	"spitter",
	"jockey",
	"charger"
};
new Handle:timertele;
new ConVar:infected_spawn_interval;
new ConVar:z_infected_limit;
new ConVar:z_spawn_max;
new ConVar:sb_escort;
new bool:is_late;
new SpawnMaxCount;
new ArrayList:thread_handle;
new ArraySpecial[6];
new TargetPlayer;
new survivors2[8];
new numSurvivors2;
new TeleCount[66];
new String:CLASSNAME_INFECTED[12] = "infected";
new String:CLASSNAME_WITCH[8] = "witch";
new String:CLASSNAME_PHYSPROPS[16] = "prop_physics";
public Plugin:myinfo =
{
	name = "AnneServer InfectedSpawn",
	description = "AnneServer InfectedSpawn",
	author = "Caibiii",
	version = "2022.02.24",
	url = "https://github.com/Caibiii/AnneServer"
};
public void:__ext_core_SetNTVOptional()
{
	MarkNativeAsOptional("GetFeatureStatus");
	MarkNativeAsOptional("RequireFeature");
	MarkNativeAsOptional("AddCommandListener");
	MarkNativeAsOptional("RemoveCommandListener");
	MarkNativeAsOptional("BfWriteBool");
	MarkNativeAsOptional("BfWriteByte");
	MarkNativeAsOptional("BfWriteChar");
	MarkNativeAsOptional("BfWriteShort");
	MarkNativeAsOptional("BfWriteWord");
	MarkNativeAsOptional("BfWriteNum");
	MarkNativeAsOptional("BfWriteFloat");
	MarkNativeAsOptional("BfWriteString");
	MarkNativeAsOptional("BfWriteEntity");
	MarkNativeAsOptional("BfWriteAngle");
	MarkNativeAsOptional("BfWriteCoord");
	MarkNativeAsOptional("BfWriteVecCoord");
	MarkNativeAsOptional("BfWriteVecNormal");
	MarkNativeAsOptional("BfWriteAngles");
	MarkNativeAsOptional("BfReadBool");
	MarkNativeAsOptional("BfReadByte");
	MarkNativeAsOptional("BfReadChar");
	MarkNativeAsOptional("BfReadShort");
	MarkNativeAsOptional("BfReadWord");
	MarkNativeAsOptional("BfReadNum");
	MarkNativeAsOptional("BfReadFloat");
	MarkNativeAsOptional("BfReadString");
	MarkNativeAsOptional("BfReadEntity");
	MarkNativeAsOptional("BfReadAngle");
	MarkNativeAsOptional("BfReadCoord");
	MarkNativeAsOptional("BfReadVecCoord");
	MarkNativeAsOptional("BfReadVecNormal");
	MarkNativeAsOptional("BfReadAngles");
	MarkNativeAsOptional("BfGetNumBytesLeft");
	MarkNativeAsOptional("BfWrite.WriteBool");
	MarkNativeAsOptional("BfWrite.WriteByte");
	MarkNativeAsOptional("BfWrite.WriteChar");
	MarkNativeAsOptional("BfWrite.WriteShort");
	MarkNativeAsOptional("BfWrite.WriteWord");
	MarkNativeAsOptional("BfWrite.WriteNum");
	MarkNativeAsOptional("BfWrite.WriteFloat");
	MarkNativeAsOptional("BfWrite.WriteString");
	MarkNativeAsOptional("BfWrite.WriteEntity");
	MarkNativeAsOptional("BfWrite.WriteAngle");
	MarkNativeAsOptional("BfWrite.WriteCoord");
	MarkNativeAsOptional("BfWrite.WriteVecCoord");
	MarkNativeAsOptional("BfWrite.WriteVecNormal");
	MarkNativeAsOptional("BfWrite.WriteAngles");
	MarkNativeAsOptional("BfRead.ReadBool");
	MarkNativeAsOptional("BfRead.ReadByte");
	MarkNativeAsOptional("BfRead.ReadChar");
	MarkNativeAsOptional("BfRead.ReadShort");
	MarkNativeAsOptional("BfRead.ReadWord");
	MarkNativeAsOptional("BfRead.ReadNum");
	MarkNativeAsOptional("BfRead.ReadFloat");
	MarkNativeAsOptional("BfRead.ReadString");
	MarkNativeAsOptional("BfRead.ReadEntity");
	MarkNativeAsOptional("BfRead.ReadAngle");
	MarkNativeAsOptional("BfRead.ReadCoord");
	MarkNativeAsOptional("BfRead.ReadVecCoord");
	MarkNativeAsOptional("BfRead.ReadVecNormal");
	MarkNativeAsOptional("BfRead.ReadAngles");
	MarkNativeAsOptional("BfRead.BytesLeft.get");
	MarkNativeAsOptional("PbReadInt");
	MarkNativeAsOptional("PbReadFloat");
	MarkNativeAsOptional("PbReadBool");
	MarkNativeAsOptional("PbReadString");
	MarkNativeAsOptional("PbReadColor");
	MarkNativeAsOptional("PbReadAngle");
	MarkNativeAsOptional("PbReadVector");
	MarkNativeAsOptional("PbReadVector2D");
	MarkNativeAsOptional("PbGetRepeatedFieldCount");
	MarkNativeAsOptional("PbSetInt");
	MarkNativeAsOptional("PbSetFloat");
	MarkNativeAsOptional("PbSetBool");
	MarkNativeAsOptional("PbSetString");
	MarkNativeAsOptional("PbSetColor");
	MarkNativeAsOptional("PbSetAngle");
	MarkNativeAsOptional("PbSetVector");
	MarkNativeAsOptional("PbSetVector2D");
	MarkNativeAsOptional("PbAddInt");
	MarkNativeAsOptional("PbAddFloat");
	MarkNativeAsOptional("PbAddBool");
	MarkNativeAsOptional("PbAddString");
	MarkNativeAsOptional("PbAddColor");
	MarkNativeAsOptional("PbAddAngle");
	MarkNativeAsOptional("PbAddVector");
	MarkNativeAsOptional("PbAddVector2D");
	MarkNativeAsOptional("PbRemoveRepeatedFieldValue");
	MarkNativeAsOptional("PbReadMessage");
	MarkNativeAsOptional("PbReadRepeatedMessage");
	MarkNativeAsOptional("PbAddMessage");
	MarkNativeAsOptional("Protobuf.ReadInt");
	MarkNativeAsOptional("Protobuf.ReadInt64");
	MarkNativeAsOptional("Protobuf.ReadFloat");
	MarkNativeAsOptional("Protobuf.ReadBool");
	MarkNativeAsOptional("Protobuf.ReadString");
	MarkNativeAsOptional("Protobuf.ReadColor");
	MarkNativeAsOptional("Protobuf.ReadAngle");
	MarkNativeAsOptional("Protobuf.ReadVector");
	MarkNativeAsOptional("Protobuf.ReadVector2D");
	MarkNativeAsOptional("Protobuf.GetRepeatedFieldCount");
	MarkNativeAsOptional("Protobuf.SetInt");
	MarkNativeAsOptional("Protobuf.SetInt64");
	MarkNativeAsOptional("Protobuf.SetFloat");
	MarkNativeAsOptional("Protobuf.SetBool");
	MarkNativeAsOptional("Protobuf.SetString");
	MarkNativeAsOptional("Protobuf.SetColor");
	MarkNativeAsOptional("Protobuf.SetAngle");
	MarkNativeAsOptional("Protobuf.SetVector");
	MarkNativeAsOptional("Protobuf.SetVector2D");
	MarkNativeAsOptional("Protobuf.AddInt");
	MarkNativeAsOptional("Protobuf.AddInt64");
	MarkNativeAsOptional("Protobuf.AddFloat");
	MarkNativeAsOptional("Protobuf.AddBool");
	MarkNativeAsOptional("Protobuf.AddString");
	MarkNativeAsOptional("Protobuf.AddColor");
	MarkNativeAsOptional("Protobuf.AddAngle");
	MarkNativeAsOptional("Protobuf.AddVector");
	MarkNativeAsOptional("Protobuf.AddVector2D");
	MarkNativeAsOptional("Protobuf.RemoveRepeatedFieldValue");
	MarkNativeAsOptional("Protobuf.ReadMessage");
	MarkNativeAsOptional("Protobuf.ReadRepeatedMessage");
	MarkNativeAsOptional("Protobuf.AddMessage");
	VerifyCoreVersion();
	return void:0;
}

Float:operator+(Float:,_:)(Float:oper1, oper2)
{
	return oper1 + float(oper2);
}

Float:operator+(Float:,_:)(Float:oper1, oper2)
{
	return oper1 + float(oper2);
}

void:MakeVectorFromPoints(Float:pt1[3], Float:pt2[3], Float:output[3])
{
	output[0] = pt2[0] - pt1[0];
	output[1] = pt2[1] - pt1[1];
	output[2] = pt2[2] - pt1[2];
	return void:0;
}

bool:StrEqual(String:str1[], String:str2[], bool:caseSensitive)
{
	return strcmp(str1, str2, caseSensitive) == 0;
}

HasAnyCountFull()
{
	new class1;
	new class3;
	new class5;
	new class6;
	new count;
	new survivors[4];
	new numSurvivors;
	new i = 1;
	while (i <= MaxClients)
	{
		new var1;
		if (IsBotInfected(i) && IsPlayerAlive(i))
		{
			new type = GetEntProp(i, PropType:0, "m_zombieClass", 4, 0);
			if (type <= 6)
			{
				count++;
			}
			switch (type)
			{
				case 1:
				{
					class1++;
					new String:cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[class1]);
					if (ConVar.IntValue.get(FindConVar(cvar)) <= class1)
					{
						ArraySpecial[0] = 0;
					}
				}
				case 2:
				{
					ArraySpecial[1] = 0;
				}
				case 3:
				{
					class3++;
					new String:cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[class3]);
					if (ConVar.IntValue.get(FindConVar(cvar)) <= class3)
					{
						ArraySpecial[2] = 0;
					}
				}
				case 4:
				{
					ArraySpecial[3] = 0;
				}
				case 5:
				{
					class5++;
					new String:cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[class5]);
					if (ConVar.IntValue.get(FindConVar(cvar)) <= class5)
					{
						ArraySpecial[4] = 0;
					}
				}
				case 6:
				{
					class6++;
					new String:cvar[16];
					Format(cvar, 16, "z_%s_limit", infected_name[class6]);
					if (ConVar.IntValue.get(FindConVar(cvar)) <= class6)
					{
						ArraySpecial[5] = 0;
					}
				}
				default:
				{
				}
			}
		}
		new var2;
		if (IsSurvivor(i) && !IsSurvivorPinned(i) && IsPlayerAlive(i))
		{
			is_late = true;
			if (numSurvivors < 4)
			{
				survivors[numSurvivors] = i;
				numSurvivors++;
			}
		}
		i++;
	}
	if (0 < numSurvivors)
	{
		TargetPlayer = survivors[GetRandomInt(0, numSurvivors + -1)];
	}
	else
	{
		TargetPlayer = L4D_GetHighestFlowSurvivor();
	}
	return count;
}

bool:PlayerVisibleTo(Float:spawnpos[3])
{
	new Float:pos[3] = 0.0;
	numSurvivors2 = 0;
	new i = 1;
	while (i <= MaxClients)
	{
		new var1;
		if (IsSurvivor(i) && IsPlayerAlive(i))
		{
			survivors2[numSurvivors2] = i;
			numSurvivors2 += 1;
			GetClientEyePosition(i, pos);
			new var2;
			if (PosIsVisibleTo(i, spawnpos) || GetVectorDistance(spawnpos, pos, false) < 200.0)
			{
				return true;
			}
		}
		i++;
	}
	return false;
}

bool:PosIsVisibleTo(client, Float:targetposition[3])
{
	new Float:position[3] = 0.0;
	new Float:vAngles[3] = 0.0;
	new Float:vLookAt[3] = 0.0;
	new Float:spawnPos[3] = 0.0;
	GetClientEyePosition(client, position);
	MakeVectorFromPoints(targetposition, position, vLookAt);
	GetVectorAngles(vLookAt, vAngles);
	static Handle:trace;
	trace = TR_TraceRayFilterEx(targetposition, vAngles, 24705, RayType:1, TracerayFilter, client);
	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		static Float:vStart[3];
		TR_GetEndPosition(vStart, trace);
		if (GetVectorDistance(targetposition, vStart, false) + 75.0 >= GetVectorDistance(position, targetposition, false))
		{
			isVisible = true;
		}
		else
		{
			new var1 = targetposition;
			spawnPos = var1;
			spawnPos[2] += 40.0;
			MakeVectorFromPoints(spawnPos, position, vLookAt);
			GetVectorAngles(vLookAt, vAngles);
			trace = TR_TraceRayFilterEx(spawnPos, vAngles, 24705, RayType:1, TracerayFilter, client);
			if (TR_DidHit(trace))
			{
				TR_GetEndPosition(vStart, trace);
				if (GetVectorDistance(spawnPos, vStart, false) + 75.0 >= GetVectorDistance(position, spawnPos, false))
				{
					isVisible = true;
				}
			}
			isVisible = true;
		}
	}
	else
	{
		isVisible = true;
	}
	CloseHandle(trace);
	trace = MissingTAG:0;
	return isVisible;
}

public bool:TracerayFilter(entity, contentMask)
{
	if (entity <= MaxClients)
	{
		return false;
	}
	new String:class[128];
	GetEdictClassname(entity, class, 128);
	new var1;
	if (StrEqual(class, CLASSNAME_INFECTED, false) || StrEqual(class, CLASSNAME_WITCH, false) || StrEqual(class, CLASSNAME_PHYSPROPS, false))
	{
		return false;
	}
	return true;
}

bool:IsOnValidMesh(Float:pos[3])
{
	new Address:pNavArea = L4D2Direct_GetTerrorNavArea(pos, 120.0);
	if (pNavArea)
	{
		return true;
	}
	return false;
}

bool:IsValidClient(client)
{
	new var1;
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	return false;
}

bool:IsPlayerStuck(Float:pos[3])
{
	new bool:isStuck = 1;
	new Float:mins[3] = 0.0;
	new Float:maxs[3] = 0.0;
	new Float:pos2[3] = 0.0;
	pos2[0] = pos[0];
	pos2[1] = pos[1];
	pos2[2] = pos[2] + 35.0;
	mins[0] = -16.0;
	mins[1] = -16.0;
	mins[2] = 0.0;
	maxs[0] = 16.0;
	maxs[1] = 16.0;
	maxs[2] = 35.0;
	TR_TraceHullFilter(pos, pos2, mins, maxs, 147467, TracerayFilter, any:0);
	isStuck = TR_DidHit(Handle:0);
	return isStuck;
}

bool:IsSurvivorPinned(client)
{
	if (IsSurvivor(client))
	{
		if (0 < GetEntProp(client, PropType:0, "m_isIncapacitated", 4, 0))
		{
			return true;
		}
		if (0 < GetEntPropEnt(client, PropType:0, "m_tongueOwner", 0))
		{
			return true;
		}
		if (0 < GetEntPropEnt(client, PropType:0, "m_pounceAttacker", 0))
		{
			return true;
		}
		if (0 < GetEntPropEnt(client, PropType:0, "m_carryAttacker", 0))
		{
			return true;
		}
		if (0 < GetEntPropEnt(client, PropType:0, "m_pummelAttacker", 0))
		{
			return true;
		}
		if (0 < GetEntPropEnt(client, PropType:0, "m_jockeyAttacker", 0))
		{
			return true;
		}
	}
	return false;
}

bool:IsPinningASurvivor(client)
{
	new var1;
	if (IsBotInfected(client) && IsPlayerAlive(client))
	{
		if (0 < GetEntPropEnt(client, PropType:0, "m_tongueVictim", 0))
		{
			return true;
		}
		if (0 < GetEntPropEnt(client, PropType:0, "m_pounceVictim", 0))
		{
			return true;
		}
		if (0 < GetEntPropEnt(client, PropType:0, "m_carryVictim", 0))
		{
			return true;
		}
		if (0 < GetEntPropEnt(client, PropType:0, "m_pummelVictim", 0))
		{
			return true;
		}
		if (0 < GetEntPropEnt(client, PropType:0, "m_jockeyVictim", 0))
		{
			return true;
		}
	}
	return false;
}

bool:IsSpecialInArray(Array[6], infected_type)
{
	new i;
	while (i < 6)
	{
		if (Array[i] == infected_type)
		{
			return true;
		}
		i++;
	}
	return false;
}

bool:IsSurvivor(client)
{
	new var1;
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	return false;
}

bool:IsBotInfected(client)
{
	new var1;
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3)
	{
		return true;
	}
	return false;
}

bool:CanBeTP(client)
{
	new var1;
	if (!IsClientInGame(client) || !IsFakeClient(client))
	{
		return false;
	}
	new var2;
	if (GetClientTeam(client) == 3 && !IsPlayerAlive(client))
	{
		return false;
	}
	if (GetEntProp(client, PropType:0, "m_zombieClass", 4, 0) == 8)
	{
		return false;
	}
	return true;
}

public Action:L4D_OnShovedBySurvivor(client, victim, Float:vecDir[3])
{
	if (IsSpitter(victim))
	{
		return Action:3;
	}
	return Action:0;
}

public Action:L4D2_OnEntityShoved(client, entity, weapon, Float:vecDir[3], bool:bIsHighPounce)
{
	if (IsSpitter(client))
	{
		return Action:3;
	}
	return Action:0;
}

bool:IsInfected(client)
{
	new var1;
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

bool:IsSpitter(client)
{
	if (!IsInfected(client))
	{
		return false;
	}
	if (!IsPlayerAlive(client))
	{
		return false;
	}
	if (GetEntProp(client, PropType:0, "m_zombieClass", 4, 0) != 4)
	{
		return false;
	}
	return true;
}

public void:OnPluginStart()
{
	HookEvent("round_start", OnRoundStart, EventHookMode:2);
	HookEvent("finale_win", OnRoundEnd, EventHookMode:2);
	HookEvent("map_transition", OnRoundEnd, EventHookMode:2);
	HookEvent("round_end", OnRoundEnd, EventHookMode:2);
	HookEvent("player_death", player_death, EventHookMode:2);
	infected_spawn_interval = CreateConVar("versus_special_respawn_interval", "16.0", "", 0, false, 0.0, false, 0.0);
	z_infected_limit = CreateConVar("l4d_infected_limit", "4", "", 0, false, 0.0, false, 0.0);
	sb_escort = CreateConVar("sb_escort", "1", "", 0, false, 0.0, false, 0.0);
	z_spawn_max = CreateConVar("z_spawn_max", "500", "", 0, false, 0.0, false, 0.0);
	ConVar.SetInt(FindConVar("director_no_specials"), 1, false, false);
	thread_handle = ArrayList.ArrayList(1, 0);
	RegAdminCmd("sm_startspawn", startspawn, 16384, "restartspawn", "", 0);
	return void:0;
}

public Action:startspawn(client, any:args)
{
	if (L4D_HasAnySurvivorLeftSafeArea())
	{
		CreateTimer(0.5, SpawnFirstInfected, any:0, 0);
	}
	return Action:0;
}

public void:player_death(Event:event, String:name[], bool:dont_broadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid", 0));
	if (IsBotInfected(client))
	{
		if (GetEntProp(client, PropType:0, "m_zombieClass", 4, 0) != 4)
		{
			CreateTimer(0.5, kickbot, client, 0);
		}
	}
	TeleCount[client] = 0;
	return void:0;
}

public Action:kickbot(Handle:timer, any:client)
{
	new var1;
	if (IsClientInGame(client) && !IsClientInKickQueue(client))
	{
		if (IsFakeClient(client))
		{
			KickClient(client, "");
		}
	}
	return Action:0;
}

public void:OnRoundStart(Event:event, String:name[], bool:dont_broadcast)
{
	CloseHandle(timertele);
	timertele = MissingTAG:0;
	is_late = false;
	new i;
	while (ArrayList.Length.get(thread_handle) > i)
	{
		KillTimer(ArrayList.Get(thread_handle, i, 0, false), false);
		ArrayList.Erase(thread_handle, i);
		i++;
	}
	CreateTimer(3.0, SafeRoomOthers, any:0, 2);
	return void:0;
}

public void:OnRoundEnd(Event:event, String:name[], bool:dont_broadcast)
{
	CloseHandle(timertele);
	timertele = MissingTAG:0;
	is_late = false;
	new i;
	while (ArrayList.Length.get(thread_handle) > i)
	{
		KillTimer(ArrayList.Get(thread_handle, i, 0, false), false);
		ArrayList.Erase(thread_handle, i);
		i++;
	}
	return void:0;
}

public Action:SafeRoomOthers(Handle:timer)
{
	new infectedBot = 1;
	while (infectedBot <= MaxClients)
	{
		new var1;
		if (IsBotInfected(infectedBot) && IsPlayerAlive(infectedBot))
		{
			TeleCount[infectedBot] = 0;
		}
		new var2;
		if (IsSurvivor(infectedBot) && !IsPlayerAlive(infectedBot))
		{
			L4D_RespawnPlayer(infectedBot);
		}
		infectedBot++;
	}
	return Action:0;
}

public Action:SpawnFirstInfected(Handle:timer)
{
	if (!is_late)
	{
		is_late = true;
		if (ConVar.FloatValue.get(infected_spawn_interval) > 9.0)
		{
			new Handle:time = CreateTimer(ConVar.FloatValue.get(infected_spawn_interval) + 8.0, SpawnNewInfected, any:0, 1);
			ArrayList.Push(thread_handle, time);
			TriggerTimer(time, true);
		}
		else
		{
			new Handle:time = CreateTimer(ConVar.FloatValue.get(infected_spawn_interval) + 4.0, SpawnNewInfected, any:0, 1);
			ArrayList.Push(thread_handle, time);
			TriggerTimer(time, true);
		}
		timertele = CreateTimer(1.0, Timer_PositionSI, any:0, 1);
	}
	return Action:0;
}

public Action:SpawnNewInfected(Handle:timer)
{
	if (is_late)
	{
		if (ConVar.IntValue.get(z_infected_limit) > ArrayList.Length.get(thread_handle))
		{
			if (ConVar.FloatValue.get(infected_spawn_interval) > 9.0)
			{
				new Handle:time = CreateTimer(ConVar.FloatValue.get(infected_spawn_interval) + 8.0, SpawnNewInfected, any:0, 1);
				ArrayList.Push(thread_handle, time);
				TriggerTimer(time, true);
			}
			else
			{
				new Handle:time = CreateTimer(ConVar.FloatValue.get(infected_spawn_interval) + 4.0, SpawnNewInfected, any:0, 1);
				ArrayList.Push(thread_handle, time);
				TriggerTimer(time, true);
			}
		}
		else
		{
			if (ConVar.IntValue.get(z_infected_limit) < ArrayList.Length.get(thread_handle))
			{
				new i;
				while (ArrayList.Length.get(thread_handle) > i)
				{
					if (timer == ArrayList.Get(thread_handle, i, 0, false))
					{
						ArrayList.Erase(thread_handle, i);
						return Action:4;
					}
					i++;
				}
			}
		}
		ConVar.IntValue.set(z_spawn_max, 250);
		SpawnMaxCount = SpawnMaxCount + 1;
		if (ConVar.IntValue.get(z_infected_limit) < SpawnMaxCount)
		{
			new index = ConVar.IntValue.get(z_infected_limit) + 2;
			if (SpawnMaxCount > index)
			{
				SpawnMaxCount = index;
			}
			ConVar.IntValue.set(sb_escort, 1);
		}
	}
	return Action:0;
}

public void:OnGameFrame()
{
	new var1;
	if (is_late && ConVar.IntValue.get(sb_escort) > 0 && SpawnMaxCount > 0)
	{
		if (!(ConVar.IntValue.get(z_infected_limit) <= HasAnyCountFull()))
		{
			new Float:spawnPos[3] = 0.0;
			new Float:survivorPos[3] = 0.0;
			new Float:direction[3] = 0.0;
			new Float:traceImpact[3] = 0.0;
			new Float:Mins[3] = 0.0;
			new Float:Maxs[3] = 0.0;
			new Float:dist = 0.0;
			new infected_type = GetRandomInt(1, 6);
			GetClientEyePosition(TargetPlayer, survivorPos);
			new var4 = z_spawn_max;
			ConVar.FloatValue.set(var4, ConVar.FloatValue.get(var4) + 5);
			if (ConVar.FloatValue.get(z_spawn_max) < 500.0)
			{
				dist = 750.0;
				Maxs[2] = survivorPos[2] + 500.0;
			}
			else
			{
				dist = ConVar.FloatValue.get(z_spawn_max) + 250.0;
				Maxs[2] = survivorPos[2] + ConVar.FloatValue.get(z_spawn_max);
			}
			Mins[0] = survivorPos[0] - ConVar.FloatValue.get(z_spawn_max);
			Maxs[0] = survivorPos[0] + ConVar.FloatValue.get(z_spawn_max);
			Mins[1] = survivorPos[1] - ConVar.FloatValue.get(z_spawn_max);
			Maxs[1] = survivorPos[1] + ConVar.FloatValue.get(z_spawn_max);
			direction[0] = 90.0;
			direction[1] = 0.0;
			direction[2] = 0.0;
			spawnPos[0] = GetRandomFloat(Mins[0], Maxs[0]);
			spawnPos[1] = GetRandomFloat(Mins[1], Maxs[1]);
			spawnPos[2] = GetRandomFloat(survivorPos[2], Maxs[2]);
			new count2;
			while (!IsOnValidMesh(spawnPos) || IsPlayerStuck(spawnPos) || PlayerVisibleTo(spawnPos))
			{
				count2++;
				if (!(count2 > 50))
				{
					spawnPos[0] = GetRandomFloat(Mins[0], Maxs[0]);
					spawnPos[1] = GetRandomFloat(Mins[1], Maxs[1]);
					spawnPos[2] = GetRandomFloat(survivorPos[2], Maxs[2]);
					TR_TraceRay(spawnPos, direction, 147467, RayType:1);
					if (TR_DidHit(Handle:0))
					{
						TR_GetEndPosition(traceImpact, Handle:0);
						if (!IsOnValidMesh(traceImpact))
						{
							spawnPos[2] = survivorPos[2] + 20.0;
							TR_TraceRay(spawnPos, direction, 147467, RayType:1);
							if (TR_DidHit(Handle:0))
							{
								TR_GetEndPosition(traceImpact, Handle:0);
								spawnPos = traceImpact;
								spawnPos[2] += 20.0;
							}
						}
						spawnPos = traceImpact;
						spawnPos[2] += 20.0;
					}
				}
				if (count2 <= 50)
				{
					new X;
					while (X < numSurvivors2)
					{
						new index = survivors2[X];
						new count;
						GetClientEyePosition(index, survivorPos);
						survivorPos[2] -= 60.0;
						if (L4D2_VScriptWrapper_NavAreaBuildPath(spawnPos, survivorPos, dist, false, false, 3, false))
						{
							while (!IsSpecialInArray(ArraySpecial, infected_type) && count < 50)
							{
								infected_type = GetRandomInt(1, 6);
								count++;
							}
							if (count > 49)
							{
								infected_type = 3;
							}
							L4D2_SpawnSpecial(infected_type, spawnPos, 3604);
							SpawnMaxCount = SpawnMaxCount + -1;
						}
						X++;
					}
				}
			}
			if (count2 <= 50)
			{
				new X;
				while (X < numSurvivors2)
				{
					new index = survivors2[X];
					new count;
					GetClientEyePosition(index, survivorPos);
					survivorPos[2] -= 60.0;
					if (L4D2_VScriptWrapper_NavAreaBuildPath(spawnPos, survivorPos, dist, false, false, 3, false))
					{
						while (!IsSpecialInArray(ArraySpecial, infected_type) && count < 50)
						{
							infected_type = GetRandomInt(1, 6);
							count++;
						}
						if (count > 49)
						{
							infected_type = 3;
						}
						L4D2_SpawnSpecial(infected_type, spawnPos, 3604);
						SpawnMaxCount = SpawnMaxCount + -1;
					}
					X++;
				}
			}
		}
	}
	return void:0;
}

public Action:Timer_PositionSI(Handle:timer)
{
	new infectedBot = 1;
	while (infectedBot <= MaxClients)
	{
		new var1;
		if (IsBotInfected(infectedBot) && IsPlayerAlive(infectedBot) && CanBeTP(infectedBot))
		{
			if (TeleCount[infectedBot] > 6)
			{
				new Float:pos2[3] = 0.0;
				GetClientEyePosition(infectedBot, pos2);
				new var2;
				if (!PlayerVisibleTo(pos2) && !IsPinningASurvivor(infectedBot))
				{
					SDKHook(infectedBot, SDKHookType:20, UpdateThink);
					TeleCount[infectedBot] = 0;
				}
			}
			TeleCount[infectedBot] += 1;
		}
		infectedBot++;
	}
	return Action:0;
}

public void:UpdateThink(infected_type)
{
	new var1;
	if (!IsValidClient(infected_type) || !IsPlayerAlive(infected_type))
	{
		return void:0;
	}
	TeleCount[infected_type] = 0;
	static Float:pos2[3];
	GetClientEyePosition(infected_type, pos2);
	new var2;
	if (!PlayerVisibleTo(pos2) && !IsPinningASurvivor(infected_type))
	{
		new Float:spawnPos[3] = 0.0;
		new Float:survivorPos[3] = 0.0;
		new Float:direction[3] = 0.0;
		new Float:traceImpact[3] = 0.0;
		new Float:Mins[3] = 0.0;
		new Float:Maxs[3] = 0.0;
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
		new count2;
		while (!IsOnValidMesh(spawnPos) || IsPlayerStuck(spawnPos) || PlayerVisibleTo(spawnPos))
		{
			count2++;
			if (!(count2 > 50))
			{
				spawnPos[0] = GetRandomFloat(Mins[0], Maxs[0]);
				spawnPos[1] = GetRandomFloat(Mins[1], Maxs[1]);
				spawnPos[2] = GetRandomFloat(survivorPos[2], Maxs[2]);
				TR_TraceRay(spawnPos, direction, 147467, RayType:1);
				if (TR_DidHit(Handle:0))
				{
					TR_GetEndPosition(traceImpact, Handle:0);
					if (!IsOnValidMesh(traceImpact))
					{
						spawnPos[2] = survivorPos[2] + 20.0;
						TR_TraceRay(spawnPos, direction, 147467, RayType:1);
						if (TR_DidHit(Handle:0))
						{
							TR_GetEndPosition(traceImpact, Handle:0);
							spawnPos = traceImpact;
							spawnPos[2] += 20.0;
						}
					}
					spawnPos = traceImpact;
					spawnPos[2] += 20.0;
				}
			}
			if (count2 <= 50)
			{
				new X;
				while (X < numSurvivors2)
				{
					new index = survivors2[X];
					GetClientEyePosition(index, survivorPos);
					survivorPos[2] -= 60.0;
					if (L4D2_VScriptWrapper_NavAreaBuildPath(spawnPos, survivorPos, 800.0, false, false, 3, false))
					{
						TeleportEntity(infected_type, spawnPos, NULL_VECTOR, NULL_VECTOR);
						SDKUnhook(infected_type, SDKHookType:20, UpdateThink);
					}
					X++;
				}
			}
		}
		if (count2 <= 50)
		{
			new X;
			while (X < numSurvivors2)
			{
				new index = survivors2[X];
				GetClientEyePosition(index, survivorPos);
				survivorPos[2] -= 60.0;
				if (L4D2_VScriptWrapper_NavAreaBuildPath(spawnPos, survivorPos, 800.0, false, false, 3, false))
				{
					TeleportEntity(infected_type, spawnPos, NULL_VECTOR, NULL_VECTOR);
					SDKUnhook(infected_type, SDKHookType:20, UpdateThink);
				}
				X++;
			}
		}
	}
	return void:0;
}

 