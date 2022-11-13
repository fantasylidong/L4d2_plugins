/*
*	Plugin Updates Checker
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.5"

/*======================================================================================
	Plugin Info:

*	Name	:	[ANY] Plugin Updates Checker
*	Author	:	SilverShot
*	Descrp	:	Checks version cvars against a list of known latest plugin versions.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=333430
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.5 (18-Apr-2022)
	- Fixed some servers not displaying the updates and throwing an error. Thanks to "Psyk0tik" for reporting and testing.

1.4 (07-Nov-2021)
	- No longer checks for updates every map change.

1.3 (06-Nov-2021)
	- Removed timeout restriction for checking on updates.
	- Changes to fix warnings when compiling on SourceMod 1.11.

1.2 (20-Jul-2021)
	- Made the error message clearer about missing extensions.

1.1 (13-Jul-2021)
	- Fixed "Native "HTTPClient.HTTPClient" was not found" error.

1.0 (11-Jul-2021)
	- Initial release.

0.1 (25-May-2020)
	- Initial creation.

========================================================================================
	Thanks:

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	"GoD-Tony" for "Updater"
	https://forums.alliedmods.net/showthread.php?t=169095

======================================================================================*/

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>
#include <ripext>
#define REQUIRE_EXTENSIONS

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define CVAR_FLAGS				FCVAR_NOTIFY

#define	DATA_CONFIG_WRITE		"data/plugin_updates_download.cfg"			// Path to download data when using REST in Pawn.
#define	DATA_CONFIG_READ		"data/plugin_updates.cfg"					// Path to read the data config for manually updating the list of plugins.
#define	DATA_CONFIG_SAVE		"data/plugin_updates_cmd.cfg"				// Path to save the data config for manually updating the list of plugins.
#define	DATA_CONFIG_LIST		"data/plugin_updates_checker.cfg"			// Path to the data config listing multiple sites to check for plugin updates.
#define	UPDATE_MAIN_LIST		"https://pastebin.com/raw/T7Qr1iQw"			// Main list with URLs to plugin lists to check against with server, defaults to this if no config is found.
#define	UPDATE_SILVERS			"https://pastebin.com/raw/KM2HgQ7n"			// URL of plugin list to check against with server, defaults to this if no config or main list is found. Plugins listed are my own (Silvers).
#define	DATABASE_NAME			"storage-local"								// Database name for timeout.
#define	PATH_LOG_FILE			"logs/plugin_updates.txt"					// Log file path.

#define	MAX_LEN_CVARS			64											// Maximum size of cvar names, to ignore checking them.
#define	MAX_LEN_QUERIES			256											// Maximum length of database queries to use.
#define	MAX_LEN_WEBSITE			512											// Maximum length of website URLs to use.
#define	MAX_LEN_SECTION			128											// Maximum length of each section in quotes separated by commas.
#define	MAX_LEN_WEBPAGE			32768										// Maximum size of the webpage to download. (32 KB ... 20.7 KB = ~146 plugins from Silvers URL).
#define	MAX_LEN_TIMEOUT			86400										// Timeout between checks (1 day)
#pragma dynamic					MAX_LEN_WEBPAGE

#define STEAMWORKS_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "SteamWorks_CreateHTTPRequest") == FeatureStatus_Available)
#define RESTINPAWN_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "HTTPClient.DownloadFile") == FeatureStatus_Available)

ConVar g_hCvarAuto, g_hCvarIgnore, g_hCvarLogs;
int g_iLastChecked;
bool g_bMainList;
bool g_bLoaded;

// Database g_hDB;
ArrayList g_AlWebsites;
ArrayList g_AlIgnore;
int g_iIndex;



