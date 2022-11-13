#define DATABASE_MAX_QUERY_SIZE 1000

#define DATABASE_CREATE_SERVER_TABLE_QUERY \
   "CREATE TABLE IF NOT EXISTS `redirect_servers` ( \
      `ip` varchar(50) NOT NULL, \
      `query_ip` varchar(50) NOT NULL DEFAULT '', \
      `query_ip_for_groups` varchar(200) NOT NULL DEFAULT '', \
      `last_online` datetime DEFAULT NULL, \
      `refresh_failures` int(11) NOT NULL DEFAULT '0', \
      `last_refresh` timestamp NULL DEFAULT CURRENT_TIMESTAMP, \
      `hostname` varchar(200) DEFAULT '', \
      `short_hostname` varchar(50) DEFAULT NULL, \
      `private` tinyint(1) NOT NULL DEFAULT '0', \
      `players` int(11) NOT NULL DEFAULT '0', \
      `bots` int(11) NOT NULL DEFAULT '0', \
      `maxplayers` int(11) NOT NULL DEFAULT '0', \
      `map` varchar(100) NOT NULL DEFAULT '', \
      `my_groups` varchar(200) NOT NULL DEFAULT '', \
      `show_in_groups` varchar(200) NOT NULL DEFAULT '', \
      `advertise_in_groups` varchar(200) NOT NULL DEFAULT '', \
      `expose_pw_for_groups` varchar(200) NOT NULL DEFAULT '', \
      `advertise_min_players` int(11) NOT NULL DEFAULT '0', \
      `advertise_min_slots` int(11) NOT NULL DEFAULT '0', \
      `game` varchar(20) NOT NULL, \
      `order` int(11) NOT NULL DEFAULT '0', \
      `pw` varchar(200) DEFAULT '', \
      `rcon_pw` varchar(200) DEFAULT '', \
      UNIQUE KEY `ip_key` (`ip`) \
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"

#define DATABASE_UPDATE_SERVER_TABLE_FROM_0_1_2_QUERY \
    "ALTER TABLE `redirect_servers` \
        ADD COLUMN `query_ip` varchar(50) NOT NULL DEFAULT '' AFTER `ip`,\
        ADD COLUMN `query_ip_for_groups` varchar(200) NOT NULL DEFAULT '' AFTER `query_ip`;"

#define DATABASE_UPDATE_SERVER_TABLE_FROM_0_2_4_QUERY \
    "ALTER TABLE `redirect_servers` \
        MODIFY COLUMN `ip` varchar(300);"
        
#define DATABASE_CREATE_FOLLOW_TABLE_QUERY \
   "CREATE TABLE IF NOT EXISTS `redirect_follow` ( \
      `steam` varchar(40) NOT NULL, \
      `name` varchar(120) NOT NULL, \
      `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, \
      `state` enum('menu_choice','confirmed') NOT NULL DEFAULT 'menu_choice', \
      `server` varchar(40) NOT NULL, \
      `target_server` varchar(40) DEFAULT NULL, \
      UNIQUE KEY `steam_key` (`steam`) \
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;"
    
#define DATABASE_SERVER_REGISTER_QUERY \
   "INSERT INTO `redirect_servers` \
    (ip, query_ip, query_ip_for_groups, last_online, refresh_failures, short_hostname, my_groups, show_in_groups, expose_pw_for_groups, advertise_in_groups, advertise_min_players, advertise_min_slots, game, `order`, pw, rcon_pw) \
    VALUES ('%s', '%s', '%s', NOW(), 0, '%s', '%s', '%s', '%s', '%s', %d, %d, '%s', %d, '%s', '%s') \
    ON DUPLICATE KEY UPDATE \
    query_ip = VALUES(query_ip), \
    query_ip_for_groups = VALUES(query_ip_for_groups), \
    refresh_failures = VALUES(refresh_failures), \
    short_hostname = VALUES(short_hostname), \
    my_groups = VALUES(my_groups), \
    show_in_groups = VALUES(show_in_groups), \
    expose_pw_for_groups = VALUES(expose_pw_for_groups), \
    advertise_in_groups = VALUES(advertise_in_groups), \
    advertise_min_players = VALUES(advertise_min_players), \
    advertise_min_slots = VALUES(advertise_min_slots), \
    game = VALUES(game), \
    `order` = VALUES(`order`), \
    pw = VALUES(pw), \
    rcon_pw = VALUES(rcon_pw)"

