
#pragma semicolon 1
#include <sourcemod>
#include <socket>

#define RCON_FLAG_KEEP_CONNECTED            0x0000
#define RCON_FLAG_DISCONNECT_AFTER_COMMAND  0x0001
#define RCON_FLAG_CLOSE_AFTER_COMMAND       0x0002
#define RCON_FLAG_CLOSE_ON_ERROR            0x0004
#define RCON_FLAG_AUTO_DISCONNECT           (RCON_FLAG_DISCONNECT_AFTER_COMMAND | RCON_FLAG_DISCONNECT_ON_ERROR)
#define RCON_FLAG_AUTO_CLOSE                (RCON_FLAG_CLOSE_AFTER_COMMAND | RCON_FLAG_CLOSE_ON_ERROR)
// Not implemented yet
#define RCON_FLAG_AUTOLOG_ERRORS            0x0100
#define RCON_FLAG_AUTOLOG_RESPONSE          0x0200
#define RCON_FLAG_LOG_INCLUDE_SERVERIP      0x1000
#define RCON_FLAG_LOG_INCLUDE_COMMAND       0x2000
#define RCON_FLAG_LOG_INCLUDE_PASSWORD      0x4000
#define RCON_AUTOLOG_ALL                    (RCON_FLAG_AUTOLOG_ERRORS | RCON_FLAG_AUTOLOG_RESPONSE)
#define RCON AUTOLOG_INCLUDE_ALL            (RCON_FLAG_LOG_INCLUDE_SERVERIP | RCON_FLAG_LOG_INCLUDE_COMMAND | RCON_FLAG_LOG_INCLUDE_PASSWORD)

#define HANDLE_SIZE             1
#define INT_SIZE                1
#define SERVER_ADDRESS_SIZE     4*30
#define SERVER_PASSWORD_SIZE    4*50
#define MAX_COMMAND_SIZE        4*2000
#define PACKET_BUFFER_SIZE      4096

#define RCON_PACKETTYPE_EXECCOMMAND     2
#define RCON_PACKETTYPE_AUTH            3
#define RCON_PACKETTYPE_RESPONSE        0
#define RCON_PACKETTYPE_AUTH_RESPONSE   2

#define RCON_PACKETID_AUTH              0x80000000
#define RCON_PACKETID_AUTH_FAILED       0xFFFFFFFF
#define RCON_PACKETID_LIMIT             0x00004000
#define RCON_PACKETID_END               0x40000000
#define RCON_GET_USERPACKETID(%1,%2)    ((%1<<16) | %2)
#define RCON_GET_ENDPACKETID(%1)        (%1|RCON_PACKETID_END)
#define RCON_IS_ENDPACKETID(%1)         (%1 != RCON_PACKETID_AUTH_FAILED && %1 & RCON_PACKETID_END != 0)
#define RCON_GET_CMDPACKETID(%1)        (%1 & ~RCON_PACKETID_END)
#define RCON_GET_RCONID_FROMUSERID(%1)  (%1 >> 16)
#define RCON_GET_CMDID_FROMUSERID(%1)   (%1 & 0x0000FFFF)
 
#define RCON_ID_LIMIT                   0x00004000

enum rcon_Errors {
    eRcon_Error_SocketError,
    eRcon_Error_AuthFailed,
    eRcon_Error_EarlySocketDisconnect,
    eRcon_Error_OversizedCommandPacket
}

static String:g_sRcon_ErrorsString[rcon_Errors][26] =
{
    "Socket error",
    "Authorisation Refused",
    "Socket disconnected early",
    "Oversized command packet"
};

static String:g_sRcon_SocketErrorsString[7][14] =
{
    "Empty Host",
    "No Host",
    "Connect Error",
    "Send Error",
    "Bind Error",
    "Recv Error",
    "Listen Error"
};

functag public rcon_errorCB(id, any:arg, rcon_Errors:rconError, errorType, errorNum);

functag public rcon_EndCB(id, any:arg);

functag public rcon_ReceiveCB(id, any:arg, String:buffer[], size);
    
static Handle:g_hRconList = INVALID_HANDLE;
static g_iRconCommandId = 0;
static g_iRconId = 0;

enum rcon_SocketStatus {
    eRcon_Socket_Closed,
    eRcon_Socket_Disconnected,
    eRcon_Socket_Connected,
    eRcon_Socket_Connecting
}