// ====================================================================================================
//					PLUGIN START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[ANY] Plugin Updates Checker",
	author = "SilverShot",
	description = "Checks version cvars against a list of known latest plugin versions.",
	version = "1.0",
	url = "https://forums.alliedmods.net/showthread.php?t=333430"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// SteamWorks
	MarkNativeAsOptional("SteamWorks_CreateHTTPRequest");
	MarkNativeAsOptional("SteamWorks_SetHTTPRequestHeaderValue");
	MarkNativeAsOptional("SteamWorks_SetHTTPCallbacks");
	MarkNativeAsOptional("SteamWorks_SendHTTPRequest");

	// REST in Pawn
	MarkNativeAsOptional("HTTPClient.HTTPClient");
	MarkNativeAsOptional("HTTPClient.DownloadFile");
	MarkNativeAsOptional("HTTPClient.SetHeader");

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Cvars
	g_hCvarAuto = CreateConVar(		"sm_updates_auto",		"1",	"0=Manual checking only. 1=Automatically check on server start. 2=Check on server start and once per day (if uptime >= 24 hours).", CVAR_FLAGS);
	g_hCvarIgnore = CreateConVar(	"sm_updates_ignore",	"",		"Ignores plugins using these version cvars, separate by commas (no spaces).", CVAR_FLAGS);
	g_hCvarLogs = CreateConVar(		"sm_updates_logs",		"2",	"0=Print to server console. 1=Logs to sourcecmod/logs/plugin_updates.txt listing plugins whose version differs from the servers. 2=Print to server console and logs to file.", CVAR_FLAGS);

	CreateConVar("sm_updates_version",	PLUGIN_VERSION, "Plugin Updates Checker plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true, "sm_updates_checker");

	g_hCvarIgnore.AddChangeHook(ConVarChanged_Cvars);

	GetCvars();

	// Commands
	RegAdminCmd("sm_updates",			CmdUpdates,	ADMFLAG_ROOT, "Check for plugin updates.");
	RegAdminCmd("sm_updates_config",	CmdConfig,	ADMFLAG_ROOT, "Updates the data/plugin_updates.cfg config with detected cvar version numbers from plugins listed in the config.");
}

public void OnConfigsExecuted()
{
	if( !g_bLoaded )
	{
		// Validate extensions
		if( !STEAMWORKS_AVAILABLE() && !RESTINPAWN_AVAILABLE() )
		{
			SetFailState("\n==========\nThis plugin requires one of the \"SteamTools\", \"SteamWorks\" or \"REST in Pawn\" Extensions to function.\nRead installation instructions and requirements again.\n==========");
		}

		// Database
		// MySQL_Connect();

		// Auto update
		if( g_hCvarAuto.IntValue == 2 )
			CreateTimer(60.0, TimerUpdate, _, TIMER_REPEAT);

		CheckForUpdates(0);

		g_bLoaded = true;
	}
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	delete g_AlIgnore;
	g_AlIgnore = CreateArray(MAX_LEN_CVARS);

	char sTemp[512], sCvar[MAX_LEN_CVARS];

	g_hCvarIgnore.GetString(sTemp, sizeof(sTemp));
	TrimString(sTemp);

	if( sTemp[0] )
	{
		StrCat(sTemp, sizeof(sTemp), ",");

		int pos, last;
		while( (pos = SplitString(sTemp[last], ",", sCvar, sizeof(sCvar))) != -1 )
		{
			last += pos;
			g_AlIgnore.PushString(sCvar);
		}
	}
}



// ====================================================================================================
//					UPDATES CHECK
// ====================================================================================================
public Action CmdUpdates(int client, int args)
{
	CheckForUpdates(client);

	return Plugin_Handled;
}

