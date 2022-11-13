// Original autoexecconfig include file by Impact: https://forums.alliedmods.net/showthread.php?t=204254
#if defined _antispeedrunnersystem_included
	#endinput
#endif
#define _antispeedrunnersystem_included
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <adminmenu>
#define ASS_PREFIX "[ASS]"
#define ASS_PREFIX01 "\x04[ASS]\x01"
#define ASS_PREFIX03 "\x04[ASS]\x03"
#define ASS_PREFIX05 "\x04[ASS]\x05"
#define ASS_NAME "Anti-Speedrunner System"
#define ASS_AUTHOR "Psyk0tik (Crasher_3637)"
#define ASS_DESCRIPTION "The Anti-Speedrunner System provides various options for dealing with players that speedrun through campaigns and making sure survivors stick together!"
#define ASS_VERSION "28.0"
#define ASS_URL "https://forums.alliedmods.net/showthread.php?t=302868"
#define ASS_APPEND_BAD_FILENAME 0
#define ASS_APPEND_FILE_NOT_FOUND 1
#define ASS_APPEND_BAD_HANDLE 2
#define ASS_APPEND_SUCCESS 3
#define ASS_FIND_BAD_FILENAME 10
#define ASS_FIND_FILE_NOT_FOUND 11
#define ASS_FIND_BAD_HANDLE 12
#define ASS_FIND_NOT_FOUND 13
#define ASS_FIND_SUCCESS 14
#define ASS_CLEAN_FILE_NOT_FOUND 20
#define ASS_CLEAN_BAD_HANDLE 21
#define ASS_CLEAN_SUCCESS 22
#define ASS_NO_CONFIG 30
#define ASS_FORMAT_BAD_FILENAME 40
#define ASS_FORMAT_SUCCESS 41

// Configs
static bool bCreateDirectory = false;
static bool bCreateFile = false;
static char sConfigFile[PLATFORM_MAX_PATH];
static char sRawFileName[PLATFORM_MAX_PATH];
static char sFolderPath[PLATFORM_MAX_PATH];
static Handle hPluginHandle = null;
static int iCreateDirectoryMode = FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_O_READ|FPERM_O_EXEC;
static int iLastFindResult;
static int iLastAppendResult;

stock int ASS_GetFindResult()
{
	return iLastFindResult;
}

stock int ASS_GetAppendResult()
{
	return iLastAppendResult;
}

stock void ASS_CreateConfig(bool create)
{
	bCreateFile = create;
}

stock void ASS_CreateDirectory(bool create, int mode = FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_O_READ|FPERM_O_EXEC)
{
	bCreateDirectory = create;
	iCreateDirectoryMode = mode;
}

stock bool ASS_GetCreateFile()
{
	return bCreateFile;
}

stock void ASS_SetPlugin(Handle plugin)
{
	hPluginHandle = plugin;
}

stock Handle ASS_GetPlugin()
{
	return hPluginHandle;
}

stock bool ASS_Config(char[] file, char[] folder = "sourcemod/anti-speedrunner_system")
{
	Format(sConfigFile, sizeof(sConfigFile), "%s", file);
	strcopy(sRawFileName, sizeof(sRawFileName), file);
	strcopy(sFolderPath, sizeof(sFolderPath), folder);
	return ASS_FormatConfig(sConfigFile, sizeof(sConfigFile), folder) == ASS_FORMAT_SUCCESS;
}

stock bool ASS_GetConfig(char[] buffer, int size)
{
	if (strlen(sConfigFile) > 0)
	{
		strcopy(buffer, size, sConfigFile);
		return true;
	}
	buffer[0] = '\0';
	return false;
}

stock ConVar ASS_ConVar(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
	if (!(flags & FCVAR_DONTRECORD) && strlen(sConfigFile) > 0)
	{
		iLastFindResult = -1;
		iLastAppendResult = -1;
		char sValue[64];
		iLastFindResult = ASS_FindValue(name, sValue, sizeof(sValue), true);
		if (iLastFindResult == ASS_FIND_NOT_FOUND || (iLastFindResult == ASS_FIND_FILE_NOT_FOUND && bCreateFile))
		{
			iLastAppendResult = ASS_Append(name, defaultValue, description, flags, hasMin, min, hasMax, max);
		}
	}
	return CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
}

stock void ASS_ExecConfig()
{
	AutoExecConfig(!bCreateFile, sRawFileName, sFolderPath);
}