enum rcon_Connection_Status {
    eRcon_NotAuthorized,
    eRcon_Authorizing,
    eRcon_Authorized
}

enum  rcon_CommandQueue_StructureElements {
    rcon_CommandQueue_StructureElement_Id,
    rcon_CommandQueue_StructureElement_Command,
    rcon_CommandQueue_StructureElement_Arg,
    rcon_CommandQueue_StructureElement_ReceiveCallback,
    rcon_CommandQueue_StructureElement_EndCallback,
    rcon_CommandQueue_StructureElement_ErrorCallback,
    rcon_CommandQueue_StructureElement_Flags,
    rcon_CommandQueue_StructureElement_COUNT
}

static rcon_CommandQueue_StructureElementsSize[_:rcon_CommandQueue_StructureElements] =
{
    INT_SIZE,               // rcon_CommandQueue_StructureElement_Id
    MAX_COMMAND_SIZE,       // rcon_CommandQueue_StructureElement_Command
    INT_SIZE,               // rcon_CommandQueue_StructureElement_Arg
    HANDLE_SIZE,            // rcon_CommandQueue_StructureElement_ReceiveCallback
    HANDLE_SIZE,            // rcon_CommandQueue_StructureElement_EndCallback
    HANDLE_SIZE,            // rcon_CommandQueue_StructureElement_ErrorCallback
    INT_SIZE,               // rcon_CommandQueue_StructureElement_Flags
};

enum rcon_StructureElements {
    rcon_StructureElement_Id,
    rcon_StructureElement_SocketHandle,
    rcon_StructureElement_ServerIp,
    rcon_StructureElement_RconPassword,
    rcon_StructureElement_SocketStatus,
    rcon_StructureElement_RconStatus,
    rcon_StructureElement_RconCommandQueue,
    rcon_StructureElement_RconCommandQueueSendPointer,
    rcon_StructureElements_COUNT
}

static rcon_StructureElementsSize[_:rcon_StructureElements] =
{
    INT_SIZE,               // rcon_StructureElement_Id
    HANDLE_SIZE,            // rcon_StructureElement_SocketHandle
    SERVER_ADDRESS_SIZE,    // rcon_StructureElement_ServerIp
    SERVER_PASSWORD_SIZE,   // rcon_StructureElement_RconPassword
    INT_SIZE,               // rcon_StructureElement_SocketStatus
    INT_SIZE,               // rcon_StructureElement_RconStatus
    INT_SIZE,               // rcon_StructureElement_RconCommandId
    HANDLE_SIZE,            // rcon_StructureElement_RconCommandQueue
    INT_SIZE,               // rcon_StructureElement_RconCommandQueueSendPointer
};

stock Handle:rcon_CommandQueue_Create()
{
    new Handle:queue = CreateArray(HANDLE_SIZE, _:rcon_CommandQueue_StructureElement_COUNT);
    
    for (new index = 0; index < _:rcon_CommandQueue_StructureElement_COUNT; index++)
    {
        SetArrayCell(queue, index, CreateArray(rcon_CommandQueue_StructureElementsSize[index]));
    }
    
    return queue;
}

stock Handle:rcon_CommandQueue_Clear(Handle:queue)
{
    for (new index = 0; index < _:rcon_CommandQueue_StructureElement_COUNT; index++)
    {
        ClearArray(GetArrayCell(queue, index));
    }
}

stock rcon_CommandQueue_Close(Handle:queue)
{
    for (new index = 0; index < _:rcon_CommandQueue_StructureElement_COUNT; index++)
    {
        CloseHandle(GetArrayCell(queue, index));
    }
    
    CloseHandle(queue);
}

stock rcon_CommandQueue_HasFlags(Handle:queue, index, flags)
{
    return flags & GetArrayCell(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Flags), index);
}

stock rcon_CommandQueue_AddCommand(Handle:queue, id, String:command[], any:arg, rcon_ReceiveCB:rCB=rcon_ReceiveCB:INVALID_HANDLE, rcon_EndCB:enCB=rcon_EndCB:INVALID_HANDLE, rcon_errorCB:erCB=rcon_errorCB:INVALID_HANDLE, flags=RCON_FLAG_KEEP_CONNECTED)
{
    PushArrayCell(  GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Id),               id);
    PushArrayCell(  GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Arg),              arg);
    PushArrayString(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Command),          command);
    PushArrayCell(  GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_ReceiveCallback),  rCB);
    PushArrayCell(  GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_EndCallback),      enCB);
    PushArrayCell(  GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_ErrorCallback),    erCB);
    PushArrayCell(  GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Flags),            flags);
}

