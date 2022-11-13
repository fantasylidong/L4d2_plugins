#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include "treeutil.sp"
#define DEBUG 0
#define CVAR_FLAG FCVAR_NOTIFY
#define NAV_MESH_HEIGHT 20.0
#define FALL_DETECT_HEIGHT 120.0

public Plugin myinfo = 
{
	name 			= "Ai Charger 增强 2.0 版本",
	author 			= "夜羽真白，东",
	description 	= "Ai Charger 2.0",
	version 		= "2.0.0.1",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hAllowBhop, g_hBhopSpeed, g_hChargeDist, g_hAimOffset, g_hChargerTarget, g_hAllowMeleeAvoid, g_hChargerMeleeDamage, g_hChargeInterval;
// Float
//float charge_interval[MAXPLAYERS + 1] = 0.0;
// Bools
bool can_attack_pinned[MAXPLAYERS + 1] = false;
bool charger_cancharge[MAXPLAYERS + 1] = false;
// Ints
int survivor_num = 0, ranged_client[MAXPLAYERS + 1][MAXPLAYERS + 1], ranged_index[MAXPLAYERS + 1] = {0};

public void OnPluginStart()
{
	// CreateConVars
	g_hAllowBhop = CreateConVar("ai_ChargerBhop", "1", "是否开启 Charger 连跳", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hBhopSpeed = CreateConVar("ai_ChagrerBhopSpeed", "90.0", "Charger 连跳速度", CVAR_FLAG, true, 0.0);
	g_hChargeDist = CreateConVar("ai_ChargerChargeDistance", "250.0", "Charger 只能在与目标小于这一距离时冲锋", CVAR_FLAG, true, 0.0);
	g_hAimOffset = CreateConVar("ai_ChargerAimOffset", "30.0", "目标的瞄准水平与 Charger 处在这一范围内，Charger 不会冲锋", CVAR_FLAG, true, 0.0);
	g_hAllowMeleeAvoid = CreateConVar("ai_ChargerMeleeAvoid", "1", "是否开启 Charger 近战回避", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hChargerMeleeDamage = CreateConVar("ai_ChargerMeleeDamage", "350", "Charger 血量小于这个值，将不会直接冲锋拿着近战的生还者", CVAR_FLAG, true, 0.0);
	g_hChargerTarget = CreateConVar("ai_ChargerTarget", "1", "Charger目标选择：1=自然目标选择，2=优先取最近目标，3=优先撞人多处", CVAR_FLAG, true, 1.0, true, 2.0);
	g_hChargeInterval = FindConVar("z_charge_interval");
	// HookEvents
	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("ability_use", evt_AbilityUse);
	//HookEvent("charger_charge_start", evt_ChargerChargeStart);
	//HookEvent("charger_charge_end", evt_ChargerChargeEnd);
	
}
/*
public void evt_ChargerChargeStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsCharger(client))
	{
		CreateTimer(g_hChargeInterval.FloatValue, ChargerEnable, client);
	}
	charger_cancharge[client] = false;
}



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

public void evt_ChargerChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsCharger(client) && IsPinningSomeone(client))
	{
		float self_eye_pos[3] = {0.0}, targetpos[3] = {0.0}, look_at[3] = {0.0};
		if (IsValidSurvivor(nearest_target))
		{
			GetClientEyePosition(client, self_eye_pos);
			GetClientAbsOrigin(nearest_target, targetpos);
			targetpos[2] += 45.0;
			MakeVectorFromPoints(self_eye_pos, targetpos, look_at);
			GetVectorAngles(look_at, look_at);
			TeleportEntity(client, NULL_VECTOR, look_at, NULL_VECTOR);
		}
	}
}
*/

public void evt_AbilityUse(Event event, const char[] name, bool dontBroadCast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsCharger(client))
	{
		static char sAbility[16];
		event.GetString("ability", sAbility, sizeof(sAbility));
		if (strcmp(sAbility, "ability_charge") == 0)
		{
			CreateTimer(g_hChargeInterval.FloatValue, ChargerEnable, client);
		}
		charger_cancharge[client] = false;
		#if (DEBUG)
			char sTime[32];
			FormatTime(sTime, sizeof(sTime), "%I-%M-%S", GetTime()); 
			PrintToChatAll("冲锋后冲锋能力：%d %d, 冲锋时间：%s", charger_cancharge[client], GetChargerTime(client),sTime);
		#endif	
	}
}

public Action ChargerEnable(Handle timer,int client) 
{
	charger_cancharge[client] = true;
}


// 事件
public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsCharger(client))
	{	
		charger_cancharge[client] = true;
		#if (DEBUG)
			PrintToChatAll("生成后冲锋能力：%d %d", charger_cancharge[client], GetChargerTime(client));
		#endif	
		// 牛刚生成时，设置设为不可冲锋
		BlockCharge(client, 0);	
	}
}

