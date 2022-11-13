#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
public Plugin myinfo = {
	name = "hostname",
	author = "东",
	description = "服务器名",
	version = "0.1",
	url = "https://github.com/fantasylidong"
};
new Handle:cvarServerNameFormatCase1 = INVALID_HANDLE;
new Handle:cvarHostPort = INVALID_HANDLE;
new String:SavePath[256];
new Handle:HostName = INVALID_HANDLE;
static		Handle:g_hHostNameFormat, Handle:g_hHostName, Handle:g_hMainName , String:g_sDefaultN[68];
public OnPluginStart()
{
	HostName = CreateKeyValues("AnneHappy1");
	BuildPath(Path_SM, SavePath, 255, "configs/hostname/hostname1.txt");
	if (FileExists(SavePath))
	{
		FileToKeyValues(HostName, SavePath);
	}
	g_hHostName	= FindConVar("hostname");
	g_hMainName = CreateConVar("sn_main_name1", "");
	cvarHostPort = FindConVar("hostport");
	g_hHostNameFormat = CreateConVar("sn_hostname_format2", "{hostname}{gamemode}");
	//cvarServerNameFormatCase1 = CreateConVar("sn_hostname_format1", "[{mode}特{min}秒]");
	cvarServerNameFormatCase1 = CreateConVar("sn_hostname_format3", "[多特模式]");
	GetConVarString(g_hHostName, g_sDefaultN, sizeof(g_sDefaultN));
	if (strlen(g_sDefaultN))
		ChangeServerName();
}
public OnMapStart()
{
	HostName = CreateKeyValues("AnneHappy1");
	BuildPath(Path_SM, SavePath, 255, "configs/hostname/hostname1.txt");
	FileToKeyValues(HostName, SavePath);
}
public OnCvarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	decl  String:sReadyUpCfgName[128];
	decl String:FinalHostname[128];
	GetConVarString(cvarServerNameFormatCase1, FinalHostname, sizeof(FinalHostname));
	/*
	GetConVarString(cvarMpGameMode, tBuffer, sizeof(tBuffer));
	GetConVarString(cvarMpGameMin, Buffer, sizeof(Buffer));
	ReplaceString(FinalHostname, sizeof(FinalHostname), "{mode}",tBuffer);
	ReplaceString(FinalHostname, sizeof(FinalHostname), "{min}",Buffer);
	*/
	sReadyUpCfgName = FinalHostname;
	ChangeServerName(sReadyUpCfgName);
}

public OnConfigsExecuted()
{		
		if (!strlen(g_sDefaultN)) return;
		
		decl  String:sReadyUpCfgName[128];
		decl String:FinalHostname[128];
		//decl String:tBuffer[128];
		//decl String:Buffer[128];
		GetConVarString(cvarServerNameFormatCase1, FinalHostname, sizeof(FinalHostname));
		/*
		GetConVarString(cvarMpGameMode, tBuffer, sizeof(tBuffer));
		GetConVarString(cvarMpGameMin, Buffer, sizeof(Buffer));
		ReplaceString(FinalHostname, sizeof(FinalHostname), "{mode}",tBuffer);
		ReplaceString(FinalHostname, sizeof(FinalHostname), "{min}",Buffer);
		*/
		sReadyUpCfgName = FinalHostname;
		ChangeServerName(sReadyUpCfgName);
	
}
ChangeServerName(String:sReadyUpCfgName[] = "")
{
        new String:sPath[128];
		decl String:ServerPort[128];
		GetConVarString(cvarHostPort, ServerPort, sizeof(ServerPort));
		KvJumpToKey(HostName, ServerPort, false);
		KvGetString(HostName,"servername", sPath, sizeof(sPath));
		KvGoBack(HostName);
        decl String:sNewName[128];
		if(strlen(sReadyUpCfgName) == 0)
		{
			Format(sNewName, sizeof(sNewName), "%s", g_hMainName);
		}
		else
		{
			GetConVarString(g_hHostNameFormat, sNewName, sizeof(sNewName));
			ReplaceString(sNewName, sizeof(sNewName), "{hostname}", sPath);
			ReplaceString(sNewName, sizeof(sNewName), "{gamemode}", sReadyUpCfgName);
		}
		SetConVarString(g_hHostName,sNewName);
		Format(g_sDefaultN,sizeof(g_sDefaultN),"%s",sNewName);
}