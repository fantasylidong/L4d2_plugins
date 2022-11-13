
#pragma semicolon 1
#include <sourcemod>
#include <socket>


#define A2S_TIMEOUT       3.0

#define A2S_NAME_SIZE     150
#define A2S_MAP_SIZE      80

#define A2S_SPLIT         0xFFFFFFFE
#define A2S_NOSPLIT       0xFFFFFFFF

#define A2S_INFO_QUERY          "\xFF\xFF\xFF\xFF\x54Source Engine Query"
#define A2S_INFO_QUERY_SIZE     25
#define A2S_INFO_RESPONSE_ID    0x49
#define A2S_PLAYERS_CHALLENGE_QUERY       "\xFF\xFF\xFF\xFF\x55\xFF\xFF\xFF\xFF"
#define A2S_PLAYERS_CHALLENGE_QUERY_SIZE  10
#define A2S_PLAYERS_CHALLENGE_RESPONSE_ID 0x41
#define A2S_PLAYERS_QUERY       "\xFF\xFF\xFF\xFF\x55"
#define A2S_PLAYERS_QUERY_SIZE  10
#define A2S_PLAYERS_QUERY_CHALLENGESTART 5
#define A2S_PLAYERS_RESPONSE_ID 0x44


enum a2s_QueryType{
    eA2S_Infos,
    eA2S_Players,
}

enum a2s_Status{
    eA2S_Success,
    eA2S_TimeOut,
    eA2S_EarlyDisconnect,
    eA2S_InvalidResponse,
    eA2S_SocketError
}

static String:g_sA2S_Status_Strings[a2s_Status][17] =
{
    "Success",
    "TimeOut",
    "EarlyDisconnect",
    "InvalidResponse",
    "SocketError"
};

enum a2s_infoStructure
{
    a2s_Status: a2s_status,
    String:     a2s_ip[A2S_NAME_SIZE],
    String:     a2s_name[A2S_NAME_SIZE],
    String:     a2s_map[A2S_MAP_SIZE],
                a2s_players,
                a2s_maxplayers,
                a2s_bots,
    bool:       a2s_private
}

enum a2s_playersInfoStructure
{
    a2s_Status: a2s_player_status,
    String:     a2s_player_name[A2S_NAME_SIZE],
                a2s_player_score,
    Float:      a2s_player_connection_time
}

functag public a2s_QueryCallBack(any:arg, infos[a2s_infoStructure]);
functag public a2s_PlayerQueryCallBack(any:arg, infos[a2s_playersInfoStructure]);

new a2s_QueryCallBack:g_hCallback = a2s_QueryCallBack:INVALID_HANDLE;
new a2s_PlayerQueryCallBack:g_hPlayerCallback = a2s_PlayerQueryCallBack:INVALID_HANDLE;

stock a2s_Init(a2s_QueryCallBack:callback, a2s_PlayerQueryCallBack:playerCallback)
{
    g_hCallback = callback;
    g_hPlayerCallback = playerCallback;
}

stock bool:a2s_queryServer(String:serverIp[], String:serverQueryIp[], any:arg)
{
    new colonIndex = FindCharInString(serverQueryIp, ':');
    
    if(colonIndex == -1)
        return false;
    
    #if defined DEBUG
        LogMessage("a2s_queryServer: %s on IP %s", serverIp, serverQueryIp);
    #endif
    serverQueryIp[colonIndex] = '\0';
    new serverPort = StringToInt(serverQueryIp[colonIndex+1]);
    
    new Handle:socket = SocketCreate(SOCKET_UDP, a2s_OnSocketError);
    new Handle:dataPack = CreateDataPack();
    
    WritePackCell(dataPack, eA2S_Infos);
    WritePackCell(dataPack, arg);
    WritePackCell(dataPack, socket);
    
    SocketSetArg(socket, dataPack);
    SocketConnect(socket, a2s_OnSocketConnected,
                          a2s_OnSocketReceive,
                          a2s_OnSocketDisconnect,
                          serverQueryIp,
                          serverPort);
    
    new Handle:timer = CreateTimer(A2S_TIMEOUT, a2s_OnTimeout, dataPack);
    
    WritePackCell(dataPack, timer);
    WritePackString(dataPack, serverIp);
    
    return true;
}

stock bool:a2s_queryServerPlayers(String:serverIp[], any:arg)
{
    new colonIndex = FindCharInString(serverIp, ':');
    
    if(colonIndex == -1)
        return false;
    
    serverIp[colonIndex] = '\0';
    #if defined DEBUG
        LogMessage("a2s_queryServerPlayers: %s", serverIp);
    #endif
    new serverPort = StringToInt(serverIp[colonIndex+1]);
    
    new Handle:socket = SocketCreate(SOCKET_UDP, a2s_OnSocketError);
    new Handle:dataPack = CreateDataPack();
    
    WritePackCell(dataPack, eA2S_Players);
    WritePackCell(dataPack, arg);
    WritePackCell(dataPack, socket);
    
    SocketSetArg(socket, dataPack);
    SocketConnect(socket, a2s_OnSocketConnected,
                          a2s_OnSocketReceive,
                          a2s_OnSocketDisconnect,
                          serverIp,
                          serverPort);
    
    new Handle:timer = CreateTimer(A2S_TIMEOUT, a2s_OnTimeout, dataPack);
    
    WritePackCell(dataPack, timer);
    serverIp[colonIndex] = ':';
    WritePackString(dataPack, serverIp);
    
    return true;
}

