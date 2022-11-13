#include <sourcemod>
#include <redirect>
#undef REQUIRE_PLUGIN
#include <updater>
#define REQUIRE_PLUGIN

#include "redirect/version.sp"

public Plugin:myinfo =
{
    name = "Server Redirect: Ask connect with connect box",
    author = "H3bus",
    description = "Server redirection/follow: Ask connect with connect box",
    version = VERSION,
    url = "http://www.sourcemod.net"
};

#define UPDATE_URL "http://sourcemodplugin.h3bus.fr/redirect/askconnect_connectbox.txt"

public OnPluginStart()
{
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
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
    DisplayAskConnectBox(client, 10.0, ip, password);
}