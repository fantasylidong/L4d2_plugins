/*
 * @Author:             派蒙
 * @Last Modified by:   派蒙
 * @Create Date:        2022-03-23 12:42:32
 * @Last Modified time: 2022-06-19 17:51:44
 * @Github:             http://github.com/PaimonQwQ
 */

#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <sdktools>
#include <l4d2tools>
#include <sourcemod>
#include <left4dhooks>

#define MAXSIZE 33
#define VERSION "2022.06.19"

public Plugin myinfo =
{
    name = "AngelCore",
    author = "我是派蒙啊",
    description = "AngelServer的启动核心",
    version = VERSION,
    url = "http://github.com/PaimonQwQ/L4D2-Plugins/AngelBeats"
};

enum Msgs
{
    Msg_Connecting = 0,
    Msg_Connected,
    Msg_DisConnected,
    Msg_PlayerSuicide,
    Msg_PlayerJoinFalse,
    Msg_HowToJoin,
    Msg_ReachedLimit,
};//Message enums for message array(as an index)

char
    g_sFirstMap[64],
    g_sMessages[][] =
    {
        "[{olive}天使{default}] 提醒您：{blue}%N {default}将加入战线",
        "[{olive}天使{default}] 提醒您：{blue}%N {default}加入了战线",
        "[{olive}天使{default}] 提醒您：{blue}%N {default}离开了战线",
        "[{olive}天使{default}] 提醒您：{blue}%N {default}心满意足的消失了",
        "[{olive}天使{default}] 提醒您：{default}当前无生还Bot，请在开局前使用 {orange}!jg",
        "[{olive}天使{default}] 提醒您：{default}使用 {orange}!jg {default}加入生还",
        "[{olive}天使{default}] 提醒您：{default}生还数量已达上限 {orange}%d {default}，使用 {orange}!vote {default}修改生还上限",
    };//Messages for player to show

bool
    g_bIsGameStart;

float
    g_fLastDisconnectTime;

ConVar
    g_hAngelSurvivorLimit,
    g_hServerMaxSurvivor;

//插件入口
public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
    HookEvent("player_death", Event_PlayerDead, EventHookMode_Pre);
    HookEvent("mission_lost", Event_MissionLost, EventHookMode_Pre);
    HookEvent("finale_win", Event_ResetSurvivors, EventHookMode_Pre);
    HookEvent("map_transition", Event_ResetSurvivors, EventHookMode_Pre);
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
    HookEvent("player_incapacitated", Event_PlayerIncapped, EventHookMode_Pre);

    g_hServerMaxSurvivor = FindConVar("survivor_limit");
    g_hAngelSurvivorLimit = CreateConVar("angel_survivor_limit", "4", "生还人数上限");

    g_hAngelSurvivorLimit.AddChangeHook(CVarEvent_OnAngelSurvivorChanged);
    FindConVar("sb_all_bot_game").AddChangeHook(CVarEvent_OnBotGameChanged);

    g_hServerMaxSurvivor.SetBounds(ConVarBound_Lower, true, 1.0);
    g_hServerMaxSurvivor.SetBounds(ConVarBound_Upper, true, 4.0);

    g_hAngelSurvivorLimit.SetBounds(ConVarBound_Lower, true, 1.0);
    g_hAngelSurvivorLimit.SetBounds(ConVarBound_Upper, true, 28.0);

    RegConsoleCmd("sm_ammo", Cmd_GiveAmmo, "Give survivor ammo");

    RegConsoleCmd("sm_jg", Cmd_JoinSurvivor, "Turn player to survivor");
    RegConsoleCmd("sm_join", Cmd_JoinSurvivor, "Turn player to survivor");

    RegConsoleCmd("sm_s", Cmd_JoinSpectator, "Turn player to spectator");
    RegConsoleCmd("sm_afk", Cmd_JoinSpectator, "Turn player to spectator");
    RegConsoleCmd("sm_spec", Cmd_JoinSpectator, "Turn player to spectator");
    RegConsoleCmd("sm_away", Cmd_JoinSpectator, "Turn player to spectator");

    RegConsoleCmd("sm_zs", Cmd_PlayerSuicide, "Player suicided");
    RegConsoleCmd("sm_kill", Cmd_PlayerSuicide, "Player suicided");
}

//地图加载
public void OnMapStart()
{
    RestoreHealth();
    ResetInventory();
    SetGodMode(true);

    g_bIsGameStart = false;
    FindConVar("mp_gamemode").SetString("coop");

    if(L4D_IsFirstMapInScenario())
        GetCurrentMap(g_sFirstMap, sizeof(g_sFirstMap));
}

//玩家正在连接
public void OnClientConnected(int client)
{
    if (IsFakeClient(client))
        return;

    CPrintToChatAll(g_sMessages[Msg_Connecting], client);
}

