#if defined _hltv_cameras_parser_included
  #endinput
#endif
#define _hltv_cameras_parser_included

#include <hltv_cameras/cache>
#include <@shqke/util/vector>

static bool s_bInSection = false;
static SMCParser s_hParser = null;
static char s_szCameraName[MAX_CAMERA_NAME];
static float s_vecOrigin[3];

public SMCResult Handler_ParseSectionStart(SMCParser smc, const char[] name, bool opt_quotes)
{
    if (s_bInSection) {
        return SMCParse_HaltFail;
    }
    
    s_bInSection = true;
    
    strcopy(s_szCameraName, sizeof(s_szCameraName), name);
    s_vecOrigin = NULL_VECTOR;
    
    return SMCParse_Continue;
}

public SMCResult Handler_ParseLeaveSection(SMCParser smc)
{
    if (!s_bInSection) {
        return SMCParse_HaltFail;
    }
    
    s_bInSection = false;
    
    if (!CameraCache_AddCamera(s_szCameraName, s_vecOrigin)) {
        return SMCParse_Halt;
    }
    
    return SMCParse_Continue;
}

public SMCResult Handler_ParseKeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
    if (!s_bInSection) {
        return SMCParse_HaltFail;
    }
    
    if (strcmp(key, "origin") == 0) {
        StringToVector(value, s_vecOrigin);
    }
    
    return SMCParse_Continue;
}

void CameraCache_Parse()
{
    if (s_hParser == null) {
        s_hParser = new SMCParser();
        s_hParser.OnEnterSection = Handler_ParseSectionStart;
        s_hParser.OnLeaveSection = Handler_ParseLeaveSection;
        s_hParser.OnKeyValue = Handler_ParseKeyValue;
    }
    
    CameraCache_Clear();
    s_bInSection = false;
    
    char gameName[64];
    GetGameFolderName(gameName, sizeof(gameName));
    
    char levelName[128];
    GetCurrentMap(levelName, sizeof(levelName));
    
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), CONFIG_PATH_FMT, gameName, levelName);
    
    s_hParser.ParseFile(path);
    
    HLTVDirector_BuildCameraList();
}
