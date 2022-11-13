#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

char sStockCamp[14][] =
{
	"c1m1_hotel",
	"c2m1_highway",
	"c3m1_plankcountry",
	"c4m1_milltown_a",
	"c5m1_waterfront",
	"c6m1_riverbank",
	"c7m1_docks",
	"c8m1_apartment",
	"c9m1_alleys",
	"c10m1_caves",
	"c11m1_greenhouse",
	"c12m1_hilltop",
	"c13m1_alpinecreek",
	"c14m1_junkyard"
};

/*
char sStockCampNames[14][] =
{
	"死亡中心",
	"黑色狂欢节",
	"沼泽激战",
	"暴风骤雨",
	"教区",
	"短暂时刻",
	"牺牲",
	"毫不留情",
	"坠机险途",
	"死亡丧钟",
	"寂静时分",
	"血腥收获",
	"刺骨寒溪",
	"临死一博"
};
*/

char sStockCampNames[14][] =
{
	"Dead Center",
	"Dark Carnival",
	"Swamp Fever",
	"Hard Rain",
	"The Parish",
	"The Passing",
	"The Sacrifice",
	"No Mercy",
	"Crash Course",
	"Death Toll",
	"Dead Air",
	"Blood Harvest",
	"Cold Stream",
	"The Last Stand"
};

char sCustomCamp[3][] =
{
	"l4d2_stadium1_apartment",
	"l4d_reverse_hos01_rooftop",
	"l4d_farm05_cornfield_rev"
};

char sCustomCampNames[3][] =
{
	"Suicide Blitz 2",
	"Reverse No Mercy",
	"Reverse Blood Harvest"
};

char sCurrentMap[64], sNextCamp[64], sNextMap[64], sLastVotedCamp[64], sLastVotedMap[64],
	sVotedCamp[64], sVotedMap[64], sFirstMap[64], sGameMode[16];

int iFMCVoteDuration;
bool voteInitiated, bFMCEnabled, bFMCOfficial, bFMCCustom, bFMCAnnounce, bFMCIncludeCurrent, bFMCIncludeLast;
ConVar hFMCEnabled, hFMCOfficial, hFMCCustom, hFMCAnnounce, hFMCIncludeCurrent, hFMCIncludeLast,
	hFMCVoteDuration;
bool g_bMapStarted,IsSuccess;
static int counts = 0;
Handle announcetimer = INVALID_HANDLE;
public Plugin myinfo = 
{
	name = "[L4D2]救援关投票系统更改地图",
	author = "灵现江湖",
	description = "救援关投票系统更改地图.",
	version = "2.4",
	url = "qq 791347186"
};

#define TRANSLATION_FILE "fmc+vs-l4d2.phrases"
void LoadPluginTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/"...TRANSLATION_FILE...".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation \""...TRANSLATION_FILE..."\"");
	}
	LoadTranslations(TRANSLATION_FILE);
}


public void OnPluginStart()
{
	LoadPluginTranslations();
	hFMCEnabled = CreateConVar("fmc+vs-l4d2_enable", "1", "启用插件？", FCVAR_NOTIFY);
	hFMCOfficial = CreateConVar("fmc+vs-l4d2_Official", "1", "官网投票广告是否显示(1:显示，0：不显示)", FCVAR_NOTIFY);
	hFMCCustom = CreateConVar("fmc+vs-l4d2_Custom", "1", "三方图投票广告是否显示(1:显示，0：不显示)", FCVAR_NOTIFY);
	hFMCAnnounce = CreateConVar("fmc+vs-l4d2_announce", "1", "启用提示？", FCVAR_NOTIFY);
	hFMCVoteDuration = CreateConVar("fmc+vs-l4d2_vote_duration", "60", "投票间隔", FCVAR_NOTIFY);
	hFMCIncludeCurrent = CreateConVar("fmc+vs-l4d2_include_current", "0", "投票菜单是否包括当前地图", FCVAR_NOTIFY);
	hFMCIncludeLast = CreateConVar("fmc+vs-l4d2_include_last", "0", "投票菜单是否包括上个地图", FCVAR_NOTIFY);
	
	HookConVarChange(hFMCEnabled, OnFMCCVarsChanged);
	HookConVarChange(hFMCOfficial, OnFMCCVarsChanged);
	HookConVarChange(hFMCCustom, OnFMCCVarsChanged);
	HookConVarChange(hFMCAnnounce, OnFMCCVarsChanged);
	HookConVarChange(hFMCIncludeCurrent, OnFMCCVarsChanged);
	HookConVarChange(hFMCIncludeLast, OnFMCCVarsChanged);
	HookConVarChange(hFMCVoteDuration, OnFMCCVarsChanged);
	
	AutoExecConfig(true, "fmc-l4d2");
	
	HookEvent("round_start", OnRoundStart);
	HookEvent("finale_win", OnFinaleWin);
	HookEvent("round_end", OnRoundEnd);
	RegConsoleCmd("sm_fmc_menu", ShowVoteMenu, "Shows Menu Of Available And Vote-able Campaigns");
	RegConsoleCmd("sm_fmc_menu_custom", ShowVoteMenuCustom, "Shows Menu Of Available And Vote-able Custom Campaigns");
	RegConsoleCmd("sm_aa", aa, "Shows Menu Of Available And Vote-able Campaigns");
	
	SetNativeVotesCvars();
}