//玩家进入服务器
public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client))
        return;

    int surPlayerCount = GetSurvivorPlayerCount();
    g_hServerMaxSurvivor.SetInt(surPlayerCount ? surPlayerCount : 1);

    CPrintToChatAll(g_sMessages[Msg_Connected], client);
}

//玩家进入服务器(提示用)
public void OnClientPostAdminCheck(int client)
{
    if (IsFakeClient(client))
        return;

    CPrintToChat(client, g_sMessages[Msg_HowToJoin]);
}

//玩家断开连接
public void OnClientDisconnect(int client)
{
    if (!IsValidClient(client))
        return;

    if (IsClientInGame(client) && IsFakeClient(client))
        return;

    float currenttime = GetGameTime();

    if (IsClientInGame(client))
        CPrintToChatAll(g_sMessages[Msg_DisConnected], client);

    if (g_fLastDisconnectTime == currenttime)
    {
        g_hServerMaxSurvivor.SetInt(GetSurvivorPlayerCount());
        return;
    }
}

//对抗计分面板出现前
public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
    FindConVar("mp_gamemode").SetString("realism");

    return Plugin_Handled;
}

//玩家离开安全屋
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    SetGodMode(false);
    g_bIsGameStart = true;
    //重置数量为玩家生还数量
    g_hServerMaxSurvivor.SetInt(GetSurvivorPlayerCount());
    CreateTimer(0.1, Timer_AutoGive, 0, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Continue;
}

//回合开始事件
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    SetGodMode(true);
    FindConVar("mp_gamemode").SetString("coop");
    CreateTimer(1.0, Timer_DelayedOnRoundStart, 0, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Continue;
}

//玩家死亡事件
public Action Event_PlayerDead(Event event, const char[] name, bool dont_broadcast)
{
    if (GetAliveSurvivorCount() == 0)
    {
        g_bIsGameStart = false;
        FindConVar("mp_gamemode").SetString("realism");
        SetGodMode(true);
    }

    return Plugin_Continue;
}

//关卡结束
public Action Event_MissionLost(Event event, const char[] name, bool dont_broadcast)
{
    FindConVar("mp_gamemode").SetString("realism");
    if(!IsAllSurvivorPinned())
        return Plugin_Continue;

    for(int i = 1; i < MaxClients; i++)
        if(IsSurvivor(i) && (IsPlayerIncap(i) || IsSurvivorPinned(i)))
            ForcePlayerSuicide(i);

    return Plugin_Continue;
}

//重置玩家信息
public Action Event_ResetSurvivors(Event event, const char[] name, bool dontBroadcast)
{
    RestoreHealth();
    ResetInventory();
    g_bIsGameStart = false;
    FindConVar("mp_gamemode").SetString("realism");

    if(L4D_IsMissionFinalMap())
    {
        char tarMap[64], mapBuf[8];
        GetCurrentMap(tarMap, sizeof(tarMap));
        if(IsCharNumeric(tarMap[1]))
        {
            int level = -1;
            mapBuf[0] = tarMap[1];
            mapBuf[1] = IsCharNumeric(tarMap[2]) ? tarMap[2] : '\0';
            level = StringToInt(mapBuf);
            level = level >= 14 ? 1 : level + 1;
            Format(mapBuf, sizeof(mapBuf), "c%dm1_", level);

            if(FindMap(mapBuf, tarMap, sizeof(tarMap)) != FindMap_NotFound && IsMapValid(tarMap))
                ServerCommand("changelevel %s", tarMap);
            else ServerCommand("changelevel %s", g_sFirstMap);
        }
        else ServerCommand("changelevel %s", g_sFirstMap);
    }

    return Plugin_Continue;
}

//玩家均被制服时
public Action Event_PlayerIncapped(Event event, const char[] name, bool dontBroadcast)
{
    if(!IsAllSurvivorPinned())
        return Plugin_Continue;

    for(int i = 1; i < MaxClients; i++)
        if(IsSurvivor(i) && (IsPlayerIncap(i) || IsSurvivorPinned(i)))
            //直接处死加快重启
            ForcePlayerSuicide(i);

    return Plugin_Continue;
}

//玩家离开服务器
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    SetEventBroadcast(event, false);
    dontBroadcast = true;

    return Plugin_Handled;
}

//Bots事件
public void CVarEvent_OnBotGameChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if(StringToInt(newValue) != 1)
        convar.SetInt(1);
}

//生还人数上限改变事件
public void CVarEvent_OnAngelSurvivorChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_hServerMaxSurvivor.SetBounds(ConVarBound_Upper, true, convar.FloatValue);
}

//给予玩家子弹
public Action Cmd_GiveAmmo(int client, any args)
{
    if (IsValidClient(client) && IsSurvivor(client))
        BypassAndExecuteCommand(client, "give", "ammo");

    return Plugin_Handled;
}

