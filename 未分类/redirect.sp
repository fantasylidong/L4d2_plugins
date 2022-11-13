
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <regex>
#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN

#define SERVER_SHORTNAME_SIZE 100
#define SERVER_GROUP_SIZE 200

#define LOCK_CHAR_UTF8 "|PRIV| "
#define CLEANUP_FOLLOW_TIMEOUT "1 DAY"
#define CLEANUP_SERVERS_MIN_FAIL 10
#define CLEANUP_SERVERS_TIMEOUT "20 MINUTE"

#define LOCKOUT_TEAM 1

#include "redirect/version.sp"
#include "redirect/rcon_sockets.sp"
#include "redirect/server_a2s_info.sp"
#include "redirect/sounds.sp"
#include "redirect/paginated_panels.sp"
#include "redirect/database.sp"
#include "redirect/cvars.sp"


public Plugin:myinfo =
{
    name = "Server Redirect",
    author = "H3bus",
    description = "Server redirection/follow",
    version = VERSION,
    url = "http://www.sourcemod.net"
};

#define UPDATE_URL "http://sourcemodplugin.h3bus.fr/redirect/main.txt"

new Handle:g_hOnAskClientConnect_Forward;

new String:g_sServerIp[120];
new String:g_sGameDir[40];

new bool:g_bConfigsExecuted = false;

new Float:g_fAdvertisePeriod = -1.0;
new Handle:g_hAdvertiseTimer = INVALID_HANDLE;
new g_iCurrentAdvertisedServer = 0;
new g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Info];

new String:g_sServerExternalIp[120] = "";
new String:g_sServerQueryIp[120] = "";
new String:g_sServerQueryIpForGroups[SERVER_GROUP_SIZE] = "";
new bool:g_bRegisterServer = false;
new g_iServerOrder = 0;
new String:g_sServerShortName[SERVER_SHORTNAME_SIZE] = "";
new String:g_sMyGroups[SERVER_GROUP_SIZE] = "A";
new String:g_sShowInGroups[SERVER_GROUP_SIZE] = "A";
new String:g_sExposePWForGroups[SERVER_GROUP_SIZE] = "";
new String:g_sAdvertiseInGroups[SERVER_GROUP_SIZE] = "A";
new g_iAdvertiseMinPlayers = 2;
new g_iAdvertiseMinSlots = 2;
new bool:g_bAdvertiseFollow = false;
new g_iFollowTimeOut = 1;
new g_iServerQueriesCoolDown = 5;
new String:g_sServerPW[200] = "";
new String:g_sServerRconPW[200] = "";
new bool:g_bAutoCleanupDb = false;
new bool:g_bShortAdvertiseMessage = false;
new bool:g_bShortFollowMessage = false;