#define DATABASE_SERVER_UNREGISTER_QUERY \
   "DELETE FROM `redirect_servers` \
    WHERE ip='%s'"

#define DATABASE_SERVER_LIST_QUERY \
   "SELECT ip, \
           IF(query_ip != '' AND query_ip_for_groups REGEXP '[%s]', query_ip, ip) AS query_ip, \
           (last_refresh BETWEEN NOW() - INTERVAL %d SECOND AND NOW()) AS up_to_date, \
           hostname,short_hostname,private,players,bots,maxplayers,map,pw, \
           (expose_pw_for_groups REGEXP '[%s]') as expose_pw FROM `redirect_servers` \
    WHERE ip!='%s' AND game='%s' AND show_in_groups REGEXP '[%s]' AND \
        (refresh_failures <= %d OR last_online >= (NOW() - INTERVAL %s)) \
    ORDER BY `order`"

enum eDatabase_ServerList_Info {
    String:     eDatabase_ServerList_Ip[300],
    String:     eDatabase_ServerList_QueryIp[300],
    bool:       eDatabase_ServerList_UpToDate,
    String:     eDatabase_ServerList_Hostname[200],
    String:     eDatabase_ServerList_ShortHostname[50],
    bool:       eDatabase_ServerList_Private,
                eDatabase_ServerList_Players,
                eDatabase_ServerList_Bots,
                eDatabase_ServerList_MaxPlayers,
    String:     eDatabase_ServerList_Map[100],
    String:     eDatabase_ServerList_Pw[200],
    bool:       eDatabase_ServerList_ExposePw,
}

#define DATABASE_SERVER_AVERTISE_LIST_QUERY \
   "SELECT ip, \
           IF(query_ip != '' AND query_ip_for_groups REGEXP '[%s]', query_ip, ip) AS query_ip, \
           (last_refresh BETWEEN NOW() - INTERVAL %d SECOND AND NOW()) AS up_to_date,hostname,short_hostname,private,players,bots,maxplayers,map,advertise_min_players,advertise_min_slots FROM `redirect_servers` \
    WHERE ip!='%s' AND game='%s' AND advertise_in_groups REGEXP '[%s]' \
    ORDER BY `order`"
    
enum eDatabase_ServerAdvertiseList_Info {
    String:     eDatabase_ServerAdvertiseList_Ip[300],
    String:     eDatabase_ServerAdvertiseList_QueryIp[300],
    bool:       eDatabase_ServerAdvertiseList_UpToDate,
    String:     eDatabase_ServerAdvertiseList_Hostname[200],
    String:     eDatabase_ServerAdvertiseList_ShortHostname[50],
    bool:       eDatabase_ServerAdvertiseList_Private,
                eDatabase_ServerAdvertiseList_Players,
                eDatabase_ServerAdvertiseList_Bots,
                eDatabase_ServerAdvertiseList_MaxPlayers,
    String:     eDatabase_ServerAdvertiseList_Map[100],
                eDatabase_ServerAdvertiseList_AdvertiseMinPlayers,
                eDatabase_ServerAdvertiseList_AdvertiseMinSlots,
}

#define DATABASE_INCREASE_SERVER_REFRESH_FAILURES  \
   "UPDATE `redirect_servers` \
    SET refresh_failures = refresh_failures + 1, \
        last_refresh = NOW() \
    WHERE ip = '%s'"

