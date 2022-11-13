#include <sourcemod>
#include <redirect>

#include "redirect/version.sp"

public Plugin:myinfo =
{
    name = "Server Redirect: Ask connect with connect box",
    author = "H3bus",
    description = "Server redirection/follow: Ask connect with TF2 redirect command",
    version = VERSION,
    url = "http://www.sourcemod.net"
};

public OnAskClientConnect(client, String:ip[], String:password[])
{
    ClientCommand(client, "redirect %s", ip);
}
