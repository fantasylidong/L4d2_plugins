

// Config Cvar list
enum cvars_PluginCvars {
    eCvars_redirect_register_server,
    eCvars_redirect_force_ip,
    eCvars_redirect_force_query_ip,
    eCvars_redirect_force_query_ip_for_group,
    eCvars_redirect_server_order,
    eCvars_redirect_server_short_hostname,
    eCvars_redirect_my_groups,
    eCvars_redirect_show_in_groups,
    eCvars_redirect_advertise_follow,
    eCvars_redirect_expose_pw_for_groups,
    eCvars_redirect_follow_timeout,
    eCvars_redirect_server_queries_cooldown,
    eCvars_redirect_autocleanup_db,
    eCvars_redirect_advertise_period,
    eCvars_redirect_advertise_in_groups,
    eCvars_redirect_advertise_me_min_players,
    eCvars_redirect_advertise_me_min_slots,
    eCvars_redirect_short_advertise_message,
    eCvars_redirect_short_follow_message,
    
    eCvars_CVARS_COUNT
};

// Plugin Cvar handle storage
static Handle:g_hCvars_PluginCvars[eCvars_CVARS_COUNT] = { INVALID_HANDLE, ... };

stock cvars_Init()
{
    cvars_BuildPluginCvars();
}

stock cvars_Close()
{
    cvars_RestoreCvars(.keepedAlso = true, .clearLocked = true);
}

stock cvars_CreatePluginConVar(
        cvars_PluginCvars:cvarInternalId,
        String:cvarName[], String:cvarDefaultValue[], String:cvarDescription[],
        cvarFlags=FCVAR_PLUGIN | FCVAR_SPONLY,
        bool:cvarHasMin=false, Float:cvarMin=0.0,
        bool:cvarHasMax=false, Float:cvarMax=0.0
    )
{
    g_hCvars_PluginCvars[_:cvarInternalId] = CreateConVar(cvarName, cvarDefaultValue, cvarDescription, cvarFlags, cvarHasMin, cvarMin, cvarHasMax, cvarMax);
}

stock bool:cvars_GetPluginConvarBool(cvars_PluginCvars:cvarInternalId)
{
    return GetConVarBool(g_hCvars_PluginCvars[_:cvarInternalId]);
}

stock cvars_GetPluginConvarInt(cvars_PluginCvars:cvarInternalId)
{
    return GetConVarInt(g_hCvars_PluginCvars[_:cvarInternalId]);
}

stock Float:cvars_GetPluginConvarFloat(cvars_PluginCvars:cvarInternalId)
{
    return GetConVarFloat(g_hCvars_PluginCvars[_:cvarInternalId]);
}

stock cvars_GetPluginConvarString(cvars_PluginCvars:cvarInternalId, String:value[], maxLength)
{
    GetConVarString(g_hCvars_PluginCvars[_:cvarInternalId], value, maxLength);
}

stock cvars_SetPluginConvarBool(cvars_PluginCvars:cvarInternalId, bool:value, bool:replicate=false, bool:notify=false)
{
    SetConVarBool(g_hCvars_PluginCvars[_:cvarInternalId], value, replicate, notify);
}

stock cvars_SetPluginConvarInt(cvars_PluginCvars:cvarInternalId, value, bool:replicate=false, bool:notify=false)
{
    SetConVarInt(g_hCvars_PluginCvars[_:cvarInternalId], value, replicate, notify);
}

stock cvars_SetPluginConvarFloat(cvars_PluginCvars:cvarInternalId, Float:value, bool:replicate=false, bool:notify=false)
{
    SetConVarFloat(g_hCvars_PluginCvars[_:cvarInternalId], value, replicate, notify);
}

stock cvars_SetPluginConvarString(cvars_PluginCvars:cvarInternalId, const String:value[], bool:replicate=false, bool:notify=false)
{
    SetConVarString(g_hCvars_PluginCvars[_:cvarInternalId], value, replicate, notify);
}

stock cvars_HookPluginConvarChange(cvars_PluginCvars:cvarInternalId, ConVarChanged:callback)
{
    HookConVarChange(g_hCvars_PluginCvars[_:cvarInternalId], callback);
}

stock cvars_UnHookPluginConvarChange(cvars_PluginCvars:cvarInternalId, ConVarChanged:callback)
{
    UnhookConVarChange(g_hCvars_PluginCvars[_:cvarInternalId], callback);
}