new Handle:g_hClientPanels[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
new Handle:g_hLockedOutClientsId;
new Handle:g_hServersPwTrie;
new Handle:g_hServersQueryIpTrie;

public OnPluginStart()
{
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
    
    LoadTranslations("redirect.phrases");
    
    g_hOnAskClientConnect_Forward = CreateGlobalForward("OnAskClientConnect", ET_Ignore, Param_Cell, Param_String, Param_String);
    g_hLockedOutClientsId = CreateArray();
    g_hServersPwTrie = CreateTrie();
    g_hServersQueryIpTrie = CreateTrie();
    
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
    
    rcon_Init();
    a2s_Init(a2s_callback, a2s_playerCallback);
    database_Init();
    cvars_Init();
    HookConVarChange(FindConVar("rcon_password"), cvars_Event_CvarChange);
    HookConVarChange(FindConVar("sv_password"), cvars_Event_CvarChange);
    
    GetGameFolderName(g_sGameDir, sizeof(g_sGameDir));
    BuildServerIp(g_sServerIp);
    strcopy(g_sServerExternalIp, sizeof(g_sServerExternalIp), g_sServerIp);
    
    RegServerCmd("redirect_lockout", OnCommand_Lockout, "Locks a player out of game and display server list");
    RegConsoleCmd("sm_servers", OnCommand_Servers, "Display server list");
    RegConsoleCmd("sm_list", OnCommand_Servers, "Display server list");
    RegConsoleCmd("sm_hop", OnCommand_Servers, "Display server list");
    RegConsoleCmd("sm_follow", OnCommand_Follow, "Follow players");
    RegServerCmd("redirect_notify_confirm", OnCommand_RedirectNotifyConfirm);
    
    decl String:cfgFileName[120];
    strcopy(cfgFileName, sizeof(cfgFileName), g_sServerIp);
    ReplaceString(cfgFileName, sizeof(cfgFileName), ".", "_");
    ReplaceString(cfgFileName, sizeof(cfgFileName), ":", "_");
    
    AutoExecConfig(.folder = "redirect", .name = cfgFileName);
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public OnMapEnd()
{
    g_bConfigsExecuted = false;
    
    if(g_bAutoCleanupDb)
        database_CleanupTables(CLEANUP_FOLLOW_TIMEOUT, CLEANUP_SERVERS_MIN_FAIL, CLEANUP_SERVERS_TIMEOUT);
}

public OnConfigsExecuted()
{
    g_bConfigsExecuted = true;
    UpdateState();
}

stock checkIpFormat(const String:ip[])
{
    if(strlen(ip) == 0)
        return false;
    else
        return true;
    /*
    if(SimpleRegexMatch(ip, "\\d+\\.\\d+\\.\\d+\\.:\\d+") == 1)
        return true;
    else
    {
        LogError("Malformated IP \"%s\"", ip);
        return false;
    }*/
}

stock UpdateState()
{
    if(!g_bConfigsExecuted)
        return;
    
    decl String:serverExternalIp[120];
    decl String:serverQueryIp[120];
    decl String:serverQueryIpForGroups[SERVER_GROUP_SIZE];
    new bool:registerServer = g_bRegisterServer;
    new Float:advertisePeriod = g_fAdvertisePeriod;
    new advertiseMinPlayers = g_iAdvertiseMinPlayers;
    new advertiseMinSlots = g_iAdvertiseMinSlots;
    new serverOrder = g_iServerOrder;
    decl String:serverShortName[SERVER_SHORTNAME_SIZE];
    decl String:myGroups[SERVER_SHORTNAME_SIZE];
    decl String:showInGroups[SERVER_SHORTNAME_SIZE];
    decl String:exposePWForGroups[SERVER_SHORTNAME_SIZE];
    decl String:advertiseInGroups[SERVER_SHORTNAME_SIZE];
    decl String:Pw[200];
    decl String:rconPw[200];
    
    strcopy(serverExternalIp, sizeof(serverExternalIp), g_sServerExternalIp);
    strcopy(serverQueryIp, sizeof(serverQueryIp), g_sServerQueryIp);
    strcopy(serverQueryIpForGroups, sizeof(serverQueryIpForGroups), g_sServerQueryIpForGroups);
    strcopy(serverShortName, sizeof(serverShortName), g_sServerShortName);
    strcopy(myGroups, sizeof(myGroups), g_sMyGroups);
    strcopy(showInGroups, sizeof(showInGroups), g_sShowInGroups);
    strcopy(exposePWForGroups, sizeof(exposePWForGroups), g_sExposePWForGroups);
    strcopy(advertiseInGroups, sizeof(advertiseInGroups), g_sAdvertiseInGroups);
    strcopy(Pw, sizeof(Pw), g_sServerPW);
    strcopy(rconPw, sizeof(rconPw), g_sServerRconPW);
    
    cvars_GetPluginConvarString(eCvars_redirect_force_ip,                   g_sServerExternalIp,        sizeof(g_sServerExternalIp));
    cvars_GetPluginConvarString(eCvars_redirect_force_query_ip,             g_sServerQueryIp,           sizeof(g_sServerQueryIp));
    cvars_GetPluginConvarString(eCvars_redirect_force_query_ip_for_group,   g_sServerQueryIpForGroups,  sizeof(g_sServerQueryIpForGroups));
    g_bRegisterServer           = cvars_GetPluginConvarBool(eCvars_redirect_register_server);
    g_iServerOrder              = cvars_GetPluginConvarInt( eCvars_redirect_server_order);
    g_fAdvertisePeriod          = cvars_GetPluginConvarFloat(eCvars_redirect_advertise_period);
    g_iAdvertiseMinPlayers      = cvars_GetPluginConvarInt( eCvars_redirect_advertise_me_min_players);
    g_iAdvertiseMinSlots        = cvars_GetPluginConvarInt( eCvars_redirect_advertise_me_min_slots);
    g_bAdvertiseFollow          = cvars_GetPluginConvarBool(eCvars_redirect_advertise_follow);
    g_bAutoCleanupDb            = cvars_GetPluginConvarBool(eCvars_redirect_autocleanup_db);
    g_bShortAdvertiseMessage    = cvars_GetPluginConvarBool(eCvars_redirect_short_advertise_message);
    g_bShortFollowMessage       = cvars_GetPluginConvarBool(eCvars_redirect_short_follow_message);
    g_iFollowTimeOut            = cvars_GetPluginConvarInt( eCvars_redirect_follow_timeout);
    g_iServerQueriesCoolDown    = cvars_GetPluginConvarInt( eCvars_redirect_server_queries_cooldown);
    cvars_GetPluginConvarString(eCvars_redirect_server_short_hostname,      g_sServerShortName,         sizeof(g_sServerShortName));
    cvars_GetPluginConvarString(eCvars_redirect_my_groups,                  g_sMyGroups,                sizeof(g_sMyGroups));
    cvars_GetPluginConvarString(eCvars_redirect_show_in_groups,             g_sShowInGroups,            sizeof(g_sShowInGroups));
    cvars_GetPluginConvarString(eCvars_redirect_expose_pw_for_groups,       g_sExposePWForGroups,       sizeof(g_sExposePWForGroups));
    cvars_GetPluginConvarString(eCvars_redirect_advertise_in_groups,        g_sAdvertiseInGroups,       sizeof(g_sAdvertiseInGroups));
    
    if(StrEqual("", g_sExposePWForGroups))
        g_sServerPW[0] = '\0';
    else
        GetConVarString(FindConVar("sv_password"), g_sServerPW, sizeof(g_sServerPW));
        
    if(!g_bAdvertiseFollow)
        g_sServerRconPW[0] = '\0';
    else
        GetConVarString(FindConVar("rcon_password"), g_sServerRconPW, sizeof(g_sServerRconPW));
    
    if(!checkIpFormat(g_sServerExternalIp))
        strcopy(g_sServerExternalIp, sizeof(g_sServerExternalIp), g_sServerIp);
    if(!checkIpFormat(g_sServerQueryIp))
    {
        strcopy(g_sServerQueryIp, sizeof(g_sServerQueryIp), "");
        strcopy(g_sServerQueryIpForGroups, sizeof(g_sServerQueryIpForGroups), "");
    }
    
    if(!g_bRegisterServer && registerServer)
    {
        database_UnRegisterServer(g_sServerExternalIp);
    }
    else if(
                (g_bRegisterServer && !registerServer) ||
                (g_iServerOrder != serverOrder) ||
                (g_iAdvertiseMinPlayers != advertiseMinPlayers) ||
                (g_iAdvertiseMinSlots != advertiseMinSlots) ||
                !strcmp(g_sServerExternalIp, serverExternalIp) ||
                !strcmp(g_sServerQueryIp, serverQueryIp) ||
                !strcmp(g_sServerQueryIpForGroups, serverQueryIpForGroups) ||
                !strcmp(g_sServerShortName, serverShortName) ||
                !strcmp(g_sMyGroups, myGroups) ||
                !strcmp(g_sShowInGroups, showInGroups) ||
                !strcmp(g_sExposePWForGroups, exposePWForGroups) ||
                !strcmp(g_sAdvertiseInGroups, advertiseInGroups) ||
                !strcmp(g_sServerPW, Pw) ||
                !strcmp(g_sServerRconPW, rconPw)
            )
        database_RegisterServer(g_sServerExternalIp, g_sServerQueryIp, g_sServerQueryIpForGroups, g_sServerShortName, g_sGameDir, g_sMyGroups, g_sShowInGroups, g_sExposePWForGroups, g_sAdvertiseInGroups, g_iAdvertiseMinPlayers, g_iAdvertiseMinSlots, g_iServerOrder, g_sServerPW, g_sServerRconPW);
    
    if(g_fAdvertisePeriod != advertisePeriod)
        UpdateAdvertiseTimer();
}

stock UpdateAdvertiseTimer()
{
    if(g_fAdvertisePeriod <= 0.0 && g_hAdvertiseTimer != INVALID_HANDLE)
    {
        KillTimer(g_hAdvertiseTimer);
        g_hAdvertiseTimer = INVALID_HANDLE;
    }
    else if(g_fAdvertisePeriod > 0.0)
    {
        if(g_hAdvertiseTimer != INVALID_HANDLE)
            KillTimer(g_hAdvertiseTimer);
        
        g_hAdvertiseTimer = CreateTimer(g_fAdvertisePeriod, OnAdvertiseTimer, _, TIMER_REPEAT);
    }  
}

stock BuildServerIp(String:ip[], size = sizeof(ip))
{
    new String:net_public_adr[100] = "";
    decl String:port[10];

    GetConVarString(FindConVar("hostport"), port, sizeof(port));
    
    if(FindConVar("net_public_adr") != INVALID_HANDLE) 
        GetConVarString(FindConVar("net_public_adr"), net_public_adr, sizeof(net_public_adr));
        
    if(strlen(net_public_adr) == 0 && FindConVar("ip") != INVALID_HANDLE)
    {
        GetConVarString(FindConVar("ip"), net_public_adr, sizeof(net_public_adr));
	
        new colonIndex = FindCharInString(net_public_adr, ':');
        if(colonIndex == -1)
            net_public_adr[0] = '\0';
        else
            net_public_adr[colonIndex] = '\0';
    }
    
    if(strlen(net_public_adr) == 0)
    {
        new ipVal = GetConVarInt(FindConVar("hostip"));
        decl ipVals[4];
        
        ipVals[0] = (ipVal >> 24) & 0x000000FF;
        ipVals[1] = (ipVal >> 16) & 0x000000FF;
        ipVals[2] = (ipVal >> 8) & 0x000000FF;
        ipVals[3] = ipVal & 0x000000FF;
        
        FormatEx(ip, size, "%d.%d.%d.%d:%s", ipVals[0], ipVals[1], ipVals[2], ipVals[3], port);
    }
    else
    {
        FormatEx(ip, size, "%s:%s", net_public_adr, port);
    }
}

public OnClientDisconnect(client)
{
    pp_OnClientDisconnect(client);
    
    new index = FindValueInArray(g_hLockedOutClientsId, GetClientUserId(client));
    if(index != -1)
        RemoveFromArray(g_hLockedOutClientsId, index);
}

public OnClientAuthorized(client, const String:auth[])
{
    if(!IsFakeClient(client))
        database_ConfirmUser(auth, g_iFollowTimeOut, OnUserConfirmedCallBack, GetClientUserId(client));
}

public Action:OnCommand_Lockout(args)
{
    if(GetCmdArgs() != 2)
    {
        PrintToServer("Usage: redirect_lockout <userId> \"<Reason>\"");
        return Plugin_Handled;
    }
    
    decl String:str[200];
    decl userId;
    decl client;
    
    GetCmdArg(1, str, sizeof(str));
    StripQuotes(str);
    userId = StringToInt(str);
    client = GetClientOfUserId(userId);
    
    if(client <= 0 || !IsClientConnected(client))
    {
        PrintToServer("Invalid client");
        return Plugin_Handled;
    }
    
    if(FindValueInArray(g_hLockedOutClientsId, userId) == -1)
        PushArrayCell(g_hLockedOutClientsId, userId);
    
    if(IsClientInGame(client))
        ChangeClientTeam(client, LOCKOUT_TEAM);
    
    GetCmdArg(2, str, sizeof(str));
    StripQuotes(str);
    
    FakeClientCommand(client, "sm_servers");
    
    PrintToChat(client, str);
    
    return Plugin_Handled;
}

public Action:OnCommand_Servers(client, args)
{
    if(StrEqual("", g_sMyGroups))
        PrintToChat(client, "%t", "No server in database");
    else
        database_GetServerList(g_sServerExternalIp, g_sMyGroups, g_sGameDir, g_iServerQueriesCoolDown, CLEANUP_SERVERS_MIN_FAIL, CLEANUP_SERVERS_TIMEOUT, OnGetServerListCallBack, GetClientUserId(client));
    
    return Plugin_Handled;
}

public Action:OnCommand_Follow(client, args)
{
    database_GetFollowList(g_sServerExternalIp, g_sMyGroups, g_iServerQueriesCoolDown, g_iFollowTimeOut, OnFollowListCallBack, GetClientUserId(client));
    
    return Plugin_Handled;
}

public Action:OnCommand_RedirectNotifyConfirm(args)
{
    if(GetCmdArgs() != 7)
    {
        PrintToServer("Usage: redirect_notify_confirm \"<steamId>\" \"<name>\" <players> <bots> <maxplayers> \"<map>\" \"<hostname>\"");
        return Plugin_Handled;
    }
    
    if(!g_bAdvertiseFollow)
        return Plugin_Handled;
        
    decl String:steamId[100];
    decl String:name[100];
    decl String:arg[10];
    decl String:map[100];
    decl String:serverName[SERVER_SHORTNAME_SIZE];
    decl players;
    decl bots;
    decl maxplayers;
    
    GetCmdArg(1, steamId, sizeof(steamId));
    StripQuotes(steamId);
    GetCmdArg(2, name, sizeof(name));
    StripQuotes(name);
    GetCmdArg(3, arg, sizeof(arg));
    StripQuotes(arg);
    players = StringToInt(arg);
    GetCmdArg(4, arg, sizeof(arg));
    StripQuotes(arg);
    bots = StringToInt(arg);
    GetCmdArg(5, arg, sizeof(arg));
    StripQuotes(arg);
    maxplayers = StringToInt(arg);
    GetCmdArg(6, map, sizeof(map));
    StripQuotes(map);
    GetCmdArg(7, serverName, sizeof(serverName));
    StripQuotes(serverName);
    
    if(g_bShortFollowMessage)
        PrintToChatAll("%t", "Player switched to server short", name, serverName, map, players-bots, maxplayers);
    else
    {
        PrintToChatAll("%t", "Player switched to server", name);
        PrintToChatAll("%t", "Server name", serverName);
        PrintToChatAll("%t", "Server info", map, players-bots, maxplayers);
    }
    PrintToChatAll("%t", "Follow to follow");
    
    return Plugin_Handled;
}

public Action:OnAdvertiseTimer(Handle:timer)
{
    if(!StrEqual("", g_sMyGroups))
        database_GetServerAdvertiseList(g_sServerExternalIp, g_sMyGroups, g_sGameDir, g_iServerQueriesCoolDown, OnGetServerAdvertiseListCallBack);
    
    return Plugin_Continue;
}

stock OnClientConnectServer(client, String:ip[])
{
    decl String:steamId[100];
    decl String:name[100];
    decl String:pw[200];
    
    if(
        GetClientAuthString(client, steamId, sizeof(steamId)) &&
        GetClientName(client, name, sizeof(name))
       )
    {
        database_SetFollowInfo(steamId, name, false, g_sServerExternalIp, ip);
    }
    
    GetTrieString(g_hServersPwTrie, ip, pw, sizeof(pw));
    
    Call_StartForward(g_hOnAskClientConnect_Forward);
    Call_PushCell(client);
    Call_PushString(ip);
    Call_PushString(pw);
    Call_Finish();
}

stock OnClientSelectServer(client, String:ip[], String:ServerName[], String:ServerInfos[])
{
    decl String:ItemId[100];
    decl String:ItemStr[100];
    decl String:QueryIp[50];
    
    g_hClientPanels[client] = pp_Create();
    pp_SetTittle(g_hClientPanels[client], ServerName);
    pp_AddItem(g_hClientPanels[client], "", ServerInfos, ITEMDRAW_RAWLINE);
    
    Format(ItemId, sizeof(ItemId), "c%s", ip);
    Format(ItemStr, sizeof(ItemStr), "%T", "Join this server", client);
    
    pp_AddItem(g_hClientPanels[client], ItemId, ItemStr);
    
    GetTrieString(g_hServersQueryIpTrie, ip, QueryIp, sizeof(QueryIp));
    Format(ItemId, sizeof(ItemId), "r%s", QueryIp);
    Format(ItemStr, sizeof(ItemStr), "%T", "Show players", client);
    pp_AddItem(g_hClientPanels[client], ItemId, ItemStr);
    
    pp_DisplayToClient(g_hClientPanels[client], client, playersMenuCallBack);    
}

public OnUserConfirmedCallBack(Handle:sqlResponse, any:clientId)
{
    new client = GetClientOfUserId(clientId);
    
    if(client > 0 && !IsClientConnected(client) && IsClientInGame(client))
        return;
    
    if(SQL_GetAffectedRows(sqlResponse) > 0)
    {
        decl String:steamId[100];
        
        if(GetClientAuthString(client, steamId, sizeof(steamId)))
        {
            database_GetFollowSourceServer(steamId, g_sMyGroups, OnFollowSourceServerRetrieveCallback);
        }
    }
}

stock GetClientsCounts(&players, &bots, &maxplayers)
{
    players = 0;
    bots = 0;
    maxplayers = GetConVarInt(FindConVar("sv_visiblemaxplayers"));
    
    for(new client = 1; client <= MaxClients; client++)
    {
        if(IsClientConnected(client))
        {
            players++;
            
            if(IsFakeClient(client))
                bots++;
        }
    }
}

public OnFollowSourceServerRetrieveCallback(Handle:sqlResponse, any:arg)
{
    if(SQL_GetRowCount(sqlResponse) <= 0)
        return;
    
    SQL_FetchRow(sqlResponse);
    
    decl infos[eDatabase_FollowSourceServer_Info];
    
    if(!database_ExtractFollowSourceServerRow(sqlResponse, infos))
       return;
    
    if(StrEqual("", infos[eDatabase_FollowSourceServer_RconPW]))
       return;
        
    new players;
    new bots;
    new maxplayers;
    GetClientsCounts(players, bots, maxplayers);
        
    decl String:map[100];
    GetCurrentMap(map, sizeof(map));
    
    decl String:serverName[SERVER_SHORTNAME_SIZE];
    if(!StrEqual("", g_sServerShortName))
        strcopy(serverName, sizeof(serverName), g_sServerShortName);
    else
        GetConVarString(FindConVar("hostname"), serverName, sizeof(serverName));
    
    ReplaceString(serverName, sizeof(serverName), "\"", "'");
    ReplaceString(infos[eDatabase_FollowSourceServer_Name], sizeof(infos[eDatabase_FollowSourceServer_Name]), "\"", "'");
    
    decl String:command[500];
    Format(command, sizeof(command), "redirect_notify_confirm \"%s\" \"%s\" %d %d %d \"%s\" \"%s\"", 
                                    infos[eDatabase_FollowSourceServer_Steam],
                                    infos[eDatabase_FollowSourceServer_Name],
                                    players, bots, maxplayers,
                                    map,
                                    serverName);
                 
    rcon_SendCommand(infos[eDatabase_FollowSourceServer_Server], infos[eDatabase_FollowSourceServer_RconPW], command, .erCB = OnRconError);
}

public OnRconError(id, any:arg, rcon_Errors:rconError, errorType, errorNum)
{
    decl String:errorStr[200];
    rcon_GetErrorString(rconError, errorType, errorNum, errorStr);
    LogError( "OnRconError: %s", errorStr);
}

public OnGetServerListCallBack(Handle:sqlResponse, any:clientId)
{
    new client = GetClientOfUserId(clientId);
    
    if(!IsClientConnected(client) && IsClientInGame(client))
        return;
    
    if(SQL_GetRowCount(sqlResponse) <= 0)
    {
        PrintToChat(client, "%t", "No server in database");
        return;
    }
    
    if(g_hClientPanels[client] != INVALID_HANDLE)
        pp_Close(g_hClientPanels[client]);
    
    decl String:itemStr[100];
    
    g_hClientPanels[client] = pp_Create();
    Format(itemStr, sizeof(itemStr), "%T", "Choose a server", client);
    pp_SetTittle(g_hClientPanels[client], itemStr);
    
    
    while(SQL_FetchRow(sqlResponse))
    {
        decl infos[eDatabase_ServerList_Info];
        decl String:itemId[100];
        decl String:hostname[100];
        
        if(
            !database_ExtractServerListRow(sqlResponse, infos) ||
            StrEqual("", infos[eDatabase_ServerList_Ip])
           )
        {
            LogError("Expecting ip SQL field in OnGetServerListCallBack");
            continue;
        }
        
        if(!StrEqual("", infos[eDatabase_ServerList_ShortHostname]))
        {
            Format(itemId, sizeof(itemId), "st%s", infos[eDatabase_ServerList_Ip]);
            strcopy(hostname, sizeof(hostname), infos[eDatabase_ServerList_ShortHostname]);
        }
        else if(!StrEqual("", infos[eDatabase_ServerList_ShortHostname]))
        {
            Format(itemId, sizeof(itemId), "t%s", infos[eDatabase_ServerList_Ip]);
            strcopy(hostname, sizeof(hostname), infos[eDatabase_ServerList_Hostname]);
        }
        else
        {
            Format(itemId, sizeof(itemId), "t%s", infos[eDatabase_ServerList_Ip]);
            strcopy(hostname, sizeof(hostname), infos[eDatabase_ServerList_Ip]);
        }
        
        if(infos[eDatabase_ServerList_ExposePw])
            SetTrieString(g_hServersPwTrie, infos[eDatabase_ServerList_Ip], infos[eDatabase_ServerList_Pw]);
        else
            SetTrieString(g_hServersPwTrie, infos[eDatabase_ServerList_Ip], "");
        
        SetTrieString(g_hServersQueryIpTrie, infos[eDatabase_ServerList_Ip], infos[eDatabase_ServerList_QueryIp]);
        
        if(infos[eDatabase_ServerList_Private] && !infos[eDatabase_ServerList_ExposePw])
        {
            decl String:Name[100];
            Format(Name, sizeof(Name), "%T | %s", "Private", client, hostname);
            pp_AddItem(g_hClientPanels[client], itemId, Name, ITEMDRAW_WITHNEXT);
        }
        else
            pp_AddItem(g_hClientPanels[client], itemId, hostname, ITEMDRAW_WITHNEXT);
        
        if(infos[eDatabase_ServerList_UpToDate])
        {
            if(infos[eDatabase_ServerList_Players]-infos[eDatabase_ServerList_Bots] >= infos[eDatabase_ServerList_MaxPlayers])
                pp_UpdateItem(g_hClientPanels[client], itemId, hostname, ITEMDRAW_WITHNEXT | ITEMDRAW_DISABLED, .updateDisplay=false);
            
            Format(itemId, sizeof(itemId), "i%s", infos[eDatabase_ServerList_Ip]);
            Format(itemStr, sizeof(itemStr), "%T", "Server info menu", client, infos[eDatabase_ServerList_Players]-infos[eDatabase_ServerList_Bots], infos[eDatabase_ServerList_MaxPlayers], infos[eDatabase_ServerList_Map]);
            pp_AddItem(g_hClientPanels[client], itemId, itemStr, ITEMDRAW_RAWLINE);
        }
        else
        {
            Format(itemId, sizeof(itemId), "i%s", infos[eDatabase_ServerList_Ip]);
            Format(itemStr, sizeof(itemStr), "%T", "Refreshing infos", client);
            pp_AddItem(g_hClientPanels[client], itemId, itemStr, ITEMDRAW_RAWLINE);
            a2s_queryServer(infos[eDatabase_ServerList_Ip], infos[eDatabase_ServerList_QueryIp], GetClientUserId(client));
        }
    }
    
    pp_DisplayToClient(g_hClientPanels[client], client, menuCallBack);
}

public OnGetServerAdvertiseListCallBack(Handle:sqlResponse, any:data)
{
    #if defined DEBUG
        LogMessage("OnGetServerAdvertiseListCallBack");
    #endif
    if(SQL_GetRowCount(sqlResponse) <= 0)
        return;
    
    #if defined DEBUG
        LogMessage("Database gave us %d servers", SQL_GetRowCount(sqlResponse));
    #endif
    
    if(SQL_GetRowCount(sqlResponse) <= g_iCurrentAdvertisedServer)
        g_iCurrentAdvertisedServer = 0;
    
    for(new row=0; row <= g_iCurrentAdvertisedServer; row++)
        SQL_FetchRow(sqlResponse);
    
    g_iCurrentAdvertisedServer++;
    
    #if defined DEBUG
        LogMessage("Currently advertising %d", g_iCurrentAdvertisedServer);
    #endif
    
    if(
        !database_ExtractServerAdvertiseListRow(sqlResponse, g_CurrentAdvertisedServerInfo) ||
        StrEqual("", g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Ip])
       )
    {
        #if defined DEBUG
            LogMessage("Expecting ip SQL field in OnGetServerAdvertiseListCallBack");
        #endif
        
        LogError("Expecting ip SQL field in OnGetServerAdvertiseListCallBack");
        return;
    }
    
    if(g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_UpToDate])
    {
        #if defined DEBUG
            LogMessage("Server is up-to-date");
        #endif
        if(
            g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_AdvertiseMinPlayers] > g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Players]-g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Bots] ||
            g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_AdvertiseMinSlots] > (g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_MaxPlayers] - (g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Players]-g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Bots]))) 
        {
            #if defined DEBUG
                LogMessage("Not adevertising: Server min players = %s ; min slots: %d",  g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_AdvertiseMinPlayers], g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_AdvertiseMinSlots]);
            #endif
            return;
        }
        
        decl String:hostname[100];
        
        if(!StrEqual("", g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_ShortHostname]))
            strcopy(hostname, sizeof(hostname), g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_ShortHostname]);
        else if(!StrEqual("", g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Hostname]))
            strcopy(hostname, sizeof(hostname), g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Hostname]);
        else
            strcopy(hostname, sizeof(hostname), g_CurrentAdvertisedServerInfo[eDatabase_ServerList_Ip]);
        
        #if defined DEBUG
            LogMessage("Advertising %s", hostname);
        #endif
        
        if(g_bShortAdvertiseMessage)
             PrintToChatAll("%t", "Server short advertise", hostname, g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Map], g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Players]-g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Bots], g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_MaxPlayers]);
        else
        {
            PrintToChatAll("%t", "Server advertise", hostname, g_CurrentAdvertisedServerInfo[eDatabase_ServerList_Ip]);
            PrintToChatAll("%t", "Server info", g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Map], g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Players]-g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_Bots], g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_MaxPlayers]);
        }
        PrintToChatAll("%t", "Server to connect");
    }
    else
    {
        #if defined DEBUG
            LogMessage("Querying %s @\"%s\"", g_CurrentAdvertisedServerInfo[eDatabase_ServerList_Ip], g_CurrentAdvertisedServerInfo[eDatabase_ServerList_QueryIp]);
        #endif
        a2s_queryServer(g_CurrentAdvertisedServerInfo[eDatabase_ServerList_Ip], g_CurrentAdvertisedServerInfo[eDatabase_ServerList_QueryIp], -1);
    }
}