#define DATABASE_UPDATE_SERVER_INFO \
   "UPDATE `redirect_servers` SET \
        hostname = '%s', \
        private = %d, \
        players = %d, \
        bots = %d, \
        maxplayers = %d, \
        map = '%s', \
        last_online = NOW(), \
        refresh_failures = 0, \
        last_refresh = NOW() \
    WHERE ip = '%s'"

#define DATABASE_GET_FOLLOW_LIST \
   "SELECT GROUP_CONCAT(f.name SEPARATOR  ' | ') AS names, \
           s.ip, \
           IF(s.query_ip != '' AND s.query_ip_for_groups REGEXP '[%s]', s.query_ip, s.ip) AS query_ip, \
           (s.last_refresh BETWEEN NOW() - INTERVAL %d SECOND AND NOW()) AS up_to_date, \
           s.hostname,s.short_hostname,s.private,s.players,s.bots,s.maxplayers,s.map,s.pw, \
           (s.expose_pw_for_groups REGEXP '[%s]') as expose_pw \
    FROM `redirect_follow` f \
    INNER JOIN `redirect_servers` s \
    WHERE f.server = '%s' AND f.state = 'confirmed' AND f.target_server = s.ip AND f.time BETWEEN NOW() - INTERVAL %d MINUTE AND NOW() \
    GROUP BY f.target_server \
    ORDER BY f.time"

enum eDatabase_FollowList_Info {
    String:     eDatabase_FollowList_Names[100],
    String:     eDatabase_FollowList_Ip[300],
    String:     eDatabase_FollowList_QueryIp[50],
    bool:       eDatabase_FollowList_UpToDate,
    String:     eDatabase_FollowList_Hostname[200],
    String:     eDatabase_FollowList_ShortHostname[50],
    bool:       eDatabase_FollowList_Private,
                eDatabase_FollowList_Players,
                eDatabase_FollowList_Bots,
                eDatabase_FollowList_MaxPlayers,
    String:     eDatabase_FollowList_Map[100],
    String:     eDatabase_FollowList_Pw[200],
    bool:       eDatabase_FollowList_ExposePw,
}

#define DATABASE_SET_FOLLOW_INFOS \
   "INSERT INTO `redirect_follow` (steam, name, time, state, server, target_server) \
    VALUES ('%s', '%s', NOW(), '%s', '%s', '%s') \
    ON DUPLICATE KEY UPDATE name=VALUES(name), time=VALUES(time), state=VALUES(state), server=VALUES(server), target_server=VALUES(target_server)"

#define DATABASE_CONFIRM_USER \
   "UPDATE `redirect_follow` SET \
        state = 'confirmed', \
        time = NOW() \
    WHERE steam = '%s' AND time BETWEEN NOW() - INTERVAL %d MINUTE AND NOW()"

#define DATABASE_GET_FOLLOW_SOURCE_SERVER \
   "SELECT f.steam,f.name, \
           IF(s.query_ip != '' AND s.query_ip_for_groups REGEXP '[%s]', s.query_ip, s.ip) AS server, \
           s.rcon_pw \
    FROM `redirect_follow` f \
    INNER JOIN `redirect_servers` s \
    WHERE s.ip = f.server AND f.steam = '%s' AND f.state = 'confirmed'"

enum eDatabase_FollowSourceServer_Info {
    String:     eDatabase_FollowSourceServer_Steam[40],
    String:     eDatabase_FollowSourceServer_Name[120],
    String:     eDatabase_FollowSourceServer_Server[300],
    String:     eDatabase_FollowSourceServer_RconPW[200],
}

#define DATABASE_CLEANUP_FOLLOW_TABLE \
   "DELETE FROM `redirect_follow` \
    WHERE time < (NOW() - INTERVAL %s)"

#define DATABASE_CLEANUP_SERVERS_TABLE \
   "DELETE FROM `redirect_servers` \
    WHERE refresh_failures > %d AND last_online < (NOW() - INTERVAL %s)"   