stock cvars_BuildPluginCvars()
{
    // Create console variables
    CreateConVar("dm_redirect_version", VERSION, "Redirect version.", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    cvars_CreatePluginConVar(eCvars_redirect_register_server,           "redirect_register_server",             "1",        "Automatically register server in database.", .cvarHasMin = true, .cvarMin = 0.0, .cvarHasMax = true, .cvarMax = 1.0);
    cvars_CreatePluginConVar(eCvars_redirect_force_ip,                  "redirect_force_ip",                    "",         "Force the external IP of server (eg: \"10.20.30.40:27015\").");
    cvars_CreatePluginConVar(eCvars_redirect_force_query_ip,            "redirect_force_query_ip",              "",         "Force the query IP of server (eg: \"192.168.0.10:27015\").");
    cvars_CreatePluginConVar(eCvars_redirect_force_query_ip_for_group,  "redirect_force_query_ip_for_group",    "A",        "Groups that will use the query IP, others will use external IP");

    cvars_CreatePluginConVar(eCvars_redirect_server_order,              "redirect_server_order",                "1",        "Server display order, lowest value are displayed first.", .cvarHasMin = true, .cvarMin = 0.0);
    cvars_CreatePluginConVar(eCvars_redirect_server_short_hostname,     "redirect_server_short_hostname",       "",         "If non empty, use this name instead of hostname.");
    
    cvars_CreatePluginConVar(eCvars_redirect_my_groups,                 "redirect_my_groups",                   "A",        "Groups this server belongs to (each char is a group)");
    cvars_CreatePluginConVar(eCvars_redirect_show_in_groups,            "redirect_show_in_groups",              "A",        "Groups where this server is listed by !server command");
    cvars_CreatePluginConVar(eCvars_redirect_expose_pw_for_groups,      "redirect_expose_pw_for_groups",        "",         "Groups where this server expose it's sv_password (if set). Note that password is visible to players that select the server");
   
    cvars_CreatePluginConVar(eCvars_redirect_advertise_in_groups,       "redirect_advertise_in_groups",         "A",        "Groups where this server is advertised");
    cvars_CreatePluginConVar(eCvars_redirect_advertise_me_min_players,  "redirect_advertise_me_min_players",    "2",        "Minimum players to advertise this server", .cvarHasMin = true, .cvarMin = 0.0);
    cvars_CreatePluginConVar(eCvars_redirect_advertise_me_min_slots,    "redirect_advertise_me_min_slots",      "2",        "Minimum free slots to advertise this slots", .cvarHasMin = true, .cvarMin = 0.0);
    cvars_CreatePluginConVar(eCvars_redirect_advertise_period,          "redirect_advertise_period",            "120.0",    "Cycling server advertisement period. Set to -1 to disable.", .cvarHasMin = true, .cvarMin = -1.0);
    cvars_CreatePluginConVar(eCvars_redirect_advertise_follow,          "redirect_advertise_follow",            "1",        "Advertise !follow command when a player switched servers.", .cvarHasMin = true, .cvarMin = 0.0, .cvarHasMax = true, .cvarMax = 1.0);
    
    cvars_CreatePluginConVar(eCvars_redirect_follow_timeout,            "redirect_follow_timeout",              "2",        "Maximum follow advertise time in minutes after a player choose a server.");
    cvars_CreatePluginConVar(eCvars_redirect_server_queries_cooldown,   "redirect_server_queries_cooldown",     "5",        "Minimum time seconds between each server queries");
    cvars_CreatePluginConVar(eCvars_redirect_autocleanup_db,            "redirect_autocleanup_db",              "0",        "Automatically cleanup old database entries.", .cvarHasMin = true, .cvarMin = 0.0, .cvarHasMax = true, .cvarMax = 1.0);
    
    cvars_CreatePluginConVar(eCvars_redirect_short_advertise_message,   "redirect_short_advertise_message",     "0",        "Use a one line chat message for server adverts.", .cvarHasMin = true, .cvarMin = 0.0, .cvarHasMax = true, .cvarMax = 1.0);
    cvars_CreatePluginConVar(eCvars_redirect_short_follow_message,      "redirect_short_follow_message",        "0",        "Use a one line chat message for follow adverts.", .cvarHasMin = true, .cvarMin = 0.0, .cvarHasMax = true, .cvarMax = 1.0);
    
    cvars_HookAllCvars();    
}

stock cvars_HookAllCvars()
{
    for (new index = 0; index < _:eCvars_CVARS_COUNT; index++)
        cvars_HookPluginConvarChange(cvars_PluginCvars:index, cvars_Event_CvarChange);
}

stock cvars_UnHookAllCvars()
{
    for (new index = _:eCvars_dm_enabled; index < _:eCvars_CVARS_COUNT; index++)
        cvars_UnHookPluginConvarChange(cvars_PluginCvars:index, cvars_Event_CvarChange);
}

public cvars_Event_CvarChange(Handle:cvar, const String:oldValue[], const String:newValue[])
{
    UpdateState();
}
