#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.14"

#define DEBUG 0

#define CVAR_FLAGS FCVAR_NOTIFY

StringMap hMapFiles;
char g_sRoot[PLATFORM_MAX_PATH], g_sPathSeparator[4];
ConVar g_hCvarEnable, g_hCvarUpdateDelay, g_hCvarTrackNew, g_hCvarShowInfo, g_hCvarErrorLines, g_hCvarMsgFlag;
bool g_bEnable, g_bTrackNew, g_bListChanged, g_bLateload, g_bMapStart, g_bSeqStart, g_bNewSeq;
int g_iShowInfo, g_iLenRoot, g_iErrLines, g_iMsgFlags;
Handle g_hTimer, g_OnUpdateForward, g_OnReloadForward, g_OnLoadForward, g_OnUnloadForward;

enum
{
	SHOW_IN_SERVER 	= 1 << 0,
	SHOW_IN_CHAT 	= 1 << 1,
	SHOW_IN_CONSOLE = 1 << 2
}

public Plugin myinfo = {
	name = "[DEV] Autoreload plugins",
	author = "Timiditas (Fork by Dragokas)",
	description = "Autoreloads plugins whose file timestamp has changed (for developers)",
	version = PLUGIN_VERSION,
	url = "http://github.com/dragokas"
};