functag public database_CallBack(Handle:sqlResponse, any:arg);

enum datebase_query_structureElements {
                        eDatabase_query_structureElement_Index,
    bool:               eDatabase_query_structureElement_Sent,
    String:             eDatabase_query_structureElement_Query[DATABASE_MAX_QUERY_SIZE],
    SQLTCallback:       eDatabase_query_structureElement_InternalCallBack,
    database_CallBack:  eDatabase_query_structureElement_ExternalCallBack,
    any:                eDatabase_query_structureElement_Arg,
                        eDatabase_query_structureElement_COUNT
}

static Handle:g_hDatabase = INVALID_HANDLE;
static bool:g_bDatabase_Connected = false;
static bool:g_bDatabase_TablesAvailable = false;
static bool:g_bDatabase_Busy = false;
static bool:g_bDatabase_FailState = false;
static g_iDatabase_SuccessiveFailures = 0;

static g_iDatabase_QueryIndex = 0;

static Handle:g_hQueriesQueue = INVALID_HANDLE;

stock database_Init()
{
    g_hQueriesQueue = CreateArray(eDatabase_query_structureElement_COUNT);
    
    if(!SQL_CheckConfig("redirect"))
    {
        LogError("Database configuration not found \"redirect\"");
        g_bDatabase_FailState = true;
        return;
    }
}

stock database_EnqueueQuery(String:query[], SQLTCallback:internalCallBack, database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    new queryInfos[datebase_query_structureElements];
    
    queryInfos[eDatabase_query_structureElement_Index] = g_iDatabase_QueryIndex++;
    queryInfos[eDatabase_query_structureElement_Sent] = false;
    strcopy(queryInfos[eDatabase_query_structureElement_Query], sizeof(queryInfos[eDatabase_query_structureElement_Query]), query);
    queryInfos[eDatabase_query_structureElement_InternalCallBack] = internalCallBack,
    queryInfos[eDatabase_query_structureElement_ExternalCallBack] = externalCallBack,
    queryInfos[eDatabase_query_structureElement_Arg] = arg;
    
    PushArrayArray(g_hQueriesQueue, queryInfos, sizeof(queryInfos));
}

stock database_RemoveQuery(index)
{
    new item = FindValueInArray(g_hQueriesQueue, index);
    if(item == -1)
        return;
    
    RemoveFromArray(g_hQueriesQueue, item);
}

stock database_RunNextQuery()
{
    if(g_bDatabase_FailState || g_bDatabase_Busy)
        return;
    
    if(!g_bDatabase_Connected)
    {
        g_bDatabase_Busy = true;
        SQL_TConnect(database_OnConnection, "redirect");
        return;
    }
    
    if(!g_bDatabase_TablesAvailable)
    {
        database_CreateTables();
        return;
    }
    
    new size = GetArraySize(g_hQueriesQueue);
    
    for(new index=0; index < size; index++)
    {
        if(!GetArrayCell(g_hQueriesQueue, index, _:eDatabase_query_structureElement_Sent))
        {
            decl query[datebase_query_structureElements];
            GetArrayArray(g_hQueriesQueue, index, query);
            
            SetArrayCell(g_hQueriesQueue, index, true, _:eDatabase_query_structureElement_Sent);
            g_bDatabase_Busy = true;
            SQL_TQuery(
                        g_hDatabase,
                        query[eDatabase_query_structureElement_InternalCallBack],
                        query[eDatabase_query_structureElement_Query],
                        query[eDatabase_query_structureElement_Index]
                        );
            break;
        }
    }
    
}

