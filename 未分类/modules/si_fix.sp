//控制coop base versus多特模式下的特感刷新种类
//#pragma semicolon 1
//#include <sourcemod>
//#include <left4downtown.inc>
new Handle: hHunterLimit = INVALID_HANDLE;
new iHunterLimit; 
new Handle: hSmokerLimit = INVALID_HANDLE;
new iSmokerLimit; 
new Handle: hJockeyLimit = INVALID_HANDLE;
new iJockeyLimit; 
new Handle: hChargerLimit = INVALID_HANDLE;
new iChargerLimit; 
new Handle: hBoomerLimit = INVALID_HANDLE;
new iBoomerLimit; 
new Handle: hSpitterLimit = INVALID_HANDLE;
new iSpitterLimit; 
new Handle: hSpecialLimit = INVALID_HANDLE;
new iSpecialLimit; 
public Fix_PluginStart()
{
    // cvars
	hSpecialLimit = FindConVar("l4d_infected_limit");
	iSpecialLimit = GetConVarInt(hSpecialLimit);
	hHunterLimit = FindConVar("z_hunter_limit");
    iHunterLimit = GetConVarInt(hHunterLimit);
	hJockeyLimit = FindConVar("z_jockey_limit");
    iJockeyLimit = GetConVarInt(hJockeyLimit);
	hSmokerLimit = FindConVar("z_smoker_limit");
    iSmokerLimit = GetConVarInt(hSmokerLimit);
	hChargerLimit = FindConVar("z_charger_limit");
    iChargerLimit = GetConVarInt(hChargerLimit);
	hBoomerLimit = FindConVar("z_boomer_limit");
    iBoomerLimit = GetConVarInt(hBoomerLimit);
	hSpitterLimit = FindConVar("z_spitter_limit");
    iSpitterLimit = GetConVarInt(hSpitterLimit);
    HookConVarChange(hHunterLimit, Cvar_HunterLimitChange);
	HookConVarChange(hSmokerLimit, Cvar_SmokerLimitChange);
	HookConVarChange(hJockeyLimit, Cvar_JockeyLimitChange);
	HookConVarChange(hChargerLimit, Cvar_ChargerLimitChange);
	HookConVarChange(hSpitterLimit, Cvar_SpitterLimitChange);
	HookConVarChange(hBoomerLimit, Cvar_BoomerLimitChange);
	HookConVarChange(hSpecialLimit, Cvar_SpecialLimitChange);
}
public Cvar_HunterLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{ 
	iHunterLimit = StringToInt(newValue); 
}  
public Cvar_ChargerLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{ 
	iChargerLimit = StringToInt(newValue); 
}
public Cvar_SmokerLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{ 
	iSmokerLimit = StringToInt(newValue); 
}
public Cvar_JockeyLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{ 
	iJockeyLimit = StringToInt(newValue); 
}
public Cvar_BoomerLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{ 
	iBoomerLimit = StringToInt(newValue); 
}
public Cvar_SpitterLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{ 
	iSpitterLimit = StringToInt(newValue); 
}
public Cvar_SpecialLimitChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{ 
	iSpecialLimit = StringToInt(newValue); 
}
/* -------------------------------
 *      General hooks / events
 * ------------------------------- */
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
    if (strcmp(key,"HunterLimit"))
    {
        retVal = iHunterLimit;
        return Plugin_Handled;
    }
	if (strcmp(key,"SmokerLimit"))
    {
        retVal = iSmokerLimit;
        return Plugin_Handled;
    }
	if (strcmp(key,"JockeyLimit"))
    {
        retVal = iJockeyLimit;
        return Plugin_Handled;
    }
	if (strcmp(key,"ChargerLimit"))
    {
        retVal = iChargerLimit;
        return Plugin_Handled;
    }
	if (strcmp(key,"BoomerLimit"))
    {
        retVal = iBoomerLimit;
        return Plugin_Handled;
    }
	if (strcmp(key,"SpitterLimit"))
    {
        retVal = iSpitterLimit;
        return Plugin_Handled;
    }
	if (strcmp(key,"MaxSpecials"))
    {
        retVal = iSpecialLimit;
        return Plugin_Handled;
    }
	if (strcmp(key,"DominatorLimit"))
    {
        retVal = iSpecialLimit;
        return Plugin_Handled;
    }
	if (strcmp(key,"cm_MaxSpecials"))
    {
        retVal = iSpecialLimit;
        return Plugin_Handled;
    }
    return Plugin_Continue;
}