void CheckForUpdates(int client)
{
	ReplyToCommand(client, "[SM] Plugin Updates Checker: Checking for updates...");

	// Timeout
	/*
	if( !g_iLastChecked )
	{
		ReplyToCommand(client, "[SM] Plugin Updates Checker: Cannot determine last check.");
		return;
	}

	if( GetTime() - g_iLastChecked < MAX_LEN_TIMEOUT )
	{
		ReplyToCommand(client, "[SM] Plugin Updates Checker: Already checked for updates today.");
		return;
	}

	g_iLastChecked = GetTime();

	if( g_hDB != null )
	{
		char szBuffer[MAX_LEN_QUERIES];
		g_hDB.Format(szBuffer, sizeof(szBuffer), "\
		INSERT INTO \
			`plugin_updates_checker` (`server`, `last_checked`) \
		VALUES \
			('1', '%d') ON CONFLICT(`server`) \
		DO UPDATE SET \
			`last_checked` = '%d'", g_iLastChecked, g_iLastChecked);

		g_hDB.Query(Database_OnSaveData, szBuffer);
	}
	// */
	g_iLastChecked = GetTime();



	// Delete log
	if( g_hCvarLogs.IntValue )
	{
		char sTemp[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sTemp, sizeof(sTemp), PATH_LOG_FILE);
		if( FileExists(sTemp) )
			DeleteFile(sTemp);
	}



	// Read config (list of links to plugin lists) - overrides main list link
	delete g_AlWebsites;
	g_AlWebsites = new ArrayList(MAX_LEN_WEBSITE);
	g_iIndex = 0;

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), DATA_CONFIG_LIST);

	if( FileExists(sPath) )
	{
		char sLink[MAX_LEN_WEBSITE];
		File hFile = OpenFile(sPath, "r");
		if( hFile != null )
		{
			while( !hFile.EndOfFile() && hFile.ReadLine(sLink, sizeof(sLink)) )
			{
				TrimString(sLink);
				if( sLink[0] && sLink[1] != '/' && sLink[2] != '/' )
				{
					g_AlWebsites.PushString(sLink);
				}
			}
		}
	}



	// Download Main list of links
	if( g_AlWebsites.Length == 0 )
	{
		// Log + print
		if( g_hCvarLogs.IntValue != 1 )
		{
			PrintToServer("");
			PrintToServer("------------------------------");
			PrintToServer(">>> Downloading main list from: [%s]", UPDATE_MAIN_LIST);
			PrintToServer("------------------------------");
		}

		if( g_hCvarLogs.IntValue )
		{
			LogCustom(">>> Downloading main list from: [%s]", UPDATE_MAIN_LIST);
			LogCustom("");
			LogCustom("");
		}

		DownloadMainList();
		return;
	}



	// Default to Silvers plugin list if no file/list was found
	if( g_AlWebsites.Length == 0 )
	{
		g_AlWebsites.PushString(UPDATE_SILVERS);
	}



	// Log + print
	if( g_hCvarLogs.IntValue )
	{
		char sTemp[PLATFORM_MAX_PATH];
		FormatTime(sTemp, sizeof(sTemp), "%d-%b-%Y %H:%M:%S");
		LogCustom(">>> Starting plugin updates check: %s", sTemp);
	}



	// Do work
	ProcessLists();
}