stock database_CreateTables()
{
    #if defined DEBUG
        LogMessage("database_CreateTables");
        LogMessage("SQL_CreateTransaction");
    #endif
    
    new Handle:transaction = SQL_CreateTransaction();
    
    SQL_AddQuery(transaction, DATABASE_CREATE_SERVER_TABLE_QUERY);
    #if defined DEBUG
        LogMessage("SQL_AddQuery: %s", DATABASE_CREATE_SERVER_TABLE_QUERY);
    #endif
    SQL_AddQuery(transaction, DATABASE_CREATE_FOLLOW_TABLE_QUERY);
    #if defined DEBUG
        LogMessage("SQL_AddQuery: %s", DATABASE_CREATE_FOLLOW_TABLE_QUERY);
    #endif
    
    g_bDatabase_Busy = true;
    
    SQL_ExecuteTransaction(g_hDatabase, transaction, database_OnTableCreateSuccess, database_OnTableCreateError);

    #if defined DEBUG
        LogMessage("SQL_ExecuteTransaction");
    #endif
}

stock database_UpdateTables()
{
    SQL_TQuery(g_hDatabase, database_OnTableUpdated_Dummy,  DATABASE_UPDATE_SERVER_TABLE_FROM_0_1_2_QUERY);
    SQL_TQuery(g_hDatabase, database_OnTableUpdated,        DATABASE_UPDATE_SERVER_TABLE_FROM_0_2_4_QUERY);
}

stock database_CleanupTables(String:FollowTimeOut[], maxRefreshFailures, String:LastOnlineTimeout[], database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    
    FormatEx(query, sizeof(query), DATABASE_CLEANUP_FOLLOW_TABLE, FollowTimeOut);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    FormatEx(query, sizeof(query), DATABASE_CLEANUP_SERVERS_TABLE, maxRefreshFailures, LastOnlineTimeout);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock database_RegisterServer(const String:ip[], const String:query_ip[], const String:query_ip_for_groups[], const String:shortName[], const String:game[], const String:myGroups[], const String:showInGroups[], const String:exposePWForGroups[], const String:advertiseInGroups[], advertiseMinPlayers, advertiseMinSlots, order, const String:Pw[], const String:rconPw[], database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
        
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    decl String:shortName_Escaped[SERVER_SHORTNAME_SIZE*2];
    
    strcopy(shortName_Escaped, sizeof(shortName_Escaped), shortName);
    ReplaceString(shortName_Escaped, sizeof(shortName_Escaped), "'", "''");
    ReplaceString(shortName_Escaped, sizeof(shortName_Escaped), "\\", "\\\\");
    
    FormatEx(query, sizeof(query), DATABASE_SERVER_REGISTER_QUERY, ip, query_ip, query_ip_for_groups, shortName_Escaped, myGroups, showInGroups, exposePWForGroups, advertiseInGroups, advertiseMinPlayers, advertiseMinSlots, game, order, Pw, rconPw);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock database_UnRegisterServer(const String:ip[], database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    
    FormatEx(query, sizeof(query), DATABASE_SERVER_UNREGISTER_QUERY, ip);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock database_GetServerList(const String:myIp[], const String:myGroups[], const String:game[], refreshCoolDown, minFailures, const String:minTimeout[], database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    
    FormatEx(query, sizeof(query), DATABASE_SERVER_LIST_QUERY, myGroups, refreshCoolDown, myGroups, myIp, game, myGroups, minFailures, minTimeout);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock bool:database_ExtractServerListRow(Handle:sqlResponse, infos[eDatabase_ServerList_Info])
{
    decl fieldNum;
    
    if(SQL_FieldNameToNum(sqlResponse, "ip", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerList_Ip], sizeof(infos[eDatabase_ServerList_Ip]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "query_ip", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerList_QueryIp], sizeof(infos[eDatabase_ServerList_QueryIp]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "up_to_date", fieldNum))
        infos[eDatabase_ServerList_UpToDate] = bool:SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "hostname", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerList_Hostname], sizeof(infos[eDatabase_ServerList_Hostname]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "short_hostname", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerList_ShortHostname], sizeof(infos[eDatabase_ServerList_ShortHostname]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "private", fieldNum))
        infos[eDatabase_ServerList_Private] = bool:SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "players", fieldNum))
        infos[eDatabase_ServerList_Players] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "bots", fieldNum))
        infos[eDatabase_ServerList_Bots] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "maxplayers", fieldNum))
        infos[eDatabase_ServerList_MaxPlayers] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "map", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerList_Map], sizeof(infos[eDatabase_ServerList_Map]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "pw", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerList_Pw], sizeof(infos[eDatabase_ServerList_Pw]));
    else
        return false;
        
    if(SQL_FieldNameToNum(sqlResponse, "expose_pw", fieldNum))
        infos[eDatabase_ServerList_ExposePw] = bool:SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
        
    return true;
}

