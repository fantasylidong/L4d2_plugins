#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <discord_webhook>
#include <SteamWorks>

#define CONBUFSIZELARGE         (1 << 12)       // 4k

public Plugin myinfo =
{
    name = "Discord Webhook",
    author = "devilesk",
    version = "1.2.0",
    description = "Discord webhook functions.",
    url = "https://github.com/devilesk/rl4d2l-plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("discord_webhook");

    CreateNative("FormatEmbed", Native_FormatEmbed);
    CreateNative("FormatEmbed2", Native_FormatEmbed2);
    CreateNative("FormatEmbedRequest", Native_FormatEmbedRequest);
    CreateNative("SendEmbedToDiscord", Native_SendEmbedToDiscord);
    CreateNative("SendMessageToDiscord", Native_SendMessageToDiscord);
    CreateNative("SendToDiscord", Native_SendToDiscord);

    return APLRes_Success;
}

public int Native_FormatEmbed(Handle plugin, int numParams)
{
    int bufferLen = GetNativeCell(2);
    if (bufferLen < 1) { return 0; }

    char[] buffer = new char[bufferLen+1];

    int len;

    GetNativeStringLength(3, len);
    char[] title = new char[len+1];
    GetNativeString(3, title, len+1);

    GetNativeStringLength(4, len);
    char[] description = new char[len+1];
    GetNativeString(4, description, len+1);

    GetNativeStringLength(5, len);
    char[] url = new char[len+1];
    GetNativeString(5, url, len+1);
    
    int color = GetNativeCell(6);
    
    char fields[CONBUFSIZELARGE];
    char name[256];
    char value[256];
    int inline;
    
    for (int i = 7; i <= numParams; i+=3)
    {
        // field name
        GetNativeStringLength(i, len);
        if (len <= 0) { return 0; }
        GetNativeString(i, name, len+1);
        
        // field value
        GetNativeStringLength(i+1, len);
        if (len <= 0) { return 0; }
        GetNativeString(i+1, value, len+1);
        
        inline = GetNativeCellRef(i+2);
        
        if (i == 7)
        {
            Format(fields, CONBUFSIZELARGE, "{\"name\":\"%s\",\"value\":\"%s\",\"inline\":%d}", name, value, inline);
        }
        else
        {
            Format(fields, CONBUFSIZELARGE, "%s,{\"name\":\"%s\",\"value\":\"%s\",\"inline\":%d}", fields, name, value, inline);
        }
    }

    InternalFormatEmbed(buffer, bufferLen, title, description, url, color, fields);
    
    SetNativeString(1, buffer, bufferLen+1, false);

    return 1;
}

public int Native_FormatEmbed2(Handle plugin, int numParams)
{
    int bufferLen = GetNativeCell(2);
    if (bufferLen < 1) { return 0; }

    char[] buffer = new char[bufferLen+1];

    int len;

    GetNativeStringLength(3, len);
    char[] title = new char[len+1];
    GetNativeString(3, title, len+1);

    GetNativeStringLength(4, len);
    char[] description = new char[len+1];
    GetNativeString(4, description, len+1);

    GetNativeStringLength(5, len);
    char[] url = new char[len+1];
    GetNativeString(5, url, len+1);
    
    int color = GetNativeCell(6);

    GetNativeStringLength(7, len);
    char[] fields = new char[len+1];
    GetNativeString(7, fields, len+1);

    InternalFormatEmbed(buffer, bufferLen+1, title, description, url, color, fields);
    SetNativeString(1, buffer, bufferLen+1, false);

    return 1;
}

public int Native_FormatEmbedRequest(Handle plugin, int numParams)
{
    int bufferLen = GetNativeCell(2);
    if (bufferLen < 1) { return 0; }

    char[] buffer = new char[bufferLen+1];

    int len;

    GetNativeStringLength(3, len);
    if (len <= 0) { return 0; }
    char[] message = new char[len+1];
    GetNativeString(3, message, len+1);

    InternalFormatEmbedRequest(buffer, bufferLen+1, message);
    
    SetNativeString(1, buffer, bufferLen+1, false);

    return 1;
}

public int Native_SendEmbedToDiscord(Handle plugin, int numParams)
{
    int len;

    GetNativeStringLength(1, len);
    if (len <= 0) { return 0; }
    char[] webhook = new char[len+1];
    GetNativeString(1, webhook, len+1);

    GetNativeStringLength(2, len);
    char[] title = new char[len+1];
    GetNativeString(2, title, len+1);

    GetNativeStringLength(3, len);
    char[] description = new char[len+1];
    GetNativeString(3, description, len+1);

    GetNativeStringLength(4, len);
    char[] url = new char[len+1];
    GetNativeString(4, url, len+1);
    
    int color = GetNativeCell(5);
    
    char fields[CONBUFSIZELARGE];
    char name[256];
    char value[256];
    int inline;
    
    for (int i = 6; i <= numParams; i+=3)
    {
        // field name
        GetNativeStringLength(i, len);
        if (len <= 0) { return 0; }
        GetNativeString(i, name, len+1);
        
        // field value
        GetNativeStringLength(i+1, len);
        if (len <= 0) { return 0; }
        GetNativeString(i+1, value, len+1);
        
        inline = GetNativeCellRef(i+2);
        
        if (i == 6)
        {
            Format(fields, CONBUFSIZELARGE, "{\"name\":\"%s\",\"value\":\"%s\",\"inline\":%d}", name, value, inline);
        }
        else
        {
            Format(fields, CONBUFSIZELARGE, "%s,{\"name\":\"%s\",\"value\":\"%s\",\"inline\":%d}", fields, name, value, inline);
        }
    }

    InternalSendEmbedToDiscord(webhook, title, description, url, color, fields);

    return 1;
}