stock rcon_CommandQueue_RemoveCommand(Handle:queue, id)
{
    new index;
    
    if(!rcon_CommandQueue_FindIndexFromId(queue, id, index))
        return;
    
    rcon_CommandQueue_RemoveCommandIndex(queue, index);
}

stock rcon_CommandQueue_RemoveCommandIndex(Handle:queue, index)
{
    RemoveFromArray(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Id),               index);
    RemoveFromArray(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Arg),              index);
    RemoveFromArray(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Command),          index);
    RemoveFromArray(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_ReceiveCallback),  index);
    RemoveFromArray(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_EndCallback),      index);
    RemoveFromArray(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_ErrorCallback),    index);
    RemoveFromArray(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Flags),            index);
}

stock rcon_CommandQueue_GetSize(Handle:queue)
{
    return GetArraySize(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Id));
}

stock rcon_CommandQueue_GetCommand(Handle:queue, index, String:buffer[], size=sizeof(buffer))
{
    GetArrayString(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Command), index, buffer, size);
    return GetArrayCell(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Id), index);
}

stock rcon_CommandQueue_GetArg(Handle:queue, index)
{
    return GetArrayCell(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Arg), index);
}

stock rcon_CommandQueue_GetReceiveCallback(Handle:queue, index)
{
    return GetArrayCell(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_ReceiveCallback), index);
}

stock rcon_CommandQueue_GetEndCallback(Handle:queue, index)
{
    return GetArrayCell(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_EndCallback), index);
}

stock rcon_CommandQueue_GetErrorCallback(Handle:queue, index)
{
    return GetArrayCell(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_ErrorCallback), index);
}

stock rcon_CommandQueue_CallReceiveCallback(Handle:queue, index, id, const String:buffer[], size)
{
    new rcon_ReceiveCB:callback = rcon_ReceiveCB:rcon_CommandQueue_GetReceiveCallback(queue, index);
    
    if(callback == rcon_ReceiveCB:INVALID_HANDLE)
        return;
    
    Call_StartFunction(INVALID_HANDLE, callback);
    Call_PushCell(id);
    Call_PushCell(rcon_CommandQueue_GetArg(queue, index));
    Call_PushString(buffer);
    Call_PushCell(size);
    
    Call_Finish();
}

stock rcon_CommandQueue_CallEndCallback(Handle:queue, index, id)
{
    new rcon_EndCB:callback = rcon_EndCB:rcon_CommandQueue_GetEndCallback(queue, index);
    
    if(callback == rcon_EndCB:INVALID_HANDLE)
        return;
    
    Call_StartFunction(INVALID_HANDLE, callback);
    Call_PushCell(id);
    Call_PushCell(rcon_CommandQueue_GetArg(queue, index));
    
    Call_Finish();
}

stock rcon_CommandQueue_CallErrorCallback(Handle:queue, index, id, rcon_Errors:rconError, errorType, errorNum)
{
    new rcon_errorCB:callback = rcon_errorCB:rcon_CommandQueue_GetErrorCallback(queue, index);
    
    if(callback == rcon_errorCB:INVALID_HANDLE)
        return;
    
    Call_StartFunction(INVALID_HANDLE, callback);
    Call_PushCell(id);
    Call_PushCell(rcon_CommandQueue_GetArg(queue, index));
    Call_PushCell(rconError);
    Call_PushCell(errorType);
    Call_PushCell(errorNum);
    
    Call_Finish();
}

stock rcon_CommandQueue_BroadcastErrorCallback(rconIndex, Handle:queue, rcon_Errors:rconError, errorType, errorNum)
{
    new size = rcon_CommandQueue_GetSize(queue);
    new String:buffer[1];
    
    for(new index = 0; index < size; index++)
    {
        new id = rcon_CommandQueue_GetCommand(queue, index, buffer, 0);
        rcon_CommandQueue_CallErrorCallback(queue, index, RCON_GET_USERPACKETID(rconIndex, id), rconError, errorType, errorNum);
    }
}