stock database_GetServerAdvertiseList(const String:myIp[], const String:myGroups[], const String:game[], refreshCoolDown, database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    
    FormatEx(query, sizeof(query), DATABASE_SERVER_AVERTISE_LIST_QUERY, myGroups, refreshCoolDown, myIp, game, myGroups);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock bool:database_ExtractServerAdvertiseListRow(Handle:sqlResponse, infos[eDatabase_ServerAdvertiseList_Info])
{
    decl fieldNum;
    
    if(SQL_FieldNameToNum(sqlResponse, "ip", fieldNum)) 
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerAdvertiseList_Ip], sizeof(infos[eDatabase_ServerAdvertiseList_Ip]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "query_ip", fieldNum)) {
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerAdvertiseList_QueryIp], sizeof(infos[eDatabase_ServerAdvertiseList_QueryIp]));
   }
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "up_to_date", fieldNum))
        infos[eDatabase_ServerAdvertiseList_UpToDate] = bool:SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "hostname", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerAdvertiseList_Hostname], sizeof(infos[eDatabase_ServerAdvertiseList_Hostname]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "short_hostname", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerAdvertiseList_ShortHostname], sizeof(infos[eDatabase_ServerAdvertiseList_ShortHostname]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "private", fieldNum))
        infos[eDatabase_ServerAdvertiseList_Private] = bool:SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "players", fieldNum))
        infos[eDatabase_ServerAdvertiseList_Players] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "bots", fieldNum))
        infos[eDatabase_ServerAdvertiseList_Bots] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "maxplayers", fieldNum))
        infos[eDatabase_ServerAdvertiseList_MaxPlayers] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "map", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_ServerAdvertiseList_Map], sizeof(infos[eDatabase_ServerAdvertiseList_Map]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "advertise_min_players", fieldNum))
        infos[eDatabase_ServerAdvertiseList_AdvertiseMinPlayers] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "advertise_min_slots", fieldNum))
        infos[eDatabase_ServerAdvertiseList_AdvertiseMinSlots] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    return true;
}