// 主要
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsCharger(client))
	{
		bool has_sight = view_as<bool>(GetEntProp(client, Prop_Send, "m_hasVisibleThreats"));
		int target = GetClientAimTarget(client, true), flags = GetEntityFlags(client), closet_survivor_distance = GetClosetSurvivorDistance(client), ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
		float self_pos[3] = {0.0}, target_pos[3] = {0.0}, vec_speed[3] = {0.0}, vel_buffer[3] = {0.0}, cur_speed = 0.0;
		GetClientAbsOrigin(client, self_pos);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec_speed);
		cur_speed = SquareRoot(Pow(vec_speed[0], 2.0) + Pow(vec_speed[1], 2.0));
		survivor_num = GetSurvivorCount(true, false);
		
		
		// 冲锋时，将 vel 三方向置 0.0，并记录冲锋时间戳
		if (buttons & IN_ATTACK)
		{
			//charge_interval[client] = GetGameTime();
			#if (DEBUG)
				PrintToChatAll("冲锋重置三方向为0");
			#endif	
			vel[0] = vel[1] = vel[2] = 0.0;
		}
		
		


		// 建立在距离小于冲锋限制距离，有视野且生还者有效的情况下
		if (closet_survivor_distance < g_hChargeDist.IntValue)
		{
			if (has_sight && IsValidSurvivor(target) && !IsClientIncapped(target) && !IsClientPinned(target) && !IsInChargeDuration(client))
			{
				// 目标没有正在看着自身（被控不算看着自身），自身可以冲锋且血量大于限制血量，阻止冲锋，对目标挥拳
				if (GetClientHealth(client) >= g_hChargerMeleeDamage.IntValue && !Is_Target_Watching_Attacker(client, target, g_hAimOffset.IntValue))
				{
					if ((buttons &= ~IN_ATTACK) )
					{
						BlockCharge(client, 1);
					}
					// 查找冲锋范围内是否有其他正在看着自身的玩家
					for (int i = 0; i < ranged_index[client]; i++)
					{
						if (ranged_client[client][i] != target && !IsClientPinned(ranged_client[client][i]) && Is_Target_Watching_Attacker(client, ranged_client[client][i], g_hAimOffset.IntValue) && !Is_InGetUp_Or_Incapped(ranged_client[client][i]) && IsValidEntity(ability) && GetEntProp(ability, Prop_Send, "m_isCharging") != 1 )
						{
							SetCharge(client, 1);
							float new_target_pos[3] = {0.0};
							GetClientAbsOrigin(ranged_client[client][i], new_target_pos);
							MakeVectorFromPoints(self_pos, new_target_pos, new_target_pos);
							GetVectorAngles(new_target_pos, new_target_pos);
							TeleportEntity(client, NULL_VECTOR, new_target_pos, NULL_VECTOR);
							buttons |= IN_ATTACK2;
							buttons |= IN_ATTACK;
							return Plugin_Changed;
						}
					}
				}
				// 目标可能正在看着自身，自身可以冲锋，目标没有拿着近战，且不在倒地或起身状态时则直接冲锋，目标拿着近战，则转到 OnChooseVictim 处理，转移新目标或继续挥拳
				if (!Client_MeleeCheck(target) && !Is_InGetUp_Or_Incapped(target)  && IsValidEntity(ability) && GetEntProp(ability, Prop_Send, "m_isCharging") != 1 )
				{
					SetCharge(client , 2);
					buttons |= IN_ATTACK2;
					buttons |= IN_ATTACK;
					return Plugin_Changed;
				}
				else if (Is_InGetUp_Or_Incapped(target) && (buttons &= ~IN_ATTACK))
				{
					BlockCharge(client, 2);
					buttons |= IN_ATTACK2;
				}
			}
			// 自身血量大于冲锋限制血量，且目标是被控的人时，检测冲锋范围内是否有其他人（可能拿着近战），有则对其冲锋，自身血量小于冲锋限制血量，对着被控的人冲锋
			else if (has_sight && IsValidSurvivor(target) && IsClientPinned(target) && !IsInChargeDuration(client))
			{
				if (GetClientHealth(client) > g_hChargerMeleeDamage.IntValue)
				{
					if ((buttons &= ~IN_ATTACK))
					{
						BlockCharge(client, 3);
					}
					for (int i = 0; i < ranged_index[client]; i++)
					{
						// 循环时，由于 ranged_index 增加时，数组中一定为有效生还者，故无需判断是否是有效生还者
						if (!IsClientPinned(ranged_client[client][i]) && Is_Target_Watching_Attacker(client, ranged_client[client][i], g_hAimOffset.IntValue) && !Is_InGetUp_Or_Incapped(ranged_client[client][i]) && IsValidEntity(ability) && GetEntProp(ability, Prop_Send, "m_isCharging") != 1)
						{
							SetCharge(client, 3);
							float new_target_pos[3] = {0.0};
							GetClientAbsOrigin(ranged_client[client][i], new_target_pos);
							MakeVectorFromPoints(self_pos, new_target_pos, new_target_pos);
							GetVectorAngles(new_target_pos, new_target_pos);
							TeleportEntity(client, NULL_VECTOR, new_target_pos, NULL_VECTOR);
							buttons |= IN_ATTACK2;
							buttons |= IN_ATTACK;
							return Plugin_Changed;
						}
					}
				}
				// 被控的人在起身或者倒地状态，阻止冲锋
				else if (Is_InGetUp_Or_Incapped(target) && (buttons &= ~IN_ATTACK))
				{
					BlockCharge(client, 4);
					buttons |= IN_ATTACK2;
				}
			}
		}
		else if (!IsInChargeDuration(client) && (buttons &= ~IN_ATTACK) && cur_speed > 100.0)
		{
			//PrintToChatAll("距离在可冲锋范围外，且此次操作不是冲锋按键，封锁冲锋功能" );
			BlockCharge(client, 5);
			buttons |= IN_ATTACK2;
		}
		// 连跳，并阻止冲锋，可以攻击被控的人的时，将最小距离置 0，连跳追上被控的人
		//int min_dist = can_attack_pinned[client] ? 0 : g_hChargeDist.IntValue;
		#if (DEBUG)
			/*float fsurvivorPos[3], fChargerPos[3];
			if(IsValidClient(target) && IsValidClient(client))
			{
				GetClientEyePosition(target, fsurvivorPos);
				GetClientEyePosition(client, fChargerPos);
				fsurvivorPos[2] -= 60.0;
				fChargerPos[2] -= 60.0;
				Address padr = L4D_GetNearestNavArea(fsurvivorPos,300);
				Address padr2 = L4D_GetNearestNavArea(fChargerPos,300);
				PrintToChatAll("target:%N has_sight:%d cur_speed:%f distance:%d path:%d" , target, has_sight, cur_speed, closet_survivor_distance,L4D2_NavAreaBuildPath(padr, padr2, 9999.0, 3, false));
			}	*/		
			//PrintToChatAll("cancharger:%d cantime:%d ", charger_cancharge[client], GetChargerTime(client));
			//PrintToChatAll("target:%N has_sight:%d cur_speed:%f distance:%d cantime:%d" , target, has_sight, cur_speed, closet_survivor_distance, GetChargerTime(client));
		#endif	
		if (has_sight && g_hAllowBhop.BoolValue && 0 < closet_survivor_distance < 10000 && cur_speed > 175.0 && IsValidSurvivor(target))
		{
			if (flags & FL_ONGROUND)
			{
				GetClientAbsOrigin(target, target_pos);
				vel_buffer = CalculateVel(self_pos, target_pos, g_hBhopSpeed.FloatValue);
				buttons |= IN_JUMP;
				buttons |= IN_DUCK;
				if (Do_Bhop(client, buttons, vel_buffer))
				{
					return Plugin_Changed;
				}
			}
		}
		if (has_sight && cur_speed <= 50.0 && closet_survivor_distance>=50 &&!IsPinningSomeone(client) && IsValidClient(target))
		{
			buttons |= IN_FORWARD;
			buttons |= IN_ATTACK2;
			buttons |= IN_JUMP;
			float new_target_pos[3] = {0.0}, vec[3] = {0.0};
			GetClientAbsOrigin(target, new_target_pos);
			MakeVectorFromPoints(self_pos, new_target_pos, new_target_pos);
			vec = new_target_pos;
			GetVectorAngles(new_target_pos, new_target_pos);
			NormalizeVector(vec, vec);
			ScaleVector(vec, 250.0);
			TeleportEntity(client, NULL_VECTOR, new_target_pos, vec);
			#if (DEBUG)
				PrintToChatAll("target:%N 傻站不动没让他向前跳打",client);
			#endif
			return Plugin_Changed;
		}
		// 梯子上，阻止连跳
		if (GetEntityMoveType(client) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	return Plugin_Continue;
}
// 目标选择
public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	int new_target = 0;
	if (IsCharger(specialInfected) && !IsPinningSomeone(specialInfected))
	{
		float self_pos[3] = {0.0}, target_pos[3] = {0.0};
		GetClientEyePosition(specialInfected, self_pos);
		// 获取在冲锋范围内的目标
		FindRangedClients(specialInfected, g_hChargeDist.FloatValue + 100.0);
		if (IsValidSurvivor(curTarget) && IsPlayerAlive(curTarget))
		{
			GetClientEyePosition(curTarget, target_pos);
			for (int i = 0; i < ranged_index[specialInfected]; i++)
			{
				// 1. 范围内有人被控且自身血量大于限制血量，则先去对被控的人挥拳
				if (GetClientHealth(specialInfected) > g_hChargerMeleeDamage.IntValue && !IsInChargeDuration(specialInfected) && (GetEntPropEnt(ranged_client[specialInfected][i], Prop_Send, "m_pounceAttacker") > 0 || GetEntPropEnt(ranged_client[specialInfected][i], Prop_Send, "m_tongueOwner") > 0 || GetEntPropEnt(ranged_client[specialInfected][i], Prop_Send, "m_jockeyAttacker") > 0))
				{
					can_attack_pinned[specialInfected] = true;
					curTarget = ranged_client[specialInfected][i];
					#if (DEBUG)
						PrintToChatAll("范围内有人被控且自身血量大于限制血量，则先去对被控的 %N 挥拳", curTarget);
					#endif	
					BlockCharge(specialInfected, 6);
					return Plugin_Changed;
				}
				can_attack_pinned[specialInfected] = false;
			}
			if (!IsClientIncapped(curTarget) && !IsClientPinned(curTarget))
			{
				// 允许近战回避且目标正拿着近战武器且血量高于冲锋限制血量，随机获取一个没有拿着近战武器且可视的目标，转移目标
				if (g_hAllowMeleeAvoid.BoolValue && Client_MeleeCheck(curTarget) && GetVectorDistance(self_pos, target_pos) >= g_hChargeDist.FloatValue && GetClientHealth(specialInfected) >= g_hChargerMeleeDamage.IntValue)
				{
					int melee_num = 0;
					Get_MeleeNum(melee_num, new_target);
					if (Client_MeleeCheck(curTarget) && melee_num < survivor_num && IsValidSurvivor(new_target) && Player_IsVisible_To(specialInfected, new_target))
					{
						curTarget = new_target;
						#if (DEBUG)
							PrintToChatAll("允许近战回避且目标正拿着近战武器且血量高于冲锋限制血量，随机获取一个没有拿着近战武器且可视的目标，转移目标到%N", curTarget);
						#endif	
						return Plugin_Changed;
					}
				}
				// 不满足近战回避距离限制或血量要求的牛，阻止其冲锋，令其对手持近战的目标挥拳
				else if (g_hAllowMeleeAvoid.BoolValue && Client_MeleeCheck(curTarget) && !IsInChargeDuration(specialInfected) && (GetVectorDistance(self_pos, target_pos) < g_hChargeDist.FloatValue || GetClientHealth(specialInfected) >= g_hChargerMeleeDamage.IntValue))
				{
					#if (DEBUG)
						PrintToChatAll(" 不满足近战回避距离限制或血量要求的牛，阻止其冲锋，令其对手持近战的目标挥拳");
					#endif		
					BlockCharge(curTarget, 7);
				}
				// 目标选择
				switch (g_hChargerTarget.IntValue)
				{
					case 2:
					{
						new_target = GetClosetMobileSurvivor(specialInfected);
						if (IsValidSurvivor(new_target))
						{
							curTarget = new_target;
							return Plugin_Changed;
						}
					}
					case 3:
					{
						new_target = GetCrowdPlace(survivor_num);
						if (IsValidSurvivor(new_target))
						{
							curTarget = new_target;
							return Plugin_Changed;
						}
					}
				}
			}
		}
		else if (!IsValidSurvivor(curTarget))
		{
			new_target = GetClosetMobileSurvivor(specialInfected);
			if (IsValidSurvivor(new_target))
			{
				curTarget = new_target;
				#if (DEBUG)
					PrintToChatAll("%N 因为无效生还者更换攻击目标 为", specialInfected, curTarget);
				#endif
				return Plugin_Changed;
			}
		}
	}
	if (!can_attack_pinned[specialInfected] && IsCharger(specialInfected) && IsValidSurvivor(curTarget) && (IsClientIncapped(curTarget) || IsClientPinned(curTarget)))
	{
		new_target = GetClosetMobileSurvivor(specialInfected);
		if (IsValidSurvivor(new_target))
		{
			curTarget = new_target;
			#if (DEBUG)
				PrintToChatAll("%N 因为原目标倒地或者被控且不能攻击被控目标情况下，更换攻击目标 为", specialInfected, curTarget);
			#endif
			return Plugin_Changed;
		}
	}
	#if (DEBUG)
		PrintToChatAll("%N 没有达成任何会换攻击目标条件，攻击目标依旧为 %N", specialInfected, curTarget);
	#endif
	return Plugin_Continue;
}
void Get_MeleeNum(int &melee_num, int &new_target)
{
	int active_weapon = -1;
	char weapon_name[48] = '\0';
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR) && IsPlayerAlive(client) && !IsClientIncapped(client) && !IsClientPinned(client))
		{
			active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(active_weapon) && IsValidEdict(active_weapon))
			{
				GetEdictClassname(active_weapon, weapon_name, sizeof(weapon_name));
				if (strcmp(weapon_name[7], "melee") == 0 || strcmp(weapon_name, "weapon_chainsaw") == 0)
				{
					melee_num += 1;
				}
				else
				{
					new_target = client;
				}
			}
		}
	}
}
bool Client_MeleeCheck(int client)
{
	int active_weapon = -1;
	char weapon_name[48] = '\0';
	if (IsValidSurvivor(client) && IsPlayerAlive(client) && !IsClientIncapped(client) && !IsClientPinned(client))
	{
		active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (IsValidEntity(active_weapon) && IsValidEdict(active_weapon))
		{
			GetEdictClassname(active_weapon, weapon_name, sizeof(weapon_name));
			if (strcmp(weapon_name[7], "melee") == 0 || strcmp(weapon_name, "weapon_chainsaw") == 0)
			{
				return true;
			}
		}
	}
	return false;
}
// From：http://github.com/PaimonQwQ/L4D2-Plugins/smartspitter.sp
int GetCrowdPlace(int num_survivors)
{
	if (num_survivors > 0)
	{
		int index = 0, iTarget = 0;
		int[] iSurvivors = new int[num_survivors];
		float fDistance[MAXPLAYERS + 1] = -1.0;
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR))
			{
				iSurvivors[index++] = client;
			}
		}
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR))
			{
				fDistance[client] = 0.0;
				float fClientPos[3] = 0.0;
				GetClientAbsOrigin(client, fClientPos);
				for (int i = 0; i < num_survivors; i++)
				{
					float fPos[3] = 0.0;
					GetClientAbsOrigin(iSurvivors[i], fPos);
					fDistance[client] += GetVectorDistance(fClientPos, fPos, true);
				}
			}
		}
		for (int i = 0; i < num_survivors; i++)
		{
			if (fDistance[iSurvivors[iTarget]] > fDistance[iSurvivors[i]])
			{
				if (fDistance[iSurvivors[i]] != -1.0)
				{
					iTarget = i;
				}
			}
		}
		return iSurvivors[iTarget];
	}
	else
	{
		return -1;
	}
}