public Action aa(int client, int args)
{
	if (client == 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	CPrintToChatAll("%s",sGameMode);
	return Plugin_Handled;
}

public void OnMapStart()
{
	g_bMapStarted = true;
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));
	FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));
	if (StrContains(sGameMode, "versus", false) != -1 || StrContains(sGameMode, "mutation19", false) != -1)
	{
		IsSuccess = false;
		HookUserMessage(GetUserMessageId("PZEndGamePanelMsg"), PZEndGamePanelMsg, true);
		HookUserMessage(GetUserMessageId("DisconnectToLobby"), OnDisconnectToLobby, true);
		counts = 1;
	}
	voteInitiated = false;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));
	if (StrContains(sGameMode, "versus", false) != -1 || StrContains(sGameMode, "mutation19", false) != -1)
	{
		if(counts == 1)
		{
			UnhookUserMessage(GetUserMessageId("PZEndGamePanelMsg"), PZEndGamePanelMsg, true);
			UnhookUserMessage(GetUserMessageId("DisconnectToLobby"), OnDisconnectToLobby, true);
			counts = 0;
		}
	}
}

public void OnConfigsExecuted()
{
	SetNativeVotesCvars();
}

public void OnFMCCVarsChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	SetNativeVotesCvars();
}

void SetNativeVotesCvars()
{
	bFMCEnabled = hFMCEnabled.BoolValue;
	bFMCOfficial = hFMCOfficial.BoolValue;
	bFMCCustom = hFMCCustom.BoolValue;
	bFMCAnnounce = hFMCAnnounce.BoolValue;
	bFMCIncludeCurrent = hFMCIncludeCurrent.BoolValue;
	bFMCIncludeLast = hFMCIncludeLast.BoolValue;
	
	iFMCVoteDuration = hFMCVoteDuration.IntValue;
	
	if( g_bMapStarted )
		FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));
}

