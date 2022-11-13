
#pragma semicolon 1
#include <sourcemod>
#include <socket>
#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN

#include "redirect/version.sp"

public Plugin:myinfo =
{
    name = "Server Redirect: Ask connect with steambot",
    author = "H3bus",
    description = "Server redirection/follow: Ask connect with steambot",
    version = VERSION,
    url = "http://www.sourcemod.net"
};

#define UPDATE_URL "http://sourcemodplugin.h3bus.fr/redirect/askconnect_steambot.txt"

enum SocketStatus {
    eSocket_Closed,
    eSocket_Disconnected,
    eSocket_Connecting,
    eSocket_Connected
}

new Handle:g_hSocketHandle = INVALID_HANDLE;
new Handle:g_hCommandQueue = INVALID_HANDLE;
new Handle:g_hCvarSocketAddress = INVALID_HANDLE;
new Handle:g_hCvarSocketPort = INVALID_HANDLE;

new SocketStatus:g_SocketStatus = eSocket_Closed;

public OnPluginStart()
{
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
    
    LoadTranslations("redirect.phrases");
    
    g_hCvarSocketAddress    = CreateConVar("redirect_askconnect_steambot_address", "localhost", "Address of the steambot, should always be loacalhost");
    g_hCvarSocketPort       = CreateConVar("redirect_askconnect_steambot_port", "19855", "TCP port of the steambot", .hasMin=true, .min=1.0);
    
    g_hSocketHandle = SocketCreate(SOCKET_TCP, OnSocketError);
    g_SocketStatus = eSocket_Disconnected;
    
    g_hCommandQueue = CreateArray(4096);
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public OnAskClientConnect(client, String:ip[], String:password[])
{
    decl String:steamId[30];
    
    if(GetClientAuthString(client, steamId, sizeof(steamId)))
    {
        decl String:buffer[4096];
        decl String:TranslatedStr[500];
        
        Format(TranslatedStr, sizeof(TranslatedStr), "%T", "Connect by Clicking Link", client);
        Format(buffer, sizeof(buffer), "BCMDCHAT%s|%s\n", steamId, TranslatedStr);
        PushArrayString(g_hCommandQueue, buffer);
        Format(buffer, sizeof(buffer), "BCMDCHAT%s|steam://connect/%s/%s\n", steamId, ip, password);
        PushArrayString(g_hCommandQueue, buffer);
        SocketProcess();
    }
}

stock SocketProcess()
{
    if(g_SocketStatus == eSocket_Closed)
    {
        g_hSocketHandle = SocketCreate(SOCKET_TCP, OnSocketError);
        g_SocketStatus = eSocket_Disconnected;
    }
    
    if(g_SocketStatus == eSocket_Disconnected)
    {
        decl String:host[200];
        GetConVarString(g_hCvarSocketAddress, host, sizeof(host));
        
        g_SocketStatus = eSocket_Connecting;
        SocketConnect(g_hSocketHandle, 
                        OnSocketConnected,
                        OnSocketReceive,
                        OnSocketDisconnect,
                        host,
                        GetConVarInt(g_hCvarSocketPort));
    }
    else if(g_SocketStatus == eSocket_Connected )
    {
        decl String:buffer[4096];
     
        while(GetArraySize(g_hCommandQueue) > 0)
        {
            new length = GetArrayString(g_hCommandQueue, 0, buffer, sizeof(buffer));
            SocketSend(g_hSocketHandle, buffer, length);
            
            RemoveFromArray(g_hCommandQueue, 0);
        }
    }
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:arg)
{
    CloseHandle(g_hSocketHandle);
    g_SocketStatus = eSocket_Closed;
    ClearArray(g_hCommandQueue);
    
    LogError("Socket error %d, %d", errorType, errorNum);
}

public OnSocketConnected(Handle:socket, any:arg)
{
    g_SocketStatus = eSocket_Connected;
    SocketProcess();
}

public OnSocketReceive(Handle:socket, const String:receiveData[], const dataSize, any:arg)
{
}

public OnSocketDisconnect(Handle:socket, any:arg)
{
    g_SocketStatus = eSocket_Disconnected;
    if(GetArraySize(g_hCommandQueue) > 0)
    {
        CreateTimer(3.0, Timer_AfterDisconnect, INVALID_HANDLE);
    }
}

public Action:Timer_AfterDisconnect(Handle:timer)
{
    SocketProcess();
}



