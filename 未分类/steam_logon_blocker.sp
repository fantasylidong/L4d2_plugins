#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.1"

#include <sourcemod>
#include <dhooks>

int
	g_iOffsets_CBaseClient_GetUserID,
	g_iOffsets_CNetChan_GetName,
	g_iOffsets_CNetChan_last_received,
	g_iOffsets_CNetChan_m_Timeout;

bool
	g_bBlockTimeout;

ConVar
	g_cvBlockCodes,
	g_cvBlockTimeOut;

ArrayList
	g_aBlockCodes;

char
	g_sLogPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "L4D2 No steam logon blocker",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	InitGameData();
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_no_steam_logon_blocker.log");

	CreateConVar("l4d2_no_steam_logon_blocker_version", VERSION, "Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvBlockCodes = CreateConVar("l4d2_no_steam_logon_blocker_code", "1,6", "Code to block disconnect, using comma split.\nhttps://github.com/alliedmodders/hl2sdk/blob/sdk2013/public/steam/steamclientpublic.h#L183");
	g_cvBlockTimeOut = CreateConVar("l4d2_no_steam_logon_blocker_timeout", "0", "block timeout");

	GetCvars();

	g_cvBlockCodes.AddChangeHook(OnConVarChanged);
	g_cvBlockTimeOut.AddChangeHook(OnConVarChanged);

	AutoExecConfig(true, "l4d2_no_steam_logon_blocker");
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bBlockTimeout = g_cvBlockTimeOut.BoolValue;

	delete g_aBlockCodes;
	g_aBlockCodes = new ArrayList();

	char sBuffer[64], sCode[10][3];
	int iPieces, iCode;

	g_cvBlockCodes.GetString(sBuffer, sizeof(sBuffer));
	iPieces = ExplodeString(sBuffer, ",", sCode, sizeof(sCode), sizeof(sCode[]));

	for (int i = 0; i < iPieces; i++)
	{
		iCode = StringToInt(sCode[i]);
		if (iCode > 0)
			g_aBlockCodes.Push(iCode);
	}
}

/*
https://github.com/alliedmodders/hl2sdk/blob/sdk2013/public/steam/steamclientpublic.h#L183
enum EAuthSessionResponse
{
	k_EAuthSessionResponseOK = 0,							// Steam has verified the user is online, the ticket is valid and ticket has not been reused.
	k_EAuthSessionResponseUserNotConnectedToSteam = 1,		// The user in question is not connected to steam
	k_EAuthSessionResponseNoLicenseOrExpired = 2,			// The license has expired.
	k_EAuthSessionResponseVACBanned = 3,					// The user is VAC banned for this game.
	k_EAuthSessionResponseLoggedInElseWhere = 4,			// The user account has logged in elsewhere and the session containing the game instance has been disconnected.
	k_EAuthSessionResponseVACCheckTimedOut = 5,				// VAC has been unable to perform anti-cheat checks on this user
	k_EAuthSessionResponseAuthTicketCanceled = 6,			// The ticket has been canceled by the issuer
	k_EAuthSessionResponseAuthTicketInvalidAlreadyUsed = 7,	// This ticket has already been used, it is not valid.
	k_EAuthSessionResponseAuthTicketInvalid = 8,			// This ticket is not from a user instance currently connected to steam.
	k_EAuthSessionResponsePublisherIssuedBan = 9,			// The user is banned for this game. The ban came via the web api and not VAC
};

code 1,6,7,8: No Steam logon
code 6: If client does not connect to Steam within a short time, Will time out.
*/
MRESReturn OnValidateAuthTicketResponseHelperPre(Address pCSteam3Server, DHookParam hParams)
{
	Address pCBaseClient = hParams.GetAddress(1);
	int userid = LoadFromAddress(pCBaseClient + view_as<Address>(g_iOffsets_CBaseClient_GetUserID), NumberType_Int32);
	int client = GetClientOfUserId(userid);

	if (client > 0 && client <= MaxClients && IsClientConnected(client) && !IsFakeClient(client))
	{
		int code = hParams.Get(2);

		if (g_aBlockCodes.FindValue(code) != -1)
		{
			LogToFileEx(g_sLogPath, "%N received failure code: %i, blocked disconnect", client, code);
			return MRES_Supercede;
		}
		else LogToFileEx(g_sLogPath, "%N received failure code: %i", client, code);
	}
	else LogToFileEx(g_sLogPath, "invalid player: client = %i, userid = %i", client, userid);

	return MRES_Ignored;
}

