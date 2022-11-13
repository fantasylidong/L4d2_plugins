#pragma semicolon 1
#pragma newdecls required

#define MAXSTEAMID              64

Handle g_hCvarEnabled = INVALID_HANDLE;
Handle g_hCvarDebug = INVALID_HANDLE;
Handle g_hCvarDatabaseConfig = INVALID_HANDLE;
char errorBuffer[255];
Handle db = INVALID_HANDLE;
Handle hIsVouchedStmt = INVALID_HANDLE;
Handle hInsertPlayerStmt = INVALID_HANDLE;
char g_sDatabaseConfig[64];
char g_sPrevSteamId[MAXSTEAMID] = "";
bool g_bVouchNext;
Handle hNextVouchTimer = INVALID_HANDLE;

public Plugin myinfo = 
{
    name = "Whitelist Database",
    author = "devilesk",
    description = "Restricts server to Steam IDs in a whitelist database",
    version = "0.2.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public void OnPluginStart() {
    g_hCvarEnabled = CreateConVar("whitelist_database", "0", "Enable whitelist database", 0, true, 0.0, true, 1.0);
    g_hCvarDebug = CreateConVar("whitelist_database_debug", "0", "Whitelist Database debug mode", 0, true, 0.0, true, 1.0);
    g_hCvarDatabaseConfig = CreateConVar(
            "whitelist_database_cfg",
            "whitelist_database",
            "Name of database keyvalue entry to use in databases.cfg",
            0, true, 0.0, false
        );
        
    RegConsoleCmd("sm_vouchnext", Command_VouchNext, "Autovouch the next unvouched player to join the server.");
    RegConsoleCmd("sm_vouchprev", Command_VouchPrev, "Vouch the last unvouched player to join the server.");
    RegConsoleCmd("sm_vouchlast", Command_VouchPrev, "Vouch the last unvouched player to join the server.");
    RegConsoleCmd("sm_vouch", Command_Vouch, "Vouch the given steam id.");
}

public Action Command_VouchNext(int client, int args)  {
    if (!GetConVarBool(g_hCvarEnabled)) return Plugin_Handled;
    if (!IsClientVouched(client)) return Plugin_Handled;
    
    PrintDebug("[Command_VouchNext] client: %i, g_bVouchNext: %i", client, g_bVouchNext);
    
    if (!g_bVouchNext) {
        g_bVouchNext = true;
        hNextVouchTimer = CreateTimer(600.0, DisableNextVouch);
        ReplyToCommand(client, "Autovouching the next unvouched player.");
    }
    else {
        g_bVouchNext = false;
        delete hNextVouchTimer;
        ReplyToCommand(client, "Not autovouching the next unvouched player.");
    }
    return Plugin_Handled;
}

public Action DisableNextVouch(Handle timer) {
    PrintDebug("[DisableNextVouch] Clearing timer. g_bVouchNext: %i", g_bVouchNext);
    g_bVouchNext = false;
    delete hNextVouchTimer;
}

public Action Command_VouchPrev(int client, int args)  {
    if (!GetConVarBool(g_hCvarEnabled)) return Plugin_Handled;
    if (!IsClientVouched(client)) return Plugin_Handled;
    
    PrintDebug("[Command_VouchPrev] client: %i, g_sPrevSteamId: %s", client, g_sPrevSteamId);
    
    if (!g_sPrevSteamId[0]) {
        ReplyToCommand(client, "No player to vouch.");
        return Plugin_Handled;
    }
    
    if (IsVouched(g_sPrevSteamId)) {
        ReplyToCommand(client, "Player already vouched.");
        return Plugin_Handled;
    }
    
    if (InsertPlayer(g_sPrevSteamId)) {
        ReplyToCommand(client, "Vouched player.");
    }
    else {
        ReplyToCommand(client, "Error vouching player.");
    }
    
    g_sPrevSteamId[0] = '\0';
    return Plugin_Handled;
}

public Action Command_Vouch(int client, int args)  {
    if (!GetConVarBool(g_hCvarEnabled)) return Plugin_Handled;
    if (!IsClientVouched(client)) return Plugin_Handled;
    
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_vouch \"<steamid>\"");
        return Plugin_Handled;
    }
    
    char sSteamId[MAXSTEAMID];
    GetCmdArg(1, sSteamId, sizeof(sSteamId));
    
    PrintDebug("[Command_Vouch] client: %i, sSteamId: %s", client, sSteamId);
    
    if (IsVouched(sSteamId)) {
        ReplyToCommand(client, "Player already vouched.");
        return Plugin_Handled;
    }
    
    if (InsertPlayer(sSteamId)) {
        ReplyToCommand(client, "Vouched player.");
    }
    else {
        ReplyToCommand(client, "Error vouching player.");
    }
    
    // stop storing previous steamid if we just explicitly vouched it
    if (StrEqual(sSteamId, g_sPrevSteamId, false)) {
        g_sPrevSteamId[0] = '\0';
    }
    return Plugin_Handled;
}

public void OnMapStart() {
    g_sPrevSteamId[0] = '\0';
    g_bVouchNext = false;
    delete hNextVouchTimer;
}

public void OnConfigsExecuted() {
    InitDatabase();
    InitQueries();
}