public Action ShowVoteMenu(int client, int args)
{
	if (client == 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if (!L4D_IsMissionFinalMap())
	{
		CPrintToChat(client, "%t", "OnlyFinalMap");
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		CPrintToChat(client, "%t", "VoteInProcess");
		return Plugin_Handled;
	}
	
	FMCMenu();
	return Plugin_Handled;
}

public Action ShowVoteMenuCustom(int client, int args)
{
	if (client == 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if (!L4D_IsMissionFinalMap())
	{
		CPrintToChat(client, "%t", "OnlyFinalMap");
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		CPrintToChat(client, "%t", "VoteInProcess");
		return Plugin_Handled;
	}
	
	FMCMenu(true);
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if (!bFMCEnabled || !bFMCAnnounce || IsFakeClient(client) || !L4D_IsMissionFinalMap())
	{
		return;
	}
    //PrintToChat(client, "\x04[FMC]\x03 投票官方地图, 请输入 \x05 !fmc_menu");
	//PrintToChat(client, "\x04[FMC]\x03 投票第三方地图, 请输入 \x05!fmc_menu_custom");
	CreateTimer(120.0, InformOfCC, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action InformOfCC(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if (!IsClientInGame(client))
	{
		return Plugin_Stop;
	}
	if(bFMCOfficial)
	{ 
		CPrintToChat(client, "%t", "VoteOfficalMap");
	}
	else if(bFMCCustom)
	{
		CPrintToChat(client, "%t", "VoteCustomMap");
	}
	return Plugin_Continue;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, Delay_RoundStart);
	return Plugin_Continue;
}



public Action Delay_RoundStart(Handle timer)
{
	if (!bFMCEnabled || !L4D_IsMissionFinalMap())
	{
		return Plugin_Continue;
	}
	if(announcetimer == INVALID_HANDLE)
	{
		announcetimer = CreateTimer(30.0 , AnnounceNextCamp);
		//CreateTimer(30.0, AnnounceNextCamp);
		FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));
		/* if ((StrContains(sGameMode, "versus", false) != -1 && !voteInitiated) || ((StrEqual(sGameMode, "coop", false) || StrEqual(sGameMode, "realism", false) || StrContains(sGameMode, "mutation19", false) != -1) && !voteInitiated))
		{
			ClearNextCampaign();
			
			CreateTimer(60.0, VoteCampaignDelay);
		} */
		if (!voteInitiated) 
		{
			ClearNextCampaign();
			CreateTimer(60.0, VoteCampaignDelay);
		}
	}	
	return Plugin_Continue;
}

public Action AnnounceNextCamp(Handle timer)
{
	CPrintToChatAll("%t", "LastMap");
	if (!StrEqual(sVotedMap, "", false))
	{
		CPrintToChatAll("%t %s |%t|","NextMap", sVotedMap, sVotedCamp);
	}
	else
	{
		FMC_GetNextCampaign(sCurrentMap);
		CPrintToChatAll("%t %s |%t|","NextMap", sNextMap, sNextCamp);
	}
	CloseHandle(announcetimer);
	announcetimer = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action VoteCampaignDelay(Handle timer)
{
	if (voteInitiated)
	{
		return Plugin_Stop;
	}
	
	CreateTimer(5.0, ReadyVoteMenu);
	CPrintToChatAll("%t", "StartIn5Sec");
	
	return Plugin_Stop;
}

// *************************
// 			生还者
// *************************
// 判断是否有效玩家 id，有效返回 true，无效返回 false
stock bool IsValidClient(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		return true;
	}
	else
	{
		return false;
	}
}

stock bool IsPlayer(int client)
{
	int team = GetClientTeam(client);
	return (team == 2 || team == 3);
}


public Action ReadyVoteMenu(Handle timer)
{
	CPrintToChatAll("%t", "StartVote");
	FMCMenu();

	
	
	return Plugin_Stop;
}
/*
void AddTranslatedMenuItem(Menu menu, const char[] opt, const char[] phrase, int client)
{
	char buffer[128];
	Format(buffer, sizeof(buffer), "%T", phrase, client);
	menu.AddItem(opt, buffer);
}
*/

void FMCMenu(bool bCustom = false)
{
	Menu voteMenu = new Menu(voteMenuHandler, MenuAction_DisplayItem|MenuAction_Display);
	//char temp[MAX_NAME_LENGTH];
	//Format(temp, sizeof(temp), "%t", "VoteNextMap"); 
	//SetMenuTitle(voteMenu, temp);
	//voteMenu.SetTitle("%t", temp);
	//voteMenu.SetTitle(temp);
	voteMenu.SetTitle("Vote Next Map To");
	/*
	if (StrEqual(sVotedMap, "", false))
	{
		voteMenu.AddItem(sNextMap, sNextCamp);
	}
	else
	{
		voteMenu.AddItem(sVotedMap, sVotedCamp);
	}
	*/
	
	if (!bCustom)
	{
		for (int i = 0; i < 14; i++)
		{
			if (StrEqual(sNextMap, sStockCamp[i], false) || (!bFMCIncludeCurrent && StrEqual(sFirstMap, sStockCamp[i], false)) || (!bFMCIncludeLast && StrEqual(sLastVotedMap, sStockCamp[i], false)))
			{
				continue;
			}
			
			voteMenu.AddItem(sStockCamp[i], sStockCampNames[i]);
		}
	}
	else
	{
		for (int i = 0; i < 3; i++)
		{
			if (!IsMapValid(sCustomCamp[i]) || (!bFMCIncludeCurrent && StrEqual(sFirstMap, sCustomCamp[i], false)) || (!bFMCIncludeLast && StrEqual(sLastVotedMap, sCustomCamp[i], false)))
			{
				continue;
			}
			
			voteMenu.AddItem(sCustomCamp[i], sCustomCampNames[i]);
		}
	}
	voteMenu.ExitButton = false;
	voteMenu.VoteResultCallback = voteMenuResult;
	voteMenu.DisplayVoteToAll(iFMCVoteDuration);
}

public int voteMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_DisplayItem:
		{
			/* Get the display string, we'll use it as a translation phrase */
	        char display[64];
	        menu.GetItem(param2, "", 0, _, display, sizeof(display));
	 
	        /* Translate the string to the client's language */
	        char buffer[255];
	        Format(buffer, sizeof(buffer), "%T", display, param1);
	 
	        /* Override the text */
	        return RedrawMenuItem(buffer);
		}
		case MenuAction_Display:
	    {
	        Panel panel = view_as<Panel>(param2);
	 
	        char buffer[255];
	        Format(buffer, sizeof(buffer), "%T", "VoteNextMap", param1);
	 
	        panel.SetTitle(buffer);
	    }
	}
}