stock static int ASS_FormatConfig(char[] buffer, int size, char[] folder = "sourcemod/anti-speedrunner_system")
{
	if (strlen(sConfigFile) < 1)
	{
		return ASS_NO_CONFIG;
	}
	if (StrContains(sConfigFile, ".cfg") != -1 && strlen(sConfigFile) < 4)
	{
		return ASS_FORMAT_BAD_FILENAME;
	}
	char sPathPrefix[PLATFORM_MAX_PATH];
	if (strlen(folder) > 0)
	{
		Format(sPathPrefix, sizeof(sPathPrefix), "cfg/%s/", folder);
		if (bCreateDirectory && !DirExists(sPathPrefix))
		{
			CreateDirectory(sPathPrefix, iCreateDirectoryMode);
		}
	}
	else
	{
		Format(sPathPrefix, sizeof(sPathPrefix), "cfg/");
	}
	char sFile[PLATFORM_MAX_PATH];
	sFile[0] = '\0';
	if (StrContains(buffer, sPathPrefix) != 0)
	{
		StrCat(sFile, sizeof(sFile), sPathPrefix);
	}
	StrCat(sFile, sizeof(sFile), sConfigFile);
	if (StrContains(sFile[strlen(sFile) - 4], ".cfg") != 0)
	{
		StrCat(sFile, sizeof(sFile), ".cfg");
	}
	strcopy(buffer, size, sFile);
	return ASS_FORMAT_SUCCESS;
}

stock int ASS_Append(const char[] name, const char[] defaultValue, const char[] description, int flags, bool hasMin, float min, bool hasMax, float max)
{
	if (strlen(sConfigFile) < 1)
	{
		return ASS_NO_CONFIG;
	}
	char sFile[PLATFORM_MAX_PATH];
	strcopy(sFile, sizeof(sFile), sConfigFile);
	bool bFileExists = FileExists(sFile);
	if (bCreateFile || bFileExists)
	{
		File fFile = OpenFile(sFile, (bFileExists ? "a" : "w"));
		char sWrite[2048];
		if (fFile == null)
		{
			return ASS_APPEND_BAD_HANDLE;
		}
		if (bCreateFile && !bFileExists)
		{
			fFile.WriteLine("// This file was auto-generated by the Anti-Speedrunner System v%s (%s)", ASS_VERSION, ASS_URL);
			GetPluginFilename(hPluginHandle, sWrite, sizeof(sWrite));
			Format(sWrite, sizeof(sWrite), "// ConVars for plugin \"%s\"", sWrite);
			fFile.WriteLine(sWrite);
		}
		fFile.WriteLine("\n");
		int iNewLines = ASS_GetCharCountInStr('\n', description);
		if (iNewLines == 0)
		{
			Format(sWrite, sizeof(sWrite), "// %s", description);
			fFile.WriteLine(sWrite);
		}
		else
		{
			char[][] newlineBuf = new char[iNewLines + 1][2048];
			ExplodeString(description, "\n", newlineBuf, iNewLines + 1, 2048, false);
			for (int iLine; iLine <= iNewLines; iLine++)
			{
				if (strlen(newlineBuf[iLine]) > 0)
				{
					fFile.WriteLine("// %s", newlineBuf[iLine]);
				}
			}
		}
		fFile.WriteLine("// -");
		Format(sWrite, sizeof(sWrite), "// Default: \"%s\"", defaultValue);
		fFile.WriteLine(sWrite);
		if (hasMin)
		{		
			Format(sWrite, sizeof(sWrite), "// Minimum: \"%f\"", min);
			fFile.WriteLine(sWrite);
		}
		if (hasMax)
		{
			Format(sWrite, sizeof(sWrite), "// Maximum: \"%f\"", max);
			fFile.WriteLine(sWrite);
		}
		Format(sWrite, sizeof(sWrite), "%s \"%s\"", name, defaultValue);
		fFile.WriteLine(sWrite);
		delete fFile;		
		return ASS_APPEND_SUCCESS;
	}
	return ASS_APPEND_FILE_NOT_FOUND;
}

