#if defined _autorecorder_console_included
  #endinput
#endif
#define _autorecorder_console_included

#include <autorecorder/logic>

public Action sm_recordstatus(int client, int args)
{
    if (!SourceTV_IsActive()) {
        ReplyToCommand(client, "SourceTV is not active.");
        
        return Plugin_Handled;
    }

    if (!SourceTV_IsRecording()) {
        ReplyToCommand(client, "SourceTV is not recording.");
        
        return Plugin_Handled;
    }
    
    char szLength[64];
    Util_FormatSeconds(szLength, sizeof(szLength), RoundToCeil(GetTickInterval() * SourceTV_GetRecordingTick()));
    
    char szSize[64];
    Util_FormatBytes(szSize, sizeof(szSize), FileSize(g_szDemoPath));
    
    ReplyToCommand(client, "Recording to \"%s\" (length: %s, size: %s)", g_szDemoPath, szLength, szSize);

    return Plugin_Handled;
}

public Action sm_record(int client, int args)
{
    if (!SourceTV_IsActive()) {
        ReplyToCommand(client, "SourceTV is not active.");
        
        return Plugin_Handled;
    }

    if (SourceTV_IsRecording()) {
        ReplyToCommand(client, "SourceTV is already recording.");
        
        return Plugin_Handled;
    }

    char path[PLATFORM_MAX_PATH] = "";
    if (args > 0) {
        GetCmdArg(1, path, sizeof(path));
    }

    char error[512];
    if (TryStartRecording(path, error, sizeof(error))) {
        ReplyToCommand(client, "Recording SourceTV demo to \"%s\"", g_szDemoPath);
        LogAction(client, -1, "Recording started by %L (path: \"%s\")", client, g_szDemoPath);
    }
    else {
        ReplyToCommand(client, "Unable to start recording (error: \"%s\")", error);
        LogError("Unable to start recording (by: %L, error: \"%s\")", client, error);
    }

    return Plugin_Handled;
}

public Action sm_stoprecord(int client, int args)
{
    if (!SourceTV_IsActive()) {
        ReplyToCommand(client, "SourceTV is not active.");
        
        return Plugin_Handled;
    }

    if (!SourceTV_IsRecording()) {
        ReplyToCommand(client, "SourceTV is not recording.");
        
        return Plugin_Handled;
    }

    SourceTV_StopRecording();
    
    ReplyToCommand(client, "Completed SourceTV demo \"%s\"", g_szDemoPath);
    LogAction(client, -1, "Recording stopped by %L", client);

    return Plugin_Handled;
}

void Console_Init()
{
    RegAdminCmd("sm_recordstatus", sm_recordstatus, ADMFLAG_ROOT, "sm_recordstatus - Show recording information.");
    RegAdminCmd("sm_record", sm_record, ADMFLAG_ROOT, "sm_record [path] - Record a new demo.");
    RegAdminCmd("sm_stoprecord", sm_stoprecord, ADMFLAG_ROOT, "sm_stoprecord - Stop recording.");
}