stock a2s_UnpackIntLE(const String:packet[])
{
    return (packet[3] << 24) + (packet[2] << 16) + (packet[1] << 8) + packet[0];
}

stock a2s_OnError(any:datapack, a2s_Status:status)
{
    ResetPack(datapack);
    ReadPackCell(datapack); //queryType
    new arg = ReadPackCell(datapack);
    new Handle:socket = ReadPackCell(datapack);
    new Handle:timer = ReadPackCell(datapack);
    
    new infos[a2s_infoStructure];
    infos[a2s_status] = status;
    ReadPackString(datapack, infos[a2s_ip], sizeof(infos[a2s_ip]));
    
    LogError("A2S error '%s' while refreshing %s infos", g_sA2S_Status_Strings[status], infos[a2s_ip]);
    
    #if defined DEBUG
        LogMessage("A2S error '%s' while refreshing %s infos", g_sA2S_Status_Strings[status], infos[a2s_ip]);
    #endif
    Call_StartFunction(INVALID_HANDLE, g_hCallback);
    Call_PushCell(arg);
    Call_PushArray(infos, sizeof(infos));
    Call_Finish();
    
    if(status != eA2S_TimeOut)
        CloseHandle(timer);
    CloseHandle(socket);
    CloseHandle(datapack);
}

public a2s_HandleInfoPacket(const String:receiveData[], const dataSize, any:datapack)
{
    ResetPack(datapack);
    ReadPackCell(datapack); //queryType
    new arg = ReadPackCell(datapack);
    new Handle:socket = ReadPackCell(datapack);
    new Handle:timer = ReadPackCell(datapack);
    
    new infos[a2s_infoStructure];
    ReadPackString(datapack, infos[a2s_ip], sizeof(infos[a2s_ip]));
    
    new bool:checksOk = true;
    new dataPos = 0;
    
    // Bypass Protocol
    dataPos++;
    
    if(checksOk && dataPos < dataSize)
        dataPos += strcopy(infos[a2s_name], A2S_NAME_SIZE, receiveData[dataPos]) + 1;
    
    if(checksOk && dataPos < dataSize)
    {
        new slashIndex = FindCharInString(receiveData[dataPos], '/', .reverse=true);
        
        if(slashIndex != -1)
            dataPos += slashIndex+1;
        
        dataPos += strcopy(infos[a2s_map], A2S_MAP_SIZE, receiveData[dataPos]) + 1;
    }
    
    // Bypass Folder
    if(checksOk && dataPos < dataSize)
        dataPos += strlen(receiveData[dataPos]) + 1;
    
    // Bypass Game
    if(checksOk && dataPos < dataSize)
        dataPos += strlen(receiveData[dataPos]) + 1;
    
    // Bypass ID
    dataPos += 2;
    
    if(checksOk && dataPos < dataSize)
        infos[a2s_players] = receiveData[dataPos];
    dataPos++;
    
    if(checksOk && dataPos < dataSize)
        infos[a2s_maxplayers] = receiveData[dataPos];
    dataPos++;
    
    if(checksOk && dataPos < dataSize)
        infos[a2s_bots] = receiveData[dataPos];
    dataPos++;
    
    // Bypass Server type and environment
    dataPos += 2;
    
    if(checksOk && dataPos < dataSize)
        infos[a2s_private] = bool:receiveData[dataPos];
    
    if(checksOk && dataPos < dataSize)
    {
        if(infos[a2s_bots] > infos[a2s_players])
            infos[a2s_players] = infos[a2s_bots];
        
        infos[a2s_status] = eA2S_Success;
        
        #if defined DEBUG
            LogMessage("A2S success on server %s, map: %s, players: %d, bots: %d, maxplayers: %d", infos[a2s_ip], infos[a2s_map], infos[a2s_players], infos[a2s_bots], infos[a2s_maxplayers]);
        #endif
        Call_StartFunction(INVALID_HANDLE, g_hCallback);
        Call_PushCell(arg);
        Call_PushArray(infos, sizeof(infos));
        Call_Finish();
        
        CloseHandle(timer);
        CloseHandle(socket);
        CloseHandle(datapack);
    }
    else
        a2s_OnError(datapack, eA2S_InvalidResponse);
}

public a2s_HandlePlayersChallengePacket(Handle:socket, const String:receiveData[], const dataSize, any:datapack)
{
    if(dataSize >= 4)
    {
        #if defined DEBUG
            LogMessage("a2s_HandlePlayersChallengePacket: success");
        #endif
        new String:query[A2S_PLAYERS_QUERY_SIZE] = A2S_PLAYERS_QUERY;
        
        strcopy(query[A2S_PLAYERS_QUERY_CHALLENGESTART], A2S_PLAYERS_QUERY_SIZE - A2S_PLAYERS_QUERY_CHALLENGESTART, receiveData);
        SocketSend(socket, query, A2S_PLAYERS_QUERY_SIZE);
    }
    else
    {
        a2s_OnError(datapack, eA2S_InvalidResponse);
    }
}