public void OnClientAuthorized(int client, const char[] sSteamId) {
    if (!GetConVarBool(g_hCvarEnabled)) return;
    if (IsFakeClient(client)) return;
    if (db == INVALID_HANDLE) return;
    
    bool bVouched = IsVouched(sSteamId);
    
    PrintDebug("[OnClientAuthorized] client: %i, sSteamId: %s, bVouched: %i, g_bVouchNext: %i", client, sSteamId, bVouched, g_bVouchNext);

    if (bVouched) return;
    
    if (g_bVouchNext) {
        if (InsertPlayer(sSteamId)) {
            PrintToChatAll("Vouched %N.", client);
        }
        else {
            PrintDebug("[OnClientAuthorized] Error vouching player. %s", sSteamId);
        }
        g_bVouchNext = false;
        delete hNextVouchTimer;
        KickClient(client, "You are not whitelisted");
        return;
    }
    
    strcopy(g_sPrevSteamId, sizeof(g_sPrevSteamId), sSteamId);
    KickClient(client, "You are not whitelisted");
    PrintToChatAll("!vouchprev or !vouch \"%s\" to whitelist %N.", sSteamId, client);
}

void InitDatabase() {
    GetConVarString(g_hCvarDatabaseConfig, g_sDatabaseConfig, sizeof(g_sDatabaseConfig));
    if (db != INVALID_HANDLE) {
        CloseHandle(db);
        db = INVALID_HANDLE;
    }
    db = SQL_Connect(g_sDatabaseConfig, false, errorBuffer, sizeof(errorBuffer));
    PrintDebug("[InitDatabase] g_sDatabaseConfig: %s", g_sDatabaseConfig);
    if (db == INVALID_HANDLE) {
        PrintToServer("Could not connect: %s", errorBuffer);
    }
    else {
        SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS `players` ( \
        `id` INT NOT NULL auto_increment, \
        `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
        `name` varchar(128), \
        `discord` varchar(48), \
        `steamid` varchar(32), \
        PRIMARY KEY  (`id`) \
        );");
    }
}

void InitQueries() {
    if (hInsertPlayerStmt != INVALID_HANDLE) {
        CloseHandle(hInsertPlayerStmt);
        hInsertPlayerStmt = INVALID_HANDLE;
    }
    if ( hInsertPlayerStmt == INVALID_HANDLE ) {
        hInsertPlayerStmt = SQL_PrepareQuery(db, "INSERT INTO players ( \
        id, \
        createdAt, \
        name, \
        steamid \
        ) VALUES ( NULL, \
            ?,?,? \
        )", errorBuffer, sizeof(errorBuffer));

        if ( hInsertPlayerStmt == INVALID_HANDLE ) {
            PrintDebug("[InitQueries] Prepare player query failed. %s", errorBuffer);
        }
        else {
            PrintDebug("[InitQueries] Prepare player query success.");
        }
    }
    
    if (hIsVouchedStmt != INVALID_HANDLE) {
        CloseHandle(hIsVouchedStmt);
        hIsVouchedStmt = INVALID_HANDLE;
    }
    if ( hIsVouchedStmt == INVALID_HANDLE ) {
        hIsVouchedStmt = SQL_PrepareQuery(db, "SELECT * FROM players WHERE steamid = ?", errorBuffer, sizeof(errorBuffer));

        if ( hIsVouchedStmt == INVALID_HANDLE ) {
            PrintDebug("[InitQueries] Prepare check vouch player query failed. %s", errorBuffer);
        }
        else {
            PrintDebug("[InitQueries] Prepare check vouch player query success.");
        }
    }
}

public bool IsClientVouched(int client) {
    char sSteamId[MAXSTEAMID];
    GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
    return IsVouched(sSteamId);
}

public bool IsVouched(const char[] sSteamId) {
    SQL_BindParamString(hIsVouchedStmt, 0, sSteamId, false);
    
    if (!SQL_Execute(hIsVouchedStmt)) {
        PrintToChatAll("[Whitelist] Failed to check vouch for player %s.", sSteamId);
        PrintDebug("[IsVouched] Failed to check vouch for player %s.", sSteamId);
        return false;
    }
    
    int count = SQL_GetRowCount(hIsVouchedStmt);
    PrintDebug("[IsVouched] sSteamId: %s, count: %i.", sSteamId, count);
    return count == 1;
}

public bool InsertPlayer(const char[] sSteamId) {
    if ( hInsertPlayerStmt == INVALID_HANDLE ) {
        PrintDebug("[InsertPlayer] Player query invalid.");
    }
    
    char sTmpTime[20];
    FormatTime( sTmpTime, sizeof(sTmpTime), "%Y-%m-%d %H:%M:%S" );

    SQL_BindParamString(hInsertPlayerStmt, 0, sTmpTime, false);
    SQL_BindParamString(hInsertPlayerStmt, 1, sSteamId, false);
    SQL_BindParamString(hInsertPlayerStmt, 2, sSteamId, false);
    
    if (!SQL_Execute(hInsertPlayerStmt)) {
        PrintToChatAll("[InsertPlayer] Failed to vouch player %s.", sSteamId);
        PrintDebug("[InsertPlayer] Failed to vouch player %s.", sSteamId);
        return false;
    }
    PrintDebug("[InsertPlayer] Vouched player %s.", sSteamId);
    return true;
}

stock void PrintDebug(const char[] Message, any ...) {
    if (GetConVarBool(g_hCvarDebug)) {
        char DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
    }
}