stock int ASS_FindValue(const char[] cvar, char[] value, int size, bool caseSensitive = false)
{
	value[0] = '\0';
	if (strlen(sConfigFile) < 1)
	{
		return ASS_NO_CONFIG;
	}
	char sFile[PLATFORM_MAX_PATH];
	strcopy(sFile, sizeof(sFile), sConfigFile);
	bool bFileExists = FileExists(sFile);
	if (bCreateFile && !bFileExists)
	{
		return ASS_FIND_FILE_NOT_FOUND;
	}
	if (bFileExists)
	{
		File fFile = OpenFile(sFile, "r");
		int iValueStart;
		int iValueEnd;
		int iCvarEnd;
		char sConvar[64];
		char sValue[64];
		char sRead[2048];
		char sCopy[2048];
		if (fFile == null)
		{
			return ASS_FIND_BAD_HANDLE;
		}
		while (!fFile.EndOfFile() && fFile.ReadLine(sRead, sizeof(sRead)))
		{
			if (IsCharSpace(sRead[0]) || sRead[0] == '/' || (!IsCharNumeric(sRead[0]) && !IsCharAlpha(sRead[0])))
			{
				continue;
			}
			if (ASS_GetCharCountInStr(' ', sRead) < 1)
			{
				continue;
			}
			if (ASS_GetCharCountInStr('"', sRead) != 2)
			{
				continue;
			}
			if ((iValueStart = StrContains(sRead, "\"")) == -1)
			{
				continue;
			}
			if ((iValueEnd = StrContains(sRead[iValueStart+1], "\"")) == -1)
			{
				continue;
			}
			if ((iCvarEnd = StrContains(sRead, " ")) == -1 || iCvarEnd >= iValueStart)
			{
				continue;
			}
			if (iCvarEnd >= iValueStart)
			{
				continue;
			}
			strcopy(sCopy, sizeof(sCopy), sRead);
			sCopy[iCvarEnd] = '\0';
			strcopy(sConvar, sizeof(sConvar), sCopy);
			strcopy(sCopy, sizeof(sCopy), sRead[iValueStart+1]);
			sCopy[iValueEnd] = '\0';
			strcopy(sValue, sizeof(sValue), sCopy);
			if (StrEqual(sConvar, cvar, caseSensitive))
			{
				Format(value, size, "%s", sConvar);
				delete fFile;
				return ASS_FIND_SUCCESS;
			}					
		}
		delete fFile;	
		return ASS_FIND_NOT_FOUND;
	}
	return ASS_FIND_FILE_NOT_FOUND;
}

stock int ASS_Clean()
{
	if (strlen(sConfigFile) < 1)
	{
		return ASS_NO_CONFIG;
	}
	char sFile[PLATFORM_MAX_PATH];
	strcopy(sFile, sizeof(sFile), sConfigFile);
	if (!FileExists(sFile))
	{
		return ASS_CLEAN_FILE_NOT_FOUND;
	}
	char sFile2[PLATFORM_MAX_PATH];
	Format(sFile2, sizeof(sFile2), "%s_tempcopy", sFile);
	char sRead[2048];
	int iCount;
	bool bFirstReached;
	File fFile1 = OpenFile(sFile, "r");
	File fFile2 = OpenFile(sFile2, "w");
	if (fFile1 == null || fFile2 == null)
	{
		if (fFile1 != null)
		{
			delete fFile1;
		}
		if (fFile2 != null)
		{
			delete fFile2;
		}
		return ASS_CLEAN_BAD_HANDLE;
	}
	while (!fFile1.EndOfFile() && fFile1.ReadLine(sRead, sizeof(sRead)))
	{
		if (IsCharSpace(sRead[0]))
		{
			iCount++;
		}
		else
		{
			iCount = 0;
		}
		if (iCount < 2 || !bFirstReached)
		{
			ReplaceString(sRead, sizeof(sRead), "\n", "");
			fFile2.WriteLine(sRead);
		}
		if (iCount == 2)
		{
			bFirstReached = true;
		}
	}
	delete fFile1;
	delete fFile2;
	DeleteFile(sFile);
	RenameFile(sFile, sFile2);	
	return ASS_CLEAN_SUCCESS;
}

stock static int ASS_GetCharCountInStr(int character, const char[] str)
{
	int iLength = strlen(str);
	int iCount;
	for (int iString; iString < iLength; iString++)
	{
		if (str[iString] == character)
		{
			iCount++;
		}
	}
	return iCount;
}

// Checks
stock bool bHasGameDataFile()
{
	return FileExists("addons/sourcemod/gamedata/anti-speedrunner_system.txt", true);
}