/* Fork by Dragokas
	
	1.14 (27-Nov-2021)
	 - Potential fix for rare crash, caused by file system error.
	 - Improved DEBUG version in attempt to track the rare case with server crash caused by false positive time stamp change detection for all plugins at once.
	
	1.13 (01-July-2021)
	 - Added command "sm_pluginsreload" - to force checking plugin files for newly updated (by SilverShot request).
	 - Added new allowed value "0" for "sm_autoreload_delay" ConVar - to disable checking plugins update by timer at all.
	
	1.12 (09-May-2021)
	 - Little safe check to prevent error if < 4 character length filename for some reason is located at plugins folder.
	
	1.11 (16-Apr-2021)
	 - Added TIMER_FLAG_NO_MAPCHANGE to prevent accidentally plugin double reload on map change.
	 - Added forwards (thanks to Silvers for request):
	 
	  * AP_OnPluginUpdate - called when plugin list update sequence is about to start (or ended) - see the "started" argument to determine.
			> This happens when 1 or more plugins are to be planned for loading/reloading/unloading.
			> Example: when 10 plugins are changed simultaneously, this forward is called 2 times: 1 - very first before all other forward, then 2 - it is called as last, after all other forwards.
	  * AP_OnPluginLoad - called before and after plugin is loaded (no matter successfully or not - see the "pre" and "status" arguments for details).
			> This happens when plugin wasn't loaded yet, or its previous loading failed.
	  * AP_OnPluginReload - called before and after plugin is reloaded (no matter successfully or not - see the "pre" and "status" arguments for details).
			> This happens when plugin is already loaded at the moment.
	  * AP_OnPluginUnload
			> This happens when plugin is removed, moved or renamed from its initial location.
	  
	  * Notice 1: You can prevent plugins from load/reload/unload by returning Plugin_Stop in forward (it is only applicable for actions done directly by this plugin).
	  * Notice 2: these forwards doesn't report about actions made by other plugins including sourcemod itself, like:
	  > when you manually load/reload/unload plugin via console;
	  > when SM load/reload/unload plugin between OnMapEnd and OnMapStart events.
	
	1.10 (05-Oct-2020)
	 - Fixed: not hooked dynamic change of "sm_autoreload_error_lines" ConVar.

	1.9 (02-Apr-2020)
	 - Fixed Windows support. Reloader incorreclty selected load action type, because FindPluginByFile() can't normalize linux path separator (thanks to CrazyGhostRider for report).
	 - Plugin list is being updated now with newly added plugins on each map start (even if sm_autoreload_track_new == 0).
	 - Plugin reloading is blocked between map end and map start (for safe).
	
	1.8 (22-Mar-2020)
	 - Attempt to indirectly recognize <Disabled> plugins to prevent both load / reload commands executing for each modified plugin (affected rcon double-msg only).
	 - Added reloading of translation files cache; can be triggered by any of plugins reload (Marttt suggestion).
	 - Added ability to display reload message to admins only: new ConVar "sm_autoreload_msg_flag" (e.g., useful to not distract the players).
	 - Added ability to disable reloader: new ConVar "sm_autoreload_enable" (e.g. useful when some plugin can surely crash the server due to "hot" reload).

	1.7 (18-Mar-2020)
	 - Some non-essential message cleaning

	1.6 (17-Mar-2020)
	 - Code is simplified, changed timing logic.
	 - Plugin load status is now always displayed (it's checked with 0.5 sec. delay after actual re-loading).
	 - Status description is simplified.
	 - Plugin change is now detected by file size as well.
	 - "sm_autoreload_delay" ConVar safe minimum is defined as 1.0 sec.
	 - Disabled load/reload selection logic based on plugin status, since FindPluginByFile returns 0 even if plugin is loaded but disabled. Now, reload + load is always executed together.
	 - Added ability to display in chat part of error log when plugin is failed to load (you can disable or adjust number of lines in "sm_autoreload_error_lines" ConVar).
	 - Added an option to display info in console only, see "sm_autoreload_show_info" description.
	
	1.5 (16-Mar-2020)
	 - Better file uploading finish detection, so no more twice spam in error log (thanks to SilverShot).
	 - Some message misprints corrected.
	
	1.4 (13-Mar-2020)
	 - Added better plugin deletion detection
	 - ArrayLists are replaced by StringMap (for optimization)
	 - some code and messages optimizaion.

	1.3 (12-Mar-2020)
	 - Added one more plugin reload attempt in case it was previously reloaded at the same moment as file uploading progress is not finished
	 - Added displaying the status of reloaded plugin (if first attempt is failed).
	 - Added recurse scanning into subdirectories
	 - Added ability to track new files (activate it in "sm_autoreload_track_new" ConVar). By default, disabled to save performance.
	 - Added displaying info in chat (can be disabled by "sm_autoreload_show_info" ConVar).
	
	Notice: you can also unload plugin by deleting the file or renaming extension e.g. into "plugin.smx.bak", or by moving it in "disabled" folder.
	
	1.2 (22-Nov-2019)
	 - Converted to a new syntax and methodmaps
	 - Added ConVar "sm_autoreload_delay"
	 - Some code optimizations
	
	1.1
	 - Added command "sm plugins load" in case plugin is not loaded last time due to startup error
	
	1.0
	 - Original version by Timiditas: https://forums.alliedmods.net/showthread.php?t=106320
*/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateload = late;
	g_OnUpdateForward = CreateGlobalForward("AP_OnPluginUpdate", ET_Ignore, Param_Cell); // pre (started or ended)
	g_OnLoadForward 	= CreateGlobalForward("AP_OnPluginLoad", ET_Hook, Param_String, Param_Cell, Param_Cell); // name, pre, status
	g_OnReloadForward = CreateGlobalForward("AP_OnPluginReload", ET_Hook, Param_String, Param_Cell, Param_Cell); // name, pre, status
	g_OnUnloadForward = CreateGlobalForward("AP_OnPluginUnload", ET_Hook, Param_String, Param_Cell); // name, pre
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar( "sm_autoreload_version", PLUGIN_VERSION, "Plugin version", CVAR_FLAGS | FCVAR_DONTRECORD );
	
	g_hCvarEnable = CreateConVar( 		"sm_autoreload_enable", 		"1", 	"Enable this plugin? (1 - Yes, 0 - No)", CVAR_FLAGS );
	g_hCvarUpdateDelay = CreateConVar( 	"sm_autoreload_delay", 			"5.0", 	"Delay between updates (in sec.). Set 0 to disable timer at all.", CVAR_FLAGS);
	g_hCvarTrackNew = CreateConVar( 	"sm_autoreload_track_new", 		"0", 	"Do we need to check for new plugin files appearing? (1 - Yes, 0 - No)", CVAR_FLAGS );
	g_hCvarShowInfo = CreateConVar( 	"sm_autoreload_show_info", 		"1", 	"Where to show info about reloaded plugin? (0 - Nowhere, 1 - Server, 2 - Chat, 4 - Console. Sum them to combine several options)", CVAR_FLAGS );
	g_hCvarErrorLines = CreateConVar( 	"sm_autoreload_error_lines", 	"4", 	"How many lines of error log to display when plugin is failed to load? (0 - to disable)", CVAR_FLAGS, false, _, true, 10.0 );
	g_hCvarMsgFlag = CreateConVar( 		"sm_autoreload_msg_flag", 		"", 	"Display chat message to admins only defined by these admin flags (leave empty - to display for all users)", CVAR_FLAGS );
	
	AutoExecConfig(true, "sm_autoreload");
	
	RegAdminCmd("sm_pluginsreload", CmdAutoreload, ADMFLAG_ROOT, "Forcibly check plugin files for newly updated and reload if any");
	
	g_hCvarEnable.AddChangeHook(OnConVarChanged);
	g_hCvarUpdateDelay.AddChangeHook(OnConVarChanged);
	g_hCvarTrackNew.AddChangeHook(OnConVarChanged);
	g_hCvarShowInfo.AddChangeHook(OnConVarChanged);
	g_hCvarErrorLines.AddChangeHook(OnConVarChanged);
	g_hCvarMsgFlag.AddChangeHook(OnConVarChanged);
	
	GetCvars();
	
	BuildPath(Path_SM, g_sRoot, sizeof(g_sRoot), "plugins/");
	g_iLenRoot = strlen(g_sRoot);
	
	strcopy(g_sPathSeparator, sizeof(g_sPathSeparator), g_sRoot[g_iLenRoot-1]);
	
	hMapFiles = new StringMap();
	
	if( !g_bLateload ) // on late load list is loaded OnMapStart() automatically
	{
		GetPluginList(g_sRoot, true);
		PrintAll(-1, "[AutoReload] Found %i plugins.", hMapFiles.Size);
	}
	
	UpdateTimer();
}