// 方法，是否是 AI 牛
bool IsCharger(int client)
{
	return view_as<bool>(GetInfectedClass(client) == view_as<int>(ZC_CHARGER) && IsFakeClient(client));
}

// 判断目标是否处于正在起身或正在倒地状态
bool Is_InGetUp_Or_Incapped(int client)
{
	int character_index = IdentifySurvivor(client);
	if (character_index != view_as<int>(SC_INVALID))
	{
		int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
		if (sequence == GetUpAnimations[character_index][ID_HUNTER] || sequence == GetUpAnimations[character_index][ID_CHARGER] || sequence == GetUpAnimations[character_index][ID_CHARGER_WALL] || sequence == GetUpAnimations[character_index][ID_CHARGER_GROUND])
		{
			return true;
		}
		else if (sequence == IncappAnimations[character_index][ID_SINGLE_PISTOL] || sequence == IncappAnimations[character_index][ID_DUAL_PISTOLS])
		{
			return true;
		}
		return false;
	}
	return false;
}

// 阻止牛冲锋
void BlockCharge(int client, int reason)
{
	if (GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0)
	{
		return;
	}
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (IsValidEntity(ability) && GetEntProp(ability, Prop_Send, "m_isCharging") != 1 && (GetEntPropFloat(ability, Prop_Send, "m_timestamp") < GetGameTime()))
	{
			SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + 0.1);
			#if (DEBUG)
				PrintToChatAll("牛牛%N 被%d阻止冲锋" , client, reason);
			#endif		
	}
	
}