void ProcessLists()
{
	// Verify we still have lines to read
	if( g_iIndex >= g_AlWebsites.Length )
		return;

	// Read next config line
	char sLink[MAX_LEN_WEBSITE];
	g_AlWebsites.GetString(g_iIndex, sLink, sizeof(sLink));
	g_iIndex++;

	// Log + print
	if( g_hCvarLogs.IntValue != 1 )
	{
		PrintToServer("");
		PrintToServer("------------------------------");
		PrintToServer(">>> Checking for plugin updates from: [%s]", sLink);
		PrintToServer("------------------------------");
		PrintToServer("");
	}

	if( g_hCvarLogs.IntValue )
	{
		LogCustom("");
		LogCustom(">>> Checking for plugin updates from: [%s]", sLink);
		LogCustom("");
	}



	// Request
	g_bMainList = false;

	// STEAMWORKS
	if( STEAMWORKS_AVAILABLE() )
	{
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sLink);
		SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Pragma", "no-cache");
		SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Cache-Control", "no-cache");
		SteamWorks_SetHTTPCallbacks(hRequest, OnRequestComplete);
		SteamWorks_SendHTTPRequest(hRequest);
	}
	// REST IN PAWN
	else if( RESTINPAWN_AVAILABLE() )
	{
		char sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), DATA_CONFIG_WRITE);
		if( FileExists(sPath) )
			DeleteFile(sPath);

		// Find / after https://
		char sURL[MAX_LEN_WEBSITE];
		Format(sURL, sizeof(sURL), sLink);

		int pos = FindCharInString(sURL, '/');
		pos += FindCharInString(sURL[pos + 2], '/');
		pos += FindCharInString(sURL[pos + 2], '/');
		sURL[pos + 2] = 0;

		HTTPClient httpClient = new HTTPClient(sURL);
		httpClient.SetHeader("Pragma", "no-cache");
		httpClient.SetHeader("Cache-Control", "no-cache");
		httpClient.DownloadFile(sURL[pos + 3], sPath, OnFileDownloaded);

		delete httpClient;
	}
}



// ====================================================================================================
//					REST IN PAWN
// ====================================================================================================
public void OnFileDownloaded(HTTPStatus status, any value, const char[] error)
{
	if( status == HTTPStatus_OK )
	{
		char sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), DATA_CONFIG_WRITE);

		if( FileExists(sPath) )
		{
			char[] body = new char[MAX_LEN_WEBPAGE];
			File hFile = OpenFile(sPath, "r");

			int len = FileSize(sPath, true, NULL_STRING);
			hFile.ReadString(body, MAX_LEN_WEBPAGE, len);
			delete hFile;
			// DeleteFile(sPath);

			if( g_bMainList )
				GetMainList(body);
			else
				CheckVersions(body);
		}
	}
	else
	{
		char sError[256];
		FormatEx(sError, sizeof(sError), "REST error (status code %d). Error: %s", status, error);
		LogError(sError);
	}

	// Continue with each line from the main list/config, if available.
	ProcessLists();
}



// ====================================================================================================
//					STEAMWORKS
// ====================================================================================================
public void OnRequestComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int main)
{
	if( bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK )
	{
		int length;
		SteamWorks_GetHTTPResponseBodySize(hRequest, length);
		char[] body = new char[length];

		SteamWorks_GetHTTPResponseBodyData(hRequest, body, length);

		if( g_bMainList )
			GetMainList(body);
		else
			CheckVersions(body);
	}
	else
	{
		LogError("Error Response: Successful: %d. Error code: %d", bRequestSuccessful, eStatusCode);
	}

	// Continue with each line from the main list/config, if available.
	ProcessLists();
}



// ====================================================================================================
//					MAIN LIST
// ====================================================================================================
void DownloadMainList()
{
	g_bMainList = true;

	// STEAMWORKS
	if( STEAMWORKS_AVAILABLE() )
	{
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, UPDATE_MAIN_LIST);
		SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Pragma", "no-cache");
		SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Cache-Control", "no-cache");
		SteamWorks_SetHTTPCallbacks(hRequest, OnRequestComplete);
		SteamWorks_SendHTTPRequest(hRequest);
	}
	// REST IN PAWN
	else if( RESTINPAWN_AVAILABLE() )
	{
		char sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), DATA_CONFIG_WRITE);
		if( FileExists(sPath) )
			DeleteFile(sPath);

		// Find / after https:// to split the link
		char sURL[MAX_LEN_WEBSITE];
		Format(sURL, sizeof(sURL), UPDATE_MAIN_LIST);

		int pos = FindCharInString(sURL, '/');
		pos += FindCharInString(sURL[pos + 2], '/');
		pos += FindCharInString(sURL[pos + 2], '/');
		sURL[pos + 2] = 0;

		HTTPClient httpClient = new HTTPClient(sURL);
		httpClient.SetHeader("Pragma", "no-cache");
		httpClient.SetHeader("Cache-Control", "no-cache");
		httpClient.DownloadFile(sURL[pos + 3], sPath, OnFileDownloaded);

		delete httpClient;
	}
}