stock bool:rcon_CommandQueue_FindIndexFromId(Handle:queue, id, &index)
{
    index = FindValueInArray(GetArrayCell(queue, _:rcon_CommandQueue_StructureElement_Id), id);
    
    if(index == -1)
        return false;
    else
        return true;
}

stock rcon_Init()
{
    g_hRconList = CreateArray(HANDLE_SIZE, _:rcon_StructureElements_COUNT);
    
    for (new index = 0; index < _:rcon_StructureElements_COUNT; index++)
    {
        SetArrayCell(g_hRconList, index, CreateArray(rcon_StructureElementsSize[index]));
    }
}

stock rcon_DeInit()
{
    new size = GetArraySize(GetArrayCell(g_hUserMessages_MessagesArray, rcon_StructureElement_SocketHandle));
    
    for (new index = 0; index < size; index++)
    {
        rcon_Close(index);
        rcon_CommandQueue_Close(GetArrayCell(GetArrayCell(g_hRconList, _rcon_StructureElement_RconCommandQueue), index);
    }
    
    for (new index = 0; index < _:rcon_StructureElements_COUNT; index++)
    {
        CloseHandle(GetArrayCell(g_hRconList, index));
    }
}

stock rcon_SetSocketHandle(rconIndex, Handle:socketHandle)
{
    SetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_SocketHandle), rconIndex, socketHandle);
}

stock Handle:rcon_GetSocketHandle(rconIndex)
{
    return Handle:GetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_SocketHandle), rconIndex);
}

stock rcon_SetSocketAddress(rconIndex, String:socketAddress[])
{
    SetArrayString(GetArrayCell(g_hRconList, _:rcon_StructureElement_ServerIp), rconIndex, socketIp);
}

stock rcon_GetSocketAddress(rconIndex, String:socketAddress[], size = sizeof(socketAddress))
{
    GetArrayString(GetArrayCell(g_hRconList, _:rcon_StructureElement_ServerIp), rconIndex, socketAddress, size);
}

stock rcon_GetSocketIp(rconIndex, &port=0, String:socketIp[], size = sizeof(socketIp))
{
    rcon_GetSocketAddress(rconIndex, socketIp, size);
    
    new colonIndex = FindCharInString(socketIp, ':');
    
    if(colonIndex == -1)
        return;
    
    socketIp[colonIndex] = '\0';
    port = StringToInt(socketIp[colonIndex+1]);
}

stock rcon_SetServerPassword(rconIndex, String:serverPassword[])
{
    SetArrayString(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconPassword), rconIndex, serverPassword);
}

stock rcon_GetServerPassword(rconIndex, String:serverPassword[], size = sizeof(serverPassword))
{
    GetArrayString(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconPassword), rconIndex, serverPassword, size);
}

stock rcon_SetSocketStatus(rconIndex, rcon_SocketStatus:socketStatus)
{
    SetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_SocketStatus), rconIndex, socketStatus);
}

stock rcon_SocketStatus:rcon_GetSocketStatus(rconIndex)
{
    return rcon_SocketStatus:GetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_SocketStatus), rconIndex);
}

stock rcon_SetRconStatus(rconIndex, rcon_Connection_Status:rconStatus)
{
    SetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconStatus), rconIndex, rconStatus);
}

stock rcon_Connection_Status:rcon_GetRconStatus(rconIndex)
{
    return rcon_Connection_Status:GetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconStatus), rconIndex);
}

stock Handle:rcon_GetCommandQueue(rconIndex)
{
    return Handle:GetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconCommandQueue), rconIndex);
}

stock rcon_SetCommandQueueSendPointer(rconIndex, pointer)
{
    SetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconCommandQueueSendPointer), rconIndex, pointer);
}

stock rcon_GetCommandQueueSendPointer(rconIndex)
{
    return GetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconCommandQueueSendPointer), rconIndex);
}

stock rcon_GetId(rconIndex)
{
    return GetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_Id), rconIndex);
}

stock bool:rcon_FindIndexFromId(id, &rconIndex)
{
    rconIndex = FindValueInArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_Id), id);
    
    if(rconIndex != -1)
        return true;
    else
        return false;
}

