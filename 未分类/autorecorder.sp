#include <sourcemod>

#define REQUIRE_EXTENSIONS
#include <sourcetvmanager>

#include <autorecorder/logic>
#include <autorecorder/console>

public void OnPluginStart()
{
    Logic_Init();
    Console_Init();
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "sourcetvsupport") == 0 && SourceTV_IsRecording()) {
        SourceTV_StopRecording();
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int maxlen)
{
    switch (GetEngineVersion()) {
        case Engine_Left4Dead2, Engine_Left4Dead:
        {
            return APLRes_Success;
        }
    }

    strcopy(error, maxlen, "Game is not supported.");

    return APLRes_SilentFailure;
}

public Plugin myinfo =
{
    name = "[L4D/2] Automated Demo Recording",
    author = "shqke",
    description = "Plugin takes control over demo recording process allowing to record only useful footage",
    version = "1.2",
    url = "https://github.com/shqke/sp_public"
};