stock bool bHasIdlePlayer(int client)
{
	int iIdler = GetClientOfUserId(GetEntData(client, FindSendPropInfo("SurvivorBot", "m_humanSpectatorUserID")));
	if (iIdler)
	{
		if (IsClientInGame(iIdler) && !IsFakeClient(iIdler) && (GetClientTeam(iIdler) != 2))
		{
			return true;
		}
	}
	return false;
}

stock bool bHasTranslationFile()
{
	return FileExists("addons/sourcemod/translations/anti-speedrunner_system.phrases.txt", true);
}

public bool bInfectedFilter(const char[] pattern, Handle clients)
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsInfected(iPlayer))
		{
			PushArrayCell(clients, iPlayer);
		}
	}
	return true;
}

stock bool bIsAbleHumanSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !bIsPlayerIncapacitated(client) && !IsClientInKickQueue(client) && !IsFakeClient(client) && !bHasIdlePlayer(client) && !bIsPlayerIdle(client);
}

stock bool bIsAbleSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !bIsPlayerIncapacitated(client) && !IsClientInKickQueue(client);
}

stock bool bIsAdminAllowed(int client)
{
	return CheckCommandAccess(client, "ass_override", ADMFLAG_GENERIC, false);
}

stock bool bIsBotIdle(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && bHasIdlePlayer(client);
}

stock bool bIsBotIdleSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && !bHasIdlePlayer(client);
}

stock bool bIsBotInfected(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && !IsClientInKickQueue(client) && IsFakeClient(client);
}

stock bool bIsBotSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsClientInKickQueue(client) && IsFakeClient(client);
}

stock bool bIsBuggedMap()
{
	char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));
	return StrEqual(sMapName, "l4d_smalltown03_ranchhouse", false) || StrEqual(sMapName, "l4d_smalltown04_mainstreet", false) || StrEqual(sMapName, "c10m3_ranchhouse", false) || StrEqual(sMapName, "c10m4_mainstreet", false);
}

stock bool bIsFinaleMap()
{
	return FindEntityByClassname(-1, "trigger_finale") != -1;
}

stock bool bIsHumanSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsClientInKickQueue(client) && !IsFakeClient(client) && !bHasIdlePlayer(client) && !bIsPlayerIdle(client);
}

stock bool bIsInfected(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && !IsClientInKickQueue(client);
}

stock bool bIsL4D2Game()
{
	char sGameName[64];
	GetGameFolderName(sGameName, sizeof(sGameName));
	return StrEqual(sGameName, "left4dead2", false);
}

stock bool bIsPlayerIdle(int client)
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (!IsClientInGame(iPlayer) || GetClientTeam(iPlayer) != 2 || !IsFakeClient(iPlayer) || !bHasIdlePlayer(iPlayer))
		{
			continue;
		}
		int iIdler = GetClientOfUserId(GetEntData(iPlayer, FindSendPropInfo("SurvivorBot", "m_humanSpectatorUserID")));
		if (iIdler == client)
		{
			return true;
		}
	}
	return false;
}

stock bool bIsPlayerIncapacitated(int client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
	{
		return true;
	}
	return false;
}

stock bool bIsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsClientInKickQueue(client);
}

stock bool bIsSystemValid(ConVar convar, ConVar convar2, ConVar convar3)
{
	char sGameMode[32];
	char sConVarModes[2049];
	char sModeName[64][32];
	convar.GetString(sGameMode, sizeof(sGameMode));
	convar2.GetString(sConVarModes, sizeof(sConVarModes));
	ExplodeString(sConVarModes, ",", sModeName, sizeof(sModeName), sizeof(sModeName[]));
	for (int iMode = 0; iMode < sizeof(sModeName); iMode++)
	{
		if (StrContains(sGameMode, sModeName[iMode], false) == -1 && sModeName[iMode][0] != '\0')
		{
			return false;
		}
		else
		{
			return true;
		}
	}
	convar3.GetString(sConVarModes, sizeof(sConVarModes));
	ExplodeString(sConVarModes, ",", sModeName, sizeof(sModeName), sizeof(sModeName[]));
	for (int iMode = 0; iMode < sizeof(sModeName); iMode++)
	{
		if (StrContains(sGameMode, sModeName[iMode], false) != -1 && sModeName[iMode][0] != '\0')
		{
			return false;
		}
		else
		{
			return true;
		}
	}
	return true;
}