public Action CmdAutoreload(int client, int argc)
{
	Timer_Regeneration(null);
	return Plugin_Handled;
}

public void OnConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();

	if( convar == g_hCvarUpdateDelay && strcmp(oldValue, newValue) != 0 )
	{
		UpdateTimer();
	}
}

void GetCvars()
{
	g_bEnable = g_hCvarEnable.BoolValue;
	g_bTrackNew = g_hCvarTrackNew.BoolValue;
	g_iShowInfo = g_hCvarShowInfo.IntValue;
	g_iErrLines = g_hCvarErrorLines.IntValue;
	
	char sFlags[32];
	g_hCvarMsgFlag.GetString(sFlags, sizeof(sFlags));
	if( sFlags[0] )
	{
		g_iMsgFlags = ReadFlagString(sFlags);
	}
}

void UpdateTimer()
{
	if( g_hTimer )
	{
		delete g_hTimer;
	}
	if( g_hCvarUpdateDelay.FloatValue != 0.0 )
	{
		g_hTimer = CreateTimer(g_hCvarUpdateDelay.FloatValue, Timer_Regeneration, _, TIMER_REPEAT);
	}
}

int GetFileStamp(char[] sPath)
{
	int iSize = FileSize(sPath, false);
	if( iSize == -1 )
	{
		return -1;
	}
	int iStamp = GetFileTime(sPath, FileTime_LastChange);
	if( iStamp == -1 )
	{
		return -1;
	}
	return iStamp + iSize;
}

public void OnMapStart()
{
	GetPluginList(g_sRoot, true);
	g_bListChanged = true;
	g_bMapStart = true;
	g_bSeqStart = false;
}

public void OnMapEnd()
{
	g_bMapStart = false;
}

void GetPluginList(char[] dirname, bool bFirstLoad)
{
	char			sPath[PLATFORM_MAX_PATH];
	static char 	PluginFile[PLATFORM_MAX_PATH];
	FileType 		fileType;
	int 			iStamp;
	int 			iLenPlugin;
	
	DirectoryListing dir = OpenDirectory(dirname);
	
	if( dir == null ) {
		return;
	}
	
	while( dir.GetNext(PluginFile, sizeof(PluginFile), fileType) )
	{
		FormatEx(sPath, sizeof(sPath), "%s%s", dirname, PluginFile);
		
		switch( fileType )
		{
			case FileType_File:
			{
				iLenPlugin = strlen(PluginFile);
				
				if( iLenPlugin >= 4 && strcmp(PluginFile[iLenPlugin - 4], ".smx") == 0 )
				{
					Format(PluginFile, sizeof(PluginFile), "%s%s", dirname[g_iLenRoot], PluginFile); // append prefix in recurse calls
					
					if( bFirstLoad || !hMapFiles.GetValue(PluginFile, iStamp) )
					{
						iStamp = GetFileStamp(sPath);
						hMapFiles.SetValue(PluginFile, iStamp);
						
						if( !bFirstLoad ) // new file is added
						{
							if( !g_bSeqStart )
							{
								g_bSeqStart = true;
								CallForward_OnUpdate(1);
							}
							g_bNewSeq = true;
							g_bListChanged = true; // request for StringMapSnapshot update
							LoadPlugin(PluginFile, 0.5);
						}
					}
				}
			}
			case FileType_Directory:
			{
				if( strcmp(PluginFile, ".") != 0 && strcmp(PluginFile, "..") != 0 && strcmp(PluginFile, "disabled") != 0 )
				{
					StrCat(sPath, sizeof(sPath), g_sPathSeparator);
					GetPluginList(sPath, bFirstLoad);
				}
			}
		}
	}
	delete dir;
}