void GetMainList(char[] response)
{
	int end, pos, len = strlen(response);
	char sLine[MAX_LEN_SECTION];

	// Windows/Linux compatibility
	ReplaceString(response, len, "\r\n", "\n");

	for( ;; )
	{
		end = StrContains(response[pos], "\n");
		if( end == -1 ) end = (len - pos) + 1;
		if( pos + end < len )
			response[pos + end] = 0;
		else
			response[len] = 0;

		strcopy(sLine, sizeof(sLine), response[pos]);
		TrimString(sLine);

		if( sLine[0] && sLine[1] != '/' && sLine[2] != '/' )
		{
			g_AlWebsites.PushString(sLine);
			// PrintToServer("Push link: %s", sLine);
		}

		if( end == (len - pos) + 1 ) break;
		pos += end + 1;
	}
}



// ====================================================================================================
//					CHECK VERSIONS
// ====================================================================================================
void CheckVersions(char[] response)
{
	char version[16];
	char sLine[4][MAX_LEN_SECTION];
	ConVar hCvar;
	int check, count, total, ignored, end, pos, len = strlen(response);

	// Windows/Linux compatibility
	ReplaceString(response, len, "\r\n", "\n");

	// Loop returned list
	for( ;; )
	{
		end = StrContains(response[pos], "\n");
		if( end == -1 ) end = (len - pos) + 1;
		response[pos + end] = 0;

		ExplodeString(response[pos], "\",", sLine, sizeof(sLine), sizeof(sLine[]));

		// Because we're splitting the string with the characters ", we're missing the trailing quote " so add it back to properly Trim string and Strip quotes...
		// This is a bit excessive, but allows using commas in the plugins title section, if that's ever an issue.
		StrCat(sLine[0], sizeof(sLine[]), "\"\x0");
		TrimString(sLine[0]);
		StripQuotes(sLine[0]);

		if( sLine[0][0] && sLine[0][1] != '/' && sLine[0][2] != '/' )
		{
			// PrintToServer("[%s]\n[%s]\n[%s]\n[%s]\n", sLine[0],sLine[2], sLine[1], sLine[3]); // Debug

			hCvar = FindConVar(sLine[0]);
			check++;

			// Version cvar found from active plugin on server
			if( hCvar != null )
			{
				hCvar.GetString(version, sizeof(version));
				total++;

				// Version
				StrCat(sLine[1], sizeof(sLine[]), "\"\x0");
				TrimString(sLine[1]);
				StripQuotes(sLine[1]);

				// Ignore cvars
				if( g_AlIgnore && g_AlIgnore.FindString(sLine[0]) != -1 )
				{
					// Name
					TrimString(sLine[3]);
					StripQuotes(sLine[3]);

					if( g_hCvarLogs.IntValue != 1 )
					{
						PrintToServer(">>> Ignoring: %s [%s] (%s <> %s)", sLine[3], sLine[0], version, sLine[1]);
						PrintToServer("");
					}

					if( g_hCvarLogs.IntValue )
					{
						LogCustom(">>> Ignoring: %s [%s] (%s <> %s)", sLine[3], sLine[0], version, sLine[1]);
						LogCustom("");
					}

					ignored++;

					pos += end + 1;
					continue;
				}

				if( strcmp(version, sLine[1]) ) // Version different
				{
					count++;

					// Link
					StrCat(sLine[2], sizeof(sLine[]), "\"\x0");
					TrimString(sLine[2]);
					StripQuotes(sLine[2]);

					// Name
					TrimString(sLine[3]);
					StripQuotes(sLine[3]);

					// PrintToServer("%s (%s <> %s) %s", sLine[2], version, sLine[1], sLine[3]); // Debug

					// Log + print
					if( g_hCvarLogs.IntValue != 1 )
					{
						PrintToServer("%s", sLine[3]);
						PrintToServer("%s", sLine[2]);
						PrintToServer("Server: %s\nLatest: %s", version, sLine[1]);
						PrintToServer("");
						// PrintToServer("----------");
					}

					if( g_hCvarLogs.IntValue )
					{
						LogCustom("%s", sLine[3]);
						LogCustom("%s", sLine[2]);
						LogCustom("Server: %s\nLatest: %s", version, sLine[1]);
						LogCustom("");
					}
				}
				/*
				// Lists plugins up-to-date - used for debug testing
				else
				{
					TrimString(sLine[3]); // Name
					StripQuotes(sLine[3]);
					PrintToServer("Up-to-date: [%s] [%s]", sLine[3], sLine[0]);
				}
				// */
			}
			/*
			// Lists plugins not found - used for debug testing
			else
			{
				TrimString(sLine[3]); // Name
				StripQuotes(sLine[3]);
				PrintToServer("Not found: [%s] [%s]", sLine[3], sLine[0]);
			}
			// */
		}

		if( end == (len - pos) + 1 ) break;
		pos += end + 1;
	}

	// Log + print
	if( g_hCvarLogs.IntValue != 1 )
	{
		PrintToServer("");
		if( ignored )
		{
			if( count )		PrintToServer("Found %d of %d plugins with updates. (Total %d) (Ignored %d).", count, total, check, ignored);
			else			PrintToServer("Congratulations! All %d plugins are up to date! (Total %d) (Ignored %d).", total, check, ignored);
		} else {
			if( count )		PrintToServer("Found %d of %d plugins with updates. (Total %d).", count, total, check);
			else			PrintToServer("Congratulations! All %d plugins are up to date! (Total %d).", total, check);
		}
		PrintToServer("");
	}

	if( g_hCvarLogs.IntValue )
	{
		if( ignored )
		{
			if( count )		LogCustom(">>> Found %d of %d plugins with updates. (Total %d) (Ignored %d).", count, total, check, ignored);
			else			LogCustom(">>> Congratulations! All %d plugins are up to date! (Total %d) (Ignored %d).", total, check, ignored);
		} else {
			if( count )		LogCustom(">>> Found %d of %d plugins with updates. (Total %d).", count, total, check);
			else			LogCustom(">>> Congratulations! All %d plugins are up to date! (Total %d).", total, check);
		}
		LogCustom("");
		LogCustom("");
	}
}