stock bool bIsTank(int client)
{
	char sClassname[32];
	if (bIsInfected(client))
	{
		GetEntityNetClass(client, sClassname, sizeof(sClassname));
		if (StrEqual(sClassname, "Tank", false))
		{
			return true;
		}
	}
	return false;
}

stock bool bIsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsClientInKickQueue(client) && !IsFakeClient(client);
}

public bool bSurvivorFilter(const char[] pattern, Handle clients)
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsSurvivor(iPlayer))
		{
			PushArrayCell(clients, iPlayer);
		}
	}
	return true;
}

stock bool bTraceRayDontHitSelf(int entity, any data)
{
	return entity == data;
}

// Functions
stock int iGetAbleHumanCount()
{
	int iAbleHumanCount;
	for (int iHuman = 1; iHuman <= MaxClients; iHuman++)
	{
		if (bIsAbleHumanSurvivor(iHuman))
		{
			iAbleHumanCount += 1;
		}
	}
	return iAbleHumanCount;
}

stock int iGetBadHumanCount()
{
	int iBadCount;
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsHumanSurvivor(iPlayer) && bIsPlayerBad(iPlayer))
		{
			iBadCount += 1;
		}
	}
	return iBadCount;
}

stock int iGetBotSurvivor()
{
	for (int iBot = MaxClients; iBot >= 1; iBot--)
	{
		if (bIsBotSurvivor(iBot))
		{
			return iBot;
		}
	}
	return -1;
}

stock int iGetHumanCount()
{
	int iHumanCount;
	for (int iHuman = 1; iHuman <= MaxClients; iHuman++)
	{
		if (bIsHumanSurvivor(iHuman))
		{
			iHumanCount += 1;
		}
	}
	return iHumanCount;
}

stock int iGetIdleBot(int client)
{
	for (int iBot = 1; iBot <= MaxClients; iBot++)
	{
		if (iGetIdlePlayer(iBot) == client)
		{
			return iBot;
		}
	}
	return 0;
}

stock int iGetIdlePlayer(int client)
{
	if (bIsBotSurvivor(client))
	{
		char sClassname[12];
		GetEntityNetClass(client, sClassname, sizeof(sClassname));
		if (strcmp(sClassname, "SurvivorBot") == 0)
		{
			int iIdler = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
			if (iIdler > 0 && IsClientInGame(iIdler) && GetClientTeam(iIdler) == 1)
			{
				return iIdler;
			}
		}
	}
	return 0;
}

stock int iGetIncapCount()
{
	int iIncapacitatedCount;
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (!bIsAbleSurvivor(iPlayer))
		{
			iIncapacitatedCount += 1;
		}
	}
	return iIncapacitatedCount;
}

stock int iGetReviveCount()
{
	int iRevivedCount;
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsAbleSurvivor(iPlayer))
		{
			iRevivedCount += 1;
		}
	}
	return iRevivedCount;
}

stock int iGetSurvivorCount()
{
	int iSurvivorCount;
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor))
		{
			iSurvivorCount += 1;
		}
	}
	return iSurvivorCount;
}

stock void vCopyVector(float source[3], float target[3])
{
	target[0] = source[0];
	target[1] = source[1];
	target[2] = source[2];
}

stock void vMultiTargetFilters(int toggle)
{
	switch (toggle)
	{
		case 0:
		{
			RemoveMultiTargetFilter("@survivors", bSurvivorFilter);
			RemoveMultiTargetFilter("@infected", bInfectedFilter);
		}
		case 1:
		{
			AddMultiTargetFilter("@survivors", bSurvivorFilter, "all survivors", false);
			AddMultiTargetFilter("@infected", bInfectedFilter, "all infected", false);
		}
	}
}

stock void vNobodyVoted(int votes, int totalvotes)
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsHumanSurvivor(iPlayer))
		{
			if (bHasTranslationFile())
			{
				PrintToChat(iPlayer, "%s %t", ASS_PREFIX03, "NobodyVoted", votes, totalvotes);
			}
			else
			{
				PrintToChat(iPlayer, "%s %d\x01/\x03%d\x01 voted.", ASS_PREFIX03, votes, totalvotes);
			}
		}
	}
}

stock void vCheatCommand(int client, char[] command, char[] arguments = "")
{
	SetCommandFlags(command, GetCommandFlags(command) & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, GetCommandFlags(command));
}