native IsModeActive();
native GetModeValueInt(const String:key[], defvalue = 0);
native GetModeValueVector(const String:key[], Float:vector[3], Float:defvalue[3] = NULL_VECTOR);
native GetModeValueString(const String:key[], String:value[], maxlength, const String:defvalue[]);
native CopyModeSubsection(Handle:kv, const String:section[]);

forward OnModeLoad();
forward OnModeLoaded();
forward OnModeUnLoad();
forward OnModeUnLoaded();