/*
// return (last_received + m_Timeout) < net_time;
// 
// last_received = 55.29(GetEngineTime = 56.27), m_Timeout = 65.00, net_time = 55.29
// last_received = 55.29(GetEngineTime = 56.28), m_Timeout = 65.00, net_time = 55.31
// last_received = 55.36(GetEngineTime = 56.35), m_Timeout = 65.00, net_time = 55.37
// last_received = 55.36(GetEngineTime = 56.37), m_Timeout = 65.00, net_time = 55.39
*/
MRESReturn OnTimedOutCheckPost(Address pCNetChan, DHookReturn hReturn)
{
	if (hReturn.Value == true && g_bBlockTimeout)
	{
		char sName[128];
		GetName(pCNetChan, sName, sizeof(sName));

		float m_Timeout = LoadFromAddress(pCNetChan + view_as<Address>(g_iOffsets_CNetChan_m_Timeout), NumberType_Int32);
		if (m_Timeout == 300.0) // do not block.
		{
			LogToFileEx(g_sLogPath, "%s Connection timed out", sName);
			return MRES_Ignored;
		}

		StoreToAddress(pCNetChan + view_as<Address>(g_iOffsets_CNetChan_last_received), GetEngineTime(), NumberType_Int32);
		LogToFileEx(g_sLogPath, "%s timed out, blocked disconnect", sName);

		hReturn.Value = false;
		return MRES_Override;
	}
	return MRES_Ignored;
}

int GetName(Address pCNetChan, char[] buffer, int maxlength)
{
	int i;
	char sChar;
	Address pAddr = pCNetChan + view_as<Address>(g_iOffsets_CNetChan_GetName);

	do
	{
		sChar = view_as<int>(LoadFromAddress(pAddr + view_as<Address>(i), NumberType_Int8));
		buffer[i] = sChar;
	} while (sChar && ++i < maxlength - 1);

	return i;
}

void InitGameData()
{
	GameData hGameData = new GameData("l4d2_no_steam_logon_blocker");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_no_steam_logon_blocker.txt\" gamedata.");

	DynamicDetour dDetour;

	dDetour = DynamicDetour.FromConf(hGameData, "CSteam3Server::OnValidateAuthTicketResponseHelper");
	if (dDetour == null)
		SetFailState("Failed to create DynamicHook: CSteam3Server::OnValidateAuthTicketResponseHelper");
	if (!dDetour.Enable(Hook_Pre, OnValidateAuthTicketResponseHelperPre))
		SetFailState("Failed to detour pre: CSteam3Server::OnValidateAuthTicketResponseHelper");

	dDetour = DynamicDetour.FromConf(hGameData, "CNetChan::IsTimedOut");
	if (dDetour == null)
		SetFailState("Failed to create DynamicHook: CNetChan::IsTimedOut");
	if (!dDetour.Enable(Hook_Post, OnTimedOutCheckPost))
		SetFailState("Failed to detour post: CNetChan::IsTimedOut");

	g_iOffsets_CBaseClient_GetUserID = hGameData.GetOffset("CBaseClient::GetUserID");
	if (g_iOffsets_CBaseClient_GetUserID == -1)
		SetFailState("Failed to get CBaseClient::GetUserID offsets");
	
	g_iOffsets_CNetChan_GetName = hGameData.GetOffset("CNetChan::GetName");
	if (g_iOffsets_CNetChan_GetName == -1)
		SetFailState("Failed to get CNetChan::GetName offsets");
	
	g_iOffsets_CNetChan_last_received = hGameData.GetOffset("CNetChan::last_received");
	if (g_iOffsets_CNetChan_last_received == -1)
		SetFailState("Failed to get CNetChan::last_received offsets");

	g_iOffsets_CNetChan_m_Timeout = hGameData.GetOffset("CNetChan::m_Timeout");
	if (g_iOffsets_CNetChan_m_Timeout == -1)
		SetFailState("Failed to get CNetChan::m_Timeout offsets");

	delete hGameData;
}