public a2s_HandlePlayersPacket(const String:receiveData[], const dataSize, any:datapack)
{
    #if defined DEBUG
        LogMessage("a2s_HandlePlayersPacket");
    #endif
    ResetPack(datapack);
    ReadPackCell(datapack); //queryType
    new arg = ReadPackCell(datapack);
    new Handle:socket = ReadPackCell(datapack);
    new Handle:timer = ReadPackCell(datapack);
    
    new bool:checksOk = true;
    new dataPos = 0;
    
    decl infos[a2s_playersInfoStructure];
    infos[a2s_player_status] = eA2S_Success;
    
    new playerCount = receiveData[dataPos];
    dataPos++;
    
    for(new i = 0; i < playerCount && checksOk; i++)
    {
        if(dataPos >= dataSize)
            checksOk = false;
        dataPos++; // Bypass index
        
        if(checksOk && dataPos < dataSize)
            dataPos += strcopy(infos[a2s_player_name], sizeof(infos[a2s_player_name]), receiveData[dataPos]) + 1;
        
        if(checksOk && dataPos < dataSize)
            infos[a2s_player_score] = a2s_UnpackIntLE(receiveData[dataPos]);
        dataPos += 4;
        
        if(checksOk && dataPos < dataSize)
            infos[a2s_player_connection_time] = Float:a2s_UnpackIntLE(receiveData[dataPos]);
        dataPos += 4;
        
        if(checksOk && dataPos <= dataSize)
        {
            #if defined DEBUG
                LogMessage("Success");
            #endif
            Call_StartFunction(INVALID_HANDLE, g_hPlayerCallback);
            Call_PushCell(arg);
            Call_PushArray(infos, sizeof(infos));
            Call_Finish();
        }
    }
    
    CloseHandle(timer);
    CloseHandle(socket);
    CloseHandle(datapack);
}


// Callbacks
public a2s_OnSocketError(Handle:socket_, const errorType, const errorNum, any:datapack)
{
    ResetPack(datapack);
    ReadPackCell(datapack); // queryType
    ReadPackCell(datapack); // arg
    ReadPackCell(datapack); // socket
    ReadPackCell(datapack); // timer
    
    decl String:ip[100];
    ReadPackString(datapack, ip, sizeof(ip));
    
    LogError("A2S Socket error on server %s |Type %d, errno %d", ip, errorType, errorNum);
    
    #if defined DEBUG
        LogMessage("A2S Socket error on server %s |Type %d, errno %d", ip, errorType, errorNum);
    #endif
    a2s_OnError(datapack, eA2S_SocketError);
}

public a2s_OnSocketConnected(Handle:socket, any:datapack)
{
    ResetPack(datapack);
    new a2s_QueryType:queryType = ReadPackCell(datapack);
    if(queryType == eA2S_Infos)
        SocketSend(socket, A2S_INFO_QUERY, A2S_INFO_QUERY_SIZE);
    else if(queryType == eA2S_Players)
        SocketSend(socket, A2S_PLAYERS_CHALLENGE_QUERY, A2S_PLAYERS_CHALLENGE_QUERY_SIZE);
}

public a2s_OnSocketReceive(Handle:socket_, const String:receiveData[], const dataSize, any:datapack)
{
    ResetPack(datapack);
    new a2s_QueryType:queryType = ReadPackCell(datapack);
    
    new bool:checksOk = true;
    new dataPos = 0;
    
    new header = a2s_UnpackIntLE(receiveData[dataPos]);
    dataPos += 4;
    
    if(header != A2S_NOSPLIT)
        checksOk = false;
    
    if(checksOk && dataPos < dataSize && queryType == eA2S_Infos && receiveData[dataPos] == A2S_INFO_RESPONSE_ID)
    {
        dataPos++;
        a2s_HandleInfoPacket(receiveData[dataPos], dataSize - dataPos, datapack);
    }
    else if(checksOk && dataPos < dataSize && queryType == eA2S_Players && receiveData[dataPos] == A2S_PLAYERS_CHALLENGE_RESPONSE_ID)
    {
        dataPos++;
        a2s_HandlePlayersChallengePacket(socket_, receiveData[dataPos], dataSize - dataPos, datapack);
    }
    else if(checksOk && dataPos < dataSize && queryType == eA2S_Players && receiveData[dataPos] == A2S_PLAYERS_RESPONSE_ID)
    {
        dataPos++;
        a2s_HandlePlayersPacket(receiveData[dataPos], dataSize - dataPos, datapack);
    }
    else
    {
        a2s_OnError(datapack, eA2S_InvalidResponse);
    }
}

public a2s_OnSocketDisconnect(Handle:socket_, any:datapack)
{
    a2s_OnError(datapack, eA2S_EarlyDisconnect);
}

public Action:a2s_OnTimeout(Handle:timer, any:datapack)
{
    a2s_OnError(datapack, eA2S_TimeOut);
    
    return Plugin_Stop;
}
