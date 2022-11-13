#if defined _finale_maps_included_
  #endinput
#endif
#define _finale_maps_included_

#include "includes/rl4d2l_util"

static Handle:hFileFinaleMaps = INVALID_HANDLE;
static Handle:hTrieFinaleMaps = INVALID_HANDLE;

bool IsMissionFinalMap() {
    new String:sMapName[64];
    GetCurrentMapLower(sMapName, sizeof(sMapName));

    if (hFileFinaleMaps == INVALID_HANDLE) {
        new String:sFile[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, sFile, sizeof(sFile), "configs/finalemaps.ini");
        
        hFileFinaleMaps = OpenFile(sFile, "r");
        
        if (hFileFinaleMaps == INVALID_HANDLE)
        {
            SetFailState("[IsMissionFinalMap] \"%s\" not found!", sFile);
            return false;
        }
        
        if (hTrieFinaleMaps == INVALID_HANDLE)
            hTrieFinaleMaps = CreateTrie();
        
        decl String:sBuffer[256];
        while(ReadFileLine(hFileFinaleMaps, sBuffer, sizeof(sBuffer)))
        {
            TrimString(sBuffer);
            StrToLower(sBuffer);
            if((StrContains(sBuffer, "//") == -1) && (!StrEqual(sBuffer, "")))
            {
                SetTrieValue(hTrieFinaleMaps, sBuffer, 1);
            }
        }
    }

    new dummy;
    return GetTrieValue(hTrieFinaleMaps, sMapName, dummy);
}