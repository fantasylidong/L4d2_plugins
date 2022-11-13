#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_engine>
#include <sdktools_entinput>

#include <hltv_cameras/sdk>
#include <hltv_cameras/cache>
#include <hltv_cameras/parser>
#include <@shqke/util/vector>

public Action sm_addhltvcamera(int client, int argc)
{
    char baseCameraName[MAX_CAMERA_NAME];
    GetCmdArg(1, baseCameraName, sizeof(baseCameraName));
    
    if (baseCameraName[0] == '\0' || baseCameraName[0] == '*') {
        strcopy(baseCameraName, sizeof(baseCameraName), "camera");
    }
    
    // Autogenerate camera name
    char cameraName[MAX_CAMERA_NAME];
    CameraCache_GenerateName(cameraName, sizeof(cameraName), baseCameraName);
    
    float origin[3];
    
    if (argc >= 2) {
        char value[32];
        GetCmdArg(2, value, sizeof(value));
        StringToVector(value, origin);
    }
    else if (client != 0) {
        GetClientEyePosition(client, origin);
    }
    
    if (!CameraCache_AddCamera(cameraName, origin)) {
        ReplyToCommand(client, "Couldn't add a new camera (engine supports up to %d).", MAX_NUM_CAMERAS);
        
        return Plugin_Handled;
    }
    
    CameraCache_Save();
    
    HLTVDirector_BuildCameraList();
    
    ReplyToCommand(client, "Successfully added new camera \"%s\".", cameraName);
    LogAction(client, -1, "Added camera \"%s\" (origin: %f %f %f) by %L", cameraName, origin[0], origin[1], origin[2], client);
    
    return Plugin_Handled;
}

public Action sm_sethltvcamera(int client, int argc)
{
    char cameraName[MAX_CAMERA_NAME];
    GetCmdArg(1, cameraName, sizeof(cameraName));
    
    int index = CameraCache_IndexFromName(cameraName);
    if (index == -1) {
        ReplyToCommand(client, "Camera \"%s\" doesn't exist.", cameraName);
        
        return Plugin_Handled;
    }
    
    float origin[3];
    
    if (argc >= 2) {
        char value[32];
        GetCmdArg(2, value, sizeof(value));
        StringToVector(value, origin);
    }
    else if (client != 0) {
        GetClientEyePosition(client, origin);
    }
    
    CameraCache_MoveCamera(index, origin);
    CameraCache_Save();
    
    ReplyToCommand(client, "Successfully moved camera \"%s\" to %f %f %f.", cameraName, origin[0], origin[1], origin[2]);
    LogAction(client, -1, "Added camera \"%s\" (origin: %f %f %f) by %L", cameraName, origin[0], origin[1], origin[2], client);
    
    return Plugin_Handled;
}

public Action sm_delhltvcamera(int client, int argc)
{
    char cameraName[MAX_CAMERA_NAME];
    GetCmdArg(1, cameraName, sizeof(cameraName));
    
    int index = CameraCache_IndexFromName(cameraName);
    if (index == -1) {
        ReplyToCommand(client, "Camera \"%s\" doesn't exist.", cameraName);
        
        return Plugin_Handled;
    }
    
    float origin[3];
    CameraCache_GetOrigin(index, origin);
    
    CameraCache_DeleteCamera(index);
    CameraCache_Save();
    
    ReplyToCommand(client, "Successfully removed camera \"%s\".", cameraName);
    LogAction(client, -1, "Removed camera \"%s\" (origin: %f %f %f) by %L", cameraName, origin[0], origin[1], origin[2], client);
    
    return Plugin_Handled;
}

public Action sm_clearhltvcameras(int client, int argc)
{
    // TODO: log removed cameras
    CameraCache_Clear();
    CameraCache_Save();
    
    ReplyToCommand(client, "Successfully cleared camera cache.");
    LogAction(client, -1, "Cleared camera cache by %L", client);
    
    return Plugin_Handled;
}

public Action sm_reloadhltvcameras(int client, int argc)
{
    CameraCache_Parse();
    
    ReplyToCommand(client, "Successfully reloaded from camera config.");
    
    return Plugin_Handled;
}

public Action sm_listhltvcameras(int client, int argc)
{
    CameraCache_List(client);
    
    return Plugin_Handled;
}

public void OnMapStart()
{
    // With point_viewcontrol being in preserved list, OnMapStart should be enough
    CameraCache_Parse();
}

public void OnPluginEnd()
{
    CameraCache_Clear();
}

public void OnPluginStart()
{
    GameConfig_LoadOrFail();
    CameraCache_Init();
    
    RegAdminCmd("sm_addhltvcamera", sm_addhltvcamera, ADMFLAG_ROOT, "sm_addhltvcamera [name|*] [origin] - place unique camera entity at given or current position");
    RegAdminCmd("sm_sethltvcamera", sm_sethltvcamera, ADMFLAG_ROOT, "sm_sethltvcamera [name] [origin] - replace existing camera entity with given or current position");
    RegAdminCmd("sm_delhltvcamera", sm_delhltvcamera, ADMFLAG_ROOT, "sm_delhltvcamera [name] - remove camera entity from config");
    RegAdminCmd("sm_clearhltvcameras", sm_clearhltvcameras, ADMFLAG_ROOT, "sm_clearhltvcameras - clear (empty) config");
    RegAdminCmd("sm_reloadhltvcameras", sm_reloadhltvcameras, ADMFLAG_ROOT, "sm_reloadhltvcameras - reload from config");
    RegAdminCmd("sm_listhltvcameras", sm_listhltvcameras, ADMFLAG_ROOT, "sm_listhltvcameras - list cameras in cache");
}

public Plugin myinfo =
{
    name = "Manage HLTV Cameras",
    author = "shqke",
    description = "Manage point_viewcontrol entities used by HLTV Director on the fly",
    version = "1.6",
    url = "https://github.com/shqke/sp_public"
};