stock AdvertiseOnA2SResults(infos[a2s_infoStructure])
{
    if(infos[a2s_status] != eA2S_Success)
    {
        database_IncreaseServerRefreshFailures(infos[a2s_ip]);
    }
    else
    {
        database_UpdateServerInfos(infos[a2s_ip], infos[a2s_name], infos[a2s_private], infos[a2s_players], infos[a2s_bots], infos[a2s_maxplayers], infos[a2s_map]);
        
        if(
            g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_AdvertiseMinPlayers] <= infos[a2s_players]-infos[a2s_bots] && 
            g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_AdvertiseMinSlots] <= (infos[a2s_maxplayers] - (infos[a2s_players]-infos[a2s_bots]))
          )
        {
            decl String:hostname[100];
            if(!StrEqual("", g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_ShortHostname]))
                strcopy(hostname, sizeof(hostname), g_CurrentAdvertisedServerInfo[eDatabase_ServerAdvertiseList_ShortHostname]);
            else
                strcopy(hostname, sizeof(hostname), infos[a2s_name]);
            
            if(g_bShortAdvertiseMessage)
                PrintToChatAll("%t", "Server short advertise", hostname, infos[a2s_map], infos[a2s_players]-infos[a2s_bots], infos[a2s_maxplayers]);
            else
            {
                PrintToChatAll("%t", "Server advertise", hostname, infos[a2s_ip]);
                PrintToChatAll("%t", "Server info", infos[a2s_map], infos[a2s_players]-infos[a2s_bots], infos[a2s_maxplayers]);
            }
            PrintToChatAll("%t", "Server to connect");
        }
    }
}

