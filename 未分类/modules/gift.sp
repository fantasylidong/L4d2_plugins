#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define GAMEDATA			"l4d2_gift_rewards"

Handle sdkCreateGift;

ArrayList g_ByteSaved;
Address g_Address;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void GF_PluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	int iOffset = GameConfGetOffset(hGameData, "Patch_Offset");
	if( iOffset == -1 ) SetFailState("Failed to load \"Patch_Offset\" offset.");

	int iByteMatch = GameConfGetOffset(hGameData, "Patch_Byte");
	if( iByteMatch == -1 ) SetFailState("Failed to load \"Patch_Byte\" byte.");

	int iByteCount = GameConfGetOffset(hGameData, "Patch_Count");
	if( iByteCount == -1 ) SetFailState("Failed to load \"Patch_Count\" count.");

	g_Address = GameConfGetAddress(hGameData, "CTerrorPlayer::Event_Killed");
	if( !g_Address ) SetFailState("Failed to load \"CTerrorPlayer::Event_Killed\" address.");

	g_Address += view_as<Address>(iOffset);
	g_ByteSaved = new ArrayList();

	for( int i = 0; i < iByteCount; i++ )
	{
		g_ByteSaved.Push(LoadFromAddress(g_Address + view_as<Address>(i), NumberType_Int8));
	}

	if( g_ByteSaved.Get(0) != iByteMatch ) SetFailState("Failed to load, byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, g_ByteSaved.Get(0), iByteMatch);



	// ====================================================================================================
	// SDKCALLS
	// ====================================================================================================
	StartPrepSDKCall(SDKCall_Static);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CHolidayGift::Create") == false )
		SetFailState("Could not load the \"CHolidayGift::Create\" gamedata signature.");

	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkCreateGift = EndPrepSDKCall();
	if( sdkCreateGift == null )
		SetFailState("Could not prep the \"CHolidayGift::Create\" function.");
	delete hGameData;
	
}
RPGGift(int client)
{
	int index = GetRandomInt(1, 10);
	if(index == 10)
	{
		float vPos[3];
		GetClientAbsOrigin(client, vPos);
		SDKCall(sdkCreateGift, vPos, view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), 0);
	}
}
public void EventGift(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	GiveAward(client);
}

void GiveAward(int client)
{
	int random = GetRandomInt(1, 2);
	if( random )
	{
		switch( random )
		{
			case 1:		ADDCASH(client);
			case 2:		ADDEXP(client);
		}
	}
}
void ADDCASH(int client)
{
	int a = GetRandomInt(1, 10);
	player_data[client][MONEY] += a;
	PrintToChatAll("\x04%N\x03打开了礼包获得%d点B数", client,a);
}

void ADDEXP(int client)
{
	int b = GetRandomInt(1, 1000);
    player_data[client][EXPERIENCE] += b;
	PrintToChatAll("\x04%N\x03打开了礼包获得%d点经验", client,b);
}