public Action Timer_Regeneration(Handle timer)
{
	if( !g_bEnable || !g_bMapStart )
	{
		return;
	}
	
	static char sFilename[64];
	static char sPath[PLATFORM_MAX_PATH];
	static StringMapSnapshot hSnap;
	int iStamp, iStampnew;
	
	#if DEBUG
	int cntChanged;
	#endif
	
	g_bNewSeq = false;
	
	if( g_bListChanged )
	{
		delete hSnap;
	}
	
	if( !hSnap )
	{
		hSnap = hMapFiles.Snapshot();
	}
	
	for( int i = 0; i < hSnap.Length; i++ )
	{
		hSnap.GetKey(i, sFilename, sizeof(sFilename));
		hMapFiles.GetValue(sFilename, iStamp);
		
		FormatEx(sPath, sizeof(sPath), "%s%s", g_sRoot, sFilename);
		
		iStampnew = GetFileStamp(sPath);
		
		if( iStamp != iStampnew )
		{
			g_bNewSeq = true;
			
			if( !g_bSeqStart )
			{
				g_bSeqStart = true;
				CallForward_OnUpdate(1);
			}
			if( iStampnew == -1 && !FileExists(sPath, false) )
			{
				if( g_iShowInfo & SHOW_IN_SERVER )
				{
					PrintToServer("[AutoReload] %s plugin is deleted. Unloading...", sFilename);
				}
				PrintAll(-1 &~ SHOW_IN_SERVER, "\x03%s\x01 plugin is deleted. Unloading...", sFilename);
				
				if( CallForward_OnUnload(sFilename, 1) == Plugin_Continue )
				{
					ServerCommand("sm plugins unload %s", sFilename);
					CallForward_OnUnload(sFilename, 0);
				}
				else {
					PrintAll(-1, "\x03%s\x01 has prevented from been unloaded by 3rd party plugin", sFilename);
				}
				
				hMapFiles.Remove(sFilename);
				g_bListChanged = true;
				continue;
			}
			
			#if DEBUG
			PrintAll(-1, "[Autoreload] New timestamp detected: %i != %i (%s)", iStampnew, iStamp, sFilename);
			++ cntChanged;
			if( cntChanged == 6 )
			{
				LogError("Potential problem detected. Possibly, corrupted timestamp:");
				LogError("[Autoreload] New timestamp detected: %i != %i, size: %i, ft: %i (%s)", 
					iStampnew, iStamp, FileSize(sPath, false), GetFileTime(sPath, FileTime_LastChange), sFilename);
			}
			#endif
			
			if( iStampnew == -1 ) // Crash fix. File system error?
			{
				continue;
			}
			
			hMapFiles.SetValue(sFilename, iStampnew, true);
			ReloadPlugin(sFilename, 0.5); // delay in order to give ftp uploader time to finish copy operation
		}
	}
	
	if( g_bTrackNew )
	{
		GetPluginList(g_sRoot, false);
	}
	
	if( g_bSeqStart && !g_bNewSeq )
	{
		CallForward_OnUpdate(0);
		g_bSeqStart = false;
	}
}

void LoadPlugin(char[] sFilename, float delay)
{
	ReloadPlugin(sFilename, delay, 1);
}