public OnFollowListCallBack(Handle:sqlResponse, any:clientId)
{
    new client = GetClientOfUserId(clientId);
    
    if(!IsClientConnected(client) && IsClientInGame(client))
        return;
    
    if(SQL_GetRowCount(sqlResponse) <= 0)
    {
        PrintToChat(client, "%t", "No one to follow");
        return;
    }
    
    if(g_hClientPanels[client] != INVALID_HANDLE)
        pp_Close(g_hClientPanels[client]);
    
    decl String:itemStr[100];
    g_hClientPanels[client] = pp_Create();
    Format(itemStr, sizeof(itemStr), "%T", "Who do you want to follow?", client);
    pp_SetTittle(g_hClientPanels[client], itemStr);
    
    while(SQL_FetchRow(sqlResponse))
    {
        decl String:hostname[100];
        decl String:itemId[100];
        decl infos[eDatabase_FollowList_Info];
        
        if(
            !database_ExtractFollowListRow(sqlResponse, infos) ||
            StrEqual("", infos[eDatabase_FollowList_Ip]) ||
            StrEqual("", infos[eDatabase_FollowList_Names])
           )
        {
            LogError("Expecting ip and names SQL field in OnFollowListCallBack");
            continue;
        }
        
        Format(itemId, sizeof(itemId), "n%s", infos[eDatabase_FollowList_Ip]);
        pp_AddItem(g_hClientPanels[client], itemId, infos[eDatabase_FollowList_Names], ITEMDRAW_WITHNEXT);
                
        if(!StrEqual("", infos[eDatabase_FollowList_ShortHostname]))
        {
            Format(itemId, sizeof(itemId), "st%s", infos[eDatabase_FollowList_Ip]);
            strcopy(hostname, sizeof(hostname), infos[eDatabase_FollowList_ShortHostname]);
        }
        else if(!StrEqual("", infos[eDatabase_FollowList_Hostname]))
        {
            Format(itemId, sizeof(itemId), "t%s", infos[eDatabase_FollowList_Ip]);
            strcopy(hostname, sizeof(hostname), infos[eDatabase_FollowList_Hostname]);
        }
        else
        {
            Format(itemId, sizeof(itemId), "t%s", infos[eDatabase_FollowList_Ip]);
            strcopy(hostname, sizeof(hostname), infos[eDatabase_FollowList_Ip]);
        }
        
        if(infos[eDatabase_FollowList_ExposePw])
            SetTrieString(g_hServersPwTrie, infos[eDatabase_FollowList_Ip], infos[eDatabase_FollowList_Pw]);
        else
            SetTrieString(g_hServersPwTrie, infos[eDatabase_FollowList_Ip], "");
        
        SetTrieString(g_hServersQueryIpTrie, infos[eDatabase_FollowList_Ip], infos[eDatabase_FollowList_QueryIp]);
        
        if(infos[eDatabase_FollowList_Private] && !infos[eDatabase_FollowList_ExposePw])
        {
            decl String:Name[100];
            Format(Name, sizeof(Name), "%T | %s", "Private", client, hostname);
            pp_AddItem(g_hClientPanels[client], itemId, Name, ITEMDRAW_WITHNEXT);
        }
        else
            pp_AddItem(g_hClientPanels[client], itemId, hostname, ITEMDRAW_WITHNEXT);
            
        pp_AddItem(g_hClientPanels[client], itemId, hostname, ITEMDRAW_RAWLINE | ITEMDRAW_WITHNEXT);
        
        Format(itemId, sizeof(itemId), "i%s", infos[eDatabase_FollowList_Ip]);
        
        if(infos[eDatabase_FollowList_UpToDate])
        {
            Format(itemStr, sizeof(itemStr), "%T", "Server info menu", client, infos[eDatabase_FollowList_Players]-infos[eDatabase_FollowList_Bots], infos[eDatabase_FollowList_MaxPlayers], infos[eDatabase_FollowList_Map]);
            pp_AddItem(g_hClientPanels[client], itemId, itemStr, ITEMDRAW_RAWLINE);
        }
        else
        {
            Format(itemStr, sizeof(itemStr), "%T", "Refreshing infos", client);
            pp_AddItem(g_hClientPanels[client], itemId, itemStr, ITEMDRAW_RAWLINE);
            a2s_queryServer(infos[eDatabase_FollowList_Ip], infos[eDatabase_FollowList_QueryIp], GetClientUserId(client));
        }
    }
    
    pp_DisplayToClient(g_hClientPanels[client], client, menuCallBack);
}