stock bool:rcon_GetIndexFromUserId(CommandUserId, &rconIndex=0, &commandIndex=0)
{
    new rconId = RCON_GET_RCONID_FROMUSERID(CommandUserId);
    new commandId = RCON_GET_CMDID_FROMUSERID(CommandUserId);
    
    new rconIndex;
    if(!rcon_FindIndexFromId(rconId, rconIndex)
        return;
    
    if(rconIndex >= ArraySize(GetArrayCell(g_hRconList, _:rcon_StructureElement_ServerIp)))
        return false;
    
    new Handle:queue = rcon_GetCommandQueue(rconIndex);
    if(!rcon_CommandQueue_FindIndexFromId(queue, commandId, commandIndex))
        return false;
    
    return true;
}

stock bool:rcon_GetCommandContext_Server(CommandUserId, String:buffer[], size=sizeof(buffer))
{
    new rconIndex;
    
    if(!rcon_GetIndexFromUserId(CommandUserId, rconIndex))
        return false;
    
    rcon_GetSocketAddress(rconIndex, buffer, size);
    
    return true;
}

stock bool:rcon_GetCommandContext_Command(CommandUserId, String:buffer[], size=sizeof(buffer))
{
    new rconIndex;
    new commandIndex;
    
    if(!rcon_GetIndexFromUserId(CommandUserId, rconIndex, commandIndex))
        return false;
    
    new Handle:queue = rcon_GetCommandQueue(rconIndex);
    rcon_CommandQueue_GetCommand(queue, commandIndex, buffer, size);
    
    return true;
}

stock rcon_IncCommandId(rconIndex)
{
    g_iRconCommandId++;
    if(g_iRconCommandId >= RCON_PACKETID_LIMIT)
        g_iRconCommandId = 0;
        
    return g_iRconCommandId;
}

stock rcon_AddCommand(rconIndex, String:command[], any:arg, rcon_ReceiveCB:rCB=rcon_ReceiveCB:INVALID_HANDLE, rcon_EndCB:enCB=rcon_EndCB:INVALID_HANDLE, rcon_errorCB:erCB=rcon_errorCB:INVALID_HANDLE, flags=RCON_FLAG_KEEP_CONNECTED)
{
    new id = rcon_IncCommandId(rconIndex);
    new Handle:queue = rcon_GetCommandQueue(rconIndex);
    
    rcon_CommandQueue_AddCommand(queue, id, command, arg, rCB, enCB, erCB, flags);
    
    return id;
}

stock rcon_RemoveCommand(rconIndex, id)
{
    new Handle:queue = rcon_GetCommandQueue(rconIndex);
    new index;
    
    if(!rcon_CommandQueue_FindIndexFromId(queue, id, index))
        return;
    
    rcon_CommandQueue_RemoveCommand(queue, index);
    
    new pointer = rcon_GetCommandQueueSendPointer(rconIndex);
    if(pointer > index)
        rcon_SetCommandQueueSendPointer(rconIndex, pointer-1);
}

stock rcon_GetNextCommand(rconIndex, &id, String:buffer[], size=sizeof(buffer))
{
    new Handle:queue = rcon_GetCommandQueue(rconIndex);
    new queueSize = rcon_CommandQueue_GetSize(queue);
    new pointer = rcon_GetCommandQueueSendPointer(rconIndex);
    
    if(pointer < queueSize-1)
    {
        pointer++;
        rcon_SetCommandQueueSendPointer(rconIndex, pointer);
        id = rcon_CommandQueue_GetCommand(queue, pointer, buffer, size);
        return true;
    }
    else
        return false;
}

stock rcon_CommandEnded(rconIndex, id)
{
    new Handle:queue = rcon_GetCommandQueue(rconIndex);
    new index;
    
    if(!rcon_CommandQueue_FindIndexFromId(queue, id, index))
        return;
    
    rcon_CommandQueue_CallEndCallback(queue, index, RCON_GET_USERPACKETID(rconIndex, id));
    
    new bool:disconnectRequest = false;
    new bool:closeRequest = false;
    
    if(rcon_CommandQueue_GetSize(queue) == 1)
    {
        if(rcon_CommandQueue_HasFlags(queue, index, RCON_FLAG_CLOSE_AFTER_COMMAND))
            closeRequest = true;
        else if(rcon_CommandQueue_HasFlags(queue, index, RCON_FLAG_DISCONNECT_AFTER_COMMAND))
            disconnectRequest = true;
    }
    
    rcon_RemoveCommand(rconIndex, index);
    
    if(closeRequest)
        rcon_RemoveRcon(rconIndex);
    else if(disconnectRequest)
        rcon_Disconnect(rconIndex);
}

stock rcon_CommandReceive(rconIndex, id, const String:buffer[], size)
{
    new Handle:queue = rcon_GetCommandQueue(rconIndex);
    new index;
    
    if(!rcon_CommandQueue_FindIndexFromId(queue, id, index))
        return;
    
    rcon_CommandQueue_CallReceiveCallback(queue, index, RCON_GET_USERPACKETID(rconIndex, id), buffer, size);
}

stock rcon_BroadcastError(rconIndex, rcon_Errors:rconError, errorType, errorNum)
{
    new Handle:queue = rcon_GetCommandQueue(rconIndex);
    
    rcon_CommandQueue_BroadcastErrorCallback(rconIndex, queue, rconError, errorType, errorNum);
    rcon_CommandQueue_Clear(queue);
    rcon_SetCommandQueueSendPointer(rconIndex, -1);
}

stock rcon_CommandError(rconIndex, id, rcon_Errors:rconError, errorType, errorNum)
{
    new Handle:queue = rcon_GetCommandQueue(rconIndex);
    new index;
   
    if(!rcon_CommandQueue_FindIndexFromId(queue, id, index))
        return;
    
    rcon_CommandQueue_CallErrorCallback(queue, index, RCON_GET_USERPACKETID(rconIndex, id), rconError, errorType, errorNum);
    rcon_RemoveCommand(rconIndex, id);
}

stock rcon_IncId()
{
    g_iRconId++;
    if(g_iRconId >= RCON_ID_LIMIT)
        g_iRconId = 0;
        
    return g_iRconId;
}

stock rcon_CreateRcon(String:serverIp[], String:serverPassword[])
{
    new rconIndex = PushArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_Id),rcon_IncId());
    PushArrayCell(  GetArrayCell(g_hRconList, _:rcon_StructureElement_SocketHandle),    INVALID_HANDLE);
    PushArrayString(GetArrayCell(g_hRconList, _:rcon_StructureElement_ServerIp),        serverIp);
    PushArrayString(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconPassword),    serverPassword);
    PushArrayCell(  GetArrayCell(g_hRconList, _:rcon_StructureElement_SocketStatus),    eRcon_Socket_Closed);
    PushArrayCell(  GetArrayCell(g_hRconList, _:rcon_StructureElement_RconStatus),      eRcon_NotAuthorized);
    PushArrayCell(  GetArrayCell(g_hRconList, _:rcon_StructureElement_RconCommandQueue),rcon_CommandQueue_Create());
    PushArrayCell(  GetArrayCell(g_hRconList, _:rcon_StructureElement_RconCommandQueueSendPointer),-1);
    
    return rconIndex;
}

