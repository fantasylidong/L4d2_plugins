#if defined _autorecorder_logic_included
  #endinput
#endif
#define _autorecorder_logic_included

#include <@shqke/util/format>
#include <@shqke/util/convars>
#include <@shqke/util/files>
#include <@shqke/util/clients>

ConVar hostport = null;
ConVar mp_gamemode = null;
ConVar sm_server_uid = null;

ConVar sm_autorecord_enable = null;

ConVar sm_autorecord_minplayers = null;
ConVar sm_autorecord_minplayersdelay = null;
ConVar sm_autorecord_ignorebots = null;

ConVar sm_autorecord_roundsplit = null;
ConVar sm_autorecord_sizesplit = null;
ConVar sm_autorecord_lengthsplit = null;

ConVar sm_autorecord_allowoverwrites = null;
ConVar sm_autorecord_pathfmt = null;

float g_flLastMinPlayersTest = -1.0;

char g_szDemoPath[PLATFORM_MAX_PATH];
char g_szModFolder[PLATFORM_MAX_PATH];
char g_szLevelName[PLATFORM_MAX_PATH];

bool HaveEnoughPlayers()
{
    return Util_ClientsConnected(!sm_autorecord_ignorebots.BoolValue) >= sm_autorecord_minplayers.IntValue;
}

int FormatPathString(char[] buffer, int maxlength, const char[] format)
{
    bool expectSpecifier = false;
    int pos = 0;
    
    for (int i = 0; i < maxlength && pos < maxlength && format[i] != '\0'; i++) {
        if (format[i] == '%' && (expectSpecifier = !expectSpecifier)) {
            continue;
        }
        
        if (!expectSpecifier) {
            buffer[pos++] = format[i];
            
            continue;
        }
        
        switch (format[i]) {
            case 's': // Unix timestamp
            {
                pos += Format(buffer[pos], maxlength - pos, "%u", GetTime());
            }
            case 'q': // Random number
            {
                pos += Format(buffer[pos], maxlength - pos, "%u", GetURandomInt() % 100000);
            }
            case 'f': // Mod folder
            {
                pos += strcopy(buffer[pos], maxlength - pos, g_szModFolder);
            }
            case 'l': // Level name
            {
                pos += strcopy(buffer[pos], maxlength - pos, g_szLevelName);
            }
            case 'i': // String value of sm_server_uid
            {
                pos += Util_ConVarGetStringValue(sm_server_uid, buffer[pos], maxlength - pos);
            }
            case 'P': // String value of hostport
            {
                pos += Util_ConVarGetStringValue(hostport, buffer[pos], maxlength - pos, "l4d2");
            }
            case 'L': // String value of mp_gamemode
            {
                pos += Util_ConVarGetStringValue(mp_gamemode, buffer[pos], maxlength - pos, "coop");
            }
            default:
            {
                if (Util_IsCharTimeSpecifier(format[i])) {
                    static char s_format[3] = "%%";
                    s_format[1] = format[i];
                    
                    static char s_timeBuffer[128];
                    FormatTime(s_timeBuffer, sizeof(s_timeBuffer), s_format);
                    
                    pos += strcopy(buffer[pos], maxlength - pos, s_timeBuffer);
                }
            }
        }
        
        expectSpecifier = false;
    }
    
    buffer[pos] = '\0';
    
    return pos;
}