public int Native_SendMessageToDiscord(Handle plugin, int numParams)
{
    int len;

    GetNativeStringLength(1, len);
    if (len <= 0) { return 0; }
    char[] webhook = new char[len+1];
    GetNativeString(1, webhook, len+1);

    GetNativeStringLength(2, len);
    if (len <= 0) { return 0; }
    char[] message = new char[len+1];
    GetNativeString(2, message, len+1);

    InternalSendMessageToDiscord(webhook, message);

    return 1;
}

public int Native_SendToDiscord(Handle plugin, int numParams)
{
    int len;

    GetNativeStringLength(1, len);
    if (len <= 0) { return 0; }
    char[] webhook = new char[len+1];
    GetNativeString(1, webhook, len+1);

    GetNativeStringLength(2, len);
    if (len <= 0) { return 0; }
    char[] message = new char[len+1];
    GetNativeString(2, message, len+1);

    InternalSendToDiscord(webhook, message);

    return 1;
}

void InternalFormatEmbed(char[] buffer, int bufferLen, const char[] title, const char[] description, const char[] url, int color, const char[] fields)
{
    Format(buffer, bufferLen, "{\"title\":\"%s\",\"description\":\"%s\",\"url\":\"%s\",\"color\": %d,\"fields\": [%s]}", title, description, url, color, fields);
}

void InternalFormatEmbedRequest(char[] buffer, int bufferLen, const char[] sMessage)
{
    Format(buffer, bufferLen, "{\"embeds\": [%s]}", sMessage);
}

void InternalSendEmbedToDiscord(const char[] sWebhook, const char[] title, const char[] description, const char[] url, int color, const char[] fields) {
    char sMessage[CONBUFSIZELARGE];
    InternalFormatEmbed(sMessage, sizeof(sMessage), title, description, url, color, fields);
    InternalFormatEmbedRequest(sMessage, sizeof(sMessage), sMessage);
    InternalSendToDiscord(sWebhook, sMessage);
}

void InternalSendMessageToDiscord(const char[] sWebhook, const char[] message) {
    char sMessage[4096];
    Format(sMessage, sizeof(sMessage), "{\"content\":\"%s\"}", message);
    InternalSendToDiscord(sWebhook, sMessage);
}

void InternalSendToDiscord(const char[] sWebhook, const char[] message) {
    char sUrl[512];
    if(!GetWebHook(sWebhook, sUrl, sizeof(sUrl)))
    {
        LogError("Error: Webhook: %s - Url: %s", sWebhook, sUrl);
        return;
    }

    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, sUrl);

    SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", message, strlen(message));
    PrintDebug("[InternalSendToDiscord] request %s", message);
    
    if(request == null || !SteamWorks_SetHTTPCallbacks(request, Discord_Callback) || !SteamWorks_SendHTTPRequest(request)) {
        PrintDebug("[InternalSendToDiscord] failed to fire");
        delete request;
    }
}

public void Discord_Callback(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode) {
    if(!bFailure && bRequestSuccessful) {
        switch (eStatusCode) {
            case k_EHTTPStatusCode200OK, k_EHTTPStatusCode204NoContent:{
                //all gud
            }
            default: {
                PrintDebug("[Discord_Callback] failed with code [%i]", eStatusCode);
                SteamWorks_GetHTTPResponseBodyCallback(hRequest, Print_Response);
            }
        }
    }
    delete hRequest;
}

public void Print_Response(const char[] sData)
{
    PrintDebug("[Print_Response] %s", sData);
}

bool GetWebHook(const char[] sWebhook, char[] sUrl, int iLength)
{
    KeyValues kv = new KeyValues("Discord");

    char sFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/discord_webhook.cfg");

    if (!FileExists(sFile))
    {
        SetFailState("[GetWebHook] \"%s\" not found!", sFile);
        return false;
    }

    kv.ImportFromFile(sFile);

    if (!kv.GotoFirstSubKey())
    {
        SetFailState("[GetWebHook] Can't find webhook for \"%s\"!", sFile);
        return false;
    }

    char sBuffer[64];

    do
    {
        kv.GetSectionName(sBuffer, sizeof(sBuffer));

        if(StrEqual(sBuffer, sWebhook, false))
    {
        kv.GetString("url", sUrl, iLength);
        delete kv;
        return true;
    }
    }
    while (kv.GotoNextKey());

    delete kv;

    return false;
}

stock void PrintDebug(const char[] Message, any ...) {
    char DebugBuff[256];
    VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
    LogMessage(DebugBuff);
}