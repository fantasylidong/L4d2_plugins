#include <sourcemod>
#include <redirect>
#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN

#include "redirect/version.sp"

public Plugin:myinfo =
{
    name = "Server Redirect: Ask connect in console",
    author = "H3bus",
    description = "Server redirection/follow: Ask connect in console",
    version = VERSION,
    url = "http://www.sourcemod.net"
};

#define UPDATE_URL "http://sourcemodplugin.h3bus.fr/redirect/askconnect_console.txt"

public OnPluginStart()
{
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
    
    LoadTranslations("redirect.phrases");
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
    PrintToChat(client, "%t", "Connect infos in console");
    
    PrintToConsole(client, " _____________________________________________________________________");
    PrintToConsole(client, "%t", "Connect by CC console");
    if(password[0] == '\0')
        PrintToConsole(client, "connect %s", ip);
    else
        PrintToConsole(client, "connect %s; password %s", ip, password);
    PrintToConsole(client, "_____________________________________________________________________");
}
