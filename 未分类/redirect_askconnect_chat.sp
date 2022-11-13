#include <sourcemod>
#include <redirect>
#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN

#include "redirect/version.sp"

public Plugin:myinfo =
{
    name = "Server Redirect: Ask connect in chat",
    author = "H3bus",
    description = "Server redirection/follow: Ask connect in chat",
    version = VERSION,
    url = "http://www.sourcemod.net"
};

#define UPDATE_URL "http://sourcemodplugin.h3bus.fr/redirect/askconnect_chat.txt"

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
    PrintToChat(client, "%t", "Connect by CC URL");
    PrintToChat(client, "%t", "Connect URL", ip, password);
}