stock rcon_RemoveRcon(rconIndex)
{
    rcon_Disconnect(rconIndex);
    rcon_CommandQueue_Close(GetArrayCell(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconCommandQueue), rconIndex));
    
    RemoveFromArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_Id),              rconIndex);
    RemoveFromArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_SocketHandle),    rconIndex);
    RemoveFromArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_ServerIp),        rconIndex);
    RemoveFromArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconPassword),    rconIndex);
    RemoveFromArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_SocketStatus),    rconIndex);
    RemoveFromArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconStatus),      rconIndex);
    RemoveFromArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconCommandQueue),rconIndex);
    RemoveFromArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_RconCommandQueueSendPointer), rconIndex);
    
    return rconIndex;
}

rcon_CreateSocket(rconIndex)
{
    new Handle:socket = SocketCreate(SOCKET_TCP, rcon_OnSocketError);
    SocketSetArg(socket, rcon_GetId(rconIndex));
    
    rcon_SetSocketHandle(rconIndex, socket);
    rcon_SetSocketStatus(rconIndex, eRcon_Socket_Disconnected);
}

stock rcon_Disconnect(rconIndex)
{
    if(rcon_GetSocketStatus(rconIndex) > eRcon_Socket_Disconnected)
    {
        SocketDisconnect(rcon_GetSocketHandle(rconIndex));
        CloseHandle(rcon_GetSocketHandle(rconIndex));
        
        rcon_SetSocketStatus(rconIndex, eRcon_Socket_Closed);
        rcon_SetRconStatus(rconIndex, eRcon_NotAuthorized);
    }
    
    rcon_BroadcastError(rconIndex, eRcon_Error_EarlySocketDisconnect, 0, 0);
}