public menuCallBack(Handle:pp, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:Id[100];
        decl String:name[100];
        decl String:infos[100];
        new ipIndex = 1;
        
        pp_GetMenuItem(pp, param2+1, Id, sizeof(Id), _, infos, sizeof(infos));
        pp_GetMenuItem(pp, param2, Id, sizeof(Id), _, name, sizeof(name));
        
        if(Id[0] == 's')
            ipIndex++;
        
        OnClientSelectServer(param1, Id[ipIndex], name, infos);
    }
}

public playersMenuCallBack(Handle:pp, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        decl String:Id[50];
        
        pp_GetMenuItem(pp, param2, Id, sizeof(Id));
        
        if(Id[0] == 'c')
        {
            OnClientConnectServer(param1, Id[1]);
        }
        else if(Id[0] == 'r')
        {
            decl String:ItemStr[50];
            decl String:Title[100];
            
            pp_GetTittle(g_hClientPanels[param1], ItemStr, sizeof(ItemStr));
            Format(Title, sizeof(Title), "%s | %T", ItemStr, "Players", param1);
            pp_SetTittle(g_hClientPanels[param1], Title);
            
            Format(ItemStr, sizeof(ItemStr), "%T", "Players", param1);
            pp_UpdateItem(g_hClientPanels[param1], Id, ItemStr, ITEMDRAW_SPACER);
            
            pp_DisplayToClient(g_hClientPanels[param1], param1, playersMenuCallBack);
            
            a2s_queryServerPlayers(Id[1], GetClientUserId(param1));
        }
    }
}