stock bool GetChargerTime(int client)
{
	if (GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0)
	{
		return false;
	}
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (IsValidEntity(ability))
	{
		return GetEntPropFloat(ability, Prop_Send, "m_timestamp") < GetGameTime();
	}
	return false;
}

// 让牛冲锋
void SetCharge(int client, int reason)
{
	if (GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0)
	{
		return;
	}
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (IsValidEntity(ability) && GetEntProp(ability, Prop_Send, "m_isCharging") != 1  && GetEntPropFloat(ability, Prop_Send, "m_timestamp") < GetGameTime() + 1.0)
	{
		SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() - 0.5);
		#if (DEBUG)
			PrintToChatAll("牛牛%N 被%d设置为可冲锋", client, reason);
		#endif
	}
	
}

stock bool IsPinningSomeone(int client)
{
	bool bIsPinning = false;
	if (IsCharger(client))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0) bIsPinning = true;
	}
	return bIsPinning;
}

// 是否在冲锋间隔
bool IsInChargeDuration(int client)
{
	//return view_as<bool>((GetGameTime() - charge_interval[client]) < g_hChargeInterval.FloatValue);
	return !charger_cancharge[client];
}
// 查找范围内可视的有效的（未倒地，未死亡，未被控）的玩家
int FindRangedClients(int client, float range)
{
	int index = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == view_as<int>(TEAM_SURVIVOR) && IsPlayerAlive(i) && !IsClientIncapped(i))
		{
			float self_eye_pos[3] = {0.0}, target_eye_pos[3] = {0.0};
			GetClientEyePosition(client, self_eye_pos);
			GetClientEyePosition(i, target_eye_pos);
			if (GetVectorDistance(self_eye_pos, target_eye_pos) <= range)
			{
				Handle hTrace = TR_TraceRayFilterEx(self_eye_pos, target_eye_pos, MASK_VISIBLE, RayType_EndPoint, TR_RayFilter, client);
				if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == i)
				{
					ranged_client[client][index] = i;
					index += 1;
				}
				delete hTrace;
				hTrace = INVALID_HANDLE;
			}
		}
	}
	ranged_index[client] = index;
	return index;
}
// 牛连跳
bool Do_Bhop(int client, int &buttons, float vec[3])
{
	if (buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
	{
		if (ClientPush(client, vec))
		{
			return true;
		}
	}
	return false;
}
bool ClientPush(int client, float vec[3])
{
	float curvel[3] = {0.0};
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", curvel);
	AddVectors(curvel, vec, curvel);
	if (GetVectorLength(curvel) <= 250.0)
	{
		NormalizeVector(curvel, curvel);
		ScaleVector(curvel, 251.0);
	}
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, curvel);
	return true;
}
// 计算与目标之间的向量
float[] CalculateVel(float self_pos[3], float target_pos[3], float force)
{
	float vecbuffer[3] = {0.0};
	SubtractVectors(target_pos, self_pos, vecbuffer);
	NormalizeVector(vecbuffer, vecbuffer);
	ScaleVector(vecbuffer, force);
	return vecbuffer;
}