stock rcon_Process(rconIndex)
{
    if(rcon_GetSocketStatus(rconIndex) == eRcon_Socket_Closed)
    {
        rcon_CreateSocket(rconIndex);
    }
    
    if(rcon_GetSocketStatus(rconIndex) == eRcon_Socket_Disconnected)
    {
        new String:serverIp[SERVER_ADDRESS_SIZE];
        new serverPort;
        
        rcon_GetSocketIp(rconIndex, serverPort, serverIp);
        rcon_SetSocketStatus(rconIndex, eRcon_Socket_Connecting);
        SocketConnect(rcon_GetSocketHandle(rconIndex), rcon_OnSocketConnected,
                                                       rcon_OnSocketReceive,
                                                       rcon_OnSocketDisconnect,
                                                       serverIp,
                                                       serverPort);
    }
    else if(
            rcon_GetRconStatus(rconIndex) == eRcon_NotAuthorized && 
            rcon_GetSocketStatus(rconIndex) == eRcon_Socket_Connected
           )
    {
        rcon_SetRconStatus(rconIndex, eRcon_Authorizing);
        new String:serverPassword[SERVER_PASSWORD_SIZE];
        rcon_GetServerPassword(rconIndex, serverPassword);
        rcon_CreateAndSendCommand(rconIndex, RCON_PACKETID_AUTH, RCON_PACKETTYPE_AUTH, serverPassword);
    }
    else if(
            rcon_GetRconStatus(rconIndex) == eRcon_Authorized && 
            rcon_GetSocketStatus(rconIndex) == eRcon_Socket_Connected
           )
    {
        while(rcon_processCommands(rconIndex)) {}
    }
        
}

stock rcon_processCommands(rconIndex)
{
    new String:buffer[MAX_COMMAND_SIZE];
    new commandId;
    
    if(rcon_GetNextCommand(rconIndex, commandId, buffer, sizeof(buffer)))
    {
        new userId = RCON_GET_USERPACKETID(rcon_GetId(rconIndex), commandId);
        rcon_CreateAndSendCommand(rconIndex, userId, RCON_PACKETTYPE_EXECCOMMAND, buffer);
        buffer[0] = '\0';
        rcon_CreateAndSendCommand(rconIndex, RCON_GET_ENDPACKETID(userId), RCON_PACKETTYPE_EXECCOMMAND, buffer);
        return true;
    }
    else
        return false;
    
}

stock rcon_SendCommand(String:serverIp[], String:serverPassword[], String:command[], any:arg=0, rcon_ReceiveCB:rCB=rcon_ReceiveCB:INVALID_HANDLE, rcon_EndCB:enCB=rcon_EndCB:INVALID_HANDLE, rcon_errorCB:erCB=rcon_errorCB:INVALID_HANDLE, flags=RCON_FLAG_KEEP_CONNECTED)
{
    new rconIndex = FindStringInArray(GetArrayCell(g_hRconList, _:rcon_StructureElement_ServerIp), serverIp);
    
    if(rconIndex == -1)
        rconIndex = rcon_CreateRcon(serverIp, serverPassword);
    else
        rcon_SetServerPassword(rconIndex, serverPassword);
    
    new commandId = rcon_AddCommand(rconIndex, command, arg, rCB, enCB, erCB, flags);
    
    rcon_Process(rconIndex);
    
    return RCON_GET_USERPACKETID(rcon_GetId(rconIndex), commandId);
}

stock rcon_PackIntLE(integer, String:packet[])
{
    packet[0] = integer & 0xFF;
    packet[1] = (integer & 0xFF00) >> 8;
    packet[2] = (integer & 0xFF0000) >> 16;
    packet[3] = integer >> 24;
    
    return 4;
}

stock rcon_PackString(String:str[], String:packet[], size=sizeof(packet))
{
    return strcopy(packet, size, str) + 1;
}

stock rcon_UnpackIntLE(const String:packet[])
{
    return (packet[3] << 24) + (packet[2] << 16) + (packet[1] << 8) + packet[0];
}