public a2s_callback(any:clientId, infos[a2s_infoStructure])
{
    if(clientId == -1)
    {
        AdvertiseOnA2SResults(infos);
        return;
    }
    
    new client = GetClientOfUserId(clientId);
    
    if(client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client))
        return;
    
    if(g_hClientPanels[client] == INVALID_HANDLE)
        return;
    
    decl String:itemId[100];
    decl String:itemStr[100];
    
    if(infos[a2s_status] == eA2S_Success)
    {
        new flags = ITEMDRAW_NO_UPDATE;
        if(infos[a2s_players]-infos[a2s_bots] >= infos[a2s_maxplayers])
            flags = ITEMDRAW_WITHNEXT | ITEMDRAW_DISABLED;
        
        Format(itemId, sizeof(itemId), "t%s", infos[a2s_ip]);
        
        if(infos[a2s_private])
        {
            decl String:pw[100];
            GetTrieString(g_hServersPwTrie, infos[a2s_ip], pw, sizeof(pw));
            if(StrEqual("", pw))
            {
                decl String:Name[100];
                Format(Name, sizeof(Name), "%T | %s", "Private", client, infos[a2s_name]);
                if(!pp_UpdateItem(g_hClientPanels[client], itemId, Name, flags))
                {
                    Format(itemId, sizeof(itemId), "st%s", infos[a2s_ip]);
                    pp_UpdateItem(g_hClientPanels[client], itemId, "", flags);
                }
            }
        }
        else if(!pp_UpdateItem(g_hClientPanels[client], itemId, infos[a2s_name], flags))
        {
            Format(itemId, sizeof(itemId), "st%s", infos[a2s_ip]);
            pp_UpdateItem(g_hClientPanels[client], itemId, "", flags);
        }
        
        Format(itemId, sizeof(itemId), "i%s", infos[a2s_ip]);
        Format(itemStr, sizeof(itemStr), "%T", "Server info menu", client, infos[a2s_players]-infos[a2s_bots], infos[a2s_maxplayers], infos[a2s_map]);
        pp_UpdateItem(g_hClientPanels[client], itemId, itemStr, .updateDisplay=true);
        
        database_UpdateServerInfos(infos[a2s_ip], infos[a2s_name], infos[a2s_private], infos[a2s_players], infos[a2s_bots], infos[a2s_maxplayers], infos[a2s_map]);
    }
    else
    {
        Format(itemId, sizeof(itemId), "i%s", infos[a2s_ip]);
        Format(itemStr, sizeof(itemStr), "%T", "Error refreshing infos", client);
        pp_UpdateItem(g_hClientPanels[client], itemId, itemStr, .updateDisplay=true);
        
        database_IncreaseServerRefreshFailures(infos[a2s_ip]);
    }
}