bool TryStartRecording(const char[] format, char[] error, int maxlength)
{
    if (!LibraryExists("sourcetvsupport")) {
        strcopy(error, maxlength, "Missing extension SourceTV Support");
        
        return false;
    }
    
    if (!SourceTV_IsMasterProxy()) {
        strcopy(error, maxlength, "Only SourceTV master proxy can record demos instantly");
        
        return false;
    }
    
    int pathlen = 0;
    // + 1 - overflow test to be exact when forming paths
    char path[PLATFORM_MAX_PATH + 1] = "";
    if (format[0] != '\0') {
        // Form a path from given format
        pathlen = FormatPathString(path, sizeof(path), format);
    }
    
    if (path[0] == '\0') {
        // Form a path from cvar sm_autorecord_pathfmt
        char cvarfmt[PLATFORM_MAX_PATH];
        sm_autorecord_pathfmt.GetString(cvarfmt, sizeof(cvarfmt));
        pathlen = FormatPathString(path, sizeof(path), cvarfmt);
    }
    
    if (path[0] == '\0') {
        // Form a path from default format
        pathlen = FormatPathString(path, sizeof(path), "auto-%Y%m%d-%H%M%S-%l-%q");
    }
    
    if (pathlen == sizeof(path) - 1) {
        Format(error, maxlength, "Buffer overflow (path: \"%s\")", path);
        
        return false;
    }
    
    if (!Util_IsValidPath(path)) {
        Format(error, maxlength, "Invalid path \"%s\"", path);
        
        return false;
    }
    
    // File mode - 0775 (u+rwx g+rwx o+rx), use umask on linux to override this
    if (!Util_CreateDirHierarchy(path, 0x1FD)) {
        Format(error, maxlength, "Failed to create directory hierarchy (path: \"%s\")", path);
        
        return false;
    }
    
    bool bAllowOverwrites = sm_autorecord_allowoverwrites.BoolValue;
    pathlen = Util_StripKnownExtension(path, ".dem");
    
    // perf test 0.0244
    for (int i = 0; ; i++) {
        if (i == 10000) {
            path[pathlen] = '\0';
            Format(error, maxlength, "Failed to form a unique file name - ran out of retries (path: \"%s.dem\")", path);
            
            return false;
        }
        
        int written = Format(path[pathlen], sizeof(path) - pathlen, ( i == 0 ) ? ".dem" : ".%d.dem", i);
        if (pathlen + written == sizeof(path) - 1) {
            path[pathlen] = '\0';
            
            if (i == 0) {
                Format(error, maxlength, "Failed to form a file name - buffer overflow (path: \"%s.dem\")", path);
            }
            else {
                Format(error, maxlength, "Failed to form a unique file name - buffer overflow (path: \"%s.%d.dem\")", path, i);
            }
            
            return false;
        }
        
        if (bAllowOverwrites || !FileExists(path)) {
            // Formed a file path - now start recording
            break;
        }
    }
    
    if (!SourceTV_StartRecording(path)) {
        Format(error, maxlength, "Failed to start a recording (path: \"%s\")", path);
        
        return false;
    }
    
    return true;
}

void TryStartAutoRecording(const char[] reason)
{
    if (!sm_autorecord_enable.BoolValue) {
        return;
    }

    if (!SourceTV_IsActive()) {
        return;
    }
    
    if (!SourceTV_IsMasterProxy()) {
        return;
    }

    if (SourceTV_IsRecording()) {
        return;
    }

    if (!HaveEnoughPlayers()) {
        return;
    }
    
    // CHLTVServer::StartMaster stops recording that round_start has initiated
    // Event order on map change:
    // round_start (gametime = 1.0)
    // CHLTVServer::StartMaster() - no convenient trigger
    // OnMapStart() (gametime > 1.0) - works in coop, versus and survival
    if (GetGameTime() == 1.0) {
        return;
    }

    char error[512];
    if (TryStartRecording(NULL_STRING, error, sizeof(error))) {
        LogMessage("Started autorecording (reason: \"%s\")", reason);
    }
    else {
        LogError("Unable to start autorecording (error: \"%s\")", error);
    }
}

public void Handler_Frame_CheckStopRecording(any data)
{
    if (!sm_autorecord_enable.BoolValue) {
        return;
    }
    
    if (!SourceTV_IsRecording()) {
        return;
    }
    
    if (g_flLastMinPlayersTest != -1.0 && g_flLastMinPlayersTest + sm_autorecord_minplayersdelay.FloatValue < GetEngineTime()) {
        SourceTV_StopRecording();
        
        return;
    }
    
    if (g_flLastMinPlayersTest == -1.0 && !HaveEnoughPlayers()) {
        if (sm_autorecord_minplayersdelay.FloatValue <= 0.0) {
            // Stop recording immediately
            SourceTV_StopRecording();
            
            return;
        }
        else {
            // Resolve delay later
            g_flLastMinPlayersTest = GetEngineTime();
        }
    }
    
    int maxsize = sm_autorecord_sizesplit.IntValue;
    if (maxsize > 0) {
        int bytes = FileSize(g_szDemoPath);
        if (bytes / 1000 / 1000 >= maxsize) {
            char szSize[64];
            Util_FormatBytes(szSize, sizeof(szSize), bytes);
            
            LogMessage("Restarting demo recording (size: %s)", szSize);
            
            SourceTV_StopRecording();
            TryStartAutoRecording("Max demo file size reached");
            
            return;
        }
    }
    
    int maxlength = sm_autorecord_lengthsplit.IntValue;
    if (maxlength > 0) {
        int seconds = RoundToCeil(GetTickInterval() * SourceTV_GetRecordingTick());
        if (seconds / 60 >= maxlength) {
            char szLength[64];
            Util_FormatSeconds(szLength, sizeof(szLength), seconds);
            
            LogMessage("Restarting demo recording (length: %s)", szLength);
            
            SourceTV_StopRecording();
            TryStartAutoRecording("Max demo length reached");
            
            return;
        }
    }
}

public Action RunThink(Handle timer)
{
    Handler_Frame_CheckStopRecording(0);

    return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
    TryStartAutoRecording("Client joined");
}

public void OnClientConnected(int client)
{
    if (g_flLastMinPlayersTest != -1.0 && HaveEnoughPlayers()) {
        // Reset timer
        g_flLastMinPlayersTest = -1.0;
    }
}

