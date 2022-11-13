#if defined _first_maps_included_
  #endinput
#endif
#define _first_maps_included_

#include "includes/rl4d2l_util"

static Handle:hFileFirstMaps = INVALID_HANDLE;
static Handle:hTrieFirstMaps = INVALID_HANDLE;

bool IsMissionFirstMap() {
    new String:sMapName[64];
    GetCurrentMapLower(sMapName, sizeof(sMapName));

    if (hFileFirstMaps == INVALID_HANDLE) {
        new String:sFile[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, sFile, sizeof(sFile), "configs/firstmaps.ini");
        
        hFileFirstMaps = OpenFile(sFile, "r");
        
        if (hFileFirstMaps == INVALID_HANDLE)
        {
            SetFailState("[IsMissionFirstMap] \"%s\" not found!", sFile);
            return false;
        }
        
        if (hTrieFirstMaps == INVALID_HANDLE)
            hTrieFirstMaps = CreateTrie();
        
        decl String:sBuffer[256];
        while(ReadFileLine(hFileFirstMaps, sBuffer, sizeof(sBuffer)))
        {
            TrimString(sBuffer);
            StrToLower(sBuffer);
            if((StrContains(sBuffer, "//") == -1) && (!StrEqual(sBuffer, "")))
            {
                SetTrieValue(hTrieFirstMaps, sBuffer, 1);
            }
        }
    }

    new dummy;
    return GetTrieValue(hTrieFirstMaps, sMapName, dummy);
}