stock FormatGameTime(String:dst[], destSize, Float:time)
{
    new Float:iTime = time;
    new hours = RoundToFloor(iTime/3600.0);
    iTime -= hours * 3600.0;
    new minutes = RoundToFloor(iTime/60.0);
    iTime -= minutes * 60.0;
    new seconds = RoundFloat(iTime);
    
    if(hours != 0)
        Format(dst, destSize, "%dh%dm%ds", hours, minutes, seconds);
    else if(minutes != 0)
        Format(dst, destSize, "%dm%ds", minutes, seconds);
    else
        Format(dst, destSize, "%ds", seconds);
}

public a2s_playerCallback(any:clientId, infos[a2s_playersInfoStructure])
{
    new client = GetClientOfUserId(clientId);
    
    if(client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client))
        return;
    
    if(g_hClientPanels[client] == INVALID_HANDLE)
        return;
    
    if(infos[a2s_player_status] == eA2S_Success)
    {
       decl String:infoStr[100];
       decl String:timeStr[20];
       
       FormatGameTime(timeStr, sizeof(timeStr), infos[a2s_player_connection_time]);
       Format(infoStr, sizeof(infoStr), "%T", "Score Time", client, infos[a2s_player_score], timeStr);
       
       pp_AddItem(g_hClientPanels[client], "", infos[a2s_player_name], ITEMDRAW_RAWLINE | ITEMDRAW_WITHNEXT);
       pp_AddItem(g_hClientPanels[client], "", infoStr, ITEMDRAW_RAWLINE, .updateDisplay=true);
    }
}

public Action:ChangeTeamTimer(Handle:timer, any:clientId)
{
    new client = GetClientOfUserId(clientId);
    
    if(client > 0 && IsClientConnected(client) && IsClientInGame(client))
    {
        ChangeClientTeam(client, LOCKOUT_TEAM); 
    }
    
    return Plugin_Stop;
}


public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
    new clientId = GetEventInt(event, "userid");
    
    if(FindValueInArray(g_hLockedOutClientsId, clientId) != -1)
    {
        new newTeam = GetEventInt(event, "team");
        
        if(newTeam != LOCKOUT_TEAM)
        {
            FakeClientCommand(GetClientOfUserId(clientId), "sm_servers");
            CreateTimer(0.1, ChangeTeamTimer, clientId);
        }
        
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}
