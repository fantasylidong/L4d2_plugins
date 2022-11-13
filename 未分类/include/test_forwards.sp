#define PLUGIN_VERSION "1.0"

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

public Plugin myinfo = {
	name = "[DEV] Test 'Autoreload plugins' forwards",
	author = "Dragokas",
	description = "Example of using forwards provided by 'Autoreload plugins'",
	version = PLUGIN_VERSION,
	url = "http://github.com/dragokas"
};

int g_iLockLoad, g_iLockReload, g_iLockUnload;

public void OnPluginStart()
{
	RegAdminCmd("sm_block_reload", 	CmdBlockReload,		ADMFLAG_ROOT, 	"Switch On/Off Blocking plugins from been reloaded");
	RegAdminCmd("sm_block_load", 	CmdBlockLoad, 		ADMFLAG_ROOT,	"Switch On/Off Blocking new plugins from been loaded");
	RegAdminCmd("sm_block_unload", 	CmdBlockUnload, 	ADMFLAG_ROOT,	"Switch On/Off Blocking plugins from been unloaded");
}

public Action CmdBlockReload(int client, int argc)
{
	g_iLockReload ^= 1;
	PrintToChatAll("\x01Plugin reload is: \x04 %s", g_iLockReload ? "blocked" : "allowed");
	return Plugin_Handled;
}

public Action CmdBlockLoad(int client, int argc)
{
	g_iLockLoad ^= 1;
	PrintToChatAll("\x01Plugin load is: \x04 %s", g_iLockLoad ? "blocked" : "allowed");
	return Plugin_Handled;
}

public Action CmdBlockUnload(int client, int argc)
{
	g_iLockUnload ^= 1;
	PrintToChatAll("\x01Plugin unload is: \x04 %s", g_iLockUnload ? "blocked" : "allowed");
	return Plugin_Handled;
}

public void AP_OnPluginUpdate(int pre)
{
	if( pre )
	{
		PrintToChatAll("\x04[Forward]\x01 Update is started ...");
	}
	else {
		PrintToChatAll("\x04[Forward]\x01 Update is ended ...");
	}
}

public Action AP_OnPluginLoad(char[] path, int pre, int status)
{
	PrintToChatAll("\x04[Forward]\x01 %s Load '%s'. Status:\x04 %s", pre ? "(before)" : "(after)", path, StatusToString(status));
	return view_as<Action>(g_iLockLoad);
}

public Action AP_OnPluginReload(char[] path, int pre, int status)
{
	PrintToChatAll("\x04[Forward]\x01 %s Reload '%s'. Status:\x04 %s", pre ? "(before)" : "(after)", path, StatusToString(status));
	return view_as<Action>(g_iLockReload);
}

public Action AP_OnPluginUnload(char[] path, int pre)
{
	PrintToChatAll("\x04[Forward]\x01 %s Unload '%s'", pre ? "(before)" : "(after)", path);
	return view_as<Action>(g_iLockUnload);
}

char[] StatusToString(int status)
{
	char sStatus[16];
	switch( status )
	{
		case -1:				sStatus = "Invalid";
		case Plugin_Running: 	sStatus = "Running";
		case Plugin_Paused: 	sStatus = "Paused";
		case Plugin_Error: 		sStatus = "Error";
		case Plugin_Loaded: 	sStatus = "Loaded";
		case Plugin_Failed: 	sStatus = "Failed";
		case Plugin_Created: 	sStatus = "Created";
		case Plugin_Uncompiled: sStatus = "Uncompiled";
		case Plugin_BadLoad: 	sStatus = "BadLoad";
		case Plugin_Evicted: 	sStatus = "Evicted";
	}
	return sStatus;
}