stock database_IncreaseServerRefreshFailures(const String:ip[], database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    
    FormatEx(query, sizeof(query), DATABASE_INCREASE_SERVER_REFRESH_FAILURES, ip);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock database_UpdateServerInfos(const String:ip[], const String:hostname[], bool:private, players, bots, maxplayers, String:map[], database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    decl String:hostname_Escaped[SERVER_SHORTNAME_SIZE*2];
    
    strcopy(hostname_Escaped, sizeof(hostname_Escaped), hostname);
    ReplaceString(hostname_Escaped, sizeof(hostname_Escaped), "'", "''");
    ReplaceString(hostname_Escaped, sizeof(hostname_Escaped), "\\", "\\\\");

    FormatEx(query, sizeof(query), DATABASE_UPDATE_SERVER_INFO, hostname_Escaped, private, players, bots, maxplayers, map, ip);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock database_GetFollowList(const String:ip[], const String:myGroups[], refreshCoolDown, maxTime, database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    
    FormatEx(query, sizeof(query), DATABASE_GET_FOLLOW_LIST, myGroups, refreshCoolDown, myGroups, ip, maxTime);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock bool:database_ExtractFollowListRow(Handle:sqlResponse, infos[eDatabase_FollowList_Info])
{
    decl fieldNum;
    
    if(SQL_FieldNameToNum(sqlResponse, "names", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowList_Names], sizeof(infos[eDatabase_FollowList_Names]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "ip", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowList_Ip], sizeof(infos[eDatabase_FollowList_Ip]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "query_ip", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowList_QueryIp], sizeof(infos[eDatabase_FollowList_QueryIp]));
    else
        return false;
        
    if(SQL_FieldNameToNum(sqlResponse, "up_to_date", fieldNum))
        infos[eDatabase_FollowList_UpToDate] = bool:SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "hostname", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowList_Hostname], sizeof(infos[eDatabase_FollowList_Hostname]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "short_hostname", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowList_ShortHostname], sizeof(infos[eDatabase_FollowList_ShortHostname]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "private", fieldNum))
        infos[eDatabase_FollowList_Private] = bool:SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "players", fieldNum))
        infos[eDatabase_FollowList_Players] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "bots", fieldNum))
        infos[eDatabase_FollowList_Bots] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "maxplayers", fieldNum))
        infos[eDatabase_FollowList_MaxPlayers] = SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "map", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowList_Map], sizeof(infos[eDatabase_FollowList_Map]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "pw", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowList_Pw], sizeof(infos[eDatabase_FollowList_Pw]));
    else
        return false;
        
    if(SQL_FieldNameToNum(sqlResponse, "expose_pw", fieldNum))
        infos[eDatabase_FollowList_ExposePw] = bool:SQL_FetchInt(sqlResponse, fieldNum);
    else
        return false;
        
    return true;
}