//加入生还
public Action Cmd_JoinSurvivor(int client, any args)
{
    if (IsValidClient(client) && !IsSurvivor(client) && !IsFakeClient(client))
    {
        if(IsSurvivorTeamFull() && g_bIsGameStart)
        {
            CPrintToChat(client, g_sMessages[Msg_PlayerJoinFalse]);
            return Plugin_Handled;
        }
        float survivors = 4.0;
        //获取生还数量ConVar范围上限
        g_hServerMaxSurvivor.GetBounds(ConVarBound_Upper, survivors);
        int surPlayerCount = GetSurvivorPlayerCount();
        //设置生还数量为：如果当前数量>=范围上限，设置为范围上限；否则，
        //如果生还队伍已满，设置为生还玩家数量+1；否则，如果生还玩家数量不为0，
        //设置为生还玩家数量，否则设置为1
        //(p.s.这逻辑是不太好讲，但是3元运算符写着真爽，下次还写ww)
        g_hServerMaxSurvivor.SetInt(g_hServerMaxSurvivor.FloatValue >= survivors ?
            view_as<int>(survivors) : IsSurvivorTeamFull() ? surPlayerCount + 1 :
            surPlayerCount ? surPlayerCount : 1);
        //若执行完上述语句后，没有被playermanager插件自动添加假人
        //说明队伍已满，不再继续执行加入指令，以防炸服
        if(IsSurvivorTeamFull())
        {
            CPrintToChat(client, g_sMessages[Msg_ReachedLimit], GetSurvivorCount());
            return Plugin_Handled;
        }
        ClientCommand(client, "jointeam survivor");
    }
    CreateTimer(0.1, Timer_NoWander, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Handled;
}

//进入旁观（被控禁止旁观）
public Action Cmd_JoinSpectator(int client, any args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    if (!IsSurvivorPinned(client))
    {
        ChangeClientTeam(client, TEAM_SPECTATOR);
        //如果没有开始游戏
        if(!g_bIsGameStart)
        {
            int surPlayerCount = GetSurvivorPlayerCount();
            //设置生还数量为：如果生还玩家数量不为0，设置为生还玩家数量，否则设置为1
            g_hServerMaxSurvivor.SetInt(surPlayerCount ? surPlayerCount : 1);
        }
    }

    return Plugin_Handled;
}

//玩家自杀
public Action Cmd_PlayerSuicide(int client, any args)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return Plugin_Handled;

    CPrintToChatAll(g_sMessages[Msg_PlayerSuicide], client);
    ForcePlayerSuicide(client);

    return Plugin_Handled;
}

//开局重置
public Action Timer_DelayedOnRoundStart(Handle timer)
{
    RestoreHealth();
    ResetInventory();
    g_bIsGameStart = false;
}



//自动给予药品
public Action Timer_AutoGive(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
        if (IsSurvivor(client) && !IsFakeClient(client))
        {
            if (!IsPlayerAlive(client)) L4D_RespawnPlayer(client);
            if(GetPlayerWeaponSlot(client, 4) == -1)
                BypassAndExecuteCommand(client, "give", "pain_pills");
            if(GetPlayerHealth(client) < 100)
                BypassAndExecuteCommand(client, "give", "health");
            L4D_SetPlayerTempHealth(client, 0);
            L4D_SetPlayerReviveCount(client, 0);
            L4D_SetPlayerThirdStrikeState(client, false);
            L4D_SetPlayerIsGoingToDie(client, false);
        }

    return Plugin_Continue;
}

//取消玩家闲置
public Action Timer_NoWander(Handle timer, int client)
{
    if(!IsSurvivor(client))
        return Plugin_Continue;

    BypassAndExecuteCommand(client, "sb_takecontrol" ,"");

    return Plugin_Stop;
}

//重置玩家血量
void RestoreHealth()
{
    for (int client = 1; client <= MaxClients; client++)
        if (IsSurvivor(client))
        {
            if(GetPlayerHealth(client) < 100)
                BypassAndExecuteCommand(client, "give", "health");
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
            SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
            SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
        }
}

//设置玩家状态
void SetGodMode(bool status)
{
    ConVar god = FindConVar("god");
    ConVar ammo = FindConVar("sv_infinite_ammo");

    god.Flags &= ~FCVAR_NOTIFY;
    god.SetBool(status);
    god.Flags |= FCVAR_NOTIFY;

    ammo.Flags &= ~FCVAR_NOTIFY;
    ammo.SetBool(status);
    ammo.Flags |= FCVAR_NOTIFY;
}

//重置玩家背包
void ResetInventory()
{
    for (int client = 1; client <= MaxClients; client++)
        if (IsSurvivor(client))
        {
            for (int i = 0; i < 5; i++)
                DeleteInventoryItem(client, i);

            BypassAndExecuteCommand(client, "give", "pistol");
        }
}

//删除背包物品
void DeleteInventoryItem(int client, int slot)
{
    if (!IsValidClient(client))
        return;

    int item = GetPlayerWeaponSlot(client, slot);
    if (item > 0)
        RemovePlayerItem(client, item);
}

