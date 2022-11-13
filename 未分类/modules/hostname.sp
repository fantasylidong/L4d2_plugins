#pragma semicolon 1
#pragma tabsize 0
#include <sourcemod>
new Handle:cvarMainName = INVALID_HANDLE;
new Handle:cvarServerNameFormatCase1 = INVALID_HANDLE;
new Handle:cvarMpGameMode = INVALID_HANDLE;
new Handle:cvarMpGameMin = INVALID_HANDLE;
new Handle:cvarHostname = INVALID_HANDLE;
public HS_PluginStart()
{
	cvarMainName = CreateConVar("l4d2_hostname", "Do you like VAN♂游♂戏", "Main server name.");
	cvarServerNameFormatCase1 = CreateConVar("sn_hostname_format1", "{hostname}[{gamemode}特{min}秒]", "Hostname format. Case: Confogl or Vanilla without difficulty levels, such as Versus.");
	cvarMpGameMode = FindConVar("l4d_infected_limit");
	cvarMpGameMin = FindConVar("versus_special_respawn_interval");
	cvarHostname = FindConVar("hostname");
	//Hooks
	HookConVarChange(cvarMpGameMode, OnCvarChanged1);
	HookConVarChange(cvarMpGameMin, OnCvarChanged3);
	HookConVarChange(cvarMainName, OnCvarChanged2);
	SetName();
}
public OnConfigsExecuted()
{
	SetName();
}
public OnCvarChanged1(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	SetName();
}
public OnCvarChanged2(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	SetName();
}
public OnCvarChanged3(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	SetName();
}
SetName()
{
	SetVanillaName();
}

SetVanillaName()
{
	decl String:FinalHostname[128];
	decl String:tBuffer[128];
	decl String:Buffer[128];
	GetConVarString(cvarServerNameFormatCase1, FinalHostname, sizeof(FinalHostname));
	GetConVarString(cvarMpGameMode, tBuffer, sizeof(tBuffer));
	GetConVarString(cvarMpGameMin, Buffer, sizeof(Buffer));
	ReplaceString(FinalHostname, sizeof(FinalHostname), "{gamemode}",tBuffer);
	ReplaceString(FinalHostname, sizeof(FinalHostname), "{min}",Buffer);
	ParseNameAndSendToMainConVar(FinalHostname);
}

ParseNameAndSendToMainConVar(String:sBuffer[])
{
	decl String:tBuffer[128];
	GetConVarString(cvarMainName, tBuffer, sizeof(tBuffer));
	ReplaceString(sBuffer, 128, "{hostname}", tBuffer);
	SetConVarString(cvarHostname, sBuffer, false, false);
}