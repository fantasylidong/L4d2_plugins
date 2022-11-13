/*
 * @Author:             派蒙
 * @Last Modified by:   派蒙
 * @Create Date:        2022-03-24 17:00:57
 * @Last Modified time: 2022-07-21 21:07:18
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
#define VERSION "2022.07.18"

public Plugin myinfo =
{
    name = "AngelDirector",
    author = "我是派蒙啊",
    description = "AngelServer的刷特导演",
    version = VERSION,
    url = "http://github.com/PaimonQwQ/L4D2-Plugins/AngelBeats"
};

bool
    g_bIsGameStart,
    g_bIsSpawnCounting;

float
    g_fLastFlowPercent;

ConVar
    //模式开关
    g_hAngelVersus,
    //导演刷特限制
    g_hHunterLimit,
    g_hBoomerLimit,
    g_hSmokerLimit,
    g_hJockeyLimit,
    g_hChargerLimit,
    g_hSpitterLimit,
    //插件刷特限制
    g_hSICountLimit,
    g_hAngelHardMode,
    g_hAngelSpawnFlow,
    g_hAngelSpawnMode,
    g_hAngelDelayDistance,
    g_hAngelSpawnInterval,
    g_hAngelDirectorDebug,
    g_hAngelSIAttackIntent,
    g_hAngelJockeyLimit,
    g_hAngelHunterLimit,
    g_hAngelSpitterLimit,
    g_hAngelBoomerLimit,
    g_hAngelSmokerLimit,
    g_hAngelChargerLimit;

//插件入口
public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("witch_killed", Event_WitchKilled);
    HookEvent("mission_lost", Event_MissionLost);
    HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_Pre);
    HookEvent("player_team", Event_PlayerChangeTeam, EventHookMode_Pre);

    g_hHunterLimit = FindConVar("z_hunter_limit");
    g_hBoomerLimit = FindConVar("z_boomer_limit");
    g_hSmokerLimit = FindConVar("z_smoker_limit");
    g_hJockeyLimit = FindConVar("z_jockey_limit");
    g_hChargerLimit = FindConVar("z_charger_limit");
    g_hSpitterLimit = FindConVar("z_spitter_limit");

    CreateConVar("angel_infected_limit", "6", "特感上限显示");
    g_hAngelVersus = CreateConVar("angel_versus", "0", "Angel对抗开关");
    g_hSICountLimit = CreateConVar("l4d_infected_limit", "31", "特感数量上限");
    g_hAngelDirectorDebug = CreateConVar("angel_director_debug", "0", "输出测试信息");

    //高难度下特感会刷的很散
    g_hAngelHardMode = CreateConVar("angel_director_hard", "1", "高难度模式");
    //0=Disable, 1=Smoker, 2=Boomer, 3=Hunter, //4=Spitter, 5=Jockey, 6=Charger
    g_hAngelSpawnMode = CreateConVar("angel_director_spawner", "3", "刷特模式");
    //路程刷特方式：若 当前生还最高路程 - 上次刷特特感最高路程 >= 权重 * (40 - 当前刷特秒数) / 20 时，开始计时
    g_hAngelSpawnFlow = CreateConVar("angel_spawn_flow", "3.2", "生还进程影响刷特的权重");
    //0.0表示玩家灰常冷静(逛gai中)，1.0表示玩家鸭梨山大，
    //当玩家状态低于特感进攻意图时，唤醒刷特时钟，开始计时
    g_hAngelSIAttackIntent = CreateConVar("angel_director_intent", "0.48", "生还状态影响的特感刷新强度(进攻意图)");

    g_hAngelSpawnInterval = CreateConVar("angel_special_respawn_interval", "16", "复活时间限制");
    g_hAngelDelayDistance = CreateConVar("angel_special_delay_distance", "520", "特感落后传送距离");

    g_hAngelJockeyLimit = CreateConVar("angel_jockey_limit", "1", "Jockey数量限制");
    g_hAngelHunterLimit = CreateConVar("angel_hunter_limit", "1", "Hunter数量限制");
    g_hAngelSpitterLimit = CreateConVar("angel_spitter_limit", "1", "Spitter数量限制");
    g_hAngelBoomerLimit = CreateConVar("angel_boomer_limit", "1", "Boomer数量限制");
    g_hAngelSmokerLimit = CreateConVar("angel_smoker_limit", "1", "Smoker数量限制");
    g_hAngelChargerLimit = CreateConVar("angel_charger_limit", "1", "Charger数量限制");

    //不应该让这个值较低，否则起不到作用
    //太高了也不行，否则有可能一波接一波，打的生还头皮发麻(有人喜欢坐牢XD)
    g_hAngelSIAttackIntent.SetBounds(ConVarBound_Lower, true, 0.20);
    g_hAngelSIAttackIntent.SetBounds(ConVarBound_Upper, true, 0.90);

    g_hSICountLimit.AddChangeHook(CvarEvent_LimitChanged);
    g_hHunterLimit.AddChangeHook(CvarEvent_LimitChanged);
    g_hBoomerLimit.AddChangeHook(CvarEvent_LimitChanged);
    g_hSmokerLimit.AddChangeHook(CvarEvent_LimitChanged);
    g_hJockeyLimit.AddChangeHook(CvarEvent_LimitChanged);
    g_hChargerLimit.AddChangeHook(CvarEvent_LimitChanged);
    g_hSpitterLimit.AddChangeHook(CvarEvent_LimitChanged);

    g_hAngelJockeyLimit.AddChangeHook(CvarEvent_AngelLimitChanged);
    g_hAngelHunterLimit.AddChangeHook(CvarEvent_AngelLimitChanged);
    g_hAngelBoomerLimit.AddChangeHook(CvarEvent_AngelLimitChanged);
    g_hAngelSpitterLimit.AddChangeHook(CvarEvent_AngelLimitChanged);
    g_hAngelSmokerLimit.AddChangeHook(CvarEvent_AngelLimitChanged);
    g_hAngelChargerLimit.AddChangeHook(CvarEvent_AngelLimitChanged);

    RegConsoleCmd("sm_dc", Cmd_DirectorMsg, "Show director-manager information");
    RegConsoleCmd("sm_xx", Cmd_DirectorMsg, "Show director-manager information");
    RegConsoleCmd("sm_mode", Cmd_DirectorMode, "Show director spawn mode");
}

//地图加载
public void OnMapStart()
{
    g_bIsGameStart = false;
    g_bIsSpawnCounting = true;
}

//刷特检测
public void OnGameFrame()
{
    CheckSpawnCounter();
}

//玩家特感进入灵魂状态
public void L4D_OnEnterGhostState(int client)
{
    //Angel对抗或躲猫猫未开启，玩家进入特感灵魂时移动至旁观
    if (!g_hAngelVersus.BoolValue || !FindConVar("z_hunter_limit").BoolValue)
        ChangeClientTeam(client, TEAM_SPECTATOR);

    if(FindConVar("angel_party").IntValue)
        L4D_SetClass(client, FindConVar("angel_party").IntValue);
}

//玩家离开安全屋
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    if(!FindConVar("angel_party").IntValue)
    {
        CPrintToChatAll("[{olive}特感详情{default}]");
        CPrintToChatAll("\tSmoker {blue}%d\t{default}Spitter {blue}%d\t{default}Boomer {blue}%d",
            g_hAngelSmokerLimit.IntValue, g_hAngelSpitterLimit.IntValue, g_hAngelBoomerLimit.IntValue);
        CPrintToChatAll("\tHunter {blue}%d\t{default}Jockey {blue}%d\t{default}Charger {blue}%d",
            g_hAngelHunterLimit.IntValue, g_hAngelJockeyLimit.IntValue, g_hAngelChargerLimit.IntValue);
    }
    CPrintToChatAll("{olive}插件{default}[{blue}Angel{default}] {olive}状态{default}[{blue}%d特/%d秒{default}] {olive}版本{default}[{blue}%s{default}]",
        GetInfectedLimit(), g_hAngelSpawnInterval.IntValue, VERSION);

    g_bIsGameStart = true;
    CreateTimer(0.5, Timer_Prepare2Spawn, 0, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(g_hAngelSpawnInterval.FloatValue / 2 + 1, Timer_DelaySIDealed, 0, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

    return Plugin_Continue;
}

//特感限制
public Action L4D_OnSpawnSpecial(int &zombieClass, const float vecPos[3], const float vecAng[3])
{
    if(L4D2_IsTankInPlay() && GetSurvivorCount() <= 2)
        return Plugin_Handled;

    return Plugin_Continue;
}

//回合开始事件
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bIsGameStart = false;
    g_bIsSpawnCounting = true;

    return Plugin_Continue;
}

//关卡失败
public Action Event_MissionLost(Event event, const char[] name, bool dont_broadcast)
{
    g_bIsGameStart = false;
    g_bIsSpawnCounting = true;

    return Plugin_Continue;
}

//坦克生成事件
public Action Event_TankSpawn(Event event, const char[] name, bool dont_broadcast)
{
    int tank = GetClientOfUserId(event.GetInt("userid"));
    SetPlayerHealth(tank, (GetSurvivorCount() > 2 ? 1500 : 1100) * GetSurvivorCount());

    return Plugin_Continue;
}

//秒妹回血
public Action Event_WitchKilled(Event event, const char[] name, bool dont_broadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsSurvivor(client) && IsPlayerAlive(client) && !IsPlayerIncap(client))
    {
        int heal = GetPlayerHealth(client) + 10;
        if (heal > GetEntProp(client, Prop_Data, "m_iMaxHealth"))
            heal = GetPlayerHealth(client);

        SetPlayerHealth(client, heal);
    }

    return Plugin_Continue;
}

//玩家切换队伍时修正尸潮数量
public Action Event_PlayerChangeTeam(Event event, const char[] name, bool dont_broadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || IsFakeClient(client))
        return Plugin_Continue;

    CreateTimer(0.1, Timer_MobChange, 0, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Continue;
}

//尸潮数量更改
public Action Timer_MobChange(Handle timer)
{
    FindConVar("z_common_limit").SetInt(6 * GetSurvivorCount());
    FindConVar("z_mega_mob_size").SetInt(5 * GetSurvivorCount());
    FindConVar("z_mob_spawn_min_size").SetInt(4 * GetSurvivorCount());
    FindConVar("z_mob_spawn_max_size").SetInt(5 * GetSurvivorCount());

    return Plugin_Stop;
}

//特感生成准备
public Action Timer_Prepare2Spawn(Handle timer)
{
    StartSpawn();
    if(g_hAngelDirectorDebug.BoolValue)
            CPrintToChatAll("count down");

    return Plugin_Stop;
}

//延后特感传送
public Action Timer_DelaySIDealed(Handle timer)
{
    if(!g_bIsGameStart)
        return Plugin_Stop;

    if(g_bIsSpawnCounting)
        return Plugin_Continue;

    CheckDelaySITeleport();

    return Plugin_Continue;
}

//特感数量更改
public void CvarEvent_LimitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    //请勿更改，否则会出现卡特现象(特感刷不出来)
    if(convar != g_hSICountLimit)
        convar.SetInt(0, true);
    else convar.SetInt(31, true);
}

//刷特数量更改
public void CvarEvent_AngelLimitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    FindConVar("angel_infected_limit").SetInt(GetInfectedLimit());
}

//插件信息
public Action Cmd_DirectorMsg(int client, any args)
{
    CPrintToChat(client, "{olive}插件{default}[{blue}Angel{default}] {olive}状态{default}[{blue}%d特/%d秒{default}] {olive}版本{default}[{blue}%s{default}]",
        GetInfectedLimit(), g_hAngelSpawnInterval.IntValue, VERSION);

    return Plugin_Handled;
}

//刷特信息
public Action Cmd_DirectorMode(int client, any args)
{
    if(!FindConVar("angel_party").IntValue)
    {
        CPrintToChat(client, "[{olive}特感详情{default}]");
        CPrintToChat(client, "\tSmoker {blue}%d\t{default}Spitter {blue}%d\t{default}Boomer {blue}%d",
            g_hAngelSmokerLimit.IntValue, g_hAngelSpitterLimit.IntValue, g_hAngelBoomerLimit.IntValue);
        CPrintToChat(client, "\tHunter {blue}%d\t{default}Jockey {blue}%d\t{default}Charger {blue}%d",
            g_hAngelHunterLimit.IntValue, g_hAngelJockeyLimit.IntValue, g_hAngelChargerLimit.IntValue);
    }
    else ClientCommand(client, "sm_dc");

    return Plugin_Handled;
}

//是否存在非克、舌头、口水、胖子存活
bool IsAllKillersDown()
{
    for(int client = 1; client <= MaxClients; client++)
        if(IsInfected(client) && !IsTank(client) && IsPlayerAlive(client) && IsFakeClient(client))
            if(GetInfectedClass(client) != view_as<int>(ZC_Spitter) &&
                GetInfectedClass(client) != view_as<int>(ZC_Smoker) &&
                GetInfectedClass(client) != view_as<int>(ZC_Boomer))
                return false;

    return true;
}

//特感延后传送
void CheckDelaySITeleport()
{
    if(!g_bIsGameStart) return;
    int keySurvivor =  L4D_GetHighestFlowSurvivor();//最高路程生还
    if(g_hAngelDirectorDebug.BoolValue)
        PrintToChatAll("try tp to survivor(%d)", keySurvivor);

    for(int i = 1; i < MaxClients; i++)
        if(IsInfected(i) && IsFakeClient(i) && IsPlayerAlive(i) &&
            //如果能传送并且不是克并且未控制生还，进行传送检测
            CanInfectedTeleport(i) && !IsTank(i) && !IsPinningASurvivor(i))
        {
                float pos[3];
                float keyPos[3];

                if(!IsSurvivor(keySurvivor)) return;
                GetClientAbsOrigin(i, pos);
                GetClientAbsOrigin(keySurvivor, keyPos);
                Address p1 = L4D_GetNearestNavArea(pos, 300.0, false, false, false, TEAM_INFECTED);
                Address p2 = L4D_GetNearestNavArea(keyPos, 300.0, false, false, false, TEAM_SURVIVOR);
                //如果特感路程低于生还路程
                if(L4D2Direct_GetFlowDistance(i) < L4D2Direct_GetFlowDistance(keySurvivor) &&
                    //并且在指定延后距离下不能成功构建Nav导航，进行传送
                    !L4D2_NavAreaBuildPath(p1, p2, g_hAngelDelayDistance.FloatValue, TEAM_INFECTED, false))
                {
                    //获取合适位置传送：如果是困难模式，按照类型找位，否则按照导演生成模式找位
                    GetRandomSpawnPosition(keySurvivor, i, g_hAngelHardMode.BoolValue ? GetInfectedClass(i) : g_hAngelSpawnMode.IntValue, 2, pos);
                    TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
                    //重置技能和血量
                    L4D2_SetCustomAbilityCooldown(i, 0.0);
                    BypassAndExecuteCommand(i, "give", "health");
                    if(g_hAngelDirectorDebug.BoolValue)
                        CPrintToChatAll("%N tped to %N",i, keySurvivor);
                }
        }
}

//检测是否可以进行倒计时
void CheckSpawnCounter()
{
    if(!g_bIsGameStart) return;
    //当前生还最高路程
    float flow = L4D2_GetFurthestSurvivorFlow() / L4D2Direct_GetMapMaxFlowDistance() * 100;
    //如果所有控制型特感死亡，或者存活特感数量小于上限的一半
    if((IsAllKillersDown() || GetAliveInfectedCount() <= GetInfectedLimit() / 2 ||
        //或者玩家冷静度(未遭受伤害程度较高或者造成伤害程度较低)低于特感进攻度
        L4D_GetAvgSurvivorIntensity() <= g_hAngelSIAttackIntent.FloatValue ||
        //或者路程差超过指定权重，如果还没进入计时，开始计时
        flow - g_fLastFlowPercent >= g_hAngelSpawnFlow.FloatValue * (40 - g_hAngelSpawnInterval.FloatValue) / 20) && !g_bIsSpawnCounting)
    {
        if(g_hAngelDirectorDebug.BoolValue)
            CPrintToChatAll("counting--%d %d %.3f %.3f", IsAllKillersDown(), GetAliveInfectedCount() <= GetInfectedLimit() / 4 * 2, flow - g_fLastFlowPercent, L4D_GetAvgSurvivorIntensity());
        float time = g_hAngelSpawnInterval.FloatValue + 1;
        //计时锁死
        g_bIsSpawnCounting = true;
        //唤醒刷特时钟
        CreateTimer(time, Timer_Prepare2Spawn, 0, TIMER_FLAG_NO_MAPCHANGE);
    }
}

//开始刷特
void StartSpawn()
{
    if(!g_bIsGameStart) return;

    if(g_hAngelDirectorDebug.BoolValue)
        CPrintToChatAll("try spawn");

    float pos[3];
    float keyPos[3];
    int typeLimit[6], keySurvivor = L4D_GetHighestFlowSurvivor();
    if(g_hAngelDirectorDebug.BoolValue)
        PrintToChatAll("try spawn to survivor(%d)", keySurvivor);
    //最高路程生还Client
    if(!IsSurvivor(keySurvivor))
        return;
    GetClientAbsOrigin(keySurvivor, keyPos);
    typeLimit[0] = g_hAngelSmokerLimit.IntValue;
    typeLimit[1] = g_hAngelBoomerLimit.IntValue;
    typeLimit[2] = g_hAngelHunterLimit.IntValue;
    typeLimit[3] = g_hAngelSpitterLimit.IntValue;
    typeLimit[4] = g_hAngelJockeyLimit.IntValue;
    typeLimit[5] = g_hAngelChargerLimit.IntValue;

    //初始默认位置，取决于刷特模式
    GetRandomSpawnPosition(keySurvivor, -1, g_hAngelSpawnMode.IntValue, 2, pos);

    for(int i = 1; i < 7; i++)
        for(int v = GetAliveInfectedCountByClass(i); v < typeLimit[i - 1]; v++)
        {
            //如果特感存活数量超过上限，并且是在party模式下，退出刷特
            if(GetAliveInfectedCount() >= GetInfectedLimit() &&
                FindConVar("angel_party").IntValue > 0)
                break;

            float tarPos[3];
            //得到超出上限的特感，我们不关心是哪种特感溢出，只需要拿到一个存活的特感即可
            int target = GetInfectedClientBeyondLimit();
            //获取特感种类，party模式下指定为party种类，否则为循环控制的种类
            int zclass = FindConVar("angel_party").IntValue ? FindConVar("angel_party").IntValue : i;
            //如果特感存在且存活
            if(IsInfected(target) && IsPlayerAlive(target))
                GetClientAbsOrigin(target, tarPos);

            //困难刷特模式：位置较散
            if(g_hAngelHardMode.BoolValue)
                GetRandomSpawnPosition(keySurvivor, target, zclass, 2, pos);

            Address p1 = L4D_GetNearestNavArea(tarPos, 300.0, false, false, false, TEAM_INFECTED);
            Address p2 = L4D_GetNearestNavArea(keyPos, 300.0, false, false, false, TEAM_SURVIVOR);

            //若特感不存在，则直接生成
            if(!IsInfected(target))
            {
                target = L4D2_SpawnSpecial(zclass, pos, NULL_VECTOR);
                if(g_hAngelDirectorDebug.BoolValue)
                    CPrintToChatAll("spawn target %N", target);
            }
            //如果存在，进行传送判定，若没有控中生还且能传送
            else if(!IsPinningASurvivor(target) && CanInfectedTeleport(target) &&
                //并且路程落后于最远的生还(暂时禁用)
                // L4D2Direct_GetFlowDistance(target) < L4D2Direct_GetFlowDistance(keySurvivor) &&
                //并且在指定延后距离下不能成功构建Nav导航，进行传送
                !L4D2_NavAreaBuildPath(p1, p2, g_hAngelDelayDistance.FloatValue, TEAM_INFECTED, false))
            {
                //设置特感种类
                L4D_SetClass(target, zclass);
                //传送到指定位置
                TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
                //重置技能和血量
                L4D2_SetCustomAbilityCooldown(target, 0.0);
                BypassAndExecuteCommand(target, "give", "health");
                if(g_hAngelDirectorDebug.BoolValue)
                    CPrintToChatAll("find target, tped to %N", target);
            }

            //若生成后特感不存在，并且在Debug模式下，输出信息
            if(!IsInfected(target) && g_hAngelDirectorDebug.BoolValue)
                CPrintToChatAll("sth wrong while spawning");
        }

    //设置刷特路程
    g_fLastFlowPercent = (g_hAngelHardMode.BoolValue ? L4D2_GetFurthestSurvivorFlow() : GetFurthestInfectedFlow()) / L4D2Direct_GetMapMaxFlowDistance() * 100;
    g_bIsSpawnCounting = false;
}

//获取特感上限
int GetInfectedLimit()
{
    return g_hAngelSmokerLimit.IntValue + g_hAngelSpitterLimit.IntValue +
        g_hAngelBoomerLimit.IntValue + g_hAngelHunterLimit.IntValue +
        g_hAngelJockeyLimit.IntValue + g_hAngelChargerLimit.IntValue;
}

//获取指定特感种类的存活数量
int GetAliveInfectedCountByClass(int zclass)
{
    int count = 0;
    for(int i = 1; i < MaxClients; i++)
        if(IsInfected(i) && IsPlayerAlive(i) && GetInfectedClass(i) == zclass)
            count++;

    return count;
}

//获取最远的特感的路程
float GetFurthestInfectedFlow()
{
    float farFlowDis = 0.0;
    for(int i = 1; i < MaxClients; i++)
        if(IsInfected(i) && IsPlayerAlive(i) && farFlowDis < L4D2Direct_GetFlowDistance(i))
            farFlowDis = L4D2Direct_GetFlowDistance(i);

    return farFlowDis;
}

//获取超出上限的特感Client
int GetInfectedClientBeyondLimit()
{
    //如果是在party模式下，特感溢出不会继续生成，需要依赖传送时钟处理
    if(FindConVar("angel_party").IntValue)
        return 0;

    int typeLimit[6];
    typeLimit[0] = g_hAngelSmokerLimit.IntValue;
    typeLimit[1] = g_hAngelBoomerLimit.IntValue;
    typeLimit[2] = g_hAngelHunterLimit.IntValue;
    typeLimit[3] = g_hAngelSpitterLimit.IntValue;
    typeLimit[4] = g_hAngelJockeyLimit.IntValue;
    typeLimit[5] = g_hAngelChargerLimit.IntValue;
    for(int i = 1; i < 7; i++)
        for(int v = 1, count = 0; v <= MaxClients; v++)
            if(IsInfected(v) && IsPlayerAlive(v) && IsFakeClient(v) && !IsTank(v) &&
                GetInfectedClass(v) == i && CanInfectedTeleport(v) && !IsPinningASurvivor(v))
                if(++count > typeLimit[i - 1])
                    return v;

    return 0;
}

//获取特感随机生成位置
void GetRandomSpawnPosition(int survivor, int infected, int zclass, int times, float pos[3])
{
    if(!zclass) return;
    L4D_GetRandomPZSpawnPosition(survivor, zclass, times, pos);
    if(!IsInfected(infected) || !IsSurvivor(survivor)) return;

    float surPos[3];
    GetClientAbsOrigin(survivor, surPos);
    Address p1 = L4D_GetNearestNavArea(pos, 300.0, false, false, false, TEAM_INFECTED);
    Address p2 = L4D_GetNearestNavArea(surPos, 300.0, false, false, false, TEAM_SURVIVOR);

    //生成点对应的Nav网格为空，或者生成点与生还者位置位于同一网格，或者点可以被生还看到
    while((!L4D_GetNearestNavArea(pos, 300.0, false, false, false, TEAM_INFECTED) || L4D2_NavAreaTravelDistance(pos, surPos, true) <= 0 || CanPointBeenDetected(pos, RangeType_Visibility) ||
        //或者生成点与生还位置在指定延后距离下能成功构建Nav导航
        L4D2_NavAreaBuildPath(p1, p2, g_hAngelDelayDistance.FloatValue, TEAM_INFECTED, false) ||
        //或者生成点的Nav网格路程低于最高生还者路程时，若生成次数大于0，则尝试下一次生成
        L4D2Direct_GetTerrorNavAreaFlow(L4D2Direct_GetTerrorNavArea(pos)) < L4D2_GetFurthestSurvivorFlow()) && times > 0)
        L4D_GetRandomPZSpawnPosition(survivor, zclass, times--, pos);
}

//特感是否能传送
bool CanInfectedTeleport(int client)
{
    //如果不是特感，或者特感死亡，亦或者特感能看见生还，则不能传送
    if(!IsInfected(client) || !IsPlayerAlive(client) || L4D_HasVisibleThreats(client))
        return false;

    float pos[3];
    GetClientAbsOrigin(client, pos);

    //RangeType_Visibility=>BeenSeen RangeType_Audibility=>BeenHeard
    return !(CanPointBeenDetected(pos, RangeType_Visibility));// ||
        //CanPointBeenDetected(pos, RangeType_Audibility));
}

//点是否可以被指定方式感知
bool CanPointBeenDetected(float pos[3], ClientRangeType rangeType)
{
    int count = 0;
    int clients[MAXSIZE];
    int size = GetClientsInRange(pos, rangeType, clients, MAXSIZE);
    switch(rangeType)
    {
        case RangeType_Visibility:
        {
            for(int i = 0; i < size; i++)
                //如果能被玩家生还看见，则可以被感知
                if(IsSurvivor(clients[i]) && !IsFakeClient(clients[i])
                    && IsPlayerAlive(clients[i]))
                    return true;
        }
        case RangeType_Audibility:
        {
            for(int i = 0; i < size; i++)
                if(IsSurvivor(clients[i]) && IsPlayerAlive(clients[i]))
                    count++;
        }
        default:
        {
            return false;
        }
    }

    //如果能被存活的全部的生还听见，则认为可以被感知
    return (count >= GetAliveSurvivorCount());
}