stock bool:rcon_CreateAndSendCommand(rconIndex, packetId, packetType, String:packetBody[])
{
    new String:packetOut[PACKET_BUFFER_SIZE+1];
    
    new pos = 4;
    pos += rcon_PackIntLE(packetId, packetOut[pos]);
    pos += rcon_PackIntLE(packetType, packetOut[pos]);
    pos += rcon_PackString(packetBody, packetOut[pos], sizeof(packetOut)-pos);

    new packetLength = pos;
    if(packetLength > sizeof(packetOut)-1)
    {
        rcon_CommandError(rconIndex, packetId, eRcon_Error_OversizedCommandPacket, 0, 0);
        return false;
    }
    
    rcon_PackIntLE(packetLength-4, packetOut[0]);
    
    SocketSend(rcon_GetSocketHandle(rconIndex), packetOut, packetLength);
    
    return true;
}

stock rcon_CheckAuth(rconIndex, packetId, packetType, const String:packet[])
{
    if(packetId == RCON_PACKETID_AUTH && packetType == RCON_PACKETTYPE_AUTH_RESPONSE)
    {
        rcon_SetRconStatus(rconIndex, eRcon_Authorized);
        rcon_Process(rconIndex);
    }
    else if(packetId == RCON_PACKETID_AUTH_FAILED && packetType == RCON_PACKETTYPE_AUTH_RESPONSE)
    {
        rcon_SetRconStatus(rconIndex, eRcon_NotAuthorized);
        rcon_BroadcastError(rconIndex, eRcon_Error_AuthFailed, 0, 0);
    }
}

stock rcon_GetErrorString(rcon_Errors:rconError, errorType, errorNum, String:buffer[], size=sizeof(buffer))
{
    if(rconError == eRcon_Error_SocketError)
        Format(buffer, size, "%s: %s (errno.h Error %d)", g_sRcon_ErrorsString[rconError], g_sRcon_SocketErrorsString[errorType], errorNum);
    else
        Format(buffer, size, "%s", g_sRcon_ErrorsString[rconError]);
}

// CallBacks
public rcon_OnSocketError(Handle:socket, const errorType, const errorNum, any:arg)
{
    new rconIndex;
    if(!rcon_FindIndexFromId(arg, rconIndex))
        return;
    
    CloseHandle(rcon_GetSocketHandle(rconIndex));
    
    rcon_SetSocketStatus(rconIndex, eRcon_Socket_Closed);
    rcon_SetRconStatus(rconIndex, eRcon_NotAuthorized);
    
    rcon_BroadcastError(rconIndex, eRcon_Error_SocketError, errorType, errorNum);
}

public rcon_OnSocketConnected(Handle:socket, any:arg)
{
    new rconIndex;
    if(!rcon_FindIndexFromId(arg, rconIndex))
        return;
    
    rcon_SetSocketStatus(rconIndex, eRcon_Socket_Connected);
    rcon_SetRconStatus(rconIndex, eRcon_NotAuthorized);
    
    rcon_Process(rconIndex);
}

public rcon_OnSocketReceive(Handle:socket, const String:receiveData[], const dataSize, any:arg)
{
    new bodySize = rcon_UnpackIntLE(receiveData[0]);
    new packetId = rcon_UnpackIntLE(receiveData[4]);
    new packetType = rcon_UnpackIntLE(receiveData[8]);
    
    new rconIndex;
    if(!rcon_FindIndexFromId(arg, rconIndex))
        return;
    
    if(packetType == RCON_PACKETTYPE_AUTH_RESPONSE)
    {
        rcon_CheckAuth(rconIndex, packetId, packetType, receiveData);
    }
    else if(packetType == RCON_PACKETTYPE_RESPONSE && RCON_IS_ENDPACKETID(packetId))
    {
        rcon_CommandEnded(rconIndex, RCON_GET_CMDID_FROMUSERID(RCON_GET_CMDPACKETID(packetId)));
    }
    else if(packetType == RCON_PACKETTYPE_RESPONSE)
    {
        rcon_CommandReceive(rconIndex, RCON_GET_CMDID_FROMUSERID(packetId), receiveData[12], bodySize-8);
    }
}

public rcon_OnSocketDisconnect(Handle:socket, any:arg)
{
    new rconIndex;
    if(!rcon_FindIndexFromId(arg, rconIndex))
        return;
    
    CloseHandle(rcon_GetSocketHandle(rconIndex));
    
    rcon_SetSocketStatus(rconIndex, eRcon_Socket_Closed);
    rcon_SetRconStatus(rconIndex, eRcon_NotAuthorized);
    
    rcon_BroadcastError(rconIndex, eRcon_Error_EarlySocketDisconnect, 0, 0);
}