stock database_SetFollowInfo(const String:steamId[], const String:name[], bool:confirmed, const String:ip[], const String:targetIp[], database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    decl String:name_Escaped[SERVER_SHORTNAME_SIZE*2];
    
    strcopy(name_Escaped, sizeof(name_Escaped), name);
    ReplaceString(name_Escaped, sizeof(name_Escaped), "'", "''");
    ReplaceString(name_Escaped, sizeof(name_Escaped), "\\", "\\\\");
    
    FormatEx(query, sizeof(query), DATABASE_SET_FOLLOW_INFOS, steamId, name_Escaped, confirmed?"confimed":"menu_choice", ip, targetIp);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock database_ConfirmUser(const String:steamId[], maxTime, database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    
    FormatEx(query, sizeof(query), DATABASE_CONFIRM_USER, steamId, maxTime);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock database_GetFollowSourceServer(const String:steamId[], const String:myGroups[], database_CallBack:externalCallBack=database_CallBack:-1, any:arg=0)
{
    if(g_bDatabase_FailState)
        return;
    
    decl String:query[DATABASE_MAX_QUERY_SIZE];
    
    FormatEx(query, sizeof(query), DATABASE_GET_FOLLOW_SOURCE_SERVER, myGroups, steamId);
    database_EnqueueQuery(query, database_GeneralCallback, externalCallBack, arg);
    database_RunNextQuery();
}

stock bool:database_ExtractFollowSourceServerRow(Handle:sqlResponse, infos[eDatabase_FollowSourceServer_Info])
{
    decl fieldNum;
    
    if(SQL_FieldNameToNum(sqlResponse, "steam", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowSourceServer_Steam], sizeof(infos[eDatabase_FollowSourceServer_Steam]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "name", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowSourceServer_Name], sizeof(infos[eDatabase_FollowSourceServer_Name]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "server", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowSourceServer_Server], sizeof(infos[eDatabase_FollowSourceServer_Server]));
    else
        return false;
    
    if(SQL_FieldNameToNum(sqlResponse, "rcon_pw", fieldNum))
        SQL_FetchString(sqlResponse, fieldNum, infos[eDatabase_FollowSourceServer_RconPW], sizeof(infos[eDatabase_FollowSourceServer_RconPW]));
    else
        return false;
    
    return true;
}


// CallBacks
public database_OnConnection(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    g_bDatabase_Busy = false;
    
    if (hndl == INVALID_HANDLE)
    {
        LogError("Database connection failure: %s", error);
        g_iDatabase_SuccessiveFailures++;
        
        if(g_iDatabase_SuccessiveFailures > 5)
            g_bDatabase_FailState = true;
        
        g_hDatabase = INVALID_HANDLE;
        
        return;
    }
    else
    {
        #if defined DEBUG
            LogMessage("database_OnConnection: Sucess");
        #endif
        g_bDatabase_Connected = true;
        g_hDatabase = hndl;
        
        SQL_SetCharset(g_hDatabase, "utf8");
    
        database_RunNextQuery();
    }
}

public database_OnTableCreateSuccess(Handle:db, any:data, numQueries, Handle:results[], any:queryData[])
{
    #if defined DEBUG
        LogMessage("database_OnTableCreateSuccess");
    #endif
    g_bDatabase_Busy = false;
    g_bDatabase_TablesAvailable = true;
    
    database_UpdateTables();
}

public database_OnTableCreateError(Handle:db, any:data, numQueries, const String:error[], failIndex, any:queryData[])
{
    g_bDatabase_Busy = false;
    LogError("Database table creation failure: %s", error);
    g_bDatabase_TablesAvailable = false;
    g_bDatabase_FailState = true;
    g_bDatabase_Connected = false;
    CloseHandle(g_hDatabase);
    g_hDatabase = INVALID_HANDLE;
    
    ClearArray(g_hQueriesQueue);
}


public database_OnTableUpdated_Dummy(Handle:owner, Handle:hndle, const String:error[], any:data)
{
}

public database_OnTableUpdated(Handle:owner, Handle:hndle, const String:error[], any:data)
{
    #if defined DEBUG
        LogMessage("database_OnTableUpdated");
    #endif
    database_AfterTableUpdated();
}


stock database_AfterTableUpdated()
{
    g_bDatabase_Busy = false;
    g_bDatabase_TablesAvailable = true;
    
    database_RunNextQuery();
}

public database_GeneralCallback(Handle:owner, Handle:hndle, const String:error[], any:data)
{
    new item = FindValueInArray(g_hQueriesQueue, data);
    
    if(error[0])
    {
        #if defined DEBUG
            LogMessage("database_GeneralCallback: Database failure: %s", error);
        #endif
        LogError("Database failure: %s", error);
        
        if(item != -1)
        {
            decl query[datebase_query_structureElements] ;
            GetArrayArray(g_hQueriesQueue, item, query);
            
            #if defined DEBUG
                LogMessage("While running query: %s", query[eDatabase_query_structureElement_Query]);
            #endif
            LogError("While running query: %s", query[eDatabase_query_structureElement_Query]);
        }        
    }
    else
    {
        decl query[datebase_query_structureElements] ;
        GetArrayArray(g_hQueriesQueue, item, query);
        #if defined DEBUG
            LogMessage("database_GeneralCallback: Database success on query: %s", query[eDatabase_query_structureElement_Query]);
        #endif
        
        if(query[eDatabase_query_structureElement_ExternalCallBack] != database_CallBack:-1)
        {
            #if defined DEBUG
                LogMessage("database_GeneralCallback: calling plugin callback");
            #endif
            Call_StartFunction(INVALID_HANDLE, query[eDatabase_query_structureElement_ExternalCallBack]);
            Call_PushCell(hndle);
            Call_PushCell(query[eDatabase_query_structureElement_Arg]);
            Call_Finish();
            #if defined DEBUG
                LogMessage("database_GeneralCallback: plugin callback returned");
            #endif
        }
    }
    
    database_RemoveQuery(data);
    
    g_bDatabase_Busy = false;
    database_RunNextQuery();
}
