#pragma newdecls required
/**/
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.1"
#define MAX_LINE_WIDTH 64
ConVar g_hCVarMinAllowedSlots;
ConVar g_hCVarMaxAllowedSlots;
ConVar g_hCVarCurrentMaxSlots;
ConVar MaxPlayer;
int g_iCVarMinAllowedSlots,g_iCVarMaxAllowedSlots,CurrentMaxSlots,iMaxPlayer;
/**
 * 此插件不再处理大厅解锁
 * 大厅解锁交还给l4d2_unreservelobby处理
 */
public Plugin myinfo =
{
	name = "服务器位置插件",
	author = "东",
	description = "设置服务器位置",
	version = PLUGIN_VERSION,
	url = "https://github.com/fantasylidong/L4d2_plugins"
}
public void  OnPluginStart()
{
//	LoadTranslations("menu_shop.phrases.txt");
	g_hCVarMinAllowedSlots = CreateConVar("sm_slot_vote_min", "1", "可投票的最小位置 (这个值必须比 sm_slot_vote_max小).", 0, true, 1.0, true, 32.0);
	g_hCVarMaxAllowedSlots = CreateConVar("sm_slot_vote_max", "12", "可投票的最大位置 (这个值必须比sm_slot_vote_min大).", 0, true, 1.0, true, 32.0);
	g_hCVarCurrentMaxSlots = CreateConVar("sm_slot_start", "8", "启动服务器时的默认位置数量", 0, true, 1.0, true, 32.0);
	MaxPlayer=FindConVar("sv_maxplayers");
	MaxPlayer.AddChangeHook(ConVarChanged_Cvars);
	g_hCVarMinAllowedSlots.AddChangeHook(ConVarChanged_Cvars);
	g_hCVarMaxAllowedSlots.AddChangeHook(ConVarChanged_Cvars);
	RegConsoleCmd("sm_slots", SetSlots, "设置服务器位置");
	GetCvars();
	//AutoExecConfig(true, "slots");
}
// *********************
//		获取Cvar值
// *********************
void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}
void GetCvars()
{
	CurrentMaxSlots=g_hCVarCurrentMaxSlots.IntValue;
	iMaxPlayer=MaxPlayer.IntValue;
	g_iCVarMinAllowedSlots = g_hCVarMinAllowedSlots.IntValue;
	g_iCVarMaxAllowedSlots = g_hCVarMaxAllowedSlots.IntValue;
	compare();
}
void compare(){
	if(CurrentMaxSlots!=iMaxPlayer){
		ServerCommand("sv_maxplayers %d",CurrentMaxSlots);
		ServerCommand("sv_visiblemaxplayers %d",CurrentMaxSlots);
	}
}
//设置服务器位置动作
public Action SetSlots(int client,int args)
{
	if(args!=1){
		ReplyToCommand(client,"\x03错误参数，位置只能设置为%d-%d，使用方式为!slots 7(你想要的位置数)",g_iCVarMinAllowedSlots,g_iCVarMaxAllowedSlots);
		return Plugin_Handled;
	}
	if(client==0||(IsVaildClient(client) && IsPlayerAlive(client))){
		char arg[32];
		GetCmdArg(1, arg, sizeof(arg));
		int slots = StringToInt(arg);
		if(slots < g_iCVarMinAllowedSlots || slots > g_iCVarMaxAllowedSlots){
			ReplyToCommand(client,"\x03错误参数，位置只能设置为%d-%d，使用方式为!slots 7(你想要的位置数)",g_iCVarMinAllowedSlots,g_iCVarMaxAllowedSlots);
			return Plugin_Handled;
		}
		CurrentMaxSlots=slots;
		SetConVarInt(g_hCVarCurrentMaxSlots,slots);
		ServerCommand("sv_maxplayers %d",slots);
		ServerCommand("sv_visiblemaxplayers %d",slots);
	}
	else{
		PrintToChatAll("\x03不是生还者无法设置位置");
	}
	return Plugin_Handled;
}

//检查client合法
int IsVaildClient(int client)
{
	if( client > 0 ) return 1;
	if( client < 64 ) return 1;
	if( IsClientInGame(client) ) return 1;
	if( GetClientTeam(client) == 2 ) return 1;
	else
    {
        return 0;
    }
}