void ReloadPlugin(char[] sFilename, float delay, int iLoadOnly = 0 )
{
	DataPack dp = new DataPack();
	dp.WriteString(sFilename);
	dp.WriteCell(iLoadOnly);
	CreateTimer(delay, Timer_ReloadDelayed, dp, TIMER_HNDL_CLOSE | TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ReloadDelayed(Handle timer, DataPack dp)
{
	static char sFilename[64];
	static char sPath[PLATFORM_MAX_PATH];
	bool bAskLoad, bAskReload, bAllowLoad, bAllowReload;
	
	dp.Reset();
	dp.ReadString(sFilename, sizeof(sFilename));
	int iLoadOnly = dp.ReadCell();
	
	FormatEx(sPath, sizeof(sPath), "%s%s", g_sRoot, sFilename);
	hMapFiles.SetValue(sFilename, GetFileStamp(sPath), true); // ensure we saved actual stamp info, since copy operation could finish just right now or even still processing
	
	if( iLoadOnly ) // for newly added plugin we just need "load"
	{
		bAskLoad = true;
	}
	else {
		Handle hPlugin = FindPluginByFile(sFilename);
		PluginStatus ps;
		
		if( hPlugin )
		{
			ps = GetPluginStatus(hPlugin);
		}
		
		if( !hPlugin && !HasDisabledPlugins() ) // disabled plugins considered as loaded, but they have hPlugin == INVALID_HANDLE
		{
			bAskLoad = true;
		}
		else if( hPlugin && ps == Plugin_Running || ps == Plugin_Loaded )
		{
			bAskReload = true;
		}
		else { // for less common statuses
			bAskReload = true;
			bAskLoad = true; // plugin still will not be loaded twice since it is prevented by sm itself
		}
		#if DEBUG
		PrintAll(-1, "Plugin status code before reload: %i", ps);
		#endif
	}
	
	if( bAskReload )
	{
		if( CallForward_OnReload(sFilename, 1) == Plugin_Continue )
		{
			bAllowReload = true;
		}
		else {
			PrintAll(-1, "\x03%s\x01 has prevented from been reloaded by 3rd party plugin", sFilename);
			return;
		}
	}
	if( bAskLoad )
	{
		if( CallForward_OnLoad(sFilename, 1) == Plugin_Continue )
		{
			bAllowLoad = true;
		}
		else {
			PrintAll(-1, "\x03%s\x01 has prevented from been loaded by 3rd party plugin", sFilename);
			return;
		}
	}
	
	if( g_iShowInfo & SHOW_IN_SERVER )
	{
		PrintToServer("[AutoReload] %s has changed timestamp. Reloading...", sFilename);
	}	
	
	ServerCommand("sm_reload_translations");
		
	if( bAllowReload )
	{
		ServerCommand("sm plugins reload %s", sFilename);
	}
	if( bAllowLoad )
	{
		ServerCommand("sm plugins load %s", sFilename);
	}
	
	ServerExecute();
	
	//
	// Notice for dev: do not use ServerCommandEx() for returning plugin load status since it is not always return a reply.
	
	CreateTimer(0.4, Timer_ShowStatus, CloneHandle(dp), TIMER_HNDL_CLOSE | TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ShowStatus(Handle timer, DataPack dp)
{
	static char sFilename[64];
	
	dp.Reset();
	dp.ReadString(sFilename, sizeof(sFilename));
	int iLoadOnly = dp.ReadCell();
	
	Handle hPlugin = FindPluginByFile(sFilename);
	PluginStatus ps;
	
	static char sStatus[32];

	if( hPlugin == INVALID_HANDLE )
	{
		sStatus = "NOT Loaded";
		ps = view_as<PluginStatus>(-1);
	}
	else {
		ps = GetPluginStatus(hPlugin);
		
		switch( ps )
		{
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
	}
	if( hPlugin && ps == Plugin_Running )
	{
		if( g_iShowInfo & SHOW_IN_CHAT )
		{
			PrintAll(-1 &~ SHOW_IN_SERVER, "\x03%s\x01 plugin reloaded. Status: \x03Running (OK)", sFilename);
		}
	}
	else {
		if( g_iShowInfo & SHOW_IN_CHAT )
		{
			PrintAll(-1 &~ SHOW_IN_SERVER, "\x03%s\x01 plugin reloaded. Status: \x04%s", sFilename, sStatus);
		}
		
		if( g_iErrLines )
		{
			if( g_iShowInfo & SHOW_IN_CHAT )
			{
				ParseErrorLog(sFilename);
			}
		}
	}
	if( iLoadOnly )
	{
		CallForward_OnLoad(sFilename, 0, view_as<int>(ps));
	}
	else {
		CallForward_OnReload(sFilename, 0, view_as<int>(ps));
	}
}

void ParseErrorLog( char[] sFilename )
{
	static char sLog[PLATFORM_MAX_PATH];
	char sDate[16], g_sBuf[10][192];
	
	int iUnix = GetTime();
	FormatTime(sDate, sizeof(sDate), "%Y%m%d", iUnix);
	BuildPath(Path_SM, sLog, sizeof(sLog), "logs/errors_%s.log", sDate);
	
	// check is error log recently updated
	int ft = GetFileTime(sLog, FileTime_LastChange);
	if( iUnix - ft > 2 )
	{
		return;
	}
	
	File f = OpenFile(sLog, "r", false);
	if( !f )
	{
		return;
	}
	
	// speed optimiz
	int iSize = FileSize(sLog, false);
	int MinBytes = sizeof(g_sBuf) * sizeof(g_sBuf[]);
	
	if( iSize > MinBytes )
	{
		f.Seek(iSize - MinBytes, SEEK_CUR);
	}
	
	int i, line = 0, match = -1;
	
	while( f.ReadLine( g_sBuf[line], sizeof(g_sBuf[])) )
	{
		if( StrContains(g_sBuf[line], sFilename, true) != -1 )
		{
			match = line;
		}
		else if( line == match )
		{
			match = -1;
		}
		
		++line;
		
		if( line == sizeof(g_sBuf) )
		{
			line = 0;
		}
	}

	if( match != -1 )
	{
		int desc = match - 1; // error description line
		int start;
		
		if( desc < 0 )
		{
			desc = sizeof(g_sBuf) - 1;
		}
		if( StrContains(g_sBuf[desc], "Exception", true) != -1 )
		{
			start = StrContains(g_sBuf[desc], "[SM]", true);
			if( start == -1)
			{
				start = 0;
			}
			PrintAll(-1 &~ SHOW_IN_SERVER, "\x04%s", g_sBuf[desc][start]);
		}
		
		for( i = 0; i < g_iErrLines && g_sBuf[match][0] != '\0'; i++ )
		{
			start = StrContains(g_sBuf[match], "[SM]", true);
			if( start == -1)
			{
				start = 0;
			}
			PrintAll(-1 &~ SHOW_IN_SERVER, "\x04%s", g_sBuf[match][start]);
			
			++match;
			
			if( match == sizeof(g_sBuf) )
			{
				match = 0;
			}
			
			if( match == line )
			{
				break;
			}
		}
	}
	f.Close();
}

void PrintAll( int iTargets, char[] format, any ... )
{
	static char buf[256];
	VFormat(buf, sizeof(buf), format, 3);
	
	if( g_iShowInfo & SHOW_IN_SERVER && iTargets & SHOW_IN_SERVER )
	{
		PrintToServer(buf);
	}
	
	if( g_iShowInfo & (SHOW_IN_CHAT | SHOW_IN_CONSOLE) && iTargets & (SHOW_IN_CHAT | SHOW_IN_CONSOLE) )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && !IsFakeClient(i) )
			{
				if( !g_iMsgFlags || GetUserFlagBits(i) & (g_iMsgFlags | ADMFLAG_ROOT) )
				{
					if( g_iShowInfo & SHOW_IN_CHAT && iTargets & SHOW_IN_CHAT )
					{
						PrintToChat(i, buf);
					}
					if( g_iShowInfo & SHOW_IN_CONSOLE && iTargets & SHOW_IN_CONSOLE )
					{
						PrintToConsole(i, buf);
					}
				}
			}
		}
	}
}

bool HasDisabledPlugins()
{
	Handle hIter = GetPluginIterator(); 
	if( hIter )
	{
		while( MorePlugins(hIter) ) 
		{
			if( ReadPlugin(hIter) == INVALID_HANDLE ) // https://forums.alliedmods.net/showthread.php?t=322175
			{
				return true;
			}
		}
	}
	return false;
}

void CallForward_OnUpdate(int pre)
{
	Action result;
	Call_StartForward(g_OnUpdateForward);
	Call_PushCell(pre);
	Call_Finish(result);
}

Action CallForward_OnLoad(char[] path, int pre, int status = -1)
{
	Action result;
	Call_StartForward(g_OnLoadForward);
	Call_PushString(path);
	Call_PushCell(pre);
	Call_PushCell(status);
	Call_Finish(result);
	return result;
}

Action CallForward_OnReload(char[] path, int pre, int status = -1)
{
	Action result;
	Call_StartForward(g_OnReloadForward);
	Call_PushString(path);
	Call_PushCell(pre);
	Call_PushCell(status);
	Call_Finish(result);
	return result;
}

Action CallForward_OnUnload(char[] path, int pre)
{
	Action result;
	Call_StartForward(g_OnUnloadForward);
	Call_PushString(path);
	Call_PushCell(pre);
	Call_Finish(result);
	return result;
}