// ====================================================================================================
//					UPDATE CONFIG
// ====================================================================================================
public Action CmdConfig(int client, int args)
{
	char sPath[PLATFORM_MAX_PATH] = DATA_CONFIG_READ;
	BuildPath(Path_SM, sPath, sizeof(sPath), sPath);

	if( FileExists(sPath) )
	{
		char sNew[PLATFORM_MAX_PATH] = DATA_CONFIG_SAVE;
		BuildPath(Path_SM, sNew, sizeof(sNew), sNew);

		int count, total;
		ConVar hCvar;
		char version[16];
		char sLine[256];
		char sRead[4][MAX_LEN_SECTION];
		File hFile = OpenFile(sPath, "r");
		File hNew = OpenFile(sNew, "w");

		while( ReadFileLine(hFile, sLine, sizeof(sLine)) )
		{
			ExplodeString(sLine, ",", sRead, sizeof(sRead), sizeof(sRead[]));
			TrimString(sRead[0]);
			StripQuotes(sRead[0]);
			hCvar = FindConVar(sRead[0]);

			if( hCvar != null )
			{
				TrimString(sRead[1]);
				StripQuotes(sRead[1]);

				hCvar.GetString(version, sizeof(version));
				if( strcmp(version, sRead[1]) )
				{
					count++;
					Format(sRead[1], sizeof(sRead[]), "\"%s\"", sRead[1]);
					Format(version, sizeof(version), "\"%s\"", version);
					ReplaceString(sLine, sizeof(sLine), sRead[1], version);
				}
			}

			total++;
			hNew.WriteString(sLine, false);
		}

		delete hNew;
		delete hFile;

		ReplyToCommand(client, "Updated %d of %d entries.", count, total);
	} else {
		ReplyToCommand(client, "Cannot find the config \"%s\" to update.", sPath);
	}
	return Plugin_Handled;
}