public void OnClientDisconnect_Post(int client)
{
    RequestFrame(Handler_Frame_CheckStopRecording);
}

public void Event_round_start(Event event, const char[] name, bool dontBroadcast)
{
    if (sm_autorecord_enable.BoolValue && sm_autorecord_roundsplit.BoolValue) {
        SourceTV_StopRecording();
        TryStartAutoRecording("Round started");
    }
}

// SourceTV Manager
public void SourceTV_OnStartRecording(int instance, const char[] filename)
{
    SourceTV_GetDemoFileName(g_szDemoPath, sizeof(g_szDemoPath));

    RequestFrame(Handler_Frame_CheckStopRecording);
}

public void SourceTV_OnStopRecording(int instance, const char[] filename, int recordingtick)
{
    g_flLastMinPlayersTest = -1.0;
}

public void OnConfigsExecuted()
{
    TryStartAutoRecording("Config executed");
}

public void Handler_Frame_MapStart(any data)
{
    TryStartAutoRecording("Map started");
}

public void OnMapStart()
{
    char path[PLATFORM_MAX_PATH];
    GetCurrentMap(path, sizeof(path));
    Util_UnqualifiedFileName(g_szLevelName, sizeof(g_szLevelName), path);
    
    // RequestFrame would deal with server not processing frames
    RequestFrame(Handler_Frame_MapStart);
}

public void Handler_ConVar_Change(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (SourceTV_IsRecording()) {
        RequestFrame(Handler_Frame_CheckStopRecording);
    }
    else {
        TryStartAutoRecording("ConVar change condition trigger");
    }
}

void Logic_Init()
{
    hostport = FindConVar("hostname");
    mp_gamemode = FindConVar("mp_gamemode");

    sm_server_uid = CreateConVar("sm_server_uid", "", "Unique server ID string");

    sm_autorecord_enable = CreateConVar("sm_autorecord_enable", "1", "Enable autorecording features");
    
    sm_autorecord_minplayers = CreateConVar("sm_autorecord_minplayers", "1", "Minimum players required to allow demo recording");
    sm_autorecord_minplayersdelay = CreateConVar("sm_autorecord_minplayersdelay", "0.5", "Delay before stopping a demo, in seconds", FCVAR_NONE, true, 0.0, true, 300.0);
    sm_autorecord_ignorebots = CreateConVar("sm_autorecord_ignorebots", "1", "Ignore bots when counting players");
    
    sm_autorecord_roundsplit = CreateConVar("sm_autorecord_roundsplit", "0", "Restart recording on every round_start");
    sm_autorecord_sizesplit = CreateConVar("sm_autorecord_sizesplit", "0", "Restart recording if demo file has reached max size, in megabytes");
    sm_autorecord_lengthsplit = CreateConVar("sm_autorecord_lengthsplit", "0", "Restart recording after time of footage, in minutes");
    
    sm_autorecord_allowoverwrites = CreateConVar("sm_autorecord_allowoverwrites", "0", "Allow file overwrites, or append .i.dem to the end of path");
    sm_autorecord_pathfmt = CreateConVar("sm_autorecord_pathfmt", "addons/record/%Y%m%d/%P/auto-%H%M%S-%l-%q", "Format string specifying a path where to record demo files.\n"
        ... "	Available specifiers:\n"
        ... "	%s - unix timestamp of when recording has started\n"
        ... "	%q - randomly generated number in range [0-99999]\n"
        ... "	%f - game folder (e.g. left4dead2)\n"
        ... "	%l - level name without extension (e.g. c8m1_apartment)\n"
        ... "	%i - unique id (from convar sm_server_uid)\n"
        ... "	%P - server game port (from convar hostport)\n"
        ... "	%L - game mode (from convar mp_gamemode)\n"
        ... "	%% - a % sign\n"
        ... "	Single character specifiers from https://www.cplusplus.com/reference/ctime/strftime/\n");
        
    sm_autorecord_minplayers.AddChangeHook(Handler_ConVar_Change);
    sm_autorecord_ignorebots.AddChangeHook(Handler_ConVar_Change);
    sm_autorecord_minplayersdelay.AddChangeHook(Handler_ConVar_Change);
    sm_autorecord_sizesplit.AddChangeHook(Handler_ConVar_Change);
    sm_autorecord_lengthsplit.AddChangeHook(Handler_ConVar_Change);
    
    HookEvent("round_start", Event_round_start, EventHookMode_PostNoCopy);
    CreateTimer(5.0, RunThink, .flags = TIMER_REPEAT);
    
    GetGameFolderName(g_szModFolder, sizeof(g_szModFolder));
    
    if (SourceTV_IsRecording()) {
        SourceTV_OnStartRecording(0, NULL_STRING);
    }
}