// 目标与牛的 x 距离是否在限制内
bool Is_Target_Watching_Attacker(int client, int target, int offset)
{
	if (IsValidInfected(client) && IsValidSurvivor(target) && IsPlayerAlive(client) && IsPlayerAlive(target) && !IsClientIncapped(target) && !IsClientPinned(target) && !Is_InGetUp_Or_Incapped(target))
	{
		int aim_offset = RoundToNearest(Get_Player_Aim_Offset(target, client));
		if (aim_offset <= offset)
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	return false;
}
float Get_Player_Aim_Offset(int client, int target)
{
	if (IsValidClient(client) && IsValidClient(target) && IsPlayerAlive(client) && IsPlayerAlive(target))
	{
		float self_pos[3] = {0.0}, target_pos[3] = {0.0}, aim_vector[3] = {0.0}, dir_vector[3] = {0.0}, result_angle = 0.0;
		GetClientEyeAngles(client, aim_vector);
		aim_vector[0] = aim_vector[2] = 0.0;
		GetAngleVectors(aim_vector, aim_vector, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(aim_vector, aim_vector);
		GetClientAbsOrigin(target, target_pos);
		GetClientAbsOrigin(client, self_pos);
		self_pos[2] = target_pos[2] = 0.0;
		MakeVectorFromPoints(self_pos, target_pos, dir_vector);
		NormalizeVector(dir_vector, dir_vector);
		result_angle = RadToDeg(ArcCosine(GetVectorDotProduct(aim_vector, dir_vector)));
		return result_angle;
	}
	return -1.0;
}