// ====================================================================================================
//					DATABASE
// ====================================================================================================
/*
void MySQL_Connect()
{
	if( !SQL_CheckConfig(DATABASE_NAME) )
	{
		SetFailState("Missing database entry \"%s\" from your servers \"sourcemod/configs/databases.cfg\" file.", DATABASE_NAME);
	}

	Database.Connect(OnMySQLConnect, DATABASE_NAME);
}

public void OnMySQLConnect(Database db, const char[] szError, any data)
{
	if( db == null || szError[0] )
	{
		SetFailState("MySQL error: %s", szError);
		return;
	}

	g_hDB = db;

	// Create table if missing
	char szBuffer[MAX_LEN_QUERIES];
	db.Format(szBuffer, sizeof(szBuffer),\
		"CREATE TABLE IF NOT EXISTS `plugin_updates_checker` ( \
			`server` int NULL UNIQUE, \
			`last_checked` varchar(12) NULL, \
			PRIMARY KEY (`server`)\
		);");

	g_hDB.Query(Database_OnConnect, szBuffer);
}

public void Database_OnConnect(Database db, DBResultSet results, const char[] error, any data)
{
	if( results == null )
	{
		SetFailState("[Database_OnConnect] Error: %s", error);
	}

	char szBuffer[MAX_LEN_QUERIES];
	g_hDB.Format(szBuffer, sizeof(szBuffer), "SELECT `last_checked` FROM `plugin_updates_checker`");
	g_hDB.Query(Database_OnLoadData, szBuffer);
}

public void Database_OnLoadData(Database db, DBResultSet results, const char[] error, any data)
{
	if( results != null )
	{
		char szBuffer[MAX_LEN_QUERIES];

		if( results.RowCount )
		{
			results.FetchRow();
			results.FetchString(0, szBuffer, sizeof(szBuffer));
			g_iLastChecked = StringToInt(szBuffer);
		} else {
			g_iLastChecked = GetTime() - MAX_LEN_TIMEOUT - 1;
		}

		// Update on server start
		if( g_bLoaded && g_hCvarAuto.IntValue )
		{
			if( GetTime() - g_iLastChecked > MAX_LEN_TIMEOUT )
			{
				CheckForUpdates(0);
				g_iLastChecked = GetTime();
			} else {
				PrintToServer("[SM] Plugin Updates Checker: Already checked for updates today.");
			}
		}

		g_bLoaded = true;
	}
}

public void Database_OnSaveData(Database db, DBResultSet results, const char[] error, any data)
{
	if( results == null )
	{
		LogError("[Database_OnSaveData] Error: %s", error);
	}
	else
	{
		delete results;
	}
}
// */



// ====================================================================================================
//					AUTO UPDATE + LOG
// ====================================================================================================
public Action TimerUpdate(Handle timer)
{
	// if( g_iLastChecked && GetTime() - g_iLastChecked > MAX_LEN_TIMEOUT )
	if( g_iLastChecked && GetTime() - g_iLastChecked > MAX_LEN_TIMEOUT )
	{
		CheckForUpdates(0);
		g_iLastChecked = GetTime();
	}

	return Plugin_Continue;
}

void LogCustom(const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);

	File file;
	char FileName[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, FileName, sizeof(FileName), PATH_LOG_FILE);
	file = OpenFile(FileName, "a+");
	file.WriteLine("%s", buffer);
	FlushFile(file);
	delete file;
}