public void voteMenuResult(
	Menu menu,
	int num_votes,
	int num_clients,
	const int[][] client_info,
	int num_items,
	const int[][] item_info
)
{
	int majorityItem = 0;
	if (num_items >= 2)
	{
		int i = 1;
		while (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[i][VOTEINFO_ITEM_VOTES])
		{
			i += 1;
		}
		
		if (i >= 2)
		{
			majorityItem = GetRandomInt(0, i - 1);
		}
	}
	
	menu.GetItem(item_info[majorityItem][VOTEINFO_ITEM_INDEX], sVotedMap, sizeof(sVotedMap), _, sVotedCamp, sizeof(sVotedCamp));
	CPrintToChatAll("%t", "VoteResult", sVotedCamp, sVotedMap, item_info[majorityItem][VOTEINFO_ITEM_VOTES]);
	voteInitiated = true;
	strcopy(sLastVotedCamp, sizeof(sLastVotedCamp), sVotedCamp);
	strcopy(sLastVotedMap, sizeof(sLastVotedMap), sVotedMap);
	
	if (bFMCAnnounce)
	{
		CreateTimer(5.0, AnnounceNextCamp);
	}
}

public Action OnFinaleWin(Event event, const char[] name, bool dontBroadcast)
{
	if (!bFMCEnabled || !L4D_IsMissionFinalMap())
	{
		return Plugin_Continue;
	}
	
	CreateTimer(3.0, ForceNextCampaign);
	return Plugin_Continue;
}

public Action ForceNextCampaign(Handle timer)
{
	if (StrEqual(sVotedMap, "", false))
	{
		FMC_GetNextCampaign(sCurrentMap);
		ServerCommand("changelevel %s", sNextMap);
	}
	else
	{
		ServerCommand("changelevel %s", sVotedMap);
	}
	return Plugin_Stop;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	return Plugin_Continue;
}


public Action PZEndGamePanelMsg(UserMsg msg_id, BfRead hMsg, const players[], int playersNum, bool reliable, bool init)
{
	if (!bFMCEnabled || !L4D_IsMissionFinalMap())
	{
		return Plugin_Continue;
	}
	
	if(!IsSuccess)
	{
		IsSuccess = true;
		CreateTimer(10.0, ForceNextCampaign);
	}
	return Plugin_Handled;
}

public Action OnDisconnectToLobby(UserMsg msg_id, Handle bf, const players[], int playersNum, bool reliable, bool init)
{
	if (IsSuccess)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


void ClearNextCampaign()
{
	sNextCamp[0] = '\0';
	sNextMap[0] = '\0';
	
	sVotedCamp[0] = '\0';
	sVotedMap[0] = '\0';
}

void FMC_GetNextCampaign(const char[] sMap)
{
	if (StrEqual(sMap, "c1m4_atrium", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[1]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[1]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[0]);
	}
	else if (StrEqual(sMap, "c6m3_port", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[6]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[6]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[5]);
	}
	else if (StrEqual(sMap, "c2m5_concert", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[2]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[2]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[1]);
	}
	else if (StrEqual(sMap, "c3m4_plantation", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[3]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[3]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[2]);
	}
	else if (StrEqual(sMap, "c4m5_milltown_escape", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[4]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[4]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[3]);
	}
	else if (StrEqual(sMap, "c5m5_bridge", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[5]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[5]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[4]);
	}
	else if (StrEqual(sMap, "c13m4_cutthroatcreek", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[0]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[0]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[13]);
	}
	else if (StrEqual(sMap, "c14m1_junkyard", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[13]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[13]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[12]);
	}
	else if (StrEqual(sMap, "c8m5_rooftop", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[8]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[8]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[7]);
	}
	else if (StrEqual(sMap, "c9m2_lots", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[9]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[9]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[8]);
	}
	else if (StrEqual(sMap, "c10m5_houseboat", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[10]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[10]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[9]);
	}
	else if (StrEqual(sMap, "c11m5_runway", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[11]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[11]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[10]);
	}
	else if (StrEqual(sMap, "c12m5_cornfield", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[12]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[12]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[11]);
	}
	else if (StrEqual(sMap, "c7m3_port", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[7]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[7]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sStockCamp[6]);
	}
	else if (StrEqual(sMap, "l4d2_stadium5_stadium", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[0]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[0]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sCustomCamp[1]);
	}
	else if (StrEqual(sMap, "l4d_reverse_hos05_apartment", false))
	{
		strcopy(sNextCamp, sizeof(sNextCamp), sStockCampNames[0]);
		strcopy(sNextMap, sizeof(sNextMap), sStockCamp[0]);
		
		strcopy(sFirstMap, sizeof(sFirstMap), sCustomCamp[2]);
	}
}