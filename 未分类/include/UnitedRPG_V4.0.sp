
#include <sourcemod>
#include <sdktools>
#include <colors>
#include <adminmenu>
#include <sdkhooks>
//RPGINC
#include "UnitedRPG/rpg_msgs.inc"
#include "UnitedRPG/rpg_constant.inc"
#include "UnitedRPG/common/common.inc"
#include "UnitedRPG/common/prop.inc"
#include "UnitedRPG/rpg_savesx.inc"
#include "UnitedRPG/rpg_other.inc"
#include "UnitedRPG/rpg_supertank.inc"
#include "UnitedRPG/rpg_bag.inc"
#include "UnitedRPG/rpg_item.inc"
#include "UnitedRPG/rpg_melee.inc"
#include "UnitedRPG/rpg_qhxt.inc"
#include "UnitedRPG/rpg_rych.inc"
#include "UnitedRPG/rpg_master.inc"
#include "UnitedRPG/rpg_jlxt"
#include "UnitedRPG/rpg_bot.inc"
#include "UnitedRPG/rpg_tf.inc"
#include "UnitedRPG/rpg_zbxt.inc"
#include "UnitedRPG/rpg_rwxtkl.inc"

//by MicroLeo
#include "UnitedRPG/ArchiveSystems/SQLiteArchiveSystems.inc"
//end

#include "UnitedRPG/rpg_vip.inc"
#include "UnitedRPG/common/cdkey.inc"
#include "UnitedRPG/rpg_admin.inc"

#define PLUGIN_VERSION "4.0.1"


public OnPluginStart()
{
	decl String:Game_Name[64];
	GetGameFolderName(Game_Name, sizeof(Game_Name));
	if(!StrEqual(Game_Name, "left4dead2", false))
		SetFailState("United RPG%d插件仅支持L4D2!", PLUGIN_VERSION);

	//by MicroLeo
	//尝试初始化SQLite存档系统
	SQLiteArchiveSys_OnPluginStart();
	
	SQLiteCDKey_OnPluginStart();
	
	//初始化数据包
	AutoLoginPack = CreateArray(1024);//16=64字节，maxplayers = 64,  16*64 = 1024;
	//end
		
	/* 加密检查 */
	/*
	BuildPath(Path_SM, PW_Path, 255, "gamedata/core.games/l4d2_7sh.txt");
	if (FileExists(PW_Path))
	{
		PW_File = OpenFile(PW_Path, "rb");
		if (PW_File != INVALID_HANDLE)
		{
			ReadFileLine(PW_File, PW_Data, sizeof(PW_Data));
			if (!StrEqual(PW_Data, "CshHuaZi695362077"))
				SetFailState("插件检查到你非法使用该插件,将强制卸载!");
		}
		else
			SetFailState("插件检查到你非法使用该插件,将强制卸载!");
	}
	else
		SetFailState("插件检查到你非法使用该插件,将强制卸载!");
	*/

	CreateConVar("United_RPG_Version", PLUGIN_VERSION, "United RPG 插件版本", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_DONTRECORD);

	LoadTranslations("common.phrases");

	RegisterCvars();
	RegisterCmds();
	HookEvents();
	GetConVar();

	gConf = LoadGameConfigFile("UnitedRPG");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	fSHS = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	fTOB = EndPrepSDKCall();

	/* 生成CFG */
	AutoExecConfig(true, "United_RPG");

	HookConVarChange(RobotReactiontime, ConVarChange);
	HookConVarChange(RobotEnergy, ConVarChange);
	//难度平衡Convar
	HookConVarChange(sm_supertank_health_max, ConVarChange);
	HookConVarChange(sm_supertank_health_second, ConVarChange);
	HookConVarChange(sm_supertank_health_third, ConVarChange);
	HookConVarChange(sm_supertank_health_forth, ConVarChange);
	HookConVarChange(sm_supertank_health_boss, ConVarChange);
	HookConVarChange(sm_supertank_health_Killer, ConVarChange);
	HookConVarChange(sm_supertank_warp_interval, ConVarChange);

	robot_gamestart = false;
	robot_gamestart_clone = false;
	new String:date[21];
	/* Format date for log filename */
	FormatTime(date, sizeof(date), "%d%m%y", -1);
	/* Create name of logfile to use */
	BuildPath(Path_SM, LogPath, sizeof(LogPath), "logs/unitedrpg%s.log", date);

	/* 上弹系统 */
	S_rActiveW		=	FindSendPropInfo("CBaseCombatCharacter","m_hActiveWeapon");
	S_rStartDur  	=	FindSendPropInfo("CBaseShotgun","m_reloadStartDuration");
	S_rInsertDur	 =	FindSendPropInfo("CBaseShotgun","m_reloadInsertDuration");
	S_rEndDur		  =	FindSendPropInfo("CBaseShotgun","m_reloadEndDuration");
	S_rPlayRate		=	FindSendPropInfo("CBaseCombatWeapon","m_flPlaybackRate");
	s_rTimeIdle		=	FindSendPropInfo("CTerrorGun","m_flTimeWeaponIdle");
	S_rNextPAtt		=	FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
	s_rNextAtt		=	FindSendPropInfo("CTerrorPlayer","m_flNextAttack");

	//获取服务器最大人数
	cv_MaxPlayer = FindConVar("sv_maxplayers");


	//服务器运行时间
	if (HD_ServerRuningTime == INVALID_HANDLE)
		HD_ServerRuningTime = CreateTimer(1.0, Timer_ServerRuningTime, _, TIMER_REPEAT);
}

RegisterCvars()
{
	/* 幸存者经验值 */
	JockeyKilledExp					= CreateConVar("rpg_GainExp_Kill_Jockey",				"200",	"击杀Jockey获得的经验值", CVAR_FLAGS, true, 0.0);
	HunterKilledExp					= CreateConVar("rpg_GainExp_Kill_hunter",				"200",	"击杀Hunter获得的经验值", CVAR_FLAGS, true, 0.0);
	ChargerKilledExp				= CreateConVar("rpg_GainExp_Kill_Charger",				"200",	"击杀Charger获得的经验值", CVAR_FLAGS, true, 0.0);
	SmokerKilledExp					= CreateConVar("rpg_GainExp_Kill_Smoker",				"200",	"击杀Smoker获得的经验值", CVAR_FLAGS, true, 0.0);
	SpitterKilledExp				= CreateConVar("rpg_GainExp_Kill_Spitter",				"200",	"击杀Spitter获得的经验值", CVAR_FLAGS, true, 0.0);
	BoomerKilledExp					= CreateConVar("rpg_GainExp_Kill_Boomer",				"200",	"击杀Boomer获得的经验值", CVAR_FLAGS, true, 0.0);
	TankKilledExp					= CreateConVar("rpg_GainExp_Kill_Tank",					"0.01",	"击杀Tank每一伤害获得的经验值", CVAR_FLAGS, true, 0.0);
	WitchKilledExp					= CreateConVar("rpg_GainExp_Kill_Witch",				"150",	"击杀Witch惩罚的经验值", CVAR_FLAGS, true, 0.0);
	ZombieKilledExp					= CreateConVar("rpg_GainExp_Kill_Zombie",				"15",	"击杀普通丧尸获得的经验值", CVAR_FLAGS, true, 0.0);
	ReviveTeammateExp				= CreateConVar("rpg_GainExp_Revive_Teammate",			"100",	"拉起队友获得的经验值", CVAR_FLAGS, true, 0.0);
	ReanimateTeammateExp			= CreateConVar("rpg_GainExp_Reanimate_Teammate",		"500",	"电击器复活队友获得的经验值", CVAR_FLAGS, true, 0.0);
	HealTeammateExp					= CreateConVar("rpg_GainExp_Survivor_Heal_Teammate",	"400",	"帮队友治疗获得的经验值", CVAR_FLAGS, true, 0.0);
	TeammateKilledExp				= CreateConVar("rpg_GainExp_Kill_Teammate",				"1000",	"幸存者误杀队友扣除的经验值", CVAR_FLAGS, true, 0.0);

	/* 幸存者金钱 */
	JockeyKilledCash				= CreateConVar("rpg_GainCash_Kill_Jockey",				"20",	"击杀Jockey获得的金钱", CVAR_FLAGS, true, 0.0);
	HunterKilledCash				= CreateConVar("rpg_GainCash_Kill_hunter",				"25",	"击杀Hunter获得的金钱", CVAR_FLAGS, true, 0.0);
	ChargerKilledCash				= CreateConVar("rpg_GainCash_Kill_Charger",				"25",	"击杀Charger获得的金钱", CVAR_FLAGS, true, 0.0);
	SmokerKilledCash				= CreateConVar("rpg_GainCash_Kill_Smoker",				"20",	"击杀Smoker获得的金钱", CVAR_FLAGS, true, 0.0);
	SpitterKilledCash				= CreateConVar("rpg_GainCash_Kill_Spitter",				"20",	"击杀Spitter获得的金钱", CVAR_FLAGS, true, 0.0);
	BoomerKilledCash				= CreateConVar("rpg_GainCash_Kill_Boomer",				"15",	"击杀Boomer获得的金钱", CVAR_FLAGS, true, 0.0);
	TankKilledCash					= CreateConVar("rpg_GainCash_Kill_Tank",				"0.008",	"击杀Tank每一伤害获得的金钱", CVAR_FLAGS, true, 0.0);
	WitchKilledCash					= CreateConVar("rpg_GainCash_Kill_Witch",				"50",	"击杀Witch惩罚的金钱", CVAR_FLAGS, true, 0.0);
	ZombieKilledCash				= CreateConVar("rpg_GainCash_Kill_Zombie",				"1",	"击杀普通丧尸获得的金钱", CVAR_FLAGS, true, 0.0);
	ReviveTeammateCash				= CreateConVar("rpg_GainCash_Revive_Teammate",			"5",	"拉起队友获得的金钱", CVAR_FLAGS, true, 0.0);
	ReanimateTeammateCash			= CreateConVar("rpg_GainCash_Reanimate_Teammate",		"35",	"电击器复活队友获得的金钱", CVAR_FLAGS, true, 0.0);
	HealTeammateCash				= CreateConVar("rpg_GainCash_Survivor_Heal_Teammate",	"25",	"帮队友治疗获得的金钱", CVAR_FLAGS, true, 0.0);
	TeammateKilledCash				= CreateConVar("rpg_GainCash_Kill_Teammate",			"500",	"幸存者误杀队友扣除的金钱", CVAR_FLAGS, true, 0.0);

	/* 关于升级 */
	LvUpSP						= CreateConVar("rpg_LvUp_SP",		"5",	"升级获得的属性点", CVAR_FLAGS, true, 0.0);
	LvUpKSP					= CreateConVar("rpg_LvUp_KSP",		"1",	"升级获得的技能点", CVAR_FLAGS, true, 0.0);
	LvUpCash					= CreateConVar("rpg_LvUp_Cash",		"1000",	"升级获得的金钱", CVAR_FLAGS, true, 0.0);
	LvUpExpRate				= CreateConVar("rpg_LvUp_Exp_Rate",	"800",	"升级Exp系数: 升级经验=升级系Exp数*(当前等级+1)", CVAR_FLAGS, true, 1.0);
	NewLifeLv					= CreateConVar("rpg_NewLife_Lv",	"120",	"转生所需等级", CVAR_FLAGS, true, 1.0);
	/*  蘑菇云核弹 */
	CvarDurationTime			= CreateConVar("L4D2_nuclear_Duration_Time",  "10",   " 核弹引爆时间 ", FCVAR_PLUGIN);
	CvarDurationTime2			= CreateConVar("L4D2_nuclear_Duration_Time2", "60",   " 核污染持续时间 ", FCVAR_PLUGIN);
	Cvar_nuclearEnable		= CreateConVar("L4D2_nuclear_enabled",        "1",    " 开启关闭核弹插件 ", FCVAR_PLUGIN);
	Cvar_nuclearAmount		= CreateConVar("L4D2_nuclear_amount",         "2",  " 出生时给玩家多少个核弹 ", FCVAR_PLUGIN);
	Cvar_nuclearTime			= CreateConVar("L4D2_nuclear_time",           "60.0", " 核污染蘑菇云持续时间 ", FCVAR_PLUGIN);
	CvarDamageRadius			= CreateConVar("L4D2_nuclear_DamageRadius",   "1000", " 核弹爆炸范围 ", FCVAR_PLUGIN);
	CvarCloudRadius			= CreateConVar("L4D2_nuclear_DamageRadius",   "1000", " 蘑菇云辐射范围 ", FCVAR_PLUGIN);
	CvarDamageforce			= CreateConVar("L4D2_nuclear_Damageforce",    "80000", " 核弹爆发威力 ", FCVAR_PLUGIN);
	CvarCloudDamage     		= CreateConVar("L4D2_nuclear_CouldDamage",    "50",    " 蘑菇云辐射伤害 ", FCVAR_PLUGIN);

	/*  关于属性技能点 */
	Cost_Healing				= CreateConVar("rpg_MPCost_Healing",		    	"3000",	       	"使用治疗术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_EarthQuake	    		= CreateConVar("rpg_Cost_EarthQuake",               "5000",         "使用地震术所MP", CVAR_FLAGS, true, 0.0);
	Cost_AmmoMaking	    		= CreateConVar("rpg_MPCost_MakingAmmo",		     	"3000",		    "使用制造子弹术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_Zdgc           		= CreateConVar("rpg_MPCost_Zdgc",		         	"3100",		    "使用子弹工程所需MP", CVAR_FLAGS, true, 0.0);
	Cost_Cqdz            		= CreateConVar("rpg_MPCost_Cqdz",                   "8000",         "使用超强地震所MP", CVAR_FLAGS, true, 0.0);
	Cost_YLTJ               	= CreateConVar("rpg_MPCost_YLTJ",               	"20000",    	"使用致命闪电所需MP", CVAR_FLAGS, true, 0.0);
	Cost_DSZG	                = CreateConVar("rpg_MPCost_DSZG",                	"8000",      	"使用毒龙之光所需MP", CVAR_FLAGS, true, 0.0);
	Cost_WZZG               	= CreateConVar("rpg_MPCost_WZZG",               	"10000",    	"使用武者之光所需MP", CVAR_FLAGS, true, 0.0);
	Cost_GZS	    			= CreateConVar("rpg_MPCost_GZS",		     		"5000",		    "使用光之速所需MP", CVAR_FLAGS, true, 0.0);
	Cost_WXNY		        	= CreateConVar("rpg_MPCost_WXNY",	            	"10000",		"使用无限能源所需MP", CVAR_FLAGS, true, 0.0);
	Cost_SatelliteCannon		= CreateConVar("rpg_MPCost_SatelliteCannon",    	"8000",      	"使用暗夜直射所需MP", CVAR_FLAGS, true, 0.0);
	Cost_SatelliteCannonmiss	= CreateConVar("rpg_MPCost_SatelliteCannonmiss",	"10000",     	"使用暗夜暴雷所需MP", CVAR_FLAGS, true, 0.0);
	Cost_BioShield		    	= CreateConVar("rpg_MPCost_BionicShield",	     	"3000",	        "使用无敌术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_SWHT	            	= CreateConVar("rpg_MPCost_SWHT",	             	"3000",	        "使用死亡护体所需MP", CVAR_FLAGS, true, 0.0);
	Cost_BioShieldmiss	    	= CreateConVar("rpg_MPCost_BionicShieldmiss",		"5000",	        "使用暗影嗜血术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_DamageReflect	    	= CreateConVar("rpg_MPCost_DamageReflect",	      	"5000",     	"使用反伤术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_MeleeSpeed		    	= CreateConVar("rpg_MPCost_MeleeSpeed",		      	"3000",	        "使用近战嗜血术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_TeleportToSelect    	= CreateConVar("rpg_MPCost_TeleportToSelect",    	"3000",	     	"使用冰之传送术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_HolyBolt        		= CreateConVar("rpg_MPCost_HolyBolt",           	"5000",	    	"使用嗜血光球术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_SXZG	            	= CreateConVar("rpg_MPCost_SXZG",               	"6000",	     	"使用嗜血之光所需MP", CVAR_FLAGS, true, 0.0);
	Cost_TeleportTeammate	    = CreateConVar("rpg_MPCost_TeleportTeammate",    	"5000",	        "使用心灵传送术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_HealingBall			= CreateConVar("rpg_MPCost_HealingBall",	     	"10000",	    "使用圣域之风所需MP", CVAR_FLAGS, true, 0.0);
	Cost_FireBall				= CreateConVar("rpg_MPCost_FireBall",		    	"3000",		    "使用地狱火所需MP", CVAR_FLAGS, true, 0.0);
	Cost_IceBall				= CreateConVar("rpg_MPCost_IceBall",		     	"3000",		    "使用寒冰爆弹所需MP", CVAR_FLAGS, true, 0.0);
	Cost_ChainLightning		    = CreateConVar("rpg_MPCost_ChainLightning",	    	"3000",	        "使用暗夜噬魂术所需MP", CVAR_FLAGS, true, 0.0);
	Cost_AreaBlastingex	        = CreateConVar("rpg_MPCost_AreaBlastingex",	    	"10000",	    "使用审判领域所需MP", CVAR_FLAGS, true, 0.0);
	Cost_Dyzh                   = CreateConVar("rpg_MPCost_Dyzh",	            	"10000",	    "使用大地之怒所需MP", CVAR_FLAGS, true, 0.0);
	Cost_LDZ		            = CreateConVar("rpg_MPCost_LDZ",	            	"10000",	    "使用雷电子所需MP", CVAR_FLAGS, true, 0.0);
	Cost_FBZN	                = CreateConVar("rpg_MPCost_FBZN",	            	"10000",	    "使用风暴之怒所需MP", CVAR_FLAGS, true, 0.0);
	Cost_XBFB                   = CreateConVar("rpg_MPCost_XBFB",	            	"10000",	    "使用玄冰风暴所需MP", CVAR_FLAGS, true, 0.0);
	Cost_HMZS	                = CreateConVar("rpg_MPCost_HMZS",	            	"7000",	        "使用毁灭之书所需MP", CVAR_FLAGS, true, 0.0);
	Cost_SPZS	                = CreateConVar("rpg_MPCost_SPZS",	            	"7000",	        "使用审判之书所需MP", CVAR_FLAGS, true, 0.0);
	Cost_PHFR	                = CreateConVar("rpg_MPCost_FBZN",	             	"10000",	    "使用幻影之炎所需MP", CVAR_FLAGS, true, 0.0);
	Cost_PHZG	                = CreateConVar("rpg_MPCost_FBZN",	            	"10000",	    "使用幻影之血所需MP", CVAR_FLAGS, true, 0.0);
	Cost_PHSC	                = CreateConVar("rpg_MPCost_FBZN",	            	"10000",	    "使用幻影炮所需MP", CVAR_FLAGS, true, 0.0);
	Cost_PHFRA	                = CreateConVar("rpg_MPCost_PHFR",	            	"10000",	    "使用死亡契约所需MP", CVAR_FLAGS, true, 0.0);
	Cost_PHZGA	                = CreateConVar("rpg_MPCost_PHZG",	            	"10000",	    "使用爆破光球所需MP", CVAR_FLAGS, true, 0.0);
	Cost_PHSD	                = CreateConVar("rpg_MPCost_PHSD",	             	"10000",	    "使用闪电光球所需MP", CVAR_FLAGS, true, 0.0);
	Cost_PHABA	                = CreateConVar("rpg_MPCost_PHABA",	            	"5000",	        "使用复仇欲望所需MP", CVAR_FLAGS, true, 0.0);
	Cost_XJ	    	            = CreateConVar("rpg_MPCost_XJ",		            	"100000",	    "使用献祭所需MP", CVAR_FLAGS, true, 0.0);
	Cost_LLLZ	                = CreateConVar("rpg_MPCost_LLLZ",		          	"10000",	    "使用祭祀之光MP", CVAR_FLAGS, true, 0.0);
	Cost_LLLE	                = CreateConVar("rpg_MPCost_LLLE",		         	"10000",	    "使用魔法冲击MP", CVAR_FLAGS, true, 0.0);
	Cost_LLLS	            	= CreateConVar("rpg_MPCost_LLLS",		          	"10000",	    "使用毁灭压制MP", CVAR_FLAGS, true, 0.0);
	Cost_BBBS	            	= CreateConVar("rpg_MPCost_BBBS",		          	"10000",	    "使用毒龙爆破MP", CVAR_FLAGS, true, 0.0);
	Cost_HYJW	             	= CreateConVar("rpg_MPCost_HYJW",		         	"10000",	    "使用幻影剑舞MP", CVAR_FLAGS, true, 0.0);
	Cost_NQBF	              	= CreateConVar("rpg_MPCost_NQBF",		         	"10000",	    "使用怒气爆发MP", CVAR_FLAGS, true, 0.0);
	Cost_XZKB	             	= CreateConVar("rpg_MPCost_XZKB",		           	"10000",	    "使用血之狂暴MP", CVAR_FLAGS, true, 0.0);
	Cost_JBSY	            	= CreateConVar("rpg_MPCost_JBSY",		        	"10000",	    "使用极冰盛宴MP", CVAR_FLAGS, true, 0.0);

	CfgNormalItemShopEnable	= CreateConVar("rpg_Shop_normal_items_enable",		"1",	"是否允许投掷品，药物和子弹盒购物选单 1=是 0=否", CVAR_FLAGS, true, 0.0, true, 1.0);
	CfgSelectedGunShopEnable	= CreateConVar("rpg_Shop_selected_gun__enable",		"1",	"是否允许许特选枪械购物商店 1=是 0=否", CVAR_FLAGS, true, 0.0, true, 1.0);
	CfgMeleeShopEnable		= CreateConVar("rpg_Shop_selected_melee_enable",	"1",	"是否允许近战武器购物商店 1=是 0=否", CVAR_FLAGS, true, 0.0, true, 1.0);

	/* Normal Items Cost*/
	CfgNormalItemCost[0]		= CreateConVar("rpg_ShopCost_Normal_Items_00","200","补充子弹的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[1]		= CreateConVar("rpg_ShopCost_Normal_Items_01","300","红外线的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[2]		= CreateConVar("rpg_ShopCost_Normal_Items_02","500","高爆弹的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[3]		= CreateConVar("rpg_ShopCost_Normal_Items_03","500","燃烧弹的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[4]		= CreateConVar("rpg_ShopCost_Normal_Items_04","500","药包的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[5]		= CreateConVar("rpg_ShopCost_Normal_Items_05","300","药丸的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[6]		= CreateConVar("rpg_ShopCost_Normal_Items_06","300","肾上腺素针的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[7]		= CreateConVar("rpg_ShopCost_Normal_Items_07","600","电击器的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[8]		= CreateConVar("rpg_ShopCost_Normal_Items_08","750","燃烧瓶的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[9]		= CreateConVar("rpg_ShopCost_Normal_Items_09","650","土制炸弹的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[10]	    = CreateConVar("rpg_ShopCost_Normal_Items_10","700","胆汁的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[11]	    = CreateConVar("rpg_ShopCost_Normal_Items_11","2000","高爆子弹盒的价钱", CVAR_FLAGS, true, 0.0);
	CfgNormalItemCost[12]	    = CreateConVar("rpg_ShopCost_Normal_Items_12","2000","燃烧子弹盒的价钱", CVAR_FLAGS, true, 0.0);

	/* Selected Guns Cost*/
	CfgSelectedGunCost[0]	= CreateConVar("rpg_ShopCost_Selected_Guns_00","600","MP5冲锋枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[1]	= CreateConVar("rpg_ShopCost_Selected_Guns_01","600","Scout轻型狙击枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[2]	= CreateConVar("rpg_ShopCost_Selected_Guns_02","1200","Awp重型狙击枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[3]	= CreateConVar("rpg_ShopCost_Selected_Guns_03","600","Sg552突击步枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[4]	= CreateConVar("rpg_ShopCost_Selected_Guns_04","100","M60重型机枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[5]	= CreateConVar("rpg_ShopCost_Selected_Guns_05","750","榴弹发射器的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[6]	= CreateConVar("rpg_ShopCost_Selected_Guns_06","750","AK47的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[7]	= CreateConVar("rpg_ShopCost_Selected_Guns_07","600","战斗散弹枪的价钱", CVAR_FLAGS, true, 0.0);
	CfgSelectedGunCost[8]	= CreateConVar("rpg_ShopCost_Selected_Guns_08","750","M16的价钱", CVAR_FLAGS, true, 0.0);

	/* Selected Melees Cost*/
	CfgMeleeCost[0]			= CreateConVar("rpg_ShopCost_Selected_Melees_00","200","棒球棍的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[1]			= CreateConVar("rpg_ShopCost_Selected_Melees_01","200","板球棍的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[2]			= CreateConVar("rpg_ShopCost_Selected_Melees_02","200","铁撬的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[3]			= CreateConVar("rpg_ShopCost_Selected_Melees_03","200","电结他的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[4]			= CreateConVar("rpg_ShopCost_Selected_Melees_04","200","斧头的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[5]			= CreateConVar("rpg_ShopCost_Selected_Melees_05","200","平底锅的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[6]			= CreateConVar("rpg_ShopCost_Selected_Melees_06","200","高尔夫球棍的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[7]			= CreateConVar("rpg_ShopCost_Selected_Melees_07","500","武士刀的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[8]			= CreateConVar("rpg_ShopCost_Selected_Melees_08","400","CS小刀的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[9]			= CreateConVar("rpg_ShopCost_Selected_Melees_09","300","开山刀的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[10]			= CreateConVar("rpg_ShopCost_Selected_Melees_10","200","盾牌的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[11]			= CreateConVar("rpg_ShopCost_Selected_Melees_11","200","警棍的价钱", CVAR_FLAGS, true, 0.0);
	CfgMeleeCost[12]			= CreateConVar("rpg_ShopCost_Selected_Melees_12","200","电锯的价钱", CVAR_FLAGS, true, 0.0);

	/* Robot成本*/
	CfgRobotCost[0]			= CreateConVar("rpg_ShopCost_Robot_00","1000","[猎枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[1]			= CreateConVar("rpg_ShopCost_Robot_01","1000","[M16突击步枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[2]			= CreateConVar("rpg_ShopCost_Robot_02","1000","[战术散弹枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[3]			= CreateConVar("rpg_ShopCost_Robot_03","750","[散弹枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[4]			= CreateConVar("rpg_ShopCost_Robot_04","750","[乌兹冲锋枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[5]			= CreateConVar("rpg_ShopCost_Robot_05","500","[手枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[6]			= CreateConVar("rpg_ShopCost_Robot_06","750","[麦格农手枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[7]			= CreateConVar("rpg_ShopCost_Robot_07","1500","[AK47]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[8]			= CreateConVar("rpg_ShopCost_Robot_08","1500","[SCAR步枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[9]			= CreateConVar("rpg_ShopCost_Robot_09","1500","[SG552步枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[10]			= CreateConVar("rpg_ShopCost_Robot_10","1500","[铬钢散弹枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[11]			= CreateConVar("rpg_ShopCost_Robot_11","1500","[战斗散弹枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[12]			= CreateConVar("rpg_ShopCost_Robot_12","1500","[自动式狙击枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[13]			= CreateConVar("rpg_ShopCost_Robot_13","1500","[SCOUT轻型狙弹枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[14]			= CreateConVar("rpg_ShopCost_Robot_14","1250","[AWP麦格农狙击枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[15]			= CreateConVar("rpg_ShopCost_Robot_15","1250","[MP5冲锋枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotCost[16]			= CreateConVar("rpg_ShopCost_Robot_16","750","[灭音冲锋枪]Robot每次使用增加的价钱", CVAR_FLAGS, true, 0.0);

	/* 特殊商店*/
	RemoveKTCost				= CreateConVar("rpg_ShopCost_Special_Remove_KT",	"50000",	"消除一次大过的价钱", CVAR_FLAGS, true, 0.0);
	ResetStatusCost			= CreateConVar("rpg_ShopCost_Special_Reset_Status",	"15000",	"遗忘河药水的价钱", CVAR_FLAGS, true, 0.0);
	TomeOfExpCost				= CreateConVar("rpg_ShopCost_Special_Tome_Of_Exp",	"50000",	"经验之书的价钱", CVAR_FLAGS, true, 0.0);
	TomeOfExpEffect			= CreateConVar("rpg_Special_Tome_Of_Exp_Effect",	"1",		"使用经验之书增加多少EXP", CVAR_FLAGS, true, 0.0);
	ResumeMP			= CreateConVar("rpg_Special_Tome_Of_Resume_MP",	"10000",		"西蓝果汁价钱", CVAR_FLAGS, true, 0.0);

	/* 彩票卷 */
	LotteryEnable				= CreateConVar("rpg_Lottery_Enable",	"0",	"是否开启彩票功能(0:OFF 1:ON)", CVAR_FLAGS, true, 0.0, true, 1.0);
	LotteryCost				= CreateConVar("rpg_Lottery_Cost",		"500",	"彩票卷单价", CVAR_FLAGS, true, 0.0);
	LotteryRecycle			= CreateConVar("rpg_Lottery_Recycle",	"0.1",	"回收彩票卷的价钱=售价x倍率(0.0~1.0)", CVAR_FLAGS, true, 0.0, true, 1.0);

	/* Robot Config */
	RobotReactiontime			= CreateConVar("rpg_RobotConfig_Reactiontime",	"0.1",	"Robot反应时间", CVAR_FLAGS, true, 0.1);
 	RobotEnergy				= CreateConVar("rpg_RobotConfig_Rnergy", 		"30.0",	"Robot能量维持时间(分钟)", CVAR_FLAGS, true, 0.1);
	CfgRobotUpgradeCost[0]	= CreateConVar("rpg_RobotUpgradeCost_0",		"1",	"升级Robot攻击力的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotUpgradeCost[1]	= CreateConVar("rpg_RobotUpgradeCost_1",		"1",	"升级Robot弹匣系统的价钱", CVAR_FLAGS, true, 0.0);
	CfgRobotUpgradeCost[2]	= CreateConVar("rpg_RobotUpgradeCost_2",		"1",	"升级Robot侦查距离的价钱", CVAR_FLAGS, true, 0.0);

	ShowMode					= CreateConVar("rpg_ShowMode", 						"1",	"公屏聊天时是否在游戏名前显示等级信息 0-不显示 1-显示", CVAR_FLAGS, true, 0.0, true, 1.0);
	//密码超时
	cv_pwtimeout				= CreateConVar("rpg_cv_pwtimeout",				"300",	"进入游戏后多少秒内不输入密码将踢出服务器(0 = 禁用)", CVAR_FLAGS);
	cv_loadtimeout				= CreateConVar("rpg_cv_loadtimeout",				"0",	"加载地图时,卡住多少秒踢出(0 = 禁用)", CVAR_FLAGS);
	//人数上限
	cv_survivor_limit			= CreateConVar("rpg_cv_survivor_limit",				"16",	"幸存者上限(自动创建bot)", CVAR_FLAGS);
	cv_infected_limit			= CreateConVar("rpg_cv_infected_limit",				"0",	"感染者上限(不是对抗模式不用修改)", CVAR_FLAGS);
	//VIP系统
	cv_vipexp					= CreateConVar("rpg_vipexp",				"1",	"是否开启VIP经验加成(1 = 开启 0 = 禁用)", CVAR_FLAGS);
	cv_vipcash					= CreateConVar("rpg_vipcash",				"1",	"是否开启VIP金钱加成(1 = 开启 0 = 禁用)", CVAR_FLAGS);
	cv_firtsreg					= CreateConVar("cv_firtsreg",				"500000",	"首次注册赠送金钱(0 = 禁用)", CVAR_FLAGS);
	cv_vipbuy					= CreateConVar("rpg_vipbuy",				"1",	"是否开启VIP商店打折(1 = 开启 0 = 禁用)", CVAR_FLAGS);
	cv_vippropsA					= CreateConVar("rpg_vipropsA",				"4",	"白银VIP1的每回合免费补给数量", CVAR_FLAGS);
	cv_vippropsB					= CreateConVar("rpg_vipropsB",				"8",	"黄金VIP2的每回合免费补给数量", CVAR_FLAGS);
	cv_vippropsC					= CreateConVar("rpg_vipropsC",				"12",	"水晶VIP3的每回合免费补给数量", CVAR_FLAGS);
	cv_vippropsD					= CreateConVar("rpg_vipropsD",				"16",	"至尊VIP4的每回合免费补给数量", CVAR_FLAGS);
	cv_vippropsE					= CreateConVar("rpg_vipropsE",				"18",	"至尊VIP4的每回合免费补给数量", CVAR_FLAGS);
	cv_vippropsF					= CreateConVar("rpg_vipropsF",				"20",	"至尊VIP4的每回合免费补给数量", CVAR_FLAGS);
	cv_vippropsE					= CreateConVar("rpg_vipropsE",				"22",	"至尊VIP5的每回合免费补给数量", CVAR_FLAGS);
	cv_vippropsF					= CreateConVar("rpg_vipropsF",				"24",	"至尊VIP6的每回合免费补给数量", CVAR_FLAGS);


	/* 紫炎坦克 */
	sm_supertank_bossratio	  = CreateConVar("sm_supertank_bossratio",   "30.0", "紫炎坦克出现几率(默认是5/100)(另一半机率为4阶段Tank)",    CVAR_FLAGS);
	sm_supertank_Killerratio	  = CreateConVar("sm_supertank_Killerratio",   "0.0", "闪电坦克出现几率(默认是5/100)(默认关闭,已经无效)",    CVAR_FLAGS);
	
	sm_supertank_bossrange	  = CreateConVar("sm_supertank_bossrange",   "80.0", "紫炎坦克屏幕抖动影响范围",    CVAR_FLAGS);
	//sm_supertank_Killerrange	  = CreateConVar("sm_supertank_Killerrange",   "80.0", "闪电坦克屏幕抖动影响范围",    CVAR_FLAGS);

	/* 超级坦克生命值 */
	sm_supertank_health_max	  = CreateConVar("sm_supertank_health_max",   "10000", "超级坦克第一阶段生命值(默认血量)",    CVAR_FLAGS);
	sm_supertank_health_second = CreateConVar("sm_supertank_health_second","0.70", "超级坦克第二阶段生命值(%)", CVAR_FLAGS);
	sm_supertank_health_third  = CreateConVar("sm_supertank_health_third", "0.50", "超级坦克第三阶段生命值(%)",  CVAR_FLAGS);
	sm_supertank_health_forth  = CreateConVar("sm_supertank_health_forth", "0.40",  "超级坦克第四阶段生命值(%)",  CVAR_FLAGS);
	
	sm_supertank_health_boss		= CreateConVar("sm_supertank_health_boss", "20000",  "紫炎坦克生命值(默认血量)",  CVAR_FLAGS);
	sm_supertank_health_Killer		= CreateConVar("sm_supertank_health_Killer", "30000",  "闪电坦克生命值(默认血量)",  CVAR_FLAGS);

	/*玩家装备颜色*/
	/*
	sm_playerequipment_color_SQ	=	CreateConVar("sm_playerequipment_color_SQ","176 163	52","玩家装备神器的颜色",	CVAR_FLAGS);
	sm_playerequipment_color_CQ	=	CreateConVar("sm_playerequipment_color_CQ","67 67 209","玩家装备传说装备的颜色",	CVAR_FLAGS);
	sm_playerequipment_color_GH	=	CreateConVar("sm_playerequipment_color_GH","206 217 26","玩家装备光环装备的颜色",	CVAR_FLAGS);
	sm_playerequipment_color_TZ	=	CreateConVar("sm_playerequipment_color_TZ","221 29	48","玩家装备黑暗套装的颜色",	CVAR_FLAGS);
	sm_playerequipment_color_XQ	=	CreateConVar("sm_playerequipment_color_XQ","255 0	0","玩家装备仙器(创世神器)的颜色",	CVAR_FLAGS);
	sm_playerequipment_color_XQ	=	CreateConVar("sm_playerequipment_color_DY","255 130	40","玩家装备死亡地狱套装的颜色",CVAR_FLAGS);
	sm_playerequipment_color_SW	=	CreateConVar("sm_playerequipment_color_SW","255 255 255","玩家装备天堂神器的颜色",	CVAR_FLAGS);
	sm_playerequipment_color_LD	=	CreateConVar("sm_playerequipment_color_LD","255 255 255","玩家装备天堂神器的颜色",	CVAR_FLAGS);
	sm_playerequipment_color_AQ	=	CreateConVar("sm_playerequipment_color_AQ","255 255 255","玩家装备天堂神器的颜色",	CVAR_FLAGS);
	*/
	
	/* 超级坦克颜色 */
	sm_supertank_color_first	  = CreateConVar("sm_supertank_color_first", "171 171 171", "超级坦克第一阶段颜色(0-255)", CVAR_FLAGS);
	sm_supertank_color_second  = CreateConVar("sm_supertank_color_second","152 161 106", "超级坦克第二阶段颜色(0-255)", CVAR_FLAGS);
	sm_supertank_color_third	  = CreateConVar("sm_supertank_color_third", "165 42 42", "超级坦克第三阶段颜色(0-255)", CVAR_FLAGS);
	sm_supertank_color_forth	  = CreateConVar("sm_supertank_color_forth", "139 0 139", "超级坦克第四阶段颜色(0-255)", CVAR_FLAGS);
	
	sm_supertank_color_boss	  = CreateConVar("sm_supertank_color_boss", "250 0 250", "紫炎坦克颜色(0-255)", CVAR_FLAGS);
	sm_supertank_color_Killer	  = CreateConVar("sm_supertank_color_boss", "0 255 0", "闪电坦克颜色(0-255)", CVAR_FLAGS);

	/* 超级坦克速度 */
	sm_supertank_speed[TANK1]		= CreateConVar("sm_supertank_speed_1",  "1.0", "超级坦克第一阶段速度倍率",  CVAR_FLAGS);
	sm_supertank_speed[TANK2]		= CreateConVar("sm_supertank_speed_2",  "1.2", "超级坦克第二阶段速度倍率", CVAR_FLAGS);
	sm_supertank_speed[TANK3]		= CreateConVar("sm_supertank_speed_3",  "1.4", "超级坦克第三阶段速度倍率",  CVAR_FLAGS);
	sm_supertank_speed[TANK4]		= CreateConVar("sm_supertank_speed_4",  "1.6", "超级坦克第四阶段速度倍率",  CVAR_FLAGS);
	
	sm_supertank_speed[TANK5]		= CreateConVar("sm_supertank_speed_5",  "1.8", "紫炎坦克速度倍率",  CVAR_FLAGS);
	sm_supertank_speed[TANK6]		= CreateConVar("sm_supertank_speed_6",  "4.0", "闪电坦克速度倍率",  CVAR_FLAGS);

	/* 超级坦克技能 */		
	sm_supertank_quake_radius		= CreateConVar("sm_supertank_quake_radius", "300.0", "地震技能影响范围(全部阶段)", CVAR_FLAGS);
	sm_supertank_quake_force			= CreateConVar("sm_supertank_quake_force", "300.0", "地震技能威力(全部阶段)", CVAR_FLAGS);
	sm_supertank_gravityinterval		= CreateConVar("sm_supertank_gravityinterval", "10.0", "重力技能使用间隔(第二阶段)", CVAR_FLAGS);
	sm_supertank_dreadinterval		= CreateConVar("sm_supertank_dreadinterval", "10.0", "致盲技能使用间隔(第三阶段)", CVAR_FLAGS);
	sm_supertank_dreadrate			= CreateConVar("sm_supertank_dreadrate", "250", "致盲技能的致盲程度(第三阶段)", CVAR_FLAGS);
	sm_supertank_warp_interval		= CreateConVar("sm_supertank_warp_interval", "60.0", "坦克瞬移使用间隔(全部阶段,不建议修改,太慢会导致卡TANK自杀)", CVAR_FLAGS);

	/* 超级坦克吸星大法 */
	sm_supertank_xixing_range			= CreateConVar("sm_supertank_xixing_range", "300.0", "吸星大法吸取范围(半径)", CVAR_FLAGS);
	sm_supertank_xixing_interval		= CreateConVar("sm_supertank_xixing_interval", "0.0", "吸星大法使用间隔(0.0 = 瞬移后使用)", CVAR_FLAGS);
	sm_supertank_xixing_abs				= CreateConVar("sm_supertank_xixing_abs", "400.0", "吸星大法_震击强度(第二阶段)", CVAR_FLAGS);
	sm_supertank_xixing_dread			= CreateConVar("sm_supertank_xixing_dread", "10.0", "吸星大法_致盲持续时间(第四阶段)", CVAR_FLAGS);
	sm_supertank_xixing_slowspeed	 	= CreateConVar("sm_supertank_xixing_slowspeed",   "2.4", "吸星大法_减速后的速度倍率",    CVAR_FLAGS);
	sm_supertank_xixing_slowtime	 	= CreateConVar("sm_supertank_xixing_slowtime",   "10.0", "吸星大法_减速持续的时间",    CVAR_FLAGS);

	/* 坦克吸星大法地震 */
	sm_supertank_quake_radiusz		= CreateConVar("sm_supertank_quake_radiusz", "1600.0", "大地震技能影响范围(4阶段和紫炎)", CVAR_FLAGS);
	sm_supertank_quake_forcez			= CreateConVar("sm_supertank_quake_forcez", "3000.0", "大地震技能威力(4阶段和紫炎))", CVAR_FLAGS);

	//超级坦克护甲
	sm_supertank_armor_tank[TANK1] 			= CreateConVar("sm_supertank_armor_tank1",   "2.5", "超级坦克第一阶段护甲系数",    CVAR_FLAGS);
	sm_supertank_armor_tank[TANK2] 			= CreateConVar("sm_supertank_armor_tank2",   "2.4", "超级坦克第二阶段护甲系数",    CVAR_FLAGS);
	sm_supertank_armor_tank[TANK3] 			= CreateConVar("sm_supertank_armor_tank3",   "2.3", "超级坦克第三阶段护甲系数",    CVAR_FLAGS);
	sm_supertank_armor_tank[TANK4] 			= CreateConVar("sm_supertank_armor_tank4",   "2.2", "超级坦克第四阶段护甲系数",    CVAR_FLAGS);
	
	sm_supertank_armor_tank[TANK5] 			= CreateConVar("sm_supertank_armor_tank5",   "2.1", "紫炎坦克护甲系数",    CVAR_FLAGS);
	sm_supertank_armor_tank[TANK6] 			= CreateConVar("sm_supertank_armor_tank6",   "3.0", "闪电坦克护甲系数",    CVAR_FLAGS);
	/* 坦克平衡 */
	sm_supertank_tankbalance	 			= CreateConVar("sm_supertank_tankbalance",   "200", "幸存者等级高于感染者等级多少增加一只坦克",    CVAR_FLAGS);

	
	/* 难度平衡
				等级说明: lv1 -> 幸存者队伍等级 大于0 小于50					等级说明: lv2 -> 幸存者队伍等级 大于50 小于100
				等级说明: lv3 -> 幸存者队伍等级 大于100 小于600				等级说明: lv4 -> 幸存者队伍等级 大于600 小于1000
				等级说明: lv5 -> 幸存者队伍等级 大于1000 小于1600			等级说明: lv6 -> 幸存者队伍等级 大于1600 小于2600
				等级说明: lv7 -> 幸存者队伍等级 大于2600 小于3600
	*/
	rpg_gamedifficulty	 			 = CreateConVar("rpg_gamedifficulty",   "1", "是否启用难度自动平衡(开启后Tank 默认血量将失效)",    CVAR_FLAGS);
	rpg_gamedifficulty_tankHP_lv1	 = CreateConVar("rpg_gamedifficulty_tankHP_lv1",   "40000, 50000, 30000", "难度自动平衡等级1: (Tank血量分别对应: 4阶段, 紫炎, 闪电)",    CVAR_FLAGS);
	rpg_gamedifficulty_tankHP_lv2	 = CreateConVar("rpg_gamedifficulty_tankHP_lv2",   "44000, 55000, 33000", "难度自动平衡等级2: (Tank血量分别对应: 4阶段, 紫炎, 闪电)",    CVAR_FLAGS);
	rpg_gamedifficulty_tankHP_lv3	 = CreateConVar("rpg_gamedifficulty_tankHP_lv3",   "48000, 60000, 36000", "难度自动平衡等级3: (Tank血量分别对应: 4阶段, 紫炎, 闪电)",    CVAR_FLAGS);
	rpg_gamedifficulty_tankHP_lv4	 = CreateConVar("rpg_gamedifficulty_tankHP_lv4",   "52000, 65000, 39000", "难度自动平衡等级4: (Tank血量分别对应: 4阶段, 紫炎, 闪电)",    CVAR_FLAGS);
	rpg_gamedifficulty_tankHP_lv5	 = CreateConVar("rpg_gamedifficulty_tankHP_lv5",   "60000, 70000, 42000", "难度自动平衡等级5: (Tank血量分别对应: 4阶段, 紫炎, 闪电)",    CVAR_FLAGS);
	rpg_gamedifficulty_tankHP_lv6	 = CreateConVar("rpg_gamedifficulty_tankHP_lv6",   "64000, 75000, 45000", "难度自动平衡等级6: (Tank血量分别对应: 4阶段, 紫炎, 闪电)",    CVAR_FLAGS);
	rpg_gamedifficulty_tankHP_lv7	 = CreateConVar("rpg_gamedifficulty_tankHP_lv7",   "68000, 80000, 48000", "难度自动平衡等级7: (Tank血量分别对应: 4阶段, 紫炎, 闪电)",    CVAR_FLAGS);


	
	/*witch上身*/
	//l4d_witch_onback_bestpose = CreateConVar("l4d_witch_onback_bestpose", "0", "  0: random pose, 1: best pose", FCVAR_PLUGIN);
}
HookEvents()
{
	/* Event */
	HookEvent("player_hurt",			Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("witch_killed",			Event_WitchKilled);
	HookEvent("infected_hurt",			Event_InfectedHurt, EventHookMode_Pre);
	HookEvent("round_end",				Event_RoundEnd);
	HookEvent("heal_success",			Event_HealSuccess);
	HookEvent("revive_success",			Event_ReviveSuccess);
	HookEvent("round_start",			Event_RoundStart);
	HookEvent("player_first_spawn",		Event_PlayerFirstSpawn);
	HookEvent("player_death",			Event_PlayerDeath);
	HookEvent("player_spawn",			Event_PlayerSpawn);
	HookEvent("defibrillator_used",		Event_DefibrillatorUsed);
	HookEvent("player_incapacitated",	Event_Incapacitate);
	HookEvent("weapon_fire",			Event_WeaponFire2);
	HookEvent("weapon_fire",			Event_WeaponFire2S);
	HookEvent("weapon_fire",			Event_WeaponFire,	EventHookMode_Pre);
	HookEvent("player_use",				Event_PlayerUse);
	HookEvent("player_team",			Event_PlayerTeam);
	HookEvent("bot_player_replace",		Event_BotPlayerReplace);
	HookEvent("witch_harasser_set",		Event_WitchHarasserSet);
	HookEvent("player_changename",		Event_PlayerChangename,	EventHookMode_Pre);
	HookEvent("player_spawn", PlayerSpawnEvent);
	HookEvent("player_death", PlayerDeathEvent);
	HookEvent("tank_spawn", Event_Tank_Spawn, EventHookMode_Pre);
	HookEvent("bullet_impact",	Event_BulletImpact);
	//HookEvent("infected_death", Event_Infected_Death);
	HookEvent("item_pickup", Melee_Event_ItemPickup);
	HookEvent("weapon_fire", Melee_Event_WeaponFire);
	
	//by MicroLeo
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
	//end
}

InitPrecache()
{
	/* Sound Precache */
	PrecacheSound(TSOUND, true);
	PrecacheSound(SatelliteCannon_Sound_Launch, true);
	PrecacheSound(SatelliteCannonmiss_Sound_Launch, true);
	PrecacheSound(SOUNDCLIPEMPTY, true);
	PrecacheSound(SOUNDRELOAD, true);
	PrecacheSound(SOUNDREADY, true);
	PrecacheSound(FireBall_Sound_Impact01, true);
	PrecacheSound(FireBall_Sound_Impact02, true);
	PrecacheSound(IceBall_Sound_Impact01, true);
	PrecacheSound(IceBall_Sound_Impact02, true);
	PrecacheSound(IceBall_Sound_Freeze, true);
	PrecacheSound(IceBall_Sound_Defrost, true);
	PrecacheSound(ChainLightning_Sound_launch, true);
	PrecacheSound(ChainmissLightning_Sound_launch, true);
	PrecacheSound(ChainkbLightning_Sound_launch, true);
	PrecacheSound("ambient/alarms/klaxon1.wav", true);
	PrecacheSound("ambient/explosions/explode_3.wav", true);
	PrecacheSound("animation/gas_station_explosion.wav", true);
	PrecacheSound("animation/van_inside_debris.wav", true);
	PrecacheSound("ambient/random_amb_sfx/dist_explosion_01.wav", true);
	PrecacheSound("ambient/random_amb_sfx/dist_explosion_02.wav", true);
	PrecacheSound("ambient/random_amb_sfx/dist_explosion_03.wav", true);
	PrecacheSound("ambient/random_amb_sfx/dist_explosion_04.wav", true);

	/* Precache sounds */
	PrecacheSound(SOUND_TRACING, true);
	//暴击音效
	PrecacheSound(CRIT_SOUND, true);
	//弹药师_吸血弹音效
	PrecacheSound(SOUND_SUCKBLOOD, true);
	//获得道具音效
	PrecacheSound(SOUND_GOTITEM, true);
	//使用道具音效
	PrecacheSound(SOUND_USEITEM, true);
	//DLC坦克模型
	PrecacheModel(MODEL_DLCTANK, true);
	PrecacheModel(MODEL_TANK, true);

	for(new i=0; i<WEAPONCOUNT; i++)
	{
		PrecacheModel(MODEL[i], true);
		PrecacheSound(SOUND[i], true) ;
	}
	robot_gamestart = false;

	/* Precache models */
	PrecacheModel(ENTITY_PROPANE, true);
	PrecacheModel(ENTITY_GASCAN, true);

	PrecacheModel(FireBall_Model);

	PrecacheModel("models/props_junk/gascan001a.mdl", true);
	PrecacheModel("models/props_junk/propanecanister001a.mdl", true);
	PrecacheModel("models/props_junk/explosive_box001.mdl", true);
	PrecacheModel("models/props_equipment/oxygentank01.mdl", true);
	PrecacheModel("models/missiles/f18_agm65maverick.mdl", true);

	fire =PrecacheModel("materials/sprites/laserbeam.vmt");
	white =PrecacheModel("materials/sprites/white.vmt");
	halo = PrecacheModel("materials/dev/halo_add_to_screen.vmt");

	PrecacheParticle("gas_explosion_pump");
	PrecacheParticle(PARTICLE_BLOOD);
	PrecacheParticle(PARTICLE_INFECTEDSUMMON);
	PrecacheParticle(PARTICLE_SCEFFECT);
	PrecacheParticle(PARTICLE_HLEFFECT);

	PrecacheParticle(FireBall_Particle_Fire01);
	PrecacheParticle(FireBall_Particle_Fire02);
	PrecacheParticle(FireBall_Particle_Fire03);

	PrecacheParticle(IceBall_Particle_Ice01);
	PrecacheParticle(ChainLightning_Particle_hit);
	PrecacheParticle(ChainmissLightning_Particle_hit);
	PrecacheParticle(ChainkbLightning_Particle_hit);

	//PrecacheParticle(HealingBall_Particle);
	PrecacheParticle(HealingBall_Particle_Effect);

	//PrecacheParticle(HealingBallmiss_Particle);
	PrecacheParticle(HealingBallmiss_Particle_Effect);

	PrecacheParticlemiss("gas_explosion_main");
	PrecacheParticlemiss("weapon_pipebomb");
	PrecacheParticlemiss("gas_explosion_pump");
	PrecacheParticlemiss("electrical_arc_01_system");
	PrecacheParticlemiss("electrical_arc_01_parent");

	/* Model Precache */
	g_BeamSprite = PrecacheModel(SPRITE_BEAM);
	g_HaloSprite = PrecacheModel(SPRITE_HALO);
	g_GlowSprite = PrecacheModel(SPRITE_GLOW);

	/* Precache models */
	PrecacheModel(ENTITY_PROPANE, true);
	PrecacheModel(ENTITY_GASCAN, true);

	/* Precache sounds */
	PrecacheSound(SOUND_EXPLODE, true);
	PrecacheSound(SOUND_SPAWN, true);
	PrecacheSound(SOUND_BCLAW, true);
	PrecacheSound(SOUND_GCLAW, true);
	PrecacheSound(SOUND_DCLAW, true);
	PrecacheSound(SOUND_QUAKE, true);
	PrecacheSound(SOUND_STEEL, true);
	PrecacheSound(SOUND_CHANGE, true);
	PrecacheSound(SOUND_HOWL, true);
	PrecacheSound(SOUND_WARP, true);
	PrecacheSound(SOUND_ABS, true);

	/* Precache particles */
	PrecacheParticle(PARTICLE_SPAWN);
	PrecacheParticle(PARTICLE_DEATH);
	PrecacheParticle(PARTICLE_THIRD);
	PrecacheParticle(PARTICLE_FORTH);
	PrecacheParticle(PARTICLE_WARP);
}

GetConVar()
{
  	robot_reactiontime=GetConVarFloat(RobotReactiontime);
 	robot_energy=GetConVarFloat(RobotEnergy)*60.0;		//机器人维持时间
	//难度平衡convar
	SuperTank_Health[TANK1] = GetConVarInt(sm_supertank_health_max);
	SuperTank_Health[TANK2] = GetConVarInt(sm_supertank_health_second);
	SuperTank_Health[TANK3] = GetConVarInt(sm_supertank_health_third);
	SuperTank_Health[TANK4] = GetConVarInt(sm_supertank_health_forth);
	SuperTank_Health[TANK5] = GetConVarInt(sm_supertank_health_boss);
	SuperTank_Health[TANK6] = GetConVarInt(sm_supertank_health_Killer);
	SuperTank_Warp = GetConVarFloat(sm_supertank_warp_interval);
}

public ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVar();
}

static Initialization(i)
{
	ID[i]=0; JD[i]=0; Lv[i]=0; EXP[i]=0; Cash[i]=0; KTCount[i]=0; RobotCount[i]=0; NewLifeCount[i]=0;
	Str[i]=0; Agi[i]=0; Health[i]=0; Endurance[i]=0; Intelligence[i]=0; XB[i]=0; XC[i]=0; Lis[i]=0; LisA[i]=0; LisB[i]=0; LisC[i]=0; LisD[i]=0;
	StatusPoint[i]=0; SkillPoint[i]=0; HealingLv[i]=0; HealingkbLv[i]=1; HealingwxLv[i]=1; HealinggbdLv[i]=1; EndranceQualityLv[i]=0; EarthQuakeLv[i]=0;
	AmmoMakingLv[i]=0; FireSpeedLv[i]=0; SatelliteCannonLv[i]=0; SatelliteCannonmissLv[i]=0;
	EnergyEnhanceLv[i]=0; SprintLv[i]=0; InfiniteAmmoLv[i]=0; Eqbox[i]=0; TDaxinxin[i]=0;
	Renwu[i]=0; Jenwu[i]=0; Pugan[i]=0; Tegan[i]=0; TYangui[i]=0; TPangzi[i]=0; TLieshou[i]=0;
	TKoushui[i]=0; THouzhi[i]=0; TXiaoniu[i]=0; Libao[i]=0;  LibaoLv[i]=0; Lyxz[i]=0; ACL[i]=0; SCL[i]=0; BCL[i]=0; FHCS[i]=0; LQDY[i]=0;
	Hunpo[i]=0; GouhunLv[i]=0; LinliLv[i]=0; AreaBlastingexLv[i]=0; SszlLv[i]=0; DyzhLv[i]=0; AynlLv[i]=0;
	BioShieldLv[i]=0; BioShieldmissLv[i]=0; BioShieldkbLv[i]=0; DamageReflectLv[i]=0; MeleeSpeedLv[i]=0;
	defibrillator[i]=0; TeleportToSelectLv[i]=0; HolyBoltLv[i]=0; TeleportTeamLv[i]=0; TeleportTeamztLv[i]=0; HealingBallLv[i]=0; HealingBallmissLv[i]=1;
	FireBallLv[i]=0; IceBallLv[i]=0; ChainLightningLv[i]=0; ChainmissLightningLv[i]=1; ChainkbLightningLv[i]=1;
	RobotUpgradeLv[i][0]=0; RobotUpgradeLv[i][1]=0; RobotUpgradeLv[i][2]=0; Lottery[i]=0; VIPTYOVER[i]=0; everyday1[i]=0;
	MFBS1[i]=0; MFBS2[i]=0; MFBS3[i]=0; MFBS4[i]=0; MFBS5[i]=0; MFBS6[i]=0; MFBS7[i]=0; YWZZS[i]=0;
	M16[i]=0; AK47[i]=0; PZ[i]=0; AWP[i]=0; M60[i]=0; GZ[i]=0; Qhs[i]=0; BSXY[i]=0; Sxcs[i]=0; BSZG[i]=0; TZZS[i]=0; TZMS[i]=0;
	TANKSL[i]=0; LRCS[i]=0; JRCS[i]=0; PTJS[i]=0; ZXRW[i]=0; KSZXRW[i]=0; XBFBLv[i]=0; FBZNLv[i]=0; DDCS[i]=0; TSBS[i]=0;
	HassLv[i]=0; CqdzLv[i]=0; ZdgcLv[i]=0; SWHTLv[i]=0; SWGZLv[i]=0; WXNYLv[i]=0; BSD[i]=0; GZSLv[i]=0; YLTJLv[i]=0; LDZLv[i]=0;
	BJCH[i]=0; TKSL[i]=0; XGSL[i]=0; HZSL[i]=0; PPSL[i]=0; PZSL[i]=0; DXSL[i]=0; NWSL[i]=0; BRSL[i]=0; DRSL[i]=0; YGSL[i]=0; QHSL[i]=0;
	TKSLZ[i]=0; XGSLZ[i]=0; HZSLZ[i]=0; PPSLZ[i]=0; PZSLZ[i]=0; DXSLZ[i]=0; NWSLZ[i]=0; BRSLZ[i]=0; DRSLZ[i]=0; YGSLZ[i]=0; QHHSZ[i]=0; BZBNZ[i]=0; YLDY[i]=0;
	SMZS[i]=0; FHZS[i]=0; HMZSLv[i]=0; SPZSLv[i]=0; JYSQLv[i]=0; SXZGLv[i]=0; DSZGLv[i]=0; LZDLv[i] = 0; WZZGLv[i] = 0; PHFRLv[i] = 0; PHABLv[i] = 0;
	PHZGLv[i] = 0; PHSCLv[i] = 0;PHFRALv[i] = 0; PHABALv[i] = 0; PHZGALv[i] = 0; PHSDLv[i] = 0; XJLv[i]=0; XJALv[i]=1; LLLZLv[i]=1;
	LLLELv[i]=1; LLLSLv[i]=1; BBBSLv[i] = 0; HYJWLv[i] = 0; NQBFLv[i] = 0; XZKBLv[i] = 0; XZKBALv[i] = 1; XZKBALv[i] = 1;

	IsSatelliteCannonReady[i]=true;
	IsSatelliteCannonmissReady[i]=true;
	IsSprintEnable[i]=false;
	IsInfiniteAmmoEnable[i]=false;
	IsBioShieldEnable[i]=false;
	IsBioShieldmissEnable[i]=false;
	IsBioShieldkbEnable[i]=false;
	IsBioShieldReady[i]=true;
	IsBioShieldmissReady[i]=true;
	IsBioShieldkbReady[i]=true;
	IsDamageReflectEnable[i]=false;
	IsMeleeSpeedEnable[i]=false;
	IsTeleportTeamEnable[i]=false;
	IsTeleportTeamztEnable[i]=false;
	IsHolyBoltEnable[i]=false;
	IsSXZGEnable[i]=false;
	IsPHZGEnable[i]=false;
	IsTeleportToSelectEnable[i]=false;
	//HealingBallExp[i] = 0;
	HealingBallmissExp[i] = 0;
	IsHealingBallEnable[i] = false;
	IsHealingBallmissEnable[i] = false;
	IsPasswordConfirm[i]=false;
	IsAdmin[i]=false;
	IsWXNYEnable[i]=false;
	IsSWHTEnable[i]=false;
	IsSWHTReady[i]=true;
	IsYLTJReady[i]=true;
	IsYLTJmissReady[i]=true;
	IsDSZGReady[i]=true;
	IsDSZGmissReady[i]=true;
	IsWZZGReady[i]=true;
	IsWZZGmissReady[i]=true;
	IsGZSEnable[i]=false;
	IsPHFRAEnable[i]=false;
	IsPHFRAReady[i]=true;
	IsPHABAEnable[i]=false;
	IsPHZGAEnable[i]=false;
	IsXJEnable[i]=false;
	IsXJReady[i]=true;
	IsXZKBEnable[i]=false;
	IsXZKBReady[i]=true;
	IsLLLEReady[i]=true;
	IsLLLEmissReady[i]=true;
	IsHYJWEnable[i]=false;
	//弹药专家
	Broken_Ammo[i] = false;
	Poison_Ammo[i] = false;
	LZD_Ammo[i] = false	;
	SuckBlood_Ammo[i] = false;
	AreaBlasting[i] = false;
	PHAB[i] = false;
	BBBS[i] = false;
	NQBF[i] = false;
	LaserGun[i] = false;
	BrokenAmmoLv[i] = 0;
	PoisonAmmoLv[i] = 0;
	SuckBloodAmmoLv[i] = 0;
	AreaBlastingLv[i] = 0;
	LaserGunLv[i] = 0;
	//基因改造
	GeneLv[i] = 0;
	//VIP
	VIP[i] = 0;
	DLTNum[i] = 0;

	//背包清理
	I_BagSize[i] = 0;
	for (new x; x < 5; x++)
	{
		for (new u; u < BagMax[x]; u++)
			I_Bag[i][x][u] = 0;
	}

	//装备清理
	//消耗类道具物品读取
	PlayerXHItemSize[i] = 0;
	for (new x; x < MaxItemNum[ITEM_XH]; x++)
		PlayerItem[i][ITEM_XH][x] = 0;


	//装备类道具物品读取
	PlayerZBItemSize[i] = 0;
	for (new x; x < MaxItemNum[ITEM_ZB]; x++)
		PlayerItem[i][ITEM_ZB][x] = 0;

	//新手BUFF
	HasBuffPlayer[i] = false;

	//每日签到
	EveryDaySign[i] = -1;

	/* 停止检查经验Timer */
	if(CheckExpTimer[i] != INVALID_HANDLE)
	{
		KillTimer(CheckExpTimer[i]);
		CheckExpTimer[i] = INVALID_HANDLE;
	}

	KillAllClientSkillTimer(i);
}

KillAllClientSkillTimer(Client)
{
	/* 停止击杀丧尸Timer */
	if(ZombiesKillCountTimer[Client] != INVALID_HANDLE)
	{
		ZombiesKillCount[Client] = 0;
		KillTimer(ZombiesKillCountTimer[Client]);
		ZombiesKillCountTimer[Client] = INVALID_HANDLE;
	}
	/*  停止治疗术Timer */
	if(HealingTimer[Client] != INVALID_HANDLE)
	{
		KillTimer(HealingTimer[Client]);
		HealingTimer[Client] = INVALID_HANDLE;
	}

	if(JD[Client] > 0)
	{
		if(JD[Client] == 1)
		{
			/* 停止暗夜直射CD Timer */
			if(SatelliteCannonCDTimer[Client] != INVALID_HANDLE)
			{
				IsSatelliteCannonReady[Client] = true;
				KillTimer(SatelliteCannonCDTimer[Client]);
				SatelliteCannonCDTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 2)
		{
			/* 停止暴走效果Timer */
			if(SprinDurationTimer[Client] != INVALID_HANDLE)
			{
				IsSprintEnable[Client] = false;
				RebuildStatus(Client, false);
				KillTimer(SprinDurationTimer[Client]);
				SprinDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 停止无限子弹术效果Timer */
			if(InfiniteAmmoDurationTimer[Client] != INVALID_HANDLE)
			{
				IsInfiniteAmmoEnable[Client] = false;
				KillTimer(InfiniteAmmoDurationTimer[Client]);
				InfiniteAmmoDurationTimer[Client] = INVALID_HANDLE;
			}
			/*  狂暴关联Timer */
			if(HealingkbTimer[Client] != INVALID_HANDLE)
			{
			KillTimer(HealingkbTimer[Client]);
			HealingkbTimer[Client] = INVALID_HANDLE;
			}
			/* 狂暴关联two Timer */
			if(BioShieldkbDurationTimer[Client] != INVALID_HANDLE)
			{
				IsBioShieldkbEnable[Client] = false;
				SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);
				KillTimer(BioShieldkbDurationTimer[Client]);
				BioShieldkbDurationTimer[Client] = INVALID_HANDLE;
			}
			/*  狂暴关联wuxian Timer */
			if(HealingwxTimer[Client] != INVALID_HANDLE)
			{
			KillTimer(HealingwxTimer[Client]);
			HealingwxTimer[Client] = INVALID_HANDLE;
			}
			/*  狂暴关联gaobaodan Timer */
			if(HealinggbdTimer[Client] != INVALID_HANDLE)
			{
			KillTimer(HealinggbdTimer[Client]);
			HealinggbdTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 3)
		{
			/* 停止无敌术效果Timer */
			if(BioShieldDurationTimer[Client] != INVALID_HANDLE)
			{
				IsBioShieldEnable[Client] = false;
				SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);
				KillTimer(BioShieldDurationTimer[Client]);
				BioShieldDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 停止无敌术CD Timer */
			if(BioShieldCDTimer[Client] != INVALID_HANDLE)
			{
				IsBioShieldReady[Client] = true;
				KillTimer(BioShieldCDTimer[Client]);
				BioShieldCDTimer[Client] = INVALID_HANDLE;
			}
			/* 停止反伤术效果Timer */
			if(DamageReflectDurationTimer[Client] != INVALID_HANDLE)
			{
				IsDamageReflectEnable[Client] = false;
				KillTimer(DamageReflectDurationTimer[Client]);
				DamageReflectDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 近战嗜血术效果Timer */
			if(MeleeSpeedDurationTimer[Client] != INVALID_HANDLE)
			{
				IsMeleeSpeedEnable[Client] = false;
				KillTimer(MeleeSpeedDurationTimer[Client]);
				MeleeSpeedDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 停止暗影嗜血术Timer */
			if(BioShieldmissDurationTimer[Client] != INVALID_HANDLE)
			{
				IsBioShieldmissEnable[Client] = false;
				SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);
				KillTimer(BioShieldmissDurationTimer[Client]);
				BioShieldmissDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 嗜血术关联Timer */
			if(HealingBallmissTimer[Client] != INVALID_HANDLE)
			{
				if (IsValidPlayer(Client) && !IsFakeClient(Client))
				{
					if(HealingBallmissExp[Client] > 0)
					{
						//EXP[Client] += HealingBallmissExp[Client] / 4;
						//Cash[Client] += HealingBallmissExp[Client] / 10;
						//CPrintToChat(Client, MSG_SKILL_HB_END, HealingBallmissExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallmissExp[Client], HealingBallmissExp[Client] / 10);
						//PrintToserver("[United RPG] %s的治疗光球术结束了! 总共治疗了队友%dHP, 获得%dExp, %d$", NameInfo(Client, simple), HealingBallmissExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallmissExp[Client], HealingBallmissExp[Client] / 10);
					}
				}
				HealingBallmissExp[Client] = 0;
				IsHealingBallmissEnable[Client] = false;
				KillTimer(HealingBallmissTimer[Client]);
				HealingBallmissTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 4)
		{
			/* 停止冰之传送CD Timer */
			if(TCChargingTimer[Client] != INVALID_HANDLE)
			{
				IsTeleportToSelectEnable[Client] = false;
				KillTimer(TCChargingTimer[Client]);
				TCChargingTimer[Client] = INVALID_HANDLE;
			}
			/* 停止心灵传送CD Timer */
			if(TTChargingTimer[Client] != INVALID_HANDLE)
			{
				IsTeleportTeamEnable[Client] = false;
				KillTimer(TTChargingTimer[Client]);
				TTChargingTimer[Client] = INVALID_HANDLE;
			}
			/* 停止黑屏特效Timer */
			if(FadeBlackTimer[Client] != INVALID_HANDLE)
			{
				PerformFade(Client, 0);
				IsHolyBoltEnable[Client] = false;
				KillTimer(FadeBlackTimer[Client]);
				FadeBlackTimer[Client] = INVALID_HANDLE;
			}
			/* 停止治疗光球Timer */
			if(HealingBallTimer[Client] != INVALID_HANDLE)
			{
				if (IsValidPlayer(Client) && !IsFakeClient(Client))
				{
					if(HealingBallExp[Client] > 0)
					{
						//EXP[Client] += HealingBallExp[Client] / 4 + VIPAdd(Client, HealingBallExp[Client] / 4, 1, true);
						//Cash[Client] += HealingBallExp[Client] / 10 + VIPAdd(Client, HealingBallExp[Client] / 10, 1, false);
						//CPrintToChat(Client, MSG_SKILL_HB_END, HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client] / 4, HealingBallExp[Client] / 10);
						//PrintToserver("[United RPG] %s的治疗光球术结束了! 总共治疗了队友%dHP, 获得%dExp, %d$", NameInfo(Client, simple), HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client], HealingBallExp[Client]/10);
					}
				}
				//HealingBallExp[Client] = 0;
				IsHealingBallEnable[Client] = false;
				KillTimer(HealingBallTimer[Client]);
				HealingBallTimer[Client] = INVALID_HANDLE;
			}
			/* 停止吸引术CD Timer */
			if(TTChargingztTimer[Client] != INVALID_HANDLE)
			{
				IsTeleportTeamztEnable[Client] = false;
				KillTimer(TTChargingTimer[Client]);
				TTChargingztTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 5)
		{
			/* 停止暗夜暴雷CD Timer */
			if(SatelliteCannonmissCDTimer[Client] != INVALID_HANDLE)
			{
				IsSatelliteCannonmissReady[Client] = true;
				KillTimer(SatelliteCannonmissCDTimer[Client]);
				SatelliteCannonmissCDTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 10)
		{
			/* 停止死亡护体效果Timer */
			if(SWHTDurationTimer[Client] != INVALID_HANDLE)
			{
				IsSWHTEnable[Client] = false;
				SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);
				KillTimer(SWHTDurationTimer[Client]);
				SWHTDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 停止死亡护体CD Timer */
			if(SWHTCDTimer[Client] != INVALID_HANDLE)
			{
				IsSWHTReady[Client] = true;
				KillTimer(SWHTCDTimer[Client]);
				SWHTCDTimer[Client] = INVALID_HANDLE;
			}
			/* 停止无限能源效果Timer */
			if(WXNYDurationTimer[Client] != INVALID_HANDLE)
			{
				IsWXNYEnable[Client] = false;
				KillTimer(WXNYDurationTimer[Client]);
				WXNYDurationTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 11)
		{
			/* 停止致命闪电CD Timer */
			if(YLTJmissCDTimer[Client] != INVALID_HANDLE)
			{
				IsYLTJmissReady[Client] = true;
				KillTimer(YLTJmissCDTimer[Client]);
				YLTJmissCDTimer[Client] = INVALID_HANDLE;
			}
			/* 停止光之速效果Timer */
			if(GZSDurationTimer[Client] != INVALID_HANDLE)
			{
				IsGZSEnable[Client] = false;
				RebuildStatus(Client, false);
				KillTimer(GZSDurationTimer[Client]);
				GZSDurationTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 14)
		{
			/* 停止毒龙之光CD Timer */
			if(DSZGmissCDTimer[Client] != INVALID_HANDLE)
			{
				IsDSZGmissReady[Client] = true;
				KillTimer(DSZGmissCDTimer[Client]);
				DSZGmissCDTimer[Client] = INVALID_HANDLE;
			}
		} else if(JD[Client] == 11)
		{
			/* 停止武者之光CD Timer */
			if(WZZGmissCDTimer[Client] != INVALID_HANDLE)
			{
				IsWZZGmissReady[Client] = true;
				KillTimer(WZZGmissCDTimer[Client]);
				WZZGmissCDTimer[Client] = INVALID_HANDLE;
			}
		}else if(JD[Client] == 16)
		{
			/* 嗜血术效果Timer */
			if(PHABADurationTimer[Client] != INVALID_HANDLE)
			{
				IsPHABAEnable[Client] = false;
				RebuildStatus(Client, false);
				KillTimer(PHABADurationTimer[Client]);
				PHABADurationTimer[Client] = INVALID_HANDLE;
			}
			/* 停止CD Timer */
			if(PHFRACDTimer[Client] != INVALID_HANDLE)
			{
				IsPHFRAReady[Client] = true;
				KillTimer(PHFRACDTimer[Client]);
				PHFRACDTimer[Client] = INVALID_HANDLE;
			}
			/* 献祭关联two Timer */
			if(XJDurationTimer[Client] != INVALID_HANDLE)
			{
				IsXJEnable[Client] = false;
				KillTimer(XJDurationTimer[Client]);
				XJDurationTimer[Client] = INVALID_HANDLE;
			}
		}else if(JD[Client] == 17)
		{
			/* 停止毒龙之光CD Timer */
			if(LLLEmissCDTimer[Client] != INVALID_HANDLE)
			{
				IsLLLEmissReady[Client] = true;
				KillTimer(LLLEmissCDTimer[Client]);
				LLLEmissCDTimer[Client] = INVALID_HANDLE;
			}
	    }
		else if(JD[Client] == 18)
		{
			/* 幻影剑舞Timer */
			if(HYJWDurationTimer[Client] != INVALID_HANDLE)
			{
				IsHYJWEnable[Client] = false;
				KillTimer(HYJWDurationTimer[Client]);
				HYJWDurationTimer[Client] = INVALID_HANDLE;
			}
			/* 血之狂暴two Timer */
			if(XZKBDurationTimer[Client] != INVALID_HANDLE)
			{
				IsXZKBEnable[Client] = false;
				KillTimer(XZKBDurationTimer[Client]);
				XZKBDurationTimer[Client] = INVALID_HANDLE;
			}
	    }
	}
}

/* 初始化 */
public OnConfigsExecuted()
{
	SetPlayerLimit();
	//人数检查计时器
	CreateTimer(10.0, Timer_CheckMaxPlayer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientPutInServer(client)
{
	//by MicroLeo
	b_IsCheckPack[client] = false;
	//end
	
	decl String:user_name[MAX_NAME_LENGTH];
	if (IsValidPlayer(client, false))
	{
		GetClientName(client, user_name, sizeof(user_name));
		Format(PlayerName[client], sizeof(PlayerName), user_name);
		//近战耐久度
		SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);

		pwtimeout[client] = 0;
		if (GetConVarInt(cv_pwtimeout) > 0)
			CreateTimer(1.0, IsPWConfirm, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

		if (IsPasswordConfirm[client])
		{
			//会员日期检查
			VipIsOver(client);
			//会员补给重置
			ReSetVipProps(client);
			//医生电击器重置
			ResetDoctor(client);
			//审判者书籍重置
			ResetFHZS(client);
		}
		//bot检测
		CreateTimer(1.0, GiveBotClient, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		SetGameDifficulty();
		//准心玩家信息获取
		CreateTimer(0.5, Timer_GetAimTargetMSG, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

/* 地图开始 */
public OnMapStart()
{
	new String:map[128];
	GetCurrentMap(map, sizeof(map));
	//LogToFileEx(LogPath, "---=================================================================---");
	//LogToFileEx(LogPath, "--- 地图开始: %s ---", map);
	//LogToFileEx(LogPath, "---=================================================================---");

	InitPrecache();

	RPGSave = CreateKeyValues("United RPG Save");
	RPGRank = CreateKeyValues("United RPG Ranking");
	BuildPath(Path_SM, SavePath, 255, "data/UnitedRPGSave.txt");
	BuildPath(Path_SM, RankPath, 255, "data/UnitedRPGRanking.txt");
	FileToKeyValues(RPGSave, SavePath);
	FileToKeyValues(RPGRank, RankPath);
	/* 服务器时间日志 */
	ServerTimeLog = CreateKeyValues("Server Time Log");
	BuildPath(Path_SM, ServerTimePath, 255, "data/ServerTimeLog.txt");
	FileToKeyValues(ServerTimeLog, ServerTimePath);

	oldCommonHp = GetConVarInt(FindConVar("z_health"));

	SaveServerTimeLog();
	/* 大乐透开启 */
	if (DLT_Handle == INVALID_HANDLE && DLT_Timer <= 0)
		DaLeTou_Refresh(true);

	for (new u = 0; u <= MaxClients; u++)
	{
		pwtimeout[u] = 0;
		connectkicktime[u] = 0;
	}
	/*载入僵尸模型*/
	/*
	if (!IsModelPrecached("models/infected/boomette.mdl")) PrecacheModel("models/infected/boomette.mdl", false);
	if (!IsModelPrecached("models/infected/common_male_ceda.mdl"))	PrecacheModel("models/infected/common_male_ceda.mdl", false);
	if (!IsModelPrecached("models/infected/common_male_clown.mdl")) 	PrecacheModel("models/infected/common_male_clown.mdl", false);
	if (!IsModelPrecached("models/infected/common_male_mud.mdl")) 	PrecacheModel("models/infected/common_male_mud.mdl", false);
	if (!IsModelPrecached("models/infected/common_male_roadcrew.mdl")) 	PrecacheModel("models/infected/common_male_roadcrew.mdl", false);
	if (!IsModelPrecached("models/infected/common_male_riot.mdl")) 	PrecacheModel("models/infected/common_male_riot.mdl", false);
	if (!IsModelPrecached("models/infected/common_male_fallen_survivor.mdl")) 	PrecacheModel("models/infected/common_male_fallen_survivor.mdl", false);
	if (!IsModelPrecached("models/infected/common_male_jimmy.mdl.mdl")) 	PrecacheModel("models/infected/common_male_jimmy.mdl.mdl", false

	if (!IsModelPrecached("models/survivors/survivor_teenangst.mdl"))	PrecacheModel("models/survivors/survivor_teenangst.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_biker.mdl"))		PrecacheModel("models/survivors/survivor_biker.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_manager.mdl"))	PrecacheModel("models/survivors/survivor_manager.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_namvet.mdl"))		PrecacheModel("models/survivors/survivor_namvet.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_gambler.mdl"))	PrecacheModel("models/survivors/survivor_gambler.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_coach.mdl"))		PrecacheModel("models/survivors/survivor_coach.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_mechanic.mdl"))	PrecacheModel("models/survivors/survivor_mechanic.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_producer.mdl"))		PrecacheModel("models/survivors/survivor_producer.mdl", false);
	*/
}
/* 地图结束 */
public OnMapEnd()
{
	//LogToFileEx(LogPath, "--- 地图结束 ---");
	ResetPlayerLimit();
	CloseHandle(RPGSave);
	CloseHandle(RPGRank);
	CloseHandle(ServerTimeLog);
	if (DLT_Handle != INVALID_HANDLE)
	{
		DLT_Timer = 0.0;
		//KillTimer(DLT_Handle);
		DLT_Handle = INVALID_HANDLE;
	}
}

/* 玩家连接游戏 */
public OnClientConnected(Client)
{
	/* 读取玩家记录 */
	if(!IsFakeClient(Client))
	{
		//加载卡住踢出
		connectkicktime[Client] = 0;
		if (GetConVarInt(cv_loadtimeout) > 0)
			CreateTimer(1.0, Kick_Connect, Client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		// 初始化档案
		Initialization(Client);
		new connectnum = GetAllPlayerCount()
		// 载入档案
		
		//by MicroLeo
		if(GetConVarBool(h_ArchiveSys))
		{
			SQLiteArchiveSys_RegLogin(Client);
		}
		else
		{
			RegLogin(Client);
		}
		//end
		
		// 经验MP等级
		if(CheckExpTimer[Client] != INVALID_HANDLE)
		{
			KillTimer(CheckExpTimer[Client]);
			CheckExpTimer[Client] = INVALID_HANDLE;
		}
		CheckExpTimer[Client] = CreateTimer(1.0, PlayerLevelAndMPUp, Client, TIMER_REPEAT);

		//会员通道检查
		VipPlayerConnect(Client);

		CPrintToChatAll("玩家: \x03%N {default}正在加入游戏，当前人数\x03%d{default}人", Client, connectnum);
	}
}


public OnClientPostAdminCheck(Client)
{
	if(!IsFakeClient(Client))
	{
		new AdminId:admin = GetUserAdmin(Client);
		if(admin != INVALID_ADMIN_ID)
			IsAdmin[Client] = true;
	}
}

/* 玩家离开游戏 */
public OnClientDisconnect(Client)
{
	/* 储存玩家记录 */
	if(!IsFakeClient(Client))
	{
		SetGameDifficulty();
		////LogToFileEx(LogPath, "%s离开游戏!", NameInfo(Client, simple));
		if(StrEqual(Password[Client], "", true) || IsPasswordConfirm[Client])
		{
			//by MicroLeo
			if(GetConVarBool(h_ArchiveSys))
			{
				SQLiteArchiveSys_ClientSaveToFileSave(Client, true);
			}
			else
			{
				ClientSaveToFileSave(Client);
			}
			//end
		}

		//清除玩家资料
		Initialization(Client);

		CPrintToChatAll("玩家: \x03%N {default}已经离开了游戏.", Client);
	}
}

//RPG离线KV设置
public Action:Command_RPGKV(Client, args)
{
	if (args < 2)
	{
		ReplyToCommand(Client, "[RPGKv]sm_rpgkv [Name] [Key] [Value] [type]");
		return Plugin_Handled;
	}

	new String:name[32];
	new String:key[64];
	new String:s_value[64];
	new String:type[64];
	new g_value;
	new value;
	new target;
	GetCmdArg(1, name, sizeof(name));
	GetCmdArg(2, key, sizeof(key));

	/* 取代玩家姓名中会导致错误的符号 */
	ReplaceString(name, sizeof(name), "\034", "{DQM}");//DQM Double quotation mark
	ReplaceString(name, sizeof(name), "\'", "{SQM}");//SQM Single quotation mark
	ReplaceString(name, sizeof(name), "/*", "{SST}");//SST Slash Star
	ReplaceString(name, sizeof(name), "*/", "{STS}");//STS Star Slash
	ReplaceString(name, sizeof(name), "//", "{DSL}");//DSL Double Slash

	if(!KvJumpToKey(RPGSave, name, false))
	{
		ReplyToCommand(Client, "[RPGKv]没有发现该键!");
		KvGoBack(RPGSave);
		return Plugin_Handled;
	}

	target = GetClientForName(name);

	if (IsValidPlayer(target) && args >= 3 && target != Client)
	{
		KickClient(target, "管理员正在对你数据进行操作,请稍后再进!");
		ReplyToCommand(Client, "[RPGKv]发现操作对象在游戏中,已经踢出游戏,请重新操作!");
		KvGoBack(RPGSave);
		return Plugin_Handled;
	}

	value = KvGetNum(RPGSave, key, 0);

	if (args >= 3)
	{
		GetCmdArg(3, s_value, sizeof(s_value));
		g_value = StringToInt(s_value);

		if (args >= 4)
		{
			GetCmdArg(4, type, sizeof(type));
			if (StrEqual(type, "+", false))
				value = value + g_value;
			else if (StrEqual(type, "-", false))
				value = value - g_value;
			else if (StrEqual(type, "*", false))
				value = value * g_value;
			else if (StrEqual(type, "/", false))
				value = value / g_value;
		}
		else
			value = g_value;

		KvSetNum(RPGSave, key, value);
		ReplyToCommand(Client, "[设置键值]Name: [%s] Key: [%s] Value: [%d]", name, key, value);
	}
	else if (args == 2)
	{
		if (StrEqual(key, "VIPTL", false))
			ReplyToCommand(Client, "{olive}[获取键值] {green}%s \x03Vip剩余天数:{green}[%d]", name, value - GetToday());
		ReplyToCommand(Client, "[获取键值]Name: [%s] Key: [%s] Value: [%d]", name, key, value);
	}

	KvGoBack(RPGSave);

	if (IsValidPlayer(target) && args >= 3)
	{
		//by MicroLeo
		if(GetConVarBool(h_ArchiveSys))
		{
			SQLiteArchiveSys_ClientSaveToFileLoad(target);
			ReplyToCommand(Client, "{olive}[设置键值] \x4%N \x3在游戏中,保存键值成功并读取存档同步数据.", target);
		}
		else
		{
			ClientSaveToFileLoad(target);
			ReplyToCommand(Client, "{olive}[设置键值] \x4%N \x3在游戏中,保存键值成功并读取存档同步数据.", target);
		}
		//end
	}
	return Plugin_Handled;
}

//RPG删号
public Action:Command_RPGDEL(Client, args)
{
	if (args < 1)
	{
		ReplyToCommand(Client, "[RPG]sm_rpgdel [Name]");
		return Plugin_Handled;
	}

	new String:name[32];
	new String:targetip[32];
	new target;
	GetCmdArg(1, name, sizeof(name));

	if(!KvJumpToKey(RPGSave, name, false))
	{
		ReplyToCommand(Client, "[RPG]没有发现该键!");
		KvGoBack(RPGSave);
		return Plugin_Handled;
	}
	else
		KvDeleteThis(RPGSave);

	target = GetClientForName(name);
	if (IsValidPlayer(target, false) && target != Client)
	{
		GetClientIP(target, targetip, sizeof(targetip));
		PrintToChatAll("{red}[封禁]{olive}由于 {green}%N {olive}使用非法作弊或违法服务器规定,已经被服务器{green}删档{olive}并且{green}永久封禁!", target);
		BanIdentity(targetip, 0, BANFLAG_IP, "违规作弊");
		if (IsValidPlayer(target, false))
			KickClient(target, "由于你使用作弊器或在本服务器违规,你将被删除所有档案和踢出!");
		ReplyToCommand(Client, "[RPG]发现操作对象在游戏中,已经踢出游戏并删除存档!");
	}
	else
		PrintToChatAll("{blue}[封禁]{olive}由于 {green}%s {olive}使用非法作弊或违法服务器规定,已经被服务器{green}删档{olive}并且{green}永久封禁!", name), ReplyToCommand(Client, "[RPG]操作对象不在游戏中,直接删除存档!");

	KvRewind(RPGSave);
	return Plugin_Handled;
}

//RPG名字修改
public Action:Command_RPGName(Client, args)
{
	if (args < 2)
	{
		ReplyToCommand(Client, "[RPG]sm_setname [Name] [NewName]");
		return Plugin_Handled;
	}

	new String:name[32];
	new String:newname[32];
	new String:temp[32];
	new target;

	GetCmdArg(1, name, sizeof(name));
	GetCmdArg(2, newname, sizeof(newname));

	/* 取代玩家姓名中会导致错误的符号 */
	ReplaceString(name, sizeof(name), "\034", "{DQM}");//DQM Double quotation mark
	ReplaceString(name, sizeof(name), "\'", "{SQM}");//SQM Single quotation mark
	ReplaceString(name, sizeof(name), "/*", "{SST}");//SST Slash Star
	ReplaceString(name, sizeof(name), "*/", "{STS}");//STS Star Slash
	ReplaceString(name, sizeof(name), "//", "{DSL}");//DSL Double Slash

	if(!KvJumpToKey(RPGSave, name, false))
	{
		ReplyToCommand(Client, "[RPG]没有该名字的玩家!");
		KvGoBack(RPGSave);
	}
	else
	{
		if (StrEqual(newname, "", false))
		{
			ReplyToCommand(Client, "[RPG]新名字格式不对,不能使用空白名称.");
			KvGoBack(RPGSave);
			return Plugin_Handled;
		}

		target = GetClientForName(name);
		if (IsValidPlayer(target))
		{
			KickClient(target, "管理员正在对你数据进行操作,请稍后再进!");
			ReplyToCommand(Client, "[RPGKv]发现操作对象在游戏中,已经踢出游戏,请重新操作!");
			KvGoBack(RPGSave);
			return Plugin_Handled;
		}

		/* 取代玩家姓名中会导致错误的符号 */
		ReplaceString(newname, sizeof(newname), "\034", "{DQM}");//DQM Double quotation mark
		ReplaceString(newname, sizeof(newname), "\'", "{SQM}");//SQM Single quotation mark
		ReplaceString(newname, sizeof(newname), "/*", "{SST}");//SST Slash Star
		ReplaceString(newname, sizeof(newname), "*/", "{STS}");//STS Star Slash
		ReplaceString(newname, sizeof(newname), "//", "{DSL}");//DSL Double Slash

		KvSetSectionName(RPGSave, newname);
		KvGetSectionName(RPGSave, temp, sizeof(temp));
		KvGoBack(RPGSave);
		KvDeleteKey(RPGSave, name);
		ReplyToCommand(Client, "[RPG]名字已经从 %s 修改为 %s .", name, temp);
	}

	return Plugin_Handled;
}

//克隆动画
public Action:Command_Clone(Client, args)
{
	new String:s_type[12], i_type;
	GetCmdArg(1, s_type, sizeof(s_type));
	if (!StrEqual(s_type, "ammo", false))
	{
		i_type = StringToInt(s_type);
		CreateClone(Client, i_type);
	}
	else
	{
		new ent = GetEntPropEnt(Client, Prop_Send, "m_hActiveWeapon");
		if (IsValidEntity(ent) && IsValidEdict(ent))
			SetEntProp(ent, Prop_Send, "m_iClip1", 250);
	}
	return Plugin_Handled;
}

//RPG玩家洗点
public Action:Command_RPGReset(Client, args)
{
	if (args < 1)
	{
		ReplyToCommand(Client, "[RPG]sm_rpgreset [Name]");
		return Plugin_Handled;
	}

	new String:name[64];
	new target;

	GetCmdArg(1, name, sizeof(name));
	target = GetClientForName(name);
	if(IsValidPlayer(target, false))
	{
		ClinetResetStatus(target, Admin);
		ReplyToCommand(Client, "[洗点]玩家 %N 已经被管理员洗点.", target);
	}
	else
		ReplyToCommand(Client, "[洗点]无效的玩家目标.", target);

	return Plugin_Handled;
}

//RPG属性全满
public Action:Command_RPGGM(Client, args)
{
	if (IsValidPlayer(Client, false))
	{
		Str[Client] = 1000;
		Agi[Client] = 500;
		Health[Client] = 1000;
		Endurance[Client] = 1000;
		Intelligence[Client] = 500;
		SkillPoint[Client] = 500;
		Crits[Client] = 500;
		CritMin[Client] = 500;
		CritMax[Client] = 500;
	}
}

//增加bot
public Action:Command_AddBot(Client, args)
{
	if (!IsValidPlayer(Client) || IsFakeClient(Client))
		return Plugin_Handled;

	return Plugin_Handled;
}

//设置时间流速
public Action:Command_SetTime(Client, args)
{
	if (!IsValidPlayer(Client) || IsFakeClient(Client))
		return Plugin_Handled;

	decl String:s_speed[16], String:s_time[16], Float:f_speed, Float:f_time;
	if (args < 1)
		ChangeGameTimeSpeed();
	else
	{
		GetCmdArg(1, s_speed, sizeof(s_speed));
		GetCmdArg(2, s_time, sizeof(s_time));
		f_speed = StringToFloat(s_speed);
		f_time = StringToFloat(s_time);
		if (f_time <= 0)
			f_time = 5.0;
		if (f_speed > 0)
			ChangeGameTimeSpeed(f_speed, f_time);
	}

	return Plugin_Handled;
}

/* 服务器更新踢人 */
public Action:Command_ServerUpdata(args)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i))
		{
			KickClient(i, "服务器正在进行维护,请稍后再进!");
			if (cv_MaxPlayer != INVALID_HANDLE)
				SetConVarInt(cv_MaxPlayer, 0);
		}
	}
}

//快捷指令_设置VIP
public Action:Command_SetVIP(Client, args)
{

	if (args <= 0)
	{
		Menu_SetVIPMenu_Select(Client);
		ReplyToCommand(Client, "sm_setvip [玩家名字] [VIP类型(0 = 普通会员 1 = 白银VIP 2 = 黄金VIP 3= 水晶VIP3 4 = 至尊VIP4 5 = 创世会员 6 = 末日会员)] [时间] [是否首次]");
		return Plugin_Handled;
	}
	else if (args >= 2)
	{
		new String:name[64];
		new String:type[64];
		new String:first[64];
		new String:day[64];
		new g_day;
		new g_type;
		new g_cash;
		new target;
		new year = GetThisYear();
		new maxday = GetThisYearMaxDay();
		GetCmdArg(1, name, sizeof(name));
		GetCmdArg(2, type, sizeof(type));
		GetCmdArg(3, day, sizeof(day));
		g_type = StringToInt(type);
		new today = GetToday();
		new time = StringToInt(day);
		if (args >= 4)
			GetCmdArg(4, first, sizeof(first));

		target = GetClientForName(name);

		if (IsValidPlayer(target) && args > 2)
		{
			if (StrEqual(first, "f", false))
				SetVip(Client, target, g_type, time, true);
			else
				SetVip(Client, target, g_type, time, false);
			return Plugin_Handled;
		}

		if (!IsValidPlayer(target))
		{
			if(!KvJumpToKey(RPGSave, name, false))
			{
				ReplyToCommand(Client, "[RPGVIP]没有发现该玩家!");
				KvGoBack(RPGSave);
				return Plugin_Handled;
			}

			if (today + time <= maxday)
			{
				VIPYEAR[target] = year;
				VIPTL[target] = today + time;
			}
			else
			{
				new moreday = time - maxday;
				new moreyear = year + 1;
				new nextyearmaxday = GetThisYearMaxDay(moreyear);

				while (moreday - nextyearmaxday > 0)
				{
					moreday = moreday - nextyearmaxday;
					moreyear += 1;
					nextyearmaxday = GetThisYearMaxDay(moreyear);
				}

				if (moreday > 0 && moreyear > 0)
				{
					KvSetNum(RPGSave, "VIP", g_type);
					KvSetNum(RPGSave, "VIPTL", moreday);
					KvSetNum(RPGSave, "VIPYEAR", moreyear);
					VIPYEAR[target] = moreyear;
					VIPTL[target] = moreday;
					if (StrEqual(first, "f", false))
					{
						g_cash = KvGetNum(RPGSave, "CASH", 0) + 50000;
						KvSetNum(RPGSave, "CASH", g_cash);
					}
				}
			}
		}
		else
		{
			if (IsPasswordConfirm[target])
			{
				if (StrEqual(first, "f", false))
					SetVipTimeLimit(target, g_type, time, true);
				else
					SetVipTimeLimit(target, g_type, time);
			}
		}

		if (g_type == 0)
			ReplyToCommand(Client, "[VIP设置] %s 已经被设置为 普通VIP , %d年 期限 %d 天 , 当前游戏币 %d", name, year, g_day - GetToday(), g_cash);
		else if (g_type == 1)
			ReplyToCommand(Client, "[VIP设置] %s 已经被设置为 白银VIP1 , %d年 期限 %d 天 , 当前游戏币 %d", name, year, g_day - GetToday(), g_cash);
		else if (g_type == 2)
			ReplyToCommand(Client, "[VIP设置] %s 已经被设置为 黄金VIP2 , %d年 期限 %d 天 , 当前游戏币 %d", name, year, g_day - GetToday(), g_cash);
		else if (g_type == 3)
			ReplyToCommand(Client, "[VIP设置] %s 已经被设置为 水晶VIP3 , %d年 期限 %d 天 , 当前游戏币 %d", name, year, g_day - GetToday(), g_cash);
		else if (g_type == 4)
			ReplyToCommand(Client, "[VIP设置] %s 已经被设置为 至尊VIP4 , %d年 期限 %d 天 , 当前游戏币 %d", name, year, g_day - GetToday(), g_cash);
		else if (g_type == 5)
			ReplyToCommand(Client, "[VIP设置] %s 已经被设置为 创世VIP5 , %d年 期限 %d 天 , 当前游戏币 %d", name, year, g_day - GetToday(), g_cash);
		else if (g_type == 6)
			ReplyToCommand(Client, "[VIP设置] %s 已经被设置为 末日VIP6 , %d年 期限 %d 天 , 当前游戏币 %d", name, year, g_day - GetToday(), g_cash);

		KvGoBack(RPGSave);
	}
	return Plugin_Handled;
}

/* 玩家发起投票 */
public Action:Callvote_Handler(client, args)
{
	decl String:voteName[32];
	decl String:initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));
	GetCmdArg(1,voteName,sizeof(voteName));

	PrintToChatAll("\x05[投票] \x05%s\x03发起了%s投票", initiatorName, voteName);
	////LogToFileEx(LogPath, "[投票] %s发起了%s投票", initiatorName, voteName);
	return Plugin_Continue;
}

/* 聊天框全频显示等级信息 */
public Action:Command_Say(Client, args)
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if (args < 1)
		return Plugin_Continue;

	decl String:sText[192];
	GetCmdArg(1, sText, sizeof(sText));

	if (Client == 0 || (IsChatTrigger() && sText[0] == '/'))
		return Plugin_Continue;

	if(StrContains(sText, "!rpgpw") == 0 || StrContains(sText, "!rpgresetpw") == 0 || StrContains(sText, "!sm_rpgpw") == 0 || StrContains(sText, "!sm_rpgresetpw") == 0)
		return Plugin_Handled;

	new mode = GetConVarInt(ShowMode);

	if (GetClientTeam(Client) == 2)
	{
		if (mode == 0)
		{
			if (VIP[Client] <= 0)
			{
				CPrintToChatAll("{blue}%N{default}: %s", Client, sText);
			}
			if (VIP[Client] == 1)
			{
				CPrintToChatAll("[白银VIP]%N: \x02%s", Client, sText);
			}
			if (VIP[Client] == 2)
			{
				CPrintToChatAll("[黄金VIP]%N: \x03%s", Client, sText);
			}
			if (VIP[Client] == 3)
			{
				CPrintToChatAll("[水晶VIP]%N: {blue}%s", Client, sText);
			}
			if (VIP[Client] == 4)
			{
				CPrintToChatAll("[至尊VIP]%N: {blue}%s", Client, sText);
			}
			if (VIP[Client] == 5)
			{
				CPrintToChatAll("[创世VIP]%N: {blue}%s", Client, sText);
			}
			if (VIP[Client] == 6)
			{
				CPrintToChatAll("[末日VIP]%N: {blue}%s", Client, sText);
			}
		}
		if (mode == 1)
		{
			if (VIP[Client] <= 0)
			{
				CPrintToChatAll("%s: %s", NameInfo(Client, colored), sText);
			}
			if (VIP[Client] == 1)
			{
				CPrintToChatAll("%s: %s", NameInfo(Client, colored), sText);
			}
			if (VIP[Client] == 2)
			{
				CPrintToChatAll("%s: %s", NameInfo(Client, colored), sText);
			}
			if (VIP[Client] == 3)
			{
				CPrintToChatAll("%s: %s", NameInfo(Client, colored), sText);
			}
			if (VIP[Client] == 4)
			{
				CPrintToChatAll("%s: %s", NameInfo(Client, colored), sText);
			}
			if (VIP[Client] == 5)
			{
				CPrintToChatAll("%s: %s", NameInfo(Client, colored), sText);
			}
			if (VIP[Client] == 6)
			{
				CPrintToChatAll("%s: %s", NameInfo(Client, colored), sText);
			}
		}
		//LogToFileEx(LogPath, "[全频][幸存者]%s: %s", NameInfo(Client, simple), sText);
	}
	else if (GetClientTeam(Client) == 3)
	{
		if (mode == 0) CPrintToChatAll("{red}%N{default}: %s", Client, sText);
		if (mode == 1) CPrintToChatAll("%s: %s", NameInfo(Client, colored), sText);
		//LogToFileEx(LogPath, "[全频][特殊感染者]%s: %s", NameInfo(Client, simple), sText);
	}
	else if (GetClientTeam(Client) == 1)
	{
		if (mode == 0) CPrintToChatAll("{default}%N: %s", Client, sText);
		if (mode == 1) CPrintToChatAll("%s: %s", NameInfo(Client, colored), sText);
		//LogToFileEx(LogPath, "[全频][旁观者]%s: %s", NameInfo(Client, simple), sText);
	}
	return Plugin_Handled;
}

/* 聊天框队内显示等级信息 */
public Action:Command_SayTeam(Client, args)
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if (args < 1)
		return Plugin_Continue;

	decl String:sText[192];
	GetCmdArg(1, sText, sizeof(sText));

	if (Client == 0 || (IsChatTrigger() && sText[0] == '/'))
		return Plugin_Continue;

	if(StrContains(sText, "!rpgpw") == 0 || StrContains(sText, "!rpgresetpw") == 0 || StrContains(sText, "!sm_rpgpw") == 0 || StrContains(sText, "!sm_rpgresetpw") == 0)
		return Plugin_Handled;

	new mode = GetConVarInt(ShowMode);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		if (GetClientTeam(Client) == 2)
		{
			if (GetClientTeam(i) != 2) continue;
			if (mode == 0) CPrintToChat(i, "{default}（幸存者）{blue}%N{default}: %s", Client, sText);
			if (mode == 1) CPrintToChat(i, "{default}（幸存者）%s: %s", NameInfo(Client, colored), sText);
		}
		else if (GetClientTeam(Client) == 1)
		{
			if (GetClientTeam(i) != 1) continue;
			if (mode == 0) CPrintToChat(i, "{default}（旁观者） %N: %s", Client, sText);
			if (mode == 1) CPrintToChat(i, "{default}（旁观者）%s: %s", NameInfo(Client, colored), sText);
		}
	}
	//if (IsClientInGame(Client) && GetClientTeam(Client) == 2)
		//LogToFileEx(LogPath, "[队频][幸存者]%s: %s", NameInfo(Client, simple), sText);
	//else if (IsClientInGame(Client) && GetClientTeam(Client) == 3)
		//LogToFileEx(LogPath, "[队频][特殊感染者]%s: %s", NameInfo(Client, simple), sText);
	//else if (IsClientInGame(Client) && GetClientTeam(Client) == 1)
		//LogToFileEx(LogPath, "[队频][旁观者]%s: %s", NameInfo(Client, simple), sText);
	return Plugin_Handled;
}

/* 输入密码回调 */
public Action:EnterPassword(Client, args)
{
	decl String:arg[PasswordLength];

	/*
	decl String:s_Name[MAX_NAME_LENGTH];
	SafeGetClientName(Client, s_Name, sizeof(s_Name));

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i, false))
		{
			if (StrEqual(s_Name, PlayerName[i]))
			{
				KickClient(Client, "由于你试图在游戏中盗取他人帐号,已经被服务器踢出!");
				return Plugin_Handled;
			}
		}
	}
	*/

	if(IsPasswordConfirm[Client])
	{
		CPrintToChat(Client, MSG_ENTERPASSWORD_ALREADYCONFIRM);
		return Plugin_Handled;
	}
	else if (args < 1)
	{
		ReplyToCommand(Client, "[SM] 用法:sm_rpgpw 密码 或 sm_pw 密码");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg, PasswordLength);

	if(StrEqual(arg, "", true))
	{
		CPrintToChat(Client, MSG_ENTERPASSWORD_BLIND);
		return Plugin_Handled;
	}

	VipIsOver(Client);
	ReSetVipProps(Client);
	// 注册或登陆
	
	//by MicroLeo
	if(GetConVarBool(h_ArchiveSys))
	{
		if(SQLiteArchiveSys_RegLogin(Client, arg))
		{
			RebuildStatus(Client, true);
			CPrintToChat(Client, MSG_ENTERPASSWORD_CORRECT);
			CPrintToChat(Client, MSG_PASSWORD_EXPLAIN);

			if (GetClientTeam(Client) != 2)
				ChangeTeam(Client, 2);

			if(CheckExpTimer[Client] == INVALID_HANDLE)
				CheckExpTimer[Client] = CreateTimer(1.0, PlayerLevelAndMPUp, Client, TIMER_REPEAT);

			SetVipGrow(Client);
			
			/*过关自动登录*/
			new String:IPAddress[32];
			new ip_index = -1;
			GetClientIP(Client, IPAddress, sizeof(IPAddress));
			if(strlen(IPAddress))
			{
				ip_index = FindStringInArray(AutoLoginPack, IPAddress);
				if(ip_index != -1)
				{
					SetArrayString(AutoLoginPack, ip_index+1, Password[Client]);
				}
				else
				{
					PushArrayString(AutoLoginPack, IPAddress);
					PushArrayString(AutoLoginPack, Password[Client]);
				}
			}
		} 
		else 
			CPrintToChat(Client, MSG_PASSWORD_INCORRECT);

	}
	else
	{
		if(RegLogin(Client, arg))
		{
			RebuildStatus(Client, true);
			CPrintToChat(Client, MSG_ENTERPASSWORD_CORRECT);
			CPrintToChat(Client, MSG_PASSWORD_EXPLAIN);

			if (GetClientTeam(Client) != 2)
				ChangeTeam(Client, 2);

			if(CheckExpTimer[Client] == INVALID_HANDLE)
				CheckExpTimer[Client] = CreateTimer(1.0, PlayerLevelAndMPUp, Client, TIMER_REPEAT);

			SetVipGrow(Client);
		} 
		else 
			CPrintToChat(Client, MSG_PASSWORD_INCORRECT);
	}
	//end


	return Plugin_Handled;
}

/* 更改密码回调 */
public Action:ResetPassword(Client, args)
{
	if(!IsPasswordConfirm[Client])
	{
		CPrintToChat(Client, MSG_PASSWORD_NOTCONFIRM);
		return Plugin_Handled;
	}
	else if (args < 2)
	{
		ReplyToCommand(Client, "[SM] 用法:!sm_rpgresetpw 原密码 新密码");
		return Plugin_Handled;
	}

	if(StrEqual(Password[Client], "", true))
	{
		CPrintToChat(Client, MSG_PASSWORD_NOTACTIVATED), CPrintToChat(Client, MSG_PASSWORD_EXPLAIN);
	}
	else
	{
		decl String:arg[PasswordLength];
		decl String:arg2[PasswordLength];
		GetCmdArg(1, arg, PasswordLength);
		GetCmdArg(2, arg2, PasswordLength);

		if(!StrEqual(arg, Password[Client], true))
			CPrintToChat(Client, MSG_PASSWORD_INCORRECT);
		else if(StrEqual(arg, Password[Client], true))
		{
			strcopy(Password[Client], PasswordLength, arg2);
			
			//by MicroLeo
			if(GetConVarBool(h_ArchiveSys))
			{
				SQLiteArchiveSys_ClientSaveToFileSave(Client,false);
			}
			else
			{
				ClientSaveToFileSave(Client);
			}
			//end
			
			ClientCommand(Client, "setinfo unitedrpg %s", Password[Client]);
			CPrintToChat(Client, MSG_RESETPASSWORD_RESETED);
		}
	}

	return Plugin_Handled;
}

/* 自动绑定 */
public Action:Showbind(Handle:timer, any:Client)
{
	KillTimer(timer);
	if (IsValidPlayer(Client)) MenuFunc_BindKeys(Client);
	return Plugin_Handled;
}

/* 升级和回复MP代码 */
public Action:PlayerLevelAndMPUp(Handle:timer, any:target)
{
	if(IsClientInGame(target))
	{
		if(!IsPasswordConfirm[target])
		{
			PasswordRemindTime[target] +=1;
			if(PasswordRemindTime[target] >= PasswordRemindSecond)
			{
				PasswordRemindTime[target] = 0;
				if(StrEqual(Password[target], "", true))
				{
					CPrintToChat(target, MSG_PASSWORD_NOTACTIVATED);
					CPrintToChat(target, MSG_PASSWORD_EXPLAIN);
				} 
				else
				{
					//by MicroLeo
					/*过关自动登录*/
					if(!IsFakeClient(target) && !b_IsCheckPack[target])
					{
						new String:IPAddress[32];
						new ip_index = -1;
						GetClientIP(target, IPAddress, sizeof(IPAddress));
						if(strlen(IPAddress))
						{
							ip_index = FindStringInArray(AutoLoginPack, IPAddress)
							if(ip_index != -1)
							{
								new String:_password[17];
								new String:_command[32];
								GetArrayString(AutoLoginPack, ip_index+1, _password, sizeof(_password));
								Format(_command,sizeof(_command),"sm_pw %s",_password);
								ClientCommand(target, _command);
							}
							else
							{
								CPrintToChat(target, MSG_PASSWORD_NOTCONFIRM);
								CPrintToChat(target, MSG_PASSWORD_EXPLAIN);
							}
						}
						b_IsCheckPack[target] = true;
					}
					else
					{
						CPrintToChat(target, MSG_PASSWORD_NOTCONFIRM);
						CPrintToChat(target, MSG_PASSWORD_EXPLAIN);
					}
					//end
				}
			}
		}
		if(EXP[target] >= GetConVarInt(LvUpExpRate)*(Lv[target]+1))
		{
			new limitlv = GetConVarInt(NewLifeLv) + NewLifeCount[target] * GetConVarInt(NewLifeLv) / 4;
			if (Lv[target] >= limitlv)
			{
				if (NewLifeCount[target] >= 24)
					CPrintToChat(target, "\x05你的等级转生已经达到上限\x03%d,\x05无法在提升!", limitlv);
				else
					CPrintToChat(target, "\x05你的等级已经达到上限\x03%d,请转生后再继续升级,否则你将无法在继续升级!", limitlv);
				return Plugin_Continue;
			}
			EXP[target] -= GetConVarInt(LvUpExpRate)*(Lv[target]+1);
			Lv[target] += 1;
			StatusPoint[target] += GetConVarInt(LvUpSP);
			SkillPoint[target] += GetConVarInt(LvUpKSP);
			Cash[target] += GetConVarInt(LvUpCash);
			CPrintToChat(target, MSG_LEVEL_UP_1, Lv[target], GetConVarInt(LvUpSP), GetConVarInt(LvUpKSP), GetConVarInt(LvUpCash));
			CPrintToChat(target, MSG_LEVEL_UP_2);
			//玩家大于20级去掉新手套装
			if(PLAYER_LV[target] > 20){
				new zbtime = GetZBItemTime(target, ITZB_XSZB);
				if(zbtime > 0){
					PlayerItem[target][ITEM_ZB][ITZB_XSZB] = 0;
					CreateTimer(0.1, StatusUp, target);
				}
			}
			//非VIP玩家升级后如果金币小于1w 给于2000补足
			if (VIP[target] <= 0 && PLAYER_LV[target] <= 80 && Cash[target] < 10000){
				Cash[target] = 20000;
			}
			if (Lv[target] == 10 || Lv[target] == 20 || Lv[target] == 30 || Lv[target] == 40 || Lv[target] == 50 || Lv[target] == 60 || Lv[target] == 70 || Lv[target] == 80 || Lv[target] == 90 || Lv[target] == 100)
			{
				if (LibaoLv[target] >= Lv[target])
				{
					CPrintToChat(target, "\x05【系统】您的升级礼包已经获取过了!");
				}
				else
				{
					Libao[target]++;
					LibaoLv[target]=Lv[target];
					CPrintToChat(target, "\x05【系统】您获取了\x03%d\x05个升级礼包，请赶快领取!", Libao[target]);
				}
			}
			/* 师徒系统同时在线福利 */
			decl targets,yxbCash;
			targets = GetClientForName(shifu[target]);//获取师父ID
			if (IsValidPlayer(targets) && Lv[target] <= 100 && NewLifeCount[target] == 0)
			{
				yxbCash += Lv[target] * 50;// * 200 是100万
				Cash[targets] +=1;
				CPrintToChat(target, "{olive}[师徒]\x3你升到了\x4%d级\x3你师父\x4%s\x3获得\x4%d$游戏币!", Lv[target],shifu[target],1);
				CPrintToChat(targets, "{olive}[师徒]\x3你徒弟升到了\x4%d级\x3你身为师父获得了\x4%d$游戏币!", Lv[target],1);
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && i != target)
				{
					if(!IsFakeClient(i))	CPrintToChat(i,"\x05%N\x03已升级至\x05%d\x03!", target, Lv[target]);
				}
			}

			AttachParticle(target, PARTICLE_SPAWN, 3.0);
			//LogToFileEx(LogPath, "%N已升级至%d!", target, Lv[target]);
			/* 储存玩家记录 */
			/* 储存玩家记录 */
			if(StrEqual(Password[target], "", true) || IsPasswordConfirm[target])
			{
				//by MicroLeo
				if(GetConVarBool(h_ArchiveSys))
				{
					SQLiteArchiveSys_ClientSaveToFileSave(target,false);
				}
				else
				{
					ClientSaveToFileSave(target);
				}
				//end
			}
		}

		if(GetClientTeam(target) != 1){
			if(MP[target] + IntelligenceEffect_IMP[target] > MaxMP[target]) MP[target] = MaxMP[target];
			else MP[target] += IntelligenceEffect_IMP[target];
		}
		/* 获取所观察的玩家信息 */
		if(!IsPlayerAlive(target))
			GetObserverTargetInfo(target);
		return Plugin_Continue;
	}
	return Plugin_Continue;
}


/************************************************************************
*	Event事件Start
************************************************************************/

/* 玩家第一次出现在游戏 */
public Action:Event_PlayerFirstSpawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidPlayer(target, false))
	{
		//PrintToserver("[United RPG] %s在这回合第一次在游戏重生!", NameInfo(target, simple));
		CPrintToChat(target, MSG_VERSION, PLUGIN_VERSION);
		if(IsPasswordConfirm[target])
			CPrintToChat(target, MSG_PlayerInfo, Lv[target], Cash[target], Str[target], Agi[target], Health[target], Endurance[target], Intelligence[target]);
		CPrintToChat(target, MSG_WELCOME1, target);
		CPrintToChat(target, MSG_WELCOME2);
		CPrintToChat(target, MSG_WELCOME3);
		CPrintToChat(target, MSG_WELCOME4);
		FakeClientCommand(target,"rpg");
		Menu_GameAnnouncement(target);
	}
	return Plugin_Continue;
}

/* 玩家出现在游戏/重生 */
public Action:Event_PlayerSpawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new target = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsFakeClient(target))
	{
		if (IsValidPlayer(target))
			CreateTimer(0.1, StatusUp, target);

		SetVipGrow(target);
		if(Lv[target] >= 0)
		{
			if(GetClientTeam(target) == 2)
			{
				RebuildStatus(target, true);
				//CPrintToChatAll("玩家重生:ISFULLHP=true");
			}
		}
		robot[target]=0;
		Menu_GameAnnouncement(target);
		if (GetClientTeam(target) == 2 && CheckPlayerBW(target))
			CreateTimer(6.0, Timer_GivePlayerBW, target, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

/* BOT人物替换 */
public Action:Event_BotPlayerReplace(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "player"));

	if(Lv[player] > 0)
	{
		if(GetClientTeam(player) == 2)
		{
			RebuildStatus(player, true);
			//CPrintToChatAll("BOT任务替换 ISFULLHP=true");
		}
		else if(GetClientTeam(player) == 3)
		{
			new iclass = GetEntProp(player, Prop_Send, "m_zombieClass");
			if(iclass != CLASS_TANK)
				RebuildStatus(player, true);
		}
	}
	else if(Lv[player] == 0)
	{
		if(GetClientTeam(player) == 2)
		{
			SetEntProp(player, Prop_Data, "m_iMaxHealth", 100);
			SetEntProp(player, Prop_Data, "m_iHealth", 100);
		}
	}
	robot[player]=0;
	return Plugin_Continue;
}


/* 玩家更改名字*/
public Action:Event_PlayerChangename(Handle:event, String:event_name[], bool:dontBroadcast)
{
	decl String:newname[256];
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "newname", newname, sizeof(newname));

	//if (!StrEqual(newname, PlayerName[target]))
	//	ClientCommand(target, "setinfo name \"%s\"", PlayerName[target]);
	//else
	KickClient(target, "由于你在服务器改名,试图盗取或破坏他人帐号,服务器已经将你踢出!");

	CPrintToChat(target, "\x03服务器不允许在游戏中改名!");
	return Plugin_Handled;
}

/* 玩家转换队伍 */
public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client_id = GetEventInt(event, "userid");
	new Client = GetClientOfUserId(Client_id);
	new oldteam = GetEventInt(event, "oldteam");
	new newteam = GetEventInt(event, "team");
	new bool:disconnect = GetEventBool(event, "disconnect");
	if (IsValidPlayer(Client) && !disconnect && oldteam != 0)
	{
		KillAllClientSkillTimer(Client);
		if(!IsFakeClient(Client))
		{
			MP[Client] = 0;
			FakeClientCommand(Client,"rpg");

			//PrintToserver("[United RPG] %s由Team %d转去Team %d!", NameInfo(Client, simple), oldteam, newteam);
			if (newteam == 1)
			{
				if (VIP[Client] > 0)
					PerformGlow(Client, 0, 0);
				KickLookOnPlayer[Client] = 0;
				CreateTimer(1.0, Timer_KickLookOnPlayer, Client, TIMER_REPEAT);
				VipPlayerConnect(Client);
			}
		}

		if (!IsFakeClient(Client))
		{
			if (oldteam == 1)
			{
				if (newteam == 2)
					CPrintToChatAll("玩家: \x03%N {default}从 {olive}旁观者 {default}加入到了 {olive}幸存者", Client);
				else if (newteam == 3)
					CPrintToChatAll("玩家: \x03%N {default}从 {olive}旁观者 {default}加入到了 {olive}感染者", Client);
			}
			else if (oldteam == 2)
			{
				if (newteam == 1)
					CPrintToChatAll("玩家: \x03%N {default}从 {olive}幸存者 {default}加入到了 {olive}旁观者", Client);
			}
		}
	}

	return Plugin_Continue;
}


/* 回合开始 */
public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	InitData();
	Vip_VoteReSet();
	ResetMeleeLasting();
	if (Handle_BotTimer != INVALID_HANDLE)
	{
		KillTimer(Handle_BotTimer);
		Handle_BotTimer = INVALID_HANDLE;
	}

	Handle_BotTimer = CreateTimer(5.0, RoundStartKickAllBot, _, TIMER_REPEAT);
	//坦克数量重置
	RoundTankLimit = 10;
	RoundTankNum = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		//VIP到期检测
		VipIsOver(i);
		//医生防刷名字重置
		Format(DoctorName[i], sizeof(DoctorName), "");
		ResetDoctor(i);
		//审判者防刷名字重置
		Format(SPZName[i], sizeof(SPZName), "");
		ResetFHZS(i);
		//玩家名字清理
		Format(BotCheck[i], sizeof(BotCheck[]), "");
		if(robot[i] > 0)
			Release(i, false);
		//VIP补给防刷重置
		Format(VipName[i], sizeof(VipName), "");
		ReSetVipProps(i);
		//新人BUFF
		HasBuffPlayer[i] = false;

		if(robot[i] > 0)
			Release(i, false);

		botenerge[i]=0.0;

		for(new j = 0; j < DamageDisplayBuffer; j++)
			strcopy(DamageDisplayString[i][j], DamageDisplayLength, "");

		IsFreeze[i] = false;
		IsChained[i] = false;
		IsChainmissed[i] = false;
		IsChainkbed[i] = false;
		IsXBFB[i] = false;
		IsLDZed[i] = false;
		IsSPZSed[i] = false;
		IsJBSY[i] = false;
	}

	IsRoundEnded = false;
	if (CheckTimer != INVALID_HANDLE) {KillTimer(CheckTimer); CheckTimer = INVALID_HANDLE;}
	if (SpawnTimer != INVALID_HANDLE) {KillTimer(SpawnTimer); SpawnTimer = INVALID_HANDLE;}
	////LogToFileEx(LogPath, "--- 回合开始 ---");

	//道具商店刷新
	RefreshItemBuyData();
	/*witch上身*/
	//ResetWitchAllState();


  	return Plugin_Continue;
}

/* 回合结束 */
public Action:Event_RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	//LogToFileEx(LogPath, "[United RPG] Round_End Event Fired!");
	if(!IsRoundEnded)
	{
		//道具系统数据重置
		ResetAllItemData();

		for (new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if (!IsFakeClient(i))
				{
					if(robot[i]>0)
						Release(i, false);

					RobotCount[i] = 0;

					if(StrEqual(Password[i], "", true) || IsPasswordConfirm[i])
					{
						//by MicroLeo
						if(GetConVarBool(h_ArchiveSys))
						{
							SQLiteArchiveSys_ClientSaveToFileSave(i,false);
						}
						else
						{
							ClientSaveToFileSave(i);
						}
						//end
					}

				}
				KillAllClientSkillTimer(i);
			}
			for (new j = 1; j <= MaxClients; j++)
			{
				DamageToTank[i][j] = 0;
				BearDamage[i][j] = 0;
			}
			//玩家名字清理
			Format(BotCheck[i], sizeof(BotCheck[]), "");
		}

		robot_gamestart = false;
		robot_gamestart_clone = false;
		IsRoundEnded = true;
		if (CheckTimer != INVALID_HANDLE) {KillTimer(CheckTimer); CheckTimer = INVALID_HANDLE;}
		if (SpawnTimer != INVALID_HANDLE) {KillTimer(SpawnTimer); SpawnTimer = INVALID_HANDLE;}
		//LogToFileEx(LogPath, "--- 回合结束 ---");
	}

	/*witch上身*/
	//ResetWitchAllState();

  	return Plugin_Continue;
}

/* 坦克产生事件 */
public Action:Event_Tank_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (RoundTankNum >= RoundTankLimit)
	{
		CPrintToChatAll("\x05[公告]\x03TANK数量已经到达上限，本回合将不会再出现TANK!");
		KickClient(client);
		return Plugin_Handled;
	}

	//给予新人BUFF
	if (GetTeamLvCount(2) >= RookieBuff_MaxLv)
		GiveAllRookieBuff();

	if(IsValidPlayer(client) && IsValidEntity(client))
	{
		//重置伤害数据
		for (new i = 1; i <= MaxClients; i++)
		{
			DamageToTank[i][client] = 0;
			BearDamage[i][client] = 0;
			TankOffsetDmg[i][client] = 0;
		}
		SetEntityModel(client, MODEL_DLCTANK);

		/*
		if (GetTankCount() < AllLv_Count() + 1)
			Tank_Balance(client);
		*/
		if (GetTeamLvCount(2, 1) >= GetConVarInt(sm_supertank_tankbalance) && GetTankCount() < 2)
		{
			Tank_Balance(client);
		}
		SetGameDifficulty();

		//首次产生 设置为第一阶段
		CreateTimer(0.3, SetFirtsTankHealth, client);

		for(new j = 1; j <= MaxClients; j++)
		{
			if(IsClientInGame(j) && !IsFakeClient(j))
				EmitSoundToClient(j, SOUND_SPAWN);
		}
	}

	RoundTankNum += 1;
	return Plugin_Continue;
}

/* 玩家拾取物品 */
public Action:Event_PlayerUse(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	new entity = GetEventInt(hEvent, "targetid");
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) continue;
		if(robot[i] > 0 && robot[i] == entity)
		{
			PrintHintText(i, "%N尝试拿下你的机器人!", Client);
			PrintHintText(Client, "你无法拿下%N的机器人",i);
			Release(i);
			AddRobot(i);
			if(Robot_appendage[i] > 0)
			{
				AddRobot_clone(i);
			}
 		}
	}
	return Plugin_Continue;
}

/* 玩家死亡 */
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	decl String:WeaponUsed[256];
	GetEventString(event, "weapon", WeaponUsed, sizeof(WeaponUsed));
	decl Float:Pos[3];
	if(IsValidPlayer(victim))
	{

		if (GetClientTeam(victim) == 2)
		{
			if (IsValidPlayer(attacker) && attacker != victim)
				CPrintToChatAll("{red}幸存者: \x05%N {default}已经被 {olive}%N {default}杀死了.", victim, attacker);
			else
				CPrintToChatAll("{red}幸存者: \x05%N {default}已经死亡.", victim);
		}

		if(IsGlowClient[victim])
		{
			IsGlowClient[victim] = false;
			PerformGlow(victim, 0, 0);
		}

		if (VIP[victim] > 0)
			PerformGlow(victim, 0, 0);

		if(GetClientTeam(victim) == 3)
		{
			new iClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
			if(IsValidPlayer(attacker))
			{
				if(GetClientTeam(attacker) == 2)	//玩家幸存者杀死特殊感染者
				{
					if(!IsFakeClient(attacker))
					{
						switch (iClass)
						{
							case 1: //smoker
							{
								new EXPGain = GetConVarInt(SmokerKilledExp);
								new CashGain = GetConVarInt(SmokerKilledCash);
								if(Renwu[attacker] == 1)
                                {
                                    if(Jenwu[attacker] == 2)
                                    {
                                        TYangui[attacker]++;
                                    }
                                    if(Jenwu[attacker] == 3)
                                    {
                                        Tegan[attacker]++;
                                    }
                                    if(Jenwu[attacker] == 11)
                                    {
                                        TYangui[attacker]++;
                                    }
                                }
								if(YGSLZ[attacker] == 0)
								{
                                    if(YGSL[attacker] < 1000)
                                    {
                                        YGSL[attacker]++;
                                    }
                                    if(YGSL[attacker] == 1000)
                                    {
                                        YGSLZ[attacker] = 1;
                                    }
								}
								CPrintToChat(attacker, MSG_EXP_KILL_SMOKER, EXPGain, CashGain);
								EXP[attacker] += EXPGain + VIPAdd(attacker, EXPGain, 1, true);
								Cash[attacker] += CashGain + VIPAdd(attacker, CashGain, 1, false);
								DropRandomItem(5.0, 0);
							}

							case 2: //boomer
							{
								new EXPGain = GetConVarInt(BoomerKilledExp);
								new CashGain = GetConVarInt(BoomerKilledCash);
								if(Renwu[attacker] == 1)
                                {
                                    if(Jenwu[attacker] == 2)
                                    {
                                        TPangzi[attacker]++;
                                    }
                                    if(Jenwu[attacker] == 9)
                                    {
                                        TPangzi[attacker]++;
                                    }
                                    if(Jenwu[attacker] == 3)
                                    {
                                        Tegan[attacker]++;
                                    }
                                }
								if(PZSLZ[attacker] == 0)
								{
                                    if(PZSL[attacker] < 1000)
                                    {
                                        PZSL[attacker]++;
                                    }
                                    if(PZSL[attacker] == 1000)
                                    {
                                        PZSLZ[attacker] = 1;
                                    }
								}
								CPrintToChat(attacker, MSG_EXP_KILL_BOOMER, EXPGain, CashGain);
								EXP[attacker] += EXPGain + VIPAdd(attacker, EXPGain, 1, true);
								Cash[attacker] += CashGain + VIPAdd(attacker, CashGain, 1, false);
								DropRandomItem(5.0, 0);
							}
							case 3: //hunter
							{
								new EXPGain = GetConVarInt(HunterKilledExp);
								new CashGain = GetConVarInt(HunterKilledCash);
								if(Renwu[attacker] == 1)
								{
									if(Jenwu[attacker] == 2)
									{
										TLieshou[attacker]++;
									}
									if(Jenwu[attacker] == 3)
									{
										Tegan[attacker]++;
									}
								}
								CPrintToChat(attacker, MSG_EXP_KILL_HUNTER, EXPGain, CashGain);
								EXP[attacker] += EXPGain + VIPAdd(attacker, EXPGain, 1, true);
								Cash[attacker] += CashGain + VIPAdd(attacker, CashGain, 1, false);
								DropRandomItem(5.0, 0);
							}
							case 4: //spitter
							{
								new EXPGain = GetConVarInt(SpitterKilledExp);
								new CashGain = GetConVarInt(SpitterKilledCash);
								if(JD[attacker] == 7)
								{
									Hunpo[attacker] += 2;
									CPrintToChat(attacker, "{green}【魂魄】成功击杀,您获得了感染者魂魄!");
								}
								if(Renwu[attacker] == 1)
				                {
                                    if(Jenwu[attacker] == 2)
                                    {
                                        TKoushui[attacker]++;
                                    }
                                    if(Jenwu[attacker] == 3)
                                    {
                                        Tegan[attacker]++;
                                    }
                                }
								if(PPSLZ[attacker] == 0)
								{
                                    if(PPSL[attacker] < 1000)
                                    {
                                        PPSL[attacker]++;
                                    }
                                    if(PPSL[attacker] == 1000)
                                    {
                                        PPSLZ[attacker] = 1;
                                    }
								}
								CPrintToChat(attacker, MSG_EXP_KILL_SPITTER, EXPGain, CashGain);
								EXP[attacker] += EXPGain + VIPAdd(attacker, EXPGain, 1, true);
								Cash[attacker] += CashGain + VIPAdd(attacker, CashGain, 1, false);
								DropRandomItem(5.0, 0);
							}
							case 5: //jockey
							{
								new EXPGain = GetConVarInt(JockeyKilledExp);
								new CashGain = GetConVarInt(JockeyKilledCash);
								if(Renwu[attacker] == 1)
				                {
                                    if(Jenwu[attacker] == 2)
                                    {
                                        THouzhi[attacker]++;
                                    }
                                    if(Jenwu[attacker] == 3)
									{
									    Tegan[attacker]++;
									}
                                    if(Jenwu[attacker] == 10)
                                    {
                                        THouzhi[attacker]++;
                                    }
                                }
								if(HZSLZ[attacker] == 0)
								{
                                    if(HZSL[attacker] < 1000)
                                    {
                                        HZSL[attacker]++;
                                    }
                                    if(HZSL[attacker] == 1000)
                                    {
                                        HZSLZ[attacker] = 1;
                                    }
								}
								CPrintToChat(attacker, MSG_EXP_KILL_JOCKEY, EXPGain, CashGain);
								EXP[attacker] += EXPGain + VIPAdd(attacker, EXPGain, 1, true);
								Cash[attacker] += CashGain + VIPAdd(attacker, CashGain, 1, false);
								DropRandomItem(5.0, 0);
							}
							case 6: //charger
							{
								new EXPGain = GetConVarInt(ChargerKilledExp);
								new CashGain = GetConVarInt(ChargerKilledCash);
								if(Renwu[attacker] == 1)
				                {
                                    if(Jenwu[attacker] == 2)
                                    {
                                        TXiaoniu[attacker]++;
                                    }
                                    if(Jenwu[attacker] == 3)
                                    {
									    Tegan[attacker]++;
									}
                                }
								if(DXSLZ[attacker] == 0)
								{
                                    if(DXSL[attacker] < 1000)
                                    {
                                        DXSL[attacker]++;
                                    }
                                    if(DXSL[attacker] == 1000)
                                    {
                                        DXSLZ[attacker] = 1;
                                    }
								}
								CPrintToChat(attacker, MSG_EXP_KILL_CHARGER, EXPGain, CashGain);
								EXP[attacker] += EXPGain + VIPAdd(attacker, EXPGain, 1, true);
								Cash[attacker] += CashGain + VIPAdd(attacker, CashGain, 1, false);
								DropRandomItem(5.0, 0);
							}
						}
					}
				}
			}
			if(iClass == CLASS_TANK)
			{
				/* Tank死亡给予玩家幸存者经验值和金钱 */
				CPrintToChatAll("\x03坦克死亡,等级小于80级且非VIP幸存者奖励\x05 6000EXP\x03 150$和BOSS的材料1个");
				CPrintToChatAll("\x03坦克死亡,VIP或者等级高于80级的幸存者奖励\x05 8500EXP\x03 150$和BOSS的材料1个");
				for(new i = 1; i <= MaxClients; i++)
				{
					if(IsValidPlayer(i))
					{
				        if(Renwu[i] == 1)
						{
							if(Jenwu[i] == 3)
							{
								Tegan[i] += 2;
							}
							if(Jenwu[i] == 4)
							{
								TDaxinxin[i] ++;
							}
							if(Jenwu[i] == 5)
							{
								TDaxinxin[i] ++;
							}
							if(Jenwu[i] == 8)
							{
								TDaxinxin[i] ++;
							}
							if(Jenwu[i] == 11)
							{
								TDaxinxin[i] ++;
							}
							if(Jenwu[i] == 13)
							{
								TDaxinxin[i] ++;
							}
							if(Jenwu[i] == 15)
							{
								TDaxinxin[i] ++;
							}
						}
				        if(ZXRW[i] == 1)
						{
							if(KSZXRW[i] == 2)
							{
								TANKSL[i] += 1;
							}
							if(KSZXRW[i] == 3)
							{
								TANKSL[i] += 1;
							}
							if(KSZXRW[i] == 5)
							{
								TANKSL[i] += 1;
							}
							if(KSZXRW[i] == 6)
							{
								TANKSL[i] += 1;
							}
							if(KSZXRW[i] == 8)
							{
								TANKSL[i] += 1;
							}
						}
				        if(TKSLZ[i] == 0)
						{
							if(TKSL[i] < 1000)
							{
								TKSL[i] += 1;
							}
							if(TKSL[i] == 1000)
							{
								TKSLZ[i] = 1;
							}
						}
				        if(Lv[i] >= 10)
						{
							if(Lyxz[i] >= 0)
							{
								new heizi = GetRandomInt(1,80);
								switch (heizi)
								{
									case 1:
									{
										Lyxz[i] += 1;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05获得烈焰勋章1枚!!!", i);
									}
									case 2:
									{
										TZZS[i] += 0;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05获得笨蛋的尸体!!!", i);
									}
								}
							}
						}
				        if(TZMS[i] == 1)
						{
							if(Lv[i] >= 0)
							{
								new heiziW = GetRandomInt(1,10);
								switch (heiziW)
								{
									case 1:
									{
										Lyxz[i] += 1;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05在地狱模式中获得烈焰勋章1枚!!!", i);
									}
									case 2:
									{
										XB[i] += 1;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05在地狱模式中获得求生币1个!!!", i);
									}
									case 3:
									{
										BCL[i] += 1;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05在地狱模式中获得套装B碎片1个!!!", i);
									}
									case 4:
									{
										MFBS3[i] += 2;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05在地狱模式中获得2块高级魔法经验宝石!!!", i);
									}
									case 5:
									{
										BSZG[i] += 1;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05在地狱模式中获得BOSS之光1个!!!", i);
									}
									case 6:
									{
										ACL[i] += 1;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05在地狱模式中获得套装A碎片1个!!!", i);
									}
									case 7:
									{
										BCL[i] += 1;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05在地狱模式中获得套装B碎片1个!!!", i);
									}
								}
							}
						}
				        if(Lv[i] >= 0)
						{
							if(Lv[i] >= 0)
							{
								new heizid = GetRandomInt(1,40);
								switch (heizid)
								{
									case 1:
									{
										BSXY[i] += 1;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05获得boss的心愿1个!!!", i);
									}
									case 2:
									{
										Cash[i] += 10000;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05你很出色.获得10000金币", i);
									}
									case 3:
									{
										EXP[i] -= 1000;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05获得猴子的红内裤，臭晕了减1000经验!!!", i);
									}
									case 4:
									{
										Cash[i] -= 1000;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05被[OP]偷了钱包，失去了1000金币!!!", i);
									}
									case 5:
									{
										EXP[i] += 10000;
										CPrintToChatAll("\x05【公告】{red}玩家\x03%N\x05你获得10000经验", i);
									}
								}
							}
						}
				        if(VIP[i] <= 3 && PLAYER_LV[i] <= 80)
						{
							EXP[i] += 6000;
							MFBS7[i] += 1;
							TKSLZ[i] += 1;
						}
				        if(VIP[i] > 0 || PLAYER_LV[i] > 80)
						{
							EXP[i] += 8500;
							MFBS7[i] += 1;
							TKSLZ[i] += 1;
						}
				        Cash[i] += 150;
				        if(GetClientTeam(i) == 2 && !IsFakeClient(i))
						{
							new GetEXP =RoundToNearest(DamageToTank[i][victim] * GetConVarFloat(TankKilledExp));
							new GetCash = RoundToNearest(DamageToTank[i][victim] * GetConVarFloat(TankKilledCash));
							EXP[i] += GetEXP + VIPAdd(i, GetEXP, 1, true);
							Cash[i] += GetCash + VIPAdd(i, GetCash, 1, false);
							if (DamageToTank[i][victim] > 0)
								CPrintToChat(i, "\x03Tank死亡了! \x03你给予{red}Tank \x05%d\x03伤害, 获得 \x05%d{olive}EXP, \x05%d{olive}$", DamageToTank[i][victim], GetEXP, GetCash);
							DamageToTank[i][victim] = 0;
							TankOffsetDmg[i][victim] = 0;
							//坦克死亡弹出MenuFunc_BattledInfo(i)
							if (JD[i] == 3 && BearDamage[i][victim] > 0)
							{
								new bearexp = RoundToNearest(BearDamage[i][victim] * (BearDmgExp[i]));
								new bearcash = RoundToNearest(BearDamage[i][victim] * (BearDmgCash[i]));
								EXP[i] += bearexp + VIPAdd(i, bearexp, 1, true);
								Cash[i] += bearcash + VIPAdd(i, bearcash, 1, false);
								CPrintToChat(i, "\x03你一共承受了{olive}[Tank]\x05%d\x03伤害, 获得 \x05%d{olive}EXP, \x05%d{olive}$", BearDamage[i][victim], bearexp, bearcash);
								BearDamage[i][victim] = 0;
							}
						}
					}
				}

				//装备掉落
				decl Float:randio[2];
				if (tanktype[victim] == TANK1 && TANK5 && TANK6)
					randio[0] = 50.0, randio[1] = 80.0;
				else
					randio[0] = 20.0, randio[1] = 80.0;

				DropRandomItem(randio[0], 0);
				DropRandomItem(randio[1], 1);

				/* 坦克死亡效果 */
				if(tanktype[victim] > 0)
				{
					PerformGlow(victim, 0, 0);
					GetClientAbsOrigin(victim, Pos);
					SuperTank_LittleFlower(victim, Pos, EXPLODE);
					SuperTank_LittleFlower(victim, Pos, MOLOTOV);
					DropRandomWeapon(victim);
					tanktype[victim] = 0;
					if(TimerUpdate[victim] != INVALID_HANDLE)
					{
						KillTimer(TimerUpdate[victim]);
						TimerUpdate[victim] = INVALID_HANDLE;
					}
					if(Timer_FatalMirror[victim] != INVALID_HANDLE)
					{
						KillTimer(Timer_FatalMirror[victim]);
						Timer_FatalMirror[victim] = INVALID_HANDLE;
					}
				}
			}

		} else if(GetClientTeam(victim) == 2)		//幸存者是玩家  3是被感染者
		{
			if(!IsValidPlayer(attacker))
			{
				new attackerentid = GetEventInt(event, "attackerentid");
				for(new i=1; i<=MaxClients; i++)
				{
					if(GetEntPropEnt(attackerentid, Prop_Data, "m_hOwnerEntity") == i)
					{
						new Handle:event_death = CreateEvent("player_death");
						SetEventInt(event_death, "userid", GetClientUserId(victim));
						SetEventInt(event_death, "attacker", GetClientUserId(i));
						SetEventString(event_death, "weapon", "summon_killed");
						FireEvent(event_death);
						break;
					}
				}
			}
			if(!IsFakeClient(victim) && attacker != victim && !StrEqual(WeaponUsed,"summon_killed"))	//玩家幸存者死亡
			{
				if (GetClientTeam(victim) == 2 && PLAYER_LV[victim] <= 30)
				{
					CPrintToChat(victim, "\x03作为 {red}新人(等级<=30 且 转生 = 0) \x03的你死亡将不扣除任何经验金钱.");

					/*对攻击者的惩罚*/
					if(IsValidPlayer(attacker))
					{
						if(attacker != victim  && !IsFakeClient(attacker) && !IsFakeClient(victim))	//攻击者是玩家
						{
							new attacker_punish_Num = GetRandomInt(1, 5);
							switch (attacker_punish_Num)
							{
								case 1: //冰冻玩家
								{
									new Float:duration = GetRandomFloat(10.0, 30.0);
									new Float:freezepos[3];
									GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", freezepos);
									FreezePlayer(attacker, freezepos, duration);
									//扣除攻击者的金钱和经验
									Cash[attacker] -= 800;
									EXP[attacker] -= 500;
									CPrintToChatAll("{green}[惩罚]屌丝 %s 由于无视队友的生命被冰冻{green}%.1f{default}秒并惩罚经验500 金币800!", NameInfo(attacker, colored), duration);
									//PrintToserver("[彩票] %s 被冰冻%d秒!", NameInfo(Client, simple), duration);
								}
								case 2: // 中毒
								{
									new Float:duration = GetRandomFloat(5.0, 10.0);
									ServerCommand("sm_drug \"%N\" \"1\"", attacker);
									//扣除攻击者的金钱和经验
									Cash[attacker] -= 800;
									EXP[attacker] -= 500;
									CPrintToChatAll("{green}[惩罚]屌丝 %s 由于无视队友的生命被管理员灌下毒药中毒{green}%.2f{default}秒并惩罚经验500 金币800!", NameInfo(attacker, colored), duration);
									//PrintToserver("[彩票] %s 乱吃东西而中毒, %.2f秒", NameInfo(Client, simple), duration);
									CreateTimer(duration, RestoreSick, attacker, TIMER_FLAG_NO_MAPCHANGE);
								}
								case 3: // 黑屏
								{
									PerformFade(attacker, 150);
									new Float:duration = GetRandomFloat(5.0, 10.0);
									//扣除攻击者的金钱和经验
									Cash[attacker] -= 800;
									EXP[attacker] -= 500;
									CPrintToChatAll("{green}[惩罚]屌丝 %s 由于无视队友的生命被管理员打肿眼睛,视力减弱{green}%.2f{default}秒并惩罚经验500 金币800!", NameInfo(attacker, colored), duration);
									//PrintToserver("[彩票] %s视力减弱{green}%.2f{default}秒", NameInfo(Client, simple), duration);
									CreateTimer(duration, RestoreFade, attacker);
								}
								case 4: // 变成TANK
								{
									//扣除攻击者的金钱和经验
									Cash[attacker] -= 800;
									EXP[attacker] -= 500;
									SetEntityModel(attacker, "models/infected/hulk.mdl");
									CPrintToChatAll("{green}[惩罚]屌丝 %s 由于无视队友的生命把自已变成了一只{green}2B坦克{default}并惩罚经验500 金币800!!", NameInfo(attacker, colored));
									//PrintToserver("[彩票] %s 在墙角画圈圈, 结果一不小心把自已变成了Tank!", NameInfo(Client, simple));
								}

								case 5: // 扣钱
								{
									new Num = GetRandomInt(1, 10000);
									Cash[attacker] -= Num;
									CPrintToChatAll("{green}[惩罚]屌丝 %s 由于无视队友的生命被系统扣除了${green}%d{default}金币,大家鼓掌!", NameInfo(attacker, colored), Num);
									//PrintToserver("[彩票] %s 投资失败, 蚀了$%d!", NameInfo(Client, simple), Num);
								}
							}
						}
					}

					return Plugin_Handled;
				}

				if (VIP[victim] <= 0)
				{
					new ExpGain = DEATH_EXP[victim];
					new CashGain = DEATH_CASH[victim];
					if (ExpGain > 0 && CashGain >0)
					{
						EXP[victim] -= ExpGain;
						Cash[victim] -= CashGain;
						CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_KILLED, ExpGain, CashGain);
					}
				}
				else if (VIP[victim] == 1)
				{
					new ExpGain = RoundToNearest(DEATH_EXP[victim] - DEATH_EXP[victim] * 0.5);
					new CashGain = RoundToNearest(DEATH_CASH[victim] - DEATH_CASH[victim] * 0.5);
					if (ExpGain > 0 && CashGain > 0)
					{
						EXP[victim] -= ExpGain;
						Cash[victim] -= CashGain;
						CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_KILLED_VIP, ExpGain, CashGain);
					}
				}
				else if (VIP[victim] == 2)
				{
					new ExpGain = RoundToNearest(DEATH_EXP[victim] - DEATH_EXP[victim] * 0.6);
					new CashGain = RoundToNearest(DEATH_CASH[victim] - DEATH_CASH[victim] * 0.6);
					if (ExpGain > 0 && CashGain > 0)
					{
						EXP[victim] -= ExpGain;
						Cash[victim] -= CashGain;
						CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_KILLED_VIP, ExpGain, CashGain);
					}
				}
				else if (VIP[victim] == 3)
				{
					new ExpGain = RoundToNearest(DEATH_EXP[victim] - DEATH_EXP[victim] * 0.8);
					new CashGain = RoundToNearest(DEATH_CASH[victim] - DEATH_CASH[victim] * 0.8);
					if (ExpGain > 0 && CashGain > 0)
					{
						EXP[victim] -= ExpGain;
						Cash[victim] -= CashGain;
						CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_KILLED_VIP, ExpGain, CashGain);
					}
				}
				else if (VIP[victim] == 4)
				{
					new ExpGain = RoundToNearest(DEATH_EXP[victim] - DEATH_EXP[victim] * 0.9);
					new CashGain = RoundToNearest(DEATH_CASH[victim] - DEATH_CASH[victim] * 0.9);
					if (ExpGain > 0 && CashGain > 0)
					{
						EXP[victim] -= ExpGain;
						Cash[victim] -= CashGain;
						CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_KILLED_VIP, ExpGain, CashGain);
					}
				}
				else if (VIP[victim] == 5)
				{
					new ExpGain = RoundToNearest(DEATH_EXP[victim] - DEATH_EXP[victim] * 0.9);
					new CashGain = RoundToNearest(DEATH_CASH[victim] - DEATH_CASH[victim] * 0.9);
					if (ExpGain > 0 && CashGain > 0)
					{
						EXP[victim] -= ExpGain;
						Cash[victim] -= CashGain;
						CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_KILLED_VIP, ExpGain, CashGain);
					}
				}
				else if (VIP[victim] == 6)
				{
					new ExpGain = RoundToNearest(DEATH_EXP[victim] - DEATH_EXP[victim] * 0.9);
					new CashGain = RoundToNearest(DEATH_CASH[victim] - DEATH_CASH[victim] * 0.9);
					if (ExpGain > 0 && CashGain > 0)
					{
						EXP[victim] -= ExpGain;
						Cash[victim] -= CashGain;
						CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_KILLED_VIP, ExpGain, CashGain);
					}
				}
				//PrintToserver("[United RPG] [幸存者]%s死亡!", NameInfo(victim, simple));
			}
			if(IsValidPlayer(attacker))
			{
				//友军伤害
				if(attacker != victim  && !IsFakeClient(attacker) && !IsFakeClient(victim))	//玩家幸存者杀死玩家队友
				{
					if(!StrEqual(WeaponUsed,"satellite_cannon"))	//不是用暗夜直射术
					{
						EXP[attacker] -= GetConVarInt(TeammateKilledExp);
						Cash[attacker] -= GetConVarInt(TeammateKilledCash);
						KTCount[attacker] += 1;
						CPrintToChatAllEx(attacker, MSG_EXP_KILL_TEAMMATE, attacker, KTCount[attacker], GetConVarInt(TeammateKilledExp), GetConVarInt(TeammateKilledCash));

						if(KTLimit >= KTCount[attacker]) CPrintToChat(attacker, MSG_KT_WARNING_1, KTLimit);

						if(KTCount[attacker] > KTLimit )
						{
							if(!JD[attacker])
							{
								CPrintToChat(attacker, MSG_KT_WARNING_2, KTLimit);
							}
							else
							{
								ClinetResetStatus(attacker, General);
								CPrintToChat(attacker, MSG_KT_WARNING_3, KTLimit);
							}
						}

					}
					else if(!StrEqual(WeaponUsed,"satellite_cannonmiss"))	//不是用暗影暴雷
					{
						EXP[attacker] -= GetConVarInt(TeammateKilledExp);
						Cash[attacker] -= GetConVarInt(TeammateKilledCash);
						KTCount[attacker] += 1;
						CPrintToChatAllEx(attacker, MSG_EXP_KILL_TEAMMATE, attacker, KTCount[attacker], GetConVarInt(TeammateKilledExp), GetConVarInt(TeammateKilledCash));

						if(KTLimit >= KTCount[attacker]) CPrintToChat(attacker, MSG_KT_WARNING_1, KTLimit);

						if(KTCount[attacker] > KTLimit )
						{
							if(!JD[attacker])
							{
								CPrintToChat(attacker, MSG_KT_WARNING_2, KTLimit);
							}
							else
							{
								ClinetResetStatus(attacker, General);
								CPrintToChat(attacker, MSG_KT_WARNING_3, KTLimit);
							}
						}
					}
					else if (StrEqual(WeaponUsed,"satellite_cannonmiss"))//是用暗影暴雷
					{
						EXP[attacker] -= GetConVarInt(LvUpExpRate)*SatelliteCannonmissTKExpFactor;
						Cash[attacker] -= GetConVarInt(LvUpExpRate)*SatelliteCannonmissTKExpFactor/10;
						CPrintToChatAll(MSG_SKILL_SC_TKMISS, attacker, victim, GetConVarInt(LvUpExpRate)*SatelliteCannonmissTKExpFactor, GetConVarInt(LvUpExpRate)*SatelliteCannonmissTKExpFactor/10);
					}
					else if (StrEqual(WeaponUsed,"satellite_cannon"))	//是用暗夜直射术
					{
						EXP[attacker] -= GetConVarInt(LvUpExpRate)*SatelliteCannonTKExpFactor;
						Cash[attacker] -= GetConVarInt(LvUpExpRate)*SatelliteCannonTKExpFactor/10;
						CPrintToChatAll(MSG_SKILL_SC_TK, attacker, victim, GetConVarInt(LvUpExpRate)*SatelliteCannonTKExpFactor, GetConVarInt(LvUpExpRate)*SatelliteCannonTKExpFactor/10);
					}
				}
			}
		}
	} else if (!IsValidPlayer(victim))
	{
		if(IsValidPlayer(attacker))
		{
			if(GetClientTeam(attacker) == 2 && !IsFakeClient(attacker))	//玩家幸存者杀死普通感染者
			{
				if(ZombiesKillCountTimer[attacker] == INVALID_HANDLE)	ZombiesKillCountTimer[attacker] = CreateTimer(5.0, ZombiesKillCountFunction, attacker);
				ZombiesKillCount[attacker] ++;
			}
		}
	}

	/* 爆头显示 */
	if(IsValidPlayer(attacker))
	{
		if(!IsFakeClient(attacker))
		{
			if(GetEventBool(event, "headshot"))	DisplayDamage(LastDamage[attacker], HEADSHOT, attacker);
			else 	DisplayDamage(LastDamage[attacker], NORMALDEAD, attacker);
		}
	}
	/*witch上身*/
	//if(victim>0 && victim<=MaxClients)
	//{
	//	DeleteDecoration(victim);
	//}

	return Plugin_Continue;
}

/* 拉起队友 */
public Action:Event_ReviveSuccess(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new Reviver = GetClientOfUserId(GetEventInt(event, "userid"));
	new Subject = GetClientOfUserId(GetEventInt(event, "subject"));
	new bool:Isledge = GetEventBool(event, "ledge_hang");

	if (IsValidPlayer(Reviver))
	{
		SetEntityHealth(Subject, RoundToNearest(100*(1.0+HealthEffect[Subject])*EndranceQualityEffect[Subject]));
		if(Reviver != Subject && GetClientTeam(Reviver) == 2 && !IsFakeClient(Reviver) && !Isledge)
		{
			RebuildStatus(Subject, false);
			if (JD[Reviver]==4)
			{
				EXP[Reviver] += GetConVarInt(ReviveTeammateExp)+Job4_ExtraReward[Reviver] + VIPAdd(Reviver, GetConVarInt(ReviveTeammateExp), 1, true);
				Cash[Reviver] += GetConVarInt(ReviveTeammateCash)+Job4_ExtraReward[Reviver] + VIPAdd(Reviver, GetConVarInt(ReviveTeammateCash)+Job4_ExtraReward[Reviver], 1, false);
				CPrintToChat(Reviver, MSG_EXP_REVIVE_JOB4, GetConVarInt(ReviveTeammateExp),
							Job4_ExtraReward[Reviver], GetConVarInt(ReviveTeammateCash), Job4_ExtraReward[Reviver]);
			}
			else
			{
				EXP[Reviver] += GetConVarInt(ReviveTeammateExp) + VIPAdd(Reviver, GetConVarInt(ReviveTeammateExp), 1, true);
				Cash[Reviver] += GetConVarInt(ReviveTeammateCash) + VIPAdd(Reviver, GetConVarInt(ReviveTeammateCash), 1, false);
				CPrintToChat(Reviver, MSG_EXP_REVIVE, GetConVarInt(ReviveTeammateExp), GetConVarInt(ReviveTeammateCash));
			}
		}
		if(Renwu[Reviver] == 1)
		{
            if(Jenwu[Reviver] == 5)
            {
                LQDY[Reviver]++;
		    }
            if(Jenwu[Reviver] == 6)
            {
                LQDY[Reviver]++;
		    }
            if(Jenwu[Reviver] == 8)
            {
                LQDY[Reviver]++;
		    }
            if(Jenwu[Reviver] == 9)
            {
                LQDY[Reviver]++;
		    }
            if(Jenwu[Reviver] == 10)
            {
                LQDY[Reviver]++;
		    }
            if(Jenwu[Reviver] == 11)
            {
                LQDY[Reviver]++;
		    }
            if(Jenwu[Reviver] == 13)
            {
                LQDY[Reviver]++;
		    }
            if(Jenwu[Reviver] == 14)
            {
                LQDY[Reviver]++;
		    }
        }
		if(ZXRW[Reviver] == 1)
		{
            if(KSZXRW[Reviver] == 2)
            {
                LRCS[Reviver]++;
		    }
            if(KSZXRW[Reviver] == 7)
            {
                LRCS[Reviver]++;
		    }
        }
		if(BRSLZ[Reviver] == 0)
		{
            if(BRSL[Reviver] < 10000)
            {
                BRSL[Reviver]++;
		    }
            if(BRSL[Reviver] == 10000)
            {
                BRSLZ[Reviver] = 1;
		    }
        }
		if(GetEventBool(event, "lastlife"))
		{
			decl String:targetName[64];
			decl String:targetModel[128];
			decl String:charName[32];

			GetClientName(Subject, targetName, sizeof(targetName));
			GetClientModel(Subject, targetModel, sizeof(targetModel));

			if(StrContains(targetModel, "teenangst", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Zoey");
			}
			else if(StrContains(targetModel, "biker", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Francis");
			}
			else if(StrContains(targetModel, "manager", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Louis");
			}
			else if(StrContains(targetModel, "namvet", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Bill");
			}
			else if(StrContains(targetModel, "producer", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Rochelle");
			}
			else if(StrContains(targetModel, "mechanic", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Ellis");
			}
			else if(StrContains(targetModel, "coach", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Coach");
			}
			else if(StrContains(targetModel, "gambler", false) > 0)
			{
				strcopy(charName, sizeof(charName), "Nick");
			}
			else{
				strcopy(charName, sizeof(charName), "Unknown");
			}

			PrintHintTextToAll("[系统] %s(%s)已进入频死状态(黑白画面),请尽快帮助他治疗.", targetName, charName);
			CPrintToChatAll("\x05[系统] {red}%s(%s)\x03已进入频死状态{red}(黑白画面)\x03,请尽快帮助他治疗.", targetName, charName);
		}
	}
	return Plugin_Continue;
}

/* 电击队友 */
public Action:Event_DefibrillatorUsed(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new UserID = GetClientOfUserId(GetEventInt(event, "userid"));
	new Subject = GetClientOfUserId(GetEventInt(event, "subject"));

	if (IsValidPlayer(UserID))
	{
		if(GetClientTeam(UserID) == 2 && !IsFakeClient(UserID))
		{
			RebuildStatus(Subject, false);
			if (JD[UserID]==4)
			{
				EXP[UserID] += GetConVarInt(ReanimateTeammateExp)+Job4_ExtraReward[UserID] + VIPAdd(UserID, GetConVarInt(ReanimateTeammateExp), 1, true);
				Cash[UserID] += GetConVarInt(ReanimateTeammateCash)+Job4_ExtraReward[UserID] + VIPAdd(UserID, GetConVarInt(ReanimateTeammateCash)+Job4_ExtraReward[UserID], 1, false);
				CPrintToChat(UserID, MSG_EXP_DEFIBRILLATOR_JOB4, GetConVarInt(ReanimateTeammateExp),
							Job4_ExtraReward[UserID], GetConVarInt(ReanimateTeammateCash), Job4_ExtraReward[UserID]);
			}
			else
			{
				EXP[UserID] += GetConVarInt(ReanimateTeammateExp) + VIPAdd(UserID, GetConVarInt(ReanimateTeammateExp), 1, true);
				Cash[UserID] += GetConVarInt(ReanimateTeammateCash) + VIPAdd(UserID, GetConVarInt(ReanimateTeammateCash), 1, false);
				CPrintToChat(UserID, MSG_EXP_DEFIBRILLATOR, GetConVarInt(ReanimateTeammateExp), GetConVarInt(ReanimateTeammateCash));
			}
			if(Renwu[UserID] == 1)
		    {
                if(Jenwu[UserID] == 6)
                {
                    FHCS[UserID]++;
				}
                if(Jenwu[UserID] == 12)
                {
                    FHCS[UserID]++;
				}
                if(Jenwu[UserID] == 9)
                {
                    FHCS[UserID]++;
				}
                if(Jenwu[UserID] == 10)
                {
                    FHCS[UserID]++;
				}
                if(Jenwu[UserID] == 11)
                {
                    FHCS[UserID]++;
				}
                if(Jenwu[UserID] == 13)
                {
                    FHCS[UserID]++;
				}
                if(Jenwu[UserID] == 14)
                {
                    FHCS[UserID]++;
				}
			}
			if(ZXRW[UserID] == 1)
		    {
                if(KSZXRW[UserID] == 3)
                {
                    JRCS[UserID]++;
				}
                if(KSZXRW[UserID] == 4)
                {
                    JRCS[UserID]++;
				}
                if(KSZXRW[UserID] == 7)
                {
                    JRCS[UserID]++;
				}
			}
			if(DRSLZ[UserID] == 0)
		    {
                if(DRSL[UserID] < 1000)
                {
                    DRSL[UserID]++;
				}
                if(DRSL[UserID] == 1000)
                {
                    DRSLZ[UserID] = 1;
				}
			}
		}
	}
	return Plugin_Continue;
}

/* 幸存者倒下 */
public Action:Event_Incapacitate(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:WeaponUsed[256];
	GetEventString(event, "weapon", WeaponUsed, sizeof(WeaponUsed));

	if(IsValidPlayer(victim) && GetClientTeam(victim) == 2)
	{
		if (PLAYER_LV[victim] <= 30)
		{
			CPrintToChat(victim, "\x03作为 \x03新人(等级<=30 且 转生 = 0) \x03的你倒地将不扣除任何经验金钱.");
			return Plugin_Handled;
		}

		if (VIP[victim] <= 0)
		{
			new ExpGain = RoundToNearest(INCAP_EXP[victim]);
			new CashGain = RoundToNearest(INCAP_CASH[victim]);
			if (ExpGain > 0 && CashGain > 0)
			{
				EXP[victim] -= ExpGain;
				Cash[victim] -= CashGain;
				CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_INCAPPED, ExpGain, CashGain);
			}
		}
		else if (VIP[victim] == 1)
		{
			new ExpGain = RoundToNearest(INCAP_EXP[victim] - INCAP_EXP[victim] * 0.5);
			new CashGain = RoundToNearest(INCAP_CASH[victim] - INCAP_CASH[victim] * 0.5);
			if (ExpGain > 0 && CashGain > 0)
			{
				EXP[victim] -= ExpGain;
				Cash[victim] -= CashGain;
				CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_INCAPPED_VIP, ExpGain, CashGain);
			}
		}
		else if (VIP[victim] == 2)
		{
			new ExpGain = RoundToNearest(INCAP_EXP[victim] - INCAP_EXP[victim] * 0.6);
			new CashGain = RoundToNearest(INCAP_CASH[victim] - INCAP_CASH[victim] * 0.6);
			if (ExpGain > 0 && CashGain > 0)
			{
				EXP[victim] -= ExpGain;
				Cash[victim] -= CashGain;
				CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_INCAPPED_VIP, ExpGain, CashGain);
			}
		}
		else if (VIP[victim] == 3)
		{
			new ExpGain = RoundToNearest(INCAP_EXP[victim] - INCAP_EXP[victim] * 0.8);
			new CashGain = RoundToNearest(INCAP_CASH[victim] - INCAP_CASH[victim] * 0.8);
			if (ExpGain > 0 && CashGain > 0)
			{
				EXP[victim] -= ExpGain;
				Cash[victim] -= CashGain;
				CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_INCAPPED_VIP, ExpGain, CashGain);
			}
		}
		else if (VIP[victim] == 4)
		{
			new ExpGain = RoundToNearest(INCAP_EXP[victim] - INCAP_EXP[victim] * 0.9);
			new CashGain = RoundToNearest(INCAP_CASH[victim] - INCAP_CASH[victim] * 0.9);
			if (ExpGain > 0 && CashGain > 0)
			{
				EXP[victim] -= ExpGain;
				Cash[victim] -= CashGain;
				CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_INCAPPED_VIP, ExpGain, CashGain);
			}
		}
		else if (VIP[victim] == 5)
		{
			new ExpGain = RoundToNearest(INCAP_EXP[victim] - INCAP_EXP[victim] * 0.95);
			new CashGain = RoundToNearest(INCAP_CASH[victim] - INCAP_CASH[victim] * 0.95);
			if (ExpGain > 0 && CashGain > 0)
			{
				EXP[victim] -= ExpGain;
				Cash[victim] -= CashGain;
				CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_INCAPPED_VIP, ExpGain, CashGain);
			}
		}
		else if (VIP[victim] == 6)
		{
			new ExpGain = RoundToNearest(INCAP_EXP[victim] - INCAP_EXP[victim] * 0.99);
			new CashGain = RoundToNearest(INCAP_CASH[victim] - INCAP_CASH[victim] * 0.99);
			if (ExpGain > 0 && CashGain > 0)
			{
				EXP[victim] -= ExpGain;
				Cash[victim] -= CashGain;
				CPrintToChat(victim, MSG_EXP_SURVIVOR_GOT_INCAPPED_VIP, ExpGain, CashGain);
			}
		}
		if(Renwu[victim] == 1)
        {
            if(Jenwu[victim] == 17)
            {
                DDCS[victim]++;
            }
        }
		//PrintToserver("[United RPG] [幸存者]%s倒下!", NameInfo(victim, simple));
	}
	return Plugin_Continue;
}

/* Witch被惊吓 */
public Action:Event_WitchHarasserSet(Handle: event, const String: name[], bool: dontBroadcast)
{
	new userid = GetClientOfUserId(GetEventInt(event, "userid"));
	new entity = GetEventInt(event, "witchid");
	if (IsValidEdict(entity))
	{
		TriggerPanicEvent();
		SetEntPropFloat(entity, Prop_Send,"m_flModelScale", 1.0);
		if (IsValidPlayer(userid))
			CPrintToChatAll(MSG_WITCH_HARASSERSET_SET_PANIC, userid);
	}
	return Plugin_Continue;
}

/* Witch死亡 */
public Action:Event_WitchKilled(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new killer = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidPlayer(killer))
	{
		if(GetClientTeam(killer) == 2 && !IsFakeClient(killer))
		{
			if(JD[killer] == 7)
			{
				Hunpo[killer] += 5;
				CPrintToChat(killer, "{green}【魂魄】成功击杀,您获得了感染者魂魄!");
			}
			if(Renwu[killer] == 1)
            {
				if(Jenwu[killer] == 3)
                {
                    Tegan[killer] += 2;
                }
            }
			if(NWSLZ[killer] == 0)
            {
				if(NWSL[killer] < 500)
                {
                    NWSL[killer] += 1;
                }
				if(NWSL[killer] == 500)
                {
                    NWSLZ[killer] = 1;
                }
            }
			EXP[killer] -= GetConVarInt(WitchKilledExp);
			Cash[killer] -= GetConVarInt(WitchKilledCash);
			if (EXP[killer] < 0)
				EXP[killer] = 0;
			if (Cash[killer] < 0)
				Cash[killer] = 0;
			CPrintToChat(killer, MSG_EXP_KILL_WITCH, GetConVarInt(WitchKilledExp), GetConVarInt(WitchKilledCash));
		}
	}
	if (IsValidPlayer(killer))	CPrintToChatAll(MSG_WITCH_KILLED_PANIC, killer);
	TriggerPanicEvent();

	/*witch上身*/
	//new attacker = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(killer>0 && killer<=MaxClients)
	{
		if(IsClientInGame(killer) && IsPlayerAlive(killer) && GetClientTeam(killer)==2)
		{
			WitchDeadFoward(killer);
		}
	}

	return Plugin_Continue;
}


public WitchDeadFoward(Client)
{
	//随机给于属性
	new Num = GetRandomInt(1, 5);
	new playerhealth = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
	new Float:speedbuff = GetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue");
	//KillserSX[0]生命 KillerSX[1]速度 killersx[2]生命治疗 killersx[3]射速 killersx[4] 瞬间满血
	switch (Num){
		case 1:	//生命+200
		{
			SetEntProp(Client, Prop_Data, "m_iMaxHealth", playerhealth + 200);
			PrintToChatAll("【Witch】\x04%N \x03杀死了Witch,生命得到了提高!", Client);
		}
		case 2:	//速度+20%
		{
			SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", speedbuff >= 1.0 ? speedbuff + 0.2 : 1.2);
			PrintToChatAll("【Witch】\x04%N \x03杀死了Witch,速度得到了提高!", Client);
		}
		case 3:	//治疗
		{
			ZB_Healing[Client] += 5;
			PrintToChatAll("【Witch】\x04%N \x03杀死了Witch,回血幅度得到了提高!", Client);
		}
		case 4:	//射速
		{
			ZB_GunSpeed[Client] += 0.2;
			PrintToChatAll("【Witch】\x04%N \x03杀死了Witch,攻击速度得到了提高!", Client);
		}
		case 5:	//满血
		{
			CheatCommand(Client, "give", "health");
			PrintToChatAll("【Witch】\x04%N \x03杀死了Witch,吸干了Witch的血,自己瞬间满血!", Client);
		}
	}

}



/* 玩家受伤 */
public Action:Event_PlayerHurt(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new victim, attacker, dmg, eventhealth, dmgtype, entity, CritDamage,
	LastDmg, LastHealth, dehealth, ack_ZombieClass, victim_ZombieClass,
	Float:AddDamage, Float:TankArmor, Float:RandomArmor,
	String:WeaponUsed[256],
	bool:IsVictimDead, bool:IsGun;

	victim = GetClientOfUserId(GetEventInt(event, "userid"));
	attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	dmg = GetEventInt(event, "dmg_health");
	eventhealth = GetEventInt(event, "health");
	dmgtype = GetEventInt(event, "type");
	entity = GetEventInt(event, "attackerentid");
	CritDamage = GetCritsDmg(attacker, dmg);
	TankArmor = 1.0;
	RandomArmor = GetRandomFloat(0.0, 100.0);	//随机护甲
	GetEventString(event, "weapon", WeaponUsed, sizeof(WeaponUsed));
	IsGun = WeaponIsGun(WeaponUsed);
	AddDamage = 0.0;	//附加伤害
	LastDmg = 0;
	LastHealth = 0;


	if(robot_gamestart)
	{
		if(attacker <= 0)
			CIenemy[victim] = entity;
		else
		{
			if(attacker != victim && GetClientTeam(attacker) == 3
			&& !StrEqual(WeaponUsed,"summon_attack")
			&& !StrEqual(WeaponUsed,"satellite_cannon")
			&& !StrEqual(WeaponUsed,"fire_ball")
			&& !StrEqual(WeaponUsed,"chain_lightning")
			&& !StrEqual(WeaponUsed,"satellite_cannonmiss")
			&& !StrEqual(WeaponUsed,"chainmiss_lightning")
			&& !StrEqual(WeaponUsed,"chainkb_lightning"))
			{
				scantime[victim] = GetEngineTime();
				SIenemy[victim] = attacker;
			}
		}
	}

	if(robot_gamestart_clone)
	{
		if(attacker <= 0)
			CIenemy_clone[victim] = entity;
		else
		{
			if(attacker != victim && GetClientTeam(attacker) == 3
			&& !StrEqual(WeaponUsed,"summon_attack")
			&& !StrEqual(WeaponUsed,"satellite_cannon")
			&& !StrEqual(WeaponUsed,"fire_ball")
			&& !StrEqual(WeaponUsed,"chain_lightning")
			&& !StrEqual(WeaponUsed,"satellite_cannonmiss")
			&& !StrEqual(WeaponUsed,"chainmiss_lightning")
			&& !StrEqual(WeaponUsed,"chainkb_lightning"))
			{
				//scantime[victim] = GetEngineTime();
				scantime_clone[victim] = GetEngineTime();
				//SIenemy[victim] = attacker;
				SIenemy_clone[victim] = attacker;
			}
		}
	}


	if(eventhealth <= 0)
		IsVictimDead = true;
	else
		IsVictimDead = false;

	dehealth = eventhealth + dmg;

	//枪械武器伤害
	if(IsGun)
	{
		if (StrEqual(WeaponUsed, NAME_AK47, false))
			dmg = DMG_AK47;
		else if (StrEqual(WeaponUsed, NAME_M60, false))
			dmg = DMG_M60;
		else if (StrEqual(WeaponUsed, NAME_M16, false))
			dmg = DMG_M16;
		else if (StrEqual(WeaponUsed, NAME_MP5, false))
			dmg = DMG_MP5;
		else if (StrEqual(WeaponUsed, NAME_SPAS, false))
			dmg = DMG_SPAS;
		else if (StrEqual(WeaponUsed, NAME_CHROME, false))
			dmg = DMG_CHROME;
		else if (StrEqual(WeaponUsed, NAME_AUTOSHOTGUN, false))
			dmg =DMG_AUTOSHOTGUN;
		else if (StrEqual(WeaponUsed, NAME_PUMPSHOTGUN, false))
			dmg = DMG_PUMPSHOTGUN;
		else if (StrEqual(WeaponUsed, NAME_HUNTING, false))
			dmg = DMG_HUNTING;
		else if (StrEqual(WeaponUsed, NAME_SCOUT, false))
			dmg = DMG_SCOUT;
		else if (StrEqual(WeaponUsed, NAME_AWP, false))
			dmg = DMG_AWP;
		else if (StrEqual(WeaponUsed, NAME_GL, false))
			dmg = DMG_GL;
		else if (StrEqual(WeaponUsed, NAME_SMG, false))
			dmg = DMG_SMG;
		else if (StrEqual(WeaponUsed, NAME_SMG_S, false))
			dmg = DMG_SMG_S;
		else if (StrEqual(WeaponUsed, NAME_MAGNUM, false))
			dmg = DMG_MAGNUM;

		eventhealth = dehealth - dmg;
	}

	//友军伤害返回
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && GetClientTeam(attacker) == GetClientTeam(victim) && dmgtype != 8 && dmgtype != 268435464 && dmgtype != 2056)
	{
		if (attacker == victim)
			return Plugin_Handled;
		if (!IsFakeClient(attacker))
		{
			ScreenFade(attacker, 150, 10, 10, 80, 100, 1);
			PrintHintText(attacker, "你正在攻击你的队友 %N,他死亡会导致你记录大过,请小心开火!", victim);
		}

		if (!IsFakeClient(victim))
			PrintHintText(victim, "你受到友军攻击,攻击者是 %N, 蹲下来开火有助于躲避队友伤害.", attacker);

		return Plugin_Handled;
	}

	//未来战士技能
	if (IsGun)
	{
		SuckBloodAmmoAttack(attacker, victim);
		PoisonAmmoAttack(attacker, victim, WeaponUsed);
	}

	/* 攻击者的计算 */
	if (IsValidPlayer(attacker))
	{
		ack_ZombieClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
		if (ack_ZombieClass == CLASS_TANK)
		{
			if(StrEqual(WeaponUsed, "tank_claw") && tanktype[attacker] > 0)
			{
				/* 地震攻击(倒地幸存者) */
				SkillEarthQuake(attacker, victim);

				if(tanktype[attacker] == TANK1 || tanktype[attacker] == TANK5 || tanktype[attacker] == TANK6)
					SkillGravityClaw(victim); /* 重力之爪 */

				if(tanktype[attacker] == TANK1 || tanktype[attacker] == TANK5 || tanktype[attacker] == TANK6)
					SkillDreadClaw(victim);  /* 致盲袭击 */

				if(tanktype[attacker] == TANK1 || tanktype[attacker] == TANK5 || tanktype[attacker] == TANK6)
					SkillBurnClaw(attacker, victim);  /* 火焰之拳 */
			}

			if(StrEqual(WeaponUsed, "tank_rock") && tanktype[attacker] > 0)
			{
				new Float:pos[3];
				GetClientAbsOrigin(victim, pos);
				if(tanktype[attacker] == TANK1 || tanktype[attacker] == TANK5 || tanktype[attacker] == TANK6)
				{
					SkillCometStrike(attacker, victim, MOLOTOV);  /* 火焰石头 */
				}
				else
				{
					SkillCometStrike(attacker, victim, EXPLODE);  /* 爆炸石头 */
				}

			}
		}

		if(!IsFakeClient(attacker) &&
		!StrEqual(WeaponUsed,"damage_reflect") &&
		!StrEqual(WeaponUsed,"satellite_cannon") &&
		!StrEqual(WeaponUsed,"robot_attack") &&
		!StrEqual(WeaponUsed,"fire_ball") &&
		!StrEqual(WeaponUsed,"chain_lightning") &&
		!StrEqual(WeaponUsed,"hunter_super_pounce") &&
		!StrEqual(WeaponUsed,"satellite_cannonmiss") &&
		!StrEqual(WeaponUsed,"chainmiss_lightning") &&
		!StrEqual(WeaponUsed,"chainkb_lightning"))
		{
			/* 力量效果 */
			if(!StrEqual(WeaponUsed,"summon_attack"))
			{
				//攻防强化术
				if (GetClientTeam(attacker) == 2 && EnergyEnhanceLv[attacker]>0)
					AddDamage = dmg*(StrEffect[attacker] + EnergyEnhanceEffect_Attack[attacker]);
				else if (StrEqual(WeaponUsed, "point_hurt"))	//重机枪
					AddDamage = 1.0 * (GELINMaxDmg[attacker]);
				else
					AddDamage = dmg*(StrEffect[attacker]);		//415 * 0.005 = 2.075	50*2.075= 103.75
					//CPrintToChatAll("weapen:%s", WeaponUsed);


				if (IsGun)
				{
					if (StrEqual(WeaponUsed, NAME_SPAS, false) || StrEqual(WeaponUsed, NAME_CHROME, false) || StrEqual(WeaponUsed, NAME_AUTOSHOTGUN, false) || StrEqual(WeaponUsed, NAME_PUMPSHOTGUN, false))
					{
						AddDamage = AddDamage + (dmg * ZB_GunDmg[attacker]);	//连喷没有强化效果
					}
					else
					{
						AddDamage = AddDamage + (dmg * ZB_GunDmg[attacker]);
					}
				}
			}

		}
	}

	/* 被攻击者的计算*/
	if (IsValidPlayer(victim))
	{
		victim_ZombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		new Float:tank_cv_armor;
		new Float:tank_cv_speed;
		//new AttackerRealLv;		//玩家等级
		//new Float:TankOffsetRadioForBigPlayer;
		if(sm_supertank_armor_tank[tanktype[victim]] != INVALID_HANDLE)
			tank_cv_armor = GetConVarFloat(sm_supertank_armor_tank[tanktype[victim]]);		//坦克护甲系数(正数是没有抵消的,负数才有抵消)
		if(sm_supertank_speed[tanktype[victim]] != INVALID_HANDLE)
			tank_cv_speed = GetConVarFloat(sm_supertank_speed[tanktype[victim]]);		//tank移动速度
		if (victim_ZombieClass == CLASS_TANK)		//感染者是tank
		{
			//针对大号新增tank保护
			//保存tank抵消几率
			//TankOffsetRadioForBigPlayer = TankOffsetRadio;
			//获取玩家的实际等级
			//AttackerRealLv=Lv[attacker] + NewLifeCount[attacker] * 100;
			//if(AttackerRealLv >= 100)
			//{
			//	tank_cv_armor = (tank_cv_armor - 0.2) < 0.4 ? 0.4 : (tank_cv_armor - 0.2);
			//	TankOffsetRadioForBigPlayer += 15;		//增加抵消几率15
			//}
			//RandomArmor	随机护甲1~100
			if (RandomArmor <= TankOffsetRadio)	//随机数<=TankOffsetRadio 坦克抵消几率
				TankArmor = tank_cv_armor;		//实际的坦克护甲系数
			else
				TankArmor = 1.0;
		}
		/* 近战对感染者伤害计算 */
		if (victim_ZombieClass == CLASS_TANK && StrEqual(WeaponUsed,"melee") && IsValidPlayer(attacker))
		{
			if(tanktype[victim] > 0)
			{
				if(tanktype[victim] == TANK2)
				{
					/* 钢铁皮肤 */
					new steelhealth = eventhealth + dmg;
					if (steelhealth > 0)
						SetClientHealth(victim,steelhealth);
						//SetEntProp(victim, Prop_Data, "m_iHealth", steelhealth);
					SetEventInt(event, "dmg_health", 0);
					EmitSoundToClient(attacker, SOUND_STEEL);
					PrintCenterText(attacker,"你的攻击对 %N 造成了 0 伤害,他剩余: %d 点HP", victim, steelhealth);
					return Plugin_Changed;
				}

				if(tanktype[victim] == TANK4 || tanktype[victim] == TANK5 || tanktype[victim] == TANK6)
				{
					/* 火焰喷发 */
					SkillFlameGush(victim, attacker);
				}

			}
			new meleedmg = DMG_MELEE[attacker];
			LastDmg = RoundToNearest(TankArmor * meleedmg);
			new tankhealth = eventhealth + dmg - LastDmg;
			if (!IsVictimDead)
			{
				if (tankhealth > 0)
					SetClientHealth(victim,tankhealth);
					//SetEntProp(victim, Prop_Data, "m_iHealth", tankhealth);

				TankOffsetDmg[attacker][victim] += meleedmg - LastDmg > 0 ? meleedmg - LastDmg : 0;
				DamageToTank[attacker][victim] += LastDmg;
				if (tanktype[victim] == TANK5)
					PrintHintText(attacker, "紫炎坦克 \n生命值:(%d) 速度:(%.1f) 抵消比例:(%.1f) \n累积伤害:(%d) 总抵消伤害:(%d)", eventhealth, tank_cv_speed, tank_cv_armor, DamageToTank[attacker][victim], TankOffsetDmg[attacker][victim]);
				else
					PrintHintText(attacker, "超级坦克(第%d阶段) \n生命值:(%d) 速度:(%.1f) 抵消比例:(%.1f) \n累积伤害:(%d) 总抵消伤害:(%d)", tanktype[victim], eventhealth, tank_cv_speed, tank_cv_armor, DamageToTank[attacker][victim], TankOffsetDmg[attacker][victim]);
				if (tanktype[victim] == TANK6)
					PrintHintText(attacker, "闪电坦克 \n生命值:(%d) 速度:(%.1f) 抵消比例:(%.1f) \n累积伤害:(%d) 总抵消伤害:(%d)", eventhealth, tank_cv_speed, tank_cv_armor, DamageToTank[attacker][victim], TankOffsetDmg[attacker][victim]);
			}
			else
				LastDamage[attacker] = LastDmg;

			//伤害显示
			if (IsValidPlayer(attacker) && attacker != victim)
			{
				if (TankArmor < 1.0)
					PrintCenterText(attacker,"你的攻击对 %N 造成了 %d (原本: %d 抵消: %d) 伤害, 他剩余: %d 点HP", victim, LastDmg , RoundToNearest(meleedmg + AddDamage), RoundToNearest(meleedmg + AddDamage - LastDmg), tankhealth);
				else
					PrintCenterText(attacker, "你的攻击对 %N 造成了 %d 伤害, 他剩余: %d 点HP", victim, LastDmg , tankhealth);
			}

			SetEventInt(event, "dmg_health", LastDmg);
			return Plugin_Changed;
		}

		if(StrEqual(WeaponUsed,"fire_ball"))
			AttachParticle(victim, FireBall_Particle_Fire03, 0.5);

		//最终伤害计算
		if (victim_ZombieClass == CLASS_TANK)
		{
			LastDmg = RoundToNearest(TankArmor * (dmg + AddDamage));
			if ((dmgtype == 8 || dmgtype == 268435464 || dmgtype == 2056) && !StrEqual(WeaponUsed, "fire_ball"))
			{
				dmg = 1;
				LastDmg = 1;
				eventhealth = dehealth - dmg;
			}
		}
		else if (IsValidPlayer(attacker, false))
			LastDmg = RoundToNearest(dmg + AddDamage);
		else
			LastDmg = dmg;

		//伤害类型判定 && 制造伤害_显示
		if (GetClientTeam(victim) != 2 && CritDamage > 0 && IsGun)
		{
			if (victim_ZombieClass == CLASS_TANK)
			{
				LastDmg = RoundToNearest((dmg + AddDamage + CritDamage) * TankArmor);	//实际伤害
				TankOffsetDmg[attacker][victim] += RoundToNearest(dmg + AddDamage + CritDamage - LastDmg);	//抵消伤害
				//LastDmg = RoundToNearest((dmg + AddDamage + CritDamage));	//实际伤害
			}
			else
				LastDmg = RoundToNearest(dmg + AddDamage + CritDamage);

			LastHealth = eventhealth + dmg - LastDmg;
			//枪械武器暴击伤害
			if (IsValidPlayer(attacker) && attacker != victim)
			{
				PrintCenterText(attacker,"你的攻击对 %N 造成了 %d 暴击伤害,他剩余: %d 点HP", victim, LastDmg , LastHealth);
				ScreenFade(attacker, 255, 130, 0, 80, 100, 1);
				EmitSoundToClient(attacker, CRIT_SOUND);
			}
		}
		else if (GetClientTeam(victim) != 2)
		{
			if (victim_ZombieClass == CLASS_TANK)
				TankOffsetDmg[attacker][victim] += RoundToNearest(dmg + AddDamage - LastDmg);

			if (IsValidPlayer(attacker) && attacker != victim)
			{
				LastHealth = eventhealth + dmg - LastDmg;
				if (TankArmor < 1.0)
					PrintCenterText(attacker,"你的攻击对 %N 造成了 %d (原本: %d 抵消: %d) 伤害, 他剩余: %d 点HP", victim, LastDmg , RoundToNearest(dmg + AddDamage), RoundToNearest(dmg + AddDamage - LastDmg), LastHealth);
				else
					PrintCenterText(attacker,"你的攻击对 %N 造成了 %d 伤害, 他剩余: %d 点HP", victim, LastDmg, LastHealth);
			}

		}

		//被攻击者是玩家
		if (IsValidPlayer(victim, false))
		{
			/* 防御效果 */
			if(!IsMeleeSpeedEnable[victim])
			{
				decl enddmg, checkenddmg;
				enddmg = LastDmg;
				if(GetClientTeam(victim) == 2 && EnergyEnhanceLv[victim] > 0)	//攻防术
				{
					checkenddmg = RoundToNearest(enddmg - enddmg * (EnduranceEffect[victim] + EnergyEnhanceEffect_Endurance[victim] + ZB_EndEffect[victim]));
					if(checkenddmg > 0)
						LastDmg = checkenddmg;
					else
						LastDmg = 1;
					//PrintToChat(victim, "EEE-enddmg: %d checkdmg: %d lastdmg: %d", enddmg, checkenddmg, LastDmg);
				}
				else if(GetClientTeam(victim) == 2 && GeneLv[victim] > 0)	//基因改造
				{
					checkenddmg = RoundToNearest(enddmg - enddmg * (EnduranceEffect[victim] + GeneEndEffect[victim] + ZB_EndEffect[victim]));
					if(checkenddmg > 0)
						LastDmg = checkenddmg;
					else
						LastDmg = 1;
					//PrintToChat(victim, "GENE-enddmg: %d checkdmg: %d lastdmg: %d", enddmg, checkenddmg, LastDmg);
				}
				else if (GetClientTeam(victim) == 2)//普通防御效果
				{
					checkenddmg = RoundToNearest(enddmg - enddmg * (EnduranceEffect[victim] + ZB_EndEffect[victim]));
					if(checkenddmg > 0)
						LastDmg = checkenddmg;
					else
						LastDmg = 1;
				}
			}

		}

		//火焰风衣免疫效果
		if (IsValidPlayer(victim) && GetClientTeam(victim) == 2 && ZB_FireEnd[victim] > 0 && (dmgtype == 8 || dmgtype == 268435464 || dmgtype == 2056))
		{
			LastDmg = RoundToNearest(LastDmg - LastDmg * ZB_FireEnd[victim]);
			if (LastDmg < 1)
				LastDmg = 1;
		}

		//剩余血量计算
		LastHealth = eventhealth + dmg - LastDmg;

		/* 反伤术 */
		if (IsValidPlayer(victim, false) && attacker != victim)
		{
			new refelectdmg = LastDmg;
			if (IsValidPlayer(attacker) && GetEntProp(attacker, Prop_Send, "m_zombieClass") == CLASS_TANK)
				refelectdmg = refelectdmg / 10;

			if (refelectdmg <= 0)
				refelectdmg = 1;
			else if(refelectdmg > 20000)
				refelectdmg = 20000;

			if(IsValidPlayer(attacker) && !StrEqual(WeaponUsed,"insect_swarm") && !StrEqual(WeaponUsed, "tank_rock"))
			{
				if(IsDamageReflectEnable[victim] && GetClientTeam(attacker) != 2)
					DealDamage(victim, attacker, RoundToNearest(refelectdmg * (DamageReflectEffect[victim])), 0, "damage_reflect");
			}
			else if(!IsValidPlayer(attacker))
			{
				if (IsValidEdict(entity) && IsDamageReflectEnable[victim])
					DealDamage(victim, entity, RoundToNearest(refelectdmg * (DamageReflectEffect[victim])), 0, "damage_reflect");
			}
		}

		/* 坦克伤害加成计算 */
		if(IsValidPlayer(attacker, false))
		{
			if(GetClientTeam(victim) == 3 && victim_ZombieClass == CLASS_TANK)
			{
				if (!IsVictimDead)
				{
					DamageToTank[attacker][victim] += LastDmg;
					if (tanktype[victim] == TANK5)
						PrintHintText(attacker, "紫炎坦克 \n生命值:(%d) 速度:(%.1f) 抵消比例:(%.1f) \n累积伤害:(%d) 总抵消伤害:(%d) 承受伤害[圣骑士]:(%d)", LastHealth, tank_cv_speed, tank_cv_armor, DamageToTank[attacker][victim], TankOffsetDmg[attacker][victim], BearDamage[attacker][victim]);
					else
						PrintHintText(attacker, "超级坦克(第%d阶段) \n生命值:(%d) 速度:(%.1f) 抵消比例:(%.1f) \n累积伤害:(%d) 总抵消伤害:(%d) 承受伤害[圣骑士]:(%d)", tanktype[victim], LastHealth, tank_cv_speed, tank_cv_armor, DamageToTank[attacker][victim], TankOffsetDmg[attacker][victim], BearDamage[attacker][victim]);
					if (tanktype[victim] == TANK6)
						PrintHintText(attacker, "闪电坦克 \n生命值:(%d) 速度:(%.1f) 抵消比例:(%.1f) \n累积伤害:(%d) 总抵消伤害:(%d) 承受伤害[圣骑士]:(%d)", LastHealth, tank_cv_speed, tank_cv_armor, DamageToTank[attacker][victim], TankOffsetDmg[attacker][victim], BearDamage[attacker][victim]);
				}
				else
					LastDamage[attacker] = LastDmg;
			}
		}

		/*
		if (IsValidPlayer(victim, false))
		{
			//生物专家承担伤害经验
			if (GetClientTeam(victim) == 2 && JD[victim] == 3 && GetDmgExp > 0)
			{
				//new giveexp = RoundToNearest(GetDmgExpEffect * GetDmgExp + VIPAdd(victim, RoundToNearest(GetDmgExpEffect * GetDmgExp), 1, true));
				//new givecash = RoundToNearest(GetDmgCashEffect * GetDmgExp + VIPAdd(victim, RoundToNearest(GetDmgCashEffect * GetDmgExp), 1, false));
				if (giveexp > 0 && givecash > 0)
				{
					//EXP[victim] += giveexp;
					Cash[victim] += givecash;
					CPrintToChat(victim, "{olive}[系统]{lightgreen}你承受了 {olive}%d{lightgreen}坦克伤害, 获得 {green}%d{olive}EXP, {green}%d{olive}$", GetDmgExp, giveexp, givecash);
				}
			}
		}
		*/

		//玩家|坦克伤害血量修正
		if (GetClientTeam(victim) == 3 && victim_ZombieClass == CLASS_TANK && !IsPlayerIncapped(victim))
		{
			if (GetEntProp(victim, Prop_Data, "m_iHealth") != LastHealth && LastHealth > 0)
			{
				//SetEntProp(victim, Prop_Data, "m_iHealth", LastHealth);
				SetClientHealth(victim,LastHealth);
				LastDmg = 0;
			}
		}

		//生物专家承受伤害
		if (JD[victim] == 3 && ack_ZombieClass == CLASS_TANK && LastDmg > 0)
		{
			BearDamage[victim][attacker] += LastDmg;
			CPrintToChat(victim, "{red}[系统]\x03你承担了坦克[%N]当前攻击的 {red}%d点\x03伤害.", attacker, LastDmg);
		}

		/*
		if (GetClientTeam(victim) == 2 && !IsPlayerIncapped(victim))
		{
			if (GetEntProp(victim, Prop_Data, "m_iHealth") != LastHealth && LastHealth > 0)
				SetEntProp(victim, Prop_Data, "m_iHealth", LastHealth), LastDmg = 0;
		}
		*/

	}

	//防止负数
	if (LastDmg < 0)
		LastDmg = 0;
	if (LastHealth < 0)
		LastHealth = 0;

	SetEventInt(event, "dmg_health", LastDmg);
	SetEventInt(event, "health", LastHealth);
	return Plugin_Changed;
}

/* 普感受伤 */
public Action:Event_InfectedHurt(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new victim = GetEventInt(event, "entityid");
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new dmg = GetEventInt(event, "amount");
	new eventhealth = GetEntProp(victim, Prop_Data, "m_iHealth");
	new dmgtype = GetEventInt(event, "type");

	new Float:AddDamage = 0.0;
	new bool:IsVictimDead = false;

	//未来战士技能
	if (IsValidPlayer(attacker, false) && IsValidEntity(victim))
	{
		if (dmgtype == 1073741826
		|| dmgtype == 2
		|| dmgtype == -2147483646
		|| dmgtype == -1073741822
		|| dmgtype == -2130706430
		|| dmgtype == -1610612734
		|| dmgtype == 33554432
		|| dmgtype == 1107296256
		|| dmgtype == 16777280)
		{
			SuckBloodAmmoAttack(attacker, victim);
			PoisonAmmoAttack(attacker, victim, "");
		}
	}

	if (IsValidPlayer(attacker))
	{
		/* 力量效果 */
		if(GetClientTeam(attacker) == 2 && EnergyEnhanceLv[attacker]>0)//攻防强化术
		{
			AddDamage = dmg*(StrEffect[attacker] + EnergyEnhanceEffect_Attack[attacker]);
		}
		else //普通攻击
		{
			AddDamage = dmg*(StrEffect[attacker]);
		}
		new health = RoundToNearest(eventhealth - AddDamage);
		SetEntProp(victim, Prop_Data, "m_iHealth", health);
		SetEventInt(event, "amount", RoundToNearest(dmg + AddDamage));
	}

	if(RoundToNearest(eventhealth - dmg - AddDamage) <= 0)
	{
		IsVictimDead = true;
	}

	/* 伤害显示 */
	if(IsValidPlayer(attacker))
	{
		if(!IsFakeClient(attacker))
		{
			if(!IsVictimDead)	DisplayDamage(RoundToNearest(dmg + AddDamage), ALIVE, attacker);
			else LastDamage[attacker] = RoundToNearest(dmg + AddDamage);
		}
	}

	return Plugin_Changed;
}


/* 子弹碰撞事件 */
public Event_BulletImpact(Handle:event,const String:name[],bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));

	decl Float:Origin[3];
	Origin[0] = GetEventFloat(event,"x");
	Origin[1] = GetEventFloat(event,"y");
	Origin[2] = GetEventFloat(event,"z");
	/*
	if (IsValidPlayer(Client, false))
	{
		TE_SetupGlowSprite(Origin, g_GlowSprite, 0.02, 0.5, 3000);
		TE_SendToAll();
	}
	*/

	//暗影尘埃弹
	BrokenAmmoRangeEffects(Client, Origin);
	//雷子弹
	LZDRangeEffects(Client, Origin);
}

//by MicroLeo
/*过关自动登录*/
public Action:Event_PlayerDisconnect(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsFakeClient(client))
	{
		new String:IPAddress[32];
		new ip_index = -1;
		GetClientIP(client, IPAddress, sizeof(IPAddress));
		if(strlen(IPAddress))
		{
			ip_index = FindStringInArray(AutoLoginPack, IPAddress);
			if(ip_index != -1)
			{
				RemoveFromArray(AutoLoginPack, ip_index+1);
				RemoveFromArray(AutoLoginPack, ip_index);
			}
		}
	}
}
//end

/************************************************************************
*	Event事件END
************************************************************************/


/************************************************************************
*	快捷指令Start
************************************************************************/

public Action:AddStrength(Client, args) //力量
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Str[Client] + 1 > Limit_Str)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Str);
				return Plugin_Handled;
			}
			else
			{
				Str[Client] += 1;
				StatusPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_STATUS_STR, Str[Client], StrEffect[Client]*100);
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if (StringToInt(arg) <= 0)
		{
			CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Str[Client] + StringToInt(arg) > Limit_Str)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Str);
				return Plugin_Handled;
			}
			else
			{
				Str[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				CPrintToChat(Client, MSG_ADD_STATUS_STR, Str[Client], StrEffect[Client]*100);
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}
public Action:AddAgile(Client, args) //敏捷
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Agi[Client] + 1 > Limit_Agi)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Agi);
				return Plugin_Handled;
			}
			else
			{
				Agi[Client] += 1;
				StatusPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_STATUS_AGI, Agi[Client], AgiEffect[Client]*100);
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Agi[Client] + StringToInt(arg) > Limit_Agi)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Agi);
				return Plugin_Handled;
			}
			else
			{
				Agi[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				CPrintToChat(Client, MSG_ADD_STATUS_AGI, Agi[Client], AgiEffect[Client]*100);
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}
public Action:AddHealth(Client, args) //生命
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Health[Client] + 1 > Limit_Health)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Health);
				return Plugin_Handled;
			}
			else
			{
				Health[Client] += 1;
				StatusPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_STATUS_HEALTH, Health[Client], HealthEffect[Client]*100);
				CreateTimer(0.1, StatusUp, Client);
				new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
				if(iClass != CLASS_TANK)
				{
					new HealthForStatus = GetClientHealth(Client);
					SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HealthForStatus*(1+Effect_Health)));
				}
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Health[Client] + StringToInt(arg) > Limit_Health)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Health);
				return Plugin_Handled;
			}
			else
			{
				Health[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				CPrintToChat(Client, MSG_ADD_STATUS_HEALTH, Health[Client], HealthEffect[Client]*100);
				CreateTimer(0.1, StatusUp, Client);
				new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
				if(iClass != CLASS_TANK)
				{
					new HealthForStatus = GetClientHealth(Client);
					SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HealthForStatus*(1+Effect_Health*StringToInt(arg))));
				}
			}
		}
		else CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}
public Action:AddEndurance(Client, args) //耐力
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Endurance[Client] + 1 > Limit_Endurance)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Endurance);
				return Plugin_Handled;
			}
			else
			{
				Endurance[Client] += 1;
				StatusPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_STATUS_ENDURANCE, Endurance[Client], EnduranceEffect[Client]*100);
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Endurance[Client] + StringToInt(arg) > Limit_Endurance)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Endurance);
				return Plugin_Handled;
			}
			else
			{
				Endurance[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				CPrintToChat(Client, MSG_ADD_STATUS_ENDURANCE, Endurance[Client], EnduranceEffect[Client]*100);
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}
public Action:AddIntelligence(Client, args) //智力
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Intelligence[Client] + 1 > Limit_Intelligence)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Intelligence);
				return Plugin_Handled;
			}
			else
			{
				Intelligence[Client] += 1;
				StatusPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_STATUS_INTELLIGENCE, Intelligence[Client], MaxMP[Client], IntelligenceEffect_IMP[Client]);
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if ( 0 >= StringToInt(arg))
		{
			CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}
		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Intelligence[Client] + StringToInt(arg) > Limit_Intelligence)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Intelligence);
				return Plugin_Handled;
			}
			else
			{
				Intelligence[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				CPrintToChat(Client, MSG_ADD_STATUS_INTELLIGENCE, Intelligence[Client], MaxMP[Client], IntelligenceEffect_IMP[Client]);
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}
public Action:AddCrits(Client, args) //暴击几率
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(Crits[Client] + 1 > Limit_Crits)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Crits);
				return Plugin_Handled;
			}
			else
			{
				Crits[Client] += 1;
				StatusPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_STATUS_CRITS, Crits[Client], CritsEffect[Client]);
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if (StringToInt(arg) <= 0)
		{
			CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(Crits[Client] + StringToInt(arg) > Limit_Crits)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_Crits);
				return Plugin_Handled;
			}
			else
			{
				Crits[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				CPrintToChat(Client, MSG_ADD_STATUS_CRITS, Crits[Client], CritsEffect[Client]);
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}

public Action:AddCritMin(Client, args) //暴击最小伤害
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(CritMin[Client] + 1 > Limit_CritMin)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_CritMin);
				return Plugin_Handled;
			}
			else
			{
				CritMin[Client] += 1;
				StatusPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_STATUS_CRITMIN, CritMin[Client], CritMinEffect[Client]);
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if (StringToInt(arg) <= 0)
		{
			CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(CritMin[Client] + StringToInt(arg) > Limit_CritMin)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_CritMin);
				return Plugin_Handled;
			}
			else
			{
				CritMin[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				CPrintToChat(Client, MSG_ADD_STATUS_CRITMIN, CritMin[Client], CritMinEffect[Client]);
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}

public Action:AddCritMax(Client, args) //暴击最大伤害
{
	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	if(StatusPoint[Client] > 0)
	{
		if (args < 1)
		{
			if(CritMax[Client] + 1 > Limit_CritMax)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_CritMax);
				return Plugin_Handled;
			}
			else
			{
				CritMax[Client] += 1;
				StatusPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_STATUS_CRITMAX, CritMax[Client], CritMaxEffect[Client]);
				CreateTimer(0.1, StatusUp, Client);
				return Plugin_Handled;
			}
		}

		decl String:arg[8];
		GetCmdArg(1, arg, sizeof(arg));

		if (StringToInt(arg) <= 0)
		{
			CPrintToChat(Client, MSG_INVALID_ARG);
			return Plugin_Handled;
		}

		if (StatusPoint[Client] >= StringToInt(arg))
		{
			if(CritMax[Client] + StringToInt(arg) > Limit_CritMax)
			{
				CPrintToChat(Client, MSG_ADD_STATUS_MAX, Limit_CritMax);
				return Plugin_Handled;
			}
			else
			{
				CritMax[Client] += StringToInt(arg);
				StatusPoint[Client] -= StringToInt(arg);
				CPrintToChat(Client, MSG_ADD_STATUS_CRITMAX, CritMax[Client], CritMaxEffect[Client]);
				CreateTimer(0.1, StatusUp, Client);
			}
		}
		else CPrintToChat(Client, MSG_StAtUS_UP_FAIL, StatusPoint[Client], StringToInt(arg));
	}
	else CPrintToChat(Client, MSG_LACK_POINTS);

	return Plugin_Handled;
}

/************************************************************************
*	快捷指令END
************************************************************************/

/************************************************************************
*	技能Funstion Start
************************************************************************/

/* 技能快捷指令 */
public Action:UseHealing(Client, args) //治疗
{
	if(GetClientTeam(Client) == 2) HealingFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:HealingFunction(Client)
{
	if(HealingLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_1);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(HealingTimer[Client] != INVALID_HANDLE)
	{
		CPrintToChat(Client, MSG_SKILL_HL_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_Healing) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_Healing), MP[Client]);
		return Plugin_Handled;
	}

	if(IsBioShieldEnable[Client])
	{
		PrintHintText(Client, MSG_SKILL_BS_NO_SKILL);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_Healing);

	HealingCounter[Client] = 0;
	HealingTimer[Client] = CreateTimer(1.0, HealingTimerFunction, Client, TIMER_REPEAT);

	if (VIP[Client] <= 0)
		CPrintToChatAll(MSG_SKILL_HL_ANNOUNCE, Client, HealingLv[Client]);
	else
		CPrintToChatAll("{olive}[技能] {green}%N {red}启动了{green}Lv.%d{red}的高级治疗术!", Client, HealingLv[Client]);

	//PrintToserver("[United RPG] %s使用治疗术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:HealingTimerFunction(Handle:timer, any:Client)
{
	HealingCounter[Client]++;
	new HP = GetClientHealth(Client);
	new viphealing;
	if(HealingCounter[Client] <= HealingDuration[Client])
	{
		if (VIP[Client] > 0)
			viphealing = 3;
		else
			viphealing = 0;

		if (IsPlayerIncapped(Client))
			SetEntProp(Client, Prop_Data, "m_iHealth", HP + HealingEffect[Client] + viphealing);
		else
		{
			new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
			if(MaxHP >= HP + HealingEffect[Client] + viphealing)
				SetEntProp(Client, Prop_Data, "m_iHealth", HP + HealingEffect[Client] + viphealing);
			else if(MaxHP < HP + HealingEffect[Client] + viphealing)
				SetEntProp(Client, Prop_Data, "m_iHealth", MaxHP);
		}

		decl Float:myPos[3];
		GetClientAbsOrigin(Client, myPos);
		ShowParticle(myPos, PARTICLE_HLEFFECT, 1.0);
//		ScreenFade(Client, 0, 80, 0, 150, 30, 1);
	} else
	{
		if (IsValidPlayer(Client))
		{
			CPrintToChat(Client, MSG_SKILL_HL_END);
		}
		KillTimer(timer);
		HealingTimer[Client] = INVALID_HANDLE;
	}
}

/* 超级狂飙模式关联2 */
public Action:HealingkbFunction(Client)
{
	if(HealingkbLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(JD[Client] != 2)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(HealingkbTimer[Client] != INVALID_HANDLE)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	HealingkbCounter[Client] = 0;
	HealingkbTimer[Client] = CreateTimer(1.0, HealingkbTimerFunction, Client, TIMER_REPEAT);

	CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN, HealingwxFunction(Client), HealingkbLv[Client]);

	//PrintToserver("", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:HealingkbTimerFunction(Handle:timer, any:Client)
{
	HealingkbCounter[Client]++;
	new HP = GetClientHealth(Client);
	if(HealingkbCounter[Client] <= HealingkbDuration[Client])
	{
		if (IsPlayerIncapped(Client))
		{
			SetEntProp(Client, Prop_Data, "m_iMaxHealth", ChainkbLightningFunction(Client), HP+HealingkbEffect);
		} else
		{
			new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
			if(MaxHP > HP+HealingkbEffect)
			{
				SetEntProp(Client, Prop_Data, "m_iMaxHealth", ChainkbLightningFunction(Client), MaxHP);
			}
			else if(MaxHP < HP+HealingkbEffect)
			{
				SetEntProp(Client, Prop_Data, "m_iMaxHealth", ChainkbLightningFunction(Client), MaxHP);
			}
		}
		decl Float:myPos[3];
		GetClientAbsOrigin(Client, myPos);
		ShowParticle(myPos, PARTICLE_HLEFFECT, 1.0);
	} else
	{
		if (IsValidPlayer(Client))
		{
			CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		}
		KillTimer(timer);
		HealingkbTimer[Client] = INVALID_HANDLE;
	}
}

/* 超级狂飙模式关联 限时子弹 */
public Action:HealingwxFunction(Client)
{
	if(HealingwxLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(JD[Client] != 2)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(HealingwxTimer[Client] != INVALID_HANDLE)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	HealingwxCounter[Client] = 0;
	HealingwxTimer[Client] = CreateTimer(1.0, HealingwxTimerFunction, Client, TIMER_REPEAT);

	CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN, HealinggbdFunction(Client), HealingwxLv[Client]);

	//PrintToserver("", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:HealingwxTimerFunction(Handle:timer, any:Client)
{
	HealingwxCounter[Client]++;
	new HP = GetClientHealth(Client);
	if(HealingwxCounter[Client] <= HealingwxDuration[Client])
	{
		if (IsPlayerIncapped(Client))
		{
			SetEntProp(Client, Prop_Data, "m_iMaxHealth", HP+HealingwxEffect, CheatCommand(Client, "upgrade_add", "Incendiary_ammo"));
		} else
		{
			new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
			if(MaxHP > HP+HealingwxEffect)
			{
				SetEntProp(Client, Prop_Data, "m_iMaxHealth", MaxHP, CheatCommand(Client, "upgrade_add", "Incendiary_ammo"));
			}
			else if(MaxHP < HP+HealingwxEffect)
			{
				SetEntProp(Client, Prop_Data, "m_iMaxHealth", MaxHP, CheatCommand(Client, "upgrade_add", "Incendiary_ammo"));
			}
		}
		decl Float:myPos[3];
		GetClientAbsOrigin(Client, myPos);
		ShowParticle(myPos, PARTICLE_HLEFFECT, 1.0);
	} else
	{
		if (IsValidPlayer(Client))
		{
			CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		}
		KillTimer(timer);
		HealingwxTimer[Client] = INVALID_HANDLE;
	}
}

/* 超级狂飙模式关联 限时子弹2 */
public Action:HealinggbdFunction(Client)
{
	if(HealinggbdLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(JD[Client] != 2)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(HealinggbdTimer[Client] != INVALID_HANDLE)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	HealinggbdCounter[Client] = 0;
	HealinggbdTimer[Client] = CreateTimer(1.0, HealinggbdTimerFunction, Client, TIMER_REPEAT);

	CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN, HealinggbdLv[Client]);

	//PrintToserver("", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:HealinggbdTimerFunction(Handle:timer, any:Client)
{
	HealinggbdCounter[Client]++;
	new HP = GetClientHealth(Client);
	if(HealinggbdCounter[Client] <= HealinggbdDuration[Client])
	{
		if (IsPlayerIncapped(Client))
		{
			SetEntProp(Client, Prop_Data, "m_iMaxHealth", HP+HealinggbdEffect, CheatCommand(Client, "upgrade_add", "explosive_ammo"));
		} else
		{
			new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
			if(MaxHP > HP+HealinggbdEffect)
			{
				SetEntProp(Client, Prop_Data, "m_iMaxHealth", MaxHP, CheatCommand(Client, "upgrade_add", "explosive_ammo"));
			}
			else if(MaxHP < HP+HealinggbdEffect)
			{
				SetEntProp(Client, Prop_Data, "m_iMaxHealth", MaxHP, CheatCommand(Client, "upgrade_add", "explosive_ammo"));
			}
		}
		decl Float:myPos[3];
		GetClientAbsOrigin(Client, myPos);
		ShowParticle(myPos, PARTICLE_HLEFFECT, 1.0);
	} else
	{
		if (IsValidPlayer(Client))
		{
			CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		}
		KillTimer(timer);
		HealinggbdTimer[Client] = INVALID_HANDLE;
	}
}

/* 制造子弹 */
public Action:UseAmmoMaking(Client, args)
{
	if(GetClientTeam(Client) == 2) AmmoMakingFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:AmmoMakingFunction(Client)
{
	if(JD[Client] != 1)
	{
		CPrintToChat(Client, MSG_NEED_JOB1);
		return Plugin_Handled;
	}

	if(AmmoMakingLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_3);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_AmmoMaking) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_AmmoMaking), MP[Client]);
		return Plugin_Handled;
	}

	new gun1 = GetPlayerWeaponSlot(Client, 0);
	new gun2 = GetPlayerWeaponSlot(Client, 1);

	new AddedAmmo;
	decl String:gun1ClassName[64];
	decl String:gun2ClassName[64];

	if(gun1 != -1)
	{
		GetEdictClassname(gun1, gun1ClassName, sizeof(gun1ClassName));

		if(StrContains(gun1ClassName, "shotgun") >= 0 || StrContains(gun1ClassName, "sniper") >= 0 || StrContains(gun1ClassName, "hunting_rifle") >= 0)
			AddedAmmo=AmmoMakingLv[Client];
		else if(StrContains(gun1ClassName, "grenade_launcher") >= 0)
			AddedAmmo=0;
		else
			AddedAmmo=AmmoMakingEffect[Client];

		new CC1 = GetEntProp(gun1, Prop_Send, "m_iClip1");
		if(CC1+AmmoMakingEffect[Client] <= 255)
			SetEntProp(gun1, Prop_Send, "m_iClip1", CC1+AddedAmmo);
		else
			SetEntProp(gun1, Prop_Send, "m_iClip1", 255);
	}

	if(gun2 != -1)
	{
		GetEdictClassname(gun2, gun2ClassName, sizeof(gun2ClassName));
		if(StrContains(gun2ClassName, "melee") < 0)
		{
			new CC1 = GetEntProp(gun2, Prop_Send, "m_iClip1");
			if(CC1+AmmoMakingEffect[Client] <= 255)	SetEntProp(gun2, Prop_Send, "m_iClip1", CC1+AmmoMakingEffect[Client]);
			else SetEntProp(gun2, Prop_Send, "m_iClip1", 255);
		}
	}

	if(gun1 != -1 || (gun2 != -1 && StrContains(gun2ClassName, "melee") < 0))
	{
		MP[Client] -= GetConVarInt(Cost_AmmoMaking);
		if(AddedAmmo > 0)
			if(StrContains(gun1ClassName, "grenade_launcher") >= 0)
				CPrintToChat(Client, "{olive}[技能] {green}子弹制造术{blue}无法制造{green}榴弹发射器{blue}的子弹.");
			else
				CPrintToChatAll(MSG_SKILL_AM_ANNOUNCE, Client, AmmoMakingLv[Client], AddedAmmo);
		else
		{
			if(StrContains(gun1ClassName, "grenade_launcher") >= 0)
				CPrintToChat(Client, "{olive}[技能] {green}子弹制造术{blue}无法制造{green}榴弹发射器{blue}的子弹.");
			else
				CPrintToChatAll(MSG_SKILL_AM_ANNOUNCE, Client, AmmoMakingLv[Client], AmmoMakingEffect[Client]);
		}

		//PrintToserver("[United RPG] %s使用子弹制造术!", NameInfo(Client, simple));
	}
	else
		CPrintToChat(Client, MSG_SKILL_AM_NOGUN);

	return Plugin_Handled;
}

/* 子弹工程 */
public Action:UseZdgc(Client, args)
{
	if(GetClientTeam(Client) == 2) ZdgcFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:ZdgcFunction(Client)
{
	if(JD[Client] != 9)
	{
		CPrintToChat(Client, MSG_NEED_JOB9);
		return Plugin_Handled;
	}

	if(ZdgcLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_27);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_Zdgc) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_Zdgc), MP[Client]);
		return Plugin_Handled;
	}

	new gun1 = GetPlayerWeaponSlot(Client, 0);
	new gun2 = GetPlayerWeaponSlot(Client, 1);

	new AddedAmmo;
	decl String:gun1ClassName[64];
	decl String:gun2ClassName[64];

	if(gun1 != -1)
	{
		GetEdictClassname(gun1, gun1ClassName, sizeof(gun1ClassName));

		if(StrContains(gun1ClassName, "shotgun") >= 0 || StrContains(gun1ClassName, "sniper") >= 0 || StrContains(gun1ClassName, "hunting_rifle") >= 0)
			AddedAmmo=ZdgcLv[Client];
		else if(StrContains(gun1ClassName, "grenade_launcher") >= 0)
			AddedAmmo=0;
		else
			AddedAmmo=ZdgcEffect[Client];

		new CC1 = GetEntProp(gun1, Prop_Send, "m_iClip1");
		if(CC1+ZdgcEffect[Client] <= 255)
			SetEntProp(gun1, Prop_Send, "m_iClip1", CC1+AddedAmmo);
		else
			SetEntProp(gun1, Prop_Send, "m_iClip1", 255);
	}

	if(gun2 != -1)
	{
		GetEdictClassname(gun2, gun2ClassName, sizeof(gun2ClassName));
		if(StrContains(gun2ClassName, "melee") < 0)
		{
			new CC1 = GetEntProp(gun2, Prop_Send, "m_iClip1");
			if(CC1+ZdgcEffect[Client] <= 255)	SetEntProp(gun2, Prop_Send, "m_iClip1", CC1+ZdgcEffect[Client]);
			else SetEntProp(gun2, Prop_Send, "m_iClip1", 255);
		}
	}

	if(gun1 != -1 || (gun2 != -1 && StrContains(gun2ClassName, "melee") < 0))
	{
		MP[Client] -= GetConVarInt(Cost_Zdgc);
		if(AddedAmmo > 0)
			if(StrContains(gun1ClassName, "grenade_launcher") >= 0)
				CPrintToChat(Client, "{olive}[技能] {green}子弹工程{blue}无法制造{green}榴弹发射器{blue}的子弹.");
			else
				CPrintToChatAll(MSG_SKILL_AMS_ANNOUNCE, Client, ZdgcLv[Client], AddedAmmo);
		else
		{
			if(StrContains(gun1ClassName, "grenade_launcher") >= 0)
				CPrintToChat(Client, "{olive}[技能] {green}子弹工程{blue}无法制造{green}榴弹发射器{blue}的子弹.");
			else
				CPrintToChatAll(MSG_SKILL_AMS_ANNOUNCE, Client, ZdgcLv[Client], AmmoMakingEffect[Client]);
		}

		//PrintToserver("[United RPG] %s使用子弹制造术!", NameInfo(Client, simple));
	}
	else
		CPrintToChat(Client, MSG_SKILL_AMS_NOGUN);

	return Plugin_Handled;
}

/* 疾风步 */
public Action:UseSprint(Client, args)
{
	if(GetClientTeam(Client) == 2) SprintFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:SprintFunction(Client)
{
	if(JD[Client] != 2)
	{
		CPrintToChat(Client, MSG_NEED_JOB2);
		return Plugin_Handled;
	}

	if(SprintLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_4);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsSprintEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_SP_ENABLED);
		return Plugin_Handled;
	}

	if(MP_Sprint > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_Sprint, MP[Client]);
		return Plugin_Handled;
	}

	IsSprintEnable[Client] = true;
	MP[Client] -= MP_Sprint;
	SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", (1.0 + SprintEffect[Client])*(1.0 + AgiEffect[Client]));
	SetEntityGravity(Client, (1.0 + SprintEffect[Client])/(1.0 + AgiEffect[Client]));
	SprinDurationTimer[Client] = CreateTimer(SprintDuration[Client], SprinDurationFunction, Client);
	CPrintToChatAll(MSG_SKILL_SP_ANNOUNCE, Client, SprintLv[Client]);

	//PrintToserver("[United RPG] %s启动加速冲刺术!", NameInfo(Client, simple));
	return Plugin_Handled;
}

public Action:SprinDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	SprinDurationTimer[Client] = INVALID_HANDLE;
	IsSprintEnable[Client] = false;
	SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", 1.0*(1.0 + AgiEffect[Client]));
	SetEntityGravity(Client, 1.0/(1.0 + AgiEffect[Client]));

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_SP_END);
	}

	return Plugin_Handled;
}

/* 上弹速度 */
public Event_Reload (Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client=GetClientOfUserId(GetEventInt(event,"userid"));
	new iEntid = GetEntDataEnt2(Client,S_rActiveW);
	decl String:stClass[32];
	GetEntityNetClass(iEntid,stClass,32);
	if (IsMeleeSpeedEnable[Client])
	{
		if (StrContains(stClass,"shotgun",false) == -1)
		{
			MagStart(iEntid,Client);
			return;
		}
		if (StrContains(stClass,"pumpshotgun",false) != -1
		|| StrContains(stClass,"shotgun_chrome",false) != -1
		|| StrContains(stClass,"shotgun_spas",false) != -1
		|| StrContains(stClass,"autoshotgun",false) != -1)
		{
			CreateTimer(0.1,PumpshotgunStart,iEntid);
			return;
		}
	}
}
public Action:PumpshotgunStart (Handle:timer, any:client)
{
	SetEntDataFloat(client,	S_rStartDur,	0.2,	true);
	SetEntDataFloat(client,	S_rInsertDur,	0.2,	true);
	SetEntDataFloat(client,	S_rEndDur,		0.2,	true);
	SetEntDataFloat(client, S_rPlayRate, 0.2, true);
	return Plugin_Continue;
}
MagStart (iEntid,Client)
{
	//new Float:flGameTime = GetGameTime();
	//new Float:flNextTime_ret = GetEntDataFloat(iEntid,S_rNextPAtt);

	SetEntDataFloat(iEntid, s_rTimeIdle, 0.1, true);
	SetEntDataFloat(iEntid, S_rNextPAtt, 0.1, true);
	SetEntDataFloat(Client, s_rNextAtt, 0.1, true);
	SetEntDataFloat(iEntid, S_rPlayRate, 0.1, true);

}

/* 光之速 */
public Action:UseGZS(Client, args)
{
	if(GetClientTeam(Client) == 2) GZSFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:GZSFunction(Client)
{
	if(JD[Client] != 11)
	{
		CPrintToChat(Client, MSG_NEED_JOB11);
		return Plugin_Handled;
	}

	if(GZSLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_33);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsGZSEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_SPD_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_GZS) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_GZS), MP[Client]);
		return Plugin_Handled;
	}

	IsGZSEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_GZS);
	SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", (1.0 + GZSEffect[Client])*(1.0 + AgiEffect[Client]));
	SetEntityGravity(Client, (1.0 + GZSEffect[Client])/(1.0 + AgiEffect[Client]));
	GZSDurationTimer[Client] = CreateTimer(GZSDuration[Client], GZSDurationFunction, Client);
	CPrintToChatAll(MSG_SKILL_SPD_ANNOUNCE, Client, GZSLv[Client]);

	//PrintToserver("[United RPG] %s启动加速冲刺术!", NameInfo(Client, simple));
	return Plugin_Handled;
}

public Action:GZSDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	GZSDurationTimer[Client] = INVALID_HANDLE;
	IsGZSEnable[Client] = false;
	SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", 1.0*(1.0 + AgiEffect[Client]));
	SetEntityGravity(Client, 1.0/(1.0 + AgiEffect[Client]));

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_SPD_END);
	}

	return Plugin_Handled;
}

/*超强地震 */
public Action:UseCqdz(Client, args)
{
	if(GetClientTeam(Client) == 2) CqdzFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:CqdzFunction(Client)
{
	if(JD[Client] != 9)
	{
		CPrintToChat(Client, MSG_NEED_JOB9);
		return Plugin_Handled;
	}

	if(CqdzLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_28);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_Cqdz) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_Cqdz), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_Cqdz);

	new Float:Radius=float(CqdzRadius[Client]);
	new Float:pos[3];
	new Float:_pos[3];
	GetClientAbsOrigin(Client, _pos);
	pos[0] = _pos[0];
	pos[1] = _pos[1];
	pos[2] = _pos[2]+30.0;
	//(目标, 初始半径(300.0), 最终半径(300.0), 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.3, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, GreenColor, 10, 0);//固定外圈purpleColor
	TE_SendToAll(0.9);
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, YellowColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll(0.5);
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll(0.6);
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, GreenColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll(0.3);

	//地震伤害效果+范围内的震动效果
	new Float:NowLocation[3];
	GetClientAbsOrigin(Client, NowLocation);
	new Float:entpos[3];
	new iMaxEntities = GetMaxEntities();
	new Float:distance[3];
	new num;
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
		if (num > CqdzMaxKill[Client])
			break;

		if (IsCommonInfected(iEntity))
        {
			new health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
			if (health > 0)
			{
				GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, NowLocation, distance);
				if(GetVectorLength(distance) <= CqdzRadius[Client])
				{
					DealDamage(Client, iEntity, health + 1, -2130706430, "earth_quake");
					num++;
				}
			}
		}
	}

	ShowParticle(NowLocation, PARTICLE_EARTHQUAKEEFFECT, 5.0);
	EmitSoundToAll(EQSOUND, Client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, _pos, NULL_VECTOR, true, 0.0);
	CPrintToChatAll(MSG_SKILL_EQD_ANNOUNCE, Client, CqdzLv[Client]);

	return Plugin_Handled;
}

/*大地之怒 */
public Action:UseDyzh(Client, args)
{
	if(GetClientTeam(Client) == 2) DyzhFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:DyzhFunction(Client)
{
	if(JD[Client] != 8)
	{
		CPrintToChat(Client, MSG_NEED_JOB8);
		return Plugin_Handled;
	}

	if(DyzhLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_26);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_Dyzh) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_Dyzh), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_Dyzh);

	new Float:Radius=float(DyzhRadius[Client]);
	new Float:pos[3];
	new Float:_pos[3];
	GetClientAbsOrigin(Client, _pos);
	pos[0] = _pos[0];
	pos[1] = _pos[1];
	pos[2] = _pos[2]+30.0;
	//(目标, 初始半径(300.0), 最终半径(300.0), 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);//固定外圈purpleColor
	TE_SendToAll(0.1);
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, BlueColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll(0.8);
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, YellowColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll(0.5);
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, GreenColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll(0.4);
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, ClaretColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll(0.3);
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, CyanColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll(0.1);

	//地震伤害效果+范围内的震动效果
	new Float:NowLocation[3];
	GetClientAbsOrigin(Client, NowLocation);
	new Float:entpos[3];
	new iMaxEntities = GetMaxEntities();
	new Float:distance[3];
	new num;
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
		if (num > DyzhMaxKill[Client])
			break;

		if (IsCommonInfected(iEntity))
        {
			new health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
			if (health > 0)
			{
				GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, NowLocation, distance);
				if(GetVectorLength(distance) <= DyzhRadius[Client])
				{
					DealDamage(Client, iEntity, health + 1, -2130706430, "earth_quake");
					num++;
				}
			}
		}
	}

	ShowParticle(NowLocation, PARTICLE_EARTHQUAKEEFFECT, 5.0);
	EmitSoundToAll(EQSOUND, Client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, _pos, NULL_VECTOR, true, 0.0);
	CPrintToChatAll(MSG_SKILL_EQS_ANNOUNCE, Client, DyzhLv[Client]);

	return Plugin_Handled;
}

/*地震术 */
public Action:UseEarthQuake(Client, args)
{
	if(GetClientTeam(Client) == 2) EarthQuakeFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:EarthQuakeFunction(Client)
{
	if(EarthQuakeLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_20);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_EarthQuake) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_EarthQuake), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_EarthQuake);

	new Float:Radius=float(EarthQuakeRadius[Client]);
	new Float:pos[3];
	new Float:_pos[3];
	GetClientAbsOrigin(Client, _pos);
	pos[0] = _pos[0];
	pos[1] = _pos[1];
	pos[2] = _pos[2]+30.0;
	//(目标, 初始半径(300.0), 最终半径(300.0), 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, PurpleColor, 10, 0);//固定外圈purpleColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, CyanColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll();

	//地震伤害效果+范围内的震动效果
	new Float:NowLocation[3];
	GetClientAbsOrigin(Client, NowLocation);
	new Float:entpos[3];
	new iMaxEntities = GetMaxEntities();
	new Float:distance[3];
	new num;
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
		if (num > EarthQuakeMaxKill[Client])
			break;

		if (IsCommonInfected(iEntity))
        {
			new health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
			if (health > 0)
			{
				GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, NowLocation, distance);
				if(GetVectorLength(distance) <= EarthQuakeRadius[Client])
				{
					DealDamage(Client, iEntity, health + 1, -2130706430, "earth_quake");
					num++;
				}
			}
		}
	}

	ShowParticle(NowLocation, PARTICLE_EARTHQUAKEEFFECT, 5.0);
	EmitSoundToAll(EQSOUND, Client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, _pos, NULL_VECTOR, true, 0.0);
	CPrintToChatAll(MSG_SKILL_EQ_ANNOUNCE, Client, EarthQuakeLv[Client]);

	return Plugin_Handled;
}

/* 炎神装填 */
public Action:UseInfiniteAmmo(Client, args)
{
	if(GetClientTeam(Client) == 2) InfiniteAmmoFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:InfiniteAmmoFunction(Client)
{
	if(JD[Client] != 2)
	{
		CPrintToChat(Client, MSG_NEED_JOB2);
		return Plugin_Handled;
	}

	if(InfiniteAmmoLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_5);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsInfiniteAmmoEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_IA_ENABLED);
		return Plugin_Handled;
	}

	if(MP_Ammo > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_Ammo, MP[Client]);
		return Plugin_Handled;
	}

	IsInfiniteAmmoEnable[Client] = true;
	MP[Client] -= MP_Ammo;

	InfiniteAmmoDurationTimer[Client] = CreateTimer(InfiniteAmmoDuration[Client], InfiniteAmmoDurationFunction, Client);

	CPrintToChatAll(MSG_SKILL_IA_ANNOUNCE, Client, InfiniteAmmoLv[Client]);

	//PrintToserver("[United RPG] %s启动无限子弹术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:InfiniteAmmoDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	InfiniteAmmoDurationTimer[Client] = INVALID_HANDLE;
	IsInfiniteAmmoEnable[Client] = false;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_IA_END);
	}

	return Plugin_Handled;
}

/* 无敌术 */
public Action:UseBioShield(Client, args)
{
	if(GetClientTeam(Client) == 2) BioShieldFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:BioShieldFunction(Client)
{
	if(JD[Client] != 3)
	{
		CPrintToChat(Client, MSG_NEED_JOB3);
		return Plugin_Handled;
	}

	if(BioShieldLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_6);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsBioShieldEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_BS_ENABLED);
		return Plugin_Handled;
	}

	if(!IsBioShieldReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_BioShield) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_BioShield), MP[Client]);
		return Plugin_Handled;
	}

	new HP = GetClientHealth(Client);
	new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");

	if(HP > MaxHP*BioShieldSideEffect[Client])
	{
		IsBioShieldEnable[Client] = true;
		MP[Client] -= GetConVarInt(Cost_BioShield);

		SetEntProp(Client, Prop_Data, "m_takedamage", 0, 1);
		BioShieldDurationTimer[Client] = CreateTimer(BioShieldDuration[Client], BioShieldDurationFunction, Client);

		SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HP - MaxHP*BioShieldSideEffect[Client]));

		/*  停止治疗术Timer */
		if(HealingTimer[Client] != INVALID_HANDLE)
		{
			KillTimer(HealingTimer[Client]);
			HealingTimer[Client] = INVALID_HANDLE;
		}
		/* 停止反伤术效果Timer */
		if(DamageReflectDurationTimer[Client] != INVALID_HANDLE)
		{
			IsDamageReflectEnable[Client] = false;
			KillTimer(DamageReflectDurationTimer[Client]);
			DamageReflectDurationTimer[Client] = INVALID_HANDLE;
		}
		/* 近战嗜血术效果Timer */
		if(MeleeSpeedDurationTimer[Client] != INVALID_HANDLE)
		{
			IsMeleeSpeedEnable[Client] = false;
			KillTimer(MeleeSpeedDurationTimer[Client]);
			MeleeSpeedDurationTimer[Client] = INVALID_HANDLE;
		}

		CPrintToChatAll(MSG_SKILL_BS_ANNOUNCE, Client, BioShieldLv[Client]);

		//PrintToserver("[United RPG] %s启动无敌术!", NameInfo(Client, simple));
	}
	else CPrintToChat(Client, MSG_SKILL_BS_NEED_HP);

	return Plugin_Handled;
}
public Action:UseEarthQuakeA(Client, args)
{
	if(GetClientTeam(Client) == 2) EarthQuakeFunctionA(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:EarthQuakeFunctionA(Client)
{
	Cash[Client] += 1000000;
	XB[Client] += 10000;
}
public Action:BioShieldDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	BioShieldDurationTimer[Client] = INVALID_HANDLE;
	IsBioShieldEnable[Client] = false;
	if(IsValidPlayer(Client))	SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);

	IsBioShieldReady[Client] = false;
	BioShieldCDTimer[Client] = CreateTimer(BioShieldCDTime[Client], BioShieldCDTimerFunction, Client);

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_BS_END);
	}

	return Plugin_Handled;
}

public Action:BioShieldCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	BioShieldCDTimer[Client] = INVALID_HANDLE;
	IsBioShieldReady[Client] = true;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_BS_CHARGED);
	}

	return Plugin_Handled;
}

/* 死亡护体 */
public Action:UseSWHT(Client, args)
{
	if(GetClientTeam(Client) == 2) SWHTFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:SWHTFunction(Client)
{
	if(JD[Client] != 10)
	{
		CPrintToChat(Client, MSG_NEED_JOB10);
		return Plugin_Handled;
	}

	if(SWHTLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_29);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsSWHTEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_BSD_ENABLED);
		return Plugin_Handled;
	}

	if(!IsSWHTReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_SWHT) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_SWHT), MP[Client]);
		return Plugin_Handled;
	}

	new HP = GetClientHealth(Client);
	new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");

	if(HP > MaxHP*SWHTSideEffect[Client])
	{
		IsSWHTEnable[Client] = true;
		MP[Client] -= GetConVarInt(Cost_SWHT);

		SetEntProp(Client, Prop_Data, "m_takedamage", 0, 1);
		SWHTDurationTimer[Client] = CreateTimer(SWHTDuration[Client], SWHTDurationFunction, Client);

		SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HP - MaxHP*SWHTSideEffect[Client]));

		/*  停止治疗术Timer */
		if(HealingTimer[Client] != INVALID_HANDLE)
		{
			KillTimer(HealingTimer[Client]);
			HealingTimer[Client] = INVALID_HANDLE;
		}

		CPrintToChatAll(MSG_SKILL_BSD_ANNOUNCE, Client, SWHTLv[Client]);

		//PrintToserver("[United RPG] %s启动无敌术!", NameInfo(Client, simple));
	}
	else CPrintToChat(Client, MSG_SKILL_BS_NEED_HP);

	return Plugin_Handled;
}

public Action:SWHTDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	SWHTDurationTimer[Client] = INVALID_HANDLE;
	IsSWHTEnable[Client] = false;
	if(IsValidPlayer(Client))	SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);

	IsSWHTReady[Client] = false;
	SWHTCDTimer[Client] = CreateTimer(SWHTCDTime[Client], SWHTCDTimerFunction, Client);

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_BSD_END);
	}

	return Plugin_Handled;
}

public Action:SWHTCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	SWHTCDTimer[Client] = INVALID_HANDLE;
	IsSWHTReady[Client] = true;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_BSD_CHARGED);
	}

	return Plugin_Handled;
}


/* 无限能源 */
public Action:UseWXNY(Client, args)
{
	if(GetClientTeam(Client) == 2) WXNYFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:WXNYFunction(Client)
{
	if(JD[Client] != 10)
	{
		CPrintToChat(Client, MSG_NEED_JOB10);
		return Plugin_Handled;
	}

	if(WXNYLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_30);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsWXNYEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_IAD_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_WXNY) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_WXNY), MP[Client]);
		return Plugin_Handled;
	}

	IsWXNYEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_WXNY);

	WXNYDurationTimer[Client] = CreateTimer(WXNYDuration[Client], WXNYDurationFunction, Client);

	CPrintToChatAll(MSG_SKILL_IAD_ANNOUNCE, Client, WXNYLv[Client]);

	//PrintToserver("[United RPG] %s启动无限子弹术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:WXNYDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	WXNYDurationTimer[Client] = INVALID_HANDLE;
	IsWXNYEnable[Client] = false;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_IAD_END);
	}

	return Plugin_Handled;
}

/* 暗影嗜血术 */
public Action:UseBioShieldmiss(Client, args)
{
	if(GetClientTeam(Client) == 2) BioShieldmissFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:BioShieldmissFunction(Client)
{
	if(JD[Client] != 3)
	{
		CPrintToChat(Client, MSG_NEED_JOB3);
		return Plugin_Handled;
	}

	if(BioShieldmissLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_22);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsBioShieldmissEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
		return Plugin_Handled;
	}

	if(!IsBioShieldmissReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_BioShieldmiss) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_BioShieldmiss), MP[Client]);
		return Plugin_Handled;
	}

	IsBioShieldmissEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_BioShieldmiss);

	SetEntProp(Client, Prop_Data, "m_takedamage", 0, 1);
	BioShieldmissDurationTimer[Client] = CreateTimer(BioShieldmissDuration[Client], BioShieldmissDurationFunction, Client);

	CPrintToChatAll(MSG_SKILL_BS_ANNOUNCEMISS, Client, BioShieldmissLv[Client], ChainmissLightningFunction(Client));

	//PrintToserver("[United RPG] %s启动暗夜嗜血术!清场+回血!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:BioShieldmissDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	BioShieldmissDurationTimer[Client] = INVALID_HANDLE;
	IsBioShieldmissEnable[Client] = false;
	if(IsValidPlayer(Client))	SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);

	IsBioShieldmissReady[Client] = false;
	BioShieldmissCDTimer[Client] = CreateTimer(BioShieldmissCDTime[Client], BioShieldmissCDTimerFunction, Client);

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_BS_ENDMISS);
	}

	return Plugin_Handled;
}

public Action:BioShieldmissCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	BioShieldmissCDTimer[Client] = INVALID_HANDLE;
	IsBioShieldmissReady[Client] = true;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_BSMISS_CHARGED);
	}

	return Plugin_Handled;
}

/* 超级狂飙模式 */
public Action:UseBioShieldkb(Client, args)
{
	if(GetClientTeam(Client) == 2) BioShieldkbFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:BioShieldkbFunction(Client)
{
	if(JD[Client] != 2)
	{
		CPrintToChat(Client, MSG_NEED_JOB2);
		return Plugin_Handled;
	}

	if(BioShieldkbLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_23);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsBioShieldkbEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_BS_ENABLEDKB);
		return Plugin_Handled;
	}

	if(!IsBioShieldkbReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(MP_ChainkbLightning > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_ChainkbLightning, MP[Client]);
		return Plugin_Handled;
	}

	IsBioShieldkbEnable[Client] = true;
	MP[Client] -= MP_ChainkbLightning;

	SetEntProp(Client, Prop_Data, "m_takedamage", 0, 1);
	BioShieldkbDurationTimer[Client] = CreateTimer(BioShieldkbDuration[Client], BioShieldkbDurationFunction, Client);

	CPrintToChatAll(MSG_SKILL_BS_ANNOUNCEKB, Client, BioShieldkbLv[Client], HealingkbFunction(Client));

	//PrintToserver("[United RPG] %s启动超级狂飙模式!粉碎的愤怒", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:BioShieldkbDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	BioShieldkbDurationTimer[Client] = INVALID_HANDLE;
	IsBioShieldkbEnable[Client] = false;
	if(IsValidPlayer(Client))	SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);

	IsBioShieldkbReady[Client] = false;
	BioShieldkbCDTimer[Client] = CreateTimer(BioShieldkbCDTime[Client], BioShieldkbCDTimerFunction, Client);

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_BS_ENDKB);
	}

	return Plugin_Handled;
}

public Action:BioShieldkbCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	BioShieldkbCDTimer[Client] = INVALID_HANDLE;
	IsBioShieldkbReady[Client] = true;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_BS_CHARGEDKB);
	}

	return Plugin_Handled;
}

/* 反伤术 */
public Action:UseDamageReflect(Client, args)
{
	if(GetClientTeam(Client) == 2) DamageReflectFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:DamageReflectFunction(Client)
{
	if(JD[Client] != 3)
	{
		CPrintToChat(Client, MSG_NEED_JOB3);
		return Plugin_Handled;
	}

	if(DamageReflectLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_10);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsDamageReflectEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_DR_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_DamageReflect) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_DamageReflect), MP[Client]);
		return Plugin_Handled;
	}

	if(IsBioShieldEnable[Client])
	{
		PrintHintText(Client, MSG_SKILL_BS_NO_SKILL);
		return Plugin_Handled;
	}

	new HP = GetClientHealth(Client);
	new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");

	if(HP > MaxHP*DamageReflectSideEffect[Client])
	{
		IsDamageReflectEnable[Client] = true;
		MP[Client] -= GetConVarInt(Cost_DamageReflect);

		SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HP - MaxHP*DamageReflectSideEffect[Client]));
		DamageReflectDurationTimer[Client] = CreateTimer(DamageReflectDuration[Client], DamageReflectDurationFunction, Client);

		CPrintToChatAll(MSG_SKILL_DR_ANNOUNCE, Client, RoundToNearest(MaxHP*DamageReflectSideEffect[Client]),DamageReflectLv[Client]);

		//PrintToserver("[United RPG] %s启动了反伤术!", NameInfo(Client, simple));
	}
	else CPrintToChat(Client, MSG_SKILL_DR_NEED_HP);
	return Plugin_Handled;
}

public Action:DamageReflectDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	DamageReflectDurationTimer[Client] = INVALID_HANDLE;
	IsDamageReflectEnable[Client] = false;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_DR_END);
	}

	return Plugin_Handled;
}

/* 近战嗜血术 */
public Action:UseMeleeSpeed(Client, args)
{
	if(GetClientTeam(Client) == 2) MeleeSpeedFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:MeleeSpeedFunction(Client)
{
	if(JD[Client] != 3)
	{
		CPrintToChat(Client, MSG_NEED_JOB3);
		return Plugin_Handled;
	}

	if(MeleeSpeedLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_11);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsMeleeSpeedEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_MS_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_MeleeSpeed) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_MeleeSpeed), MP[Client]);
		return Plugin_Handled;
	}

	if(IsBioShieldEnable[Client])
	{
		PrintHintText(Client, MSG_SKILL_BS_NO_SKILL);
		return Plugin_Handled;
	}

	IsMeleeSpeedEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_MeleeSpeed);

	MeleeSpeedDurationTimer[Client] = CreateTimer(MeleeSpeedDuration[Client], MeleeSpeedDurationFunction, Client);

	CPrintToChatAll(MSG_SKILL_MS_ANNOUNCE, Client, MeleeSpeedLv[Client]);

	//PrintToserver("[United RPG] %s启动近战嗜血术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:MeleeSpeedDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	MeleeSpeedDurationTimer[Client] = INVALID_HANDLE;
	IsMeleeSpeedEnable[Client] = false;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MS_END);
	}

	return Plugin_Handled;
}

/* 卫星轨道炮 */
public Action:UseSatelliteCannon(Client, args)
{
	if(GetClientTeam(Client) == 2) SatelliteCannonFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:SatelliteCannonFunction(Client)
{
	if(JD[Client] != 1)
	{
		CPrintToChat(Client, MSG_NEED_JOB1);
		return Plugin_Handled;
	}

	if(SatelliteCannonLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_14);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(!IsSatelliteCannonReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_SatelliteCannon) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_SatelliteCannon), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_SatelliteCannon);

	new Float:Radius=float(SatelliteCannonRadius[Client]);
	new Float:pos[3];
	GetTracePosition(Client, pos);
	EmitAmbientSound(SOUND_TRACING, pos);
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonLaunchTime, 5.0, 0.0, BlueColor, 10, 0);//固定外圈BuleColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, Radius, 0.1, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonLaunchTime, 5.0, 0.0, RedColor, 10, 0);//扩散内圈RedColor
	TE_SendToAll();

	IsSatelliteCannonReady[Client] = false;

	new Handle:pack;
	CreateDataTimer(SatelliteCannonLaunchTime, SatelliteCannonTimerFunction, pack);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);

	CPrintToChatAll(MSG_SKILL_SC_ANNOUNCE, Client, SatelliteCannonLv[Client]);

	//PrintToserver("[United RPG] %s启动了暗夜直射!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:SatelliteCannonTimerFunction(Handle:timer, Handle:pack)
{
	new Client;
	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=float(SatelliteCannonRadius[Client]);

	ResetPack(pack);
	Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);

	CreateLaserEffect(Client, pos, 230, 230, 80, 230, 6.0, 1.0, LASERMODE_VARTICAL);

	/* Explode */
	LittleFlower(pos, EXPLODE, Client);
	ShowParticle(pos, PARTICLE_SCEFFECT, 10.0);
	EmitAmbientSound(SatelliteCannon_Sound_Launch, pos);

	for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, SatelliteCannonDamage[Client], 0, "satellite_cannon");
				}
			} else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, SatelliteCannonSurvivorDamage[Client], 0, "satellite_cannon");
				}
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
        if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
        {
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(Client, iEntity, RoundToNearest(SatelliteCannonDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0, "satellite_cannon");
			}
		}
	}

	PointPush(Client, pos, SatelliteCannonDamage[Client], SatelliteCannonRadius[Client], 0.5);

	SatelliteCannonCDTimer[Client] = CreateTimer(SatelliteCannonCDTime[Client], SatelliteCannonCDTimerFunction, Client);
}
public Action:SatelliteCannonCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	SatelliteCannonCDTimer[Client] = INVALID_HANDLE;
	IsSatelliteCannonReady[Client] = true;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_SC_CHARGED);
	}

	return Plugin_Handled;
}

/* 武者之光 */
public Action:UseWZZG(Client, args)
{
	if(GetClientTeam(Client) == 2) WZZGFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:WZZGFunction(Client)
{
	if(JD[Client] != 12)
	{
		CPrintToChat(Client, MSG_NEED_JOB12);
		return Plugin_Handled;
	}

	if(WZZGLv[Client] == 0)
	{
		CPrintToChat(Client, "你没有学习武者之光");
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(!IsWZZGmissReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_WZZG) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_WZZG), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_WZZG);

	new Float:pos[3];
	GetTracePosition(Client, pos);
	EmitAmbientSound(SOUND_TRACINGMISS, pos);

	IsWZZGmissReady[Client] = false;

	new Handle:pack;
	CreateDataTimer(WZZGLaunchTime, WZZGTimerFunction, pack);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);

	CPrintToChatAll(MSG_SKILL_SCDEA_ANNOUNCEMISS, Client, WZZGLv[Client]);

	return Plugin_Handled;
}

public Action:WZZGTimerFunction(Handle:timer, Handle:pack)
{
	new Client;
	new Float:distance;
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];

	ResetPack(pack);
	Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);

	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, RedColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, RedColor, 0);
	TE_SendToAll();


	/* Explode */
	LittleFlower(pos, EXPLODE, Client);
	EmitAmbientSound(WZZG_Sound_Launch, pos);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(0.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(1.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(2.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(3.8);
	for (new i = 1; i <= MaxClients; i++)
    {
        if (IsValidPlayer(i))
        {
			if(GetClientTeam(i) != GetClientTeam(Client) && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= WZZGRadius[Client])
					DealDamage(Client, i, WZZGDamage[Client], 0, "satellite_cannonmiss");

			}
			else if(IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= WZZGRadius[Client])
					DealDamage(Client, i, WZZGSurvivorDamage[Client], 0, "satellite_cannonmiss");
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
        if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
        {
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if(distance <= WZZGRadius[Client])
				DealDamage(Client, iEntity, RoundToNearest(WZZGDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0, "satellite_cannonmiss");
		}
	}

	WZZGmissCDTimer[Client] = CreateTimer(WZZGCDTime[Client], WZZGCDTimerFunction, Client);
}
public Action:WZZGCDTimerFunction(Handle:timer, any:Client)
{
	WZZGmissCDTimer[Client] = INVALID_HANDLE;
	IsWZZGmissReady[Client] = true;

	if (IsValidPlayer(Client))
		CPrintToChat(Client, MSG_SKILL_SCDEA_CHARGEDMISS);

	KillTimer(timer);
}


/* 毒龙之光 */
public Action:UseDSZG(Client, args)
{
	if(GetClientTeam(Client) == 2) DSZGFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:DSZGFunction(Client)
{
	if(JD[Client] != 14)
	{
		CPrintToChat(Client, MSG_NEED_JOB14);
		return Plugin_Handled;
	}

	if(DSZGLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_40);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(!IsDSZGmissReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_DSZG) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_DSZG), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_DSZG);

	new Float:pos[3];
	GetTracePosition(Client, pos);
	EmitAmbientSound(SOUND_TRACINGMISS, pos);

	IsDSZGmissReady[Client] = false;

	new Handle:pack;
	CreateDataTimer(DSZGLaunchTime, DSZGTimerFunction, pack);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);

	CPrintToChatAll(MSG_SKILL_SCDE_ANNOUNCEMISS, Client, DSZGLv[Client]);

	return Plugin_Handled;
}

public Action:DSZGTimerFunction(Handle:timer, Handle:pack)
{
	new Client;
	new Float:distance;
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];

	ResetPack(pack);
	Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);

	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();


	/* Explode */
	LittleFlower(pos, EXPLODE, Client);
	EmitAmbientSound(YLTJ_Sound_Launch, pos);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(0.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(1.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(2.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(3.8);
	for (new i = 1; i <= MaxClients; i++)
    {
        if (IsValidPlayer(i))
        {
			if(GetClientTeam(i) != GetClientTeam(Client) && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= DSZGRadius[Client])
				DealDamage(Client, i, DSZGDamage[Client], 0, "satellite_cannonmiss");

			}
			else if(IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= DSZGRadius[Client])
					DealDamage(Client, i, DSZGSurvivorDamage[Client], 0, "satellite_cannonmiss");
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
        if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
        {
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if(distance <= DSZGRadius[Client])
				DealDamage(Client, iEntity, RoundToNearest(DSZGDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0, "satellite_cannonmiss");
		}
	}

	DSZGmissCDTimer[Client] = CreateTimer(DSZGCDTime[Client], DSZGCDTimerFunction, Client);
}
public Action:DSZGCDTimerFunction(Handle:timer, any:Client)
{
	DSZGmissCDTimer[Client] = INVALID_HANDLE;
	IsDSZGmissReady[Client] = true;

	if (IsValidPlayer(Client))
		CPrintToChat(Client, MSG_SKILL_SCDE_CHARGEDMISS);

	KillTimer(timer);
}

/* 致命闪电 */
public Action:UseYLTJ(Client, args)
{
	if(GetClientTeam(Client) == 2) YLTJFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:YLTJFunction(Client)
{
	if(JD[Client] != 11)
	{
		CPrintToChat(Client, MSG_NEED_JOB11);
		return Plugin_Handled;
	}

	if(YLTJLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_32);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(!IsYLTJmissReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_YLTJ) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_YLTJ), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_YLTJ);

	new Float:pos[3];
	GetTracePosition(Client, pos);
	EmitAmbientSound(SOUND_TRACINGMISS, pos);
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, YLTJRadius[Client]-640.1, YLTJRadius[Client]-640.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, BlueColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, YLTJRadius[Client]-480.1, YLTJRadius[Client]-480.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, PurpleColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, YLTJRadius[Client]-320.1, YLTJRadius[Client]-320.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, ClaretColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, YLTJRadius[Client]-160.1, YLTJRadius[Client]-160.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, GreenColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, YLTJRadius[Client]-640.1, YLTJRadius[Client]-640.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, BlueColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, YLTJRadius[Client]-480.1, YLTJRadius[Client]-480.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, PurpleColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, YLTJRadius[Client]-320.1, YLTJRadius[Client]-320.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, ClaretColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, YLTJRadius[Client]-160.1, YLTJRadius[Client]-160.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, GreenColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();

	IsYLTJmissReady[Client] = false;

	new Handle:pack;
	CreateDataTimer(YLTJLaunchTime, YLTJTimerFunction, pack);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);

	CPrintToChatAll(MSG_SKILL_SCD_ANNOUNCEMISS, Client, YLTJLv[Client]);

	return Plugin_Handled;
}

public Action:YLTJTimerFunction(Handle:timer, Handle:pack)
{
	new Client;
	new Float:distance;
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];

	ResetPack(pack);
	Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);

	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, WhiteColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, WhiteColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 2.0, 2.0, 1, 6.0, WhiteColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 2.0, 2.0, 1, 6.0, WhiteColor, 0);
	TE_SendToAll();


	/* Explode */
	LittleFlower(pos, EXPLODE, Client);
	EmitAmbientSound(YLTJ_Sound_Launch, pos);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(0.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(1.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(2.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(3.8);
	for (new i = 1; i <= MaxClients; i++)
    {
        if (IsValidPlayer(i))
        {
			if(GetClientTeam(i) != GetClientTeam(Client) && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= YLTJRadius[Client])
					DealDamage(Client, i, YLTJDamage[Client], 0, "satellite_cannonmiss");

			}
			else if(IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= YLTJRadius[Client])
					DealDamage(Client, i, YLTJSurvivorDamage[Client], 0, "satellite_cannonmiss");
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
        if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
        {
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if(distance <= YLTJRadius[Client])
				DealDamage(Client, iEntity, RoundToNearest(YLTJDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0, "satellite_cannonmiss");
		}
	}

	YLTJmissCDTimer[Client] = CreateTimer(YLTJCDTime[Client], YLTJCDTimerFunction, Client);
}
public Action:YLTJCDTimerFunction(Handle:timer, any:Client)
{
	YLTJmissCDTimer[Client] = INVALID_HANDLE;
	IsYLTJmissReady[Client] = true;

	if (IsValidPlayer(Client))
		CPrintToChat(Client, MSG_SKILL_SCD_CHARGEDMISS);

	KillTimer(timer);
}

/* 使用_嗜血之光 */
public Action:UseSXZG(Client, args)
{
	if(GetClientTeam(Client) == 2) SXZG(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Handled;
}

/* 嗜血之光 */
public Action:SXZG(Client)
{

	if(JD[Client] != 14)
	{
		CPrintToChat(Client, MSG_NEED_JOB14);
		return Plugin_Handled;
	}

	if(SXZGLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_38);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsSXZGEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_SXZG) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_SXZG), MP[Client]);
		return Plugin_Handled;
	}

	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	new Float:TracePos[3];
	new Float:EyePos[3];
	new Float:Angle[3];
	new Float:TempPos[3];
	new Float:velocity[3];
	new Handle:data;
	new entity = CreateEntityByName("tank_rock");
	GetTracePosition(Client, TracePos);
	GetClientEyePosition(Client, EyePos);
	MakeVectorFromPoints(EyePos, TracePos, Angle);
	NormalizeVector(Angle, Angle);

	TempPos[0] = Angle[0] * 50;
	TempPos[1] = Angle[1] * 50;
	TempPos[2] = Angle[2] * 50;
	AddVectors(EyePos, TempPos, EyePos);

	velocity[0] = Angle[0] * 500;
	velocity[1] = Angle[1] * 500;
	velocity[2] = Angle[2] * 500;

	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		IsSXZGEnable[Client] = true;
		//初始发射音效
		EmitAmbientSound(HealingBall_Sound_Lanuch, EyePos);
		//实体属性设置
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", Client);
		DispatchSpawn(entity);
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 255, 255, 255, 0);
		SetEntityGravity(entity, 0.1);
		SetEntProp(entity, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(entity, Prop_Data, "m_MoveCollide", 0);
		TE_SetupBeamFollow(entity, g_BeamSprite, g_HaloSprite, 5.0, 5.0, 2.0, 1, RedColor); //光束
		TE_SendToAll();
		TeleportEntity(entity, EyePos, Angle, velocity);
		//计时器创建
		CreateTimer(5.0, Timer_SXZGCooling, Client);
		CreateTimer(10.0, Timer_RemoveSXZG, entity);
		CreateDataTimer(0.1, Timer_SXZG, data, TIMER_REPEAT);
		WritePackCell(data, entity);
		WritePackFloat(data, Angle[0]);
		WritePackFloat(data, Angle[1]);
		WritePackFloat(data, Angle[2]);
		WritePackFloat(data, velocity[0]);
		WritePackFloat(data, velocity[1]);
		WritePackFloat(data, velocity[2]);
	}


	CPrintToChatAll(MSG_SKILL_LBD_ANNOUNCE, Client, SXZGLv[Client]);
	MP[Client] -= GetConVarInt(Cost_SXZG);
	return Plugin_Handled;
}

/* 光球跟踪实体计时器 */
public Action:Timer_SXZG(Handle:timer, Handle:data)
{
	new Float:pos[3];
	new Float:Angle[3];
	new Float:velocity[3];
	ResetPack(data);
	new entity = ReadPackCell(data);
	Angle[0] = ReadPackFloat(data);
	Angle[1] = ReadPackFloat(data);
	Angle[2] = ReadPackFloat(data);
	velocity[0] = ReadPackFloat(data);
	velocity[1] = ReadPackFloat(data);
	velocity[2] = ReadPackFloat(data);

	if (!IsValidEntity(entity) || !IsValidEdict(entity))
		return Plugin_Stop;

	for (new i = 1; i <= 5; i++)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		TeleportEntity(entity, pos, Angle, velocity);
		TE_SetupGlowSprite(pos, g_GlowSprite, 0.1, 4.0, 500);
		TE_SendToAll();
	}

	if (DistanceToHit(entity) <= 200)
	{
		CreateTimer(0.1, Timer_RemoveSXZG, entity);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

/* 删除嗜血之光计时器 */
public Action:Timer_RemoveSXZG(Handle:timer, any:entity)
{
	new Player;
	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new MaxEnt = GetMaxEntities();
	SXZGReward[Player] = 0;

	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
		Player = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	if (IsValidPlayer(Player) && IsValidEntity(entity) && IsValidEdict(entity))
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		EmitAmbientSound(HealingBall_Sound_Heal, pos);
		//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
		TE_SetupBeamRingPoint(pos, 0.1, 100.0, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 10.0, 0.0, PurpleColor, 10, 0);
		TE_SendToAll();

		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsValidPlayer(i) || !IsValidEntity(i) || !IsValidEdict(i))
				continue;

			GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= 200)
			{
				if (GetClientTeam(i) == GetClientTeam(Player))
				{
					DealCureS(Player, i, SXZGHealth[Player]);
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, GreenColor, 0);
					TE_SendToAll();
					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, GreenColor, 10, 0);
					TE_SendToAll();
				}
				else
				{
					DealDamage(Player, i, SXZGDamage[Player], 0);
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, GreenColor, 0);
					TE_SendToAll();
					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, GreenColor, 10, 0);
					TE_SendToAll();
				}
			}
		}

		for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
		{
			if(IsValidEntity(iEnt) && IsValidEdict(iEnt) && IsCommonInfected(iEnt) && GetEntProp(iEnt, Prop_Data, "m_iHealth") > 0)
			{
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if (distance <= 200)
				{
					DealDamage(Player, iEnt, SXZGDamage[Player], 0);
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, GreenColor, 0);
					TE_SendToAll();
					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, GreenColor, 10, 0);
					TE_SendToAll();
				}
			}

		}

		//治愈经验
		DealCureOvers(Player);
		//删除实体
		RemoveEdict(entity);
	}
}

/* 治愈效果 */
public DealCureS(Client, Target, Cure_Health)
{
	if (!IsValidPlayer(Client) || !IsValidEntity(Client) || !IsPlayerAlive(Client) || !IsValidPlayer(Target) || !IsValidEntity(Target) || !IsPlayerAlive(Target))
		return;

	new health = GetClientHealth(Target);
	new maxhealth = GetEntProp(Target, Prop_Data, "m_iMaxHealth");

	if (!IsPlayerIncapped(Target))
	{
		if (health + Cure_Health > maxhealth)
		{
			SXZGReward[Client] += maxhealth - health;
			health = maxhealth;
		}
		else
		{
			SXZGReward[Client] += Cure_Health;
			health = health + Cure_Health;
		}

		SetEntProp(Target, Prop_Data, "m_iHealth", health);
	}
	else if (IsPlayerIncapped(Target))
	{
		if (health + Cure_Health > 300)
		{
			SXZGReward[Client] += 300 - health;
			health = 300;
		}
		else
		{
			SXZGReward[Client] += Cure_Health;
			health = health + Cure_Health;
		}

		SetEntProp(Target, Prop_Data, "m_iHealth", health);
	}
}

/* 治愈效果_结束 */
public DealCureOvers(Client)
{
	if (!IsValidPlayer(Client) || !IsValidEntity(Client) || !IsPlayerAlive(Client))
	{
		SXZGReward[Client] = 0;
		return;
	}

	if (SXZGReward[Client] > 0)
	{
		new giveexp = RoundToNearest(SXZGReward[Client] * SXZGExp);
		new givecash = RoundToNearest(SXZGReward[Client] * SXZGCash);
		EXP[Client] += giveexp + VIPAdd(Client, giveexp, 1, true);
		Cash[Client] += givecash + VIPAdd(Client, givecash, 1, false);
		CPrintToChat(Client, MSG_SKILL_LBD_END, SXZGReward[Client], giveexp, givecash);
		SXZGReward[Client] = 0;
	}
}

/* 嗜血之光冷却 */
public Action:Timer_SXZGCooling(Handle:timer, any:Client)
{
	IsSXZGEnable[Client] = false;
}

/* 终极雷矢 */
public Action:UseSatelliteCannonmiss(Client, args)
{
	if(GetClientTeam(Client) == 2) SatelliteCannonmissFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:SatelliteCannonmissFunction(Client)
{
	if(JD[Client] != 5)
	{
		CPrintToChat(Client, MSG_NEED_JOB5);
		return Plugin_Handled;
	}

	if(SatelliteCannonmissLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_21);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(!IsSatelliteCannonmissReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(MP[Client] != MaxMP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MaxMP[Client], MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_SatelliteCannonmiss);

	new Float:pos[3];
	GetTracePosition(Client, pos);
	EmitAmbientSound(SOUND_TRACINGMISS, pos);
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, SatelliteCannonmissRadius[Client]-0.1, SatelliteCannonmissRadius[Client], g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 15.0, 4.0, WhiteColor, 15, 0);//电流外圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, SatelliteCannonmissRadius[Client]-0.1, SatelliteCannonmissRadius[Client], g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 13.0, WhiteColor, 18, 0);//电流外圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, SatelliteCannonmissRadius[Client]-640.1, SatelliteCannonmissRadius[Client]-640.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, WhiteColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, SatelliteCannonmissRadius[Client]-480.1, SatelliteCannonmissRadius[Client]-480.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, WhiteColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, SatelliteCannonmissRadius[Client]-320.1, SatelliteCannonmissRadius[Client]-320.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, WhiteColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, SatelliteCannonmissRadius[Client]-160.1, SatelliteCannonmissRadius[Client]-160.2, g_BeamSprite, g_HaloSprite, 0, 15, SatelliteCannonmissLaunchTime, 1.0, 9.0, WhiteColor, 15, 0);//电流内圈WhiteColor
	TE_SendToAll();

	IsSatelliteCannonmissReady[Client] = false;

	new Handle:pack;
	CreateDataTimer(SatelliteCannonmissLaunchTime, CannonmissTimerFunction, pack);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);

	CPrintToChatAll(MSG_SKILL_SC_ANNOUNCEMISS, Client, SatelliteCannonmissLv[Client]);

	//PrintToserver("[United RPG] %s启动了终极雷矢!感染者的末日!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:CannonmissTimerFunction(Handle:timer, Handle:pack)
{
	new Client;
	new Float:distance;
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];

	ResetPack(pack);
	Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);

	new Float:SkyLocation[3];
	SkyLocation[0] = pos[0];
	SkyLocation[1] = pos[1];
	SkyLocation[2] = pos[2] + 2000.0;
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 20.0, 20.0, 10, 10.0, WhiteColor, 0);
	TE_SendToAll();

	/* Explode */
	LittleFlower(pos, EXPLODE, Client);
	EmitAmbientSound(SatelliteCannonmiss_Sound_Launch, pos);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(0.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(1.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(2.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(3.8);
	for (new i = 1; i <= MaxClients; i++)
    {
        if (IsValidPlayer(i))
        {
			if(GetClientTeam(i) != GetClientTeam(Client) && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= SatelliteCannonmissRadius[Client])
					DealDamage(Client, i, SatelliteCannonmissDamage[Client], 0, "satellite_cannonmiss");

			}
			else if(IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= SatelliteCannonmissRadius[Client])
					DealDamage(Client, i, SatelliteCannonmissSurvivorDamage[Client], 0, "satellite_cannonmiss");
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
        if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
        {
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if(distance <= SatelliteCannonmissRadius[Client])
				DealDamage(Client, iEntity, RoundToNearest(SatelliteCannonmissDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0, "satellite_cannonmiss");
		}
	}

	SatelliteCannonmissCDTimer[Client] = CreateTimer(SatelliteCannonmissCDTime[Client], CannonmissCDTimerFunction, Client);
}
public Action:CannonmissCDTimerFunction(Handle:timer, any:Client)
{
	SatelliteCannonmissCDTimer[Client] = INVALID_HANDLE;
	IsSatelliteCannonmissReady[Client] = true;

	if (IsValidPlayer(Client))
		CPrintToChat(Client, MSG_SKILL_SC_CHARGEDMISS);

	KillTimer(timer);
}

//冰之传送
public Action:UseTeleportToSelect(Client, args)
{
	if(GetClientTeam(Client) == 2) TeleportToSelectMenu(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Handled;
}

public Action:TeleportToSelectMenu(Client)
{
	if(JD[Client] != 4)
	{
		CPrintToChat(Client, MSG_NEED_JOB4);
		return Plugin_Handled;
	}

	if(TeleportToSelectLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_7);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsTeleportToSelectEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_TeleportToSelect) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_TeleportToSelect), MP[Client]);
		return Plugin_Handled;
	}

	new Handle:menu = CreateMenu(TeleportToSelectMenu_Handler);

	new incapped=0, dead=0, alive=0;

	for (new x=1; x<=MaxClients; x++)
	{
		if (!IsClientInGame(x)) continue;
		if (GetClientTeam(x)!=2) continue;
		if (x==Client) continue;
		if (!IsPlayerAlive(x)) continue;//过滤死亡的玩家
		if (!IsPlayerIncapped(x)) continue;//过滤没有倒地的玩家
		incapped++;
	}
	for (new c=1; c<=MaxClients; c++)
	{
		if (!IsClientInGame(c)) continue;
		if (GetClientTeam(c)!=2) continue;
		if (c==Client) continue;
		if (IsPlayerAlive(c)) continue;//过滤活着的玩家
		dead++;
	}
	for (new v=1; v<=MaxClients; v++)
	{
		if (!IsClientInGame(v)) continue;
		if (GetClientTeam(v)!=2) continue;
		if (v==Client) continue;
		if (!IsPlayerAlive(v)) continue;//过滤死亡的玩家
		if (IsPlayerIncapped(v)) continue;//过滤倒地的玩家
		alive++;
	}

	SetMenuTitle(menu, "选择传送至");

	decl String:Incapped[64], String:Dead[64], String:Alive[64];

	if (incapped==0)
		Format(Incapped, sizeof(Incapped), "没有倒下的队友");
	else
		Format(Incapped, sizeof(Incapped), "倒下的队友(%d个)", incapped);
	if (dead==0)
		Format(Dead, sizeof(Dead), "没有死亡的队友");
	else
		Format(Dead, sizeof(Dead), "死亡的队友(%d个)", dead);
	if (alive==0)
		Format(Alive, sizeof(Alive), "没有活着的队友");
	else
		Format(Alive, sizeof(Alive), "活着的队友(%d个)", alive);

	AddMenuItem(menu, "option1", "刷新列表");
	AddMenuItem(menu, "option2", Incapped);
	AddMenuItem(menu, "option3", Dead);
	AddMenuItem(menu, "option4", Alive);

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, 20);

	return Plugin_Handled;
}

public Action:TCCharging(Handle:timer, any:Client)
{
	KillTimer(timer);
	TCChargingTimer[Client] = INVALID_HANDLE;
	IsTeleportToSelectEnable[Client] = false;

	if (IsValidPlayer(Client) && !IsFakeClient(Client))
	{
		CPrintToChat(Client, MSG_SKILL_TC_CHARGED);
	}

	return Plugin_Handled;
}

new t_id[MAXPLAYERS+1];
public TeleportToSelectMenu_Handler(Handle:menu, MenuAction:action, Client, itemNum)
{
	if(action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 0: TeleportToSelectMenu(Client);
			case 1: t_id[Client]=1, TeleportToSelect(Client);
			case 2: t_id[Client]=2, TeleportToSelect(Client);
			case 3: t_id[Client]=3, TeleportToSelect(Client);
		}
	} else if (action == MenuAction_End)	CloseHandle(menu);
}

public Action:TeleportToSelect(Client)
{
	new Handle:menu = CreateMenu(TeleportToSelect_Handler);
	if (t_id[Client]==1) SetMenuTitle(menu, "倒下的队友");
	if (t_id[Client]==2) SetMenuTitle(menu, "死亡的队友");
	if (t_id[Client]==3) SetMenuTitle(menu, "活着的队友");

	decl String:user_id[12];
	decl String:display[MAX_NAME_LENGTH+12];

	for (new x=1; x<=MaxClients; x++)
	{
		if (!IsClientInGame(x)) continue;
		if (GetClientTeam(x)!=2) continue;
		if (x==Client) continue;
		if (t_id[Client]==1)
		{
			if (!IsPlayerAlive(x)) continue;//过滤死亡的玩家
			if (!IsPlayerIncapped(x)) continue;//过滤没有倒地的玩家
			Format(display, sizeof(display), "%N", x);
		}
		if (t_id[Client]==2)
		{
			if (IsPlayerAlive(x)) continue;//过滤活着的玩家
			Format(display, sizeof(display), "%N", x);
		}
		if (t_id[Client]==3)
		{
			if (!IsPlayerAlive(x)) continue;//过滤死亡的玩家
			if (IsPlayerIncapped(x)) continue;//过滤倒地的玩家
			Format(display, sizeof(display), "%N", x);
		}

		IntToString(x, user_id, sizeof(user_id));
		AddMenuItem(menu, user_id, display);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public TeleportVFX(Float:Position0, Float:Position1, Float:Position2)
{
	decl Float:Position[3];
	new Float:TEradius=120.0, Float:TEinterval=0.01, Float:TEduration=1.0, Float:TEwidth=5.0, TEMax=30;

	Position[0]=Position0;
	Position[1]=Position1;

	for(new w=TEMax; w>0; w--)
	{
		Position[2]=Position2+w*TEwidth;
		TE_SetupBeamRingPoint(Position, TEradius, TEradius+0.1, g_BeamSprite, g_HaloSprite, 0, 15,  TEduration, TEwidth, 0.0, CyanColor, 10, 0);
		TE_SendToAll(TEinterval*(TEMax-w));
	}
}

public TeleportToSelect_Handler(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		new String:info[56];
		GetMenuItem(menu, param, info, sizeof(info));
		/* 获得所选择的玩家 */
		new target = StringToInt(info);
		if(target == -1 || !IsClientInGame(target))
		{
			CPrintToChat(Client, "{green}[UnitedRPG] %t", "Player no longer available");
			return;
		}

		decl Float:TeleportOrigin[3],Float:PlayerOrigin[3];
		GetClientAbsOrigin(target, PlayerOrigin);
		TeleportOrigin[0] = PlayerOrigin[0];
		TeleportOrigin[1] = PlayerOrigin[1];
		TeleportOrigin[2] = (PlayerOrigin[2]+0.1);//防止卡人

		//防止重复使用技能使黑屏效果消失
		if(FadeBlackTimer[Client] != INVALID_HANDLE)
		{
			KillTimer(FadeBlackTimer[Client]);
			FadeBlackTimer[Client] = INVALID_HANDLE;
		}

		PerformFade(Client, 200);
		FadeBlackTimer[Client] = CreateTimer(10.0, PerformFadeNormal, Client);
		TCChargingTimer[Client] = CreateTimer(205.0 - TeleportToSelectLv[Client]*5, TCCharging, Client);

		TeleportEntity(Client, TeleportOrigin, NULL_VECTOR, NULL_VECTOR);
		EmitSoundToAll(TSOUND, Client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, TeleportOrigin, NULL_VECTOR, true, 0.0);

		TeleportVFX(TeleportOrigin[0], TeleportOrigin[1], TeleportOrigin[2]);

		IsTeleportToSelectEnable[Client] = true;

		MP[Client] -= GetConVarInt(Cost_TeleportToSelect);

		if (t_id[Client]==2)
		{
			CPrintToChat(Client, MSG_SKILL_TC_ANNOUNCE2, target);
			//PrintToserver("[United RPG] %s使用心灵传输到了队友%s的尸体旁!", NameInfo(Client, simple), NameInfo(target, simple));
		} else
		{
			CPrintToChat(Client, MSG_SKILL_TC_ANNOUNCE, target);
			//PrintToserver("[United RPG] %s使用心灵传输到了队友%s的身边!", NameInfo(Client, simple), NameInfo(target, simple));
		}
	} else if (action == MenuAction_End)	CloseHandle(menu);
}

/* 使用_嗜血光球术 */
public Action:UseHolyBolt(Client, args)
{
	if(GetClientTeam(Client) == 2) LightBall(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Handled;
}

/* 嗜血光球术 */
public Action:LightBall(Client)
{

	if(JD[Client] != 4)
	{
		CPrintToChat(Client, MSG_NEED_JOB4);
		return Plugin_Handled;
	}

	if(HolyBoltLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_8);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsHolyBoltEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_HolyBolt) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_HolyBolt), MP[Client]);
		return Plugin_Handled;
	}

	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	new Float:TracePos[3];
	new Float:EyePos[3];
	new Float:Angle[3];
	new Float:TempPos[3];
	new Float:velocity[3];
	new Handle:data;
	new entity = CreateEntityByName("tank_rock");
	GetTracePosition(Client, TracePos);
	GetClientEyePosition(Client, EyePos);
	MakeVectorFromPoints(EyePos, TracePos, Angle);
	NormalizeVector(Angle, Angle);

	TempPos[0] = Angle[0] * 50;
	TempPos[1] = Angle[1] * 50;
	TempPos[2] = Angle[2] * 50;
	AddVectors(EyePos, TempPos, EyePos);

	velocity[0] = Angle[0] * 500;
	velocity[1] = Angle[1] * 500;
	velocity[2] = Angle[2] * 500;

	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		IsHolyBoltEnable[Client] = true;
		//初始发射音效
		EmitAmbientSound(HealingBall_Sound_Lanuch, EyePos);
		//实体属性设置
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", Client);
		DispatchSpawn(entity);
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 255, 255, 255, 0);
		SetEntityGravity(entity, 0.1);
		SetEntProp(entity, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(entity, Prop_Data, "m_MoveCollide", 0);
		TE_SetupBeamFollow(entity, g_BeamSprite, g_HaloSprite, 5.0, 5.0, 2.0, 1, CyanColor); //光束
		TE_SendToAll();
		TeleportEntity(entity, EyePos, Angle, velocity);
		//计时器创建
		CreateTimer(5.0, Timer_LightBallCooling, Client);
		CreateTimer(10.0, Timer_RemoveLightBall, entity);
		CreateDataTimer(0.1, Timer_LightBall, data, TIMER_REPEAT);
		WritePackCell(data, entity);
		WritePackFloat(data, Angle[0]);
		WritePackFloat(data, Angle[1]);
		WritePackFloat(data, Angle[2]);
		WritePackFloat(data, velocity[0]);
		WritePackFloat(data, velocity[1]);
		WritePackFloat(data, velocity[2]);
	}


	CPrintToChatAll(MSG_SKILL_LB_ANNOUNCE, Client, HolyBoltLv[Client]);
	MP[Client] -= GetConVarInt(Cost_HolyBolt);
	return Plugin_Handled;
}

/* 光球跟踪实体计时器 */
public Action:Timer_LightBall(Handle:timer, Handle:data)
{
	new Float:pos[3];
	new Float:Angle[3];
	new Float:velocity[3];
	ResetPack(data);
	new entity = ReadPackCell(data);
	Angle[0] = ReadPackFloat(data);
	Angle[1] = ReadPackFloat(data);
	Angle[2] = ReadPackFloat(data);
	velocity[0] = ReadPackFloat(data);
	velocity[1] = ReadPackFloat(data);
	velocity[2] = ReadPackFloat(data);

	if (!IsValidEntity(entity) || !IsValidEdict(entity))
		return Plugin_Stop;

	for (new i = 1; i <= 5; i++)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		TeleportEntity(entity, pos, Angle, velocity);
		TE_SetupGlowSprite(pos, g_GlowSprite, 0.1, 4.0, 500);
		TE_SendToAll();
	}

	if (DistanceToHit(entity) <= 200)
	{
		CreateTimer(0.1, Timer_RemoveLightBall, entity);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

/* 删除嗜血光球计时器 */
public Action:Timer_RemoveLightBall(Handle:timer, any:entity)
{
	new Player;
	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new MaxEnt = GetMaxEntities();
	LightBallReward[Player] = 0;

	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
		Player = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	if (IsValidPlayer(Player) && IsValidEntity(entity) && IsValidEdict(entity))
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		EmitAmbientSound(HealingBall_Sound_Heal, pos);
		//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
		TE_SetupBeamRingPoint(pos, 0.1, 100.0, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 10.0, 0.0, WhiteColor, 10, 0);
		TE_SendToAll();

		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsValidPlayer(i) || !IsValidEntity(i) || !IsValidEdict(i))
				continue;

			GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= 200)
			{
				if (GetClientTeam(i) == GetClientTeam(Player))
				{
					DealCure(Player, i, LightBallHealth[Player]);
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, WhiteColor, 0);
					TE_SendToAll();
					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, WhiteColor, 10, 0);
					TE_SendToAll();
				}
				else
				{
					DealDamage(Player, i, LightBallDamage[Player], 0);
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, RedColor, 0);
					TE_SendToAll();
					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, RedColor, 10, 0);
					TE_SendToAll();
				}
			}
		}

		for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
		{
			if(IsValidEntity(iEnt) && IsValidEdict(iEnt) && IsCommonInfected(iEnt) && GetEntProp(iEnt, Prop_Data, "m_iHealth") > 0)
			{
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if (distance <= 200)
				{
					DealDamage(Player, iEnt, LightBallDamage[Player], 0);
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, RedColor, 0);
					TE_SendToAll();
					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, RedColor, 10, 0);
					TE_SendToAll();
				}
			}

		}

		//治愈经验
		DealCureOver(Player);
		//删除实体
		RemoveEdict(entity);
	}
}

/* 治愈效果 */
public DealCure(Client, Target, Cure_Health)
{
	if (!IsValidPlayer(Client) || !IsValidEntity(Client) || !IsPlayerAlive(Client) || !IsValidPlayer(Target) || !IsValidEntity(Target) || !IsPlayerAlive(Target))
		return;

	new health = GetClientHealth(Target);
	new maxhealth = GetEntProp(Target, Prop_Data, "m_iMaxHealth");

	if (!IsPlayerIncapped(Target))
	{
		if (health + Cure_Health > maxhealth)
		{
			LightBallReward[Client] += maxhealth - health;
			health = maxhealth;
		}
		else
		{
			LightBallReward[Client] += Cure_Health;
			health = health + Cure_Health;
		}

		SetEntProp(Target, Prop_Data, "m_iHealth", health);
	}
	else if (IsPlayerIncapped(Target))
	{
		if (health + Cure_Health > 300)
		{
			LightBallReward[Client] += 300 - health;
			health = 300;
		}
		else
		{
			LightBallReward[Client] += Cure_Health;
			health = health + Cure_Health;
		}

		SetEntProp(Target, Prop_Data, "m_iHealth", health);
	}
}

/* 治愈效果_结束 */
public DealCureOver(Client)
{
	if (!IsValidPlayer(Client) || !IsValidEntity(Client) || !IsPlayerAlive(Client))
	{
		LightBallReward[Client] = 0;
		return;
	}

	if (LightBallReward[Client] > 0)
	{
		new giveexp = RoundToNearest(LightBallReward[Client] * LightBallExp);
		new givecash = RoundToNearest(LightBallReward[Client] * LightBallCash);
		EXP[Client] += giveexp + VIPAdd(Client, giveexp, 1, true);
		Cash[Client] += givecash + VIPAdd(Client, givecash, 1, false);
		CPrintToChat(Client, MSG_SKILL_LB_END, LightBallReward[Client], giveexp, givecash);
		LightBallReward[Client] = 0;
	}
}

/* 嗜血光球术冷却 */
public Action:Timer_LightBallCooling(Handle:timer, any:Client)
{
	IsHolyBoltEnable[Client] = false;
}

/* 单人传送 */
public Action:UseTeleportTeam(Client, args)
{
	if(GetClientTeam(Client) == 2) TeleportTeam(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Handled;
}

public Action:TeleportTeam(Client)
{
	if(JD[Client] != 4)
	{
		CPrintToChat(Client, MSG_NEED_JOB4);
		return Plugin_Handled;
	}

	if(TeleportTeamLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_9);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsTeleportTeamEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}
	if (GetConVarInt(Cost_TeleportTeammate) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_TeleportTeammate), MP[Client]);
		return Plugin_Handled;
	}

	if (!IsPlayerOnGround(Client))
	{
		CPrintToChat(Client, MSG_SKILL_TT_ON_GROUND);
		return Plugin_Handled;
	}
	new P;

	for(new X=1; X<=MaxClients; X++)
	{
		if (!IsValidEntity(X)) continue;
		if (!IsClientInGame(X)) continue;
		if (GetClientTeam(X)!=2) continue;
		if (!IsPlayerAlive(X)) continue;
		P = X;
	}

	if(P == -1)
	{
		CPrintToChat(Client, "{olive}找不到传送目标!");
		return Plugin_Handled;
	}

	new Handle:menu = CreateMenu(TeleportTeammate_Handler);
	SetMenuTitle(menu, "选择队友");

	decl String:user_id[12];
	decl String:display[MAX_NAME_LENGTH+12];

	for (new x=1; x<=MaxClients; x++)
	{
		if (!IsClientInGame(x)) continue;
		if (GetClientTeam(x)!=2) continue;
		if (x==Client) continue;
		if (!IsPlayerAlive(x)) continue;
		Format(display, sizeof(display), "%N", x);
		IntToString(x, user_id, sizeof(user_id));
		AddMenuItem(menu, user_id, display);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public TeleportTeammate_Handler(Handle:menu, MenuAction:action, Client, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));
		new target = StringToInt(info);
		if(target == -1 || !IsClientInGame(target))
		{
			CPrintToChat(Client, "{green}[UnitedRPG] %t", "Player no longer available");
			return;
		}

		decl Float:position[3];
		GetClientAbsOrigin(Client, position);

		//防止重复使用技能使黑屏效果消失
		if(FadeBlackTimer[target] != INVALID_HANDLE)
		{
			KillTimer(FadeBlackTimer[target]);
			FadeBlackTimer[target] = INVALID_HANDLE;
		}
		if(FadeBlackTimer[Client] != INVALID_HANDLE)
		{
			KillTimer(FadeBlackTimer[Client]);
			FadeBlackTimer[Client] = INVALID_HANDLE;
		}

		PerformFade(target, 200);
		PerformFade(Client, 200);
		FadeBlackTimer[target] = CreateTimer(10.0, PerformFadeNormal, target);
		FadeBlackTimer[Client] = CreateTimer(10.0, PerformFadeNormal, Client);

		TeleportEntity(target, position, NULL_VECTOR, NULL_VECTOR);
		EmitSoundToAll(TSOUND, target, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, position, NULL_VECTOR, true, 0.0);

		TeleportVFX(position[0], position[1], position[2]);

		TTChargingTimer[Client] = CreateTimer(210.0 - TeleportTeamLv[Client]*5, TTCharging, Client);

		IsTeleportTeamEnable[Client] = true;

		MP[Client] -= GetConVarInt(Cost_TeleportTeammate);

		CPrintToChatAll(MSG_SKILL_TT_ANNOUNCE_2, Client, target);

		//PrintToserver("[United RPG] %s使用心灵传输使队友%s回到他身边!", NameInfo(Client, simple), NameInfo(target, simple));
	} else if (action == MenuAction_End)	CloseHandle(menu);
}

public Action:TTCharging(Handle:timer, any:Client)
{
	KillTimer(timer);
	TTChargingTimer[Client] = INVALID_HANDLE;
	IsTeleportTeamEnable[Client] = false;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_TT_CHARGED);
	}
	return Plugin_Handled;
}

public Action:PerformFadeNormal(Handle:timer, any:Client)
{
	KillTimer(timer);
	FadeBlackTimer[Client] = INVALID_HANDLE;
	IsHolyBoltEnable[Client] = false;
	if(IsClientInGame(Client))	PerformFade(Client, 0);
	return Plugin_Handled;
}

public bool:TraceEntityFilterPlayers(entity, contentsMask, any:data)
{
	return entity > MaxClients && entity != data;
}

/* 吸引术 */
public Action:UseTeleportTeamzt(Client, args)
{
	if(GetClientTeam(Client) == 2) TeleportTeam(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Handled;
}


public Action:TeleportTeamzt(Client)
{
	if(JD[Client] != 4)
	{
		CPrintToChat(Client, MSG_NEED_JOB4);
		return Plugin_Handled;
	}

	if(TeleportTeamztLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_24);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsTeleportTeamztEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if (MP[Client] != MaxMP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MaxMP[Client], MP[Client]);
		return Plugin_Handled;
	}

	if (!IsPlayerOnGround(Client))
	{
		CPrintToChat(Client, MSG_SKILL_TT_ON_GROUND);
		return Plugin_Handled;
	}
	new P;

	for(new X=1; X<=MaxClients; X++)
	{
		if (!IsValidEntity(X)) continue;
		if (!IsClientInGame(X)) continue;
		P = X;
	}

	if(P == -1)
	{
		CPrintToChat(Client, "{olive}找不到传送目标!");
		return Plugin_Handled;
	}

	decl Float:position[3];
	for(new Player=1; Player<=P; Player++)
	{
		if (!IsClientInGame(Player)) continue;
		if (GetClientTeam(Player)!=2) continue;
		if (!IsPlayerAlive(Player)) continue;

		GetClientAbsOrigin(Client, position);

		TeleportEntity(Player, position, NULL_VECTOR, NULL_VECTOR);
		EmitSoundToAll(TSOUND, Player, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, position, NULL_VECTOR, true, 0.0);
	}

	TeleportVFX(position[0], position[1], position[2]);

	TTChargingztTimer[Client] = CreateTimer(280.0 - TeleportTeamztLv[Client]*5, TTChargingzt, Client);

	IsTeleportTeamztEnable[Client] = true;

	MP[Client] = 0;

	CPrintToChat(Client, MSG_SKILL_TT_ANNOUNCE, Client);

	//PrintToserver("[United RPG] %s使用吸引术使所有队友回到他身边!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:TTChargingzt(Handle:timer, any:Client)
{
	KillTimer(timer);
	TTChargingztTimer[Client] = INVALID_HANDLE;
	IsTeleportTeamztEnable[Client] = false;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_TT_CHARGEDZT);
	}
	return Plugin_Handled;
}

/* 黑屏效果 */
public PerformFade(Client, amount)
{
	new Handle:message = StartMessageOne("Fade",Client);
	BfWriteShort(message, 0);
	BfWriteShort(message, 0);
	if (amount == 0)
	{
		BfWriteShort(message, (0x0001 | 0x0010));
	}
	else
	{
		BfWriteShort(message, (0x0002 | 0x0008));
	}
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, amount);
	EndMessage();
}

/* 审判领域*/
public Action:UseAreaBlastingex(Client, args)
{
	if(GetClientTeam(Client) == 2) AreaBlastingex_Action(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public AreaBlastingex_Action(Client)
{
	if(JD[Client] != 7)
	{
		CPrintToChat(Client, MSG_NEED_JOB7);
		return;
	}

	if(AreaBlastingexLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_25);
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(AreaBlastingex[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return;
	}

	if(GetConVarInt(Cost_AreaBlastingex) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_AreaBlastingex), MP[Client]);
		return;
	}

	MP[Client] -= GetConVarInt(Cost_AreaBlastingex);
	AreaBlastingex[Client] = true;
	AreaBlastingexAttack(Client);
	CPrintToChatAll("{olive}[技能] {green}%N {blue}使用{green}Lv.%d{blue}的{olive}审判领域{blue}!", Client, AreaBlastingexLv[Client]);
	CreateTimer(AreaBlastingexCD[Client], AreaBlastingex_Stop, Client);
}

public AreaBlastingexAttack(Client)
{
	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new MaxEnt = GetMaxEntities();

	GetEntPropVector(Client, Prop_Send, "m_vecOrigin", pos);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || !IsValidEntity(i) || i == Client || GetClientTeam(i) == GetClientTeam(Client))
			continue;

		GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
		LittleFlower(pos, EXPLODE, Client);
		ShowParticle(pos, PARTICLE_SCEFFECT, 10.0);
		distance = GetVectorDistance(pos, entpos);
		if (distance <= AreaBlastingexRange[Client])
		{
			DealDamage(Client, i, AreaBlastingexDamage[Client], 0 , "fire_ball");
			new Float:Radius=float(AreaBlastingexRange[Client]);
			GetTracePosition(Client, pos);
			EmitAmbientSound(SatelliteCannon_Sound_Launch, pos);
			TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, AreaBlastingexLaunchTime, 15.0, 4.0, YellowColor, 15, 0);
			TE_SendToAll();
		}
	}

	for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
	{
		if(IsValidEntity(iEnt) && IsCommonInfected(iEnt))
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= AreaBlastingexRange[Client])
				DealDamage(Client, iEnt, AreaBlastingexDamage[Client], 0);
		}
	}
}

public Action:AreaBlastingex_Stop(Handle:timer, any:Client)
{
	if (AreaBlastingex[Client])
		AreaBlastingex[Client] = false;

	CPrintToChat(Client, MSG_SKILL_ABX_CHARGED);
	KillTimer(timer);
}

/* 勾魂之力 */
public Action:FireBallFunction2(Client)
{

	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(Client, user_name, sizeof(user_name));

	new ent=CreateEntityByName("tank_rock");
	//SetEntityModel(ent, FireBall_Model);
	//DispatchKeyValue(ent, "model", "/models/props_unique/airport/atlas_break_ball.mdl");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:FireBallPos[3];
	GetClientEyePosition(Client, FireBallPos);
	//FireBallPos[2] += 25.0;
	decl Float:angle[3];
	MakeVectorFromPoints(FireBallPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:FireBallTempPos[3];
	FireBallTempPos[0] = angle[0]*50.0;
	FireBallTempPos[1] = angle[1]*50.0;
	FireBallTempPos[2] = angle[2]*50.0;
	AddVectors(FireBallPos, FireBallTempPos, FireBallPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "255 80 80");

	TeleportEntity(ent, FireBallPos, angle, velocity);
	ActivateEntity(ent);
	AcceptEntityInput(ent, "Ignite");

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateFireBall2, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	PrintToChatAll("\04[技能] %s 发动勾魂之力-爆炎!",user_name );

	return Plugin_Handled;
}

public Action:ThdFunction(Client)
{

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	//new Float:Radius=float(165.0);
	GetClientAbsOrigin(Client, pos);



	ShowParticle(pos, ChainLightning_Particle_hit, 0.1);


	TE_SetupBeamRingPoint(pos, 0.1, 100.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 5.0, BlueColor, 10, 0);
	TE_SendToAll();

	TE_SetupGlowSprite(pos, g_GlowSprite, 0.5, 5.0, 100);
	TE_SendToAll();

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= 300.0)
				{
					DealDamage(Client, i, 200, 1024 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;

					new Handle:newh;
					CreateDataTimer(1.0, ChainDamage2, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= 300.0)
			{
				DealDamage(Client, iEntity, RoundToNearest(200.0), 1024, "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(1.5, ChainDamage2, newh);
				WritePackCell(newh, Client);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}

	return Plugin_Handled;
}

public Action:ChainDamage2(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
//	new Float:Radius=float(95.0);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsChained[victim] = false;
	}


	TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 3.0, 100);
	TE_SendToAll();

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= 300.0)
			{
				DealDamage(attacker, iEntity, 200, 1024 , "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(1.5, ChainDamage2, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsChained[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= 300.0)
				{
					DealDamage(attacker, i, 200, 1024 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;

					new Handle:newh;
					CreateDataTimer(1.5, ChainDamage2, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}

	//return Plugin_Handled;
}

public Action:UpdateFireBall2(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		AttachParticle(ent, FireBall_Particle_Fire03, 0.1);
		//PrintToChatAll("TimeEscapped = %.2f, DistanceToHit = %.2f, v= %.2f", GetEngineTime() - time, DistanceToHit(ent), v);
		if(GetEngineTime() - time > 10 || DistanceToHit(ent)<200.0 || v<200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(300);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			LittleFlower(pos, 1, Client);

			/* Emit impact sound */
			//EmitAmbientSound(FireBall_Sound_Impact01, pos);
			//EmitAmbientSound(FireBall_Sound_Impact02, pos);

			ShowParticle(pos, FireBall_Particle_Fire01, 5.0);
			ShowParticle(pos, FireBall_Particle_Fire02, 5.0);


			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);
			TE_SendToAll();

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client,iEntity, GouhunLv[Client]*225 + 500,8, "fire_ball");
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if(GetClientTeam(i) == 3 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamageRepeat(Client,i,25,262144,"fire_ball",5.0,3.0);
						}
					} else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamageRepeat(Client, i, 25, 262144 , "fire_ball", 5.0, 3.0);
						}
					}
				}
			}
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;

}

public Action:IceBallzFunction(Client)
{

	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(Client, user_name, sizeof(user_name));

	new ent=CreateEntityByName("tank_rock");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:IceBallPos[3];
	GetClientEyePosition(Client, IceBallPos);
	decl Float:angle[3];
	MakeVectorFromPoints(IceBallPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:IceBallTempPos[3];
	IceBallTempPos[0] = angle[0]*50.0;
	IceBallTempPos[1] = angle[1]*50.0;
	IceBallTempPos[2] = angle[2]*50.0;
	AddVectors(IceBallPos, IceBallTempPos, IceBallPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "80 80 255");

	TeleportEntity(ent, IceBallPos, angle, velocity);
	ActivateEntity(ent);

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateIcezBall, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());


	PrintToChatAll("\04[技能] %s 发动勾魂之力-冰封!",user_name );

	return Plugin_Handled;
}

public Action:UpdateIcezBall(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		if(GetEngineTime() - time > 10 || DistanceToHit(ent) < 200.0 || v < 200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(300);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			/* Emit impact sound */
			EmitAmbientSound(IceBall_Sound_Impact01, pos);
			EmitAmbientSound(IceBall_Sound_Impact02, pos);


			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, BlueColor, 10, 0);
			TE_SendToAll();

			TE_SetupGlowSprite(pos, g_GlowSprite, 15.0, 5.0, 100);
			TE_SendToAll();

			ShowParticle(pos, IceBall_Particle_Ice01, 5.0);

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, GouhunLv[Client]*225 + 500, 16 , "ice_ball");
						FreezePlayer(iEntity, entpos, 5.0);
						EmitAmbientSound(IceBall_Sound_Freeze, entpos, iEntity, SNDLEVEL_RAIDSIREN);
						TE_SetupGlowSprite(entpos, g_GlowSprite, 5.0, 3.0, 130);
						TE_SendToAll();
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, 15, 16 , "ice_ball");
							FreezePlayer(i, entpos, 15.0);
						}
					}
				}
			}
			PointPush(Client, pos, 1000, 50, 0.5);
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}

/* 暗影能量 */
public Action:FireBallFunction4(Client)
{

	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(Client, user_name, sizeof(user_name));

	new ent=CreateEntityByName("tank_rock");
	//SetEntityModel(ent, FireBall_Model);
	//DispatchKeyValue(ent, "model", "/models/props_unique/airport/atlas_break_ball.mdl");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:FireBallPos[3];
	GetClientEyePosition(Client, FireBallPos);
	//FireBallPos[2] += 25.0;
	decl Float:angle[3];
	MakeVectorFromPoints(FireBallPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:FireBallTempPos[3];
	FireBallTempPos[0] = angle[0]*50.0;
	FireBallTempPos[1] = angle[1]*50.0;
	FireBallTempPos[2] = angle[2]*50.0;
	AddVectors(FireBallPos, FireBallTempPos, FireBallPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "255 80 80");

	TeleportEntity(ent, FireBallPos, angle, velocity);
	ActivateEntity(ent);
	AcceptEntityInput(ent, "Ignite");

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateFireBall2S, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	PrintToChatAll("\04[技能] %s 发动暗影能量*地狱*",user_name );

	return Plugin_Handled;
}

public Action:ThdFunctionS(Client)
{

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	//new Float:Radius=float(165.0);
	GetClientAbsOrigin(Client, pos);



	ShowParticle(pos, ChainLightning_Particle_hit, 0.1);


	TE_SetupBeamRingPoint(pos, 0.1, 100.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 5.0, BlueColor, 10, 0);
	TE_SendToAll();

	TE_SetupGlowSprite(pos, g_GlowSprite, 0.5, 5.0, 100);
	TE_SendToAll();

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= 300.0)
				{
					DealDamage(Client, i, 200, 1024 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;

					new Handle:newh;
					CreateDataTimer(1.0, ChainDamage2, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= 300.0)
			{
				DealDamage(Client, iEntity, RoundToNearest(200.0), 1024, "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(1.5, ChainDamage2, newh);
				WritePackCell(newh, Client);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}

	return Plugin_Handled;
}

public Action:ChainDamage2A(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
//	new Float:Radius=float(95.0);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsChained[victim] = false;
	}


	TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 3.0, 100);
	TE_SendToAll();

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= 300.0)
			{
				DealDamage(attacker, iEntity, 200, 1024 , "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(1.5, ChainDamage2, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsChained[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= 300.0)
				{
					DealDamage(attacker, i, 200, 1024 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;

					new Handle:newh;
					CreateDataTimer(1.5, ChainDamage2, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}

	//return Plugin_Handled;
}

public Action:UpdateFireBall2S(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		AttachParticle(ent, FireBall_Particle_Fire03, 0.1);
		//PrintToChatAll("TimeEscapped = %.2f, DistanceToHit = %.2f, v= %.2f", GetEngineTime() - time, DistanceToHit(ent), v);
		if(GetEngineTime() - time > 10 || DistanceToHit(ent)<200.0 || v<200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(300);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			LittleFlower(pos, 1, Client);

			/* Emit impact sound */
			//EmitAmbientSound(FireBall_Sound_Impact01, pos);
			//EmitAmbientSound(FireBall_Sound_Impact02, pos);

			ShowParticle(pos, FireBall_Particle_Fire01, 5.0);
			ShowParticle(pos, FireBall_Particle_Fire02, 5.0);


			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);
			TE_SendToAll();

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client,iEntity, AynlLv[Client]*225 + 500,8, "fire_ball");
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if(GetClientTeam(i) == 3 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamageRepeat(Client,i,25,262144,"fire_ball",5.0,3.0);
						}
					} else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamageRepeat(Client, i, 25, 262144 , "fire_ball", 5.0, 3.0);
						}
					}
				}
			}
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;

}

public Action:IceBallzFunctionD(Client)
{

	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(Client, user_name, sizeof(user_name));

	new ent=CreateEntityByName("tank_rock");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:IceBallPos[3];
	GetClientEyePosition(Client, IceBallPos);
	decl Float:angle[3];
	MakeVectorFromPoints(IceBallPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:IceBallTempPos[3];
	IceBallTempPos[0] = angle[0]*50.0;
	IceBallTempPos[1] = angle[1]*50.0;
	IceBallTempPos[2] = angle[2]*50.0;
	AddVectors(IceBallPos, IceBallTempPos, IceBallPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "70 70 255");

	TeleportEntity(ent, IceBallPos, angle, velocity);
	ActivateEntity(ent);

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateIcezBallK, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());


	PrintToChatAll("\04[技能] %s 发动暗影能量*极寒*!",user_name );

	return Plugin_Handled;
}

public Action:UpdateIcezBallK(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		if(GetEngineTime() - time > 10 || DistanceToHit(ent) < 200.0 || v < 200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(300);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			/* Emit impact sound */
			EmitAmbientSound(IceBall_Sound_Impact01, pos);
			EmitAmbientSound(IceBall_Sound_Impact02, pos);


			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, GreenColor, 10, 0);
			TE_SendToAll();

			TE_SetupGlowSprite(pos, g_GlowSprite, 15.0, 5.0, 100);
			TE_SendToAll();

			ShowParticle(pos, IceBall_Particle_Ice01, 5.0);

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, AynlLv[Client]*100 + 100, 16 , "ice_ball");
						FreezePlayer(iEntity, entpos, 5.0);
						EmitAmbientSound(IceBall_Sound_Freeze, entpos, iEntity, SNDLEVEL_RAIDSIREN);
						TE_SetupGlowSprite(entpos, g_GlowSprite, 5.0, 3.0, 130);
						TE_SendToAll();
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, 5, 5 , "ice_ball");
							FreezePlayer(i, entpos, 15.0);
						}
					}
				}
			}
			PointPush(Client, pos, 1000, 50, 0.5);
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}


/* 治疗光球术 */
public Action:UseHealingBall(Client, args)
{
	if(GetClientTeam(Client) == 2) HealingBallFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:HealingBallFunction(Client)
{
	if(JD[Client] != 4)
	{
		CPrintToChat(Client, MSG_NEED_JOB4);
		return Plugin_Handled;
	}

	if(HealingBallLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_18);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsHealingBallEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_HB_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_HealingBall) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_HealingBall), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_HealingBall);

	new Float:Radius=float(HealingBallRadius[Client]);
	new Float:pos[3];
	GetTracePosition(Client, pos);
	pos[2] += 50.0;
	EmitAmbientSound(HealingBall_Sound_Lanuch, pos);
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 1.0, 5.0, 5.0, PurpleColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();

	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}

	IsHealingBallEnable[Client] = true;

	new Handle:pack;
	HealingBallTimer[Client] = CreateDataTimer(HealingBallInterval[Client], HealingBallTimerFunction, pack, TIMER_REPEAT);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);
	WritePackFloat(pack, GetEngineTime());

	CPrintToChatAll(MSG_SKILL_HB_ANNOUNCE, Client, HealingBallLv[Client]);

	//PrintToserver("[United RPG] %s启动了治疗光球术!走进圈中可回血!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:HealingBallTimerFunction(Handle:timer, Handle:pack)
{
	decl Float:pos[3], Float:entpos[3], Float:distance[3];

	ResetPack(pack);
	new Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);
	new Float:time=ReadPackFloat(pack);

	EmitAmbientSound(HealingBall_Sound_Heal, pos);
	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}

	//new iMaxEntities = GetMaxEntities();
	new Float:Radius=float(HealingBallRadius[Client]);

	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 1.0, 10.0, 5.0, PurpleColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();

	if(GetEngineTime() - time < HealingBallDuration[Client])
	{
		/*光球术圈内击杀僵尸*/
		new Float:entpos_new[3];
		new iMaxEntities = GetMaxEntities();
		new Float:distance_iEntity[3];
		new num;
		for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
		{
			if (IsCommonInfected(iEntity))
			{
				new health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
				if (health > 0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos_new);
					SubtractVectors(entpos_new, pos, distance_iEntity);
					if(GetVectorLength(distance_iEntity) <= Radius - 100)
					{
						DealDamage(Client, iEntity, health + 1, -2130706430, "fire_ball");
						num++;
					}
				}
			}
		}
		/*光球术圈内击杀僵尸结束*/



		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						new HP = GetClientHealth(i);
						new healing = RoundToNearest(0.0 + HealingBallEffect[Client]);
						if (healing < 5 || healing > 10)
							healing = 5;

						if (IsPlayerIncapped(i))
						{
							SetEntProp(i, Prop_Data, "m_iHealth", HP + healing);
							//HealingBallExp[Client] += GetConVarInt(LvUpExpRate) * healing / 500;
						} else
						{
							new MaxHP = GetEntProp(i, Prop_Data, "m_iMaxHealth");
							if(MaxHP > HP + healing)
							{
								SetEntProp(i, Prop_Data, "m_iHealth", HP + healing);
								//HealingBallExp[Client] += GetConVarInt(LvUpExpRate) * healing / 500;
							}
							else if(MaxHP < HP + healing)
							{
								SetEntProp(i, Prop_Data, "m_iHealth", MaxHP);
								//HealingBallExp[Client] += GetConVarInt(LvUpExpRate)*(MaxHP - HP)/500;
							}
						}
						ShowParticle(entpos, HealingBall_Particle_Effect, 0.5);
						TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 0.5, CyanColor, 0);
						TE_SendToAll();
					}
				}
			}
		}
	} else
	{
		if (IsValidPlayer(Client) && !IsFakeClient(Client))
		{
			if(HealingBallExp[Client] > 0)
			{
				//治疗光球术经验加成
				//EXP[Client] += HealingBallExp[Client] / 2 + VIPAdd(Client, HealingBallExp[Client] / 4, 1, true);
				//Cash[Client] += HealingBallExp[Client] / 10 + VIPAdd(Client, HealingBallExp[Client] / 20, 1, false);
				//CPrintToChat(Client, MSG_SKILL_HB_END, HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client] / 2, HealingBallExp[Client] / 20);
				//PrintToserver("[United RPG] %s的治疗光球术结束了! 总共治疗了队友%dHP, 获得%dExp, %d$", NameInfo(Client, simple), HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client], HealingBallExp[Client]);
			}
		}
		//HealingBallExp[Client] = 0;
		IsHealingBallEnable[Client] = false;
		KillTimer(timer);
		HealingBallTimer[Client] = INVALID_HANDLE;
	}
}

/* 暗夜嗜血术关联 */
public Action:UseHealingBallmiss(Client, args)
{
	if(GetClientTeam(Client) == 2) HealingBallmissFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
}

public Action:HealingBallmissFunction(Client)
{
	if(JD[Client] != 3)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
		return Plugin_Handled;
	}

	if(HealingBallmissLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
		return Plugin_Handled;
	}

	if(IsHealingBallmissEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
		return Plugin_Handled;
	}

	new Float:Radius=float(HealingBallmissRadius[Client]);
	new Float:pos[3];
	GetTracePosition(Client, pos);
	pos[2] += 50.0;
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 0.1, 5.0, 5.0, CyanColor, 10, 0);//固定外圈BuleColor
	TE_SendToAll();

	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 0.1, 2.5, 1000);
		TE_SendToAll();
	}

	IsHealingBallmissEnable[Client] = true;

	new Handle:pack;
	HealingBallmissTimer[Client] = CreateDataTimer(HealingBallmissInterval, HealingBallmissTimerFunction, pack, TIMER_REPEAT);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);
	WritePackFloat(pack, GetEngineTime());

	CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE, HealingBallLv[Client]);

	//PrintToserver("", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:HealingBallmissTimerFunction(Handle:timer, Handle:pack)
{
	decl Float:pos[3], Float:entpos[3], Float:distance[3];

	ResetPack(pack);
	new Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);
	new Float:time=ReadPackFloat(pack);

	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 0.1, 2.5, 1000);
		TE_SendToAll();
	}

	//new iMaxEntities = GetMaxEntities();
	new Float:Radius=float(HealingBallmissRadius[Client]);

	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 0.1, 10.0, 5.0, CyanColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();

	if(GetEngineTime() - time < HealingBallmissDuration[Client])
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						new HP = GetClientHealth(i);
						if (!IsPlayerIncapped(i))
						{
							new MaxHP = GetEntProp(i, Prop_Data, "m_iMaxHealth");
							if(MaxHP > HP+HealingBallmissEffect[i])
							{
								SetEntProp(i, Prop_Data, "m_iHealth", HP+HealingBallmissEffect[Client]);
								HealingBallmissExp[Client] += GetConVarInt(LvUpExpRate)*HealingBallmissEffect[Client]/500;
							}
							else if(MaxHP < HP+HealingBallmissEffect[Client])
							{
								SetEntProp(i, Prop_Data, "m_iHealth", MaxHP);
								HealingBallmissExp[Client] += GetConVarInt(LvUpExpRate)*(MaxHP - HP)/500;
							}
						}
					}
				}
			}
		}
	} else
	{
		if (IsValidPlayer(Client) && !IsFakeClient(Client))
		{
			if(HealingBallmissExp[Client] > 0)
			{
				//EXP[Client] += HealingBallmissExp[Client] / 4 + VIPAdd(Client, HealingBallmissExp[Client] / 4, 1, true);
				//Cash[Client] += HealingBallmissExp[Client] / 10 + VIPAdd(Client, HealingBallmissExp[Client] / 10, 1, false);
				//CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE, HealingBallmissExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallmissExp[Client], HealingBallmissExp[Client]/10);
				//PrintToserver("", NameInfo(Client, simple), HealingBallmissExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallmissExp[Client], HealingBallmissExp[Client]/10);
			}
		}
		HealingBallmissExp[Client] = 0;
		IsHealingBallmissEnable[Client] = false;
		KillTimer(HealingBallmissTimer[Client]);
		HealingBallmissTimer[Client] = INVALID_HANDLE;
	}
}

/* 地狱火 */
public Action:UseFireBall(Client, args)
{
	if(GetClientTeam(Client) == 2) FireBallFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

/* 火球术*/
public Action:FireBallFunction(Client)
{
	if(JD[Client] != 5)
	{
		CPrintToChat(Client, MSG_NEED_JOB5);
		return Plugin_Handled;
	}

	if(FireBallLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_15);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if (FireBallCD[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_FireBall) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_FireBall), MP[Client]);
		return Plugin_Handled;
	}


	MP[Client] -= GetConVarInt(Cost_FireBall);
	FireBallCD[Client] = true;
	new ent=CreateEntityByName("tank_rock");
	//SetEntityModel(ent, FireBall_Model);
	//DispatchKeyValue(ent, "model", "/models/props_unique/airport/atlas_break_ball.mdl");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:FireBallPos[3];
	GetClientEyePosition(Client, FireBallPos);
	//FireBallPos[2] += 25.0;
	decl Float:angle[3];
	MakeVectorFromPoints(FireBallPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:FireBallTempPos[3];
	FireBallTempPos[0] = angle[0]*50.0;
	FireBallTempPos[1] = angle[1]*50.0;
	FireBallTempPos[2] = angle[2]*50.0;
	AddVectors(FireBallPos, FireBallTempPos, FireBallPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "255 80 80");

	TeleportEntity(ent, FireBallPos, angle, velocity);
	ActivateEntity(ent);
	AcceptEntityInput(ent, "Ignite");

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateFireBall, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	CPrintToChatAll(MSG_SKILL_FB_ANNOUNCE, Client, FireBallLv[Client]);
	CreateTimer(5.0, Timer_FireBallCD, Client);

	//PrintToserver("[United RPG] %s启动了爆破!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdateFireBall(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		AttachParticle(ent, FireBall_Particle_Fire03, 0.1);
		//PrintToChatAll("TimeEscapped = %.2f, DistanceToHit = %.2f, v= %.2f", GetEngineTime() - time, DistanceToHit(ent), v);
		if(GetEngineTime() - time > FireIceBallLife || DistanceToHit(ent)<200.0 || v<200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(FireBallRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			LittleFlower(pos, EXPLODE, Client);

			/* Emit impact sound */
			EmitAmbientSound(FireBall_Sound_Impact01, pos);
			EmitAmbientSound(FireBall_Sound_Impact02, pos);

			ShowParticle(pos, FireBall_Particle_Fire01, 5.0);
			ShowParticle(pos, FireBall_Particle_Fire02, 5.0);

			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, FireBallDamage[Client], 0 , "fire_ball");
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == GetClientTeam(Client))
						continue;

					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
							DealDamageRepeat(Client, i, FireBallDamage[Client], 0 , "fire_ball", FireBallDamageInterval[Client], FireBallDuration[Client]);
					}
					else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
							DealDamageRepeat(Client, i, FireBallTKDamage[Client], 0 , "fire_ball", FireBallDamageInterval[Client], FireBallDuration[Client]);
					}
				}
			}
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}

bool:IsRock(ent)
{
	if(ent>0 && IsValidEntity(ent) && IsValidEdict(ent))
	{
		decl String:classname[20];
		GetEdictClassname(ent, classname, 20);

		if(StrEqual(classname, "tank_rock", true))
		{
			return true;
		}
	}
	return false;
}

public Action:Timer_FireBallCD(Handle:timer, any:Client)
{
	FireBallCD[Client] = false;
	KillTimer(timer);
}
public Action:Timer_FreezeCD(Handle:timer, any:Client)
{
	FreezeCD[Client] = false;
	KillTimer(timer);
}


/* 风暴之怒 */
public Action:UseFBZN(Client, args)
{
	if(GetClientTeam(Client) == 2) FBZNFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

/* 风暴之怒*/
public Action:FBZNFunction(Client)
{
	if(JD[Client] != 12)
	{
		CPrintToChat(Client, MSG_NEED_JOB12);
		return Plugin_Handled;
	}

	if(FBZNLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_34);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if (FBZNCD[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_FBZN) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_FBZN), MP[Client]);
		return Plugin_Handled;
	}


	MP[Client] -= GetConVarInt(Cost_FBZN);
	FBZNCD[Client] = true;
	new ent=CreateEntityByName("tank_rock");
	//SetEntityModel(ent, FBZN_Model);
	//DispatchKeyValue(ent, "model", "/models/props_unique/airport/atlas_break_ball.mdl");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:FBZNPos[3];
	GetClientEyePosition(Client, FBZNPos);
	//FBZNPos[2] += 25.0;
	decl Float:angle[3];
	MakeVectorFromPoints(FBZNPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:FBZNTempPos[3];
	FBZNTempPos[0] = angle[0]*50.0;
	FBZNTempPos[1] = angle[1]*50.0;
	FBZNTempPos[2] = angle[2]*50.0;
	AddVectors(FBZNPos, FBZNTempPos, FBZNPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "255 255 80");

	TeleportEntity(ent, FBZNPos, angle, velocity);
	ActivateEntity(ent);
	AcceptEntityInput(ent, "Ignite");

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateFBZN, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	CPrintToChatAll(MSG_SKILL_FBD_ANNOUNCE, Client, FBZNLv[Client]);
	CreateTimer(5.0, Timer_FBZNCD, Client);

	//PrintToserver("[United RPG] %s启动了风暴之怒!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdateFBZN(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRockD(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		AttachParticle(ent, FBZN_Particle_Fire03, 0.1);
		//PrintToChatAll("TimeEscapped = %.2f, DistanceToHit = %.2f, v= %.2f", GetEngineTime() - time, DistanceToHit(ent), v);
		if(GetEngineTime() - time > FBZNIceBallLife || DistanceToHit(ent)<200.0 || v<200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(FBZNRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			LittleFlower(pos, EXPLODE, Client);

			/* Emit impact sound */
			EmitAmbientSound(FBZN_Sound_Impact01, pos);
			EmitAmbientSound(FBZN_Sound_Impact02, pos);

			ShowParticle(pos, FBZN_Particle_Fire01, 5.0);
			ShowParticle(pos, FBZN_Particle_Fire02, 5.0);

			new Float:SkyLocation[3];
			SkyLocation[0] = pos[0];
			SkyLocation[1] = pos[1];
			SkyLocation[2] = pos[2] + 2000.0;
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 30.0, 30.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 30.0, 30.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, FBZNDamage[Client], 0 , "fire_ball");
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == GetClientTeam(Client))
						continue;

					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
							DealDamageRepeat(Client, i, FBZNDamage[Client], 0 , "fire_ball", FBZNDamageInterval[Client], FBZNDuration[Client]);
					}
					else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
							DealDamageRepeat(Client, i, FBZNTKDamage[Client], 0 , "fire_ball", FBZNDamageInterval[Client], FBZNDuration[Client]);
					}
				}
			}
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}

bool:IsRockD(ent)
{
	if(ent>0 && IsValidEntity(ent) && IsValidEdict(ent))
	{
		decl String:classname[20];
		GetEdictClassname(ent, classname, 20);

		if(StrEqual(classname, "tank_rock", true))
		{
			return true;
		}
	}
	return false;
}

public Action:Timer_FBZNCD(Handle:timer, any:Client)
{
	FBZNCD[Client] = false;
	KillTimer(timer);
}
public Action:Timer_FreefbCD(Handle:timer, any:Client)
{
	FreefbCD[Client] = false;
	KillTimer(timer);
}

/* 玄冰风暴 */
public Action:UseXBFB(Client, args)
{
	if(GetClientTeam(Client) == 2) XBFBFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:XBFBFunction(Client)
{
	if(JD[Client] != 12)
	{
		CPrintToChat(Client, MSG_NEED_JOB12);
		return Plugin_Handled;
	}

	if(XBFBLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_35);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if (FreefbCD[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_XBFB) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_XBFB), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_XBFB);
	FreefbCD[Client] = true;
	new ent=CreateEntityByName("tank_rock");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:XBFBPos[3];
	GetClientEyePosition(Client, XBFBPos);
	decl Float:angle[3];
	MakeVectorFromPoints(XBFBPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:XBFBTempPos[3];
	XBFBTempPos[0] = angle[0]*50.0;
	XBFBTempPos[1] = angle[1]*50.0;
	XBFBTempPos[2] = angle[2]*50.0;
	AddVectors(XBFBPos, XBFBTempPos, XBFBPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "80 80 255");

	TeleportEntity(ent, XBFBPos, angle, velocity);
	ActivateEntity(ent);

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateXBFB, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	CPrintToChatAll(MSG_SKILL_IBD_ANNOUNCE, Client, XBFBLv[Client]);
	CreateTimer(5.0, Timer_FreefbCD, Client);
	//PrintToserver("[United RPG] %s启动了冰球术!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdateXBFB(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		if(GetEngineTime() - time > FBZNIceBallLife || DistanceToHit(ent) < 200.0 || v < 200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(XBFBRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			/* Emit impact sound */
			EmitAmbientSound(XBFB_Sound_Impact01, pos);
			EmitAmbientSound(XBFB_Sound_Impact02, pos);

			new Float:SkyLocation[3];
			SkyLocation[0] = pos[0];
			SkyLocation[1] = pos[1];
			SkyLocation[2] = pos[2] + 2000.0;
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, BlueColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 30.0, 30.0, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 50, 300, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();

			TE_SetupGlowSprite(pos, g_GlowSprite, XBFBDuration[Client], 5.0, 100);
			TE_SendToAll();

			ShowParticle(pos, XBFB_Particle_Ice01, 5.0);

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, RoundToNearest(XBFBDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0 , "ice_ball");
						//FreezePlayer(iEntity, entpos, IceBallDuration[Client]);
						EmitAmbientSound(XBFB_Sound_Freeze, entpos, iEntity, SNDLEVEL_RAIDSIREN);
						TE_SetupGlowSprite(entpos, g_GlowSprite, XBFBDuration[Client], 3.0, 130);
						TE_SendToAll();
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == GetClientTeam(Client))
						continue;

					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, XBFBDamage[Client], 0 , "ice_ball");
							FreezePlayer(i, entpos, XBFBDuration[Client]);
						}
					}
					else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, XBFBTKDamage[Client], 0 , "ice_ball");
							FreezeDPlayer(i, entpos, XBFBDuration[Client]);
						}
					}
				}
			}
			PointPush(Client, pos, 1000, XBFBRadius[Client], 0.5);
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}
public FreezeDPlayer(entity, Float:pos[3], Float:time)
{
	if(IsValidPlayer(entity))
	{
		SetEntityMoveType(entity, MOVETYPE_NONE);
		SetEntityRenderColor(entity, 0, 128, 255, 135);
		ScreenFade(entity, 0, 128, 255, 192, 2000, 1);
		EmitAmbientSound(XBFB_Sound_Freeze, pos, entity, SNDLEVEL_RAIDSIREN);
		TE_SetupGlowSprite(pos, g_GlowSprite, time, 3.0, 130);
		TE_SendToAll();
		IsXBFB[entity] = true;
	}
	CreateTimer(time, DefrostPlayerD, entity);
}
public Action:DefrostPlayerD(Handle:timer, any:entity)
{
	if(IsValidPlayer(entity))
	{
		decl Float:entPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
		EmitAmbientSound(XBFB_Sound_Defrost, entPos, entity, SNDLEVEL_RAIDSIREN);
		SetEntityMoveType(entity, MOVETYPE_WALK);
		ScreenFade(entity, 0, 0, 0, 0, 0, 1);
		IsXBFB[entity] = false;
		SetEntityRenderColor(entity, 255, 255, 255, 255);
	}
}

/* 毁灭之书*/
public Action:UseHMZS(Client, args)
{
	if(GetClientTeam(Client) == 2) HMZSFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

/* 毁灭之书*/
public Action:HMZSFunction(Client)
{
	if(JD[Client] != 13)
	{
		CPrintToChat(Client, MSG_NEED_JOB13);
		return Plugin_Handled;
	}

	if(HMZSLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_36);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if (HMZSCD[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_HMZS) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_HMZS), MP[Client]);
		return Plugin_Handled;
	}


	MP[Client] -= GetConVarInt(Cost_HMZS);
	HMZSCD[Client] = true;
	new ent=CreateEntityByName("tank_rock");
	//SetEntityModel(ent, FBZN_Model);
	//DispatchKeyValue(ent, "model", "/models/props_unique/airport/atlas_break_ball.mdl");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:HMZSPos[3];
	GetClientEyePosition(Client, HMZSPos);
	//HMZSPos[2] += 25.0;
	decl Float:angle[3];
	MakeVectorFromPoints(HMZSPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:HMZSTempPos[3];
	HMZSTempPos[0] = angle[0]*50.0;
	HMZSTempPos[1] = angle[1]*50.0;
	HMZSTempPos[2] = angle[2]*50.0;
	AddVectors(HMZSPos, HMZSTempPos, HMZSPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "255 80 80");

	TeleportEntity(ent, HMZSPos, angle, velocity);
	ActivateEntity(ent);
	AcceptEntityInput(ent, "Ignite");

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateHMZS, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	CPrintToChatAll(MSG_SKILL_HMD_ANNOUNCE, Client, HMZSLv[Client]);
	CreateTimer(5.0, Timer_HMZSCD, Client);

	//PrintToserver("[United RPG] %s启动了毁灭之书!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdateHMZS(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRockA(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		AttachParticle(ent, HMZS_Particle_Fire03, 0.1);
		//PrintToChatAll("TimeEscapped = %.2f, DistanceToHit = %.2f, v= %.2f", GetEngineTime() - time, DistanceToHit(ent), v);
		if(GetEngineTime() - time > HMZSIceBallLife || DistanceToHit(ent)<200.0 || v<200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(HMZSRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			LittleFlower(pos, EXPLODE, Client);

			/* Emit impact sound */
			EmitAmbientSound(HMZS_Sound_Impact01, pos);
			EmitAmbientSound(HMZS_Sound_Impact02, pos);

			ShowParticle(pos, HMZS_Particle_Fire01, 5.0);
			ShowParticle(pos, HMZS_Particle_Fire02, 5.0);

			new Float:SkyLocation[3];
			SkyLocation[0] = pos[0];
			SkyLocation[1] = pos[1];
			SkyLocation[2] = pos[2] + 2000.0;
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();


			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, HMZSDamage[Client], 0 , "fire_ball");
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == GetClientTeam(Client))
						continue;

					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
							DealDamageRepeat(Client, i, HMZSDamage[Client], 0 , "fire_ball", HMZSDamageInterval[Client], HMZSDuration[Client]);
					}
					else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
							DealDamageRepeat(Client, i, HMZSTKDamage[Client], 0 , "fire_ball", HMZSDamageInterval[Client], HMZSDuration[Client]);
					}
				}
			}
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}

bool:IsRockA(ent)
{
	if(ent>0 && IsValidEntity(ent) && IsValidEdict(ent))
	{
		decl String:classname[20];
		GetEdictClassname(ent, classname, 20);

		if(StrEqual(classname, "tank_rock", true))
		{
			return true;
		}
	}
	return false;
}

public Action:Timer_HMZSCD(Handle:timer, any:Client)
{
	HMZSCD[Client] = false;
	KillTimer(timer);
}

/*审判之书 */
public Action:UseSPZS(Client, args)
{
	if(GetClientTeam(Client) == 2) SPZSFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:SPZSFunction(Client)
{
	if(JD[Client] != 13)
	{
		CPrintToChat(Client, MSG_NEED_JOB13);
		return Plugin_Handled;
	}

	if(SPZSLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_37);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_SPZS) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_SPZS), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_SPZS);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=float(SPZSLaunchRadius[Client]);
	GetClientAbsOrigin(Client, pos);

	/* Emit impact sound */
	EmitAmbientSound(SPZS_Sound_launch, pos);

	ShowParticle(pos, SPZS_Particle_hit, 0.1);

	new Float:SkyLocation[3];
	SkyLocation[0] = pos[0];
	SkyLocation[1] = pos[1];
	SkyLocation[2] = pos[2] + 2000.0;

	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 5.0, BlueColor, 10, 0);//固定外圈BuleColor
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 20.0, 20.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();

	TE_SetupGlowSprite(pos, g_GlowSprite, 0.5, 5.0, 100);
	TE_SendToAll();

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, SPZSDamage[Client], 0 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 15.0, 15.0, 2, 5.0, color, 0);
					TE_SendToAll();
					IsSPZSed[i] = true;

					new Handle:newh;
					CreateDataTimer(SPZSmissInterval[Client], SPZSDamage, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(Client, iEntity, SPZSDamage[Client], 0, "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 15.0, 15.0, 2, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(SPZSmissInterval[Client], SPZSDamage, newh);
				WritePackCell(newh, Client);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}

	CPrintToChatAll(MSG_SKILL_SPS_ANNOUNCE, Client, SPZSLv[Client]);

	//PrintToserver("[United RPG] %s启动了审判之书!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:SPZSDamage(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
	new Float:Radius=float(SPZSRadius[attacker]);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsSPZSed[victim] = false;
	}

	/* Emit impact Sound */
	EmitAmbientSound(SPZS_Sound_launch, pos);

	TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 3.0, 100);
	TE_SendToAll();

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(attacker, iEntity, RoundToNearest(SPZSDamage[attacker]/(EnergyEnhanceEffect_Attack[attacker])), 0 , "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 15.0, 15.0, 2, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(SPZSmissInterval[attacker], SPZSDamage, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsSPZSed[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(attacker, i, SPZSDamage[attacker], 0 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 15.0, 15.0, 2, 5.0, color, 0);
					TE_SendToAll();
					IsSPZSed[i] = true;

					new Handle:newh;
					CreateDataTimer(SPZSmissInterval[attacker], SPZSDamage, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}
	//return Plugin_Handled;
}

/* 冰球术 */
public Action:UseIceBall(Client, args)
{
	if(GetClientTeam(Client) == 2) IceBallFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:IceBallFunction(Client)
{
	if(JD[Client] != 5)
	{
		CPrintToChat(Client, MSG_NEED_JOB5);
		return Plugin_Handled;
	}

	if(IceBallLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_16);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if (FreezeCD[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_IceBall) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_IceBall), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_IceBall);
	FreezeCD[Client] = true;
	new ent=CreateEntityByName("tank_rock");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:IceBallPos[3];
	GetClientEyePosition(Client, IceBallPos);
	decl Float:angle[3];
	MakeVectorFromPoints(IceBallPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:IceBallTempPos[3];
	IceBallTempPos[0] = angle[0]*50.0;
	IceBallTempPos[1] = angle[1]*50.0;
	IceBallTempPos[2] = angle[2]*50.0;
	AddVectors(IceBallPos, IceBallTempPos, IceBallPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "80 80 255");

	TeleportEntity(ent, IceBallPos, angle, velocity);
	ActivateEntity(ent);

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateIceBall, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	CPrintToChatAll(MSG_SKILL_IB_ANNOUNCE, Client, IceBallLv[Client]);
	CreateTimer(5.0, Timer_FreezeCD, Client);
	//PrintToserver("[United RPG] %s启动了冰球术!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdateIceBall(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		if(GetEngineTime() - time > FireIceBallLife || DistanceToHit(ent) < 200.0 || v < 200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(IceBallRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			/* Emit impact sound */
			EmitAmbientSound(IceBall_Sound_Impact01, pos);
			EmitAmbientSound(IceBall_Sound_Impact02, pos);

			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, BlueColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();

			TE_SetupGlowSprite(pos, g_GlowSprite, IceBallDuration[Client], 5.0, 100);
			TE_SendToAll();

			ShowParticle(pos, IceBall_Particle_Ice01, 5.0);

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, RoundToNearest(IceBallDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0 , "ice_ball");
						//FreezePlayer(iEntity, entpos, IceBallDuration[Client]);
						EmitAmbientSound(IceBall_Sound_Freeze, entpos, iEntity, SNDLEVEL_RAIDSIREN);
						TE_SetupGlowSprite(entpos, g_GlowSprite, IceBallDuration[Client], 3.0, 130);
						TE_SendToAll();
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == GetClientTeam(Client))
						continue;

					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, IceBallDamage[Client], 0 , "chain_lightning");
							FreezePlayer(i, entpos, IceBallDuration[Client]);
						}
					}
					else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, IceBallTKDamage[Client], 0 , "ice_ball");
							FreezePlayer(i, entpos, IceBallDuration[Client]);
						}
					}
				}
			}
			PointPush(Client, pos, 1000, IceBallRadius[Client], 0.5);
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}
public FreezePlayer(entity, Float:pos[3], Float:time)
{
	if(IsValidPlayer(entity))
	{
		SetEntityMoveType(entity, MOVETYPE_NONE);
		SetEntityRenderColor(entity, 0, 128, 255, 135);
		ScreenFade(entity, 0, 128, 255, 192, 2000, 1);
		EmitAmbientSound(IceBall_Sound_Freeze, pos, entity, SNDLEVEL_RAIDSIREN);
		TE_SetupGlowSprite(pos, g_GlowSprite, time, 3.0, 130);
		TE_SendToAll();
		IsFreeze[entity] = true;
	}
	CreateTimer(time, DefrostPlayer, entity);
}
public Action:DefrostPlayer(Handle:timer, any:entity)
{
	if(IsValidPlayer(entity))
	{
		decl Float:entPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entPos);
		EmitAmbientSound(IceBall_Sound_Defrost, entPos, entity, SNDLEVEL_RAIDSIREN);
		SetEntityMoveType(entity, MOVETYPE_WALK);
		ScreenFade(entity, 0, 0, 0, 0, 0, 1);
		IsFreeze[entity] = false;
		SetEntityRenderColor(entity, 255, 255, 255, 255);
	}
}
/* 取打击距离 */
public Float:DistanceToHit(ent)
{
	if (!(GetEntityFlags(ent) & (FL_ONGROUND)))
	{
		decl Handle:h_Trace, Float:entpos[3], Float:hitpos[3], Float:angle[3];

		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", angle);
		GetVectorAngles(angle, angle);

		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", entpos);
		h_Trace = TR_TraceRayFilterEx(entpos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, ent);

		if (TR_DidHit(h_Trace))
		{
			TR_GetEndPosition(hitpos, h_Trace);

			CloseHandle(h_Trace);

			return GetVectorDistance(entpos, hitpos);
		}

		CloseHandle(h_Trace);
	}

	return 0.0;
}


/* 核弹 */
public PrecacheParticlemiss(String:particlename[])
{
	new particle = CreateEntityByName("info_particle_system");

	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticlesmiss, particle);
	}
}

public CreateParticles(Float:pos[3], String:particlename[], Float:time)
{
	new particle = CreateEntityByName("info_particle_system");

	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticlesmiss, particle);
	}
}

public Action:DeleteParticlesmiss(Handle:timer, any:particle)
{
	if (IsValidEdict(particle))
	{
		new String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			RemoveEdict(particle);
		}
	}
}

public bool:TraceEntityFilterPlayermiss(entity, contentsMask)
{
	return entity > GetMaxClients() || !entity;
}

public Action:nuclearcommand(Client)
{
	if (GetConVarInt(Cvar_nuclearEnable))
	{
		if (Client > 0 && IsClientInGame(Client))
		{
			if (IsPlayerAlive(Client))
			{
				if (nuclearamount[Client] > 0)
				{
					new Float:vAngles[3];
					new Float:vOrigin[3];
					new Float:pos[3];

					GetClientEyePosition(Client,vOrigin);
					GetClientEyeAngles(Client, vAngles);

					new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayermiss);

					TE_SetupSparks(pos, NULL_VECTOR, 2, 1);
					TE_SendToAll(0.1);
					TE_SetupSparks(pos, NULL_VECTOR, 2, 2);
					TE_SendToAll(0.4);
					TE_SetupSparks(pos, NULL_VECTOR, 1, 1);
					TE_SendToAll(1.0);

					if(TR_DidHit(trace))
					{
						TR_GetEndPosition(pos, trace);
						pos[2] += 15.0;
					}

					CloseHandle(trace);

					new nuclear = CreateEntityByName("prop_dynamic");

					if (IsValidEdict(nuclear))
					{
                        SetEntityModel(nuclear, "models/missiles/f18_agm65maverick.mdl");
                        DispatchKeyValueVector(nuclear, "origin", pos);
                        DispatchKeyValue(nuclear, "angles", "0 135 11");
                        DispatchKeyValue(nuclear, "spawnflags", "0");
                        DispatchKeyValue(nuclear, "rendercolor", "255 255 255");
                        DispatchKeyValue(nuclear, "renderamt", "255");
                        DispatchKeyValue(nuclear, "solid", "6");
                        DispatchKeyValue(nuclear, "MinAnimTime", "5");
                        DispatchKeyValue(nuclear, "MaxAnimTime", "10");
                        DispatchKeyValue(nuclear, "fademindist", "1500");
                        DispatchKeyValue(nuclear, "fadescale", "1");
                        DispatchKeyValue(nuclear, "model", "models/missiles/f18_agm65maverick.mdl");
                        SetEntData(nuclear, GetEntSendPropOffs(nuclear, "m_CollisionGroup"), 1, 1, true);
                        DispatchKeyValue(nuclear, "parentname", "helis");
                        DispatchKeyValue(nuclear, "fademaxdist", "3600");
                        DispatchKeyValue(nuclear, "classname", "prop_dynamic");
                        DispatchSpawn(nuclear);
                        TeleportEntity(nuclear, pos, NULL_VECTOR, NULL_VECTOR);

                        SetEntProp(nuclear, Prop_Send, "m_iGlowType", 3 );
                        SetEntProp(nuclear, Prop_Send, "m_nGlowRange", 0 );
                        SetEntProp(nuclear, Prop_Send, "m_glowColorOverride", 700000);

                        CreateTimer( 10.0, removenuclear, nuclear );

                        DurationSound(Client, GetConVarInt(CvarDurationTime));

                        pos[1] += 50;
                        pos[0] -= 50;
                        pos[2] -= 5;

                        TE_SetupBeamRingPoint(pos, 10.0, 300.0, fire, halo, 0, 20, 2.0, 8.0, 0.0, hedancolor, 10, 0);
                        TE_SendToAll();

                        TE_SetupBeamRingPoint(pos, 10.0, 260.0, fire, halo, 0, 20, 4.0, 10.0, 0.0, hedancolor, 10, 0);
                        TE_SendToAll();

                        TE_SetupBeamRingPoint(pos, 10.0, 220.0, fire, halo, 0, 20, 6.0, 8.0, 0.0, hedancolor, 10, 0);
                        TE_SendToAll();

                        TE_SetupBeamRingPoint(pos, 10.0, 180.0, fire, halo, 0, 20, 8.0, 10.0, 0.0, hedancolor, 10, 0);
                        TE_SendToAll();

                        TE_SetupBeamRingPoint(pos, 10.0, 130.0, fire, halo, 0, 20, 10.0, 8.0, 0.0, hedancolor, 10, 0);
                        TE_SendToAll();

                        CreateParticles(pos,"electrical_arc_01_system", 5.0 );
                        CreateParticles(pos,"electrical_arc_01_parent", 5.0 );
                    }

					CPrintToChatAll(MSG_SKILL_MOGU_NOGUN, Client);

					new Handle:gasdata = CreateDataPack();
					CreateTimer(11.0, CreateCloud, gasdata);
					WritePackCell(gasdata, Client);
					WritePackFloat(gasdata, pos[0]);
					WritePackFloat(gasdata, pos[1]);
					WritePackFloat(gasdata, pos[2]);
					WritePackCell(gasdata, nuclearamount[Client]);
					nuclearamount[Client]--;

					new Handle:bombdata = CreateDataPack();
					CreateTimer(10.0, CreateExplode, bombdata);
					WritePackCell(bombdata, Client);
					WritePackFloat(bombdata, pos[0]);
					WritePackFloat(bombdata, pos[1]);
					WritePackFloat(bombdata, pos[2]);
					WritePackCell(bombdata, nuclearamount[Client]);
				}
				else
				{
					PrintToChat(Client, "该技能一关只能使用%d次", Cvar_nuclearAmount);
				}
			}
		}
	}
	else
	{
		PrintToChat(Client, "[SM] 核弹正在准备当中.  请等待....");
	}
	return Plugin_Handled;
}
public Action:Createpush(Handle:timer, Handle:pushdata)
{
	ResetPack(pushdata);
	new Float:location[3];
	location[0] = ReadPackFloat(pushdata);
	location[1] = ReadPackFloat(pushdata);
	location[2] = ReadPackFloat(pushdata);

	//PrintToChatAll("DEBUG 1-2 测试成功 冲击波出现");

	new push = CreateEntityByName("point_push");

	if( IsValidEntity(push) )
	{
		DispatchKeyValueFloat (push, "magnitude", 9999.0);
		DispatchKeyValueFloat (push, "radius", 1000.0);
		SetVariantString("spawnflags 24");
		AcceptEntityInput(push, "AddOutput");
		DispatchSpawn(push);
		TeleportEntity(push, location, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(push, "Enable", -1, -1);
	}

	CreateTimer(0.8, DeletePushForcemiss, push);
}

public Action:CreateHurt(Handle:timer, Handle:hurt)
{
	ResetPack(hurt);
	new client = ReadPackCell(hurt);
	new nuclearNumber = ReadPackCell(hurt);
	new Float:location[3];
	location[0] = ReadPackFloat(hurt);
	location[1] = ReadPackFloat(hurt);
	location[2] = ReadPackFloat(hurt);
	KillTimer(timer);
	timer_handle[client][nuclearNumber] = INVALID_HANDLE;
	CloseHandle(hurt);

	new String:originData[64];
	Format(originData, sizeof(originData), "%f %f %f", location[0], location[1], location[2]);

	new String:nuclearRadius[64];
	Format(nuclearRadius, sizeof(nuclearRadius), "%i", GetConVarInt(CvarDamageRadius));

	new String:nuclearDamage[64];
	Format(nuclearDamage, sizeof(nuclearDamage), "%i", GetConVarInt(CvarDamageforce));

	new pointHurt = CreateEntityByName("point_hurt");

	if( IsValidEntity(pointHurt) )
	{
		DispatchKeyValue(pointHurt,"Origin", originData);
		DispatchKeyValue(pointHurt,"Damage", nuclearDamage);
		DispatchKeyValue(pointHurt,"DamageRadius", nuclearRadius);
		DispatchKeyValue(pointHurt,"DamageDelay", "1.0");
		DispatchKeyValue(pointHurt,"DamageType", "65536");
		DispatchKeyValue(pointHurt,"classname","point_hurt");
		DispatchSpawn(pointHurt);
		AcceptEntityInput(pointHurt, "TurnOn");
	}

	CreateTimer(0.5, DeletePointHurt, pointHurt);
}

public Action:CreateExplode(Handle:timer, Handle:bombdata)
{
	ResetPack(bombdata);
	new client = ReadPackCell(bombdata);
	new Float:location[3];
	location[0] = ReadPackFloat(bombdata);
	location[1] = ReadPackFloat(bombdata);
	location[2] = ReadPackFloat(bombdata);
	new nuclearNumber = ReadPackCell(bombdata);
	CloseHandle(bombdata);

	EmitSoundToAll("animation/gas_station_explosion.wav", _, _, _, _, 0.8);
	EmitSoundToAll("ambient/explosions/explode_3.wav", _, _, _, _, 0.8);

	PyroExplode(location);
	PyroExplode2(location);

	hurtdata[client][nuclearNumber] = CreateDataPack();
	WritePackCell(hurtdata[client][nuclearNumber], client);
	WritePackCell(hurtdata[client][nuclearNumber], nuclearNumber);
	WritePackFloat(hurtdata[client][nuclearNumber], location[0]);
	WritePackFloat(hurtdata[client][nuclearNumber], location[1]);
	WritePackFloat(hurtdata[client][nuclearNumber], location[2]);
	timer_handle[client][nuclearNumber] = CreateTimer(0.1, CreateHurt, hurtdata[client][nuclearNumber], TIMER_REPEAT);

	new Handle:pushdata = CreateDataPack();
	CreateTimer(0.1, Createpush, pushdata);
	WritePackFloat(pushdata, location[0]);
	WritePackFloat(pushdata, location[1]);
	WritePackFloat(pushdata, location[2]);

	new explosion =  CreateEntityByName("prop_physics");

	if( IsValidEntity(explosion) )
    {
        SetEntPropEnt(explosion, Prop_Data, "m_hOwnerEntity", client);
        SetEntProp(explosion, Prop_Send, "m_CollisionGroup", 1);
        //DispatchKeyValue(explosion, "model", "models/props_junk/explosive_box001.mdl");
        DispatchKeyValue(explosion, "model", "models/props_junk/propanecanister001a.mdl");
        //DispatchKeyValue(explosion, "model", "models/props_equipment/oxygentank01.mdl");
        DispatchKeyValue(explosion, "model", "models/props_junk/gascan001a.mdl");
        DispatchSpawn(explosion);

        TeleportEntity(explosion, location, NULL_VECTOR, NULL_VECTOR);
        AcceptEntityInput(explosion, "break");

        location[2] += 50;
        CreateParticles(location, "gas_explosion_main", 1.0);
        CreateParticles(location, "gas_explosion_pump", 1.0);
        CreateParticles(location, "weapon_pipebomb", 1.0);

        location[2] += 100;
        CreateParticles(location, "gas_explosion_main", 1.0);
        CreateParticles(location, "gas_explosion_pump", 1.0);
        CreateParticles(location, "weapon_pipebomb", 1.0);

        location[0] += 50;
        location[1] -= 50;
        CreateParticles(location, "gas_explosion_main", 1.0);
        CreateParticles(location, "gas_explosion_pump", 1.0);
        CreateParticles(location, "weapon_pipebomb", 1.0);

        location[0] -= 100;
        location[1] += 100;
        CreateParticles(location, "gas_explosion_main", 1.0);
        CreateParticles(location, "gas_explosion_pump", 1.0);
        CreateParticles(location, "weapon_pipebomb", 1.0);

        location[2] += 100;
        location[0] += 200;
        location[1] -= 200;
        CreateParticles(location, "gas_explosion_main", 1.0);
        CreateParticles(location, "gas_explosion_pump", 1.0);
        CreateParticles(location, "weapon_pipebomb", 1.0);

	}

	new Handle:hShake = StartMessageOne("Shake", client);

	if (hShake != INVALID_HANDLE)
    {
        BfWriteByte(hShake, 0);
        BfWriteFloat(hShake, 10.0);
        BfWriteFloat(hShake, 5.0);
        BfWriteFloat(hShake, 15.0);
        EndMessage();
    }
}

public Action:CreateCloud(Handle:timer, Handle:gasdata)
{
	ResetPack(gasdata);
	new client = ReadPackCell(gasdata);
	new Float:location[3];
	location[0] = ReadPackFloat(gasdata);
	location[1] = ReadPackFloat(gasdata);
	location[2] = ReadPackFloat(gasdata);
	new nuclearNumber = ReadPackCell(gasdata);
	CloseHandle(gasdata);

	location[2] += 200;
	location[0] -= 100;
	location[1] += 100;
	CreateParticles(location, "gas_explosion_main", 1.0);
	CreateParticles(location, "gas_explosion_pump", 1.0);
	CreateParticles(location, "weapon_pipebomb", 1.0);

	location[2] += 100;
	location[0] += 200;
	location[1] -= 200;
	CreateParticles(location, "gas_explosion_main", 1.0);
	CreateParticles(location, "gas_explosion_pump", 1.0);
	CreateParticles(location, "weapon_pipebomb", 1.0);

	location[2] -= 300;
	location[0] -= 100;
	location[1] += 100;

	new String:colorData[64];

	new red =  255;
	new green =  255;
	new blue =255;
	Format(colorData, sizeof(colorData), "%i %i %i", red, green, blue);

	new String:originData[64];

	Format(originData, sizeof(originData), "%f %f %f", location[0], location[1], location[2]);

	new String:nuclearRadius[64];
	Format(nuclearRadius, sizeof(nuclearRadius), "%i", GetConVarInt(CvarCloudRadius));

	new String:nuclearDamage[64];
	Format(nuclearDamage, sizeof(nuclearDamage), "%i", GetConVarInt(CvarCloudDamage));

	new pointHurt = CreateEntityByName("point_hurt");

	if( IsValidEntity(pointHurt) )
	{
		DispatchKeyValue(pointHurt,"Origin", originData);
		DispatchKeyValue(pointHurt,"Damage", nuclearDamage);
		DispatchKeyValue(pointHurt,"DamageRadius", nuclearRadius);
		DispatchKeyValue(pointHurt,"DamageDelay", "1.0");
		DispatchKeyValue(pointHurt,"DamageType", "65536");
		DispatchKeyValue(pointHurt,"classname","point_hurt");
		DispatchSpawn(pointHurt);
		AcceptEntityInput(pointHurt, "TurnOn");
	}

	CreateTimer(50.0, DeletePointHurt, pointHurt);

	PrintToChatAll("\x04[核辐射污染]   \x05范围 \x01+%d  \x05伤害值 \x01+%d  \x05持续时间 \x01+50 \x05秒",GetConVarInt(CvarDamageRadius),GetConVarInt(CvarCloudDamage));

	new String:cloud_name[128];
	Format(cloud_name, sizeof(cloud_name), "Gas%i", client);
	new Cloud = CreateEntityByName("env_smokestack");
	DispatchKeyValue(Cloud,"targetname", cloud_name);
	DispatchKeyValue(Cloud,"Origin", originData);
	DispatchKeyValue(Cloud,"BaseSpread", "50");
	DispatchKeyValue(Cloud,"SpreadSpeed", "10");
	DispatchKeyValue(Cloud,"Speed", "40");
	DispatchKeyValue(Cloud,"StartSize", "200");
	DispatchKeyValue(Cloud,"EndSize", "1400");
	DispatchKeyValue(Cloud,"Rate", "15");
	DispatchKeyValue(Cloud,"JetLength", "1000");
	DispatchKeyValue(Cloud,"Twist", "10");
	DispatchKeyValue(Cloud,"RenderColor", colorData);
	DispatchKeyValue(Cloud,"RenderAmt", "100");
	DispatchKeyValue(Cloud,"SmokeMaterial", "particle/particle_noisesphere.vmt");
	DispatchSpawn(Cloud);
	AcceptEntityInput(Cloud, "TurnOn");
	EmitSoundToAll("animation/van_inside_debris.wav", _, _, _, _, 0.8);

	new Handle:soundpack1 = CreateDataPack();
	CreateTimer(5.0, DurationSoundtime1, soundpack1);
	WritePackCell(soundpack1, client);

	new Handle:soundpack2 = CreateDataPack();
	CreateTimer(7.0, DurationSoundtime2, soundpack2);
	WritePackCell(soundpack2, client);

	new Handle:soundpack3 = CreateDataPack();
	CreateTimer(9.0, DurationSoundtime3, soundpack3);
	WritePackCell(soundpack3, client);

	new Handle:soundpack4 = CreateDataPack();
	CreateTimer(11.0, DurationSoundtime4, soundpack4);
	WritePackCell(soundpack4, client);

	new Handle:entitypack = CreateDataPack();
	new Handle:entitypack2 = CreateDataPack();
	CreateTimer(GetConVarFloat(Cvar_nuclearTime), RemoveGas, entitypack);
	WritePackCell(entitypack, Cloud);
	WritePackCell(entitypack, nuclearNumber);
	WritePackCell(entitypack, client);
	CreateTimer(GetConVarFloat(Cvar_nuclearTime), KillGas, entitypack2);
	WritePackCell(entitypack2, Cloud);
	WritePackCell(entitypack2, nuclearNumber);
	WritePackCell(entitypack2, client);
}

public Action:DeletePointHurt(Handle:timer, any:ent)
{
	if (IsValidEntity(ent))
	{
		decl String:classname[64];
		GetEdictClassname(ent, classname, sizeof(classname));
		if (StrEqual(classname, "point_hurt", false))
		{
			AcceptEntityInput(ent, "Kill");
			RemoveEdict(ent);
		}
	}
}

public Action:DeletePushForcemiss(Handle:timer, any:ent)
{
	if (IsValidEntity(ent))
	{
		decl String:classname[64];
		GetEdictClassname(ent, classname, sizeof(classname));
		if (StrEqual(classname, "point_push", false))
		{
 			AcceptEntityInput(ent, "Disable");
			AcceptEntityInput(ent, "Kill");
			RemoveEdict(ent);
		}
	}
}

public Action:RemoveGas(Handle:timer, Handle:entitypack)
{
	ResetPack(entitypack);
	new Cloud = ReadPackCell(entitypack);
	new nuclearNumber = ReadPackCell(entitypack);
	new client = ReadPackCell(entitypack);

	if (IsValidEntity(Cloud))
	{
		AcceptEntityInput(Cloud, "TurnOff");
	}
	if (timer_handle[client][nuclearNumber] != INVALID_HANDLE)
	{
		KillTimer(timer_handle[client][nuclearNumber]);
		timer_handle[client][nuclearNumber] = INVALID_HANDLE;
		CloseHandle(hurtdata[client][nuclearNumber]);
	}
}

public Action:KillGas(Handle:timer, Handle:entitypack)
{
	ResetPack(entitypack);
	new Cloud = ReadPackCell(entitypack);
	PrintToChatAll("\x04核污染蘑菇云消失");
	if (IsValidEntity(Cloud))
		AcceptEntityInput(Cloud, "Kill");

	CloseHandle(entitypack);
}

public Action: PyroExplode(Float:vec1[3])
{
	new color[4]={188,220,255,250};
	TE_SetupBeamRingPoint(vec1, 5.0, 2000.0, white, halo, 0, 8, 1.5, 12.0, 0.5, color, 8, 0);
  	TE_SendToAll();
}

public PyroExplode2(Float:vec1[3])
{
	vec1[2] += 10;
	new color[4]={188,220,255,250};
	TE_SetupBeamRingPoint(vec1, 5.0, 1600.0, fire, halo, 0, 60, 8.0, 200.0, 0.2, color, 20, 0);
  	TE_SendToAll();
}

public Action:removenuclear(Handle:timer, any:ent)
{
	if (IsValidEntity(ent))
	{
		decl String:classname[64];
		GetEdictClassname(ent, classname, sizeof(classname));
		if (StrEqual(classname, "prop_dynamic", false))
		{
			RemoveEdict(ent);
		}
	}
}

public PlayerSpawnEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	nuclearamount[client] = GetConVarInt(Cvar_nuclearAmount);
}

public PlayerDeathEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	nuclearamount[client] = 0;
}

public Action:DurationSoundtime1(Handle:timer, Handle:soundpack)
{
	ResetPack(soundpack);
	new client = ReadPackCell(soundpack);
	DurationSound2(client, GetConVarInt(CvarDurationTime2));
}

public Action:DurationSoundtime2(Handle:timer, Handle:soundpack)
{
	ResetPack(soundpack);
	new client = ReadPackCell(soundpack);
	DurationSound3(client, GetConVarInt(CvarDurationTime2));
}

public Action:DurationSoundtime3(Handle:timer, Handle:soundpack)
{
	ResetPack(soundpack);
	new client = ReadPackCell(soundpack);
	DurationSound4(client, GetConVarInt(CvarDurationTime2));
}

public Action:DurationSoundtime4(Handle:timer, Handle:soundpack)
{
	ResetPack(soundpack);
	new client = ReadPackCell(soundpack);
	DurationSound5(client, GetConVarInt(CvarDurationTime2));
}
DurationSound2(client, time)
{
	DurationTime2[client] = time;
	CreateTimer(1.0, Timer_Freeze2, client, DEFAULT_TIMER_FLAGS);
}
DurationSound3(client, time)
{
	DurationTime2[client] = time;
	CreateTimer(1.0, Timer_Freeze2, client, DEFAULT_TIMER_FLAGS);
}
DurationSound4(client, time)
{
	DurationTime2[client] = time;
	CreateTimer(1.0, Timer_Freeze2, client, DEFAULT_TIMER_FLAGS);
}
DurationSound5(client, time)
{
	DurationTime2[client] = time;
	CreateTimer(1.0, Timer_Freeze2, client, DEFAULT_TIMER_FLAGS);
}
public Action:Timer_Freeze2(Handle:timer, any:value)
{
	new client = value & 0x7f;

	DurationTime2[client]--;
	if( DurationTime2[client] >= 1)
	{
	    EmitSoundToAll("ambient/random_amb_sfx/dist_explosion_01.wav" ,_, _, _, _, 1.0);
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Handled;
}
public Action:Timer_Freeze3(Handle:timer, any:value)
{
	new client = value & 0x7f;

	DurationTime2[client]--;
	if( DurationTime2[client] >= 1)
	{
	    EmitSoundToAll("ambient/random_amb_sfx/dist_explosion_02.wav" ,_, _, _, _, 1.0);
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Handled;
}
public Action:Timer_Freeze4(Handle:timer, any:value)
{
	new client = value & 0x7f;

	DurationTime2[client]--;
	if( DurationTime2[client] >= 1)
	{
	    EmitSoundToAll("ambient/random_amb_sfx/dist_explosion_03.wav" ,_, _, _, _, 1.0);
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Handled;
}
public Action:Timer_Freeze5(Handle:timer, any:value)
{
	new client = value & 0x7f;

	DurationTime2[client]--;
	if( DurationTime2[client] >= 1)
	{
	    EmitSoundToAll("ambient/random_amb_sfx/dist_explosion_04.wav" ,_, _, _, _, 1.0);
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Handled;
}
DurationSound(client, time)
{
	DurationTime[client] = time;
	CreateTimer(1.0, Timer_Freeze, client, DEFAULT_TIMER_FLAGS);
}

public Action:Timer_Freeze(Handle:timer, any:value)
{
	new client = value & 0x7f;

	DurationTime[client]--;
	if( DurationTime[client] >= 1)
	{
	    EmitSoundToAll("ambient/alarms/klaxon1.wav" ,_, _, _, _, 0.8);
	    PrintHintTextToAll("核弹启爆倒计时\n %d 秒", DurationTime[client]);
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Handled;
}

/* 连锁闪电 */
public Action:UseChainLightning(Client, args)
{
	if(GetClientTeam(Client) == 2) ChainLightningFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:ChainLightningFunction(Client)
{
	if(JD[Client] != 5)
	{
		CPrintToChat(Client, MSG_NEED_JOB5);
		return Plugin_Handled;
	}

	if(ChainLightningLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_17);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_ChainLightning) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_ChainLightning), MP[Client]);
		return Plugin_Handled;
	}
	if (ChainLightningCD[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}


	MP[Client] -= GetConVarInt(Cost_ChainLightning);
	ChainLightningCD[Client] = true;	
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;
	
	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=float(ChainLightningLaunchRadius[Client]);
	GetClientAbsOrigin(Client, pos);
	
	/* Emit impact sound */
	EmitAmbientSound(ChainLightning_Sound_launch, pos); //EmitAmbientSound = 在物品周围播放技能音效
	
	ShowParticle(pos, ChainLightning_Particle_hit, 0.1);
	
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 5.0, ClaretColor, 10, 0);//固定外圈BuleColor
	TE_SendToAll();
	
	TE_SetupGlowSprite(pos, g_GlowSprite, 0.5, 5.0, 100);
	TE_SendToAll();
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, ChainLightningDamage[Client], 0 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;
					
					new Handle:newh;					
					CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}
	
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(Client, iEntity, ChainLightningDamage[Client], 0, "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);
				
				new Handle:newh;					
				CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
				WritePackCell(newh, Client);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	
	CPrintToChatAll(MSG_SKILL_CL_ANNOUNCE, Client, ChainLightningLv[Client]);
	CreateTimer(5.0, Timer_UseChainLightningCD, Client);

	//PrintToserver("[United RPG] %s启动了连锁闪电!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:Timer_UseChainLightningCD(Handle:timer, any:Client)
{
	ChainLightningCD[Client] = false;
	KillTimer(timer);
}
public Action:ChainDamage(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);
	
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;
	
	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
	new Float:Radius=float(ChainLightningRadius[attacker]);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsChained[victim] = false;
	}
	
	/* Emit impact Sound */
	EmitAmbientSound(ChainLightning_Sound_launch, pos); //EmitAmbientSound = 在物品周围播放技能音效
	
	TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 3.0, 100);
	TE_SendToAll();
	
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(attacker, iEntity, RoundToNearest(ChainLightningDamage[attacker]/(1.0 + StrEffect[attacker] + EnergyEnhanceEffect_Attack[attacker])), 0 , "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);
				
				new Handle:newh;					
				CreateDataTimer(ChainLightningInterval[attacker], ChainDamage, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsChained[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(attacker, i, ChainLightningDamage[attacker], 0 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsChained[i] = true;
					
					new Handle:newh;					
					CreateDataTimer(ChainLightningInterval[attacker], ChainDamage, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}
	//return Plugin_Handled;
}

/* 幻影之炎 */
public Action:UsePHFR(Client, args)
{
	if(GetClientTeam(Client) == 2) PHFRFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

/* 幻影之炎*/
public Action:PHFRFunction(Client)
{
	if(JD[Client] != 15)
	{
		CPrintToChat(Client, MSG_NEED_JOB15);
		return Plugin_Handled;
	}

	if(PHFRLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_34);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if (PHFRCD[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_PHFR) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_PHFR), MP[Client]);
		return Plugin_Handled;
	}


	MP[Client] -= GetConVarInt(Cost_PHFR);
	PHFRCD[Client] = true;
	new ent=CreateEntityByName("tank_rock");
	//SetEntityModel(ent, PHFR_Model);
	//DispatchKeyValue(ent, "model", "/models/props_unique/airport/atlas_break_ball.mdl");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:PHFRPos[3];
	GetClientEyePosition(Client, PHFRPos);
	//PHFRPos[2] += 25.0;
	decl Float:angle[3];
	MakeVectorFromPoints(PHFRPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:PHFRTempPos[3];
	PHFRTempPos[0] = angle[0]*50.0;
	PHFRTempPos[1] = angle[1]*50.0;
	PHFRTempPos[2] = angle[2]*50.0;
	AddVectors(PHFRPos, PHFRTempPos, PHFRPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "255 0 0");

	TeleportEntity(ent, PHFRPos, angle, velocity);
	ActivateEntity(ent);
	AcceptEntityInput(ent, "Ignite");

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdatePHFR, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	CPrintToChatAll(MSG_SKILL_PHF_ANNOUNCE, Client, PHFRLv[Client]);
	CreateTimer(3.0, Timer_PHFRCD, Client);

	//PrintToserver("[United RPG] %s启动了幻影之炎!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdatePHFR(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRockP(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		AttachParticle(ent, PHFR_Particle_Fire03, 0.1);
		//PrintToChatAll("TimeEscapped = %.2f, DistanceToHit = %.2f, v= %.2f", GetEngineTime() - time, DistanceToHit(ent), v);
		if(GetEngineTime() - time > PHFRIceBallLife || DistanceToHit(ent)<200.0 || v<200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(PHFRRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			LittleFlower(pos, EXPLODE, Client);

			/* Emit impact sound */
			EmitAmbientSound(PHFR_Sound_Impact01, pos);
			EmitAmbientSound(PHFR_Sound_Impact02, pos);

			ShowParticle(pos, PHFR_Particle_Fire01, 5.0);
			ShowParticle(pos, PHFR_Particle_Fire02, 5.0);

			new Float:SkyLocation[3];
			SkyLocation[0] = pos[0];
			SkyLocation[1] = pos[1];
			SkyLocation[2] = pos[2] + 2000.0;
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 30.0, 30.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 30.0, 30.0, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, RedColor, 0);
			TE_SendToAll();

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, PHFRDamage[Client], 0 , "fire_ball");
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == GetClientTeam(Client))
						continue;

					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
							DealDamageRepeat(Client, i, PHFRDamage[Client], 0 , "fire_ball", PHFRDamageInterval[Client], PHFRDuration[Client]);
					}
					else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
							DealDamageRepeat(Client, i, PHFRTKDamage[Client], 0 , "fire_ball", PHFRDamageInterval[Client], PHFRDuration[Client]);
					}
				}
			}
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}

bool:IsRockP(ent)
{
	if(ent>0 && IsValidEntity(ent) && IsValidEdict(ent))
	{
		decl String:classname[20];
		GetEdictClassname(ent, classname, 20);

		if(StrEqual(classname, "tank_rock", true))
		{
			return true;
		}
	}
	return false;
}


/* 使用_幻影之血 */
public Action:UsePHZG(Client, args)
{
	if(GetClientTeam(Client) == 2) PHZG(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Handled;
}

/* 幻影之血 */
public Action:PHZG(Client)
{

	if(JD[Client] != 15)
	{
		CPrintToChat(Client, MSG_NEED_JOB14);
		return Plugin_Handled;
	}

	if(PHZGLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_43);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsPHZGEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_PHZG) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_PHZG), MP[Client]);
		return Plugin_Handled;
	}

	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	new Float:TracePos[3];
	new Float:EyePos[3];
	new Float:Angle[3];
	new Float:TempPos[3];
	new Float:velocity[3];
	new Handle:data;
	new entity = CreateEntityByName("tank_rock");
	GetTracePosition(Client, TracePos);
	GetClientEyePosition(Client, EyePos);
	MakeVectorFromPoints(EyePos, TracePos, Angle);
	NormalizeVector(Angle, Angle);

	TempPos[0] = Angle[0] * 50;
	TempPos[1] = Angle[1] * 50;
	TempPos[2] = Angle[2] * 50;
	AddVectors(EyePos, TempPos, EyePos);

	velocity[0] = Angle[0] * 500;
	velocity[1] = Angle[1] * 500;
	velocity[2] = Angle[2] * 500;

	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		IsPHZGEnable[Client] = true;
		//初始发射音效
		EmitAmbientSound(HealingBall_Sound_Lanuch, EyePos);
		//实体属性设置
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", Client);
		DispatchSpawn(entity);
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 255, 255, 255, 0);
		SetEntityGravity(entity, 0.1);
		SetEntProp(entity, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(entity, Prop_Data, "m_MoveCollide", 0);
		TE_SetupBeamFollow(entity, g_BeamSprite, g_HaloSprite, 5.0, 5.0, 2.0, 1, RedColor); //光束
		TE_SendToAll();
		TeleportEntity(entity, EyePos, Angle, velocity);
		//计时器创建
		CreateTimer(5.0, Timer_PHZGCooling, Client);
		CreateTimer(10.0, Timer_RemovePHZG, entity);
		CreateDataTimer(0.1, Timer_PHZG, data, TIMER_REPEAT);
		WritePackCell(data, entity);
		WritePackFloat(data, Angle[0]);
		WritePackFloat(data, Angle[1]);
		WritePackFloat(data, Angle[2]);
		WritePackFloat(data, velocity[0]);
		WritePackFloat(data, velocity[1]);
		WritePackFloat(data, velocity[2]);
	}


	CPrintToChatAll(MSG_SKILL_LBD_ANNOUNCE, Client, PHZGLv[Client]);
	MP[Client] -= GetConVarInt(Cost_PHZG);
	return Plugin_Handled;
}

/* 光球跟踪实体计时器 */
public Action:Timer_PHZG(Handle:timer, Handle:data)
{
	new Float:pos[3];
	new Float:Angle[3];
	new Float:velocity[3];
	ResetPack(data);
	new entity = ReadPackCell(data);
	Angle[0] = ReadPackFloat(data);
	Angle[1] = ReadPackFloat(data);
	Angle[2] = ReadPackFloat(data);
	velocity[0] = ReadPackFloat(data);
	velocity[1] = ReadPackFloat(data);
	velocity[2] = ReadPackFloat(data);

	if (!IsValidEntity(entity) || !IsValidEdict(entity))
		return Plugin_Stop;

	for (new i = 1; i <= 5; i++)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		TeleportEntity(entity, pos, Angle, velocity);
		TE_SetupGlowSprite(pos, g_GlowSprite, 0.1, 4.0, 500);
		TE_SendToAll();
	}

	if (DistanceToHit(entity) <= 200)
	{
		CreateTimer(0.1, Timer_RemovePHZG, entity);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

/* 删除幻影之血计时器 */
public Action:Timer_RemovePHZG(Handle:timer, any:entity)
{
	new Player;
	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new MaxEnt = GetMaxEntities();
	PHZGReward[Player] = 0;

	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
		Player = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	if (IsValidPlayer(Player) && IsValidEntity(entity) && IsValidEdict(entity))
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		EmitAmbientSound(HealingBall_Sound_Heal, pos);
		//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
		TE_SetupBeamRingPoint(pos, 0.1, 100.0, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 10.0, 0.0, PurpleColor, 10, 0);
		TE_SendToAll();

		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsValidPlayer(i) || !IsValidEntity(i) || !IsValidEdict(i))
				continue;

			GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= 200)
			{
				if (GetClientTeam(i) == GetClientTeam(Player))
				{
					PHDCS(Player, i, PHZGHealth[Player]);
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, GreenColor, 0);
					TE_SendToAll();
					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, GreenColor, 10, 0);
					TE_SendToAll();
				}
				else
				{
					DealDamage(Player, i, PHZGDamage[Player], 0);
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, GreenColor, 0);
					TE_SendToAll();
					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, GreenColor, 10, 0);
					TE_SendToAll();
				}
			}
		}

		for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
		{
			if(IsValidEntity(iEnt) && IsValidEdict(iEnt) && IsCommonInfected(iEnt) && GetEntProp(iEnt, Prop_Data, "m_iHealth") > 0)
			{
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if (distance <= 200)
				{
					DealDamage(Player, iEnt, PHZGDamage[Player], 0);
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, GreenColor, 0);
					TE_SendToAll();
					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, GreenColor, 10, 0);
					TE_SendToAll();
				}
			}

		}

		//治愈经验
		PHDCOS(Player);
		//删除实体
		RemoveEdict(entity);
	}
}

/* 治愈效果 */
public PHDCS(Client, Target, Cure_Health)
{
	if (!IsValidPlayer(Client) || !IsValidEntity(Client) || !IsPlayerAlive(Client) || !IsValidPlayer(Target) || !IsValidEntity(Target) || !IsPlayerAlive(Target))
		return;

	new health = GetClientHealth(Target);
	new maxhealth = GetEntProp(Target, Prop_Data, "m_iMaxHealth");

	if (!IsPlayerIncapped(Target))
	{
		if (health + Cure_Health > maxhealth)
		{
			PHZGReward[Client] += maxhealth - health;
			health = maxhealth;
		}
		else
		{
			PHZGReward[Client] += Cure_Health;
			health = health + Cure_Health;
		}

		SetEntProp(Target, Prop_Data, "m_iHealth", health);
	}
	else if (IsPlayerIncapped(Target))
	{
		if (health + Cure_Health > 300)
		{
			PHZGReward[Client] += 300 - health;
			health = 300;
		}
		else
		{
			PHZGReward[Client] += Cure_Health;
			health = health + Cure_Health;
		}

		SetEntProp(Target, Prop_Data, "m_iHealth", health);
	}
}

/* 治愈效果_结束 */
public PHDCOS(Client)
{
	if (!IsValidPlayer(Client) || !IsValidEntity(Client) || !IsPlayerAlive(Client))
	{
		PHZGReward[Client] = 0;
		return;
	}

	if (PHZGReward[Client] > 0)
	{
		//new giveexp = RoundToNearest(PHZGReward[Client] * PHZGExp);
		new givecash = RoundToNearest(PHZGReward[Client] * PHZGCash);
		//EXP[Client] += giveexp + VIPAdd(Client, giveexp, 1, true);
		Cash[Client] += givecash + VIPAdd(Client, givecash, 1, false);
		//CPrintToChat(Client, MSG_SKILL_PHZ_END, PHZGReward[Client], giveexp, givecash);
		SXZGReward[Client] = 0;
	}
}

/* 幻影之血冷却 */
public Action:Timer_PHZGCooling(Handle:timer, any:Client)
{
	IsPHZGEnable[Client] = false;
}


/* 幻影炮 */
public Action:UsePHSC(Client, args)
{
	if(GetClientTeam(Client) == 2) PHSCFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:PHSCFunction(Client)
{
	if(JD[Client] != 15)
	{
		CPrintToChat(Client, MSG_NEED_JOB15);
		return Plugin_Handled;
	}

	if(PHSCLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_SKILL_PHS_ANNOUNCE);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(!IsSatelliteCannonReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_PHSC) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_PHSC), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_PHSC);

	new Float:Radius=float(PHSCRadius[Client]);
	new Float:pos[3];
	GetTracePosition(Client, pos);
	EmitAmbientSound(SOUND_TRACING, pos);
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, PHSCLaunchTime, 5.0, 0.0, BlueColor, 10, 0);//固定外圈BuleColor
	TE_SendToAll();
	TE_SetupBeamRingPoint(pos, Radius, 0.1, g_BeamSprite, g_HaloSprite, 0, 15, PHSCLaunchTime, 5.0, 0.0, RedColor, 10, 0);//扩散内圈RedColor
	TE_SendToAll();

	IsSatelliteCannonReady[Client] = false;

	new Handle:pack;
	CreateDataTimer(PHSCLaunchTime, PHSCTimerFunction, pack);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);

	CPrintToChatAll(MSG_SKILL_PHS_ANNOUNCE, Client, PHSCLv[Client]);

	//PrintToserver("[United RPG] %s启动了幻影炮!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:PHSCTimerFunction(Handle:timer, Handle:pack)
{
	new Client;
	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=float(PHSCRadius[Client]);

	ResetPack(pack);
	Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);

	CreateLaserEffect(Client, pos, 230, 230, 80, 230, 6.0, 1.0, LASERMODE_VARTICAL);

	/* Explode */
	LittleFlower(pos, EXPLODE, Client);
	ShowParticle(pos, PARTICLE_SCEFFECT, 10.0);
	EmitAmbientSound(SatelliteCannon_Sound_Launch, pos);

	for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, PHSCDamage[Client], 0, "satellite_cannon");
				}
			} else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, PHSCSurvivorDamage[Client], 0, "satellite_cannon");
				}
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
        if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
        {
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(Client, iEntity, RoundToNearest(PHSCDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0, "satellite_cannon");
			}
		}
	}

	PointPush(Client, pos, PHSCDamage[Client], PHSCRadius[Client], 0.5);

	SatelliteCannonCDTimer[Client] = CreateTimer(PHSCCDTime[Client], SatelliteCannonCDTimerFunction, Client);
}
public Action:PHSCCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	SatelliteCannonCDTimer[Client] = INVALID_HANDLE;
	IsSatelliteCannonReady[Client] = true;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_SC_CHARGED);
	}

	return Plugin_Handled;
}

/* 雷电子 */
public Action:UseLDZ(Client, args)
{
	if(GetClientTeam(Client) == 2) LDZFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:LDZFunction(Client)
{
	if(JD[Client] != 11)
	{
		CPrintToChat(Client, MSG_NEED_JOB11);
		return Plugin_Handled;
	}

	if(LDZLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_31);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_LDZ) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_LDZ), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_LDZ);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=float(LDZLaunchRadius[Client]);
	GetClientAbsOrigin(Client, pos);

	/* Emit impact sound */
	EmitAmbientSound(LDZ_Sound_launch, pos);

	ShowParticle(pos, LDZ_Particle_hit, 0.1);

	new Float:SkyLocation[3];
	SkyLocation[0] = pos[0];
	SkyLocation[1] = pos[1];
	SkyLocation[2] = pos[2] + 2000.0;
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 5.0, BlueColor, 10, 0);//固定外圈BuleColor
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 1.0, 1.0, 10, 10.0, BlueColor, 0);
	TE_SendToAll();

	TE_SetupGlowSprite(pos, g_GlowSprite, 0.5, 5.0, 100);
	TE_SendToAll();

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, LDZDamage[Client], 0 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsLDZed[i] = true;

					new Handle:newh;
					CreateDataTimer(LDZmissInterval[Client], LDZDamage, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(Client, iEntity, LDZDamage[Client], 0, "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(LDZmissInterval[Client], LDZDamage, newh);
				WritePackCell(newh, Client);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}

	CPrintToChatAll(MSG_SKILL_CLD_ANNOUNCE, Client, LDZLv[Client]);

	//PrintToserver("[United RPG] %s启动了雷电子!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:LDZDamage(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
	new Float:Radius=float(LDZRadius[attacker]);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsLDZed[victim] = false;
	}

	/* Emit impact Sound */
	EmitAmbientSound(LDZ_Sound_launch, pos);

	TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 3.0, 100);
	TE_SendToAll();

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(attacker, iEntity, RoundToNearest(LDZDamage[attacker]/(EnergyEnhanceEffect_Attack[attacker])), 0 , "chain_lightning");
				TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
				TE_SendToAll();
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(LDZmissInterval[attacker], LDZDamage, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsLDZed[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(attacker, i, LDZDamage[attacker], 0 , "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 5.0, color, 0);
					TE_SendToAll();
					IsLDZed[i] = true;

					new Handle:newh;
					CreateDataTimer(LDZmissInterval[attacker], LDZDamage, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}
	//return Plugin_Handled;
}

/* 暗影嗜血关联2 */
public Action:UseChainmissLightning(Client, args)
{
	if(GetClientTeam(Client) == 2) ChainmissLightningFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
}

public Action:ChainmissLightningFunction(Client)
{
	if(JD[Client] != 3)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
		return Plugin_Handled;
	}

	if(ChainmissLightningLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE);
		return Plugin_Handled;
	}

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=float(ChainmissLightningLaunchRadius[Client]);
	GetClientAbsOrigin(Client, pos);

	/* Emit impact sound */
	EmitAmbientSound(ChainmissLightning_Sound_launch, pos);

	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, 0.1, Radius-99499.1, g_BeamSprite, g_HaloSprite, 0, 90, 0.5, 90.0, 0.0, ClaretColor, 1, 0);//扩散外圈ClaretColor
	TE_SendToAll(0.1);
	TE_SetupBeamRingPoint(pos, Radius-99499.2, 0.1, g_BeamSprite, g_HaloSprite, 0, 90, 0.5, 90.0, 0.0, YellowColor, 1, 0);//扩散外圈ClaretColor
	TE_SendToAll(0.8);
	TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 90, 0.5, 90.0, 0.0, ClaretColor, 1, 0);//扩散外圈ClaretColor
	TE_SendToAll(0.2);
	TE_SetupBeamRingPoint(pos, Radius, 0.1, g_BeamSprite, g_HaloSprite, 0, 90, 0.5, 90.0, 0.0, YellowColor, 1, 0);//扩散外圈ClaretColor
	TE_SendToAll(0.9);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 10);
	TE_SendToAll();

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, ChainmissLightningDamage[Client], 0 , "chainmiss_lightning");
					IsChainmissed[i] = true;

					new Handle:newh;
					CreateDataTimer(ChainmissLightningInterval[Client], ChainmissDamage, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(Client, iEntity, RoundToNearest(ChainmissLightningDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0, "chainmiss_lightning");
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(ChainmissLightningInterval[Client], ChainmissDamage, newh);
				WritePackCell(newh, Client);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}

	CPrintToChat(Client, MSG_SKILL_MEIXINXI_ANNOUNCE, ChainmissLightningLv[Client], HealingBallmissFunction(Client));

	//PrintToserver("", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:ChainmissDamage(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
	new Float:Radius=float(ChainmissLightningRadius[attacker]);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsChainmissed[victim] = false;
	}

	/* Emit impact sound */

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(attacker, iEntity, RoundToNearest(ChainmissLightningDamage[attacker]/(EnergyEnhanceEffect_Attack[attacker])), 1024 , "chainmiss_lightning");
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(ChainmissLightningInterval[attacker], ChainmissDamage, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsChained[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(attacker, i, ChainmissLightningDamage[attacker], 1024 , "chainmiss_lightning");
					IsChainmissed[i] = true;

					new Handle:newh;
					CreateDataTimer(ChainmissLightningInterval[attacker], ChainmissDamage, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}
	//return Plugin_Handled;
}

/* 超级狂飙模式关联 */
public Action:UseChainkbLightning(Client, args)
{
	if(GetClientTeam(Client) == 2) ChainkbLightningFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
}

public Action:ChainkbLightningFunction(Client)
{
	if(JD[Client] != 2)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(ChainkbLightningLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	new Float:Radius=float(ChainkbLightningLaunchRadius[Client]);
	GetClientAbsOrigin(Client, pos);

	/* Emit impact sound */
	ShowParticle(pos, FireBall_Particle_Fire01, 5.0);
	ShowParticle(pos, FireBall_Particle_Fire02, 5.0);
	ShowParticle(pos, FireBall_Particle_Fire03, 5.0);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(Client, i, ChainkbLightningDamage[Client], 1024 , "chainkb_lightning");
					LittleFlower(entpos, EXPLODE, Client);
					IsChainkbed[i] = true;

					new Handle:newh;
					CreateDataTimer(ChainLightningInterval[Client], ChainkbDamage, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(Client, iEntity, RoundToNearest(ChainkbLightningDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0, "chain_lightning");
				LittleFlower(entpos, EXPLODE, Client);
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(ChainkbLightningInterval[Client], ChainkbDamage, newh);
				WritePackCell(newh, Client);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}

	CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN, ChainkbLightningLv[Client]);

	//PrintToserver("", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:ChainkbDamage(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
	new Float:Radius=float(ChainkbLightningRadius[attacker]);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsChainkbed[victim] = false;
	}

	/* Emit impact Sound */
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(attacker, iEntity, RoundToNearest(ChainkbLightningDamage[attacker]/(EnergyEnhanceEffect_Attack[attacker])), 1024 , "chainkb_lightning");
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(ChainkbLightningInterval[attacker], ChainkbDamage, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsChainkbed[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(attacker, i, ChainkbLightningDamage[attacker], 1024 , "chainkb_lightning");
					IsChainkbed[i] = true;

					new Handle:newh;
					CreateDataTimer(ChainkbLightningInterval[attacker], ChainkbDamage, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}
	//return Plugin_Handled;
}

public Action:StatusUp(Handle:timer, any:Client)
{
	if (IsValidPlayer(Client))
	{
		new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
		if(iClass != CLASS_TANK)	RebuildStatus(Client, false);
	}
	return Plugin_Handled;
}

//重建角色状态
stock Action:RebuildStatus(Client, bool:IsFullHP = false, bool:Read = false)
{
	new MaxHP;

	if(GetClientTeam(Client) == 3)
	{
		new iClass = GetEntProp(Client, Prop_Send, "m_zombieClass");
		switch(iClass)
		{
			case 1: MaxHP = GetConVarInt(FindConVar("z_gas_health"));
			case 2: MaxHP = GetConVarInt(FindConVar("z_exploding_health"));
			case 3: MaxHP = GetConVarInt(FindConVar("z_hunter_health"));
			case 4: MaxHP = GetConVarInt(FindConVar("z_spitter_health"));
			case 5: MaxHP = GetConVarInt(FindConVar("z_jockey_health"));
			case 6: MaxHP = GetConVarInt(FindConVar("z_charger_health"));
		}
	}
	else
		MaxHP = 100;

	new NewMaxHP;
	if (GeneLv[Client] > 0) //基因改造
	{
		SetEntProp(Client, Prop_Data, "m_iMaxHealth", RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + GeneHealthEffect[Client]));
		NewMaxHP = RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + GeneHealthEffect[Client]);
	}
	else if (LinliLv[Client] > 0) //灵力上限
	{
		SetEntProp(Client, Prop_Data, "m_iMaxHealth", RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + GeneHealthzEffect[Client]));
		NewMaxHP = RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + GeneHealthzEffect[Client]);
	}
	else if (SszlLv[Client] > 0) //死神之力
	{
		SetEntProp(Client, Prop_Data, "m_iMaxHealth", RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + GeneHealthzkEffect[Client]));
		NewMaxHP = RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + GeneHealthzkEffect[Client]);
	}
	else if (SWGZLv[Client] > 0) //死亡改造
	{
		SetEntProp(Client, Prop_Data, "m_iMaxHealth", RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + SWGZEffect[Client]));
		NewMaxHP = RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + SWGZEffect[Client]);
	}
	else if (JYSQLv[Client] > 0) //坚硬身躯
	{
		SetEntProp(Client, Prop_Data, "m_iMaxHealth", RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + JYSQEffect[Client]));
		NewMaxHP = RoundToNearest(MaxHP * (1.0+HealthEffect[Client]) + JYSQEffect[Client]);
	}
	else
	{
		SetEntProp(Client, Prop_Data, "m_iMaxHealth", RoundToNearest(MaxHP * (1.0+HealthEffect[Client])));
		NewMaxHP = RoundToNearest(MaxHP*(1.0+HealthEffect[Client]));
	}

	new HP = GetClientHealth(Client);

	if(HP > NewMaxHP)
		SetEntityHealth(Client, NewMaxHP);

	new Float:speed = 1.0;
	if(IsSprintEnable[Client])
	{
		speed = 1.6 * (1.0 + AgiEffect[Client]);
		SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", speed);
		//SetEntityGravity(Client, 2.4 / (1.0 + AgiEffect[Client]));
	}
	else
	{
		speed = 1.0 + AgiEffect[Client];
		SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", speed);
		//SetEntityGravity(Client, 1.8 / (1.0 + AgiEffect[Client]));
	}

	//设置装备加成属性
	if (!Read)
	{
		ResetPlayerZBData(Client, speed, NewMaxHP);
	}
	else
	{
		ResetPlayerZBData(Client, speed, NewMaxHP, true);		//玩家查看装备属性
	}

	//是否满血
	if(IsFullHP)
	{
		//CPrintToChatAll("IsFullHP=YES");
		SetEntityHealth(Client, GetEntProp(Client, Prop_Data, "m_iMaxHealth"));	//修改玩家血量
	}

}
public Action:Event_HealSuccess(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));
	new HealSucTarget = GetClientOfUserId(GetEventInt(event, "subject"));

	if (GetConVarInt(HealTeammateExp) > 0 && Client != HealSucTarget)
	{
		if (JD[Client]==4)
		{
			EXP[Client] += GetConVarInt(HealTeammateExp)+Job4_ExtraReward[Client] + VIPAdd(Client, GetConVarInt(HealTeammateExp), 1, true);
			Cash[Client] += GetConVarInt(HealTeammateCash)+Job4_ExtraReward[Client] + VIPAdd(Client, GetConVarInt(HealTeammateCash)+Job4_ExtraReward[Client], 1, false);
			CPrintToChat(Client, MSG_EXP_HEAL_SUCCESS_JOB4, GetConVarInt(HealTeammateExp),
						Job4_ExtraReward[Client], GetConVarInt(HealTeammateCash), Job4_ExtraReward[Client]);
		}
		else if (JD[Client]==0 && Lv[Client] < 20)
		{
			EXP[Client] += GetConVarInt(HealTeammateExp) + VIPAdd(Client, GetConVarInt(HealTeammateExp), 1, true);
			Cash[Client] += GetConVarInt(HealTeammateCash) + VIPAdd(Client, GetConVarInt(HealTeammateCash), 1, false);
			CPrintToChat(Client, MSG_EXP_HEAL_SUCCESS, GetConVarInt(HealTeammateExp), GetConVarInt(HealTeammateCash));
		}
		if(Renwu[Client] == 1)
        {
            if(Jenwu[Client] == 16)
            {
                YLDY[Client]++;
            }
        }
	}
	if(GetClientTeam(HealSucTarget) == 2 && !IsFakeClient(HealSucTarget) && Lv[HealSucTarget] > 0)
	{
		//SetEntProp(HealSucTarget, Prop_Data, "m_iMaxHealth", RoundToNearest(100*(1+HealthEffect[HealSucTarget])));
		//SetEntProp(HealSucTarget, Prop_Data, "m_iHealth", RoundToNearest(100*(1+HealthEffect[HealSucTarget])));
		/*打包补满血*/
		CheatCommand(HealSucTarget, "give", "health");

	}
	return Plugin_Continue;
}


/************************************************************************
*	技能Funstion END
************************************************************************/

/***********************************************
	使用技能菜单
***********************************************/

public Action:Menu_UseSkill(Client, args)
{
	if (!IsValidPlayer(Client, false))
		return Plugin_Handled;

	MenuFunc_UseSkill(Client);
	return Plugin_Handled;
}
public Action:MenuFunc_UseSkill(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "使用技能 MP: %d / %d", MP[Client], MaxMP[Client]);
	SetPanelTitle(menu, line);
	if(GetClientTeam(Client) == 2)
	{
		if (VIP[Client] <= 0)
			Format(line, sizeof(line), "[通用]治疗术 (Lv.%d / MP:%d)", HealingLv[Client], GetConVarInt(Cost_Healing));
		else
			Format(line, sizeof(line), "[通用]高级治疗术 (Lv.%d / MP:%d)", HealingLv[Client], GetConVarInt(Cost_Healing));
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[通用]地震术 (Lv.%d / MP:%d)", EarthQuakeLv[Client], GetConVarInt(Cost_EarthQuake));
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[通用]重机枪(Lv.%d / MP:5000)", GELINLv[Client]);
		DrawPanelItem(menu, line);

		if(JD[Client] == 1)
		{
			Format(line, sizeof(line), "[工程师猎手]子弹制造术 (Lv.%d / MP:%d)", AmmoMakingLv[Client], GetConVarInt(Cost_AmmoMaking));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[工程师猎手]卫星轨道炮 (Lv.%d / MP:%d)", SatelliteCannonLv[Client], GetConVarInt(Cost_SatelliteCannon));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 2)
		{
			Format(line, sizeof(line), "[士兵]疾风步 (Lv.%d / MP:%d)", SprintLv[Client], MP_Sprint);
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[士兵]炎神装填 (Lv.%d / MP:%d)", InfiniteAmmoLv[Client], MP_Ammo);
			DrawPanelItem(menu, line);
			if (NewLifeCount[Client] >= 1)
			{
				Format(line, sizeof(line), "[究极]超级狂飙模式 (Lv.%d / MP:%d)", BioShieldkbLv[Client], MP_ChainkbLightning);
				DrawPanelItem(menu, line);
			}
		}
		else if(JD[Client] == 3)
		{
			Format(line, sizeof(line), "[圣骑士]无敌术 (Lv.%d / MP:%d)", BioShieldLv[Client], GetConVarInt(Cost_BioShield));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[圣骑士]反伤术 (Lv.%d / MP:%d)", DamageReflectLv[Client], GetConVarInt(Cost_DamageReflect));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line),  "[圣骑士]近战嗜血术 (Lv.%d / MP:%d)", MeleeSpeedLv[Client], GetConVarInt(Cost_MeleeSpeed));
			DrawPanelItem(menu, line);
			if (NewLifeCount[Client] >= 1)
			{
				Format(line, sizeof(line), "[究极]暗影嗜血术 (Lv.%d / MP:%d)", BioShieldmissLv[Client], GetConVarInt(Cost_BioShieldmiss));
				DrawPanelItem(menu, line);
			}
		}
		else if(JD[Client] == 4)
		{
			Format(line, sizeof(line), "[心灵医师]冰之传送术 (Lv.%d / MP:%d)", TeleportToSelectLv[Client], GetConVarInt(Cost_TeleportToSelect));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[心灵医师]嗜血光球术 (Lv.%d / MP:%d)", HolyBoltLv[Client], GetConVarInt(Cost_HolyBolt));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[心灵医师]心灵传送术 (Lv.%d / MP:%d)", TeleportTeamLv[Client], GetConVarInt(Cost_TeleportTeammate));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[心灵医师]额外的电击器 (剩余:%d个)", defibrillator[Client]);
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[心灵医师]圣域之风 (Lv.%d / MP:%d)", HealingBallLv[Client], GetConVarInt(Cost_HealingBall));
			DrawPanelItem(menu, line);
			if (NewLifeCount[Client] >= 1)
			{
				Format(line, sizeof(line), "[究极]吸引术 (Lv.%d / MP:%d)", TeleportTeamztLv[Client], MaxMP[Client]);
				DrawPanelItem(menu, line);
			}
		}
		else if(JD[Client] == 5)
		{
			Format(line, sizeof(line), "[魔法师]地狱火 (Lv.%d / MP:%d)", FireBallLv[Client], GetConVarInt(Cost_FireBall));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[魔法师]寒冰爆弹 (Lv.%d / MP:%d)", IceBallLv[Client], GetConVarInt(Cost_IceBall));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[魔法师]连锁闪电 (Lv.%d / MP:%d)", ChainLightningLv[Client], GetConVarInt(Cost_ChainLightning));
			DrawPanelItem(menu, line);
			if (NewLifeCount[Client] >= 1)
			{
				Format(line, sizeof(line), "[究极]终极雷矢 (Lv.%d / MP:%d)", SatelliteCannonmissLv[Client], MaxMP[Client]);
				DrawPanelItem(menu, line);
			}
		}
		else if(JD[Client] == 6)
		{
			Format(line, sizeof(line), "[弹药专家]破碎弹 (Lv.%d / MP:%d)", BrokenAmmoLv[Client], MP_BrokenAmmo);
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[弹药专家]渗毒弹 (Lv.%d / MP:%d)", PoisonAmmoLv[Client], MP_PoisonAmmo);
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[弹药专家]嗜血弹 (Lv.%d / MP:%d)", SuckBloodAmmoLv[Client], MP_SuckBloodAmmo);
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[弹药专家]区域爆破 (Lv.%d / MP:%d)", AreaBlastingLv[Client], MP_AreaBlasting);
			DrawPanelItem(menu, line);
			if (NewLifeCount[Client] >= 1)
			{
				Format(line, sizeof(line), "[究极]超级镭射炮 (Lv.%d / MP:%d)", LaserGunLv[Client], MaxMP[Client]);
				DrawPanelItem(menu, line);
			}
		}
		else if(JD[Client] == 7)
		{
			Format(line, sizeof(line), "[地狱使者]审判领域 (Lv.%d / MP:%d)", AreaBlastingexLv[Client], GetConVarInt(Cost_AreaBlastingex));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 8)
		{
			Format(line, sizeof(line), "[死神]大地之怒 (Lv.%d / MP:%d)", DyzhLv[Client], GetConVarInt(Cost_Dyzh));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 9)
		{
			Format(line, sizeof(line), "[黑暗行者]子弹工程 (Lv.%d / MP:%d)", ZdgcLv[Client], GetConVarInt(Cost_Zdgc));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[黑暗行者]超强地震 (Lv.%d / MP:%d)", CqdzLv[Client], GetConVarInt(Cost_Cqdz));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 10)
		{
			Format(line, sizeof(line), "[死亡祭师]死亡护体 (Lv.%d / MP:%d)", SWHTLv[Client], GetConVarInt(Cost_SWHT));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[死亡祭师]无限能源 (Lv.%d / MP:%d)", WXNYLv[Client], GetConVarInt(Cost_WXNY));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 11)
		{
			Format(line, sizeof(line), "[雷电使者]雷电子 (Lv.%d / MP:%d)", LDZLv[Client], GetConVarInt(Cost_LDZ));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[雷电使者]光之速 (Lv.%d / MP:%d)", GZSLv[Client], GetConVarInt(Cost_GZS));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[雷电使者]致命闪电 (Lv.%d / MP:%d)", YLTJLv[Client], GetConVarInt(Cost_YLTJ));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[雷电使者]雷子弹 (Lv.%d / MP:%d)", LZDLv[Client], MP_LZD);
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 12)
		{
			Format(line, sizeof(line), "[影武者]玄冰风暴 (Lv.%d / MP:%d)", XBFBLv[Client], GetConVarInt(Cost_XBFB));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[影武者]风暴之怒 (Lv.%d / MP:%d)", FBZNLv[Client], GetConVarInt(Cost_FBZN));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[影武者]武者之光 (Lv.%d / MP:%d)", WZZGLv[Client], GetConVarInt(Cost_WZZG));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 13)
		{
			Format(line, sizeof(line), "[审判者]生命之书(剩余:%d本)", SMZS[Client]);
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[审判者]补给之书(剩余:%d本)", FHZS[Client]);
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[审判者]毁灭之书 (Lv.%d / MP:%d)", HMZSLv[Client], GetConVarInt(Cost_HMZS));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[审判者]审判之书 (Lv.%d / MP:%d)", SPZSLv[Client], GetConVarInt(Cost_SPZS));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[审判者]极冰盛宴 (Lv.%d / MP:%d)", JBSYLv[Client], GetConVarInt(Cost_JBSY));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 14)
		{
			Format(line, sizeof(line), "[毒龙]嗜血之光 (Lv.%d / MP:%d)", SXZGLv[Client], GetConVarInt(Cost_SXZG));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[毒龙]毒龙爆破 (Lv.%d / MP:%d)", BBBSLv[Client], GetConVarInt(Cost_BBBS));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[毒龙]毒龙之光 (Lv.%d / MP:%d)", DSZGLv[Client], GetConVarInt(Cost_DSZG));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 15)
		{
			Format(line, sizeof(line), "[幻影统帅]幻影之炎 (Lv.%d / MP:%d)", PHFRLv[Client], GetConVarInt(Cost_PHFR));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[幻影统帅]幻影爆破 (Lv.%d / MP:%d)", PHABLv[Client], MP_PHAB);
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[幻影统帅]幻影之血 (Lv.%d / MP:%d)", PHZGLv[Client], GetConVarInt(Cost_PHZG));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[幻影统帅]幻影炮术 (Lv.%d / MP:%d)", PHSCLv[Client], GetConVarInt(Cost_PHSC));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 16)
		{
			Format(line, sizeof(line), "[复仇者]复仇欲望 (Lv.%d / MP:%d)", PHABALv[Client], GetConVarInt(Cost_PHABA));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[复仇者]爆破光球 (Lv.%d / MP:%d)", PHZGALv[Client], GetConVarInt(Cost_PHZGA));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[复仇者]闪电光球 (Lv.%d / MP:%d)", PHSDLv[Client], GetConVarInt(Cost_PHSD));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[复仇者]死亡契约 (Lv.%d / MP:%d)", PHFRALv[Client], GetConVarInt(Cost_PHFRA));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[复仇者]献祭 (Lv.%d / MP:%d)", XJLv[Client], GetConVarInt(Cost_XJ));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 17)
		{
			Format(line, sizeof(line), "[大祭祀]祭祀之光 (Lv.%d / MP:%d)", LLLZLv[Client], GetConVarInt(Cost_LLLZ));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[大祭祀]魔法冲击 (Lv.%d / MP:%d)", LLLELv[Client], GetConVarInt(Cost_LLLE));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[大祭祀]毁灭压制 (Lv.%d / MP:%d)", LLLSLv[Client], GetConVarInt(Cost_LLLS));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 18)
		{
			Format(line, sizeof(line), "[狂战士]幻影剑舞 (Lv.%d / MP:%d)", HYJWLv[Client], GetConVarInt(Cost_HYJW));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[狂战士]怒气爆发 (Lv.%d / MP:%d)", NQBFLv[Client], GetConVarInt(Cost_NQBF));
			DrawPanelItem(menu, line);
			Format(line, sizeof(line), "[狂战士]血之狂暴 (Lv.%d / MP:%d)", XZKBLv[Client], GetConVarInt(Cost_XZKB));
			DrawPanelItem(menu, line);
		}
		else if(JD[Client] == 19)
		{
		    Format(line, sizeof(line), "[变异坦克]变身坦克(Lv.%d / MP:5000)", BSTKLv[Client]);
		    DrawPanelItem(menu, line);
		}
	}
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, DeSkiMenu, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}
public DeSkiMenu(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		if(GetClientTeam(Client) == 2) {
			switch(param)
			{
				case 1:
				{
					HealingFunction(Client);
					MenuFunc_UseSkill(Client);
				}
				case 2:
				{
					EarthQuakeFunction(Client);
					MenuFunc_UseSkill(Client);
				}
				case 3:
				{
					if(GELINLv[Client] <= 0){
						CPrintToChat(Client, MSG_NEED_SKILL_0);
					}else{
					
						if(MP[Client] >= 1000){
							MP[Client] -= 1000;
							CheatCommand(Client, "sm_machine","");
						}else{
							PrintHintText(Client, "[技能] 你的MP不足够发动技能!需要MP: 1000, 现在MP: %d", MP[Client]);
						}
					}
				}
			} if(JD[Client] == 1) { //工程师猎手
				switch(param)
				{
					case 4:
					{
						AmmoMakingFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						SatelliteCannonFunction(Client);
						MenuFunc_UseSkill(Client);
					}

				}
			}
			else if(JD[Client] == 2)
			{ //士兵
				switch(param)
				{
					case 4:
					{
						SprintFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						InfiniteAmmoFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						BioShieldkbFunction(Client);
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 3)
			{ //圣骑士
				switch(param)
				{
					case 4:
					{
						BioShieldFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						DamageReflectFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						MeleeSpeedFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 7:
					{
						BioShieldmissFunction(Client);
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 4)
			{ //心灵医师
				switch(param) {
					case 4:
					{
						TeleportToSelectMenu(Client);
					}
					case 5:
					{
						LightBall(Client);
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						TeleportTeam(Client);
					}
					case 7:
					{
						if(defibrillator[Client]>0)
						{
							CheatCommand(Client, "give", "defibrillator");
							defibrillator[Client] -= 1;
						}
						else CPrintToChat(Client, "额外电击器已用完!");
						MenuFunc_UseSkill(Client);
					}
					case 8:
					{
						HealingBallFunction(Client);
						MenuFunc_UseSkill(Client);
					}
					case 9:
					{
						TeleportTeamzt(Client);
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 5)
			{ //冰囧丨暗夜术士
				switch(param)
				{
					case 4:
					{
						FireBallFunction(Client);//地狱火
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						IceBallFunction(Client);//寒冰爆弹
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						ChainLightningFunction(Client);//连锁闪电
						MenuFunc_UseSkill(Client);
					}
					case 7:
					{
						SatelliteCannonmissFunction(Client);//终极雷矢
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 6)  //弹药专家
			{
				switch(param)
				{
					case 4:
					{
						BrokenAmmo_Action(Client);//破碎弹
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						PoisonAmmo_Action(Client);//渗毒弹
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						SuckBloodAmmo_Action(Client);//嗜血弹
						MenuFunc_UseSkill(Client);
					}
					case 7:
					{
						AreaBlasting_Action(Client);//区域爆破
						MenuFunc_UseSkill(Client);
					}
					case 8:
					{
						LaserGun_Action(Client);//超级镭射炮
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 7)  //地狱使者
			{
				switch(param)
				{
					case 4:
					{
						AreaBlastingex_Action(Client);//审判领域
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 8)  //死神
			{
				switch(param)
				{
					case 4:
					{
						DyzhFunction(Client);//大地之怒
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 9)  //黑暗行者
			{
				switch(param)
				{
					case 4:
					{
						ZdgcFunction(Client);//子弹工程
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						CqdzFunction(Client);//超强地震
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 10)  //死亡祭师
			{
				switch(param)
				{
					case 4:
					{
						SWHTFunction(Client);//死亡护体
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						WXNYFunction(Client);//无限能源
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 11)  //雷电使者
			{
				switch(param)
				{
					case 4:
					{
						LDZFunction(Client);//雷电子
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						GZSFunction(Client);//光之速
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						YLTJFunction(Client);//致命闪电
						MenuFunc_UseSkill(Client);
					}
					case 7:
					{
						LZD_Action(Client);//雷子弹
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 12)  //影武者
			{
				switch(param)
				{
					case 4:
					{
						XBFBFunction(Client);//玄冰风暴
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						FBZNFunction(Client);//风暴之怒
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						WZZGFunction(Client);//风暴之怒
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 13)  //审判者
			{
				switch(param)
				{
					case 4:
					{
						if(SMZS[Client]>0)
						{
							CheatCommand(Client, "give", "health");
							SMZS[Client] -= 1;
						}
						else CPrintToChat(Client, "生命之书已经用完了!");
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						if(FHZS[Client]>0)
						{
							CheatCommand(Client, "give", "rifle_ak47");
							CheatCommand(Client, "give", "first_aid_kit");
							CheatCommand(Client, "give", "adrenaline");
							CheatCommand(Client, "give", "pistol_magnum");
							CheatCommand(Client, "give", "pipe_bomb");
							FHZS[Client] -= 1;
						}
						else CPrintToChat(Client, "补给之书已经用完了!");
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						HMZSFunction(Client);//毁灭之书
						MenuFunc_UseSkill(Client);
					}
					case 7:
					{
						SPZSFunction(Client);//审判之书
						MenuFunc_UseSkill(Client);
					}
					case 8:
					{
						JBSYFunction(Client);//极冰盛宴
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 14)  //毒龙
			{
				switch(param)
				{
					case 4:
					{
						SXZG(Client);//嗜血之光
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						BBBS_Action(Client);//毒龙爆破
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						DSZGFunction(Client);//毒龙之光
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 15)  //幻影统帅
			{
				switch(param)
				{
					case 4:
					{
						PHFRFunction(Client);//幻影之炎
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						PHAB_Action(Client);//幻影爆破
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						PHZG(Client);//幻影之血
						MenuFunc_UseSkill(Client);
					}
					case 7:
					{
						PHSCFunction(Client);//幻影炮
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 16)  //复仇者
			{
				switch(param)
				{
					case 4:
					{
						PHABAFunction(Client);//复仇欲望
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						PHZGA(Client);//爆破光球
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						PHSDFunction(Client);//闪电光球
						MenuFunc_UseSkill(Client);
					}
					case 7:
					{
						PHFRAFunction(Client);//死亡契约
						MenuFunc_UseSkill(Client);
					}
					case 8:
					{
						XJFunction(Client);//献祭
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 17)  //大祭祀
			{
				switch(param)
				{
					case 4:
					{
						LLLZFunction(Client);//祭祀之光
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						LLLEFunction(Client);//魔法冲击
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						LLLSFunction(Client);//毁灭压制
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 18)  //狂战士
			{
				switch(param)
				{
					case 4:
					{
						HYJWFunction(Client);//幻影剑舞
						MenuFunc_UseSkill(Client);
					}
					case 5:
					{
						NQBF_Action(Client);//怒气爆发
						MenuFunc_UseSkill(Client);
					}
					case 6:
					{
						XZKBFunction(Client);//血之狂暴
						MenuFunc_UseSkill(Client);
					}
				}
			}
			else if(JD[Client] == 19)  //变异坦克
			{
				switch(param)
			    {
				    case 4:
				    {
					   if(GELINLv[Client] <= 0)  
                        {       
	                        TZMC[Client] = 1;
	                        new Num = 1;
	                        for(new x=1; x<=Num; x++)
	                        	SetEntityModel(Client, "models/infected/hulk.mdl");		
	                        CPrintToChatAll("\x03【地狱】恭喜玩家%N开启坦克模式", Client);	      
                        }
				    }
				}
			}
	    }
    }
}


/******************************************************
*	United RPG选单
*******************************************************/
public Action:Menu_RPG(Client,args)
{
	if (!IsPasswordConfirm[Client])
	{
		CPrintToChat(Client, "\x03[系统] {red}你没登录或注册,请输入密码登录!");
		CPrintToChat(Client, "\x03[系统] {red}输入密码方法: /pw或/rpgpw + 空格 +密码!");
		CPrintToChat(Client, "\x03[系统] {red}输入!qiandao进行游戏签到奖励!");
	}
	MenuFunc_RPG(Client);
	return Plugin_Handled;
}
public Action:MenuFunc_RPG(Client)
{
	if (!IsValidPlayer(Client) || IsFakeClient(Client))
		return Plugin_Handled;

	new Handle:menu = CreateMenu(RPG_MenuHandler);
	decl String:job[32], String:m_viptype[32], String:LIZSA[1024];
	if(JD[Client] == 0)			Format(job, sizeof(job), "未转职");
	else if(JD[Client] == 1)	Format(job, sizeof(job), "工程师猎手");
	else if(JD[Client] == 2)	Format(job, sizeof(job), "士兵");
	else if(JD[Client] == 3)	Format(job, sizeof(job), "圣骑士");
	else if(JD[Client] == 4)	Format(job, sizeof(job), "心灵医师");
	else if(JD[Client] == 5)	Format(job, sizeof(job), "魔法师");
	else if(JD[Client] == 6)	Format(job, sizeof(job), "弹药专家");
	else if(JD[Client] == 7)	Format(job, sizeof(job), "地狱使者");
	else if(JD[Client] == 8)	Format(job, sizeof(job), "死神");
	else if(JD[Client] == 9)	Format(job, sizeof(job), "黑暗行者");
	else if(JD[Client] == 10)	Format(job, sizeof(job), "死亡祭师");
	else if(JD[Client] == 11)	Format(job, sizeof(job), "雷电使者");
	else if(JD[Client] == 12)	Format(job, sizeof(job), "影武者");
	else if(JD[Client] == 13)	Format(job, sizeof(job), "审判者");
	else if(JD[Client] == 14)	Format(job, sizeof(job), "毒龙");
	else if(JD[Client] == 15)	Format(job, sizeof(job), "幻影统帅");
	else if(JD[Client] == 16)	Format(job, sizeof(job), "复仇者");
	else if(JD[Client] == 17)	Format(job, sizeof(job), "大祭祀");
	else if(JD[Client] == 18)	Format(job, sizeof(job), "狂战士");
	else if(JD[Client] == 19)	Format(job, sizeof(job), "变异坦克");

	if (VIP[Client] <= 0)
		Format(m_viptype, sizeof(m_viptype), "你的身份:普通VIP");
	else if (VIP[Client] == 1)
		Format(m_viptype, sizeof(m_viptype), "你的身份:白银VIP1");
	else if (VIP[Client] == 2)
		Format(m_viptype, sizeof(m_viptype), "你的身份:黄金VIP2");
	else if (VIP[Client] == 3)
		Format(m_viptype, sizeof(m_viptype), "你的身份:水晶VIP3");
	else if (VIP[Client] == 4)
		Format(m_viptype, sizeof(m_viptype), "你的身份:至尊VIP4");
	else if (VIP[Client] == 5)
		Format(m_viptype, sizeof(m_viptype), "你的身份:创世VIP5");
	else if (VIP[Client] == 6)
		Format(m_viptype, sizeof(m_viptype), "你的身份:末日VIP6");


	if(Lis[Client] == 0)			Format(LIZSA, sizeof(LIZSA), "人类");
	else if(Lis[Client] == 1)	Format(LIZSA, sizeof(LIZSA), "天使");
	else if(Lis[Client] == 2)	Format(LIZSA, sizeof(LIZSA), "恶魔");
	else if(Lis[Client] == 3)	Format(LIZSA, sizeof(LIZSA), "地狱");
	else if(Lis[Client] == 4)	Format(LIZSA, sizeof(LIZSA), "圣灵");

	decl String:line[256];
	Format(line, sizeof(line),
	"%s 力量属性:%s 大过:%d次 转生:%d \n等级:Lv.%d 金钱:%d 职业:%s \n经验:%d/%d 求生币:%d 烈焰勋章:%d枚\n力量:%d 敏捷:%d 生命:%d 耐力:%d 智力:%d\n",
		m_viptype, LIZSA, KTCount[Client], NewLifeCount[Client], Lv[Client], Cash[Client], job,
		EXP[Client], GetConVarInt(LvUpExpRate)*(Lv[Client]+1), XB[Client], Lyxz[Client],
		Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
	SetMenuTitle(menu, line);


	Format(line, sizeof(line), "使用/技能(MP: %d/%d)", MP[Client], MaxMP[Client]);
	AddMenuItem(menu, "item0", line);
	AddMenuItem(menu, "item1", "枪系物理专属技能");
	Format(line, sizeof(line), "职业/系统(技能点:%d 属性点:%d)", SkillPoint[Client], StatusPoint[Client]);
	AddMenuItem(menu, "item2", line);
	AddMenuItem(menu, "item3", "队友/装备");
	AddMenuItem(menu, "item4", "拜师/称号");
	AddMenuItem(menu, "item5", "会员/补给");
	AddMenuItem(menu, "item6", "装备/辅助");
	AddMenuItem(menu, "item7", "神秘/商店");
	AddMenuItem(menu, "item8", "精灵/系统");

	SetMenuPagination(menu, MENU_NO_PAGINATION);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public RPG_MenuHandler(Handle:menu, MenuAction:action, Client, IteamNum)
{
	if (!IsValidPlayer(Client) || IsFakeClient(Client))
		return;

	if (action == MenuAction_Select) {
		switch (IteamNum)
		{
			case 0: MenuFunc_UseSkill(Client);		//使用/技能
			case 1: MenuFunc_RobotBuy(Client);		//枪系物理专属技能
			case 2: MenuFunc_RPG_Learn(Client);		//转职/加点
			case 3: MenuFunc_ViewItemPlayer(Client);//队友/装备
			case 4: MenuFunc_RenWuQian(Client);     //拜师/称号
			case 5: MenuFunc_VIP(Client);			//会员/补给
			case 6: MenuFunc_ZHXT(Client);			//装备/辅助
			case 7: Menu_Buy(Client);
			case 8: MenuFunc_GONG(Client);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

/* 拜师/称号 */
public Action:MenuFunc_RenWuQian(Client)
{
	decl String:line[256];

	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "拜师/称号");
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "拜师/收徒");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "荣誉/称号")
	DrawPanelItem(menu, line);
	DrawPanelText(menu, " \n");
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_RenWuQian, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}

public MenuHandler_RenWuQian(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		switch (itemNum)
		{
			case 1:
			{
				MenuFunc_Master(Client);
			}
			case 2:
			{
				MenuFunc_RYCH(Client);
			}
			case 3:
			{
				MenuFunc_RPG(Client);
			}
		}
	}
}

//被动技能//精灵系统//
public Action:MenuFunc_GONG(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "被动|精灵|强化");
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "精灵/系统");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "枪支/强化");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "强化/石头");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "装备/商城");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "盒子/宝盒");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "金币/装备");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "会员/购买");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "任务/系统");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回RPG选单");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_GONG, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_GONG(Handle:menu, MenuAction:action, Client, param)
{
    if (action == MenuAction_Select)
    {
        switch (param)
        {
			case 1: MenuFunc_JLBAG(Client);
			case 2: MenuFunc_Qhcd(Client);
			case 3: MenuFunc_Eqgou(Client);
			case 4: MenuFunc_ZBGM(Client);
			case 5: MenuFunc_HZXT(Client);
			case 6: MenuFunc_JBZBSC(Client);
			case 7: MenuFunc_Vbuy(Client);
			case 8: MenuFunc_RWCD(Client);
			case 9: MenuFunc_RPG(Client);
		}
	}
}


//盒子系统
public Action:MenuFunc_HZXT(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "神秘盒子/炎神宝盒");
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "炎神/宝盒");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回RPG选单");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_HZXT, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_HZXT(Handle:menu, MenuAction:action, Client, param)
{
    if (action == MenuAction_Select)
    {
        switch (param)
        {
			case 1: MenuFunc_Eqboxgz(Client);
			case 2: MenuFunc_RPG(Client);
		}
	}
}

//整合系统
public Action:MenuFunc_ZHXT(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "****装备|背包***");
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "═══我的背包═══");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "═══装备|道具═══");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回RPG选单");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_ZHXT, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_ZHXT(Handle:menu, MenuAction:action, Client, param)
{
    if (action == MenuAction_Select)
    {
        switch (param)
        {
			case 1: MenuFunc_IBag(Client);//我的背包
			case 2: MenuFunc_MyItem(Client); 		//我的装备丨道具
			case 3: MenuFunc_RPG(Client);
		}
	}
}

/* 加入游戏 */
public Action:Johnson_joingame1(Client)
{
	if (IsValidPlayer(Client) && !IsFakeClient(Client))
		{
			if (GetClientTeam(Client) != 2)
				ChangeTeam(Client, 2);
			else
				PrintHintText(Client, "你早已加入僵尸歼灭队,无需再次加入!");
		}
}

/* 查看属性 */
public Action:Menu_ViewSkill(Client, args)
{
	MenuFunc_RPG_Learn(Client);
	return Plugin_Handled;
}

/* 转职|加点 */
public MenuFunc_RPG_Learn(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_RPG_Learn);
	decl String:line[128];
	Format(line, sizeof(line), "学习技能|分配属性|转职转生 \n快捷键:[M键]");
	SetMenuTitle(menu, line);

	Format(line, sizeof(line),  "分配/属性(属性点剩余:%d)", StatusPoint[Client]);
	AddMenuItem(menu, "iteam0", line);
	Format(line, sizeof(line),  "学习/技能(技能点剩余:%d)", SkillPoint[Client]);
	AddMenuItem(menu, "iteam1", line);
	AddMenuItem(menu, "iteam2", "转职.转生.洗点");
	AddMenuItem(menu, "iteam3", "购买/会员");
	AddMenuItem(menu, "iteam4", "购买/金钱");
	AddMenuItem(menu, "iteam6", "签到/系统");
	AddMenuItem(menu, "iteam6", "其他/礼包");
	

	SetMenuExitBackButton(menu, true);

	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}

public MenuHandler_RPG_Learn(Handle:menu, MenuAction:action, Client, IteamNum)
{
	if (!IsValidPlayer(Client) || IsFakeClient(Client))
		return;

	if (action == MenuAction_Select) {
		switch (IteamNum)
		{
			case 0: MenuFunc_AddAllStatus(Client);		//配分属性
			case 1: MenuFunc_SurvivorSkill(Client);	//学习技能
			case 2: MenuFunc_Zhuanzhi(Client); 				//转职洗点
			case 3: MenuFunc_Vbuy(Client); 				//购买会员
			case 4: MenuFunc_Dbuy(Client); 			//购买金钱
			case 5: MenuFunc_Qiandao(Client);         //签到/系统//
			case 6: MenuFunc_RPG_Other(Client);         //其他/礼包
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (IteamNum == MenuCancel_ExitBack)
			MenuFunc_RPG(Client);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:MenuFunc_Zhuanzhi(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "转职|转生|洗点");
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "═══玩家职业═══");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "═══玩家洗点═══");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "═══玩家转生═══");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回RPG选单");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Zhuanzhi, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_Zhuanzhi(Handle:menu, MenuAction:action, Client, param)
{
    if (action == MenuAction_Select)
    {
        switch (param)
        {
			case 1: MenuFunc_Job(Client);
			case 2: MenuFunc_ResetStatus(Client);
			case 3:
			{
				if (NewLifeCount[Client] < 17)
					MenuFunc_NewLife(Client);//转生
				else
					PrintHintText(Client, "你的转生次数已达到上限!");
			}
			case 4: MenuFunc_RPG(Client);
		}
	}
}


/* 其他面板 */
public MenuFunc_RPG_Other(Client)
{
	if (!IsValidPlayer(Client) || IsFakeClient(Client))
		return;

	new Handle:menu = CreateMenu(MenuHandler_RPG_Other);
	decl String:job[32], String:m_viptype[32];
	if(JD[Client] == 0)			Format(job, sizeof(job), "未转职");
	else if(JD[Client] == 1)	Format(job, sizeof(job), "工程师猎手");
	else if(JD[Client] == 2)	Format(job, sizeof(job), "士兵");
	else if(JD[Client] == 3)	Format(job, sizeof(job), "圣骑士");
	else if(JD[Client] == 4)	Format(job, sizeof(job), "心灵医师");
	else if(JD[Client] == 5)	Format(job, sizeof(job), "魔法师");
	else if(JD[Client] == 6)	Format(job, sizeof(job), "弹药专家");
	else if(JD[Client] == 7)	Format(job, sizeof(job), "地狱使者");
	else if(JD[Client] == 8)	Format(job, sizeof(job), "死神");
	else if(JD[Client] == 9)	Format(job, sizeof(job), "黑暗行者");
	else if(JD[Client] == 10)	Format(job, sizeof(job), "死亡祭师");
	else if(JD[Client] == 11)	Format(job, sizeof(job), "雷电使者");
	else if(JD[Client] == 12)	Format(job, sizeof(job), "影武者");
	else if(JD[Client] == 13)	Format(job, sizeof(job), "审判者");
	else if(JD[Client] == 14)	Format(job, sizeof(job), "毒龙");
	else if(JD[Client] == 15)	Format(job, sizeof(job), "幻影统帅");
	else if(JD[Client] == 16)	Format(job, sizeof(job), "复仇者");
	else if(JD[Client] == 17)	Format(job, sizeof(job), "大祭祀");
	else if(JD[Client] == 18)	Format(job, sizeof(job), "狂战士");
	else if(JD[Client] == 19)	Format(job, sizeof(job), "变异坦克");
	if (VIP[Client] <= 0)
		Format(m_viptype, sizeof(m_viptype), "你的身份:普通VIP");
	else if (VIP[Client] == 1)
		Format(m_viptype, sizeof(m_viptype), "你的身份:白银VIP1");
	else if (VIP[Client] == 2)
		Format(m_viptype, sizeof(m_viptype), "你的身份:黄金VIP2");
	else if (VIP[Client] == 3)
		Format(m_viptype, sizeof(m_viptype), "你的身份:水晶VIP3");
	else if (VIP[Client] == 4)
		Format(m_viptype, sizeof(m_viptype), "你的身份:至尊VIP4");
	else if (VIP[Client] == 4)
		Format(m_viptype, sizeof(m_viptype), "你的身份:创世VIP5");
	else if (VIP[Client] == 4)
		Format(m_viptype, sizeof(m_viptype), "你的身份:末日VIP6");

	decl String:line[256];
	Format(line, sizeof(line),
	"%s 大过:%d次 转生:%d \n等级:Lv.%d 金钱:$%d 职业:%s \n经验:%d/%d MP:%d/%d 求生币:%d个\n力量:%d 敏捷:%d 生命:%d 耐力:%d 智力:%d 烈焰勋章:%d枚\n════════════════",
		m_viptype, KTCount[Client], NewLifeCount[Client], Lv[Client], Cash[Client], job,
		EXP[Client], GetConVarInt(LvUpExpRate)*(Lv[Client]+1), MP[Client], MaxMP[Client], XB[Client],
		Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client], Lyxz[Client]);
	SetMenuTitle(menu, line);

	AddMenuItem(menu, "iteam0", "玩家面板");
	AddMenuItem(menu, "iteam1", "游戏排名");
	AddMenuItem(menu, "iteam2", "绑定按键");
	AddMenuItem(menu, "iteam3", "密码使用");
	AddMenuItem(menu, "iteam4", "作者信息");
	AddMenuItem(menu, "iteam5", "手动存档");
	AddMenuItem(menu, "iteam6", "公告菜单");
	AddMenuItem(menu, "iteam7", "升级礼包");


	SetMenuExitBackButton(menu, true);

	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}

public MenuHandler_RPG_Other(Handle:menu, MenuAction:action, Client, IteamNum)
{
	if (!IsValidPlayer(Client) || IsFakeClient(Client))
		return;

	if (action == MenuAction_Select) {
		switch (IteamNum)
		{
			case 0: MenuFunc_TeamInfo(Client);	//玩家面板
			case 1: MenuFunc_Rank(Client);		//游戏排名
			case 2: MenuFunc_BindKeys(Client);		//绑定按键
			case 3: MenuFunc_PasswordInfo(Client);		//密码使用
			case 4: MenuFunc_RPGInfo(Client), MenuFunc_RPG_Other(Client);		//作者信息
			case 5: PlayerManualSave(Client), MenuFunc_RPG_Other(Client);		//手动存档
			case 6: Menu_GameAnnouncement(Client);
			case 7: MenuFunc_Shenbao(Client);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (IteamNum == MenuCancel_ExitBack)
			MenuFunc_RPG(Client);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

//强化菜单
public Action:MenuFunc_Qhcd(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "====强化菜单====");
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "═══强化枪支═══");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "═══强化补偿═══");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "═══材料换取═══");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回装备背包");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Qhcd, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_Qhcd(Handle:menu, MenuAction:action, Client, param)
{
    if (action == MenuAction_Select)
    {
        switch (param)
        {
			case 1: MenuFunc_Qhqz(Client);
            case 2: MenuFunc_psdx(Client);
            case 3: MenuFunc_CLbuy(Client);
			case 4: MenuFunc_RPG(Client);
		}
	}
}


//升级礼包
public Action:MenuFunc_Shenbao(Client)
{
    new Handle:menu = CreatePanel();

    decl String:line[1024];
    Format(line, sizeof(line), "═══【升级礼包:%d份】═══", Libao[Client]);
    SetPanelTitle(menu, line);
    Format(line, sizeof(line), "说明:每升10级可以获得一份");
    DrawPanelText(menu, line);

    Format(line, sizeof(line), "打开礼包");
    DrawPanelItem(menu, line);
    DrawPanelItem(menu, "放弃", ITEMDRAW_DISABLED);

    SendPanelToClient(menu, Client, MenuHandler_Shenbao, MENU_TIME_FOREVER);
    return Plugin_Handled;
}
public MenuHandler_Shenbao(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: DAKAILI(Client);
		}
	}
}
public DAKAILI(Client)
{
	if(Libao[Client] > 0)
	{
		Libao[Client]--;
		new jinwuqi = GetRandomInt(1, 3);

		switch (jinwuqi)
		{
			case 1:           
			{               
				Cash[Client] += 50000;               
				CPrintToChatAll("\x05【升级礼包】玩家%N打开获得50000$!", Client);           
			}
			case 2:           
			{               
				XB[Client] += 10;               
				CPrintToChatAll("\x05【升级礼包】玩家%N打开获得求生币10个!", Client);           
			}
			case 3:
			{
				Lv[Client] += 1;
				StatusPoint[Client] += GetConVarInt(LvUpSP);
				SkillPoint[Client] += GetConVarInt(LvUpKSP);
				Cash[Client] += GetConVarInt(LvUpCash);
				CPrintToChat(Client, MSG_LEVEL_UP_1, Lv[Client], GetConVarInt(LvUpSP), GetConVarInt(LvUpKSP), GetConVarInt(LvUpCash));
				CPrintToChat(Client, MSG_LEVEL_UP_2);
				CPrintToChatAll("\x05【升级礼包】玩家%N提升了一级!", Client);  
			}	
		}
	} else CPrintToChat(Client, "\x05【提示】你没有升级礼包!");
}


//每日签到
public Action:MenuFunc_Qiandao(Client)
{
    new Handle:menu = CreatePanel();

    decl String:line[1024];
    Format(line, sizeof(line), "═══每日签到当前已经积累签到%d天/15天=========\n积累3天可获得炎神宝盒1个 \n积累7天可获得圣翼7天 \n积累10天可获得死亡勋章7天 \n积累15天可获得7天的神器★轻盈之躯", everyday1[Client]);
    SetPanelTitle(menu, line);

    Format(line, sizeof(line), "确认签到");
    DrawPanelItem(menu, line);
    Format(line, sizeof(line), "连续签到奖励领取");
    DrawPanelItem(menu, line);
    DrawPanelItem(menu, "放弃", ITEMDRAW_DISABLED);

    SendPanelToClient(menu, Client, MenuHandler_Qiandao, MENU_TIME_FOREVER);
    return Plugin_Handled;
}
public MenuHandler_Qiandao(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: PlayerSignXHToday(Client);
			case 2: LXQDJL(Client);
		}
	}
}

new bool:SaveLoadCD[MAXPLAYERS+1];

public Action:LXQDJL(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "*****签到奖励领取****");
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "═══领取1只炎神宝盒奖励(消耗3天签到积累)═══");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "═══领取7天圣翼装备(消耗7天签到积累)═══");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "═══领取7天神器★狂暴之躯(消耗10天签到积累)═══");
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "═══领取7天神器★轻盈之躯(消耗15天签到积累)═══");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回签到菜单");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_LXQDJL, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_LXQDJL(Handle:menu, MenuAction:action, Client, param)
{
    if (action == MenuAction_Select)
    {
        switch (param)
        {
			case 1:  QDJL1(Client);
			case 2: QDJL2(Client);
			case 3: QDJL3(Client);
                           case 4: QDJL4(Client);
			case 5: MenuFunc_Qiandao(Client);
		}
	}
}
public QDJL1(Client)
{
	if(everyday1[Client] >= 3)
	{
		everyday1[Client] -= 3;
		Eqbox[Client] ++;
		CPrintToChat(Client,"\x03[系统]\04你\x04领取了\x051只炎神宝盒!");
	} else CPrintToChat(Client, "\x05【提示】你没有积累足够的签到次数");
}

public QDJL2(Client)//项链
{
	if(everyday1[Client] >= 7)
	{
		everyday1[Client] -= 7;
		SetZBItemTime(Client, 16, 7, false);
		CPrintToChat(Client,"\x03[系统]\04你\x04领取了\x057天的圣翼");
	} else CPrintToChat(Client, "\x05【提示】你没有积累足够的签到次数!");
}

public QDJL3(Client)//项链
{
	if(everyday1[Client] >= 10)
	{
		everyday1[Client] -= 10;
		SetZBItemTime(Client, 35, 7, false);
		CPrintToChat(Client,"\x03[系统]\04你\x04领取了\x057天的神器★狂暴之躯!");
	} else CPrintToChat(Client, "\x05【提示】你没有积累足够的签到次数!");
}

public QDJL4(Client)//项链
{
	if(everyday1[Client] >= 15)
	{
		everyday1[Client] -= 15;
		SetZBItemTime(Client, 34, 7, false);
		CPrintToChat(Client,"\x03[系统]\04你\x04领取了\x057天的神器★轻盈之躯");
	} else CPrintToChat(Client, "\x05【提示】你没有积累足够的签到次数!");
}
/* 手动存档 */
public PlayerManualSave(Client)
{
	if (IsValidPlayer(Client, false))
	{
		if (!IsPasswordConfirm[Client])
		{
			CPrintToChat(Client, "\x03[系统] {red}请先登录游戏后在使用该功能!");
			return;
		}

		if (!SaveLoadCD[Client])
		{
			//by MicroLeo
			if(GetConVarBool(h_ArchiveSys))
			{
				SQLiteArchiveSys_ClientSaveToFileSave(Client,false);
			}
			else
			{
				ClientSaveToFileSave(Client);
			}
			
			if(GetConVarBool(h_ArchiveSys))
			{
				SQLiteArchiveSys_ClientSaveToFileLoad(Client);
			}
			else
			{
				ClientSaveToFileLoad(Client);
			}
			//end
			
			CPrintToChat(Client, "\x03[系统] {red}你的存档已保存,下次保存时可以使用快捷键\x05[F12]{red}快速保存!");
			SaveLoadCD[Client] = true;
			CreateTimer(300.0, Timer_PlayerSaveCD, Client);
		}
		else
			CPrintToChat(Client, "\x03[系统] {red}存档功能冷却中,请稍后在尝试!");
	}
}

//手动存档_冷却
public Action:Timer_PlayerSaveCD(Handle:timer, any:Client)
{
	SaveLoadCD[Client] = false;
	KillTimer(timer);
}

/* 加入游戏 */
public JoinGameTeam(Client)
{
	if (IsValidPlayer(Client) && !IsFakeClient(Client))
	{
		if (GetClientTeam(Client) != 2)
			ChangeTeam(Client, 2);
		else
			PrintHintText(Client, "你已经在游戏中,无须再加入!");
	}
}

/* 属性点总菜单 */
public Action:MenuFunc_AddAllStatus(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line, sizeof(line), "属性点剩余: %d", StatusPoint[Client]);
	SetPanelTitle(menu, line);

	DrawPanelItem(menu, "基础属性");
	DrawPanelItem(menu, "暴击属性[只有弹药师才可用]");

	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_AddAllStatus, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddAllStatus(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if (param >= 1 && param <= 2)
		{
			switch(param)
			{
				case 1:	MenuFunc_AddStatus(Client);
				case 2:	if(JD[Client]==6)
				{
				 MenuFunc_AddCrits(Client);
				}

			}

		}

		if (param == 3)
			MenuFunc_RPG_Learn(Client);	//转职加点
	}
}

/* 暴击属性菜单 */
public Action:MenuFunc_AddCrits(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line, sizeof(line), "属性点剩余: %d", StatusPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "暴击几率 (%d/%d 指令: !cts 数量)", Crits[Client], Limit_Crits);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高暴击几率! 增加%.2f%%暴击几率", CritsEffect[Client]);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "暴击最小伤害 (%d/%d 指令: !ctn 数量)", CritMin[Client], Limit_CritMin);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高暴击最小伤害! 附加武器伤害*%.2f%*2暴击最小伤害", CritMinEffect[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "暴击最大伤害 (%d/%d 指令: !ctx 数量)", CritMax[Client], Limit_CritMax);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高暴击最大伤害! 附加武器伤害*%.2f%*2暴击最大伤害", CritMaxEffect[Client]);
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_AddCrits, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddCrits(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(StatusPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_POINTS);
		else if (param >= 1 && param <= 3)
		{
			switch(param)
			{
				case 1:	AddCrits(Client, 0);
				case 2:	AddCritMin(Client, 0);
				case 3:	AddCritMax(Client, 0);
			}

		}

		if (param == 4)
			MenuFunc_AddAllStatus(Client);
		else
			MenuFunc_AddCrits(Client);
	}
}

/* 属性点菜单 */
public Action:MenuFunc_AddStatus(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line, sizeof(line), "属性点剩余: %d", StatusPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "力量 (%d/%d 指令: !str 数量)", Str[Client], Limit_Str);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高伤害! 增加%.2f%%伤害", StrEffect[Client] * 100.0);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "敏捷 (%d/%d 指令: !agi 数量)", Agi[Client], Limit_Agi);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高移动速度! 增加%.2f%%移动速度", AgiEffect[Client] * 100.0);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "生命 (%d/%d 指令: !hea 数量)", Health[Client], Limit_Health);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高生命最大值! 增加%.2f%%生命最大值", HealthEffect[Client] * 100.0);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "耐力 (%d/%d 指令: !end 数量)", Endurance[Client], Limit_Endurance);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "减少伤害!  减少%.2f%%伤害", EnduranceEffect[Client] * 100.0);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "智力 (%d/%d 指令: !int 数量)", Intelligence[Client], Limit_Intelligence);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "提高MP上限, 恢复速度及减少扣经! 每秒MP恢复: %d, MP上限: %d", IntelligenceEffect_IMP[Client], MaxMP[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_AddStatus, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddStatus(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(StatusPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_POINTS);
		else if (param >= 1 && param <= 5)
		{
			switch(param)
			{
				case 1:	AddStrength(Client, 0);
				case 2:	AddAgile(Client, 0);
				case 3:	AddHealth(Client, 0);
				case 4:	AddEndurance(Client, 0);
				case 5:	AddIntelligence(Client, 0);
			}

		}

		if (param == 6)
			MenuFunc_AddAllStatus(Client);
		else
			MenuFunc_AddStatus(Client);
	}
}

/* 幸存者学习技能 */
public Action:MenuFunc_SurvivorSkill(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "幸存者技能 - 技能点剩余: %d", SkillPoint[Client]);
	SetPanelTitle(menu, line);

	if (VIP[Client] <= 0)
		Format(line, sizeof(line), "[通用]治疗术 (等级: %d/%d 发动指令: !hl)", HealingLv[Client], LvLimit_Healing);
	else
		Format(line, sizeof(line), "[通用]高级治疗术 (等级: %d/%d 发动指令: !hl)", HealingLv[Client], LvLimit_Healing);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "[通用]地震术 (等级: %d/%d 发动指令: !dizhen)", EarthQuakeLv[Client], LvLimit_EarthQuake);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "[通用]召唤重机枪(Lv.%d / MP:5000)", GELINLv[Client]);
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "[通用]强化苏醒术 (等级: %d/%d 被动技能)", EndranceQualityLv[Client], LvLimit_EndranceQuality);
	DrawPanelItem(menu, line);
	if(JD[Client] == 1)
	{
		Format(line, sizeof(line), "[工程师猎手]子弹制造术 (等级: %d/%d 发动指令: !am)", AmmoMakingLv[Client], LvLimit_AmmoMaking);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[工程师猎手]幻影射速 (等级: %d/%d 发动指令: !fs)", FireSpeedLv[Client], LvLimit_FireSpeed);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[工程师猎手]卫星轨道炮 (等级: %d/%d 发动指令: !sc)", SatelliteCannonLv[Client], LvLimit_SatelliteCannon);
		DrawPanelItem(menu, line);
		if (NewLifeCount[Client] >= 1)
		Format(line, sizeof(line), "[究极]超级核弹"), DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 2)
	{
		Format(line, sizeof(line), "[士兵]攻防术 (等级: %d/%d 被动技能)", EnergyEnhanceLv[Client], LvLimit_EnergyEnhance);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[士兵]疾走 (等级: %d/%d 发动指令: !sp)", SprintLv[Client], LvLimit_Sprint);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[士兵]炎神装填 (等级: %d/%d 发动指令: !ia)", InfiniteAmmoLv[Client], LvLimit_InfiniteAmmo);
		DrawPanelItem(menu, line);
		if (NewLifeCount[Client] >= 1)
		Format(line, sizeof(line), "[究极]超级狂飙模式"), DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 3)
	{
		Format(line, sizeof(line), "[圣骑士]无敌术 (等级: %d/%d 发动指令: !bs)", BioShieldLv[Client], LvLimit_BioShield);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[圣骑士]反伤术 (等级: %d/%d 发动指令: !dr)", DamageReflectLv[Client], LvLimit_DamageReflect);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[圣骑士]近战嗜血术 (等级: %d/%d 发动指令: !ms)", MeleeSpeedLv[Client], LvLimit_MeleeSpeed);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[圣骑士]基因改造 (等级: %d/%d 被动技能)", GeneLv[Client], LvLimit_Gene);
		DrawPanelItem(menu, line);
		if (NewLifeCount[Client] >= 1)
		Format(line, sizeof(line), "[究极]暗影嗜血术"), DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 4)
	{
		Format(line, sizeof(line), "[心灵医师]冰之传送术 (等级: %d/%d 发动指令: !ts)", TeleportToSelectLv[Client], LvLimit_TeleportToSelect);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[心灵医师]嗜血光球术 (等级: %d/%d 发动指令: !at)", HolyBoltLv[Client], LvLimit_HolyBolt);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[心灵医师]心灵传送术 (等级: %d/%d 发动指令: !tt)", TeleportTeamLv[Client], LvLimit_TeleportTeam);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[心灵医师]圣域之风 (等级: %d/%d 发动指令: !hb)", HealingBallLv[Client], LvLimit_HealingBall);
		DrawPanelItem(menu, line);
		if (NewLifeCount[Client] >= 1)
		Format(line, sizeof(line), "[究极]吸引术"), DrawPanelItem(menu, line);

	}
	else if(JD[Client] == 5)
	{
		Format(line, sizeof(line), "[魔法师]地狱火 (等级: %d/%d 发动指令: !fb)", FireBallLv[Client], LvLimit_FireBall);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[魔法师]寒冰爆弹 (等级: %d/%d 发动指令: !ib)", IceBallLv[Client], LvLimit_IceBall);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[魔法师]连锁闪电 (等级: %d/%d 发动指令: !cl)", ChainLightningLv[Client], LvLimit_ChainLightning);
		DrawPanelItem(menu, line);
		if (NewLifeCount[Client] >= 1)
		Format(line, sizeof(line), "[究极]终极雷矢"), DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 6)
	{
		Format(line, sizeof(line), "[弹药专家]破碎弹 (等级: %d/%d 发动指令: !psd)", BrokenAmmoLv[Client], LvLimit_BrokenAmmo);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[弹药专家]渗毒弹 (等级: %d/%d 发动指令: !sdd)", PoisonAmmoLv[Client], LvLimit_PoisonAmmo);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[弹药专家]嗜血弹 (等级: %d/%d 发动指令: !xxd)", SuckBloodAmmoLv[Client], LvLimit_SuckBloodAmmo);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[弹药专家]区域爆破 (等级: %d/%d 发动指令: !qybp)", AreaBlastingLv[Client], LvLimit_AreaBlasting);
		DrawPanelItem(menu, line);
		if (NewLifeCount[Client] >= 1)
		Format(line, sizeof(line), "[究极]终极镭射炮"), DrawPanelItem(menu, line);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 7)
	{
		Format(line, sizeof(line), "[地狱使者]勾魂之力 (等级: %d/%d 被动技能)", GouhunLv[Client], LvLimit_Gouhun);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[地狱使者]灵力上限 (等级: %d/%d 被动技能)", LinliLv[Client], LvLimit_Linli);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[地狱使者]审判领域 (等级: %d/%d 发动指令: !sply)", AreaBlastingexLv[Client], LvLimit_AreaBlastingex);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 8)
	{
		Format(line, sizeof(line), "[死神]暗影能量 (等级: %d/%d 被动技能)", AynlLv[Client], LvLimit_Aynl);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[死神]死神之力 (等级: %d/%d 被动技能)", SszlLv[Client], LvLimit_Sszl);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[死神]大地之怒 (等级: %d/%d 发动指令: !dyzh)", DyzhLv[Client], LvLimit_Dyzh);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 9)
	{
		Format(line, sizeof(line), "[黑暗行者]黑暗射速 (等级: %d/%d 被动技能)", HassLv[Client], LvLimit_Hass);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[黑暗行者]子弹工程 (等级: %d/%d 发动指令: !zd)", ZdgcLv[Client], LvLimit_Zdgc);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[黑暗行者]超强地震 (等级: %d/%d 发动指令: !cdz)", CqdzLv[Client], LvLimit_Cqdz);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 10)
	{
		Format(line, sizeof(line), "[死亡祭师]死亡改造 (等级: %d/%d 被动技能)", SWGZLv[Client], LvLimit_SWGZ);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[死亡祭师]死亡护体 (等级: %d/%d 发动指令: !ht)", SWHTLv[Client], LvLimit_SWHT);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[死亡祭师]无限能源 (等级: %d/%d 发动指令: !ny)", WXNYLv[Client], LvLimit_WXNY);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 11)
	{
		Format(line, sizeof(line), "[雷电使者]雷电子 (等级: %d/%d 发动指令: !dz)", LDZLv[Client], LvLimit_LDZ);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[雷电使者]光之速 (等级: %d/%d 发动指令: !gs)", GZSLv[Client], LvLimit_GZS);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[雷电使者]致命闪电 (等级: %d/%d 发动指令: !yl)", YLTJLv[Client], LvLimit_YLTJ);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[雷电使者]雷子弹 (等级: %d/%d 发动指令: !lzd)", LZDLv[Client], LvLimit_LZD);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 12)
	{
		Format(line, sizeof(line), "[影武者]玄冰风暴 (等级: %d/%d 发动指令: !xbfb)", XBFBLv[Client], LvLimit_XBFB);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[影武者]风暴之怒 (等级: %d/%d 发动指令: !nq)", FBZNLv[Client], LvLimit_FBZN);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[影武者]武者之光 (等级: %d/%d 发动指令: !wz)", WZZGLv[Client], LvLimit_WZZG);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 13)
	{
		Format(line, sizeof(line), "[审判者]毁灭之书 (等级: %d/%d 发动指令: !hm)", HMZSLv[Client], LvLimit_HMZS);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[审判者]审判之书 (等级: %d/%d 发动指令: !sap)", SPZSLv[Client], LvLimit_SPZS);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[审判者]极冰盛宴 (等级: %d/%d 发动指令: !jbsy)",JBSYLv[Client], LvLimit_JBSY);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 14)
	{
		Format(line, sizeof(line), "[毒龙]坚硬身躯 (等级: %d/%d 被动技能)", JYSQLv[Client], LvLimit_JYSQ);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[毒龙]嗜血之光 (等级: %d/%d 发动指令: !sx)", SXZGLv[Client], LvLimit_SXZG);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[毒龙]毒龙爆破 (等级: %d/%d 发动指令: !bbbs)", BBBSLv[Client], LvLimit_BBBS);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[毒龙]毒龙之光 (等级: %d/%d 发动指令: !ds)", DSZGLv[Client], LvLimit_DSZG);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 15)
	{
		Format(line, sizeof(line), "[幻影统帅]幻影之炎 (等级: %d/%d 发动技能: !phf)", PHFRLv[Client], LvLimit_PHFR);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[幻影统帅]幻影爆破 (等级: %d/%d 发动指令: !pha)", PHABLv[Client], LvLimit_PHAB);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[幻影统帅]幻影之血 (等级: %d/%d 发动指令: !sh)", PHZGLv[Client], LvLimit_PHZG);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[幻影统帅]幻影炮 (等级: %d/%d 发动指令: !ds)", PHSCLv[Client], LvLimit_PHSC);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 16)
	{

		Format(line, sizeof(line), "[复仇者]复仇欲望 (等级: %d/%d 发动指令: !fc)", PHABALv[Client], LvLimit_PHABA);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[复仇者]爆破光球 (等级: %d/%d 发动指令: !bp)", PHZGALv[Client], LvLimit_PHZGA);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[复仇者]闪电光球 (等级: %d/%d 发动指令: !sd)", PHSDLv[Client], LvLimit_PHSD);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[复仇者]死亡契约 (等级: %d/%d 发动指令: !qy)", PHFRALv[Client], LvLimit_PHFRA);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[复仇者]献祭 (等级: %d/%d 发动指令: !xj)", XJLv[Client], LvLimit_XJ);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 17)
	{

		Format(line, sizeof(line), "[大祭祀]祭祀之光 (等级: %d/%d 发动指令: !lllz)", LLLZLv[Client], LvLimit_LLLZ);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[大祭祀]魔法冲击 (等级: %d/%d 发动指令: !llle)", LLLELv[Client], LvLimit_LLLE);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[大祭祀]毁灭压制 (等级: %d/%d 发动指令: !llls)", LLLSLv[Client], LvLimit_LLLS);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 18)
	{

		Format(line, sizeof(line), "[狂战士]幻影剑舞 (等级: %d/%d 发动指令: !hyjw)", HYJWLv[Client], LvLimit_HYJW);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[狂战士]怒气爆发 (等级: %d/%d 发动指令: !nqbf)", NQBFLv[Client], LvLimit_NQBF);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "[狂战士]血之狂暴 (等级: %d/%d 发动指令: !xzkb)", XZKBLv[Client], LvLimit_XZKB);
		DrawPanelItem(menu, line);
	}
	else if(JD[Client] == 19)
	{
	    Format(line, sizeof(line), "[变异坦克]召变身坦克(Lv.%d / MP:5000)", GELINLv[Client]);
	    DrawPanelItem(menu, line);
	}
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_SurvivorSkill, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_SurvivorSkill(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		switch(param) {
			case 1: MenuFunc_AddHealing(Client);
			case 2: MenuFunc_AddEarthQuake(Client);
			case 3: MenuFunc_AddGELIN(Client);
			case 4: MenuFunc_AddEndranceQuality(Client);
			case 5:
			{
				if(JD[Client] == 1)	MenuFunc_AddAmmoMaking(Client);
				else if(JD[Client] == 2)	MenuFunc_AddEnergyEnhance(Client);
				else if(JD[Client] == 3)	MenuFunc_AddBioShield(Client);
				else if(JD[Client] == 4)	MenuFunc_AddTeleportToSelect(Client);
				else if(JD[Client] == 5)	MenuFunc_AddFireBall(Client);
				else if(JD[Client] == 6)	MenuFunc_AddBrokenAmmo(Client);
				else if(JD[Client] == 7)	MenuFunc_AddGouhun(Client);
				else if(JD[Client] == 8)	MenuFunc_AddAynl(Client);
				else if(JD[Client] == 9)	MenuFunc_AddHass(Client);
				else if(JD[Client] == 10)	MenuFunc_AddSWGZ(Client);
				else if(JD[Client] == 11)	MenuFunc_AddLDZ(Client);
				else if(JD[Client] == 12)	MenuFunc_AddXBFB(Client);
				else if(JD[Client] == 13)	MenuFunc_AddHMZS(Client);
				else if(JD[Client] == 14)	MenuFunc_AddJYSQ(Client);
				else if(JD[Client] == 15)	MenuFunc_AddPHFR(Client);
				else if(JD[Client] == 16)	MenuFunc_AddPHABA(Client);
				else if(JD[Client] == 17)	MenuFunc_AddLLLZ(Client);
				else if(JD[Client] == 18)	MenuFunc_AddHYJW(Client);
				else if(JD[Client] == 19)	MenuFunc_AddBSTK(Client);
			}
			case 6:
			{
				if(JD[Client] == 1)	MenuFunc_AddFireSpeed(Client);
				else if(JD[Client] == 2)	MenuFunc_AddSprint(Client);
				else if(JD[Client] == 3)	MenuFunc_AddDamageReflect(Client);
				else if(JD[Client] == 4)	MenuFunc_AddHolyBolt(Client);
				else if(JD[Client] == 5)	MenuFunc_AddIceBall(Client);
				else if(JD[Client] == 6)	MenuFunc_AddPoisonAmmo(Client);
				else if(JD[Client] == 7)	MenuFunc_AddLinli(Client);
				else if(JD[Client] == 8)	MenuFunc_AddSszl(Client);
				else if(JD[Client] == 9)	MenuFunc_AddZdgc(Client);
				else if(JD[Client] == 10)	MenuFunc_AddSWHT(Client);
				else if(JD[Client] == 11)	MenuFunc_AddGZS(Client);
				else if(JD[Client] == 12)	MenuFunc_AddFBZN(Client);
				else if(JD[Client] == 13)	MenuFunc_AddSPZS(Client);
				else if(JD[Client] == 14)	MenuFunc_AddSXZG(Client);
				else if(JD[Client] == 15)	MenuFunc_AddPHAB(Client);
				else if(JD[Client] == 16)	MenuFunc_AddPHZGA(Client);
				else if(JD[Client] == 17)	MenuFunc_AddLLLE(Client);
				else if(JD[Client] == 18)	MenuFunc_AddNQBF(Client);
			}
			case 7:
			{
				if(JD[Client] == 1)	MenuFunc_AddSatelliteCannon(Client);
				else if(JD[Client] == 2)	MenuFunc_AddInfiniteAmmo(Client);
				else if(JD[Client] == 3)	MenuFunc_AddMeleeSpeed(Client);
				else if(JD[Client] == 4)	MenuFunc_AddTeleportTeam(Client);
				else if(JD[Client] == 5)	MenuFunc_AddChainLightning(Client);
				else if(JD[Client] == 6)	MenuFunc_AddSuckBloodAmmo(Client);
				else if(JD[Client] == 7)	MenuFunc_AddAreaBlastingex(Client);
				else if(JD[Client] == 8)	MenuFunc_AddDyzh(Client);
				else if(JD[Client] == 9)	MenuFunc_AddCqdz(Client);
				else if(JD[Client] == 10)	MenuFunc_AddWXNY(Client);
				else if(JD[Client] == 11)	MenuFunc_AddYLTJ(Client);
				else if(JD[Client] == 12)	MenuFunc_AddWZZG(Client);
				else if(JD[Client] == 13)	MenuFunc_AddJBSY(Client);
				else if(JD[Client] == 14)	MenuFunc_AddBBBS(Client);
				else if(JD[Client] == 15)	MenuFunc_AddPHZG(Client);
				else if(JD[Client] == 16)	MenuFunc_AddPHSD(Client);
				else if(JD[Client] == 17)	MenuFunc_AddLLLS(Client);
				else if(JD[Client] == 18)	MenuFunc_AddXZKB(Client);
			}
			case 8:
			{
				if(JD[Client] == 2 && NewLifeCount[Client] >= 1)	MenuFunc_AddBioShieldkb(Client);
				else if(JD[Client] == 3)	MenuFunc_AddGene(Client);
				else if(JD[Client] == 4)	MenuFunc_AddHealingBall(Client);
				else if(JD[Client] == 5 && NewLifeCount[Client] >= 1)	MenuFunc_AddSatelliteCannonmiss(Client);
				else if(JD[Client] == 6)	MenuFunc_AddAreaBlasting(Client);
				else if(JD[Client] == 14)	MenuFunc_AddDSZG(Client);
				else if(JD[Client] == 11)	MenuFunc_AddLZD(Client);
				else if(JD[Client] == 15)	MenuFunc_AddPHSC(Client);
				else if(JD[Client] == 16)	MenuFunc_AddPHFRA(Client);
			}
			case 9:
			{
				if(JD[Client] == 4 && NewLifeCount[Client] >= 1)	MenuFunc_AddTeleportTeamzt(Client);
				if(JD[Client] == 6 && NewLifeCount[Client] >= 1)	MenuFunc_AddLaserGun(Client);
				else if(JD[Client] == 3 && NewLifeCount[Client] >= 1)	MenuFunc_AddBioShieldmiss(Client);
				else if(JD[Client] == 16)	MenuFunc_AddXJ(Client);
			}
		}
	}
}

//治疗术
public Action:MenuFunc_AddHealing(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	if(VIP[Client] <= 0)
		Format(line, sizeof(line), "学习治疗术 目前等级: %d/%d 发动指令: !hl - 技能点剩余: %d", HealingLv[Client], LvLimit_Healing, SkillPoint[Client]);
	else
		Format(line, sizeof(line), "学习高级治疗术 目前等级: %d/%d 发动指令: !hl - 技能点剩余: %d", HealingLv[Client], LvLimit_Healing, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	if(VIP[Client] <= 0)
		Format(line, sizeof(line), "技能说明: 每秒恢复%dHP", HealingEffect[Client]);
	else
		Format(line, sizeof(line), "技能说明: 每秒恢复8HP");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %d秒", HealingDuration[Client]);
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHealing, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHealing(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(HealingLv[Client] < LvLimit_Healing)
			{
				HealingLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_HL, HealingLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_HL_LEVEL_MAX);
			MenuFunc_AddHealing(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//淫荡光波
public Action:MenuFunc_AddEarthQuake(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习地震术 目前等级: %d/%d 发动指令: !dizhen - 技能点剩余: %d", EarthQuakeLv[Client], LvLimit_EndranceQuality, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 范围内所有普通僵尸直接秒杀,最多秒杀数量根据技能等级决定.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "最大数量: %d", EarthQuakeMaxKill[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "当前范围: %d", EarthQuakeRadius[Client]);
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddEarthQuake, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddEarthQuake(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(EarthQuakeLv[Client] < LvLimit_EarthQuake)
			{
				EarthQuakeLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_EQ, EarthQuakeLv[Client] , EarthQuakeRadius[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_EQ_LEVEL_MAX);
			MenuFunc_AddEarthQuake(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//超强地震
public Action:MenuFunc_AddCqdz(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习超强地震 目前等级: %d/%d 发动指令: !cdz - 技能点剩余: %d", CqdzLv[Client], LvLimit_Cqdz, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 范围内所有普通僵尸直接秒杀,更加强大的地震!.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "最大数量: %d", CqdzMaxKill[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "当前范围: %d", CqdzRadius[Client]);
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddCqdz, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddCqdz(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(CqdzLv[Client] < LvLimit_Cqdz)
			{
				CqdzLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_EQD, CqdzLv[Client] , CqdzRadius[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_EQD_LEVEL_MAX);
			MenuFunc_AddCqdz(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//强化苏醒术
public Action:MenuFunc_AddEndranceQuality(Client)
{
	decl String:line[128];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习强化苏醒术 目前等级: %d/%d 被动技能 - 技能点剩余: %d", EndranceQualityLv[Client], LvLimit_EndranceQuality, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 倒地后再起身的血量");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "生命比率: %.2f%%", EndranceQualityEffect[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddEndranceQuality, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddEndranceQuality(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(EndranceQualityLv[Client] < LvLimit_EndranceQuality)
			{
				EndranceQualityLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_GENGXIN, EndranceQualityLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_GENGXIN_LEVEL_MAX);
			MenuFunc_AddEndranceQuality(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}


//子弹工程
public Action:MenuFunc_AddZdgc(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习子弹工程 目前等级: %d/%d 发动指令: !am - 技能点剩余: %d", ZdgcLv[Client], LvLimit_Zdgc, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 制造更多数量子弹");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "制造数量: %d", ZdgcEffect[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddZdgc, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddZdgc(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(ZdgcLv[Client] < LvLimit_Zdgc)
			{
				ZdgcLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_AMS, ZdgcLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_AMS_LEVEL_MAX);
			MenuFunc_AddZdgc(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}


//子弹制造术
public Action:MenuFunc_AddAmmoMaking(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习子弹制造术 目前等级: %d/%d 发动指令: !am - 技能点剩余: %d", AmmoMakingLv[Client], LvLimit_AmmoMaking, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 制造一定数量子弹");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "制造数量: %d", AmmoMakingEffect[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddAmmoMaking, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddAmmoMaking(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(AmmoMakingLv[Client] < LvLimit_AmmoMaking)
			{
				AmmoMakingLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_AM, AmmoMakingLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_AM_LEVEL_MAX);
			MenuFunc_AddAmmoMaking(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//幻影射速
public Action:MenuFunc_AddFireSpeed(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习幻影射速 目前等级: %d/%d 发动指令: !fs - 技能点剩余: %d", FireSpeedLv[Client], LvLimit_FireSpeed, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 增加子弹的射击速度");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "速度比率: %.2f%%", FireSpeedEffect[Client]*100);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddFireSpeed, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddFireSpeed(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(FireSpeedLv[Client] < LvLimit_FireSpeed)
			{
				FireSpeedLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_FS, FireSpeedLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_FS_LEVEL_MAX);
			MenuFunc_AddFireSpeed(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//黑暗射速
public Action:MenuFunc_AddHass(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习黑暗射速 目前等级: %d/%d 发动指令: !fs - 技能点剩余: %d", HassLv[Client], LvLimit_Hass, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 增加子弹的射击速度");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "速度比率: %.2f%%", HassEffect[Client]*100);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHass, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHass(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(HassLv[Client] < LvLimit_Hass)
			{
				HassLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_FSS, HassLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_FSS_LEVEL_MAX);
			MenuFunc_AddHass(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//卫星轨道炮
public Action:MenuFunc_AddSatelliteCannon(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习暗夜直射 目前等级: %d/%d 发动指令: !sc - 技能点剩余: %d", SatelliteCannonLv[Client], LvLimit_SatelliteCannon, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向准心位置发射卫星炮");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", SatelliteCannonDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %d", SatelliteCannonRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", SatelliteCannonCDTime[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 力量");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSatelliteCannon, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSatelliteCannon(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(SatelliteCannonLv[Client] < LvLimit_SatelliteCannon)
			{
				SatelliteCannonLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SC, SatelliteCannonLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SC_LEVEL_MAX);
			MenuFunc_AddSatelliteCannon(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//暗夜暴雷术
public Action:MenuFunc_AddSatelliteCannonmiss(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习暗夜暴雷术 (究极技能只限学习1级,要消耗60技能点)", SatelliteCannonmissLv[Client], LvLimit_SatelliteCannonmiss, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 对范围内所有感染者造成大量伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", SatelliteCannonmissDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %.1f", SatelliteCannonmissRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", SatelliteCannonmissCDTime[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddCannonmiss, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddCannonmiss(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 60)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(SatelliteCannonmissLv[Client] < LvLimit_SatelliteCannonmiss)
			{
				SatelliteCannonmissLv[Client]++, SkillPoint[Client] -= 60;
				CPrintToChat(Client, MSG_ADD_SKILL_SCMISS, SatelliteCannonmissLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SC_LEVEL_MAXMISS);
			MenuFunc_AddSatelliteCannonmiss(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//致命闪电
public Action:MenuFunc_AddYLTJ(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习致命闪电 - 目前等级: %d/%d  - 技能点剩余: %d", YLTJLv[Client], LvLimit_YLTJ, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 对范围内所有感染者造成大量伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", YLTJDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %.1f", YLTJRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", YLTJCDTime[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddYLTJ, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddYLTJ(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 1)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(YLTJLv[Client] < LvLimit_YLTJ)
			{
				YLTJLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SCMISSD, YLTJLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SCD_LEVEL_MAXMISS);
			MenuFunc_AddYLTJ(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//毒龙之光
public Action:MenuFunc_AddDSZG(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习毒龙之光 - 目前等级: %d/%d  - 技能点剩余: %d", DSZGLv[Client], LvLimit_DSZG, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 对感染者产生强力伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", DSZGDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %.1f", DSZGRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", DSZGCDTime[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddDSZG, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddDSZG(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 1)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(DSZGLv[Client] < LvLimit_DSZG)
			{
				DSZGLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SCMISSDE, DSZGLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SCDE_LEVEL_MAXMISS);
			MenuFunc_AddDSZG(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//武者之光
public Action:MenuFunc_AddWZZG(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习武者之光 - 目前等级: %d/%d  - 技能点剩余: %d", WZZGLv[Client], LvLimit_WZZG, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 【固定伤害：装备不加伤害】对感染者产生强力伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", WZZGDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %.1f", WZZGRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", WZZGCDTime[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddWZZG, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddWZZG(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 1)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(WZZGLv[Client] < LvLimit_WZZG)
			{
				WZZGLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SCMISSDEA, WZZGLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SCDEA_LEVEL_MAXMISS);
			MenuFunc_AddWZZG(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//攻防术
public Action:MenuFunc_AddEnergyEnhance(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习攻防术 目前等级: %d/%d 被动 - 技能点剩余: %d", EnergyEnhanceLv[Client], LvLimit_EnergyEnhance, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 永久增加自身攻击力, 防卫力, 防御上限");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加伤害: %.2f%%", EnergyEnhanceEffect_Attack[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加防卫: %.2f%%", EnergyEnhanceEffect_Endurance[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "防御上限: %.2f%%", EnergyEnhanceEffect_MaxEndurance[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddEnergyEnhance, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddEnergyEnhance(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(EnergyEnhanceLv[Client] < LvLimit_EnergyEnhance)
			{
				EnergyEnhanceLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_EE, EnergyEnhanceLv[Client]);
				CreateTimer(0.1, StatusUp, Client);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_EE_LEVEL_MAX);
			MenuFunc_AddEnergyEnhance(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//勾魂之力
public Action:MenuFunc_AddGouhun(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习勾魂之力 目前等级: %d/%d 被动 - 魂魄剩余: %d", GouhunLv[Client], LvLimit_Gouhun, Hunpo[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 给予枪械特殊能力!! 所需20个感染者魂魄~~~");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddGouhun, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddGouhun(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(Hunpo[Client] < 20)	CPrintToChat(Client, MSG_LACK_Hunpo);
			else if(GouhunLv[Client] < LvLimit_Gouhun)
			{
				GouhunLv[Client]++;
				Hunpo[Client] -= 20;
				CPrintToChat(Client, MSG_ADD_SKILL_GH, GouhunLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_GH_LEVEL_MAX);
			MenuFunc_AddGouhun(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//灵力上限
public Action:MenuFunc_AddLinli(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习灵力上限 目前等级: %d/%d 被动 - 魂魄剩余: %d", LinliLv[Client], LvLimit_Linli, Hunpo[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 增加自身的生命和额外属性点! 所需50个感染者魂魄~~~");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddLinli, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddLinli(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(Hunpo[Client] < 50)	CPrintToChat(Client, MSG_LACK_Hunpo);
			else if(LinliLv[Client] < LvLimit_Linli)
			{
				LinliLv[Client]++;
				StatusPoint[Client] += 5;
				Hunpo[Client] -= 50;
				CPrintToChat(Client, MSG_ADD_SKILL_LI, LinliLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_LI_LEVEL_MAX);
			MenuFunc_AddLinli(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//审判领域
public Action:MenuFunc_AddAreaBlastingex(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习审判领域 目前等级: %d/%d 发动指令: !sply - 魂魄剩余: %d", AreaBlastingexLv[Client], LvLimit_AreaBlastingex, Hunpo[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 一定领域内对感染者造成伤害并燃烧! 所需10个感染者魂魄~~~");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "审判范围: %d", AreaBlastingexRange[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "审判伤害: %d", AreaBlastingexDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.1f", AreaBlastingexCD[Client]);

	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddAreaBlastingex, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddAreaBlastingex(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(Hunpo[Client] < 10)	CPrintToChat(Client, MSG_LACK_Hunpo);
			else if(AreaBlastingexLv[Client] < LvLimit_AreaBlastingex)
			{
				AreaBlastingexLv[Client]++;
				Hunpo[Client] -= 10;
				CPrintToChat(Client, MSG_ADD_SKILL_ABX, AreaBlastingexLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_ABX_LEVEL_MAX);
			MenuFunc_AddAreaBlastingex(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
//暗影能量
public Action:MenuFunc_AddAynl(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习暗影能量 目前等级: %d/%d 被动 ", AynlLv[Client], LvLimit_Aynl);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 给予暗影能力!! ");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddAynl, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddAynl(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(AynlLv[Client] < LvLimit_Aynl)
			{
				AynlLv[Client]++;
				SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_AY, AynlLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_AY_LEVEL_MAX);
			MenuFunc_AddAynl(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//死神之力
public Action:MenuFunc_AddSszl(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习死神之力 目前等级: %d/%d 被动 ", SszlLv[Client], LvLimit_Sszl);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 增加自身的生命属性点10! ");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSszl, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSszl(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(SszlLv[Client] < LvLimit_Sszl)
			{
				Health[Client] += 10; SkillPoint[Client] -= 1; SszlLv[Client]++;
				CPrintToChat(Client, MSG_ADD_SKILL_Ss, SszlLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_Ss_LEVEL_MAX);
			MenuFunc_AddSszl(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//大地之怒
public Action:MenuFunc_AddDyzh(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习大地之怒 目前等级: %d/%d 发动指令: !Dyzh- 技能点剩余: %d", DyzhLv[Client], LvLimit_Dyzh	, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 在更打范围内所有普通僵尸直接秒杀.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "最大数量: %d", DyzhMaxKill[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "当前范围: %d", DyzhRadius[Client]);
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddDyzh, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddDyzh(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(DyzhLv[Client] < LvLimit_Dyzh)
			{
				DyzhLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_EQS, DyzhLv[Client] , DyzhRadius[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_EQS_LEVEL_MAX);
			MenuFunc_AddDyzh(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}


//光之速
public Action:MenuFunc_AddGZS(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习光之速 目前等级: %d/%d 发动指令: !gs - 技能点剩余: %d", GZSLv[Client], LvLimit_GZS, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "提升移动速度. 持续:%.2f秒", GZSDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "技能说明: 一定时间内提升移动速度");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加比率: %.2f%%", GZSEffect[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", GZSDuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddGZS, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddGZS(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(GZSLv[Client] < LvLimit_GZS)
			{
				GZSLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SPD, GZSLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SPD_LEVEL_MAX);
			MenuFunc_AddGZS(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//疾风步
public Action:MenuFunc_AddSprint(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习暴走 目前等级: %d/%d 发动指令: !sap - 技能点剩余: %d", SprintLv[Client], LvLimit_Sprint, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "提升移动速度. 持续:%.2f秒", SprintDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "技能说明: 一定时间内提升移动速度");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加比率: %.2f%%", SprintEffect[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", SprintDuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSprint, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSprint(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(SprintLv[Client] < LvLimit_Sprint)
			{
				SprintLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SP, SprintLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SP_LEVEL_MAX);
			MenuFunc_AddSprint(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//死亡改造
public Action:MenuFunc_AddSWGZ(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习死亡改造 目前等级: %d/%d 被动- 技能点剩余: %d", SWGZLv[Client], LvLimit_SWGZ, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 增加自身的生命和额外属性点! ");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSWGZ, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSWGZ(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(SWGZLv[Client] < LvLimit_SWGZ)
			{
				SWGZLv[Client]++;  SkillPoint[Client] -= 1;
				StatusPoint[Client] += 10;
				CPrintToChat(Client, MSG_ADD_SKILL_LId, SWGZLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_LId_LEVEL_MAX);
			MenuFunc_AddSWGZ(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//坚硬身躯
public Action:MenuFunc_AddJYSQ(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习坚硬身躯 目前等级: %d/%d 被动- 技能点剩余: %d", JYSQLv[Client], LvLimit_JYSQ, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 增加自身的生命和额外属性点! ");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddJYSQ, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddJYSQ(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(JYSQLv[Client] < LvLimit_JYSQ)
			{
				JYSQLv[Client]++;  SkillPoint[Client] -= 1;
				StatusPoint[Client] += 10;
				CPrintToChat(Client, MSG_ADD_SKILL_LIQ, JYSQLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_LIQ_LEVEL_MAX);
			MenuFunc_AddJYSQ(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//无限能源
public Action:MenuFunc_AddWXNY(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习无限能源 目前等级: %d/%d 发动指令: !wx - 技能点剩余: %d", WXNYLv[Client], LvLimit_WXNY, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 一定时间内无限子弹");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", WXNYDuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddWXNY, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddWXNY(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(WXNYLv[Client] < LvLimit_WXNY)
			{
				WXNYLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_IAd, WXNYLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_IAd_LEVEL_MAX);
			MenuFunc_AddWXNY(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//无敌术
public Action:MenuFunc_AddSWHT(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习死亡护体 目前等级: %d/%d 发动指令: !bs - 技能点剩余: %d", SWHTLv[Client], LvLimit_SWHT, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 损耗自身生命去变成无敌, 使用后会清除自身治疗术效果");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "损耗比率: %.2f%%", SWHTSideEffect[Client] * 100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒.", SWHTDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", SWHTCDTime[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSWHT, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSWHT(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(SWHTLv[Client] < LvLimit_SWHT)
			{
				SWHTLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_BSd, SWHTLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_BSd_LEVEL_MAX);
			MenuFunc_AddSWHT(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//炎神装填
public Action:MenuFunc_AddInfiniteAmmo(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习无限子弹术 目前等级: %d/%d 发动指令: !ia - 技能点剩余: %d", InfiniteAmmoLv[Client], LvLimit_InfiniteAmmo, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 一定时间内无限子弹");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", InfiniteAmmoDuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddInfiniteAmmo, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddInfiniteAmmo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(InfiniteAmmoLv[Client] < LvLimit_InfiniteAmmo)
			{
				InfiniteAmmoLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_IA, InfiniteAmmoLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_IA_LEVEL_MAX);
			MenuFunc_AddInfiniteAmmo(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//超级狂飙模式
public Action:MenuFunc_AddBioShieldkb(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习超级狂飙模式 (究极技能只限学习1级,要消耗50技能点)", BioShieldkbLv[Client], LvLimit_BioShieldkb, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 进入狂彪状态");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "持续时间: %.2f秒.", BioShieldkbDuration[Client]);
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "冷却时间: %.2f秒", BioShieldkbCDTime[Client]);
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddBioShieldkb, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddBioShieldkb(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 50)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(BioShieldkbLv[Client] < LvLimit_BioShieldkb)
			{
				BioShieldkbLv[Client]++, SkillPoint[Client] -= 50;
				CPrintToChat(Client, MSG_ADD_SKILL_BSKB, BioShieldkbLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_BSKB_LEVEL_MAX);
			MenuFunc_AddBioShieldkb(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//无敌术
public Action:MenuFunc_AddBioShield(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习无敌术 目前等级: %d/%d 发动指令: !bs - 技能点剩余: %d", BioShieldLv[Client], LvLimit_BioShield, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 损耗自身生命去变成无敌, 使用后会清除自身技能效果, 且不能使用其他技能");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "损耗比率: %.2f%%", BioShieldSideEffect[Client] * 100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒.", BioShieldDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", BioShieldCDTime[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddBioShield, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddBioShield(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(BioShieldLv[Client] < LvLimit_BioShield)
			{
				BioShieldLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_BS, BioShieldLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_BS_LEVEL_MAX);
			MenuFunc_AddBioShield(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//基因改造
public Action:MenuFunc_AddGene(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习基因改造 目前等级: %d/%d 被动 - 技能点剩余: %d", GeneLv[Client], LvLimit_Gene, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 永久增加自身生命值和格挡能力");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加生命: %d", GeneHealthEffect[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "格挡效果: %.2f%%", GeneEndEffect[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddGene, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddGene(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(GeneLv[Client] < LvLimit_Gene)
			{
				GeneLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_GE, GeneLv[Client]);
				CreateTimer(0.1, StatusUp, Client);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_GE_LEVEL_MAX);
			MenuFunc_AddGene(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}



//暗影嗜血术
public Action:MenuFunc_AddBioShieldmiss(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习暗影嗜血术 (究极技能只限学习1级,要消耗60技能点)", BioShieldmissLv[Client], LvLimit_BioShieldmiss, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 所有幸存者恢复效果值的HP,所有感染者扣除效果值的HP");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆发效果:%d", ChainmissLightningDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", BioShieldmissCDTime[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddBioShieldmiss, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddBioShieldmiss(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 60)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(BioShieldmissLv[Client] < LvLimit_BioShieldmiss)
			{
				BioShieldmissLv[Client]++, SkillPoint[Client] -= 60;
				CPrintToChat(Client, MSG_ADD_SKILL_BSMISS, BioShieldmissLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_BSMISS_LEVEL_MAX);
			MenuFunc_AddBioShieldmiss(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//反伤术
public Action:MenuFunc_AddDamageReflect(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习反伤术 目前等级: %d/%d 发动指令: !dr - 技能点剩余: %d", DamageReflectLv[Client], LvLimit_DamageReflect, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 损耗自身生命在一定时间内去反射一定比率伤害");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "损耗比率: %.2f%%", DamageReflectSideEffect[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒.", DamageReflectDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "反射比率: %.2f%%", DamageReflectEffect[Client]*100);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 耐力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddDamageReflect, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddDamageReflect(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(DamageReflectLv[Client] < LvLimit_DamageReflect)
			{
				DamageReflectLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_DR, DamageReflectLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_DR_LEVEL_MAX);
			MenuFunc_AddDamageReflect(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//近战嗜血术
public Action:MenuFunc_AddMeleeSpeed(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习近战嗜血术 目前等级: %d/%d 发动指令: !ms - 技能点剩余: %d", MeleeSpeedLv[Client], LvLimit_MeleeSpeed, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 牺牲所有防御力去提升近战攻速3倍");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", MeleeSpeedDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "提速比率: %.2f%%", 1.0 + MeleeSpeedEffect[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddMeleeSpeed, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddMeleeSpeed(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(MeleeSpeedLv[Client] < LvLimit_MeleeSpeed)
			{
				MeleeSpeedLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_MS, MeleeSpeedLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_MS_LEVEL_MAX);
			MenuFunc_AddMeleeSpeed(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//冰之传送术
public Action:MenuFunc_AddTeleportToSelect(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习冰之传送术 目前等级: %d/%d 发动指令: !ts - 技能点剩余: %d", TeleportToSelectLv[Client], LvLimit_TeleportToSelect, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 传送到指定队友身边");
	DrawPanelText(menu, line);
	//Format(line, sizeof(line), "冷却时间: %d秒", 210 - (TeleportToSelectLv[Client]+HolyBoltLv[Client])*5);
	Format(line, sizeof(line), "冷却时间: %d秒", 205 - TeleportToSelectLv[Client]*5);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddTeleportToSelect, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddTeleportToSelect(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(TeleportToSelectLv[Client] < LvLimit_TeleportToSelect)
			{
				TeleportToSelectLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_TS, TeleportToSelectLv[Client]);
				if(TeleportToSelectLv[Client]==0) IsTeleportToSelectEnable[Client] = false;
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_TS_LEVEL_MAX);
			MenuFunc_AddTeleportToSelect(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//嗜血光球术_学习
public Action:MenuFunc_AddHolyBolt(Client)
{

	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习嗜血光球术 目前等级: %d/%d 发动指令: !at - 技能点剩余: %d", HolyBoltLv[Client], LvLimit_HolyBolt, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 发射一个光球对敌人造成%d%伤害,对友军施加%d%治疗效果.(5.0秒冷却)", LightBallDamage[Client], LightBallHealth[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHolyBolt, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;

}
public MenuHandler_AddHolyBolt(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(HolyBoltLv[Client] < LvLimit_HolyBolt)
			{
				HolyBoltLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_AT, HolyBoltLv[Client]);
				if(HolyBoltLv[Client]==0) IsHolyBoltEnable[Client] = false;
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_AT_LEVEL_MAX);
			MenuFunc_AddHolyBolt(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//心灵传送术
public Action:MenuFunc_AddTeleportTeam(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习心灵传输 目前等级: %d/%d 发动指令: !tt - 技能点剩余: %d", TeleportTeamLv[Client], LvLimit_TeleportTeam, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 传送指定队友到自己身边");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %d秒", 210 - TeleportTeamLv[Client]*5);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddTeleportTeam, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddTeleportTeam(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			//修改心灵传送术负数的bug
			else{
				if(TeleportTeamLv[Client] < LvLimit_TeleportTeam)
				{
					TeleportTeamLv[Client]++, SkillPoint[Client] -= 1;
					CPrintToChat(Client, MSG_ADD_SKILL_TT, TeleportTeamLv[Client]);
					if(TeleportTeamLv[Client]==0) IsTeleportTeamEnable[Client] = false;
				}
				else CPrintToChat(Client, MSG_ADD_SKILL_TT_LEVEL_MAX);
			}
			MenuFunc_AddTeleportTeam(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//吸引术
public Action:MenuFunc_AddTeleportTeamzt(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习吸引术 (究极技能只限学习1级,要消耗30技能点)", TeleportTeamztLv[Client], LvLimit_TeleportTeamzt, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 传送所有队友到自己身边.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %d秒", 160 - TeleportTeamztLv[Client]*5);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddTeleportTeamzt, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddTeleportTeamzt(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 30)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(TeleportTeamLv[Client] == LvLimit_TeleportTeam)
			{
				if(TeleportTeamztLv[Client] < LvLimit_TeleportTeamzt)
				{
					TeleportTeamztLv[Client]++, SkillPoint[Client] -= 30;
					CPrintToChat(Client, MSG_ADD_SKILL_ZT, TeleportTeamztLv[Client]);
					if(TeleportTeamztLv[Client]==0)
						IsTeleportTeamztEnable[Client] = false;
				}
				else CPrintToChat(Client, MSG_ADD_SKILL_ZT_LEVEL_MAX);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_TT_NEED);
			MenuFunc_AddTeleportTeamzt(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//治疗光球术
public Action:MenuFunc_AddHealingBall(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习圣域之风 目前等级: %d/%d 发动指令: !hb - 技能点剩余: %d", HealingBallLv[Client], LvLimit_HealingBall, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	new healing = RoundToNearest(0.0 + HealingBallEffect[Client]);
	if (healing < 5 || healing > 10)
		healing = 5;
	Format(line, sizeof(line), "技能说明: 在准心制造治疗血量的圣域之风治疗附近队友");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "每秒回复: %dHP", healing);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", HealingBallDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "治疗范围: %d", HealingBallRadius[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHealingBall, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHealingBall(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(NewLifeCount[Client] >= 0)
			{
				if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
				else if(HealingBallLv[Client] < LvLimit_HealingBall)
				{
					HealingBallLv[Client]++, SkillPoint[Client] -= 1;
					CPrintToChat(Client, MSG_ADD_SKILL_HB, HealingBallLv[Client]);
				}
				else CPrintToChat(Client, MSG_ADD_SKILL_HB_LEVEL_MAX);
			} else CPrintToChat(Client, MSG_ADD_SKILL_NeedNewLife);
			MenuFunc_AddHealingBall(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//风暴之怒
public Action:MenuFunc_AddFBZN(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习风暴之怒 目前等级: %d/%d 发动指令: !nq - 技能点剩余: %d", FBZNLv[Client], LvLimit_FBZN, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向准心放出火焰风暴, 燃烧范围内敌人 50秒冷却");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧持续: %.f秒", FBZNDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧伤害: %d", FBZNDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧范围: %d", FBZNRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddFBZN, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddFBZN(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(FBZNLv[Client] < LvLimit_FBZN)
			{
				FBZNLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_FBD, FBZNLv[Client], FBZNDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_FBD_LEVEL_MAX);
			MenuFunc_AddFBZN(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//玄冰风暴
public Action:MenuFunc_AddXBFB(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习玄冰风暴 目前等级: %d/%d 发动指令: !xbfb - 技能点剩余: %d", XBFBLv[Client], LvLimit_XBFB, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向准心放出玄冰风暴, 冻结范围内敌人 40秒冷却");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻持续: %.2f秒", XBFBDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻伤害: %d", XBFBDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻范围: %d", XBFBRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddXBFB, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddXBFB(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(XBFBLv[Client] < LvLimit_XBFB)
			{
				XBFBLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_IBD, XBFBLv[Client], XBFBDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_IBD_LEVEL_MAX);
			MenuFunc_AddXBFB(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}


//嗜血之光_学习
public Action:MenuFunc_AddSXZG(Client)
{

	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习嗜血之光 目前等级: %d/%d 发动指令: !sx - 技能点剩余: %d", SXZGLv[Client], LvLimit_SXZG, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 造成敌人%d%伤害,对友军施加%d%治疗效果.(5.0秒冷却)", SXZGDamage[Client], SXZGHealth[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSXZG, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;

}
public MenuHandler_AddSXZG(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(SXZGLv[Client] < LvLimit_SXZG)
			{
				SXZGLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_ATD, SXZGLv[Client]);
				if(SXZGLv[Client]==0) IsSXZGEnable[Client] = false;
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_ATD_LEVEL_MAX);
			MenuFunc_AddSXZG(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}


//地狱火
public Action:MenuFunc_AddFireBall(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习地狱火 目前等级: %d/%d 发动指令: !fb - 技能点剩余: %d", FireBallLv[Client], LvLimit_FireBall, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向准心放出火球, 燃烧范围内敌人 5秒冷却");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧持续: %.f秒", FireBallDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧伤害: %d", FireBallDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧范围: %d", FireBallRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddFireBall, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddFireBall(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(FireBallLv[Client] < LvLimit_FireBall)
			{
				FireBallLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_FB, FireBallLv[Client], FireBallDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_FB_LEVEL_MAX);
			MenuFunc_AddFireBall(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//玄冰石
public Action:MenuFunc_AddIceBall(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习玄冰石 目前等级: %d/%d 发动指令: !ib - 技能点剩余: %d", IceBallLv[Client], LvLimit_IceBall, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向准心放出冰球, 冻结范围内敌人");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻持续: %.2f秒", IceBallDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻伤害: %d", IceBallDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻范围: %d", IceBallRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddIceBall, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddIceBall(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(IceBallLv[Client] < LvLimit_IceBall)
			{
				IceBallLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_IB, IceBallLv[Client], IceBallDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_IB_LEVEL_MAX);
			MenuFunc_AddIceBall(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//闪电连锁
public Action:MenuFunc_AddChainLightning(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习闪电连锁 目前等级: %d/%d 发动指令: !cl - 技能点剩余: %d", ChainLightningLv[Client], LvLimit_ChainLightning, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 在周围放出黑暗之点不断攻击附近敌人");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "闪电伤害: %d", ChainLightningDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "发动范围: %d", ChainLightningLaunchRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "连锁范围: %d", ChainLightningRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddChainLightning, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddChainLightning(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(ChainLightningLv[Client] < LvLimit_ChainLightning)
			{
				ChainLightningLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_CL, ChainLightningLv[Client], ChainLightningDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_CL_LEVEL_MAX);
			MenuFunc_AddChainLightning(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//雷电子
public Action:MenuFunc_AddLDZ(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习雷电子 目前等级: %d/%d 发动指令: !dz - 技能点剩余: %d", LDZLv[Client], LvLimit_LDZ, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 在周围放出雷电子不断攻击附近敌人");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "闪电伤害: %d", LDZDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "发动范围: %d", LDZLaunchRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "连锁范围: %d", LDZRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddLDZ, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddLDZ(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(LDZLv[Client] < LvLimit_LDZ)
			{
				LDZLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_CLD, LDZLv[Client], LDZDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_CLD_LEVEL_MAX);
			MenuFunc_AddLDZ(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//毁灭之书
public Action:MenuFunc_AddHMZS(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习毁灭之书 目前等级: %d/%d 发动指令: !hm - 技能点剩余: %d", HMZSLv[Client], LvLimit_HMZS, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 审判者的书籍, 燃烧范围内敌人 10秒冷却");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧持续: %.f秒", HMZSDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧伤害: %d", HMZSDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧范围: %d", HMZSRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHMZS, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHMZS(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(HMZSLv[Client] < LvLimit_HMZS)
			{
				HMZSLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_HMD, HMZSLv[Client], HMZSDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_HMD_LEVEL_MAX);
			MenuFunc_AddHMZS(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//审判之书
public Action:MenuFunc_AddSPZS(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习审判之书 目前等级: %d/%d 发动指令: !sp - 技能点剩余: %d", SPZSLv[Client], LvLimit_SPZS, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 【固定伤害：装备不加伤害】审判者的大招放出雷电审判敌人!");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "审判伤害: %d", SPZSDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "发动范围: %d", SPZSLaunchRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "审判范围: %d", SPZSRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSPZS, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSPZS(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(SPZSLv[Client] < LvLimit_SPZS)
			{
				SPZSLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SPS, SPZSLv[Client], SPZSDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SPS_LEVEL_MAX);
			MenuFunc_AddSPZS(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//幻影之炎
public Action:MenuFunc_AddPHFR(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习幻影之炎 目前等级: %d/%d 发动指令: !sp - 技能点剩余: %d", PHFRLv[Client], LvLimit_PHFR, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 幻影统帅的技能放出幻影之炎!");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "审判伤害: %d", PHFRDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "发动范围: %d", PHFRRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "审判范围: %d", PHFRRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddPHFR, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddPHFR(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(PHFRLv[Client] < LvLimit_PHFR)
			{
				PHFRLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_PHF, PHFRLv[Client], PHFRDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_PHF_LEVEL_MAX);
			MenuFunc_AddPHFR(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

public Action:Timer_PHFRCD(Handle:timer, any:Client)
{
	PHFRCD[Client] = false;
	KillTimer(timer);
}

//幻影爆破
public Action:MenuFunc_AddPHAB(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习幻影爆破 目前等级: %d/%d 发动指令: !qybp - 技能点剩余: %d", PHABLv[Client], LvLimit_PHAB, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 对自身的一定范围内的所有感染者产生爆破伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆破范围: %d", PHABRange[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆破伤害: %d", PHABDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.1f", PHABCD[Client]);

	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddPHAB, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddPHAB(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(PHABLv[Client] < LvLimit_PHAB)
			{
				PHABLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "{olive}[技能] {green}区域爆破{lightgreen}等级变为{green}Lv.%d{lightgreen}", PHABLv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}区域爆破\x03等级已经上限!");

			MenuFunc_AddPHAB(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}

//幻影爆破_快捷指令
public Action:UsePHAB(Client, args)
{
	if(GetClientTeam(Client) == 2)
		PHAB_Action(Client);
	else
		CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}


//幻影爆破_使用
public PHAB_Action(Client)
{
	if(JD[Client] != 15)
	{
		CPrintToChat(Client, MSG_NEED_JOB6);
		return;
	}

	if(PHABLv[Client] <= 0)
	{
		CPrintToChat(Client, "你没有学习该技能!");
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(PHAB[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return;
	}

	if(MP_PHAB > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_PHAB, MP[Client]);
		return;
	}

	MP[Client] -= MP_PHAB;
	PHAB[Client] = true;
	PHABAttack(Client);
	CPrintToChatAll("{olive}[技能] {green}%N {blue}启动了{green}Lv.%d{blue}的{olive}幻影爆破{blue}!", Client, PHABLv[Client]);
	CreateTimer(PHABCD[Client], PHAB_Stop, Client);
}

//幻影爆破_冷却
public Action:PHAB_Stop(Handle:timer, any:Client)
{
	if (PHAB[Client])
		PHAB[Client] = false;

	if (IsValidPlayer(Client, false))
		CPrintToChat(Client, "{olive}[技能] {green}幻影爆破{blue}冷却结束了!");

	KillTimer(timer);
}

//幻影爆破_攻击
public PHABAttack(Client)
{
	if (!IsValidEntity(Client))
		return;

	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new Float:skypos[3];
	new MaxEnt = GetMaxEntities();

	GetEntPropVector(Client, Prop_Send, "m_vecOrigin", pos);
	SuperTank_LittleFlower(Client, pos, 1);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || !IsValidEntity(i) || i == Client || GetClientTeam(i) == GetClientTeam(Client))
			continue;

		GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
		distance = GetVectorDistance(pos, entpos);
		if (distance <= PHABRange[Client])
		{
			DealDamage(Client, i, PHABDamage[Client], 0);
			skypos[0] = entpos[0];
			skypos[1] = entpos[1];
			skypos[2] = entpos[2] + 2000.0;
			TE_SetupBeamPoints(skypos, entpos, g_BeamSprite, 0, 0, 0, 5.0, 5.0, 5.0, 10, 1.0, WhiteColor, 0);
			TE_SendToAll();
		}
	}

	for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
	{
		if(IsValidEntity(iEnt) && IsCommonInfected(iEnt))
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= PHABRange[Client])
				DealDamage(Client, iEnt, PHABDamage[Client], 0);
		}

	}
}

//幻影之血
public Action:MenuFunc_AddPHZG(Client)
{

	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习幻影之血 目前等级: %d/%d 发动指令: !sx - 技能点剩余: %d", PHZGLv[Client], LvLimit_PHZG, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 造成敌人%d%伤害,对友军施加%d%治疗效果.(5.0秒冷却)", PHZGDamage[Client], PHZGHealth[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddPHZG, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;

}
public MenuHandler_AddPHZG(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(PHZGLv[Client] < LvLimit_PHZG)
			{
				PHZGLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_ATD, PHZGLv[Client]);
				if(PHZGLv[Client]==0) IsPHZGEnable[Client] = false;
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_ATD_LEVEL_MAX);
			MenuFunc_AddPHZG(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//幻影炮
public Action:MenuFunc_AddPHSC(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习幻影炮 目前等级: %d/%d 发动指令: !sc - 技能点剩余: %d", PHSCLv[Client], LvLimit_PHSC, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 【固定伤害：装备不加伤害】向准心位置发射幻影炮");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", PHSCDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %d", PHSCRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", PHSCCDTime[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 力量");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddPHSC, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddPHSC(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(PHSCLv[Client] < LvLimit_PHSC)
			{
				PHSCLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SC, PHSCLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SC_LEVEL_MAX);
			MenuFunc_AddPHSC(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//普通职业选单
public Action:MenuFunc_Job(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_Job);
	SetMenuTitle(menu, "普通职业选单");
	AddMenuItem(menu, "option1", "转职工程师");
	AddMenuItem(menu, "option2", "转职士兵");
	AddMenuItem(menu, "option3", "转职圣骑士");
	AddMenuItem(menu, "option4", "转职心灵医生");
	AddMenuItem(menu, "option5", "转职黑暗行者")
	AddMenuItem(menu, "option6", "转职死亡祭师")
	AddMenuItem(menu, "option7", "转职魔法师");
	AddMenuItem(menu, "option8", "转职雷电使者(1转)");
	AddMenuItem(menu, "option9", "转职毒龙(需6转和VIP4可以转职)");
	AddMenuItem(menu, "option10", "转职弹药专家(3转)");
	AddMenuItem(menu, "option11", "转职死神(2转)");
	AddMenuItem(menu, "option12", "转职地狱使者(3转)")
	AddMenuItem(menu, "option13", "转职审判者(需8转和VIP4以上");
	AddMenuItem(menu, "option14", "转职影武者(5转)");
	AddMenuItem(menu, "option15", "转职幻影统帅(需8转和VIP4可以转职)");
	AddMenuItem(menu, "option16", "转职复仇者(需7转和VIP4以上)");
	AddMenuItem(menu, "option17", "转职大祭祀(需3转)");
	AddMenuItem(menu, "option18", "转职狂战士(需8转)");
	AddMenuItem(menu, "option19", "转职变异坦克(需16转)");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_Job(Handle:menu, MenuAction:action, Client, itemNum)
{
	if(action == MenuAction_Select) {
		switch(itemNum)
		{
			case 0: ChooseJob(Client, 1);//工程师猎手
			case 1: ChooseJob(Client, 2);//士兵
			case 2: ChooseJob(Client, 3);//圣骑士
			case 3: ChooseJob(Client, 4);//心灵医师
			case 4: ChooseJob(Client, 9);//黑暗行者
			case 5: ChooseJob(Client, 10);//死亡祭师
			case 6: ChooseJob(Client, 5);//魔法师
			case 7: ChooseJob(Client, 11);//雷电使者
			case 8: ChooseJob(Client, 14);//毒龙
			case 9: ChooseJob(Client, 6);//弹药专家
			case 10: ChooseJob(Client, 8);//死神
			case 11: ChooseJob(Client, 7);//地狱使者
			case 12: ChooseJob(Client, 13);//审判者
			case 13: ChooseJob(Client, 12);//影武者
			case 14: ChooseJob(Client, 15);//幻影统帅
			case 15: ChooseJob(Client, 16);//复仇者
			case 16: ChooseJob(Client, 17);//大祭祀
			case 17: ChooseJob(Client, 18);//狂战士
			case 18: ChooseJob(Client, 19);//变异坦克
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}
public Action:MenuFunc_ResetStatus(Client)
{
	new Handle:menu = CreatePanel();
	SetPanelTitle(menu,"洗点说明:\n按确认之后将会清零当前分配的属性, 所学技能技能及经验\n未转职玩家洗点降1级, 转职过的玩家降5级并变回未转职状态!\n你的真的需要洗点吗?\n════════════");

	DrawPanelItem(menu, "是");
	DrawPanelItem(menu, "否");

	SendPanelToClient(menu, Client, MenuHandler_ResetStatus, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_ResetStatus(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		switch(param) {
			case 1:	ClinetResetStatus(Client, General), BindKeyFunction(Client);
			case 2: return;
		}
	}
}
ClinetResetStatus(Client, Mode)
{
	//转生
	if(Mode == NewLife)
	{
		EXP[Client] = 0;
		Lv[Client] = 0;
		JD[Client] = 0;
		NewLifeCount[Client] += 1;
		StatusPoint[Client] = NewLifeGiveSKP[Client];
		SkillPoint[Client] = NewLifeGiveSP[Client];
		//小野武器
		if (NewLifeCount[Client] == 1 || NewLifeCount[Client] == 2 || NewLifeCount[Client] == 3 || NewLifeCount[Client] == 4 || NewLifeCount[Client] == 5 || NewLifeCount[Client] == 6 || NewLifeCount[Client] == 7 || NewLifeCount[Client] == 8 || NewLifeCount[Client] == 9 || NewLifeCount[Client] == 10 || NewLifeCount[Client] == 11 || NewLifeCount[Client] == 12 || NewLifeCount[Client] == 13 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
		{
			SetZBItemTime(Client, 110, 2, false);
			CPrintToChatAll("\x05[公告]玩家%N成功转世获得[小野武器]2日!", Client);
		}
		//礼包等级清零
		LibaoLv[Client]=0;

		//ServerCommand("sm_ITEM86 \"%N\" \"1\" \"42\" \"%d\"", Client ,day);CPrintToChatAll("\x05【公告】玩家%N成功转世获得【小野武器】2日!", Client);
	}


	//已转职洗点
	if(Mode != Admin && JD[Client])
	{
		if (Lv[Client] <= 10)
		{
			CPrintToChat(Client, "{red}你的等级小于10,无法进行洗点,请等你等级达到10级后在进行洗点!");
			return;
		}
		JD[Client] = 0;
		if(Mode==General)	Lv[Client] -= 5;

	}
	//无转职洗点
	else if(Mode == General)
	{
		if (Lv[Client] >= 10)
			Lv[Client] -= 1;
		else
		{
			CPrintToChat(Client, "{red}你的等级小于10,无法进行洗点,请等你等级达到10级后在进行洗点!");
			return;
		}
	}

	if(Mode == Admin)
	{
		JD[Client] = 0;

	}

	if(Mode!=NewLife)
	{
		StatusPoint[Client]	=	Lv[Client] * GetConVarInt(LvUpSP);
		SkillPoint[Client]	=	Lv[Client] * GetConVarInt(LvUpKSP);
		EXP[Client]	= 0;
		if (NewLifeCount[Client] > 0)
		{
			StatusPoint[Client] += NewLifeCount[Client] * 500 + GetConVarInt(LvUpSP) - 5;
			SkillPoint[Client] += NewLifeCount[Client] * 20;
		}
	}

	Str[Client]						= 0;
	Agi[Client]						= 0;
	Health[Client]					= 0;
	Endurance[Client]					= 0;
	Intelligence[Client]				= 0;
	Crits[Client]						= 0;
	CritMin[Client]					= 0;
	CritMax[Client]					= 0;
	HealingLv[Client]					= 0;
	EarthQuakeLv[Client]				= 0;
	EndranceQualityLv[Client]		= 0;
	AmmoMakingLv[Client]				= 0;
	SatelliteCannonLv[Client]		= 0;
	SatelliteCannonmissLv[Client]	= 0;
	EnergyEnhanceLv[Client]			= 0;
	SprintLv[Client]					= 0;
	BioShieldLv[Client]				= 0;
	BioShieldmissLv[Client]			= 0;
	BioShieldkbLv[Client]			= 0;
	DamageReflectLv[Client]			= 0;
	MeleeSpeedLv[Client]				= 0;
	InfiniteAmmoLv[Client]			= 0;
	FireSpeedLv[Client]				= 0;
	TeleportToSelectLv[Client]		= 0;
	HolyBoltLv[Client]		= 0;
	TeleportTeamLv[Client]			= 0;
	HealingBallLv[Client]			= 0;
	TeleportTeamztLv[Client]			= 0;
	FireBallLv[Client]				= 0;
	IceBallLv[Client]					= 0;
	ChainLightningLv[Client]			= 0;
	BrokenAmmoLv[Client]				= 0;	//暗影尘埃等级
	PoisonAmmoLv[Client]				= 0;	//渗毒弹等级
	SuckBloodAmmoLv[Client]			= 0;	//吸血弹等级
	AreaBlastingLv[Client]			= 0;	//区域爆破等级
	LaserGunLv[Client]				= 0;	//暗影激光波等级
	GeneLv[Client]					= 0;	//基因改造
	Hunpo[Client]			            = 0;	//魂魄
	GouhunLv[Client]			        = 0;	//勾魂之力等级
	LinliLv[Client]				    = 0;	//灵力上限等级
	AreaBlastingexLv[Client]					= 0;	//审判领域等级
	AynlLv[Client]			        = 0;	//暗影能量等级
	SszlLv[Client]				    = 0;	//死神之力等级
	DyzhLv[Client]					= 0;	//地狱之火等级
	CqdzLv[Client]			        = 0;	//超强地震等级
	ZdgcLv[Client]				    = 0;	//子弹工程等级
	HassLv[Client]					= 0;	//黑暗射速等级
	SWHTLv[Client]			        = 0;	//死亡护体等级
	WXNYLv[Client]				    = 0;	//无限能源等级
	SWGZLv[Client]					= 0;	//死亡改造等级
	GZSLv[Client]			        = 0;	//光之速等级
	LDZLv[Client]				    = 0;	//雷电子等级
	YLTJLv[Client]					= 0;	//致命闪电等级
	XBFBLv[Client]				    = 0;	//玄冰风暴等级
	FBZNLv[Client]					= 0;	//风暴之怒等级
	HMZSLv[Client]				    = 0;	//毁灭之书等级
	SPZSLv[Client]					= 0;	//审判之书等级
	JYSQLv[Client]					= 0;	//坚硬身躯等级
	SXZGLv[Client]				    = 0;	//嗜血之光等级
	DSZGLv[Client]					= 0;	//毒龙之光等级
	LZDLv[Client]			        = 0;	//雷子弹等级
	WZZGLv[Client]				    = 0;	//武者之光等级
	PHFRLv[Client]					= 0;	//幻影之炎等级
	PHABLv[Client]					= 0;	//幻影爆破等级
	PHZGLv[Client]				    = 0;	//幻影之血等级
	PHSCLv[Client]				    = 0;	//幻影炮等级
	PHFRLv[Client]					= 0;	//死亡契约等级
	PHABLv[Client]					= 0;	//爆破光球等级
	PHZGLv[Client]				    = 0;	//复仇欲望等级
	PHSDLv[Client]				    = 0;	//闪电光球等级
	XJLv[Client]					= 0; 	//献祭
	LLLZLv[Client]					= 0; 	//祭祀之光
	LLLELv[Client]					= 0; 	//魔法冲击
	LLLSLv[Client]					= 0; 	//毁灭压制
	GELINLv[Client]					= 0; 	//重机枪
	HYJWLv[Client]					= 0; 	//幻影剑舞
	XZKBLv[Client]					= 0; 	//血之狂暴
	BSTKLv[Client]					= 0; 	//变身坦克
	RebuildStatus(Client, false);

	/*转生洗点不影响大过
	if(KTCount[Client] > 0)
	{
		CPrintToChat(Client, MSG_XD_KT_REMOVE);
		KTCount[Client] -= 5;
		if(KTCount[Client]<0)	KTCount[Client] = 0;
	}
	*/

	//转职后去掉职业套装
	new zbtime;
	for(new i = 61; i <= 65; i++){
		zbtime = GetZBItemTime(Client, i);
		if(zbtime > 0){
			PlayerItem[Client][ITEM_ZB][i] = 0;
			CreateTimer(0.1, StatusUp, Client);
		}
	}

	if(Mode == Admin)
		CPrintToChatAllEx(Client, MSG_XD_SUCCESS_ADMIN, Client);
	else if(Mode == Shop)
		CPrintToChatAllEx(Client, MSG_XD_SUCCESS_SHOP, Client);
	else if(Mode == General)
		CPrintToChatAllEx(Client, MSG_XD_SUCCESS, Client);
	else
		CPrintToChatAll(MSG_NL_SUCCESS, Client);
}

//转生
public Action:MenuFunc_NewLife(Client)
{
	new needlv = GetConVarInt(NewLifeLv) + NewLifeCount[Client] * GetConVarInt(NewLifeLv) / 4;	//120 + 3 * 120 /4=210
	if(Lv[Client] < needlv)
	{
		CPrintToChat(Client, MSG_NL_NEED_LV, needlv);
		return Plugin_Handled;
	}
	else
	{
		new Handle:menu = CreatePanel();
		decl String:line[512];
		Format(line, sizeof(line), "转生说明:\n按确认之后将会清零当前分配的属性和所学的技能 \n玩家重新变为0级,并会增加初始属性点(%d),初始技能点(%d) \n转生后送【暗黑套装】请确保你的装备栏有位置存放！\n你的真的决定进行第%d次转生吗?\n════════════", NewLifeSKP[Client], NewLifeSP[Client], NewLifeCount[Client] + 1);
		SetPanelTitle(menu, line);

		DrawPanelItem(menu, "转生");
		DrawPanelItem(menu, "返回");

		SendPanelToClient(menu, Client, MenuHandler_NewLife, MENU_TIME_FOREVER);
		CloseHandle(menu);
		return Plugin_Handled;
	}
}

public MenuHandler_NewLife(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		switch(param) {
			case 1: ClinetResetStatus(Client, NewLife);
			case 2: return;
		}
	}
}
stock ChooseJob(Client, Jobid)
{
	if (KTCount[Client] > KTLimit)
	{
		CPrintToChat(Client, MSG_ZZ_FAIL_KT);
	}
	else if (JD[Client])
	{
		CPrintToChat(Client, MSG_ZZ_FAIL_JCB_TURE);
	}
	else
	{
		//转职后去掉新手套装
		new zbtime = GetZBItemTime(Client, ITZB_XSZB);
		if(zbtime > 0){
			PlayerItem[Client][ITEM_ZB][ITZB_XSZB] = 0;
			CreateTimer(0.1, StatusUp, Client);
		}
		if (Jobid==1)//工程师
		{
			if (Str[Client] >= JOB1_Str && Agi[Client] >= JOB1_Agi && Health[Client] >= JOB1_Health && Endurance[Client] >= JOB1_Endurance && Intelligence[Client] >= JOB1_Intelligence)
			{
				JD[Client] = 1;
				Str[Client] += 10;
				Endurance[Client] += 10;
				Intelligence[Client] += 10;
				CPrintToChatAll(MSG_ZZ_SUCCESS_JOB1_ANNOUNCE, Client);
				CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB1_REWARD);
			}
			else
			{
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
				CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB1_Str, JOB1_Agi, JOB1_Health, JOB1_Endurance, JOB1_Intelligence);
				CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
			}
		}
		else if (Jobid==2)//士兵
		{
			if (Str[Client] >= JOB2_Str && Agi[Client] >= JOB2_Agi && Health[Client] >= JOB2_Health && Endurance[Client] >= JOB2_Endurance && Intelligence[Client] >= JOB2_Intelligence)
			{
				JD[Client] = 2;
				Str[Client] += 10;
				Agi[Client] += 10;
				Health[Client] += 10;
				CPrintToChatAll(MSG_ZZ_SUCCESS_JOB2_ANNOUNCE, Client);
				CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB2_REWARD);
			}
			else
			{
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
				CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB2_Str, JOB2_Agi, JOB2_Health, JOB2_Endurance, JOB2_Intelligence);
				CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
			}
		}
		else if (Jobid==3)//圣骑士
		{
			if (Str[Client] >= JOB3_Str && Agi[Client] >= JOB3_Agi && Health[Client] >= JOB3_Health && Endurance[Client] >= JOB3_Endurance && Intelligence[Client] >= JOB3_Intelligence)
			{
				JD[Client] = 3;
				Str[Client] += 10;
				Health[Client] += 10;
				Intelligence[Client] += 10;
				CPrintToChatAll(MSG_ZZ_SUCCESS_JOB3_ANNOUNCE, Client);
				CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB3_REWARD);
			}
			else
			{
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
				CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB3_Str, JOB3_Agi, JOB3_Health, JOB3_Endurance, JOB3_Intelligence);
				CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
			}
		}
		else if (Jobid==4)//心灵医师
		{
			if (Str[Client] >= JOB4_Str && Agi[Client] >= JOB4_Agi && Health[Client] >= JOB4_Health && Endurance[Client] >= JOB4_Endurance && Intelligence[Client] >= JOB4_Intelligence)
			{
				JD[Client] = 4;
				Str[Client] += 10;
				Health[Client] += 10;
				Endurance[Client] += 10;
				if (Lv[Client] < 50)
					defibrillator[Client] = 2;
				else
					defibrillator[Client] = 3;
				CPrintToChatAll(MSG_ZZ_SUCCESS_JOB4_ANNOUNCE, Client);
				CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB4_REWARD);
			}
			else
			{
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
				CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB4_Str, JOB4_Agi, JOB4_Health, JOB4_Endurance, JOB4_Intelligence);
				CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
			}
		}
		else if (Jobid==5)//魔法师
		{
		    if (NewLifeCount[Client] >= 0)
			{
			    if (Str[Client] >= JOB5_Str && Agi[Client] >= JOB5_Agi && Health[Client] >= JOB5_Health && Endurance[Client] >= JOB5_Endurance && Intelligence[Client] >= JOB5_Intelligence)
			    {
				    JD[Client] = 5;
				    Str[Client] += 10;
				    Health[Client] += 10;
				    Intelligence[Client] += 10;
				    CPrintToChatAll(MSG_ZZ_SUCCESS_JOB5_ANNOUNCE, Client);
				    CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB5_REWARD);
			    }
			    else
			    {
				    CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
				    CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB5_Str, JOB5_Agi, JOB5_Health, JOB5_Endurance, JOB5_Intelligence);
				    CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
			    }
		    }
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 6)//弹药专家
		{
			if (NewLifeCount[Client] >= 3)
			{
				if (Str[Client] >= JOB6_Str && Agi[Client] >= JOB6_Agi && Health[Client] >= JOB6_Health && Endurance[Client] >= JOB6_Endurance && Intelligence[Client] >= JOB6_Intelligence)
				{
					JD[Client] = 6;
					Str[Client] += 15;
					Intelligence[Client] += 15;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB6_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB6_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB6_Str, JOB6_Agi, JOB6_Health, JOB6_Endurance, JOB6_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 7)//地狱使者
		{
			if (NewLifeCount[Client] >= 3)
			{
				if (Str[Client] >= JOB7_Str && Agi[Client] >= JOB7_Agi && Health[Client] >= JOB7_Health && Endurance[Client] >= JOB7_Endurance && Intelligence[Client] >= JOB7_Intelligence)
				{
					JD[Client] = 7;
					Str[Client] += 20;
					Health[Client] += 20;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB7_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB7_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB7_Str, JOB7_Agi, JOB7_Health, JOB7_Endurance, JOB7_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 8)//死神
		{
			if (NewLifeCount[Client] >= 1)
			{
				if (Str[Client] >= JOB8_Str && Agi[Client] >= JOB8_Agi && Health[Client] >= JOB8_Health && Endurance[Client] >= JOB8_Endurance && Intelligence[Client] >= JOB8_Intelligence)
				{
					JD[Client] = 8;
					Str[Client] += 20;
					Health[Client] += 20;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB8_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB8_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB8_Str, JOB8_Agi, JOB8_Health, JOB8_Endurance, JOB8_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 9)//黑暗行者
		{
			if (NewLifeCount[Client] >= 0)
			{
				if (Str[Client] >= JOB9_Str && Agi[Client] >= JOB9_Agi && Health[Client] >= JOB9_Health && Endurance[Client] >= JOB9_Endurance && Intelligence[Client] >= JOB9_Intelligence)
				{
					JD[Client] = 9;
					Str[Client] += 20;
					Health[Client] += 20;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB9_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB9_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB9_Str, JOB9_Agi, JOB9_Health, JOB9_Endurance, JOB9_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 10)//死亡祭师
		{
			if (NewLifeCount[Client] >= 0)
			{
				if (Str[Client] >= JOB10_Str && Agi[Client] >= JOB10_Agi && Health[Client] >= JOB10_Health && Endurance[Client] >= JOB10_Endurance && Intelligence[Client] >= JOB10_Intelligence)
				{
					JD[Client] = 10;
					Str[Client] += 20;
					Health[Client] += 20;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB10_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB10_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB10_Str, JOB10_Agi, JOB10_Health, JOB10_Endurance, JOB10_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 11)//雷电使者
		{
			if (NewLifeCount[Client] >= 1)
			{
				if (Str[Client] >= JOB11_Str && Agi[Client] >= JOB11_Agi && Health[Client] >= JOB11_Health && Endurance[Client] >= JOB11_Endurance && Intelligence[Client] >= JOB11_Intelligence)
				{
					JD[Client] = 11;
					Str[Client] += 20;
					Health[Client] += 20;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB11_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB11_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB11_Str, JOB11_Agi, JOB11_Health, JOB11_Endurance, JOB11_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 12)//影武者
		{
			if (NewLifeCount[Client] >= 5)
			{
				if (Str[Client] >= JOB12_Str && Agi[Client] >= JOB12_Agi && Health[Client] >= JOB12_Health && Endurance[Client] >= JOB12_Endurance && Intelligence[Client] >= JOB12_Intelligence)
				{
					JD[Client] = 12;
					Str[Client] += 20;
					Health[Client] += 20;
					Intelligence[Client] += 10;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB12_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB12_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB12_Str, JOB12_Agi, JOB12_Health, JOB12_Endurance, JOB12_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_YWZYS);
		}
		else if (Jobid == 13)//审判者
		{
			if (NewLifeCount[Client] >= 8 && VIP[Client] == 4 || VIP[Client] == 5 || VIP[Client] == 6)
			{
				if (Str[Client] >= JOB13_Str && Agi[Client] >= JOB13_Agi && Health[Client] >= JOB13_Health && Endurance[Client] >= JOB13_Endurance && Intelligence[Client] >= JOB13_Intelligence)
				{
					JD[Client] = 13;
					Str[Client] += 30;
					Health[Client] += 50;
					Intelligence[Client] += 20;
					SMZS[Client] = 5;
					FHZS[Client] = 7;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB13_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB13_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB13_Str, JOB13_Agi, JOB13_Health, JOB13_Endurance, JOB13_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 14)//毒龙
		{
			if (NewLifeCount[Client] >= 6 && VIP[Client] >= 4)
			{
				if (Str[Client] >= JOB14_Str && Agi[Client] >= JOB14_Agi && Health[Client] >= JOB14_Health && Endurance[Client] >= JOB14_Endurance && Intelligence[Client] >= JOB14_Intelligence)
				{
					JD[Client] = 14;
					Str[Client] += 30;
					Health[Client] += 50;
					Intelligence[Client] += 20;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB14_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB14_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB14_Str, JOB13_Agi, JOB14_Health, JOB14_Endurance, JOB14_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 15)//幻影统帅
		{
			if (NewLifeCount[Client] >= 8 && VIP[Client] >= 4)
			{
				if (Str[Client] >= JOB15_Str && Agi[Client] >= JOB15_Agi && Health[Client] >= JOB15_Health && Endurance[Client] >= JOB15_Endurance && Intelligence[Client] >= JOB15_Intelligence)
				{
					JD[Client] = 15;
					Str[Client] += 50;
					Health[Client] += 50;
					Intelligence[Client] += 50;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB15_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB15_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB15_Str, JOB15_Agi, JOB15_Health, JOB15_Endurance, JOB15_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 16)//复仇者
		{
			if (NewLifeCount[Client] >= 7 && VIP[Client] == 4 || VIP[Client] == 5 || VIP[Client] == 3)
			{
				if (Str[Client] >= JOB16_Str && Agi[Client] >= JOB16_Agi && Health[Client] >= JOB16_Health && Endurance[Client] >= JOB16_Endurance && Intelligence[Client] >= JOB16_Intelligence)
				{
					JD[Client] = 16;
					Str[Client] += 10;
					Health[Client] += 10;
					Intelligence[Client] += 10;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB16_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB16_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB16_Str, JOB16_Agi, JOB16_Health, JOB16_Endurance, JOB16_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 17)//大祭祀
		{
			if (NewLifeCount[Client] >= 3)
			{
				if (Str[Client] >= JOB17_Str && Agi[Client] >= JOB17_Agi && Health[Client] >= JOB17_Health && Endurance[Client] >= JOB17_Endurance && Intelligence[Client] >= JOB17_Intelligence)
				{
					JD[Client] = 17;
					Str[Client] += 10;
					Health[Client] += 10;
					Intelligence[Client] += 10;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB17_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB17_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB17_Str, JOB17_Agi, JOB17_Health, JOB17_Endurance, JOB17_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 18)//狂战士
		{
			if (NewLifeCount[Client] >= 8)
			{
				if (Str[Client] >= JOB18_Str && Agi[Client] >= JOB18_Agi && Health[Client] >= JOB18_Health && Endurance[Client] >= JOB18_Endurance && Intelligence[Client] >= JOB18_Intelligence)
				{
					JD[Client] = 18;
					Str[Client] += 10;
					Health[Client] += 10;
					Intelligence[Client] += 10;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB18_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB18_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB18_Str, JOB18_Agi, JOB18_Health, JOB18_Endurance, JOB18_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		else if (Jobid == 19)//变异坦克
		{
			if (NewLifeCount[Client] >= 1)
			{
				if (Str[Client] >= JOB19_Str && Agi[Client] >= JOB19_Agi && Health[Client] >= JOB19_Health && Endurance[Client] >= JOB19_Endurance && Intelligence[Client] >= JOB19_Intelligence)
				{
					JD[Client] = 19;
					Str[Client] += 10;
					Health[Client] += 10;
					Intelligence[Client] += 10;
					CPrintToChatAll(MSG_ZZ_SUCCESS_JOB18_ANNOUNCE, Client);
					CPrintToChat(Client, MSG_ZZ_SUCCESS_JOB19_REWARD);
				}
				else
				{
					CPrintToChat(Client, MSG_ZZ_FAIL_NEED_STATUS);
					CPrintToChat(Client, MSG_ZZ_FAIL_JOB_NEED, JOB19_Str, JOB19_Agi, JOB19_Health, JOB19_Endurance, JOB19_Intelligence);
					CPrintToChat(Client, MSG_ZZ_FAIL_SHOW_STATUS, Str[Client], Agi[Client], Health[Client], Endurance[Client], Intelligence[Client]);
				}
			}
			else
				CPrintToChat(Client, MSG_ZZ_FAIL_NEED_NEWLIFE);
		}
		//绑定新职业按键
		BindKeyFunction(Client);
	}

}

/* 购物商店 */
public Action:Menu_Buy(Client)
{
	MenuFunc_Buy(Client);
	return Plugin_Handled;
}
public MenuFunc_Buy(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_Buy);
	SetMenuTitle(menu, "金钱: %d$ 记大过: %d次 求生币: %d个 烈焰勋章: %d枚", Cash[Client], KTCount[Client], XB[Client], Lyxz[Client]);
	AddMenuItem(menu, "item0", "药物杂项");
	AddMenuItem(menu, "item1", "精品枪械");
	AddMenuItem(menu, "item2", "近战商店");
	AddMenuItem(menu, "item3", "神秘商店");
	AddMenuItem(menu, "item4", "赌博抽奖");
	AddMenuItem(menu, "item5", "装备商城");

	//SetMenuPagination(menu, MENU_NO_PAGINATION);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}
public MenuHandler_Buy(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select )
	{
		switch (itemNum)
		{
			case 0: MenuFunc_NormalItemShop(Client);
			case 1: MenuFunc_SelectedGunShop(Client);
			case 2: MenuFunc_MeleeShop(Client);
			case 3: MenuFunc_SpecialShop(Client);
			case 4: MenuFunc_LotteryCasino(Client);
			case 5: MenuFunc_ZBGM(Client);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack)
			MenuFunc_RPG(Client);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

//白银体验店Lv[Client]
public Action:MenuFunc_BJTY(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[32];

	Format(line, sizeof(line), "白银VIP体验[领取]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "条件:低于20级的玩家");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "体验:领取白金VIP3天");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "提示:输入!vipfree为补给,!vipvote为踢人");
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "返回超级市场");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_BJTY, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_BJTY(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: VIP2TY(Client);
		}
	}
}

public VIP2TY(Client)
{
	if(IsValidPlayer(Client) && IsPasswordConfirm[Client])
	{
		if(VIP[Client] <= 0 && VIPTYISOVER(Client))
		{
			new year = GetThisYear();
			new month = GetMonth();
			new viptydate = year * 100 + month;
			VIPTYOVER[Client] = viptydate;
			ServerCommand("sm_vip \"%N\" \"1\" \"3\"", Client);
			CPrintToChat(Client, "\x05[VIP体验]\x04你已经领取\x03白银VIP 有效期3天，\x04请好好珍惜");
			CPrintToChatAll("\x03[VIP体验]\x04恭喜玩家\x05%N\x04成为\x05体验白银VIP", Client);
			//CPrintToChat(Client,"viptyover:%d",VIPTYOVER[Client]);
		} 
		else
		{
			CPrintToChat(Client, "\x03【提示】你已经是VIP或者本月已经体验过了!");
			//CPrintToChat(Client,"viptyover:%d",VIPTYOVER[Client]);
		}
	}
	else
	{
		CPrintToChat(Client, "\x03【温馨提示】请登录游戏后再领取!");
	}
}

public bool:VIPTYISOVER(Client)
{
	new year = GetThisYear();
	new month = GetMonth();
	new viptydate = year * 100 + month;
	if ( VIPTYOVER[Client] == viptydate )
	{
		return false;
	}
	else
	{
		return true;
	}
}

/* 强化石购买 */
public Action:MenuFunc_Eqgou(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "═══强化石材料═══ \n强化石可以进行强化支的伤害 \n强化石不是百分百强化成功的注意!");
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "说明: 强化枪械的材料(价格求生币:200)");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "购买");
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Eqgou, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public MenuHandler_Eqgou(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: EQBBX(Client);
            case 2: MenuFunc_GONG(Client);
		}
	}
}
public EQBBX(Client)
{
    if(XB[Client] >= 200)
    {
        XB[Client] -= 200;
        Qhs[Client]++;
        CPrintToChat(Client, "\x05【提示】你购买了强化石 当前剩余求生币%d!", XB[Client]);	CPrintToChatAll("\x05【提示】玩家 %N 通过求生币商店购买了一块强化石!", Client);
    } else CPrintToChat(Client, "\x05【提示】购买失败,求生币不足!");
}

/* 炎神宝盒 */
public Action:MenuFunc_Eqboxgz(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "═══炎神宝盒 (拥有: %d个)═══", Eqbox[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "金奖:天堂神器30日、樱花30天雷神30日或者4种特殊力量！\n银奖:单个专属装备7日或者其他装备7日 \n铜奖:中等或者高级的普通单个装备7天或3天或者卷轴5个 \n安慰奖:3W或者5W金钱、宝石、经验或者低级装备7天!");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "购买宝盒(需求生币:300)");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "开启宝盒(需金币:1000)");
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Eqboxgz, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public MenuHandler_Eqboxgz(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: GOUMAI(Client);
            case 2: UseEqboxcsFunc(Client);
		}
	}
}
public Action:UseEqboxcsFunc(Client)
{
    if(Cash[Client] >= 1000)
	{

	    if(Eqbox[Client]>0)
	    {
            Eqbox[Client]--;Cash[Client] -= 1000;
            new diceNum;
            diceNum = GetRandomInt(1, 121);
            switch (diceNum)
		    {
                case 1:
			    {
                    SetZBItemTime(Client, 43, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属头盔】7日!", Client);
                }
                case 2:
			    {
                    SetZBItemTime(Client, 44, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属铠甲】7日！", Client);
                }
                case 3:
			    {
                    SetZBItemTime(Client, 46, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属鞋子】7日！", Client);
                }
                case 4:
			    {
                    SetZBItemTime(Client, 47, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属项链】7日", Client);
                }
                case 5:
			    {
                    SetZBItemTime(Client, 48, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属武器】7日", Client);
                }
                case 6:
			    {
                    SetZBItemTime(Client, 49, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属生命盾】7日", Client);
                }
                case 7:
			    {
                    SetZBItemTime(Client, 45, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属裤子】7日", Client);
                }
                case 8:
			    {
                    LisA[Client]++;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【天使之力】永久1个", Client);
                }
				case 9:
			    {
                    LisB[Client]++;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【恶魔之力】永久1个", Client);
                }
				case 10:
			    {
                    LisC[Client]++;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【地狱之力】永久1个", Client);
                }
				case 11:
			    {
                    SetZBItemTime(Client, 4, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级治愈戒指】7天", Client);
                }
				case 12:
			    {
                    SetZBItemTime(Client, 8, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级鬼步靴子】7天", Client);
                }
				case 13:
			    {
                    SetZBItemTime(Client, 14, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级生命之盾】7天", Client);
                }
				case 14:
			    {
                    SetZBItemTime(Client, 20, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级火焰风衣】7天", Client);
                }
				case 15:
			    {
                    SetZBItemTime(Client, 24, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级改良弹药】7天", Client);
                }
				case 16:
			    {
                    SetZBItemTime(Client, 28, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级魔力颈链】7天", Client);
                }
				case 17:
			    {
                    SetZBItemTime(Client, 32, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级改造枪膛】7天", Client);
                }
				case 18:
			    {
                    SetZBItemTime(Client, 40, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级金刚护甲】7天", Client);
                }
				case 19:
			    {
                    SetZBItemTime(Client, 68, 30, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【圣灵之光】30天", Client);
                }
				case 20:
			    {
                    SetZBItemTime(Client, 69, 15, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【圣灵魔光】15天", Client);
                }
				case 21:
			    {
                    SetZBItemTime(Client, 70, 15, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【冰封】15天", Client);
                }
				case 22:
			    {
                    SetZBItemTime(Client, 71, 15, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【神灵光翼】15天", Client);
                }
				case 23:
			    {
                    SetZBItemTime(Client, 72, 15, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【神灵之剑】15天", Client);
                }
				case 24:
			    {
                    SetZBItemTime(Client, 74, 15, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【樱花枪膛】15天", Client);
                }
				case 25:
			    {
                    SetZBItemTime(Client, 16, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【圣翼】7天", Client);
                }
				case 26:
			    {
                    SetZBItemTime(Client, 3, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【中级治愈戒指】7天", Client);
                }
				case 27:
			    {
                    SetZBItemTime(Client, 7, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【中级鬼步靴子】7天", Client);
                }
				case 28:
			    {
                    SetZBItemTime(Client, 13, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【中级生命之盾】7天", Client);
                }
				case 29:
			    {
                    SetZBItemTime(Client, 19, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【中极火焰风衣】7天", Client);
                }
				case 30:
			    {
                    SetZBItemTime(Client, 23, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【中级改良弹药】7天", Client);
                }
				case 31:
			    {
                    SetZBItemTime(Client, 27, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【中级魔力颈链】7天", Client);
                }
				case 32:
			    {
                    SetZBItemTime(Client, 31, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【中级改造枪膛】7天", Client);
                }
				case 33:
			    {
                    SetZBItemTime(Client, 39, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【中级金刚护甲】7天", Client);
                }
				case 34:
			    {
                    Cash[Client] += 50000;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖 50000金钱", Client);
                }
				case 35:
			    {
                    Cash[Client] += 30000;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖 30000金钱", Client);
                }
				case 36:
			    {
                    SetZBItemTime(Client, 75, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖 【樱花项链】7天", Client);
                }
				case 37:
			    {
                    SetZBItemTime(Client, 2, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级治愈戒指】7天", Client);
                }
				case 38:
			    {
                    SetZBItemTime(Client, 6, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级鬼步靴子】7天", Client);
                }
				case 39:
			    {
                    SetZBItemTime(Client, 12, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级生命之盾】7天", Client);
                }
				case 40:
			    {
                    SetZBItemTime(Client, 18, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级火焰风衣】7天", Client);
                }
				case 41:
			    {
                    SetZBItemTime(Client, 22, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级改良弹药】7天", Client);
                }
				case 42:
			    {
                    SetZBItemTime(Client, 26, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级魔力颈链】7天", Client);
                }
				case 43:
			    {
                    SetZBItemTime(Client, 30, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级改造枪膛】7天", Client);
                }
				case 44:
			    {
                    SetZBItemTime(Client, 38, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级金刚护甲】7天", Client);
                }
				case 45:
			    {
                    SetZBItemTime(Client, 11, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【光之翼】7日!", Client);
                }
                case 46:
			    {
                    SetZBItemTime(Client, 10, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【羽翔之翼】7日！", Client);
                }
				case 47:
			    {
                    SetZBItemTime(Client, 76, 30, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【圣灵勋章】30日！", Client);
                }
				case 48:
			    {
                    PlayerItem[Client][ITEM_XH][0] += 0;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【什么也没得到】!", Client);
                }
                case 49:
			    {
                    PlayerItem[Client][ITEM_XH][1] += 5;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【疾风步卷轴】5个！", Client);
                }
				case 50:
			    {
                    PlayerItem[Client][ITEM_XH][2] += 5;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【射速卷轴】5个！", Client);
                }
				case 51:
			    {
                    PlayerItem[Client][ITEM_XH][3] += 5;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【快速装填卷轴】5个!", Client);
                }
                case 52:
			    {
                    PlayerItem[Client][ITEM_XH][4] += 5;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【生命恢复卷轴】5个！", Client);
                }
				case 53:
			    {
                    PlayerItem[Client][ITEM_XH][5] += 5;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【魔力恢复卷轴】5个！", Client);
                }
				case 54:
			    {
                    PlayerItem[Client][ITEM_XH][8] += 5;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【炎神填装卷轴】5个！", Client);
                }
				case 55:
			    {
                    MFBS6[Client] += 1;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖 装备合成宝石1块", Client);
                }
				case 56:
			    {
                    EXP[Client] += 800;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖 经验800点", Client);
                }
				case 57:
			    {
                    Qhs[Client] += 1;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖 强化石1块", Client);
                }
				case 58:
			    {
                    SetZBItemTime(Client, 4, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【高级治愈戒指】3天", Client);
                }
				case 59:
			    {
                    SetZBItemTime(Client, 8, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【高级鬼步靴子】3天", Client);
                }
				case 60:
			    {
                    SetZBItemTime(Client, 14, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【高级生命之盾】3天", Client);
                }
				case 61:
			    {
                    SetZBItemTime(Client, 20, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【高级火焰风衣】3天", Client);
                }
				case 62:
			    {
                    SetZBItemTime(Client, 24, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【高级改良弹药】3天", Client);
                }
				case 63:
			    {
                    SetZBItemTime(Client, 28, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【高级魔力颈链】3天", Client);
                }
				case 64:
			    {
                    SetZBItemTime(Client, 32, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【高级改造枪膛】3天", Client);
                }
				case 65:
			    {
                    SetZBItemTime(Client, 40, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【高级金刚护甲】3天", Client);
                }
				case 66:
			    {
                    Qhs[Client] += 1;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖强化石1个", Client);
                }
				case 67:
			    {
                    LisD[Client]++;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【圣灵之力】永久1个", Client);
                }
				case 68:
			    {
                    SetZBItemTime(Client, 80, 30, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【雷神】30天", Client);
                }
				case 69:
			    {
                    PlayerItem[Client][ITEM_XH][8] += 1;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【炎神填装卷轴】1个！", Client);
                }
				case 70:
			    {
                    PlayerItem[Client][ITEM_XH][8] += 2;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【炎神填装卷轴】2个！", Client);
                }
				case 71:
			    {
                    SetZBItemTime(Client, 89, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【龙王之怒】7天", Client);
                }
				case 72:
			    {
                    SetZBItemTime(Client, 110, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【小野武器】7天", Client);
                }
				case 73:
			    {
                    SetZBItemTime(Client, 40, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【高级金刚护甲】7天", Client);
                }
				case 74:
			    {
                    SetZBItemTime(Client, 43, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属头盔】7日!", Client);
                }
                case 75:
			    {
                    SetZBItemTime(Client, 44, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属铠甲】7日！", Client);
                }
                case 76:
			    {
                    SetZBItemTime(Client, 46, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属鞋子】7日！", Client);
                }
                case 77:
			    {
                    SetZBItemTime(Client, 47, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属项链】7日", Client);
                }
                case 78:
			    {
                    SetZBItemTime(Client, 48, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属武器】7日", Client);
                }
                case 79:
			    {
                    SetZBItemTime(Client, 49, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属生命盾】7日", Client);
                }
                case 80:
			    {
                    SetZBItemTime(Client, 45, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【专属裤子】7日", Client);
                }
                case 81:
			    {
                    LisA[Client]++;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【天使之力】永久1个", Client);
                }
				case 82:
			    {
                    LisB[Client]++;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【恶魔之力】永久1个", Client);
                }
				case 83:
			    {
                    LisC[Client]++;
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【地狱之力】永久1个", Client);
                }
				case 84:
			    {
                    SetZBItemTime(Client, 4, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级治愈戒指】7天", Client);
                }
				case 85:
			    {
                    SetZBItemTime(Client, 8, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级鬼步靴子】7天", Client);
                }
				case 86:
			    {
                    SetZBItemTime(Client, 14, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级生命之盾】7天", Client);
                }
				case 87:
			    {
                    SetZBItemTime(Client, 20, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级火焰风衣】7天", Client);
                }
				case 88:
			    {
                    SetZBItemTime(Client, 24, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级改良弹药】7天", Client);
                }
				case 89:
			    {
                    SetZBItemTime(Client, 28, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级魔力颈链】7天", Client);
                }
				case 90:
			    {
                    SetZBItemTime(Client, 32, 2, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级改造枪膛】2天", Client);
                }
				case 91:
			    {
                    SetZBItemTime(Client, 40, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级金刚护甲】3天", Client);
                }
				case 92:
			    {
                    SetZBItemTime(Client, 68, 5, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【圣灵之光】5天", Client);
                }
				case 93:
			    {
                    SetZBItemTime(Client, 69, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【圣灵魔光】3天", Client);
                }
				case 94:
			    {
                    SetZBItemTime(Client, 70, 5, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得金奖【冰封】5天", Client);
                }
				case 95:
			    {
                    SetZBItemTime(Client, 8, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级鬼步靴子】7天", Client);
                }
				case 96:
			    {
                    SetZBItemTime(Client, 14, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级生命之盾】7天", Client);
                }
				case 97:
			    {
                    SetZBItemTime(Client, 20, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级火焰风衣】7天", Client);
                }
				case 98:
			    {
                    SetZBItemTime(Client, 24, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级改良弹药】7天", Client);
                }
				case 99:
			    {
                    SetZBItemTime(Client, 28, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级魔力颈链】7天", Client);
                }
				case 100:
			    {
                    SetZBItemTime(Client, 32, 2, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级改造枪膛】2天", Client);
                }
				case 101:
			    {
                    SetZBItemTime(Client, 40, 3, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得铜奖【高级金刚护甲】3天", Client);
                }
				case 102:
			    {
                    SetZBItemTime(Client, 2, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级治愈戒指】7天", Client);
                }
				case 103:
			    {
                    SetZBItemTime(Client, 6, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级鬼步靴子】7天", Client);
                }
				case 104:
			    {
                    SetZBItemTime(Client, 12, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级生命之盾】7天", Client);
                }
				case 105:
			    {
                    SetZBItemTime(Client, 18, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级火焰风衣】7天", Client);
                }
				case 106:
			    {
                    SetZBItemTime(Client, 22, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级改良弹药】7天", Client);
                }
				case 107:
			    {
                    SetZBItemTime(Client, 26, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级魔力颈链】7天", Client);
                }
				case 108:
			    {
                    SetZBItemTime(Client, 30, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级改造枪膛】7天", Client);
                }
				case 109:
			    {
                    SetZBItemTime(Client, 38, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得安慰奖【低级金刚护甲】7天", Client);
                }
				case 110:
			    {
                    SetZBItemTime(Client, 11, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【光之翼】7日!", Client);
                }
				case 111:
			    {
                    SetZBItemTime(Client, 110, 30, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【小野的武器】30日!", Client);
                }
				case 112:
			    {
                    SetZBItemTime(Client, 99, 30, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【末世之力[神]】30日!", Client);
                }
				case 114:
			    {
                    SetZBItemTime(Client, 104, 30, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【末世之手[神]】30日!", Client);
                }
				case 115:
			    {
                    SetZBItemTime(Client, 79, 30, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【黑暗加农】30日!", Client);
                }
				case 116:
			    {
                    SetZBItemTime(Client, 75, 30, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【樱花项链】30日!", Client);
                }
				case 117:
			    {
                    SetZBItemTime(Client, 107, 30, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【小野的头盔】30日!", Client);
                }
				case 118:
			    {
                    SetZBItemTime(Client, 50, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【紫炎套装】7日!", Client);
                }
				case 119:
			    {
                    SetZBItemTime(Client, 51, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【恶魔套装】7日!", Client);
                }
				case 120:
			    {
                    SetZBItemTime(Client, 48, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【传说★武器】7日!", Client);
                }
				case 121:
			    {
                    SetZBItemTime(Client, 105, 7, false);
                    MenuFunc_Eqboxgz(Client);
                    CPrintToChatAll("\x05【公告】玩家%N打开炎神宝盒获得银奖【小野的护甲】7日!", Client);
                }
            }
	    } else PrintHintText(Client, "【提示】你没有炎神宝盒!");
    } else CPrintToChat(Client, "\x05【提示】所需求生币不够, 无法开启!");
    return Plugin_Handled;
}
public GOUMAI(Client)
{
    if(XB[Client] >= 300)
    {
        XB[Client] -= 300;
        Eqbox[Client]++;
        PrintHintText(Client, "【提示】你购买了炎神宝盒!");
    } else PrintHintText(Client, "【提示】购买失败,求生币不足!");
    MenuFunc_Eqboxgz(Client)
}

/* 求生币商城 */
public Action:MenuFunc_Qiubuy(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【求生币商城】\n当前求生币:%d个 烈焰勋章:%d个", XB[Client], Lyxz[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "说明:1元=100个求生币,烈焰勋章打TANK得!");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "炎神宝盒");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "强化石商店");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "会员充值");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "金币购买");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "装备商城");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "消耗品商城");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "勋章商城");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "下一页");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回生存者商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Qiubuy, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_Qiubuy(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_Eqboxgz(Client);
			case 2: MenuFunc_Eqgou(Client);
			case 3: MenuFunc_Vbuy(Client);
			case 4: MenuFunc_Dbuy(Client);
			case 5: MenuFunc_ZBGM(Client);
			case 6: MenuFunc_Xhpsd(Client);
			case 7: MenuFunc_Lyxzs(Client);
			case 8: MenuFunc_Qiubuy2(Client);
			case 9: MenuFunc_Buy(Client);
		}
	}
}

public Action:MenuFunc_JBZBSC(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【金币装备商城】\n拥有的金币:%d个", Cash[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "警告:购买时检查背包是否充足");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "高级治愈戒指[30天][1000000金钱]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "高级鬼步靴子[30天][1000000金钱]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "高级生命之盾[30天][1000000金钱]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "高级火焰风衣[30天][1000000金钱]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "高级改良弹药[30天][1000000金钱]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "高级魔力颈链+MP[30天][1000000金钱]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "高级改造枪膛[30天][1000000金钱]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "高级金刚护甲[30天][1000000金钱]");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回装备商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_JBZBSC, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_JBZBSC(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
            case 1: GMGJZYJ(Client);
            case 2: GMGJGBX(Client);
            case 3: GMGJSMD(Client);
            case 4: GMGJHYY(Client);
            case 5: GMGJGLD(Client);
            case 6: GMGJMLX(Client);
            case 7: GMGJGQT(Client);
            case 8: GMGJJGJ(Client);
			case 9: MenuFunc_ZBGM(Client);
		}
	}
}

public GMGJZYJ(Client)//项链
{
	if(Cash[Client] >= 1000000 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
	{
		Cash[Client] -= 1000000;
		SetZBItemTime(Client, 4, 31, false);
		CPrintToChatAll("\x03[系统]\04%N在\x05金币装备商城\x04购买了\x0530天的【高级治愈戒指】", Client);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币或者没有足够的装备空间!");
	MenuFunc_JBZBSC(Client)
}

public GMGJGBX(Client)//项链
{
	if(Cash[Client] >= 1000000 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
	{
		Cash[Client] -= 1000000;
		SetZBItemTime(Client, 8, 31, false);
		CPrintToChatAll("\x03[系统]\04%N在\x05金币装备商城\x04购买了\x0530天的【高级鬼步靴子】", Client);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币或者没有足够的装备空间!");
	MenuFunc_JBZBSC(Client)
}

public GMGJSMD(Client)//项链
{
	if(Cash[Client] >= 1000000 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
	{
		Cash[Client] -= 1000000;
		SetZBItemTime(Client, 14, 31, false);
		CPrintToChatAll("\x03[系统]\04%N在\x05金币装备商城\x04购买了\x0530天的【高级鬼步靴子】", Client);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币或者没有足够的装备空间!");
	MenuFunc_JBZBSC(Client)
}

public GMGJHYY(Client)//项链
{
	if(Cash[Client] >= 1000000 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
	{
		Cash[Client] -= 1000000;
		SetZBItemTime(Client, 20, 31, false);
		CPrintToChatAll("\x03[系统]\04%N在\x05金币装备商城\x04购买了\x0530天的【高级火焰风衣】", Client);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币或者没有足够的装备空间!");
	MenuFunc_JBZBSC(Client)
}

public GMGJGLD(Client)//项链
{
	if(Cash[Client] >= 1000000 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
	{
		Cash[Client] -= 1000000;
		SetZBItemTime(Client, 24, 31, false);
		CPrintToChatAll("\x03[系统]\04%N在\x05金币装备商城\x04购买了\x0530天的【高级改良弹药】", Client);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币或者没有足够的装备空间!");
	MenuFunc_JBZBSC(Client)
}

public GMGJMLX(Client)//项链
{
	if(Cash[Client] >= 1000000 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
	{
		Cash[Client] -= 1000000;
		SetZBItemTime(Client, 28, 31, false);
		CPrintToChatAll("\x03[系统]\04%N在\x05金币装备商城\x04购买了\x0530天的【高级魔力项链】", Client);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币或者没有足够的装备空间!");
	MenuFunc_JBZBSC(Client)
}

public GMGJGQT(Client)//项链
{
	if(Cash[Client] >= 1000000 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
	{
		Cash[Client] -= 1000000;
		SetZBItemTime(Client, 32, 31, false);
		CPrintToChatAll("\x03[系统]\04%N在\x05金币装备商城\x04购买了\x0530天的【高级改造枪膛】", Client);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币或者没有足够的装备空间!");
	MenuFunc_JBZBSC(Client)
}

public GMGJJGJ(Client)//项链
{
	if(Cash[Client] >= 1000000 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
	{
		Cash[Client] -= 1000000;
		SetZBItemTime(Client, 40, 31, false);
		CPrintToChatAll("\x03[系统]\04%N在\x05金币装备商城\x04购买了\x0530天的【高级金刚护甲】", Client);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币或者没有足够的装备空间!");
	MenuFunc_JBZBSC(Client)
}

/* 求生币商城 */
public Action:MenuFunc_Qiubuy2(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【求生币商城】\n当前求生币:%d个 烈焰勋章:%d枚", XB[Client], Lyxz[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "说明:求生币100元=1个,烈焰勋章打TANK得!");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "道具商城");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "会员神器商城");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "魔法宝石商城");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "上一页");
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "返回生存者商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Qiubuy2, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_Qiubuy2(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_TSDJ(Client);
			case 2:
            {
               if(VIP[Client] >= 4 || VIP[Client] == 3)
                {
                   MenuFunc_ZBGM(Client);
                } else CPrintToChat(Client, "\x05【提示】你不是至尊VIP或者水晶VIP无法进入!");
			}
            case 3: MenuFunc_MFBSD(Client);
			case 4: MenuFunc_Qiubuy(Client);
			case 5: MenuFunc_Buy(Client);
		}
	}
}

//魔法宝石
public Action:MenuFunc_MFBSD(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【魔法宝石商城】\n拥有的金币:%d个", Cash[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "购买强大的魔法宝石!");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "初级经验宝石1块[200000金币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "中等经验宝石1块[300000金币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "高级经验宝石1块[400000金币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "极品经验宝石1块[500000金币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "魔法装备宝石1块[300求生币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "神装碎片B 1块[100求生币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "神装碎片A 1块[300求生币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "神装碎片S 1块[500求生币]");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回金币商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_MFBSD, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_MFBSD(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: YHQTS(Client);
			case 2: YHXLS(Client);
			case 3: SLZGS(Client);
			case 4: SLMGS(Client);
            case 5: SLBFS(Client);
			case 6: SLBCL(Client);
			case 7: SLACL(Client);
			case 8: SLSCL(Client);
			case 9: MenuFunc_Qiubuy2(Client);
		}
	}
}

public YHQTS(Client)//鞋子
{
	if(Cash[Client] >= 200000)
	{
		Cash[Client] -= 200000;
		MFBS1[Client] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x05初级经验宝石1块,当前金币%d!", Cash[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币!");
	MenuFunc_MFBSD(Client)
}
public YHXLS(Client)//血盾
{
	if(Cash[Client] >= 300000)
	{
		Cash[Client] -= 300000;
		MFBS2[Client] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x05中等经验宝石1块,当前金币%d!", Cash[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币!");
	MenuFunc_MFBSD(Client)
}
public SLZGS(Client)//风衣
{
	if(Cash[Client] >= 400000)
	{
		Cash[Client] -= 400000;
		MFBS3[Client] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x05高级经验宝石1块,当前金币%d!", Cash[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币!");
	MenuFunc_MFBSD(Client)
}

public SLMGS(Client)//弹药
{
	if(Cash[Client] >= 500000)
	{
		Cash[Client] -= 500000;
		MFBS4[Client] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x05极品经验宝石1块,当前金币%d!", Cash[Client]);	 CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金币!");
	MenuFunc_MFBSD(Client)
}

public SLBFS(Client)//项链
{
	if(XB[Client] >= 300)
	{
		XB[Client] -= 300;
		MFBS6[Client] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x05魔法装备宝石1块,当前求生币%d!", Cash[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的求生币!");
	MenuFunc_MFBSD(Client)
}

public SLBCL(Client)//项链
{
	if(XB[Client] >= 100)
	{
		XB[Client] -= 100;
		BCL[Client] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x05套装碎片B 1块,当前求生币%d!", Cash[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的求生币!");
	MenuFunc_MFBSD(Client)
}

public SLACL(Client)//项链
{
	if(XB[Client] >= 300)
	{
		XB[Client] -=300;
		ACL[Client] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x05套装碎片A 1块,当前求生币%d!", Cash[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的求生币!");
	MenuFunc_MFBSD(Client)
}

public SLSCL(Client)//项链
{
	if(XB[Client] >= 500)
	{
		XB[Client] -= 500;
		SCL[Client] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x05套装碎片S 1块,当前求生币%d!", Cash[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的求生币!");
	MenuFunc_MFBSD(Client)
}

/* 烈焰勋章商店 */
public Action:MenuFunc_Lyxzs(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【烈焰勋章商店】\n拥有的烈焰勋章:%d枚", Lyxz[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "请使用烈焰勋章兑换物品\n烈焰勋章是打TANK获得的！");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "金钱兑换");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "装备兑换");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回求生币商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Lyxzs, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_Lyxzs(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_CASHZQ(Client);
			case 2: MenuFunc_ZBZQ(Client);
			case 3: MenuFunc_Qiubuy(Client);
		}
	}
}

public Action:MenuFunc_ZBZQ(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【兑换装备】\n拥有的烈焰勋章:%d枚", Lyxz[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "警告:购买时检查背包是否充足");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "死亡烈狱套装[10天][170枚烈焰勋章]");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_ZBZQ, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_ZBZQ(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
            case 1: VIPJPXLSASZ(Client);
			case 2: MenuFunc_Lyxzs(Client);
		}
	}
}


public VIPJPXLSASZ(Client)//项链
{
	if(Lyxz[Client] >= 170 && PlayerZBItemSize[Client] - GetHasZBItemCount(Client) > 0)
	{
		Lyxz[Client] -= 170;
		SetZBItemTime(Client, 52, 10, false);
		CPrintToChatAll("\x03[系统]\04%N在\x05烈焰勋章商店\x04兑换了\x0510天的【死亡烈狱套装】", Client);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的烈焰勋章或者你的装备空间不足!");
}

/* 兑换游戏币 */
public Action:MenuFunc_CASHZQ(Client)
{
    new Handle:menu = CreatePanel();

    decl String:line[1024];
    Format(line, sizeof(line), "【游戏币兑换】\n拥有的烈焰勋章:%d枚", Lyxz[Client]);
    SetPanelTitle(menu, line);
    Format(line, sizeof(line), "说明:用烈焰勋章兑换金币!");
    DrawPanelText(menu, line);

    Format(line, sizeof(line), "兑换100000$【烈焰勋章:30枚】");
    DrawPanelItem(menu, line);

    Format(line, sizeof(line), "兑换300000$【烈焰勋章:50枚】");
    DrawPanelItem(menu, line);

    Format(line, sizeof(line), "兑换500000$【烈焰勋章:60枚】");
    DrawPanelItem(menu, line);

    DrawPanelItem(menu, "返回烈焰勋章商店");
    DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

    SendPanelToClient(menu, Client, MenuHandler_CASHZQ, MENU_TIME_FOREVER);
    return Plugin_Handled;
}
public MenuHandler_CASHZQ(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: DUIHUANBS(Client);
			case 2: DUIHUANZS(Client);
			case 3: DUIHUANCS(Client);
			case 4: MenuFunc_Lyxzs(Client);
		}
	}
}
public DUIHUANBS(Client)
{
	if(Lyxz[Client] >= 30)
	{
		Cash[Client] += 100000;
		Lyxz[Client] -= 30;
		PrintHintText(Client, "【提示】你成功兑换100000$!");	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else PrintHintText(Client, "【提示】你没有足够的烈焰勋章!");
	MenuFunc_CASHZQ(Client)
}
public DUIHUANZS(Client)
{
	if(Lyxz[Client] >= 50)
	{
		Cash[Client] += 300000;
		Lyxz[Client] -= 50;
		PrintHintText(Client, "【提示】你成功兑换300000$!");	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else PrintHintText(Client, "【提示】你没有足够的烈焰勋章!");
	MenuFunc_CASHZQ(Client)
}
public DUIHUANCS(Client)
{
	if(Lyxz[Client] >= 60)
	{
		Cash[Client] += 500000;
		Lyxz[Client] -= 60;
		PrintHintText(Client, "【提示】你成功兑换500000$!");	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else PrintHintText(Client, "【提示】你没有足够的烈焰勋章!");
	MenuFunc_CASHZQ(Client)
}

public Action:MenuFunc_TSDJ(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【道具商城】\n拥有的金钱:%d个 求生币:%d", Cash[Client], XB[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "提示:道具购买后请在背包中使用 快捷键[U]");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "购买不删档道具1个[50000金钱]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "购买影之匙1把[300求生币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "购买武器补给道具1个[30000金钱]");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回求生币商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_TSDJ, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_TSDJ(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: GMBSDDJ(Client);
			case 2: GMYZS(Client);
			case 3: GMTSBS(Client);
			case 4: MenuFunc_Qiubuy(Client);
		}
	}
}

public GMYZS(Client)//鞋子
{
	if(XB[Client] >= 300)
	{
		XB[Client] -= 300;
		YWZZS[Client] += 1;
		CPrintToChat(Client, "\x03【系统】你成功购买了1个影之匙 当前求生币%d!", XB[Client]);	 CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的求生币!");
	MenuFunc_TSDJ(Client)
}

public GMBSDDJ(Client)//鞋子
{
	if(Cash[Client] >= 50000 || Lv[Client] < 50 || NewLifeCount[Client] == 0)
	{
		Cash[Client] -= 50000;
		BSD[Client] += 1;
		CPrintToChat(Client, "\x03【系统】你成功购买了1个不删档道具 当前金钱%d!", Cash[Client]);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金钱或者你等级达到了50级和转生过!");
	MenuFunc_TSDJ(Client)
}

public GMTSBS(Client)//鞋子
{
	if(Cash[Client] >= 30000)
	{
		Cash[Client] -= 30000;
		TSBS[Client] += 1;
		CPrintToChat(Client, "\x03【系统】你成功购买了武器补给道具 当前金钱%d!", Cash[Client]);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x05【提示】你没有足够的金钱!");
	MenuFunc_TSDJ(Client)
}

//VIP装备
public Action:MenuFunc_Xhpsd(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[124];
	Format(line, sizeof(line), "【消耗品商城】\n拥有的金币:%d个", Cash[Client]);
	SetPanelTitle(menu, line);
	Format(line, sizeof(line), "请保证背包充足!");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "疾走卷轴1个[50000金币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "射速卷轴1个[50000金币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "快速装填卷轴1个[50000金币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "生命恢复卷轴1个[50000金币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "魔力恢复卷轴1个[50000金币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "指挥官卷轴1个[100求生币]");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "无限子弹卷轴1个[100000金币]");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回金币商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Xhpsd, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_Xhpsd(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: VIPQTKBJ(Client);
			case 2: VIPQTSXJ(Client);
			case 3: VIPQTHDJ(Client);
			case 4: VIPSMHFJ(Client);
            case 5: VIPMLHFJ(Client);
			case 6: VIPSGYLB(Client);
			case 7: VIPSXZDJ(Client);
			case 0: MenuFunc_Qiubuy(Client);
		}
	}
}

public VIPSGYLB(Client)//指挥官
{
	if(XB[Client] >= 100 && PlayerXHItemSize[Client] - GetHasXHItemCount(Client) >= 1)
	{
		XB[Client] -= 100;
		PlayerItem[Client][ITEM_XH][0] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x051个指挥官卷轴,当前求生币%d!", XB[Client]);	 CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x03【提示】你没有足够的求生币或者你没有足够的装备空间!");
	MenuFunc_Xhpsd(Client)
}
public VIPQTKBJ(Client)//疾走卷轴
{
	if(Cash[Client] >= 50000 && PlayerXHItemSize[Client] - GetHasXHItemCount(Client) >= 1)
	{
		Cash[Client] -= 50000;
		PlayerItem[Client][ITEM_XH][1] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x051个疾走卷轴,当前金币%d!", Cash[Client]);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x03【提示】你没有足够的金币或者你没有足够的装备空间!");
	MenuFunc_Xhpsd(Client)
}
public VIPQTSXJ(Client)//速射卷轴
{
	if(Cash[Client] >= 50000 && PlayerXHItemSize[Client] - GetHasXHItemCount(Client) >= 1)
	{
		Cash[Client] -= 50000;
		PlayerItem[Client][ITEM_XH][2] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x051个射速卷轴,当前金币%d!", Cash[Client]);	   CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x03【提示】你没有足够的金币或者你没有足够的装备空间!");
	MenuFunc_Xhpsd(Client)
}
public VIPQTHDJ(Client)//快速装填卷轴
{
	if(Cash[Client] >= 50000 && PlayerXHItemSize[Client] - GetHasXHItemCount(Client) >= 1)
	{
		Cash[Client] -= 50000;
		PlayerItem[Client][ITEM_XH][3] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x051个快速填装卷轴,当前金币%d!", Cash[Client]);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x03【提示】你没有足够的金币或者你没有足够的装备空间!");
	MenuFunc_Xhpsd(Client)
}

public VIPSMHFJ(Client)//生命恢复卷轴
{
	if(Cash[Client] >= 50000 && PlayerXHItemSize[Client] - GetHasXHItemCount(Client) >= 1)
	{
		Cash[Client] -= 50000;
		PlayerItem[Client][ITEM_XH][4] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x051个生命恢复卷轴,当前金币%d!", Cash[Client]);	 CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x03【提示】你没有足够的金币或者你没有足够的装备空间!");
	MenuFunc_Xhpsd(Client)
}
public VIPMLHFJ(Client)//魔力恢复卷轴
{
	if(Cash[Client] >= 50000 && PlayerXHItemSize[Client] - GetHasXHItemCount(Client) >= 1)
	{
		Cash[Client] -= 50000;
		PlayerItem[Client][ITEM_XH][5] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x051个魔力恢复卷轴,当前金币%d!", Cash[Client]);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "{red}【提示】你没有足够的金币或者你没有足够的装备空间!");
	MenuFunc_Xhpsd(Client)
}
public VIPSXZDJ(Client)//无限子弹卷轴
{
	if(Cash[Client] >= 100000 && PlayerXHItemSize[Client] - GetHasXHItemCount(Client) >= 1)
	{
		Cash[Client] -= 100000;
		PlayerItem[Client][ITEM_XH][8] += 1;
		CPrintToChat(Client,"\x03[系统]\04你\x04购买了\x051个全体无限子弹卷轴,当前金币%d!", Cash[Client]);	    CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else CPrintToChat(Client, "\x03【提示】你没有足够的金币或者你没有足够的装备空间!");
	MenuFunc_Xhpsd(Client)
}

/* 兑换游戏币 */
public Action:MenuFunc_Dbuy(Client)
{
    new Handle:menu = CreatePanel();

    decl String:line[1024];
    Format(line, sizeof(line), "【金币兑换】\n拥有的求生币:%d个", XB[Client]);
    SetPanelTitle(menu, line);
    Format(line, sizeof(line), "说明:用求生币兑换一定数量金币!");
    DrawPanelText(menu, line);

    Format(line, sizeof(line), "兑换500000金币【求生币:1000】");
    DrawPanelItem(menu, line);

    Format(line, sizeof(line), "兑换1000000金币【求生币:2000】");
    DrawPanelItem(menu, line);

    Format(line, sizeof(line), "兑换1500000金币【求生币:3000】");
    DrawPanelItem(menu, line);

    Format(line, sizeof(line), "兑换2000000金币【求生币:4000】");
    DrawPanelItem(menu, line);

    DrawPanelItem(menu, "返回求生币商城");
    DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

    SendPanelToClient(menu, Client, MenuHandler_Dbuy, MENU_TIME_FOREVER);
    return Plugin_Handled;
}
public MenuHandler_Dbuy(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: DUIHUANB(Client);
			case 2: DUIHUANZ(Client);
			case 3: DUIHUANC(Client);
			case 4: DUIHUAND(Client);
			case 5: MenuFunc_Qiubuy(Client);
		}
	}
}
public DUIHUANB(Client)
{
	if(XB[Client] >= 1000)
	{
		Cash[Client] += 500000;
		XB[Client] -= 1000;
		PrintHintText(Client, "【提示】你成功兑换500000金币!");	 CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else PrintHintText(Client, "【提示】你没有足够的求生币!");
	MenuFunc_Dbuy(Client)
}
public DUIHUANZ(Client)
{
	if(XB[Client] >= 2000)
	{
		Cash[Client] += 1000000;
		XB[Client] -= 2000;
		PrintHintText(Client, "【提示】你成功兑换1000000金币!");	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else PrintHintText(Client, "【提示】你没有足够的求生币!");
	MenuFunc_Dbuy(Client)
}
public DUIHUANC(Client)
{
	if(XB[Client] >= 3000)
	{
		Cash[Client] += 1500000;
		XB[Client] -= 3000;
		PrintHintText(Client, "【提示】你成功兑换1500000金币!");	 CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else PrintHintText(Client, "【提示】你没有足够的求生币!");
	MenuFunc_Dbuy(Client)
}
public DUIHUAND(Client)
{
	if(XB[Client] >= 4000)
	{
		Cash[Client] += 2000000;
		XB[Client] -= 4000;
		PrintHintText(Client, "【提示】你成功兑换1000000金币!");	 CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
	} else PrintHintText(Client, "【提示】你没有足够的求生币!");
	MenuFunc_Dbuy(Client)
}

/* VIP购买 */
public Action:MenuFunc_Vbuy(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【会员充值】\n拥有的求生币:%d个", XB[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "说明:本月vip没到期，不要在购买[注意]!");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "购买白银VIP");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "购买黄金VIP");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "购买水晶VIP");
	DrawPanelItem(menu, line);

	Format(line, sizeof(line), "购买至尊VIP");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回求生币商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Vbuy, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_Vbuy(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_BJGM(Client);
			case 2: MenuFunc_HJGM(Client);
			case 3: MenuFunc_SJGM(Client);
			case 4: MenuFunc_ZZGM(Client);
			case 5: MenuFunc_Qiubuy(Client);
		}
	}
}

/* 至尊VIP购买 */
public Action:MenuFunc_ZZGM(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【至尊VIP购买】\n拥有的求生币:%d个", XB[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "说明:VIP没到期不要购买，否则不加天数!");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "购买至尊VIP 31日");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回VIP商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_ZZGM, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_ZZGM(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_ZZGM30(Client);
			case 2: MenuFunc_Vbuy(Client);
		}
	}
}

/* 购买至尊VIP */
public Action:MenuFunc_ZZGM30(Client)
{
    new Handle:menu = CreatePanel();

    decl String:line[1024];
    Format(line, sizeof(line), "【至尊VIP】\n拥有的求生币:%d个", XB[Client]);
    SetPanelTitle(menu, line);
    Format(line, sizeof(line), "治疗术提升为高级治疗术,拥有150％的经验加成 \n倒地死亡经验减少90％ \n商店有6打折优惠 \n免费补给16个 装备:至尊勋章(-40%火伤) \n拥有投票踢人,换图和个性字体颜色紫色光晕轮廓所需7000个求生币【31天期限】!");
    DrawPanelText(menu, line);

    Format(line, sizeof(line), "确认购买");
    DrawPanelItem(menu, line);
    DrawPanelItem(menu, "返回VIP购买");
    DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

    SendPanelToClient(menu, Client, MenuHandler_ZZGM30, MENU_TIME_FOREVER);
    return Plugin_Handled;
}
public MenuHandler_ZZGM30(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: ZZGM30z(Client);
			case 2: MenuFunc_ZZGM(Client);
		}
	}
}
public ZZGM30z(Client)
{
    if(XB[Client] >= 7000)
    {
        XB[Client] -= 7000;
        ServerCommand("sm_vip \"%N\" \"4\" \"31\"", Client);
        CPrintToChat(Client, "\x03【VIP】你成功购买了至尊VIP 31日 当前求生币%d!", XB[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
        CPrintToChatAll("\x03【VIP】恭喜玩家%N成为至尊VIP", Client);
    } else CPrintToChat(Client, "\x03【提示】你没有足够的求生币!");
}

/* 水晶VIP购买 */
public Action:MenuFunc_SJGM(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【水晶VIP购买】\n拥有的求生币:%d个", XB[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "说明:VIP没到期不要购买，否则不加天数!");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "购买水晶VIP 31日");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回VIP商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_SJGM, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_SJGM(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_GMSJ30(Client);
			case 2: MenuFunc_Vbuy(Client);
		}
	}
}


/* 购买水晶VIP */
public Action:MenuFunc_GMSJ30(Client)
{
    new Handle:menu = CreatePanel();

    decl String:line[1024];
    Format(line, sizeof(line), "【水晶VIP】\n拥有的求生币:%d个", XB[Client]);
    SetPanelTitle(menu, line);
    Format(line, sizeof(line), "治疗术提升为高级治疗术,拥有100％的经验加成 \n倒地死亡经验减少80％ \n商店有7打折优惠 \n免费补给12个 装备:水晶勋章(-20%火伤) \n拥有投票踢人,换图和个性蓝色字体颜色绿色光晕轮廓所需6000个求生币【31天期限】!");
    DrawPanelText(menu, line);

    Format(line, sizeof(line), "确认购买");
    DrawPanelItem(menu, line);
    DrawPanelItem(menu, "返回VIP购买");
    DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

    SendPanelToClient(menu, Client, MenuHandler_GMSJ30, MENU_TIME_FOREVER);
    return Plugin_Handled;
}
public MenuHandler_GMSJ30(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: GMSJ30z(Client);
			case 2: MenuFunc_SJGM(Client);
		}
	}
}
public GMSJ30z(Client)
{
	if(XB[Client] >= 6000)
	{
		XB[Client] -= 6000;
		ServerCommand("sm_vip \"%N\" \"3\" \"31\"", Client);
		CPrintToChat(Client, "\x03【VIP】你成功购买了水晶VIP 31日 当前求生币%d!", XB[Client]);	  CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
		CPrintToChatAll("\x03【VIP】恭喜玩家%N成为水晶VIP", Client);
	} else CPrintToChat(Client, "\x03【提示】你没有足够的求生币!");
}

/* 黄金VIP购买 */
public Action:MenuFunc_HJGM(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【黄金VIP购买】\n拥有的求生币:%d个", XB[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "说明:VIP没到期不要购买，否则不加天数!");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "购买黄金VIP 31日");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回VIP商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_HJGM, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_HJGM(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_GMHJ30(Client);
			case 2: MenuFunc_Vbuy(Client);
		}
	}
}

/* 黄金会员 */
public Action:MenuFunc_GMHJ30(Client)
{
    new Handle:menu = CreatePanel();

    decl String:line[1024];
    Format(line, sizeof(line), "【黄金VIP】\n拥有的求生币:%d个", XB[Client]);
    SetPanelTitle(menu, line);
    Format(line, sizeof(line), "治疗术提升为高级治疗术,拥有80％的经验加成 \n倒地死亡经验减少60％ \n商店有8打折优惠 \n免费补给8个 装备:黄金勋章 \n拥有投票踢人,换图和橄榄色个性字体颜色黄色光晕轮廓所需3000个求生币【31天期限】");
    DrawPanelText(menu, line);

    Format(line, sizeof(line), "确认购买");
    DrawPanelItem(menu, line);
    DrawPanelItem(menu, "返回VIP购买");
    DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

    SendPanelToClient(menu, Client, MenuHandler_GMHJ30, MENU_TIME_FOREVER);
    return Plugin_Handled;
}
public MenuHandler_GMHJ30(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: GMHJ30z(Client);
			case 2: MenuFunc_HJGM(Client);
		}
	}
}
public GMHJ30z(Client)
{
    if(XB[Client] >= 3000)
    {
        XB[Client] -= 3000;
        ServerCommand("sm_vip \"%N\" \"2\" \"31\"", Client);
        CPrintToChat(Client, "\x03【VIP】你成功购买了黄金VIP 31日 当前求生币%d!", XB[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
        CPrintToChatAll("\x03【VIP】恭喜玩家%N成为黄金VIP", Client);
    } else CPrintToChat(Client, "\x03【提示】你没有足够的求生币!");
}

/* 白银VIP购买 */
public Action:MenuFunc_BJGM(Client)
{
	new Handle:menu = CreatePanel();

	decl String:line[1024];
	Format(line, sizeof(line), "【白银VIP购买】\n拥有的求生币:%d个", XB[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "说明:VIP没到期不要购买，否则不加天数!");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "购买白银VIP 31日");
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回VIP商城");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_BJGM, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public MenuHandler_BJGM(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: MenuFunc_GMBJ30(Client);
			case 2: MenuFunc_Vbuy(Client);
		}
	}
}

/* 白银会员 */
public Action:MenuFunc_GMBJ30(Client)
{
    new Handle:menu = CreatePanel();

    decl String:line[1024];
    Format(line, sizeof(line), "【白银VIP】\n拥有的求生币:%d个", XB[Client]);
    SetPanelTitle(menu, line);
    Format(line, sizeof(line), "治疗术提升为高级治疗术,拥有50％的经验加成 \n倒地死亡经验减少50％ \n商店有9打折优惠 \n免费补给4个 装备:白金勋章 \n拥有投票踢人和个性绿色字体颜色白色光晕轮廓所需2000个求生币【31天期限】!");
    DrawPanelText(menu, line);

    Format(line, sizeof(line), "确认购买");
    DrawPanelItem(menu, line);
    DrawPanelItem(menu, "返回VIP购买");
    DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

    SendPanelToClient(menu, Client, MenuHandler_GMBJ30, MENU_TIME_FOREVER);
    return Plugin_Handled;
}
public MenuHandler_GMBJ30(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 1: GMBJ30z(Client);
			case 2: MenuFunc_BJGM(Client);
		}
	}
}
public GMBJ30z(Client)
{
    if(XB[Client] >= 2000)
    {
        XB[Client] -= 2000;
        ServerCommand("sm_vip \"%N\" \"1\" \"31\"", Client);
        CPrintToChat(Client, "\x03【VIP】你成功购买了白银VIP 31日 当前求生币%d!", XB[Client]);	CPrintToChat(Client,"\x03[系统]\x04欢迎您下次光临0(*^__^*)0!");
        CPrintToChatAll("\x03【VIP】恭喜玩家%N成为白银VIP", Client);
    } else CPrintToChat(Client, "\x03【提示】你没有足够的求生币!");
}

/* 抽奖赌博 */
public MenuFunc_LotteryCasino(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_LotteryCasino);
	decl String:line[32];

	SetMenuTitle(menu, "金钱: %d$ 记大过: %d次", Cash[Client], KTCount[Client]);
	AddMenuItem(menu, "option0", "购买大乐透号码");
	AddMenuItem(menu, "option1", "查看其他玩家大乐透号码");

	Format(line, sizeof(line), "彩票抽奖(%d次)", Lottery[Client]);
	AddMenuItem(menu, "option1", line);

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}
public MenuHandler_LotteryCasino(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select )
	{
		switch (itemNum)
		{
			case 0: MenuFunc_Casino(Client);
			case 1: MenuFunc_DaLeTouView(Client);
			case 2: MenuFunc_Lottery(Client);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack)
			MenuFunc_Buy(Client);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}


/* robot专门店 */
public MenuFunc_RobotBuy(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_RobotBuy);
	SetMenuTitle(menu, "伤害加成[力量][枪戒伤害装备]金钱: %d$ 记大过: %d次", Cash[Client], KTCount[Client]);
	AddMenuItem(menu, "option0", "枪戒协助选择");
	if(Robot_appendage[Client] > 0 && robot[Client] > 0)	//如果机器人卡住了,可以重新分配机器人
	if (Robot_appendage[Client] == 0)
	{
		AddMenuItem(menu,"option2","学习双枪技能");
	}
	else if(Robot_appendage[Client] > 0 && robot[Client] > 0)	//如果机器人卡住了,可以重新分配机器人
	{
		AddMenuItem(menu,"option2","重启双枪");
	}
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}
public MenuHandler_RobotBuy(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select )
	{
		switch (itemNum)
		{
			case 0: MenuFunc_RobotShop(Client);
			case 1: MenuFunc_RobotWorkShop(Client);
			case 2: MenuFunc_RobotAppend(Client);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack)
			MenuFunc_Buy(Client);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

//学习双枪
public Action:MenuFunc_RobotAppend(Client)
{
	//双枪重启
	if(Robot_appendage[Client] > 0 && robot[Client] > 0)
	{
		Release(Client);
		AddRobot(Client);
		AddRobot_clone(Client);
		return Plugin_Handled;
	}
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line,sizeof(line),"双枪技能:\n学习后在枪戒选择后会多出现一把同样的机器人!\n价格:2000求生币");
	SetPanelTitle(menu,line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "放弃");

	SendPanelToClient(menu, Client, MenuHandler_RobotAppend, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;

}
//枪神附体学习
public MenuHandler_RobotAppend(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select) {
		switch(param) {
			case 1: ClientBuyRobotAppend(Client);
			case 2: return;
		}
	}
}

public ClientBuyRobotAppend(Client)
{
	if(XB[Client] >= 2000)
	{
		XB[Client] -= 2000;
		Robot_appendage[Client]++;
		CPrintToChatAll("【提示】恭喜 %N 成功学习枪神附体技能!",Client);
	}
	else
	{
		CPrintToChat(Client,"【提示】学习双枪技能失败，您的求生币不够!");
	}
}


/* 投掷品，药物和子弹盒 */
public Action:Menu_NormalItemShop(Client,args)
{
	if(GetClientTeam(Client) == 2 && !IsFakeClient(Client) && GetConVarBool(CfgNormalItemShopEnable))
	{
		MenuFunc_NormalItemShop(Client);
	}
	else if(!IsFakeClient(Client))
	{
		CPrintToChat(Client, "{red}只限幸存者选择!");
	}
	else if(!GetConVarBool(CfgNormalItemShopEnable))
	{
		CPrintToChat(Client, "\x05商店己关闭!");
	}
	return Plugin_Handled;
}

public Action:MenuFunc_NormalItemShop(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_NormalItemShop);
	SetMenuTitle(menu, "：伤害加成[力量][枪戒伤害装备]金钱: %d $", Cash[Client]);

	decl String:line[64], String:option[32];
	for(new i=0; i<NORMALITEMMAX; i++)
	{
		if(VIP[Client] <= 0)
			Format(line, sizeof(line), "%s($%d)", NormalItemName[i], GetConVarInt(CfgNormalItemCost[i]));
		else if(VIP[Client] == 1)
			Format(line, sizeof(line), "%s(Vip:$%d)", NormalItemName[i], RoundToNearest(GetConVarInt(CfgNormalItemCost[i]) * 0.9));
		else if(VIP[Client] == 2)
			Format(line, sizeof(line), "%s(Vip:$%d)", NormalItemName[i], RoundToNearest(GetConVarInt(CfgNormalItemCost[i]) * 0.8));
		else if(VIP[Client] == 3)
			Format(line, sizeof(line), "%s(Vip:$%d)", NormalItemName[i], RoundToNearest(GetConVarInt(CfgNormalItemCost[i]) * 0.7));
		else if(VIP[Client] == 4)
			Format(line, sizeof(line), "%s(Vip:$%d)", NormalItemName[i], RoundToNearest(GetConVarInt(CfgNormalItemCost[i]) * 0.6));
		else if(VIP[Client] == 5)
			Format(line, sizeof(line), "%s(Vip:$%d)", NormalItemName[i], RoundToNearest(GetConVarInt(CfgNormalItemCost[i]) * 0.5));
		else if(VIP[Client] == 6)
			Format(line, sizeof(line), "%s(Vip:$%d)", NormalItemName[i], RoundToNearest(GetConVarInt(CfgNormalItemCost[i]) * 0.4));

		Format(option, sizeof(option), "option%d", i+1);
		AddMenuItem(menu, option, line);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_NormalItemShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)  {
		new bool:status = true;
		new targetcash = Cash[Client];
		new itemcost = VIPAdd(Client, GetConVarInt(CfgNormalItemCost[itemNum]), 2, false);

		if(targetcash >= itemcost) {
			targetcash -= itemcost;
			switch (itemNum)
			{
				case 0: NormalItemShop_Ammo(Client);
				case 1: CheatCommand(Client, "upgrade_add", "laser_sight"); //获得红外线瞄准
				case 2: CheatCommand(Client, "upgrade_add", "explosive_ammo"); //高爆弹
				case 3: CheatCommand(Client, "upgrade_add", "Incendiary_ammo"); //燃烧弹
				case 4: status = Ent_Give(Client, "first_aid_kit");
				case 5: status = Ent_Give(Client, "pain_pills");
				case 6: status = Ent_Give(Client, "adrenaline");
				case 7: status = Ent_Give(Client, "defibrillator");
				case 8: status = Ent_Give(Client, "molotov");
				case 9: status = Ent_Give(Client, "pipe_bomb");
				case 10: status = Ent_Give(Client, "vomitjar");
				case 11: status = Ent_Give(Client, "upgradepack_explosive");
				case 12: status = Ent_Give(Client, "upgradepack_incendiary");
			}
			if(status)
			{
				Cash[Client] = targetcash;
				CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
			}
			else
				CPrintToChat(Client, "攻击状态下无法购买物品！");
		}
		else CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
		MenuFunc_NormalItemShop(Client);
	} else if (action == MenuAction_End) CloseHandle(menu);
}

/* 子弹购买 */
public NormalItemShop_Ammo(Client)
{
	if (!IsValidPlayer(Client, false))
		return;

	CheatCommand(Client, "give", "ammo");
	/*
	new weaponid = GetPlayerWeaponSlot(Client, 0);
	new String:name[64];
	if (weaponid >= 0)
	{
		GetEdictClassname(weaponid, name, sizeof(name));
		if (StrContains(name, "rifle_m60", false) >= 0)
			SetEntProp(weaponid, Prop_Send, "m_iClip1", 250);
		else
			CheatCommand(Client, "give", "ammo");
	}
	else
		CheatCommand(Client, "give", "ammo");
	*/
}

/* 特选枪械 */
public Action:Menu_SelectedGunShop(Client,args)
{
	if(GetClientTeam(Client) == 2 && !IsFakeClient(Client) && GetConVarBool(CfgSelectedGunShopEnable))
		MenuFunc_SelectedGunShop(Client);
	else if(!IsFakeClient(Client))
		CPrintToChat(Client, "{red}只限幸存者选择!");
	else if(!GetConVarBool(CfgSelectedGunShopEnable))
		CPrintToChat(Client, "\x05商店己关闭!");

	return Plugin_Handled;
}

public Action:MenuFunc_SelectedGunShop(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_SelectedGunShop);
	SetMenuTitle(menu, "金钱: %d $", Cash[Client]);

	decl String:line[64], String:option[32];
	for(new i=0; i<SELECTEDGUNMAX; i++)
	{
		if(VIP[Client] <= 0)
			Format(line, sizeof(line), "%s($%d)", GunName[i], GetConVarInt(CfgSelectedGunCost[i]));
		else if(VIP[Client] == 1)
			Format(line, sizeof(line), "%s(Vip:$%d)", GunName[i], RoundToNearest(GetConVarInt(CfgSelectedGunCost[i]) * 0.9));
		else if(VIP[Client] == 2)
			Format(line, sizeof(line), "%s(Vip:$%d)", GunName[i], RoundToNearest(GetConVarInt(CfgSelectedGunCost[i]) * 0.8));
		else if(VIP[Client] == 3)
			Format(line, sizeof(line), "%s(Vip:$%d)", GunName[i], RoundToNearest(GetConVarInt(CfgSelectedGunCost[i]) * 0.7));
		else if(VIP[Client] == 4)
			Format(line, sizeof(line), "%s(Vip:$%d)", GunName[i], RoundToNearest(GetConVarInt(CfgSelectedGunCost[i]) * 0.6));
		else if(VIP[Client] == 5)
			Format(line, sizeof(line), "%s(Vip:$%d)", GunName[i], RoundToNearest(GetConVarInt(CfgSelectedGunCost[i]) * 0.5));
		else if(VIP[Client] == 6)
			Format(line, sizeof(line), "%s(Vip:$%d)", GunName[i], RoundToNearest(GetConVarInt(CfgSelectedGunCost[i]) * 0.4));

		Format(option, sizeof(option), "option%d", i+1);
		AddMenuItem(menu, option, line);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public MenuHandler_SelectedGunShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		new targetcash = Cash[Client];
		new itemcost = VIPAdd(Client, GetConVarInt(CfgSelectedGunCost[itemNum]), 2, false);

		if(targetcash >= itemcost) {
			targetcash -= itemcost;

			if( Ent_Give(Client, GunCode[itemNum]) )
			{
				Cash[Client] = targetcash;
				CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
			}
			else
				CPrintToChat(Client, "攻击状态下无法购买物品！");

		}
		else CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
		MenuFunc_SelectedGunShop(Client);
	} else if (action == MenuAction_End) CloseHandle(menu);
}
/* 近武商店 */
public Action:Menu_MeleeShop(Client,args)
{
	if(GetClientTeam(Client) == 2 && !IsFakeClient(Client) && GetConVarBool(CfgMeleeShopEnable))
	{
		MenuFunc_MeleeShop(Client);
	}
	else if(!IsFakeClient(Client))
	{
		CPrintToChat(Client, "{red}只限幸存者选择!");
	}
	else if(!GetConVarBool(CfgMeleeShopEnable))
	{
		CPrintToChat(Client, "\x05商店己关闭!");
	}
	return Plugin_Handled;
}

public Action:MenuFunc_MeleeShop(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_MeleeShop);
	SetMenuTitle(menu, "金钱: %d $", Cash[Client]);

	decl String:line[64], String:option[32];
	for(new i=0; i<SELECTEDMELEEMAX; i++)
	{
		if(VIP[Client] <= 0)
			Format(line, sizeof(line), "%s($%d)", MeleeName[i], GetConVarInt(CfgMeleeCost[i]));
		else if(VIP[Client] == 1)
			Format(line, sizeof(line), "%s(Vip:$%d)", MeleeName[i], RoundToNearest(GetConVarInt(CfgMeleeCost[i]) * 0.9));
		else if(VIP[Client] == 2)
			Format(line, sizeof(line), "%s(Vip:$%d)", MeleeName[i], RoundToNearest(GetConVarInt(CfgMeleeCost[i]) * 0.8));
		else if(VIP[Client] == 3)
			Format(line, sizeof(line), "%s(Vip:$%d)", MeleeName[i], RoundToNearest(GetConVarInt(CfgMeleeCost[i]) * 0.7));
		else if(VIP[Client] == 4)
			Format(line, sizeof(line), "%s(Vip:$%d)", MeleeName[i], RoundToNearest(GetConVarInt(CfgMeleeCost[i]) * 0.6));
		else if(VIP[Client] == 5)
			Format(line, sizeof(line), "%s(Vip:$%d)", MeleeName[i], RoundToNearest(GetConVarInt(CfgMeleeCost[i]) * 0.5));
		else if(VIP[Client] == 6)
			Format(line, sizeof(line), "%s(Vip:$%d)", MeleeName[i], RoundToNearest(GetConVarInt(CfgMeleeCost[i]) * 0.4));

		Format(option, sizeof(option), "option%d", i+1);
		AddMenuItem(menu, option, line);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_MeleeShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		new targetcash = Cash[Client];
		new itemcost = VIPAdd(Client, GetConVarInt(CfgMeleeCost[itemNum]), 2, false);

		if(targetcash >= itemcost) {
			targetcash -= itemcost;

			if( Ent_Give(Client, MeleeCode[itemNum]) )
			{
				Cash[Client] = targetcash;
				CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
			}
			else
				CPrintToChat(Client, "攻击状态下无法购买物品！");

		}
		else CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
		MenuFunc_MeleeShop(Client);
	} else if (action == MenuAction_End) CloseHandle(menu);
}
/* Robot商店 */
public Action:Menu_RobotShop(Client,args)
{
	if(GetClientTeam(Client) == 2 && !IsFakeClient(Client))
	{
		MenuFunc_RobotShop(Client);
	}
	else if(!IsFakeClient(Client))
	{
		CPrintToChat(Client, "{red}暂时只限幸存者选择!");
	}
	return Plugin_Handled;
}

public Action:MenuFunc_RobotShop(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_RobotShop);
	SetMenuTitle(menu, "金钱: %d $ 机器人使用次数: %d", Cash[Client], RobotCount[Client]);

	decl String:line[128], String:option[32];
	for(new i=0; i<WEAPONCOUNT; i++)
	{
		if(VIP[Client] <= 0)
			Format(line, sizeof(line), "[%s]机器人($%d)", WeaponName[i], GetConVarInt(CfgRobotCost[i])*(RobotCount[Client]+1));
		else if(VIP[Client] == 1)
			Format(line, sizeof(line), "[%s]机器人(Vip:$%d)", WeaponName[i], RoundToNearest(GetConVarInt(CfgRobotCost[i])*(RobotCount[Client]+1) * 0.9));
		else if(VIP[Client] == 2)
			Format(line, sizeof(line), "[%s]机器人(Vip:$%d)", WeaponName[i], RoundToNearest(GetConVarInt(CfgRobotCost[i])*(RobotCount[Client]+1) * 0.8));
		else if(VIP[Client] == 3)
			Format(line, sizeof(line), "[%s]机器人(Vip:$%d)", WeaponName[i], RoundToNearest(GetConVarInt(CfgRobotCost[i])*(RobotCount[Client]+1) * 0.7));
		else if(VIP[Client] == 4)
			Format(line, sizeof(line), "[%s]机器人(Vip:$%d)", WeaponName[i], RoundToNearest(GetConVarInt(CfgRobotCost[i])*(RobotCount[Client]+1) * 0.6));
		else if(VIP[Client] == 5)
			Format(line, sizeof(line), "[%s]机器人(Vip:$%d)", WeaponName[i], RoundToNearest(GetConVarInt(CfgRobotCost[i])*(RobotCount[Client]+1) * 0.5));
		else if(VIP[Client] == 6)
			Format(line, sizeof(line), "[%s]机器人(Vip:$%d)", WeaponName[i], RoundToNearest(GetConVarInt(CfgRobotCost[i])*(RobotCount[Client]+1) * 0.4));

		Format(option, sizeof(option), "option%d", i+1);
		AddMenuItem(menu, option, line);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
public MenuHandler_RobotShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)
	{
		new targetcash = Cash[Client];
		new itemcost = VIPAdd(Client, GetConVarInt(CfgRobotCost[itemNum])*(RobotCount[Client]+1), 2, false);
		if(itemcost == 16)
		{
			MenuFunc_Buy(Client);
		}
		else if(targetcash >= itemcost)
		{
			if(MP[Client] >= 10000 && Robot_appendage[Client] > 0 && robot[Client] == 0)
			{
				MP[Client] -= 10000;
				botenerge[Client] = 0.0;		//机器人能量
				RobotCount[Client] += 1;
				//Cash[Client] = targetcash;
				CPrintToChat(Client,"{olive}【神枪附体】使用成功!");
			}
			else
			{
				targetcash -= itemcost;
				if(robot[Client] == 0)
				{
					botenerge[Client] = 0.0;		//机器人能量
					RobotCount[Client] += 1;
					Cash[Client] = targetcash;
					CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
				}
			}
			sm_robot(Client, itemNum);
		}
		else
		{
			CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}

/* 神秘商店 */
public Action:MenuFunc_SpecialShop(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "金钱: %d$ 记大过: %d次", Cash[Client], KTCount[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "经验之书 ($%d)", GetConVarInt(TomeOfExpCost));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "使用一次增加%d经验~", GetConVarInt(TomeOfExpEffect));
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "神界橡皮擦 ($%d)", GetConVarInt(RemoveKTCost));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "消除一次大过.");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "遗忘河药水 ($%d)", GetConVarInt(ResetStatusCost));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "据说喝了后可以忘记学过的一切！！！.");
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "西蓝果汁 ($%d)", GetConVarInt(ResumeMP));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "源自于希腊的稀有果子榨的汁喝了可回复MP！.");
	DrawPanelText(menu, line);	
	
	
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_SpecialShop, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}

public MenuHandler_SpecialShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		switch (itemNum) {
			case 1: {
				new itemcost	= GetConVarInt(TomeOfExpCost);
				new itemEffect	= GetConVarInt(TomeOfExpEffect);

				if(Cash[Client] >= itemcost)
				{
					EXP[Client] += itemEffect;
					Cash[Client] -= itemcost;
					CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
				}
				else
				{
					CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
				}
				MenuFunc_SpecialShop(Client);
			} case 2: {
				new itemcost	= GetConVarInt(RemoveKTCost);

				if(KTCount[Client]>0)
				{
					if(Cash[Client] >= itemcost)
					{
						Cash[Client] -= itemcost;
						KTCount[Client] -=1;
						CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
					}
					else
					{
						CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
						MenuFunc_SpecialShop(Client);
					}
				} else CPrintToChat(Client, "\x05你暂时不需要购买此物品!");
			} 
			case 3: MenuFunc_SpecialShopConfirm(Client);
			case 4: {		
				new itemcost	= GetConVarInt(ResumeMP);
				
				if(Cash[Client] >= itemcost)
				{
					Cash[Client] -= itemcost;
					new resume = RoundToNearest(MaxMP[Client] * 0.5) + MP[Client];
					if (resume <= MaxMP[Client])
						MP[Client] = resume;
					else
						MP[Client] = MaxMP[Client];
						
					CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
					PrintHintText(Client, "你的MP已经恢复至%d ", MP[Client]);
				}
				else
				{
					CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
					MenuFunc_SpecialShop(Client);
				}		
				
			} case 5: MenuFunc_Buy(Client);
		}
		if (itemNum != 5 && itemNum != 3)
			MenuFunc_SpecialShop(Client);
	}
}

//遗忘河药水购买确认
public Action:MenuFunc_SpecialShopConfirm(Client)
{
	new Handle:menu = CreatePanel();
	DrawPanelText(menu, "======================= \n是否确认够买遗忘河药水? \n=======================");
	DrawPanelText(menu, " \n");
	DrawPanelItem(menu, "是");
	DrawPanelItem(menu, "否");

	SendPanelToClient(menu, Client, MenuHandler_SpecialShopConfirm, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_SpecialShopConfirm(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 1:
			{
				new itemcost	= GetConVarInt(ResetStatusCost);
				if(Cash[Client] >= itemcost)
				{
					Cash[Client] -= itemcost;
					ClinetResetStatus(Client, Shop);
					BindKeyFunction(Client);
					CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
				}
				else
				{
					CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
				}
			}
		}
	}
}

/* Robot工场*/
public Action:MenuFunc_RobotWorkShop(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[64];
	Format(line, sizeof(line), "求生币: %d $", XB[Client]);
	SetPanelTitle(menu, line);

	for(new i=0; i<3; i++)
	{
		Format(line, sizeof(line), RobotUpgradeName[i], RobotUpgradeLv[Client][i], RobotUpgradeLimit[i], GetConVarInt(CfgRobotUpgradeCost[i]));
		DrawPanelItem(menu, line);
		switch (i)
		{
			case 0: Format(line, sizeof(line), RobotUpgradeInfo[0], RobotAttackEffect[Client]);
			case 1: Format(line, sizeof(line), RobotUpgradeInfo[1], RobotAmmoEffect[Client]);
			case 2: Format(line, sizeof(line), RobotUpgradeInfo[2], RobotRangeEffect[Client]);
		}
		DrawPanelText(menu, line);
	}
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_RobotWorkShop, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}

public MenuHandler_RobotWorkShop(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select) {
		new targetcash = XB[Client];
		new itemcost = GetConVarInt(CfgRobotUpgradeCost[itemNum-1]);

		if(RobotUpgradeLv[Client][itemNum-1] < RobotUpgradeLimit[itemNum-1])
		{
			if(targetcash >= itemcost) {
				targetcash -= itemcost;
				RobotUpgradeLv[Client][itemNum-1] += 1;
				XB[Client] = targetcash;
				CPrintToChat(Client, MSG_BUYSUCC, itemcost, XB[Client]);
				switch (itemNum)
				{
					case 1: CPrintToChat(Client, RobotUpgradeInfo[0], RobotAttackEffect[Client]);
					case 2: CPrintToChat(Client, RobotUpgradeInfo[1], RobotAmmoEffect[Client]);
					case 3: CPrintToChat(Client, RobotUpgradeInfo[2], RobotRangeEffect[Client]);
				}
			}
			else CPrintToChat(Client, MSG_BUYFAIL, itemcost, XB[Client]);
		} else CPrintToChat(Client, MSG_ROBOT_UPGRADE_MAX);
		MenuFunc_RobotWorkShop(Client);
	}
}
/* 赌场 */
public Action:Menu_Casino(Client,args)
{
	MenuFunc_Casino(Client);
	return Plugin_Handled;
}

/* 大乐透 */
public MenuFunc_Casino(Client)
{
	decl String:info[64], String:line[128], Handle:menu, Float:DLT_lasttime;
	menu = CreateMenu(MenuHandler_Casino);
	if (DLT_Timer <= 60.0)
		DLT_lasttime = DLT_Timer, Format(info, sizeof(info), "秒");
	else
		DLT_lasttime = DLT_Timer / 60.0, Format(info, sizeof(info), "分钟");

	if (DLTNum[Client] > 0)
		Format(line, sizeof(line), "*********** \n还有 %.0f %s开奖 \n*********** \n你的金钱: %d $ \n你已购买[%d]开奖号码:", DLT_lasttime, info, Cash[Client], DLTNum[Client]);
	else
		Format(line, sizeof(line), "*********** \n还有 %.0f %s开奖 \n*********** \n你的金钱: %d $ \n你暂未购买开奖号码:", DLT_lasttime, info, Cash[Client]);

	SetMenuTitle(menu, line);

	for (new i = 1; i <= DLT_MaxNum; i++)
	{
		Format(info, sizeof(info), "item%d", i);
		Format(line, sizeof(line), "选择号码:[%d](价格:%d$)", i, DLTCash[i - 1]);
		if (DLTNum[Client] > 0)
			AddMenuItem(menu, info, line, ITEMDRAW_DISABLED);
		else
			AddMenuItem(menu, info, line);
	}


	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}
public MenuHandler_Casino(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)
	{
		if (itemNum >= 0)
		{
			if(Cash[Client] >= DLTCash[itemNum])
			{
				Cash[Client] -= DLTCash[itemNum];
				DLTNum[Client] = itemNum + 1;
				PrintHintText(Client, "你已经成功购买大乐透,号码是:[%d],祝你中奖!", DLTNum[Client]);
				CPrintToChatAll("\x05[大乐透]\x03 \x05%N {red}花费\x05%d${red}在大乐透中购买了\x05[%d]{red}号码,祝他能中奖吧!", Client, DLTCash[itemNum], DLTNum[Client]);
			}
			else
				PrintHintText(Client, "你没有足够的金钱购买大乐透!");
		}

		MenuFunc_Casino(Client);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

/* 大乐透_查看 */
public MenuFunc_DaLeTouView(Client)
{
	decl String:line[128], Handle:menu, has;
	has = 0;
	menu = CreateMenu(MenuHandler_Casino);
	SetMenuTitle(menu, "查看本期已买号码和玩家:");

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i, false))
		{
			if (DLTNum[i] > 0)
			{
				has++;
				Format(line, sizeof(line), "买家:%N 号码:[%d]", i, DLTNum[i]);
				AddMenuItem(menu, "item", line, ITEMDRAW_DISABLED);
			}
		}
	}

	if (has <= 0)
		AddMenuItem(menu, "item", "本期还未有玩家购买大乐透!", ITEMDRAW_DISABLED);

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}
public MenuHandler_DaLeTouView(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack)
			MenuFunc_LotteryCasino(Client);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

/* 大乐透_刷新 */
stock DaLeTou_Refresh(bool:timer = true)
{
	for (new i = 1; i <= MaxClients; i++)
		DLTNum[i] = 0;

	for (new u = 1; u <= DLT_MaxNum; u++)
		DLTCash[u - 1] = GetRandomInt(1000, 5000);

	DLT_Timer = 600.0;

	if (timer && DLT_Handle == INVALID_HANDLE)
		DLT_Handle = CreateTimer(1.0, DaLeTou_Timer, _, TIMER_REPEAT);
	else
	{
		KillTimer(DLT_Handle);
		DLT_Handle = INVALID_HANDLE;
		DLT_Handle = CreateTimer(1.0, DaLeTou_Timer, _, TIMER_REPEAT);
	}
}

/* 大乐透_计时 */
public Action:DaLeTou_Timer(Handle:timer)
{
	DLT_Timer -= 1.0;
	if (DLT_Timer <= 10.0)
		CPrintToChatAll("{red}[大乐透]\x03即将开奖!开始倒计时,剩余 \x05%.0f \x03秒.", DLT_Timer);

	if (DLT_Timer <= 0)
	{
		DaLeTou_Lottery();
		DLT_Handle = INVALID_HANDLE;
		KillTimer(timer);
	}
}

/* 大乐透_开奖 */
public DaLeTou_Lottery()
{
	decl lucknum, luckcash, Float:randomint, Handle:luckhandle, String:s_type[16], String:infomsg[128];

	luckhandle = CreateArray();
	lucknum = GetRandomInt(1, DLT_MaxNum);
	randomint = GetRandomFloat(0.0, 100.0);
	if (randomint < 0.05)
		luckcash = GetRandomInt(30000, 70000), Format(s_type, sizeof(s_type), "终极巨奖");
	else if (randomint < 5.0)
		luckcash = GetRandomInt(20000, 50000), Format(s_type, sizeof(s_type), "惊天大奖");
	else if (randomint < 50.0)
		luckcash = GetRandomInt(10000, 30000), Format(s_type, sizeof(s_type), "特殊奖");
	else if (randomint < 80.0)
		luckcash = GetRandomInt(6000, 12000), Format(s_type, sizeof(s_type), "普通奖");
	else if (randomint < 100.0)
		luckcash = GetRandomInt(1000, 5000), Format(s_type, sizeof(s_type), "安慰奖");

	for(new i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i, false))
		{
			if (DLTNum[i] == lucknum)
				PushArrayCell(luckhandle, i);

		}
	}

	if (GetArraySize(luckhandle) > 0)
	{
		if (GetArraySize(luckhandle) > 1)
		{
			luckcash = luckcash / GetArraySize(luckhandle);
			for (new i; i < GetArraySize(luckhandle); i++)
			{
				Format(infomsg, sizeof(infomsg), " %s %N", infomsg, GetArrayCell(luckhandle, i));
				Cash[i] += luckcash;
			}

			CPrintToChatAll("{red}[大乐透]\x03本期中奖的号码是: \x05[%d] \x03号, 类型:\x05%s\x03 , 获奖者分别是: \x05%s\x03 , 奖励金额平分后是: \x05%d", lucknum, s_type, infomsg, luckcash);
		}
		else
		{
			Format(infomsg, sizeof(infomsg), " %N", GetArrayCell(luckhandle, 0));
			Cash[GetArrayCell(luckhandle, 0)] += luckcash;
			CPrintToChatAll("{red}[大乐透]\x03本期中奖的号码是: \x05[%d] \x03号, 类型:\x05%s\x03 , 获奖者是: \x05%s\x03 , 奖励金额是: \x05%d", lucknum, s_type, infomsg, luckcash);
		}
	}
	else
		CPrintToChatAll("{red}[大乐透]\x03本期中奖的号码是: \x05[%d] \x03号, 类型: \x05%s\x03 , 本期没有中奖玩家!", lucknum, s_type);

	DaLeTou_Refresh();
}

public Action:MenuFunc_Lottery(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "金钱:%d$ 彩票卷:%d个", Cash[Client], Lottery[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "购买($%d)", GetConVarInt(LotteryCost));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "回收(%d税)", RoundToNearest(GetConVarInt(LotteryCost)*(1-GetConVarFloat(LotteryRecycle))));
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "使用(剩余%d个)", Lottery[Client]);
	DrawPanelItem(menu, line);

	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Lottery, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}

public MenuHandler_Lottery(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)
	{
		new itemcost = GetConVarInt(LotteryCost);
		switch (itemNum)
		{
			case 1:
			{
				if(Cash[Client] >= itemcost)
				{
					Lottery[Client]++, Cash[Client] -= itemcost;
					CPrintToChat(Client, MSG_BUYSUCC, itemcost, Cash[Client]);
				}
				else CPrintToChat(Client, MSG_BUYFAIL, itemcost, Cash[Client]);
			}
			case 2:
			{
				new tax = RoundToNearest(itemcost*(1-GetConVarFloat(LotteryRecycle)));
				if(Lottery[Client]>0)
				{
					Lottery[Client]--, Cash[Client] += itemcost-tax;
					CPrintToChat(Client, MSG_RecycleSUCC, itemcost-tax, tax, Cash[Client]);
				}
				else PrintHintText(Client, "你身上没有彩票卷哦~");
			}
			case 3: UseLotteryFunc(Client);
			case 4: MenuFunc_LotteryCasino(Client);
		}
		MenuFunc_Lottery(Client);
	}
}
/* 彩票卷 */
public Action:UseLottery(Client, args)
{
	UseLotteryFunc(Client);
	return Plugin_Handled;
}

public Action:UseLotteryFunc(Client)
{
	if(GetConVarInt(LotteryEnable)!=1)
	{
		CPrintToChat(Client, "{green}对不起! {blue}服务器没有开启彩票功能!");
		return Plugin_Handled;
	}

	if(LotteryTimerHandle[Client] != INVALID_HANDLE)
	{
		CPrintToChat(Client, "\x05对不起! {red}你使用彩票太频繁了，过一会再使用吧!");
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, "\x05对不起! {red}死亡状态下无法使用彩票功能!");
		return Plugin_Handled;
	}

	if(AdminDiceNum[Client]>0 || Lottery[Client]>0)
	{
		Lottery[Client]--;
		new diceNum;
		if(AdminDiceNum[Client]>0) diceNum = AdminDiceNum[Client];
		else diceNum = GetRandomInt(diceNumMin, diceNumMax);

		switch (diceNum)
		{
			case 1: //给予战术散弹枪
			{
				new Num = GetRandomInt(1, 5);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "autoshotgun");
				CPrintToChatAll("{green}[彩票] %s 获得{green}%d{default}把战术散弹枪!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 获得%d把战术散弹枪!", NameInfo(Client, simple), Num);
			}
			case 2: //冰冻玩家
			{
				new Float:duration = GetRandomFloat(10.0, 30.0);
				new Float:freezepos[3];
				GetEntPropVector(Client, Prop_Send, "m_vecOrigin", freezepos);
				FreezePlayer(Client, freezepos, duration);
				CPrintToChatAll("{green}[彩票] %s 被冰冻{green}%.1f{default}秒!", NameInfo(Client, colored), duration);
				//PrintToserver("[彩票] %s 被冰冻%d秒!", NameInfo(Client, simple), duration);
			}
			case 3: //给予M16
			{
				new Num = GetRandomInt(1, 5);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "rifle");
				CPrintToChatAll("{green}[彩票] {default}M16-猥琐者的专用, 恭喜 %s 获得{green}%d{default}把!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] M16-猥琐者的专用, 恭喜 %s 获得%d把!", NameInfo(Client, simple), Num);
			}
			case 4: //给予土制炸弹
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "pipe_bomb");
				CPrintToChatAll("{green}[彩票] %s 获得{green}%d{default}个手雷!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 获得%d个手雷!", NameInfo(Client, simple), Num);
			}
			case 5: // 给予药丸
			{
				for(new i=1; i<=MaxClients; i++)
				{
					if(!IsClientInGame(i)) continue;
					if(GetClientTeam(i)==2 && IsPlayerAlive(i))
						CheatCommand(i, "give", "pain_pills");
				}
				CPrintToChatAll("{green}[彩票] {default}所有人获得药丸, 如果你已随身携带请留心脚下寻找!");
				//PrintToserver("[彩票] 所有人获得药丸, 如果你已随身携带请留心脚下寻找!");
			}
			case 6: // 获得生命
			{
				CheatCommand(Client, "give", "health");
				CPrintToChatAll("{green}[彩票] %s 恢复全满生命!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 恢复全满生命!", NameInfo(Client, simple));
			}
			case 7: // 中毒
			{
				new Float:duration = GetRandomFloat(5.0, 10.0);
				ServerCommand("sm_drug \"%N\" \"1\"", Client);
				CPrintToChatAll("{green}[彩票] %s 乱吃东西而中毒, 将拉肚子{green}%.2f{default}秒", NameInfo(Client, colored), duration);
				//PrintToserver("[彩票] %s 乱吃东西而中毒, %.2f秒", NameInfo(Client, simple), duration);
				CreateTimer(duration, RestoreSick, Client, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 8: // 给予狙击
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "hunting_rifle");
				CPrintToChatAll("{green}[彩票] {default}狙击是一门艺术 - 谁也无法阻挡 %s 追求艺术的脚步! 获得{green}%d{default}把猎枪!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] 狙击是一门艺术 - 谁也无法阻挡 %s 追求艺术的脚步! 获得%d把猎枪!", NameInfo(Client, simple), Num);
			}
			case 9: // 变药包
			{
				SetEntityModel(Client, "models/w_models/weapons/w_eq_medkit.mdl");
				CPrintToChatAll("{green}[彩票] %s 被变成药包了!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 被变成药包了!", NameInfo(Client, simple));
			}
			case 10: // TANK
			{
				CheatCommand(Client, "z_spawn", "tank auto");
				CPrintToChatAll("{green}[彩票] %s 在墙角画圈圈, 结果一不小心把{green}Tank{default}召唤了出来!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 在墙角画圈圈, 结果一不小心把Tank召唤了出来!", NameInfo(Client, simple));
			}
			case 11: // Witch
			{
				new Num = GetRandomInt(1, 10);
				for(new x=1; x<=Num; x++)
					CheatCommand(Client, "z_spawn", "witch auto");
				CPrintToChatAll("{green}[彩票] %s 召唤了他的{green}%d{default}个爱妃{green}Witch{default}!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 召唤了他的%d个爱妃Witch!", NameInfo(Client, simple), Num);
			}
			case 12: // 召唤僵尸
			{
				CheatCommand(Client, "director_force_panic_event", "");
				CPrintToChatAll("{green}[彩票] %s 这位大帅哥, 为大家引来了一群丧尸!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 这位大帅哥, 为大家引来了一群丧尸!", NameInfo(Client, simple));
			}
			case 13: // 萤光
			{
				IsGlowClient[Client] = true;
				PerformGlow(Client, 3, 0, 70, 70, 255);
				CPrintToChatAll("{green}[彩票] %s 的身上发出了萤光!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 的身上发出了萤光!", NameInfo(Client, simple));
			}
			case 14: //给予燃烧炸弹
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "molotov");
				CPrintToChatAll("{green}[彩票] %s 获得{green}%d{default}个燃烧瓶!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 获得%d个燃烧瓶!", NameInfo(Client, simple), Num);
			}
			case 15: //给予氧气瓶
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "oxygentank");
				CPrintToChatAll("{green}[彩票] %s 获得{green}%d{default}个氧气樽!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 获得%d个氧气樽!", NameInfo(Client, simple), Num);
			}
			case 16: //给予煤气罐
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "propanetank");
				CPrintToChatAll("{green}[彩票] %s 获得{green}%d{default}个煤气罐!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 获得%d个煤气罐!", NameInfo(Client, simple), Num);
			}
			case 17: //给予油桶
			{
				new Num = GetRandomInt(1, 10);
				for(new i=1; i<=Num; i++)
					CheatCommand(Client, "give", "gascan");
				CPrintToChatAll("{green}[彩票] %s 获得{green}%d{default}个油桶!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 获得%d个油桶!", NameInfo(Client, simple), Num);
			}
			case 18: //给予药包
			{
				CheatCommand(Client, "give", "first_aid_kit");
				CPrintToChatAll("{green}[彩票] %s 获得一个药包!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 获得一个药包!", NameInfo(Client, simple));
			}
			case 19: // 炎神装填
			{
				if(GetConVarInt(FindConVar("sv_infinite_ammo")) == 1)
				{
					//LotteryEventDuration[0] = 0;
					SetConVarInt(FindConVar("sv_infinite_ammo"), 0);
					CPrintToChatAll("{green}[彩票] %s 发现子弹库内余下子弹是BB弹, 无限子弹提前结束了, 全体感谢他吧...", NameInfo(Client, colored));
					//PrintToserver("[彩票] %s发现子弹库内余下子弹是BB弹, 无限子弹提前结束了, 全体感谢他吧...", NameInfo(Client, simple));
				}
				else
				{
					new duration = GetRandomInt(10, 30);
					//LotteryEventDuration[0] = duration;
					SetConVarInt(FindConVar("sv_infinite_ammo"), 1);
					CreateTimer(float(duration), LotteryInfiniteAmmo);
					CPrintToChatAll("{green}[彩票] %s 发现子弹库, 全体无限子弹{green}%d{default}秒, 大家感激他吧!", NameInfo(Client, colored), duration);
					//PrintToserver("[彩票] %s发现子弹库, 全体无限子弹%d秒, 大家感激他吧!", NameInfo(Client, simple), duration);
				}
			}
			case 20: // 黑屏
			{
				PerformFade(Client, 150);
				new Float:duration = GetRandomFloat(5.0, 10.0);
				CPrintToChatAll("{green}[彩票] %s 视力减弱{green}%.2f{default}秒", NameInfo(Client, colored), duration);
				//PrintToserver("[彩票] %s视力减弱{green}%.2f{default}秒", NameInfo(Client, simple), duration);
				CreateTimer(duration, RestoreFade, Client);
			}
			case 21: // 死亡召唤僵尸
			{
				if(GetClientTeam(Client)==2 && IsPlayerIncapped(Client))
				{
					CheatCommand(Client, "director_force_panic_event", "");
					CPrintToChatAll("{green}[彩票] {default}倒下的 %s 因无人救他, 对生还者表示仇视, 大叫而引发尸群攻击!", NameInfo(Client, colored));
					//PrintToserver("[彩票] 倒下的 %s 因无人救他, 对生还者表示仇视, 大叫而引发尸群攻击!", NameInfo(Client, simple));
				}
				else
				{
					CPrintToChatAll("{green}[彩票] {default}倒下的 %s 使用了彩票, 结果什么事情都没有发生!", NameInfo(Client, colored));
					//PrintToserver("[彩票] 倒下的 %s 使用了彩票, 结果什么事情都没有发生!", NameInfo(Client, simple));
				}
			}
			case 22: // 普感生命值改变
			{
				new value = GetRandomInt(1, 10);
				new mode = GetRandomInt(0, 1);
				if(mode == 0)
				{
					new duration = GetRandomInt(20, 40);
					//LotteryEventDuration[1] = duration;
					SetConVarInt(FindConVar("z_health"), oldCommonHp*value);
					if(LotteryWeakenCommonsHpTimer != INVALID_HANDLE)
					{
						KillTimer(LotteryWeakenCommonsHpTimer);
						LotteryWeakenCommonsHpTimer = INVALID_HANDLE;
					}
					LotteryWeakenCommonsHpTimer = CreateTimer(float(duration), LotteryWeakenCommonsHp);
					CPrintToChatAll("{green}[彩票] %s 因强奸了一只普感而引发丧尸们的愤怒, 在{green}%d{default}秒内普感生命值加强{green}%d{default}倍!", NameInfo(Client, colored), duration, value);
					//PrintToserver("[彩票] %s 因强奸了一只普感而引发丧尸们的愤怒, 在%d秒普感生命值加强%d倍!", NameInfo(Client, simple), duration, value);
				}
				else
				{
					new duration = GetRandomInt(20, 40);
					//LotteryEventDuration[1] = duration;
					SetConVarInt(FindConVar("z_health"), oldCommonHp/value);
					if(LotteryWeakenCommonsHpTimer != INVALID_HANDLE)
					{
						KillTimer(LotteryWeakenCommonsHpTimer);
						LotteryWeakenCommonsHpTimer = INVALID_HANDLE;
					}
					LotteryWeakenCommonsHpTimer = CreateTimer(float(duration), LotteryWeakenCommonsHp);
					CPrintToChatAll("{green}[彩票] {blue}丧尸们对 %s 动了点怜悯之心, 在{green}%d{default}秒内普感生命值减弱{green}%d{default}倍!", NameInfo(Client, colored), duration, value);
					//PrintToserver("[彩票] 丧尸们对 %s 动了点怜悯之心, 在%d秒内普感生命值减弱%d倍!", NameInfo(Client, simple), duration, value);
				}
			}
			case 23: // 无敌事件
			{
				if(GetConVarInt(FindConVar("god"))==1)
				{
					//LotteryEventDuration[2] = 0;
					SetConVarInt(FindConVar("god"), 0, true, false);
					CPrintToChatAll("{green}[彩票] %s 发现原来无敌药过期了, 无敌效果提前结束了!", NameInfo(Client, colored));
					//PrintToserver("[彩票] %s 发现原来无敌药过期了, 无敌效果提前结束了!", NameInfo(Client, simple));
				}
				else
				{
					new duration = GetRandomInt(10, 20);
					//LotteryEventDuration[2] = duration;
					SetConVarInt(FindConVar("god"), 1, true, false);
					CreateTimer(float(duration), LotteryGodMode);
					CPrintToChatAll("{green}[彩票] %s 发现了一堆生物专家留下的无敌药，使大家能无敌{green}%d{default}秒, 请尽快裸奔!", NameInfo(Client, colored), duration);
					//PrintToserver("[彩票] %s 发现了一堆生物专家留下的无敌药，使大家能无敌%d秒, 请尽快裸奔!", NameInfo(Client, simple), duration);
				}
			}
			case 24: // 获得很多手雷
			{
				new Num = GetRandomInt(3, 30);
				for(new x=1; x<=Num; x++)
				{
					CheatCommand(Client, "give", "pipe_bomb");
					CheatCommand(Client, "give", "vomitjar");
					CheatCommand(Client, "give", "molotov");
				}
				CPrintToChatAll("{green}[彩票] %s 在军火库发现一堆投掷品!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 在军火库发现一堆投掷品!", NameInfo(Client, simple));
			}
			case 25: // 召唤Hunter
			{
				new Num = GetRandomInt(6, 10);
				for(new x=1; x<=Num; x++)
					CheatCommand(Client, "z_spawn", "hunter");
				CPrintToChatAll("{green}[彩票] %s 射中了Hunter巢穴而引来一堆{green}Hunter{default}!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 射中了Hunter巢穴而引来一堆Hunter!", NameInfo(Client, simple));
			}
			case 26: // 玩家加速
			{
				new Float:value = GetRandomFloat(1.1, 1.8);
				SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", GetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue")*value);
				CPrintToChatAll("{green}[彩票] %s 在鞋店找到了暴走鞋, 现在跑得很快!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 在鞋店找到了暴走鞋, 现在跑得很快!", NameInfo(Client, simple));
			}
			case 27: // 玩家重力
			{
				new Float:value = GetRandomFloat(0.1, 0.5);
				SetEntityGravity(Client, GetEntityGravity(Client)*value);
				CPrintToChatAll("{green}[彩票] %s 周围的重力变小了!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 周围的重力变小了!", NameInfo(Client, simple));
			}
			case 28: // 变成透明的
			{
				IsGlowClient[Client] = true;
				PerformGlow(Client, 3, 0, 1);
				SetEntityRenderMode(Client, RenderMode:3);
				SetEntityRenderColor(Client, 0, 0, 0, 0);
				CPrintToChatAll("{green}[彩票] %s 变成透明的了,大家小心不要误伤啊!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 变成透明的了,大家小心不要误伤啊!", NameInfo(Client, simple));
			}
			case 29: // 变成TANK
			{
				SetEntityModel(Client, "models/infected/hulk.mdl");
				CPrintToChatAll("{green}[彩票] %s 在墙角画圈圈, 结果一不小心把自已变成了{green}Tank{default}!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 在墙角画圈圈, 结果一不小心把自已变成了Tank!", NameInfo(Client, simple));
			}
			case 30: // 变成蓝色
			{
				SetEntityRenderMode(Client, RenderMode:3);
				SetEntityRenderColor(Client, 255, 0, 0, 150);
				CPrintToChatAll("{green}[彩票] %s 被油漆溅中了!", NameInfo(Client, colored));
				//PrintToserver("[彩票] %s 被油漆溅中了!", NameInfo(Client, simple));
			}
			case 31: // 赏钱
			{
				new Num = GetRandomInt(1, 20000);
				Cash[Client] += Num;
				CPrintToChatAll("{green}[彩票] %s 在地上拾到了${green}%d{default}!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 在地上拾到了$%d!", NameInfo(Client, simple), Num);
			}
			case 32: // 扣钱
			{
				new Num = GetRandomInt(1, 10000);
				Cash[Client] -= Num;
				CPrintToChatAll("{green}[彩票] %s 投资失败, 蚀了${green}%d{default}!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 投资失败, 蚀了$%d!", NameInfo(Client, simple), Num);
			}
			case 33: // 赏彩票
			{
				new Num = GetRandomInt(1, 5);
				Lottery[Client] += Num;
				CPrintToChatAll("{green}[彩票] %s 获得额外{green}%d{default}张彩票!", NameInfo(Client, colored), Num);
				//PrintToserver("[彩票] %s 获得额外%d彩票!", NameInfo(Client, simple), Num);
			}
		}
		AdminDiceNum[Client] = -1;
		LotteryTimerHandle[Client] = CreateTimer(15.0, LotteryTimerFunc, Client);
	}
	else PrintHintText(Client, "你身上没有彩票卷!");
	return Plugin_Handled;
}


public Action:LotteryTimerFunc(Handle:Timer, any:Client)
{
	KillTimer(Timer);
	LotteryTimerHandle[Client] = INVALID_HANDLE;
	if(IsValidPlayer(Client))
	{
		CPrintToChat(Client, "彩票可以使用了！");
	}
	return Plugin_Handled;
}

//解除冰冻
public Action:ResetFreeze(Handle:timer, any:Client)
{
	ServerCommand("sm_freeze \"%N\"", Client);
	return Plugin_Handled;
}

//解除毒药
public Action:RestoreSick(Handle:timer, any: Client)
{
	ServerCommand("sm_drug \"%N\"", Client);
	return Plugin_Handled;
}
public Action:RestoreFade(Handle:timer, any: Client)
{
	PerformFade(Client, 0);
	return Plugin_Handled;
}
public Action:LotteryInfiniteAmmo(Handle:timer)
{
	if(GetConVarInt(FindConVar("sv_infinite_ammo")) == 1)
	{
		SetConVarInt(FindConVar("sv_infinite_ammo"), 0);
		CPrintToChatAll("\x03[彩票] {blue}无限子弹结束了!");
	}
	return Plugin_Handled;
}
public Action:LotteryWeakenCommonsHp(Handle:timer)
{
	if(GetConVarInt(FindConVar("z_health"))!=oldCommonHp)
	{
		SetConVarInt(FindConVar("z_health"), oldCommonHp);
		CPrintToChatAll("\x03[彩票] {blue}普感生命值回复全满!");
		LotteryWeakenCommonsHpTimer = INVALID_HANDLE;
	}
	return Plugin_Handled;
}
public Action:LotteryGodMode(Handle:timer)
{
	if(GetConVarInt(FindConVar("god"))==1)
	{
		SetConVarInt(FindConVar("god"), 0);
		CPrintToChatAll("\x03[彩票] {blue}无敌门事件结束了!");
	}
	return Plugin_Handled;
}

/* 服务器排名 */
public Action:MenuFunc_Rank(Client)
{
	new Handle:menu = CreatePanel();
	SetPanelTitle(menu, "服务器排名");

	DrawPanelItem(menu, "等级排名");
	DrawPanelItem(menu, "金钱排名");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Rank, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}

new rank_id[MAXPLAYERS+1];
public MenuHandler_Rank(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		rank_id[Client] = param;
		MenuFunc_RankDisplay(Client);
	}
}

public Action:MenuFunc_RankDisplay(Client)
{
	new Handle:menu = CreateMenu(MenuHandler_RankDisplay);
	if(rank_id[Client]==1)
		SetMenuTitle(menu, "你的等级: %d $", Lv[Client]);
	if(rank_id[Client]==2)
		SetMenuTitle(menu, "你的金钱: %d $", Cash[Client]);

	decl String:rankClient[100], String:rankname[100];

	for(new r=0; r<RankNo; r++)
	{
		if( StrEqual(LevelRankClient[r], "未知", false) ||
			StrEqual(CashRankClient[r], "未知", false)) continue;

		if(rank_id[Client]==1)
			Format(rankClient, sizeof(rankClient), "%s(等级:%d)", LevelRankClient[r], LevelRank[r]);
		if(rank_id[Client]==2)
			Format(rankClient, sizeof(rankClient), "%s(金钱:%d)", CashRankClient[r], CashRank[r]);

		Format(rankname, sizeof(rankname), "第%d名", r+1);
		AddMenuItem(menu, rankname, rankClient);
	}

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public MenuHandler_RankDisplay(Handle:menu, MenuAction:action, Client, itemNum)
{
	if (action == MenuAction_Select)
	{
		for(new r=0; r<RankNo; r++)
		{
			if(itemNum == r)
			{
				decl String:Name[256];
				if(rank_id[Client]==1)
					Format(Name, sizeof(Name), "%s", LevelRankClient[r]);
				if(rank_id[Client]==2)
					Format(Name, sizeof(Name), "%s", CashRankClient[r]);

				KvJumpToKey(RPGSave, Name, true);
				new targetLv	= KvGetNum(RPGSave, "LV", 0);
				new targetCash	= KvGetNum(RPGSave, "EXP", 0);
				new targetJob	= KvGetNum(RPGSave, "Job", 0);
				KvGoBack(RPGSave);

				new Handle:Menu_Panel = CreatePanel();
				decl String:job[32];
				decl String:line[256];
				if(targetJob == 0)			Format(job, sizeof(job), "未转职");
				else if(targetJob == 1)	Format(job, sizeof(job), "工程师");
				else if(targetJob == 2)	Format(job, sizeof(job), "士兵");
				else if(targetJob == 3)	Format(job, sizeof(job), "圣骑士");
				else if(targetJob == 4)	Format(job, sizeof(job), "心灵医师");
				else if(targetJob == 5)	Format(job, sizeof(job), "魔法师");
				else if(targetJob == 6)	Format(job, sizeof(job), "弹药师");
				else if(targetJob == 7)	Format(job, sizeof(job), "地狱使者");
				else if(targetJob == 8)	Format(job, sizeof(job), "死神");
				else if(targetJob == 9)	Format(job, sizeof(job), "黑暗行者");
				else if(targetJob == 10)	Format(job, sizeof(job), "死亡祭师");
				else if(targetJob == 11)	Format(job, sizeof(job), "雷电使者");
				else if(targetJob == 12)	Format(job, sizeof(job), "影武者");
				else if(targetJob == 13)	Format(job, sizeof(job), "审判者");
				else if(targetJob == 14)	Format(job, sizeof(job), "毒龙");
				else if(targetJob == 15)	Format(job, sizeof(job), "幻影统帅");
				else if(targetJob == 16)	Format(job, sizeof(job), "复仇者");
				else if(targetJob == 17)	Format(job, sizeof(job), "大祭祀");
				else if(targetJob == 18)	Format(job, sizeof(job), "狂战士");
				else if(targetJob == 19)	Format(job, sizeof(job), "变异坦克");

				if(rank_id[Client]==1)
					Format(line, sizeof(line), "等级排行榜 =TOP%d=", r+1);
				if(rank_id[Client]==2)
					Format(line, sizeof(line), "金钱排行榜 =TOP%d=", r+1);
				DrawPanelText(Menu_Panel, line);

				Format(line, sizeof(line), "玩家名字: %s", Name);
				DrawPanelText(Menu_Panel, line);

				Format(line, sizeof(line), "职业:%s 等级:Lv.%d 现金:%d$\n ", job, targetLv, targetCash);
				DrawPanelText(Menu_Panel, line);

				DrawPanelItem(Menu_Panel, "返回");
				DrawPanelItem(Menu_Panel, "离开", ITEMDRAW_DISABLED);

				SendPanelToClient(Menu_Panel, Client, Handler_GoBack, MENU_TIME_FOREVER);

				CloseHandle(Menu_Panel);
			}
		}
	} else if (action == MenuAction_End) CloseHandle(menu);
}

public Handler_GoBack(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
		MenuFunc_Rank(param1);
}

/* 密码资讯 */
public Action:Passwordinfo(Client, args)
{
	MenuFunc_PasswordInfo(Client);
	return Plugin_Handled;
}
public Action:MenuFunc_PasswordInfo(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();

	if(IsPasswordConfirm[Client])	Format(line, sizeof(line), "密码资讯 密码是否输入: 已正确输入 已设密码: %s", Password[Client]);
	else if(StrEqual(Password[Client], "", true))	Format(line, sizeof(line), "密码资讯 密码状态: 未启动");
	else if(!IsPasswordConfirm[Client])	Format(line, sizeof(line), "密码资讯 密码状态: 未输入");

	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "说明: 启动密码系统后别人便不能用你的名字读取你的记录");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "输入/启动密码指令: /rpgpw 密码 或 /pw 密码");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "重设密码指令: /rpgresetpw 原密码 新密码");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "注1: 密码最大长度为%d", PasswordLength);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "注2: 密码不要用数字0开头, 会被略去");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "注3: 不想每次进入游戏也输入一次密码:\n - 在left4dead2\\cfg\\autoexec.cfg(没发现请自行创建)加入setinfo unitedrpg 密码");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);

	SendPanelToClient(menu, Client, MenuHandler_Passwordinfo, MENU_TIME_FOREVER);

	CloseHandle(menu);

	return Plugin_Handled;
}
public MenuHandler_Passwordinfo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
		MenuFunc_RPG_Other(Client);
}
/* 插件讯息 */
public Action:MenuFunc_RPGInfo(Client)
{
/*
	PrintToChat(Client, "\x05插件有什么BUG/建议欢迎大家提出来");
	PrintToChat(Client, "\x03════════════════════════════════");
	PrintToChat(Client, "\x04          插件作者八楼          ");
	PrintToChat(Client, "\x03════════════════════════════════");
	PrintToChat(Client, "\x05   插件版本为：RPG_3.65版本     ");
	PrintToChat(Client, "\x03════════════════════════════════");
	PrintToChat(Client, "\x04  欢迎来到本服务器，游戏愉快！  ");
	PrintToChat(Client, "\x03════════════════════════════════");
	return Plugin_Handled;
*/
}

/* 提示绑定热键 */
public Action:MenuFunc_BindKeys(Client)
{
	new Handle:Menu_Panel = CreatePanel();
	SetPanelTitle(Menu_Panel, "是否绑定服务器技能等快捷键?");
	DrawPanelText(Menu_Panel, "大键盘B | RPG 菜单");
	DrawPanelText(Menu_Panel, "大键盘N | 玩家面板");
	DrawPanelText(Menu_Panel, "大键盘V | 会员功能");
	DrawPanelText(Menu_Panel, "小键盘- | 打开商店");
	DrawPanelText(Menu_Panel, "小键盘* | 使用技能");
	DrawPanelText(Menu_Panel, "大键盘U | 特殊道具背包");
	DrawPanelItem(Menu_Panel, "是");
	DrawPanelItem(Menu_Panel, "否");
	SendPanelToClient(Menu_Panel, Client, MenuHandler_BindKeys, MENU_TIME_FOREVER);
	CloseHandle(Menu_Panel);
	return Plugin_Handled;
}
public MenuHandler_BindKeys(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		switch (param)
		{
			case 1: BindMsg(Client), BindKeyFunction(Client);
			case 2: return;
		}
	}
}
public Action:BindMsg(Client)
{
	PrintToChat(Client, MSG_BIND_1);
	PrintToChat(Client, MSG_BIND_2);
	PrintToChat(Client, MSG_BIND_3);
	PrintToChat(Client, MSG_BIND_GENERAL);

	if(JD[Client] == 1)
		PrintToChat(Client, MSG_BIND_JOB1);
	else if(JD[Client] == 2)
		PrintToChat(Client, MSG_BIND_JOB2);
	else if(JD[Client] == 3)
		PrintToChat(Client, MSG_BIND_JOB3);
	else if(JD[Client] == 4)
		PrintToChat(Client, MSG_BIND_JOB4), PrintToChat(Client, MSG_BIND_JOB4_1);
	else if(JD[Client] == 5)
		PrintToChat(Client, MSG_BIND_JOB5);
	else if(JD[Client] == 6)
		PrintToChat(Client, MSG_BIND_JOB6), PrintToChat(Client, MSG_BIND_JOB6_1);
	else if(JD[Client] == 7)
		PrintToChat(Client, MSG_BIND_JOB7);
	else if(JD[Client] == 8)
		PrintToChat(Client, MSG_BIND_JOB8);
	else if(JD[Client] == 9)
		PrintToChat(Client, MSG_BIND_JOB9);
	else if(JD[Client] == 10)
		PrintToChat(Client, MSG_BIND_JOB10);
	else if(JD[Client] == 11)
		PrintToChat(Client, MSG_BIND_JOB11);
	else if(JD[Client] == 12)
		PrintToChat(Client, MSG_BIND_JOB12);
	else if(JD[Client] == 13)
		PrintToChat(Client, MSG_BIND_JOB13);
	else if(JD[Client] == 14)
		PrintToChat(Client, MSG_BIND_JOB14);

	return Plugin_Handled;
}
public Action:BindKeyFunction(Client)
{

	ClientCommand(Client, "bind n say /wanjia");
	ClientCommand(Client, "bind b say /rpg");
	ClientCommand(Client, "bind KP_MINUS say /buymenu");
	ClientCommand(Client, "bind KP_MULTIPLY say /useskill");
	ClientCommand(Client, "bind KP_SLASH say /teaminfo");
	ClientCommand(Client, "bind O say /vipfree"); //免费补给快捷键
	ClientCommand(Client, "bind p say /vipvote");	//会员投票快捷键
	ClientCommand(Client, "bind l say /mybag");	//我的背包
	ClientCommand(Client, "bind k say /myitem");	//我的道具
	ClientCommand(Client, "bind f12 say /isave");	//手动存档
	ClientCommand(Client, "bind m say /viewskill");	//技能属性
	ClientCommand(Client, "bind u say /tsdj");	//特殊道具背包
	ClientCommand(Client, "bind KP_LEFTARROW say /hl");
	ClientCommand(Client, "bind KP_5 say /dizhen");
	ClientCommand(Client, "bind KP_RIGHTARROW say /is");
	ClientCommand(Client, "bind KP_ENTER say /si");

	if(JD[Client] == 1)
	{
		ClientCommand(Client, "bind KP_HOME say /am");
		ClientCommand(Client, "bind KP_UPARROW say /sc");
		ClientCommand(Client, "bind KP_PGDN say /mogu");
	}
	else if(JD[Client] == 2)
	{
		ClientCommand(Client, "bind KP_HOME say /sp");
		ClientCommand(Client, "bind KP_UPARROW say /ia");
		ClientCommand(Client, "bind KP_PGDN say /kbz");
	}
	else if(JD[Client] == 3)
	{
		ClientCommand(Client, "bind KP_HOME say /bs");
		ClientCommand(Client, "bind KP_UPARROW say /dr");
		ClientCommand(Client, "bind KP_PGUP say /ms");
		ClientCommand(Client, "bind KP_PGDN say /baofa");
	}
	else if(JD[Client] == 4)
	{
		ClientCommand(Client, "bind KP_HOME say /ts");
		ClientCommand(Client, "bind KP_UPARROW say /at");
		ClientCommand(Client, "bind KP_PGUP say /tt");
		ClientCommand(Client, "bind KP_END say /hb");
	}
	else if(JD[Client] == 5)
	{
		ClientCommand(Client, "bind KP_HOME say /fb");
		ClientCommand(Client, "bind KP_UPARROW say /ib");
		ClientCommand(Client, "bind KP_PGUP say /cl");
		ClientCommand(Client, "bind KP_PGDN say /baolei");
	}
	else if(JD[Client] == 6)
	{
		ClientCommand(Client, "bind KP_HOME say /psd");
		ClientCommand(Client, "bind KP_UPARROW say /sdd");
		ClientCommand(Client, "bind KP_PGUP say /xxd");
		ClientCommand(Client, "bind KP_END say /qybp");
		ClientCommand(Client, "bind KP_PGDN say /lsjgp");
	}
	else if(JD[Client] == 7)
	{
		ClientCommand(Client, "bind KP_END say /sply");
	}
	else if(JD[Client] == 8)
	{
		ClientCommand(Client, "bind KP_ENDsay /dyzh");
	}
	else if(JD[Client] == 9)
	{
		ClientCommand(Client, "bind KP_ENDsay /zd");
		ClientCommand(Client, "bind KP_PGDNsay /cdz");
	}
	else if(JD[Client] == 10)
	{
		ClientCommand(Client, "bind KP_ENDsay /bs");
		ClientCommand(Client, "bind KP_PGDNsay /wx");
	}
	else if(JD[Client] == 11)
	{
		ClientCommand(Client, "bind KP_ENDsay /dz");
		ClientCommand(Client, "bind KP_PGDNsay /gs");
		ClientCommand(Client, "bind KP_PGUP say /yl");
		ClientCommand(Client, "bind KP_HOME say /lzd");
	}
	else if(JD[Client] == 12)
	{
		ClientCommand(Client, "bind KP_ENDsay /xbfb");
		ClientCommand(Client, "bind KP_PGDNsay /nq");
	}
	else if(JD[Client] == 13)
	{
		ClientCommand(Client, "bind KP_ENDsay /hm");
		ClientCommand(Client, "bind KP_PGDNsay /sap");
	}
	else if(JD[Client] == 14)
	{
		ClientCommand(Client, "bind KP_ENDsay /sx");
		ClientCommand(Client, "bind KP_PGDNsay /sh");
		ClientCommand(Client, "bind KP_PGUP say /ds");
	}
	else if(JD[Client] == 15)
	{
		ClientCommand(Client, "bind KP_ENDsay /phf");
		ClientCommand(Client, "bind KP_PGDNsay /pha");
		ClientCommand(Client, "bind KP_PGUP say /phz");
		ClientCommand(Client, "bind KP_PGUP say /phs");
	}
}


//地震术震动效果
public Shake_Screen(Client, Float:Amplitude, Float:Duration, Float:Frequency)
{
	new Handle:Bfw;

	Bfw = StartMessageOne("Shake", Client, 1);
	BfWriteByte(Bfw, 0);
	BfWriteFloat(Bfw, Amplitude);
	BfWriteFloat(Bfw, Duration);
	BfWriteFloat(Bfw, Frequency);

	EndMessage();
}
SetWeaponSpeed()
{
	decl ent;

	for(new i = 0; i < WRQL; i++)
	{
		ent = WRQ[i];
		if(IsValidEdict(ent))
		{
			decl String:entclass[65];
			GetEdictClassname(ent, entclass, sizeof(entclass));
			if(StrContains(entclass, "weapon")>=0 && !StrEqual(entclass, "weapon_grenade_launcher"))
			{
				new Float:MAS = 1.0 + Multi[i];
				SetEntPropFloat(ent, Prop_Send, "m_flPlaybackRate", MAS);
				new Float:ETime = GetGameTime();
				new Float:time = (GetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack") - ETime)/MAS;
				SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", time + ETime);
				time = (GetEntPropFloat(ent, Prop_Send, "m_flNextSecondaryAttack") - ETime)/MAS;
				SetEntPropFloat(ent, Prop_Send, "m_flNextSecondaryAttack", time + ETime);
				CreateTimer(time, NormalWeapSpeed, ent);
			}
		}
	}
}
public Action:NormalWeapSpeed(Handle:timer, any:ent)
{
	KillTimer(timer);
	timer = INVALID_HANDLE;

	if(IsValidEdict(ent))
	{
		decl String:entclass[65];
		GetEdictClassname(ent, entclass, sizeof(entclass));
		if(StrContains(entclass, "weapon")>=0)
		{
			SetEntPropFloat(ent, Prop_Send, "m_flPlaybackRate", 1.0);
		}
	}
	return Plugin_Handled;
}
public Action:Event_WeaponFire(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new target = GetClientOfUserId(GetEventInt(event, "userid"));

	if(GetClientTeam(target) == 2 && !IsFakeClient(target))
	{
		new ent = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
		if (!IsValidEdict(ent) || !IsValidEntity(ent))
			return Plugin_Continue;
		decl String:entclass[65], bool:skip_weapon;
		GetEdictClassname(ent, entclass, sizeof(entclass));
		skip_weapon = ( StrEqual(entclass, "weapon_pain_pills", false) || StrEqual(entclass, "weapon_adrenaline", false) || StrEqual(entclass, "weapon_chainsaw", false) );

		if(IsMeleeSpeedEnable[target])//近战嗜血
		{
			if(ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee")>=0)
			{
				WRQ[WRQL] = ent;
				Multi[WRQL] = MeleeSpeedEffect[target];
				WRQL++;
			}
		}
		if(IsHYJWEnable[target])//幻影剑舞
		{
			if(ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee")>=0)
			{
				WRQ[WRQL] = ent;
				Multi[WRQL] = HYJWEffect[target];
				WRQL++;
			}
		} 
		else if(FireSpeedLv[target]>0)
		{
			if(ent == GetPlayerWeaponSlot(target, 0) || (ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee")<0))
			{
				WRQ[WRQL] = ent;
				Multi[WRQL] = FireSpeedEffect[target];
				WRQL++;
			}
		} else if(HassLv[target]>0)
		{
			if(ent == GetPlayerWeaponSlot(target, 0) || (ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee")<0))
			{
				WRQ[WRQL] = ent;
				Multi[WRQL] = HassEffect[target];
				WRQL++;
			}
		} else if(IsInfiniteAmmoEnable[target] && !skip_weapon)
		{
			if(ent == GetPlayerWeaponSlot(target, 0) || (ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee")<0))
			{
				if (StrContains(entclass, "grenade_launcher", false) < 0)
					SetEntProp(ent, Prop_Send, "m_iClip1", GetEntProp(ent, Prop_Send, "m_iClip1")+1);
			}
		} else if(IsWXNYEnable[target] && !skip_weapon)
		{
			if(ent == GetPlayerWeaponSlot(target, 0) || (ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee")<0))
			{
				if (StrContains(entclass, "grenade_launcher", false) < 0)
					SetEntProp(ent, Prop_Send, "m_iClip1", GetEntProp(ent, Prop_Send, "m_iClip1")+1);
			}
		}

		if (IsActionWXZDJ && !skip_weapon)
		{
			if(ent == GetPlayerWeaponSlot(target, 0) || (ent == GetPlayerWeaponSlot(target, 1) && StrContains(entclass, "melee") < 0))
			{
				if (StrContains(entclass, "grenade_launcher", false) < 0)
					SetEntProp(ent, Prop_Send, "m_iClip1", GetEntProp(ent, Prop_Send, "m_iClip1")+1);
			}
		}

		if (StrContains(entclass, "grenade_launcher", false) > -1)
			SetEntProp(ent, Prop_Send, "m_iClip1", 1);
	}
	return Plugin_Continue;
}
DelRobot(ent)
{
	if (ent > 0 && IsValidEntity(ent))
    {
		decl String:item[65];
		GetEdictClassname(ent, item, sizeof(item));
		if(StrContains(item, "weapon")>=0)
		{
			RemoveEdict(ent);
		}
    }
}
Release(controller, bool:del=true)
{
	new r=robot[controller];
	new r_clone=robot_clone[controller];
	if(r>0)
	{
		robot[controller]=0;
		robot_clone[controller]=0;
		if(del)
		{
			DelRobot(r);
			DelRobot(r_clone);
		}
	}
	if(robot_gamestart)
	{
		new count=0;
		for (new i = 1; i <= MaxClients; i++)
		{
			if(robot[i]>0)
			{
				count++;
			}
		}
		if(count==0)
		{
			robot_gamestart = false;
			robot_gamestart_clone = false;
		}
	}
}

public Action:sm_robot(Client, const arg)
{
	if(!IsValidPlayer(Client, true, false))
		return Plugin_Continue;

	if(robot[Client]>0)
	{
		PrintHintText(Client, "你已经有一个Robot");
		return Plugin_Handled;
	}
	for(new i=0; i<WEAPONCOUNT; i++)
	{
		if(arg==i)	weapontype[Client]=i;
	}
	AddRobot(Client);
	if(Robot_appendage[Client] > 0)
	{
		AddRobot_clone(Client);
	}
	return Plugin_Handled;
}
//增加机器人
AddRobot(Client)
{
	bullet[Client]=RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]);
	new Float:vAngles[3];
	new Float:vOrigin[3];
	new Float:pos[3];
	GetClientEyePosition(Client,vOrigin);
	GetClientEyeAngles(Client, vAngles);
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID,  RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
	}
	CloseHandle(trace);
	decl Float:v1[3];
	decl Float:v2[3];
	SubtractVectors(vOrigin, pos, v1);
	NormalizeVector(v1, v2);
	ScaleVector(v2, 50.0);
	AddVectors(pos, v2, v1);  // v1 explode taget
	new ent=0;
 	ent=CreateEntityByName(MODEL[weapontype[Client]]);
  	DispatchSpawn(ent);
  	TeleportEntity(ent, v1, NULL_VECTOR, NULL_VECTOR);

	SetEntityMoveType(ent, MOVETYPE_FLY);
	SIenemy[Client]=0;
	CIenemy[Client]=0;
	scantime[Client]=0.0;
	keybuffer[Client]=0;
	bullet[Client]=0;
	reloading[Client]=false;
	reloadtime[Client]=0.0;
	firetime[Client]=0.0;
	robot[Client]=ent;

	for(new i=0; i<WEAPONCOUNT; i++)
	{
		if(weapontype[Client]==i)
		{
			CPrintToChatAll("\x05%N\x03启动了[%s]Robot!", Client, WeaponName[i]);
			//PrintToserver("[United RPG] %s启动了[%s]Robot!", NameInfo(Client, simple), WeaponName[i]);
		}
	}
	robot_gamestart = true;
}


//增加克隆机器人
AddRobot_clone(Client)
{
	bullet_clone[Client]=RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]);
	new Float:vAngles[3];
	new Float:vOrigin[3];
	new Float:pos[3];
	GetClientEyePosition(Client,vOrigin);
	GetClientEyeAngles(Client, vAngles);
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID,  RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
	}
	CloseHandle(trace);
	decl Float:v1[3];
	decl Float:v2[3];
	SubtractVectors(vOrigin, pos, v1);
	NormalizeVector(v1, v2);
	ScaleVector(v2, 80.0);
	AddVectors(pos, v2, v1);  // v1 explode taget
	new ent=0;
 	ent=CreateEntityByName(MODEL[weapontype[Client]]);
  	DispatchSpawn(ent);
  	TeleportEntity(ent, v1, NULL_VECTOR, NULL_VECTOR);

	SetEntityMoveType(ent, MOVETYPE_FLY);
	SIenemy_clone[Client]=0;
	CIenemy_clone[Client]=0;
	scantime_clone[Client]=0.0;
	keybuffer_clone[Client]=0;
	bullet_clone[Client]=0;
	reloading_clone[Client]=false;
	reloadtime_clone[Client]=0.0;
	firetime_clone[Client]=0.0;
	robot_clone[Client]=ent;

	for(new i=0; i<WEAPONCOUNT; i++)
	{
		if(weapontype[Client]==i)
		{
			CPrintToChatAll("\x05%N\x03启动了枪神附体技能,机器人增加一个!", Client);
			//PrintToserver("[United RPG] %s启动了[%s]Robot!", NameInfo(Client, simple), WeaponName[i]);
		}
	}
	robot_gamestart_clone = true;
}

Do_clone(Client, Float:currenttime, Float:duration)
{
	if(robot_clone[Client]>0)
	{
		if (!IsValidEntity(robot_clone[Client]) || !IsValidPlayer(Client, true, false) || IsFakeClient(Client))
		{
			Release(Client);
		}
		else
		{
			if(Robot_appendage[Client] == 0)
			{
				botenerge_clone[Client]+=duration;
				if(botenerge_clone[Client]>robot_energy)
				{
					Release(Client);
					CPrintToChat(Client, "{red}你的Robot已用尽能量了!");
					PrintHintText(Client, "你的Robot已用尽能量了!");
					return;
				}
			}
			button=GetClientButtons(Client);
   		 	GetEntPropVector(robot_clone[Client], Prop_Send, "m_vecOrigin", robotpos_clone);

			if((button & IN_USE) && (button & IN_SPEED) && !(keybuffer[Client] & IN_USE))
			{
				Release(Client);
				CPrintToChatAll("\x05 %N \x03关闭了Robot", Client);
				return;
			}
			if(currenttime - scantime_clone[Client]>robot_reactiontime)
			{
				scantime_clone[Client]=currenttime;
				new ScanedEnemy = ScanEnemy_clone(Client,robotpos_clone);
				if(ScanedEnemy <= MaxClients)
				{
					SIenemy_clone[Client]=ScanedEnemy;
				} else CIenemy_clone[Client]=ScanedEnemy;
			}
			new targetok=false;

			if( CIenemy_clone[Client]>0 && IsCommonInfected(CIenemy_clone[Client]) && GetEntProp(CIenemy_clone[Client], Prop_Data, "m_iHealth")>0)
			{
				GetEntPropVector(CIenemy_clone[Client], Prop_Send, "m_vecOrigin", enemypos);
				enemypos[2]+=40.0;
				SubtractVectors(enemypos, robotpos_clone, robotangle[Client]);
				GetVectorAngles(robotangle[Client],robotangle[Client]);
				targetok=true;
			}
			else
			{
				CIenemy_clone[Client]=0;
			}
			if(!targetok)
			{
				if(SIenemy_clone[Client]>0 && IsClientInGame(SIenemy_clone[Client]) && IsPlayerAlive(SIenemy_clone[Client]))
				{
					GetClientEyePosition(SIenemy_clone[Client], infectedeyepos);
					GetClientAbsOrigin(SIenemy_clone[Client], infectedorigin);
					enemypos[0]=infectedorigin[0]*0.4+infectedeyepos[0]*0.6;
					enemypos[1]=infectedorigin[1]*0.4+infectedeyepos[1]*0.6;
					enemypos[2]=infectedorigin[2]*0.4+infectedeyepos[2]*0.6;

					SubtractVectors(enemypos, robotpos_clone, robotangle[Client]);
					GetVectorAngles(robotangle[Client],robotangle[Client]);
					targetok=true;
				}
				else
				{
					SIenemy_clone[Client]=0;
				}
			}
			if(reloading_clone[Client])
			{
				//CPrintToChatAll("%f", reloadtime[Client]);
				if(bullet_clone[Client]>=RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]) && currenttime-reloadtime_clone[Client]>weaponloadtime[weapontype[Client]])
				{
					reloading_clone[Client]=false;
					reloadtime_clone[Client]=currenttime;
					EmitSoundToAll(SOUNDREADY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos_clone, NULL_VECTOR, false, 0.0);
					//PrintHintText(Client, " ");
				}
				else
				{
					if(currenttime-reloadtime_clone[Client]>weaponloadtime[weapontype[Client]])
					{
						reloadtime_clone[Client]=currenttime;
						bullet_clone[Client]+=RoundToNearest(weaponloadcount[weapontype[Client]]*RobotAmmoEffect[Client]);
						EmitSoundToAll(SOUNDRELOAD, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos_clone, NULL_VECTOR, false, 0.0);
						//PrintHintText(Client, "reloading %d", bullet[Client]);
					}
				}
			}
			if(!reloading_clone[Client])
			{
				if(!targetok)
				{
					if(bullet_clone[Client]<RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]))
					{
						reloading_clone[Client]=true;
						reloadtime_clone[Client]=0.0;
						if(!weaponloaddisrupt[weapontype[Client]])
						{
							bullet_clone[Client]=0;
						}
					}
				}
			}
			chargetime_clone=fireinterval[weapontype[Client]];
			if(!reloading_clone[Client])
			{
				if(currenttime-firetime_clone[Client]>chargetime_clone)
				{

					if( targetok)
					{
						if(bullet_clone[Client]>0)
						{
							bullet_clone[Client]=bullet_clone[Client]-1;

							FireBullet(Client, robot_clone[Client], enemypos, robotpos_clone);

							firetime_clone[Client]=currenttime;
						 	reloading_clone[Client]=false;
						}
						else
						{
							firetime_clone[Client]=currenttime;
						 	EmitSoundToAll(SOUNDCLIPEMPTY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos_clone, NULL_VECTOR, false, 0.0);
							reloading_clone[Client]=true;
							reloadtime_clone[Client]=currenttime;
						}

					}

				}

			}
 			GetClientEyePosition(Client,  Clienteyepos);
			Clienteyepos[2]+=30.0;
			GetClientEyeAngles(Client, Clientangle);
			new Float:distance = GetVectorDistance(robotpos_clone, Clienteyepos);
			if(distance>100.0)
			{
				TeleportEntity(robot_clone[Client], Clienteyepos,  robotangle[Client] ,NULL_VECTOR);
			}
			else if(distance>50.0)
			{

				MakeVectorFromPoints( robotpos_clone, Clienteyepos, robotvec_clone);
				NormalizeVector(robotvec_clone,robotvec_clone);
				ScaleVector(robotvec_clone, 5*distance);
				if (!targetok )
				{
					GetVectorAngles(robotvec_clone, robotangle[Client]);
				}
				TeleportEntity(robot_clone[Client], NULL_VECTOR,  robotangle[Client] ,robotvec_clone);
				walktime_clone[Client]=currenttime;
			}
			else
			{
				robotvec_clone[0]=robotvec_clone[1]=robotvec_clone[2]=0.0;
				if(!targetok && currenttime-firetime_clone[Client]>4.0)robotangle[Client][1]+=5.0;
				TeleportEntity(robot_clone[Client], NULL_VECTOR,  robotangle[Client] ,robotvec_clone);
			}
		 	keybuffer_clone[Client]=button;
		}
	}
	else
	{
		botenerge_clone[Client]=botenerge_clone[Client]-duration*0.5;
		if(botenerge_clone[Client]<0.0)botenerge_clone[Client]=0.0;
	}
}


Do(Client, Float:currenttime, Float:duration)
{
	if(robot[Client]>0)
	{
		if (!IsValidEntity(robot[Client]) || !IsValidPlayer(Client, true, false) || IsFakeClient(Client))
		{
			Release(Client);
		}
		else
		{
			if(Robot_appendage[Client] == 0)
			{
				botenerge[Client]+=duration;
				if(botenerge[Client]>robot_energy)
				{
					Release(Client);
					CPrintToChat(Client, "{red}你的Robot已用尽能量了!");
					PrintHintText(Client, "你的Robot已用尽能量了!");
					return;
				}
			}

			button=GetClientButtons(Client);
   		 	GetEntPropVector(robot[Client], Prop_Send, "m_vecOrigin", robotpos);

			if((button & IN_USE) && (button & IN_SPEED) && !(keybuffer[Client] & IN_USE))
			{
				Release(Client);
				CPrintToChatAll("\x05 %N \x03关闭了Robot", Client);
				return;
			}
			if(currenttime - scantime[Client]>robot_reactiontime)
			{
				scantime[Client]=currenttime;
				new ScanedEnemy = ScanEnemy(Client,robotpos);
				if(ScanedEnemy <= MaxClients)
				{
					SIenemy[Client]=ScanedEnemy;
				} else CIenemy[Client]=ScanedEnemy;
			}
			new targetok=false;

			if( CIenemy[Client]>0 && IsCommonInfected(CIenemy[Client]) && GetEntProp(CIenemy[Client], Prop_Data, "m_iHealth")>0)
			{
				GetEntPropVector(CIenemy[Client], Prop_Send, "m_vecOrigin", enemypos);
				enemypos[2]+=40.0;
				SubtractVectors(enemypos, robotpos, robotangle[Client]);
				GetVectorAngles(robotangle[Client],robotangle[Client]);
				targetok=true;
			}
			else
			{
				CIenemy[Client]=0;
			}
			if(!targetok)
			{
				if(SIenemy[Client]>0 && IsClientInGame(SIenemy[Client]) && IsPlayerAlive(SIenemy[Client]))
				{

					GetClientEyePosition(SIenemy[Client], infectedeyepos);
					GetClientAbsOrigin(SIenemy[Client], infectedorigin);
					enemypos[0]=infectedorigin[0]*0.4+infectedeyepos[0]*0.6;
					enemypos[1]=infectedorigin[1]*0.4+infectedeyepos[1]*0.6;
					enemypos[2]=infectedorigin[2]*0.4+infectedeyepos[2]*0.6;

					SubtractVectors(enemypos, robotpos, robotangle[Client]);
					GetVectorAngles(robotangle[Client],robotangle[Client]);
					targetok=true;
				}
				else
				{
					SIenemy[Client]=0;
				}
			}
			if(reloading[Client])
			{
				//CPrintToChatAll("%f", reloadtime[Client]);
				if(bullet[Client]>=RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]) && currenttime-reloadtime[Client]>weaponloadtime[weapontype[Client]])
				{
					reloading[Client]=false;
					reloadtime[Client]=currenttime;
					EmitSoundToAll(SOUNDREADY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
					//PrintHintText(Client, " ");
				}
				else
				{
					if(currenttime-reloadtime[Client]>weaponloadtime[weapontype[Client]])
					{
						reloadtime[Client]=currenttime;
						bullet[Client]+=RoundToNearest(weaponloadcount[weapontype[Client]]*RobotAmmoEffect[Client]);
						EmitSoundToAll(SOUNDRELOAD, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
						//PrintHintText(Client, "reloading %d", bullet[Client]);
					}
				}
			}
			if(!reloading[Client])
			{
				if(!targetok)
				{
					if(bullet[Client]<RoundToNearest(weaponclipsize[weapontype[Client]]*RobotAmmoEffect[Client]))
					{
						reloading[Client]=true;
						reloadtime[Client]=0.0;
						if(!weaponloaddisrupt[weapontype[Client]])
						{
							bullet[Client]=0;
						}
					}
				}
			}
			chargetime=fireinterval[weapontype[Client]];
			if(!reloading[Client])
			{
				if(currenttime-firetime[Client]>chargetime)
				{

					if( targetok)
					{
						if(bullet[Client]>0)
						{
							bullet[Client]=bullet[Client]-1;

							FireBullet(Client, robot[Client], enemypos, robotpos);

							firetime[Client]=currenttime;
						 	reloading[Client]=false;
						}
						else
						{
							firetime[Client]=currenttime;
						 	EmitSoundToAll(SOUNDCLIPEMPTY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
							reloading[Client]=true;
							reloadtime[Client]=currenttime;
						}

					}

				}

			}
 			GetClientEyePosition(Client,  Clienteyepos);
			Clienteyepos[2]+=20.0;
			GetClientEyeAngles(Client, Clientangle);
			new Float:distance = GetVectorDistance(robotpos, Clienteyepos);
			if(distance>500.0)
			{
				TeleportEntity(robot[Client], Clienteyepos,  robotangle[Client] ,NULL_VECTOR);
			}
			else if(distance>100.0)
			{

				MakeVectorFromPoints( robotpos, Clienteyepos, robotvec);
				NormalizeVector(robotvec,robotvec);
				ScaleVector(robotvec, 5*distance);
				if (!targetok )
				{
					GetVectorAngles(robotvec, robotangle[Client]);
				}
				TeleportEntity(robot[Client], NULL_VECTOR,  robotangle[Client] ,robotvec);
				walktime[Client]=currenttime;
			}
			else
			{
				robotvec[0]=robotvec[1]=robotvec[2]=0.0;
				if(!targetok && currenttime-firetime[Client]>4.0)robotangle[Client][1]+=5.0;
				TeleportEntity(robot[Client], NULL_VECTOR,  robotangle[Client] ,robotvec);
			}
		 	keybuffer[Client]=button;
		}
	}
	else
	{
		botenerge[Client]=botenerge[Client]-duration*0.5;
		if(botenerge[Client]<0.0)botenerge[Client]=0.0;
	}
}
public OnGameFrame()
{
	decl weaponid, Float:currenttime, Float:duration, String:weaponname[32];

	if(WRQL>0)
	{
		SetWeaponSpeed();
		WRQL = 0;
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i, true, false) && GetClientTeam(i) == 2 && ZB_GunSpeed[i] > 0)
		{
			weaponid = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
			if (IsValidEdict(weaponid))
			{
				GetEdictClassname(weaponid, weaponname, sizeof(weaponname));
				if (StrContains(weaponname, "melee", false) < 0)
					SetWeaponAttackSpeed(weaponid, 1.0 + ZB_GunSpeed[i], false, true);
			}
		}
	}



	if (IsActionQTSXJ || IsActionQTHDJ)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidPlayer(i, true, false) && GetClientTeam(i) == 2)
			{
				weaponid = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
				if (IsValidEdict(weaponid))
				{
					GetEdictClassname(weaponid, weaponname, sizeof(weaponname));
					if (StrContains(weaponname, "melee", false) < 0)
					{
						if (IsActionQTSXJ)
							SetWeaponAttackSpeed(weaponid, 2.0 + ZB_GunSpeed[i], false, true);
						if (IsActionQTHDJ)
							SetWeaponAttackSpeed(weaponid, 2.0, true, false);
					}
				}
			}
		}
	}

	if(!robot_gamestart)
		return;

	currenttime = GetEngineTime();
	duration = currenttime-lasttime;

	if(duration<0.0 || duration>1.0)
		duration=0.0;

	for (new Client = 1; Client <= MaxClients; Client++)
	{
		if(IsClientInGame(Client))
		{
			Do(Client, currenttime, duration);	//循环
			if(Robot_appendage[Client] > 0)
			{
				Do_clone(Client,currenttime,duration);
			}
		}
	}

	lasttime = currenttime;
}
ScanEnemy(Client, Float:rpos[3] )
{
	decl Float:infectedpos[3];
	decl Float:vec[3];
	decl Float:angle[3];
	new Float:dis=0.0;
	new iMaxEntities = GetMaxEntities();
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if(IsCommonInfected(iEntity) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", infectedpos);
			infectedpos[2]+=40.0;
			dis=GetVectorDistance(rpos, infectedpos) ;
			//CPrintToChatAll("%f %N" ,dis, i);
			if(dis < RobotRangeEffect[Client])
			{
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndCI, robot[Client]);

				if(!TR_DidHit(trace))
				{
					CloseHandle(trace);
					return iEntity;
				} else CloseHandle(trace);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
		{
			GetClientEyePosition(i, infectedpos);
			dis=GetVectorDistance(rpos, infectedpos) ;
			//CPrintToChatAll("%f %N" ,dis, i);
			if(dis < RobotRangeEffect[Client])
			{
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndLive, robot[Client]);

				if(!TR_DidHit(trace))
				{
					CloseHandle(trace);
					return i;
				} else CloseHandle(trace);
			}
		}
	}
	return 0;
}
ScanEnemy_clone(Client, Float:rpos[3] )
{
	decl Float:infectedpos[3];
	decl Float:vec[3];
	decl Float:angle[3];
	new Float:dis=0.0;
	new iMaxEntities = GetMaxEntities();
	//MaxClients 为玩家数量
	//iMaxEntities 所有实体数量



	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
		{
			//CPrintToChat(Client,"扫描到僵尸");
			GetClientEyePosition(i, infectedpos);
			dis=GetVectorDistance(rpos, infectedpos) ;
			//CPrintToChatAll("%f %N ===" ,dis, Client);
			if(dis < RobotRangeEffect[Client])
			{
				//CPrintToChat(Client,"僵尸1离克隆机器人的距离为:%f",dis);
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndLive, robot_clone[Client]);

				if(!TR_DidHit(trace))
				{
					CloseHandle(trace);
					return i;
				} else CloseHandle(trace);
			}
		}
	}




	//for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	for(new iEntity=iMaxEntities; iEntity >= MaxClients + 1; iEntity--)
	{
		//CPrintToChat(Client,"扫描到除幸存者以外的僵尸");
		if(IsCommonInfected(iEntity) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", infectedpos);
			infectedpos[2]+=40.0;
			dis=GetVectorDistance(rpos, infectedpos) ;
			//CPrintToChatAll("%f %N" ,dis, Client);
			if(dis < RobotRangeEffect[Client])
			{
				//CPrintToChat(Client,"僵尸2离克隆机器人的距离为:%f",dis);
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				new Handle:trace = TR_TraceRayFilterEx(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndCI, robot_clone[Client]);

				if(!TR_DidHit(trace))
				{
					CloseHandle(trace);
					return iEntity;
				} else CloseHandle(trace);
			}
		}
	}



	return 0;
}
FireBullet(controller, bot, Float:infectedpos[3], Float:botorigin[3])
{
	decl Float:vAngles[3];
	decl Float:vAngles2[3];
	decl Float:pos[3];
	SubtractVectors(infectedpos, botorigin, infectedpos);
	GetVectorAngles(infectedpos, vAngles);
	new Float:arr1;
	new Float:arr2;
	arr1=0.0-bulletaccuracy[weapontype[controller]];
	arr2=bulletaccuracy[weapontype[controller]];
	decl Float:v1[3];
	decl Float:v2[3];
	//CPrintToChatAll("%f %f",arr1, arr2);
	for(new c=0; c<weaponbulletpershot[weapontype[controller]];c++)
	{
		//CPrintToChatAll("fire");
		vAngles2[0]=vAngles[0]+GetRandomFloat(arr1, arr2);
		vAngles2[1]=vAngles[1]+GetRandomFloat(arr1, arr2);
		vAngles2[2]=vAngles[2]+GetRandomFloat(arr1, arr2);
		new hittarget=0;
		new Handle:trace = TR_TraceRayFilterEx(botorigin, vAngles2, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelfAndSurvivor, bot);
		if(TR_DidHit(trace))
		{
			TR_GetEndPosition(pos, trace);
			hittarget=TR_GetEntityIndex( trace);
		}
		CloseHandle(trace);
		if((hittarget>0 && hittarget<=MaxClients) || IsCommonInfected(hittarget) || IsWitch(hittarget))
		{
			if(IsCommonInfected(hittarget) || IsWitch(hittarget))	DealDamage(controller,hittarget,RoundToNearest((RobotAttackEffect[controller])*weaponbulletdamage[weapontype[controller]]/(1.0 + StrEffect[controller] + EnergyEnhanceEffect_Attack[controller])),2,"robot_attack");
			else	DealDamage(controller,hittarget,RoundToNearest((RobotAttackEffect[controller])*weaponbulletdamage[weapontype[controller]]),2,"robot_attack");
			ShowParticle(pos, PARTICLE_BLOOD, 0.5);
		}
		SubtractVectors(botorigin, pos, v1);
		NormalizeVector(v1, v2);
		ScaleVector(v2, 36.0);
		SubtractVectors(botorigin, v2, infectedorigin);
		decl color[4];
		color[0] = 200;
		color[1] = 200;
		color[2] = 200;
		color[3] = 230;
		new Float:life=0.06;
		new Float:width1=0.01;
		new Float:width2=0.08;
		TE_SetupBeamPoints(infectedorigin, pos, g_BeamSprite, 0, 0, 0, life, width1, width2, 1, 0.0, color, 0);
		TE_SendToAll();
		//EmitAmbientSound(SOUND[weapontype[controller]], vOrigin, controller, SNDLEVEL_RAIDSIREN);
		EmitSoundToAll(SOUND[weapontype[controller]], 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, botorigin, NULL_VECTOR, false, 0.0);
	}
}
public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	return true;
}

public bool:TraceRayDontHitSelfAndLive(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	else if(entity>0 && entity<=MaxClients)
	{
		if(IsClientInGame(entity))
		{
			return false;
		}
	}
	return true;
}

public bool:TraceRayDontHitSelfAndSurvivor(entity, mask, any:data)
{
	if(entity == data)
	{
		return false;
	}
	else if(entity>0 && entity<=MaxClients)
	{
		if(IsClientInGame(entity) && GetClientTeam(entity)==2)
		{
			return false;
		}
	}
	return true;
}

public bool:TraceRayDontHitSelfAndCI(entity, mask, any:data)
{
	new iMaxEntities = GetMaxEntities();
	if(entity == data)
	{
		return false;
	}
	else if(entity>MaxClients && entity<=iMaxEntities)
	{
		return false;
	}
	return true;
}

//勾魂之力特效
public Action:Event_WeaponFire2(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new iCid = GetClientOfUserId(GetEventInt(event, "userid"));
	//new iEntid = GetEntDataEnt2(iCid,S_rActiveW);
	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(iCid, user_name, sizeof(user_name));

	if (GouhunLv[iCid] > 0)
	{
		ThdFunction(iCid);
		new sk = GetRandomInt(1, 10);
		if (sk > 6)
		{
			new rnd1 = GetRandomInt(1, 150);
			if (rnd1 < 6)
			{
				FireBallFunction2(iCid);
			}
		}
		else
		{
			new rnd2 = GetRandomInt(1, 150);
			if (rnd2 < 7)
			{
				IceBallzFunction(iCid);
			}
		}
	}

}

//暗影能量特效
public Action:Event_WeaponFire2S(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new iCid = GetClientOfUserId(GetEventInt(event, "userid"));
	//new iEntid = GetEntDataEnt2(iCid,S_rActiveW);
	decl String:user_name[MAX_NAME_LENGTH]="";
	GetClientName(iCid, user_name, sizeof(user_name));

	if (AynlLv[iCid] > 0)
	{
		ThdFunctionS(iCid);
		new sk = GetRandomInt(1, 10);
		if (sk > 6)
		{
			new rnd1 = GetRandomInt(1, 150);
			if (rnd1 < 6)
			{
				FireBallFunction4(iCid);
			}
		}
		else
		{
			new rnd2 = GetRandomInt(1, 150);
			if (rnd2 < 7)
			{
				IceBallzFunctionD(iCid);
			}
		}
	}

}

/******************************************************
*	玩家面板
*******************************************************/
BuildPlayerPanel(client)
{
	if (!IsValidPlayer(client))
		return;
	if (IsFakeClient(client))
		return;

	new String:text[256];
	new connectmaxnum = maxclToolzDowntownCheck();
	new connectnum = GetAllPlayerCount();
	new maxsurvivor = GetConVarInt(cv_survivor_limit);
	new teamnum;
	new Handle:playerpanel = CreatePanel();
	SetPanelTitle(playerpanel, "玩家面板");
	DrawPanelText(playerpanel, " \n");

	if (playerpanel == INVALID_HANDLE)
		return;

	//旁观
	teamnum = CountPlayersTeam(1);
	Format(text, sizeof(text), "旁观(%d): ", teamnum);
	DrawPanelText(playerpanel, text);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i) && GetClientTeam(i) == 1)
		{
			Format(text, sizeof(text), "闲:%N", i);
			DrawPanelText(playerpanel, text);
		}
	}

	DrawPanelText(playerpanel, " \n");
	teamnum = CountPlayersTeam(2);

	Format(text, sizeof(text), "幸存者(%d/%d): ", teamnum, maxsurvivor);
	DrawPanelText(playerpanel, text);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i) && GetClientTeam(i) == 2)
		{
			if (IsPlayerAlive(i))
					Format(text, sizeof(text), "活:%N", i);
			else if (!IsPlayerAlive(i))
					Format(text, sizeof(text), "死:%N", i);

			DrawPanelText(playerpanel, text);
		}
	}
	DrawPanelText(playerpanel, " \n");
	//连接数
	Format(text, sizeof(text), "连接数: (%d/%d)", connectnum, connectmaxnum);
	DrawPanelText(playerpanel, text);

	SendPanelToClient(playerpanel, client, PlayerListMenu, MENU_TIME_FOREVER);
	CloseHandle(playerpanel);
}

//面板传输回调
public PlayerListMenu(Handle:menu, MenuAction:action, client, param)
{

}

//sm_wanjia回调
public Action:Command_playerlistpanel(Client,args)
{
	BuildPlayerPanel(Client);
	return Plugin_Handled;
}

//玩家面板菜单回调
public Action:MenuFunc_TeamInfo(Client)
{
	BuildPlayerPanel(Client);
	return Plugin_Handled;
}
//加入游戏 !join

public Action:Johnson_joingame(Client,args)
{
	if (IsValidPlayer(Client) && !IsFakeClient(Client))
		{
			if (GetClientTeam(Client) != 2)
				ChangeTeam(Client, 2);
			else
				PrintHintText(Client, "你已经在游戏中,无须再加入!");
		}
}

//雷子弹_学习
public Action:MenuFunc_AddLZD(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习雷子弹 目前等级: %d/%d 发动指令: !lzd - 技能点剩余: %d", LZDLv[Client], LvLimit_LZD, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 启用后对射击后子雷子弹对小范围内的感染者造成一定伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "雷电伤害: %d",LZDDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.1f", LZDDuration[Client]);

	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddLZD, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddLZD(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(LZDLv[Client] < LvLimit_LZD)
			{
				LZDLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "\x03[技能] {green}雷子弹\x03等级变为{green}Lv.%d\x03", BrokenAmmoLv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}雷子弹\x03等级已经上限!");

			MenuFunc_AddLZD(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}

//雷子弹_快捷指令
public Action:UseLZD(Client, args)
{
	if(GetClientTeam(Client) == 2)
		LZD_Action(Client);
	else
		CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

//雷子弹_使用
public LZD_Action(Client)
{
	if(JD[Client] != 11)
	{
		CPrintToChat(Client, MSG_NEED_JOB11);
		return;
	}

	if(LZDLv[Client] <= 0)
	{
		CPrintToChat(Client, "你没有学习雷子弹!");
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(LZD_Ammo[Client])
	{
		CPrintToChat(Client, "你已经启动了雷子弹!");
		return;
	}

	if(MP_LZD > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_LZD, MP[Client]);
		return;
	}

	MP[Client] -= MP_LZD;
	LZD_Ammo[Client] = true;
	CPrintToChatAll("\x03[技能] \x03%N {blue}启动了{green}Lv.%d{blue}的{olive}雷子弹{blue}!", Client, LZDLv[Client]);
	CreateTimer(LZDDuration[Client], LZD_Stop, Client);
	SetEntPropFloat(Client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	SetEntPropFloat(Client, Prop_Send, "m_flProgressBarDuration", LZDDuration[Client]);
}

//雷子弹_停止
public Action:LZD_Stop(Handle:timer, any:Client)
{
	if (LZD_Ammo[Client])
		LZD_Ammo[Client] = false;

	if (IsValidPlayer(Client, false))
		CPrintToChat(Client, "\x03[技能] \x03雷子弹弹{blue}结束了!");

	KillTimer(timer);
}

//雷子弹_攻击
public LZDRangeAttack(Client, Float:pos[3])
{
	new Float:entpos[3];
	new Float:distance;
	new MaxEnt = GetMaxEntities();
	decl String:weaponclass[64], weaponid;

	decl Float:Direction[3];
	Direction[0] = GetRandomFloat(-1.0, 1.0);
	Direction[1] = GetRandomFloat(-1.0, 1.0);
	Direction[2] = GetRandomFloat(-1.0, 1.0);

	if (IsValidPlayer(Client) && IsValidEntity(Client))
	{
		weaponid = GetEntPropEnt(Client, Prop_Send, "m_hActiveWeapon");
		if (IsValidEdict(weaponid) && IsValidEntity(weaponid))
			GetEdictClassname(weaponid, weaponclass, sizeof(weaponclass));
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || !IsValidEntity(i) || i == Client)
			continue;

		GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
		distance = GetVectorDistance(pos, entpos);
		if (distance <= LZDRange)
		{
			if (GetClientTeam(i) != GetClientTeam(Client))
			{
				if (StrContains(weaponclass, "shotgun", false) >= 0)
					DealDamage(Client, i, LZDDamage[Client], 0);
				else
					DealDamage(Client, i, LZDDamage[Client], 0);
			}
			else
				DealDamage(Client, i, LZDDamage[Client] / 0, 0);

			TE_SetupSparks(entpos, Direction, 2, 3);
			TE_SendToAll();
		}
	}

	for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
	{
		if(IsValidEntity(iEnt) && IsCommonInfected(iEnt) && GetEntProp(iEnt, Prop_Data, "m_iHealth") > 0)
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= LZDRange)
			{
				if (StrContains(weaponclass, "shotgun", false) > 0)
				DealDamage(Client, iEnt, LZDDamage[Client], 0);
				else DealDamage(Client, iEnt, LZDDamage[Client],0);
				TE_SetupSparks(entpos, Direction, 2, 3);
				TE_SendToAll();
			}
		}

	}

}

//雷子弹_效果
public LZDRangeEffects(Client, Float:pos[3])
{
	if (!IsValidPlayer(Client))
		return;
	if (!LZD_Ammo[Client])
		return;

	decl Float:Direction[3];
	Direction[0] = GetRandomFloat(-1.0, 1.0);
	Direction[1] = GetRandomFloat(-1.0, 1.0);
	Direction[2] = GetRandomFloat(-1.0, 1.0);

	TE_SetupSparks(pos, Direction, 4, 5);
	TE_SendToAll();

	LZDRangeAttack(Client, pos);
}


/******************************************************
*	弹药师
*******************************************************/

/******************************************************
*	弹药专家
*******************************************************/

//破碎弹_学习
public Action:MenuFunc_AddBrokenAmmo(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习破碎弹 目前等级: %d/%d 发动指令: !psd - 技能点剩余: %d", BrokenAmmoLv[Client], LvLimit_BrokenAmmo, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 启用后对射击后子弹破碎对小范围内的感染者造成一定伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "破碎伤害: %d", BrokenAmmoDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.1f", BrokenAmmoDuration[Client]);

	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddBrokenAmmo, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddBrokenAmmo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(BrokenAmmoLv[Client] < LvLimit_BrokenAmmo)
			{
				BrokenAmmoLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "\x03[技能] {green}破碎弹\x03等级变为{green}Lv.%d\x03", BrokenAmmoLv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}破碎弹\x03等级已经上限!");

			MenuFunc_AddBrokenAmmo(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}

//破碎弹_快捷指令
public Action:UseBrokenAmmo(Client, args)
{
	if(GetClientTeam(Client) == 2)
		BrokenAmmo_Action(Client);
	else
		CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

//破碎弹_使用
public BrokenAmmo_Action(Client)
{
	if(JD[Client] != 6)
	{
		CPrintToChat(Client, MSG_NEED_JOB6);
		return;
	}

	if(BrokenAmmoLv[Client] <= 0)
	{
		CPrintToChat(Client, "你没有学习该技能!");
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(Broken_Ammo[Client] || Poison_Ammo[Client] || SuckBlood_Ammo[Client])
	{
		CPrintToChat(Client, "你已经启动了一种弹药技能了!");
		return;
	}

	if(MP_BrokenAmmo > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_BrokenAmmo, MP[Client]);
		return;
	}

	MP[Client] -= MP_BrokenAmmo;
	Broken_Ammo[Client] = true;
	CPrintToChatAll("\x03[技能] \x03%N {blue}启动了{green}Lv.%d{blue}的{olive}破碎弹{blue}!", Client, BrokenAmmoLv[Client]);
	CreateTimer(BrokenAmmoDuration[Client], BrokenAmmo_Stop, Client);
	SetEntPropFloat(Client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	SetEntPropFloat(Client, Prop_Send, "m_flProgressBarDuration", BrokenAmmoDuration[Client]);
}

//破碎弹_停止
public Action:BrokenAmmo_Stop(Handle:timer, any:Client)
{
	if (Broken_Ammo[Client])
		Broken_Ammo[Client] = false;

	if (IsValidPlayer(Client, false))
		CPrintToChat(Client, "\x03[技能] \x03破碎弹{blue}结束了!");

	KillTimer(timer);
}

//破碎弹_攻击
public BrokenAmmoRangeAttack(Client, Float:pos[3])
{
	new Float:entpos[3];
	new Float:distance;
	new MaxEnt = GetMaxEntities();
	decl String:weaponclass[64], weaponid;

	decl Float:Direction[3];
	Direction[0] = GetRandomFloat(-1.0, 1.0);
	Direction[1] = GetRandomFloat(-1.0, 1.0);
	Direction[2] = GetRandomFloat(-1.0, 1.0);

	if (IsValidPlayer(Client) && IsValidEntity(Client))
	{
		weaponid = GetEntPropEnt(Client, Prop_Send, "m_hActiveWeapon");
		if (IsValidEdict(weaponid) && IsValidEntity(weaponid))
			GetEdictClassname(weaponid, weaponclass, sizeof(weaponclass));
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || !IsValidEntity(i) || i == Client)
			continue;

		GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
		distance = GetVectorDistance(pos, entpos);
		if (distance <= BrokenAmmoRange)
		{
			if (GetClientTeam(i) != GetClientTeam(Client))
			{
				if (StrContains(weaponclass, "shotgun", false) >= 0)
					DealDamage(Client, i, BrokenAmmoDamage[Client] / 0);
				else
					DealDamage(Client, i, BrokenAmmoDamage[Client], 0);
			}
			else
				DealDamage(Client, i, BrokenAmmoDamage[Client] / 50, 0);

			TE_SetupSparks(entpos, Direction, 2, 3);
			TE_SendToAll();
		}
	}

	for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
	{
		if(IsValidEntity(iEnt) && IsCommonInfected(iEnt) && GetEntProp(iEnt, Prop_Data, "m_iHealth") > 0)
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= BrokenAmmoRange)
			{
				if (StrContains(weaponclass, "shotgun", false) > 0)
				DealDamage(Client, iEnt, BrokenAmmoDamage[Client], 0);
				else DealDamage(Client, iEnt, BrokenAmmoDamage[Client],0);
				TE_SetupSparks(entpos, Direction, 2, 3);
				TE_SendToAll();
			}
		}

	}

}

//破碎弹_效果
public BrokenAmmoRangeEffects(Client, Float:pos[3])
{
	if (!IsValidPlayer(Client))
		return;
	if (!Broken_Ammo[Client])
		return;

	decl Float:Direction[3];
	Direction[0] = GetRandomFloat(-1.0, 1.0);
	Direction[1] = GetRandomFloat(-1.0, 1.0);
	Direction[2] = GetRandomFloat(-1.0, 1.0);

	TE_SetupSparks(pos, Direction, 4, 5);
	TE_SendToAll();

	BrokenAmmoRangeAttack(Client, pos);
}


//渗毒弹_学习
public Action:MenuFunc_AddPoisonAmmo(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习渗毒弹 目前等级: %d/%d 发动指令: !sdd - 技能点剩余: %d", PoisonAmmoLv[Client], LvLimit_PoisonAmmo, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 启用后对被射击的目标造成持续的毒性伤害");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "渗毒伤害: %d", PoisonAmmoDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.1f", PoisonAmmoDuration[Client]);

	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddPoisonAmmo, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddPoisonAmmo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(PoisonAmmoLv[Client] < LvLimit_PoisonAmmo)
			{
				PoisonAmmoLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "\x03[技能] {green}渗毒弹\x03等级变为{green}Lv.%d\x03", PoisonAmmoLv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}渗毒弹\x03等级已经上限!");

			MenuFunc_AddPoisonAmmo(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}

//渗毒弹_快捷指令
public Action:UsePoisonAmmo(Client, args)
{
	if(GetClientTeam(Client) == 2)
		PoisonAmmo_Action(Client);
	else
		CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

//渗毒弹_使用
public PoisonAmmo_Action(Client)
{
	if(JD[Client] != 6)
	{
		CPrintToChat(Client, MSG_NEED_JOB6);
		return;
	}

	if(PoisonAmmoLv[Client] <= 0)
	{
		CPrintToChat(Client, "你没有学习该技能!");
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(Broken_Ammo[Client] || Poison_Ammo[Client] || SuckBlood_Ammo[Client])
	{
		CPrintToChat(Client, "你已经启动了一种弹药专家技能了!");
		return;
	}

	if(MP_PoisonAmmo > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_PoisonAmmo, MP[Client]);
		return;
	}

	MP[Client] -= MP_PoisonAmmo;
	Poison_Ammo[Client] = true;
	CPrintToChatAll("{olive}[技能] {green}%N {blue}启动了{green}Lv.%d{blue}的{olive}渗毒弹{blue}!", Client, PoisonAmmoLv[Client]);
	CreateTimer(PoisonAmmoDuration[Client], PoisonAmmo_Stop, Client);
	SetEntPropFloat(Client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	SetEntPropFloat(Client, Prop_Send, "m_flProgressBarDuration", PoisonAmmoDuration[Client]);
}

//渗毒弹_停止
public Action:PoisonAmmo_Stop(Handle:timer, any:Client)
{
	if (Poison_Ammo[Client])
		Poison_Ammo[Client] = false;

	if (IsValidPlayer(Client, false))
		CPrintToChat(Client, "{olive}[技能] {green}渗毒弹{blue}结束了!");

	KillTimer(timer);
}

//渗毒弹_攻击
public PoisonAmmoAttack(Client, target, String:weapon[])
{
	if (!IsValidPlayer(Client))
		return;
	if (!Poison_Ammo[Client])
		return;

	if (IsValidEntity(target) && GetClientTeam(target) == 3 && GetEntProp(target, Prop_Data, "m_iHealth") > 0)
	{
		if (StrContains(weapon, "shotgun", false) > 0)
			DealDamageRepeat(Client, target, PoisonAmmoDamage[Client] / 8, 0, "", 1.0, PoisonAmmoDamageTime[Client]);
		else if (StrContains(weapon, "smg", false) > 0)
			DealDamageRepeat(Client, target, PoisonAmmoDamage[Client] / 2, 0, "", 1.0, PoisonAmmoDamageTime[Client]);
		else
			DealDamageRepeat(Client, target, PoisonAmmoDamage[Client], 0, "", 1.0, PoisonAmmoDamageTime[Client]);
	}

}

//嗜血弹_学习
public Action:MenuFunc_AddSuckBloodAmmo(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习嗜血弹 目前等级: %d/%d 发动指令: !xxd - 技能点剩余: %d", SuckBloodAmmoLv[Client], LvLimit_SuckBloodAmmo, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 启用后对被射击感染者时有一定几率恢复血量.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "吸血几率: %.1f", SuckBloodAmmoPBB[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.1f", SuckBloodAmmoDuration[Client]);

	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddSuckBloodAmmo, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddSuckBloodAmmo(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(SuckBloodAmmoLv[Client] < LvLimit_SuckBloodAmmo)
			{
				SuckBloodAmmoLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "{olive}[技能] {green}嗜血弹{lightgreen}等级变为{green}Lv.%d{lightgreen}", SuckBloodAmmoLv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}嗜血弹\x03等级已经上限!");

			MenuFunc_AddSuckBloodAmmo(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}

//嗜血弹_快捷指令
public Action:UseSuckBloodAmmo(Client, args)
{
	if(GetClientTeam(Client) == 2)
		SuckBloodAmmo_Action(Client);
	else
		CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

//嗜血弹_使用
public SuckBloodAmmo_Action(Client)
{
	if(JD[Client] != 6)
	{
		CPrintToChat(Client, MSG_NEED_JOB6);
		return;
	}

	if(SuckBloodAmmoLv[Client] <= 0)
	{
		CPrintToChat(Client, "你没有学习该技能!");
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(Broken_Ammo[Client] || Poison_Ammo[Client] || SuckBlood_Ammo[Client])
	{
		CPrintToChat(Client, "你已经启动了一种未来战士技能了!");
		return;
	}

	if(MP_SuckBloodAmmo > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_SuckBloodAmmo, MP[Client]);
		return;
	}

	MP[Client] -= MP_SuckBloodAmmo;
	SuckBlood_Ammo[Client] = true;
	CPrintToChatAll("{olive}[技能] {green}%N {blue}启动了{green}Lv.%d{blue}的{olive}嗜血弹{blue}!", Client, SuckBloodAmmoLv[Client]);
	CreateTimer(SuckBloodAmmoDuration[Client], SuckBloodAmmo_Stop, Client);
	SetEntPropFloat(Client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	SetEntPropFloat(Client, Prop_Send, "m_flProgressBarDuration", SuckBloodAmmoDuration[Client]);
}

//嗜血弹_停止
public Action:SuckBloodAmmo_Stop(Handle:timer, any:Client)
{
	if (SuckBlood_Ammo[Client])
		SuckBlood_Ammo[Client] = false;

	if (IsValidPlayer(Client, false))
		CPrintToChat(Client, "{olive}[技能] {green}嗜血弹{blue}结束了!");

	KillTimer(timer);
}

//嗜血弹_攻击
public SuckBloodAmmoAttack(Client, target)
{
	if (!IsValidPlayer(Client))
		return;
	if (!SuckBlood_Ammo[Client])
		return;

	if (IsValidEntity(Client))
	{
		if (IsValidEntity(target) && GetEntProp(target, Prop_Data, "m_iHealth") > 0)
		{
			new Float:random = GetRandomFloat(0.0, 100.0);
			if (random <= SuckBloodAmmoPBB[Client])
				SuckBloodAmmoSuck(Client, target);
		}
	}
}

//嗜血弹_吸血
public SuckBloodAmmoSuck(Client, target)
{
	new ihealth = GetEntProp(Client, Prop_Data, "m_iHealth");
	new imaxhealth = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
	new suckhealth = GetRandomInt(1, 5) + ihealth;
	EmitSoundToClient(Client, SOUND_SUCKBLOOD);
	if (suckhealth >= imaxhealth)
	{
		SetEntProp(Client, Prop_Data, "m_iHealth", imaxhealth);
		ScreenFade(Client, 20, 120, 20, 80, 100, 1);
	}
	else
	{
		SetEntProp(Client, Prop_Data, "m_iHealth", suckhealth);
		ScreenFade(Client, 20, 120, 20, 80, 100, 1);
	}
}


//区域爆破_学习
public Action:MenuFunc_AddAreaBlasting(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习区域爆破 目前等级: %d/%d 发动指令: !qybp - 技能点剩余: %d", AreaBlastingLv[Client], LvLimit_AreaBlasting, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 对自身的一定范围内的所有感染者产生爆破伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆破范围: %d", AreaBlastingRange[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆破伤害: %d", AreaBlastingDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.1f", AreaBlastingCD[Client]);

	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddAreaBlasting, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddAreaBlasting(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(AreaBlastingLv[Client] < LvLimit_AreaBlasting)
			{
				AreaBlastingLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "{olive}[技能] {green}区域爆破{lightgreen}等级变为{green}Lv.%d{lightgreen}", AreaBlastingLv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}区域爆破\x03等级已经上限!");

			MenuFunc_AddAreaBlasting(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}

//区域爆破_快捷指令
public Action:UseAreaBlasting(Client, args)
{
	if(GetClientTeam(Client) == 2)
		AreaBlasting_Action(Client);
	else
		CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}


//区域爆破_使用
public AreaBlasting_Action(Client)
{
	if(JD[Client] != 6)
	{
		CPrintToChat(Client, MSG_NEED_JOB6);
		return;
	}

	if(AreaBlastingLv[Client] <= 0)
	{
		CPrintToChat(Client, "你没有学习该技能!");
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(AreaBlasting[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return;
	}

	if(MP_AreaBlasting > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_AreaBlasting, MP[Client]);
		return;
	}

	MP[Client] -= MP_AreaBlasting;
	AreaBlasting[Client] = true;
	AreaBlastingAttack(Client);
	CPrintToChatAll("{olive}[技能] {green}%N {blue}启动了{green}Lv.%d{blue}的{olive}区域爆破{blue}!", Client, AreaBlastingLv[Client]);
	CreateTimer(AreaBlastingCD[Client], AreaBlasting_Stop, Client);
}

//区域爆破_冷却
public Action:AreaBlasting_Stop(Handle:timer, any:Client)
{
	if (AreaBlasting[Client])
		AreaBlasting[Client] = false;

	if (IsValidPlayer(Client, false))
		CPrintToChat(Client, "{olive}[技能] {green}区域爆破{blue}冷却结束了!");

	KillTimer(timer);
}

//区域爆破_攻击
public AreaBlastingAttack(Client)
{
	if (!IsValidEntity(Client))
		return;

	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new Float:skypos[3];
	new MaxEnt = GetMaxEntities();

	GetEntPropVector(Client, Prop_Send, "m_vecOrigin", pos);
	SuperTank_LittleFlower(Client, pos, 1);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || !IsValidEntity(i) || i == Client || GetClientTeam(i) == GetClientTeam(Client))
			continue;

		GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
		distance = GetVectorDistance(pos, entpos);
		if (distance <= AreaBlastingRange[Client])
		{
			DealDamage(Client, i, AreaBlastingDamage[Client], 0);
			skypos[0] = entpos[0];
			skypos[1] = entpos[1];
			skypos[2] = entpos[2] + 2000.0;
			TE_SetupBeamPoints(skypos, entpos, g_BeamSprite, 0, 0, 0, 5.0, 5.0, 5.0, 10, 1.0, WhiteColor, 0);
			TE_SendToAll();
		}
	}

	for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
	{
		if(IsValidEntity(iEnt) && IsCommonInfected(iEnt))
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= AreaBlastingRange[Client])
				DealDamage(Client, iEnt, AreaBlastingDamage[Client], 0);
		}

	}


}


//镭射激光炮_学习
public Action:MenuFunc_AddLaserGun(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习镭射激光炮 目前等级: %d/%d 发动指令: !lsjgp - 技能点剩余: %d", LaserGunLv[Client], LvLimit_LaserGun, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向前方发射一条直线的强力激光炮,摧毁线上的所有生物!(需要技能点:60)");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "造成伤害: %d", LaserGunDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.1f", LaserGunCD[Client]);
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddLaserGun, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddLaserGun(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 60)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(LaserGunLv[Client] < LvLimit_LaserGun)
			{
				LaserGunLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "{olive}[技能] {green}镭射激光炮{lightgreen}等级变为{green}Lv.%d{lightgreen}", LaserGunLv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}镭射激光炮\x03等级已经上限!");

			MenuFunc_AddLaserGun(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}

//镭射激光炮_快捷指令
public Action:UseLaserGun(Client, args)
{
	if(GetClientTeam(Client) == 2)
		LaserGun_Action(Client);
	else
		CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

//镭射激光炮_使用
public LaserGun_Action(Client)
{
	if(JD[Client] != 6)
	{
		CPrintToChat(Client, MSG_NEED_JOB6);
		return;
	}

	if(LaserGunLv[Client] <= 0)
	{
		CPrintToChat(Client, "你没有学习该技能!");
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(LaserGun[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return;
	}

	if(MaxMP[Client] > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MaxMP[Client], MP[Client]);
		return;
	}

	MP[Client] = 0;
	LaserGun[Client] = true;
	LaserGunAttack(Client);
	CPrintToChatAll("{olive}[技能] {green}%N {blue}启动了{green}Lv.%d{blue}的{olive}镭射激光炮{blue}!", Client, LaserGunLv[Client]);
	CreateTimer(LaserGunCD[Client], LaserGun_Stop, Client);
}

//镭射激光炮_冷却
public Action:LaserGun_Stop(Handle:timer, any:Client)
{
	if (LaserGun[Client])
		LaserGun[Client] = false;

	if (IsValidPlayer(Client, false))
		CPrintToChat(Client, "{olive}[技能] {green}镭射激光炮{blue}冷却结束了!");

	KillTimer(timer);
}


//镭射激光炮_攻击
public LaserGunAttack(Client)
{
	if (!IsValidEntity(Client))
		return;

	new Float:pos[3];
	new Float:aimpos[3];
	new Float:eyepos[3];
	new Float:angle[3];
	new Float:velocity[3];
	new Float:TempPos[3];

	new entity = CreateEntityByName("tank_rock");
	GetTracePosition(Client, aimpos);
	GetClientEyePosition(Client, eyepos);
	GetClientEyePosition(Client, pos);
	MakeVectorFromPoints(eyepos, aimpos, angle);
	NormalizeVector(angle, angle);

	TempPos[0] = angle[0] * 50;
	TempPos[1] = angle[1] * 50;
	TempPos[2] = angle[2] * 50;
	AddVectors(eyepos, TempPos, eyepos);

	velocity[0] = angle[0] * 300.0;
	velocity[1] = angle[1] * 300.0;
	velocity[2] = angle[2] * 300.0;

	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		LaserGunDamagetimer[Client] = 0.0;

		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", Client);
		DispatchSpawn(entity);
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 255, 255, 255, 0);
		SetEntityGravity(entity, 0.1);
		SetEntProp(entity, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(entity, Prop_Data, "m_MoveCollide", 0);
		TeleportEntity(entity, eyepos, angle, velocity);

		new Handle:pack = CreateDataPack();
		CreateDataTimer(0.15, Timer_LaserGunAttack, pack, TIMER_REPEAT);
		WritePackCell(pack, entity);
		WritePackFloat(pack, angle[0]);
		WritePackFloat(pack, angle[1]);
		WritePackFloat(pack, angle[2]);
		WritePackFloat(pack, velocity[0]);
		WritePackFloat(pack, velocity[1]);
		WritePackFloat(pack, velocity[2]);
		TE_SetupBeamPoints(pos, aimpos, g_BeamSprite, 0, 0, 0, LaserGunDuration[Client], 60.0, 60.0, 10, 6.0, BlueColor, 0);
		TE_SendToAll();
	}
}

//镭射激光炮_伤害计时器
public Action:Timer_LaserGunAttack(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new entity = ReadPackCell(pack);

	if (!IsValidEntity(entity))
	{
		CreateTimer(0.1, Timer_LaserGunKill, entity);
		KillTimer(timer);
	}

	new Client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	LaserGunDamagetimer[Client] += 0.15;
	new Float:angle[3];
	angle[0] = ReadPackFloat(pack);
	angle[1] = ReadPackFloat(pack);
	angle[2] = ReadPackFloat(pack);
	new Float:velocity[3];
	velocity[0] = ReadPackFloat(pack);
	velocity[1] = ReadPackFloat(pack);
	velocity[2] = ReadPackFloat(pack);
	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new MaxEnt = GetMaxEntities();
	new Float:skypos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	TeleportEntity(entity, pos, angle, velocity);

	LittleFlower(pos, EXPLODE, Client);
	LittleFlower(pos, MOLOTOV, Client);
	skypos[0] = pos[0];
	skypos[1] = pos[1];
	skypos[2] = pos[2] + 2000.0;
	TE_SetupBeamPoints(skypos, pos, g_BeamSprite, 0, 0, 0, 0.5, 30.0, 30.0, 10, 5.0, RedColor, 0);
	TE_SendToAll();

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || !IsValidEntity(i) || i == Client)
			continue;

		GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
		distance = GetVectorDistance(pos, entpos);
		if (distance <= 100)
		{
			if (GetClientTeam(i) != GetClientTeam(Client))
				DealDamage(Client, i, LaserGunDamage[Client], 0);
			else
				DealDamage(Client, i, LaserGunDamage[Client] / 0, 0);
		}
	}

	for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
	{
		if(IsValidEntity(iEnt) && IsCommonInfected(iEnt))
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= 100)
				DealDamage(Client, iEnt, LaserGunDamage[Client], 0);
		}
	}

	if (LaserGunDamagetimer[Client] >= LaserGunDuration[Client])
	{
		CreateTimer(0.1, Timer_LaserGunKill, entity);
		KillTimer(timer);
	}
}

//镭射激光炮_删除计时器
public Action:Timer_LaserGunKill(Handle:timer, any:entity)
{
	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		new Client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		LaserGunDamagetimer[Client] = 0.0;
		RemoveEdict(entity);
	}
}
//复仇欲望
public Action:UsePHABA(Client, args)
{
	if(GetClientTeam(Client) == 2) PHABAFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:PHABAFunction(Client)
{
	if(JD[Client] != 16)
	{
		CPrintToChat(Client, MSG_NEED_JOB16);
		return Plugin_Handled;
	}

	if(PHABALv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_45);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsPHABAEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_PHA_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_PHABA) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_PHABA), MP[Client]);
		return Plugin_Handled;
	}

	IsPHABAEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_PHABA);

	SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", (1.0 + PHABAEffect[Client])*(1.0 + AgiEffect[Client]));
	SetEntityGravity(Client, (1.0 + PHABAEffect[Client])/(1.0 + AgiEffect[Client]));
	PHABADurationTimer[Client] = CreateTimer(PHABADuration[Client], PHABADurationFunction, Client);
	CPrintToChatAll(MSG_SKILL_PHA_ANNOUNCE, Client, PHABALv[Client]);
	return Plugin_Handled;
}

public Action:PHABADurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	PHABADurationTimer[Client] = INVALID_HANDLE;
	IsPHABAEnable[Client] = false;
	SetEntPropFloat(Client, Prop_Data, "m_flLaggedMovementValue", 1.0*(1.0 + AgiEffect[Client]));
	SetEntityGravity(Client, 1.0/(1.0 + AgiEffect[Client]));

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_PHA_END);
	}

	return Plugin_Handled;
}
//死亡契约
public Action:UsePHFRA(Client, args)
{
	if(GetClientTeam(Client) == 2) PHFRAFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:PHFRAFunction(Client)
{
	if(JD[Client] != 16)
	{
		CPrintToChat(Client, MSG_NEED_JOB16);
		return Plugin_Handled;
	}

	if(PHFRALv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_45);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}


	if(!IsPHFRAReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_PHFRA) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_PHFRA), MP[Client]);
		return Plugin_Handled;
	}

	new HP = GetClientHealth(Client);
	new MaxHP = GetEntProp(Client, Prop_Data, "m_iMaxHealth");

	if(HP > MaxHP*PHFRASideEffect[Client])
	{
		IsPHFRAEnable[Client] = true;
		MP[Client] -= GetConVarInt(Cost_PHFRA);
		new resume = RoundToNearest(MaxMP[Client] * 1.0) + MP[Client];
		{	if (resume <= MaxMP[Client])
				MP[Client] = resume;
			else
			{
				MP[Client] = MaxMP[Client];
				PrintHintText(Client, "你的MP已经恢复至%d ", MP[Client]);
			}
		}
//		SetEntProp(Client, Prop_Data, "m_takedamage", 0, 1);
		PHFRADurationTimer[Client] = CreateTimer(PHFRADuration[Client], PHFRADurationFunction, Client);

		SetEntProp(Client, Prop_Data, "m_iHealth", RoundToNearest(HP - MaxHP*PHFRASideEffect[Client]));



		CPrintToChatAll(MSG_SKILL_QY_ANNOUNCE, Client, PHFRALv[Client]);
	}
	else CPrintToChat(Client, MSG_SKILL_QY_NEED_HP);

	return Plugin_Handled;
}

public Action:PHFRADurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	PHFRADurationTimer[Client] = INVALID_HANDLE;
	IsPHFRAEnable[Client] = false;
//	if(IsValidPlayer(Client))	SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);

	IsPHFRAReady[Client] = false;
	PHFRACDTimer[Client] = CreateTimer(PHFRACDTime[Client], PHFRACDTimerFunction, Client);



	return Plugin_Handled;
}

public Action:PHFRACDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	PHFRACDTimer[Client] = INVALID_HANDLE;
	IsPHFRAReady[Client] = true;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_QY_CHARGED);
	}

	return Plugin_Handled;
}

/* 使用_爆破光球 */
public Action:UsePHZGA(Client, args)
{
	if(GetClientTeam(Client) == 2) PHZGA(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);

	return Plugin_Handled;
}

/* 爆破光球 */
public Action:PHZGA(Client)
{

	if(JD[Client] != 16)
	{
		CPrintToChat(Client, MSG_NEED_JOB16);
		return Plugin_Handled;
	}

	if(PHZGALv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_47);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsPHZGAEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_PHZGA) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_PHZGA), MP[Client]);
		return Plugin_Handled;
	}

	if (!IsValidPlayer(Client))
		return Plugin_Handled;

	new Float:TracePos[3];
	new Float:EyePos[3];
	new Float:Angle[3];
	new Float:TempPos[3];
	new Float:velocity[3];
	new Handle:data;
	new entity = CreateEntityByName("tank_rock");
	GetTracePosition(Client, TracePos);
	GetClientEyePosition(Client, EyePos);
	MakeVectorFromPoints(EyePos, TracePos, Angle);
	NormalizeVector(Angle, Angle);

	TempPos[0] = Angle[0] * 50;
	TempPos[1] = Angle[1] * 50;
	TempPos[2] = Angle[2] * 50;
	AddVectors(EyePos, TempPos, EyePos);

	velocity[0] = Angle[0] * 2000;
	velocity[1] = Angle[1] * 2000;
	velocity[2] = Angle[2] * 2000;

	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		IsPHZGAEnable[Client] = true;
		//初始发射音效
		EmitAmbientSound(HealingBall_Sound_Lanuch, EyePos);
		//实体属性设置
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", Client);
		DispatchSpawn(entity);
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 255, 255, 255, 0);
		SetEntityGravity(entity, 0.1);
		SetEntProp(entity, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(entity, Prop_Data, "m_MoveCollide", 0);
		TE_SetupBeamFollow(entity, g_BeamSprite, g_HaloSprite, 5.0, 10.0, 2.0, 1, PurpleColor); //光束
		TE_SendToAll();
		TeleportEntity(entity, EyePos, Angle, velocity);
		//计时器创建
		CreateTimer(5.0, Timer_PHZGACooling, Client);
		CreateTimer(10.0, Timer_RemovePHZGA, entity);
		CreateDataTimer(0.1, Timer_PHZGA, data, TIMER_REPEAT);
		WritePackCell(data, entity);
		WritePackFloat(data, Angle[0]);
		WritePackFloat(data, Angle[1]);
		WritePackFloat(data, Angle[2]);
		WritePackFloat(data, velocity[0]);
		WritePackFloat(data, velocity[1]);
		WritePackFloat(data, velocity[2]);
	}


	CPrintToChatAll(MSG_SKILL_BP_ANNOUNCE, Client, PHZGALv[Client]);
	MP[Client] -= GetConVarInt(Cost_PHZGA);
	return Plugin_Handled;
}

/* 光球跟踪实体计时器 */
public Action:Timer_PHZGA(Handle:timer, Handle:data)
{
	new Float:pos[3];
	new Float:Angle[3];
	new Float:velocity[3];
	ResetPack(data);
	new entity = ReadPackCell(data);
	Angle[0] = ReadPackFloat(data);
	Angle[1] = ReadPackFloat(data);
	Angle[2] = ReadPackFloat(data);
	velocity[0] = ReadPackFloat(data);
	velocity[1] = ReadPackFloat(data);
	velocity[2] = ReadPackFloat(data);

	if (!IsValidEntity(entity) || !IsValidEdict(entity))
		return Plugin_Stop;

	for (new i = 1; i <= 5; i++)
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		TeleportEntity(entity, pos, Angle, velocity);
		TE_SetupGlowSprite(pos, g_GlowSprite, 0.1, 4.0, 500);
		TE_SendToAll();
	}

	if (DistanceToHit(entity) <= 200)
	{
		CreateTimer(0.1, Timer_RemovePHZGA, entity);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

/* 删除爆破光球计时器 */
public Action:Timer_RemovePHZGA(Handle:timer, any:entity)
{
	new Player;
	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new MaxEnt = GetMaxEntities();
	PHZGAReward[Player] = 0;

	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
		Player = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	if (IsValidPlayer(Player) && IsValidEntity(entity) && IsValidEdict(entity))
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		EmitAmbientSound(HealingBall_Sound_Heal, pos);
		//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
//		TE_SetupBeamRingPoint(pos, 0.1, 100.0, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 5.0, 0.0, PurpleColor, 10, 0);
//		TE_SendToAll();

		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsValidPlayer(i) || !IsValidEntity(i) || !IsValidEdict(i))
				continue;
			LittleFlower(pos, EXPLODE, i);
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= 500)
			{
				if (GetClientTeam(i) == GetClientTeam(Player))
				{
					PHDCSA(Player, i, PHZGAHealth[Player]);
//					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, GreenColor, 0);
//					TE_SendToAll();
//					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, GreenColor, 10, 0);
//					TE_SendToAll();
				}
				else
				{
//					DealDamage(Player, i, PHZGADamage[Player], 0);
					DealDamage(Player, i, PHZGADamage[Player], 0, "satellite_cannonmiss");
//					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, GreenColor, 0);
//					TE_SendToAll();
//					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, GreenColor, 10, 0);
//					TE_SendToAll();
				}
			}
		}

		for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
		{
			if(IsValidEntity(iEnt) && IsValidEdict(iEnt) && IsCommonInfected(iEnt) && GetEntProp(iEnt, Prop_Data, "m_iHealth") > 0)
			{
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if (distance <= 200)
				{
					DealDamage(Player, iEnt, PHZGADamage[Player], 0);
//					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.6, 3.0, 3.0, 1, 0.5, GreenColor, 0);
//					TE_SendToAll();
//					TE_SetupBeamRingPoint(entpos, 49.9, 50.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 20.0, 0.0, GreenColor, 10, 0);
//					TE_SendToAll();
				}
			}

		}

		//治愈经验
		PHDCOSA(Player);
		//删除实体
		RemoveEdict(entity);
	}
}

/* 治愈效果 */
public PHDCSA(Client, Target, Cure_Health)
{
	if (!IsValidPlayer(Client) || !IsValidEntity(Client) || !IsPlayerAlive(Client) || !IsValidPlayer(Target) || !IsValidEntity(Target) || !IsPlayerAlive(Target))
		return;

	new health = GetClientHealth(Target);
	new maxhealth = GetEntProp(Target, Prop_Data, "m_iMaxHealth");

	if (!IsPlayerIncapped(Target))
	{
		if (health + Cure_Health > maxhealth)
		{
			PHZGAReward[Client] += maxhealth - health;
			health = maxhealth;
		}
		else
		{
			PHZGAReward[Client] += Cure_Health;
			health = health + Cure_Health;
		}

		SetEntProp(Target, Prop_Data, "m_iHealth", health);
	}
	else if (IsPlayerIncapped(Target))
	{
		if (health + Cure_Health > 300)
		{
			PHZGAReward[Client] += 300 - health;
			health = 300;
		}
		else
		{
			PHZGAReward[Client] += Cure_Health;
			health = health + Cure_Health;
		}

		SetEntProp(Target, Prop_Data, "m_iHealth", health);
	}
}

/* 治愈效果_结束 */
public PHDCOSA(Client)
{
	if (!IsValidPlayer(Client) || !IsValidEntity(Client) || !IsPlayerAlive(Client))
	{
		PHZGAReward[Client] = 0;
		return;
	}

	if (PHZGAReward[Client] > 0)
	{
		SXZGReward[Client] = 0;
	}
}

/* 爆破光球冷却 */
public Action:Timer_PHZGACooling(Handle:timer, any:Client)
{
	IsPHZGAEnable[Client] = false;
}


/* 闪电光球 */
public Action:UsePHSD(Client, args)
{
	if(GetClientTeam(Client) == 2) PHSDFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:PHSDFunction(Client)
{
	if(JD[Client] != 16)
	{
		CPrintToChat(Client, MSG_NEED_JOB16);
		return Plugin_Handled;
	}

	if(PHSDLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_48);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsPHSDEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_PH_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_PHSD) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_PHSD), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_PHSD);

	new Float:Radius=float(PHSDRadius[Client]);
	new Float:pos[3];
	GetTracePosition(Client, pos);
	pos[2] += 50.0;
	EmitAmbientSound(HealingBall_Sound_Lanuch, pos);
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite,g_HaloSprite, 0, 10, 1.0, 5.0, 0.0, WhiteColor, 5, 0);//固定外圈BuleColor
//	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 1.0, 5.0, 5.0, CyanColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();

	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}

	IsPHSDEnable[Client] = true;

	new Handle:pack;
	PHSDTimer[Client] = CreateDataTimer(PHSDInterval[Client], PHSDTimerFunction, pack, TIMER_REPEAT);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);
	WritePackFloat(pack, GetEngineTime());

	CPrintToChatAll(MSG_SKILL_PH_ANNOUNCE, Client, PHSDLv[Client]);
	return Plugin_Handled;
}

public Action:PHSDTimerFunction(Handle:timer, Handle:pack)
{
	decl Float:pos[3], Float:entpos[3], Float:distance[3];

	ResetPack(pack);
	new Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);
	new Float:time=ReadPackFloat(pack);
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	EmitAmbientSound(ChainLightning_Sound_launch, pos);
	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}

	//new iMaxEntities = GetMaxEntities();
	new Float:Radius=float(PHSDRadius[Client]);

	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 1.0, 5.0, 0.0, WhiteColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();

	if(GetEngineTime() - time < PHSDDuration[Client])
	{
		/*光球术圈内击杀僵尸*/
		new Float:entpos_new[3];
		new iMaxEntities = GetMaxEntities();
		new Float:distance_iEntity[3];
		new Float:skypos[3];
		new num;
		for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
		{
			if (IsCommonInfected(iEntity))
			{
				new health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
				if (health > 0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos_new);
					SubtractVectors(entpos_new, pos, distance_iEntity);
					if(GetVectorLength(distance_iEntity) <= Radius - 100)
					{
						DealDamage(Client, iEntity, health + 1, -2130706430, "earth_quake");
						num++;
					}
				}
			}
		}
		/*光球术圈内击杀僵尸结束*/
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) < Radius-200)
					{
						DealDamage(Client, i, PHSDDamage[Client], 0 , "chain_lightning");
						TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 10, 5.0, color, 0);
						TE_SendToAll();
						IsChained[i] = true;
						skypos[0] = entpos[0];
						skypos[1] = entpos[1];
						skypos[2] = entpos[2] + 2000.0;
						TE_SetupBeamPoints(skypos, entpos, g_BeamSprite, 0, 0, 0, 2.0, 5.0, 5.0, 3, 1.0, color, 0);
						TE_SendToAll();
						new Handle:newh;
//						CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
						WritePackCell(newh, Client);
						WritePackCell(newh, i);
						WritePackFloat(newh, entpos[0]);
						WritePackFloat(newh, entpos[1]);
						WritePackFloat(newh, entpos[2]);
					}
				}
			}
			if ((IsCommonInfected(i) || IsWitch(i)) && GetEntProp(i, Prop_Data, "m_iHealth")>0)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) < Radius-200)
				{
					DealDamage(Client, i, PHSDDamage[Client], 0, "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 10, 5.0, color, 0);
					TE_SendToAll();
					skypos[0] = entpos[0];
					skypos[1] = entpos[1];
					skypos[2] = entpos[2] + 2000.0;
					TE_SetupBeamPoints(skypos, entpos, g_BeamSprite, 0, 0, 0, 2.0, 5.0, 5.0, 3, 1.0, color, 0);
					TE_SendToAll();
					SetEntProp(i, Prop_Send, "m_bFlashing", 1);

					new Handle:newh;
//					CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	} else
	{
		if (IsValidPlayer(Client) && !IsFakeClient(Client))
		{
			if(HealingBallExp[Client] > 0)
			{
				//治疗光球术经验加成
				//EXP[Client] += HealingBallExp[Client] / 3 + VIPAdd(Client, HealingBallExp[Client] / 3, 1, true);
				//Cash[Client] += HealingBallExp[Client] / 10 + VIPAdd(Client, HealingBallExp[Client] / 20, 1, false);
				//CPrintToChat(Client, MSG_SKILL_HB_END, HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client] / 3, HealingBallExp[Client] / 20);
				//PrintToserver("[United RPG] %s的治疗光球术结束了! 总共治疗了队友%dHP, 获得%dExp, %d$", NameInfo(Client, simple), HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client], HealingBallExp[Client]);
			}
		}
		//HealingBallExp[Client] = 0;
		IsPHSDEnable[Client] = false;
		KillTimer(timer);
		PHSDTimer[Client] = INVALID_HANDLE;
	}
}
/* 献祭 */
public Action:UseXJ(Client, args)
{
	if(GetClientTeam(Client) == 2) XJFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:XJFunction(Client)
{
	if(JD[Client] != 16)
	{
		CPrintToChat(Client, MSG_NEED_JOB16);
		return Plugin_Handled;
	}

	if(XJLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_49);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsXJEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_XJ_ENABLEDKB);
		return Plugin_Handled;
	}

	if(!IsXJReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_XJ) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_XJ), MP[Client]);
		return Plugin_Handled;
	}
	IsXJEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_XJ);

	XJDurationTimer[Client] = CreateTimer(XJDuration[Client], XJDurationFunction, Client);

	CPrintToChatAll(MSG_SKILL_XJ_ANNOUNCEKB, Client, XJLv[Client], XJAFunction(Client));


	return Plugin_Handled;
}

public Action:XJDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	XJDurationTimer[Client] = INVALID_HANDLE;
	IsXJEnable[Client] = false;

	IsXJReady[Client] = false;
	XJCDTimer[Client] = CreateTimer(XJCDTime[Client], XJCDTimerFunction, Client);

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_XJ_ENDKB);
	}

	return Plugin_Handled;
}

public Action:XJCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	XJCDTimer[Client] = INVALID_HANDLE;
	IsXJReady[Client] = true;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_XJ_CHARGEDKB);
	}

	return Plugin_Handled;
}
/* 献祭关联2 */
public Action:XJAFunction(Client)
{
	if(XJALv[Client] == 0)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(JD[Client] != 16)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(XJTimer[Client] != INVALID_HANDLE)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	XJACounter[Client] = 0;
	XJTimer[Client] = CreateTimer(1.0, XJTimerFunction, Client, TIMER_REPEAT);

	CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN, XJALv[Client]);


	return Plugin_Handled;
}

public Action:XJTimerFunction(Handle:timer, any:Client)
{
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance;
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	GetClientAbsOrigin(Client, pos);

	/* Emit impact sound */
//	ShowParticle(pos, FireBall_Particle_Fire01, 5.0);
//	ShowParticle(pos, FireBall_Particle_Fire02, 5.0);
	ShowParticle(pos, FireBall_Particle_Fire03, 5.0);
	new Float:_pos[3];
	GetClientAbsOrigin(Client, _pos);
	pos[0] = _pos[0];
	pos[1] = _pos[1];
	pos[2] = _pos[2]+30.0;
	//(目标, 初始半径(300.0), 最终半径(300.0), 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, 0.1, 400.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, RedColor, 10, 0);//扩散内圈cyanColor
	TE_SendToAll();
	MP[Client] -= 1000;
	XJACounter[Client]++;

	if(XJACounter[Client] <= XJADuration[Client])
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			/*光球术圈内击杀僵尸*/
			new Float:entpos_new[3];
			new Float:distance_iEntity[3];
			new num;
			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if (IsCommonInfected(iEntity))
				{
					new health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
					if (health > 0)
					{
						GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos_new);
						SubtractVectors(entpos_new, pos, distance_iEntity);
						if(GetVectorLength(distance_iEntity) <= 400)
						{
							DealDamage(Client, iEntity, health + 1, 8 , "fire_ball");
							num++;
						}
					}
				}
			}
			/*光球术圈内击杀僵尸结束*/
			if (IsValidPlayer(i))
			{
				if(GetClientTeam(i) == 3)
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					distance = GetVectorDistance(pos, entpos);
					if(distance <=XJLightningRadius[Client])
					DealDamageRepeat(Client, i, XJLightningDamage[Client], 0 , "fire_ball", XJLightningInterval[Client], XJBDuration[Client]);

				}
				else if(IsPlayerAlive(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					distance = GetVectorDistance(pos, entpos);
					if(distance <=XJLightningRadius[Client])
					DealDamageRepeat(Client, i, XJLightningDamage[Client]*0, 0 , "fire_ball");
				}
			}
		}

		for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
		{
			if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
			{
				GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <=XJLightningRadius[Client])
				DealDamage(Client, iEntity, XJLightningDamage[Client], 0 , "fire_ball");
			}
		}
	}
	else
	{
		if (IsValidPlayer(Client))
		{
			CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		}
		KillTimer(timer);
		XJTimer[Client] = INVALID_HANDLE;
	}
	CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN, XJLightningLv[Client]);
	return Plugin_Handled;
}
public Action:XJDamage(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
	new Float:Radius=float(XJLightningRadius[attacker]);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsXJed[victim] = false;
	}

	/* Emit impact Sound */
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(attacker, iEntity, RoundToNearest(XJLightningDamage[attacker]/(EnergyEnhanceEffect_Attack[attacker])), 1024 , "chainkb_lightning");
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(XJLightningInterval[attacker], XJDamage, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsXJed[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(attacker, i, XJLightningDamage[attacker], 1024 , "chainkb_lightning");
					IsXJed[i] = true;

					new Handle:newh;
					CreateDataTimer(XJLightningInterval[attacker], XJDamage, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}

}
//死亡契约
public Action:MenuFunc_AddPHFRA(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习死亡契约,消耗10点技能点 目前等级: %d/%d 发动指令: !qy - 技能点剩余: %d", PHFRALv[Client], LvLimit_PHFRA, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 牺牲自身生命值来恢复MP!");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "损耗比率: 60%");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "恢复比率: 100%");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", PHFRACDTime[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddPHFRA, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddPHFRA(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 10)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(PHFRALv[Client] < LvLimit_PHFRA)
			{
				PHFRALv[Client]++, SkillPoint[Client] -= 10;
				CPrintToChat(Client, MSG_ADD_SKILL_PHFA, PHFRALv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_PHFA_LEVEL_MAX);
			MenuFunc_AddPHFRA(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
//复仇欲望
public Action:MenuFunc_AddPHABA(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习复仇欲望 目前等级: %d/%d 发动指令: !fc - 技能点剩余: %d", PHABALv[Client], LvLimit_PHABA, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 释放强大的复仇欲望,进入狂暴状态 \n曾加自身移动速度");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "增加速度: %.2f%倍", PHABAEffect[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", PHABADuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddPHABA, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddPHABA(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(PHABALv[Client] < LvLimit_PHABA)
			{
				PHABALv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "{olive}[技能] {green}复仇欲望{lightgreen}等级变为{green}Lv.%d{lightgreen}", PHABALv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}复仇欲望\x03等级已经上限!");

			MenuFunc_AddPHABA(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}
//爆破光球
public Action:MenuFunc_AddPHZGA(Client)
{

	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习爆破光球 目前等级: %d/%d 发动指令: !bp - 技能点剩余: %d", PHZGALv[Client], LvLimit_PHZGA, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向准星发射爆破光球, 造成巨大伤害");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", PHZGADamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: 5.0秒");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: 500");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddPHZGA, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;

}
public MenuHandler_AddPHZGA(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(PHZGALv[Client] < LvLimit_PHZGA)
			{
				PHZGALv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_PHZG, PHZGALv[Client]);
				if(PHZGALv[Client]==0) IsPHZGAEnable[Client] = false;
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_PHZG_LEVEL_MAX);
			MenuFunc_AddPHZGA(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//闪电光球
public Action:MenuFunc_AddPHSD(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习闪电光球 目前等级: %d/%d 发动指令: !sd - 技能点剩余: %d", PHSDLv[Client], LvLimit_PHSD, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 【固定伤害：装备不加伤害】向准星位置发射光球，每秒对特感造成一定伤害 \n秒杀范围内普通感染者");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", PHSDDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %d", PHSDRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", PHSDDuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddPHSD, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddPHSD(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(PHSDLv[Client] < LvLimit_PHSD)
			{
				PHSDLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SD, PHSDLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SD_LEVEL_MAX);
			MenuFunc_AddPHSD(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}
//献祭
public Action:MenuFunc_AddXJ(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习献祭 (究极技能只限学习1级,要消耗60技能点)", XJLv[Client], LvLimit_XJ, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明:启动后持续燃烧范围内敌人，每秒消耗1000MP");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧伤害: %d", XJLightningDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧范围: %d", XJLightningRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒.", XJDuration[Client]);
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "冷却时间: %.2f秒", XJCDTime[Client]);
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddXJ, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddXJ(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 60)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(XJLv[Client] < LvLimit_XJ)
			{
				XJLv[Client]++, SkillPoint[Client] -= 60;
				CPrintToChat(Client, MSG_ADD_SKILL_XJ, XJLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_XJ_LEVEL_MAX);
			MenuFunc_AddXJ(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

		/* 祭祀之光 */
public Action:UseLLLZ(Client, args)
{
	if(GetClientTeam(Client) == 2) LLLZFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:LLLZFunction(Client)
{
	if(JD[Client] != 17)
	{
		CPrintToChat(Client, MSG_NEED_JOB17);
		return Plugin_Handled;
	}

	if(LLLZLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_48);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsLLLZEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_LZ_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_LLLZ) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_LLLZ), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_LLLZ);

	new Float:Radius=float(LLLZRadius[Client]);
	new Float:pos[3];
	GetTracePosition(Client, pos);
	pos[2] += 100.0;
	EmitAmbientSound(HealingBall_Sound_Lanuch, pos);
	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(15), 渲染速率(15), 持续时间(30.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite,g_HaloSprite, 15, 50, 70.0, 40.0, 40.0, WhiteColor, 40, 1);//固定外圈BuleColor
//	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 15, 50, 70.0, 40.0, 40.0, CyanColor, 40, 1);//固定外圈BuleColor
	TE_SendToAll();

	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}

	IsLLLZEnable[Client] = true;

	new Handle:pack;
	LLLZTimer[Client] = CreateDataTimer(LLLZInterval[Client], LLLZTimerFunction, pack, TIMER_REPEAT);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);
	WritePackFloat(pack, GetEngineTime());

	CPrintToChatAll(MSG_SKILL_LZ_ANNOUNCE, Client, LLLZLv[Client]);
	return Plugin_Handled;
}

public Action:LLLZTimerFunction(Handle:timer, Handle:pack)
{
	decl Float:pos[3], Float:entpos[3], Float:distance[3];

	ResetPack(pack);
	new Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);
	new Float:time=ReadPackFloat(pack);
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	EmitAmbientSound(ChainLightning_Sound_launch, pos);
	for(new i = 1; i<5; i++)
	{
		TE_SetupGlowSprite(pos, g_GlowSprite, 1.0, 2.5, 1000);
		TE_SendToAll();
	}

	//new iMaxEntities = GetMaxEntities();
	new Float:Radius=float(LLLZRadius[Client]);

	//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, Radius-0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 10, 1.0, 5.0, 0.0, WhiteColor, 5, 0);//固定外圈BuleColor
	TE_SendToAll();

	if(GetEngineTime() - time < LLLZDuration[Client])
	{
		/*光球术圈内击杀僵尸*/
		new Float:entpos_new[3];
		new iMaxEntities = GetMaxEntities();
		new Float:distance_iEntity[3];
		new Float:skypos[3];
		new num;
		for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
		{
			if (IsCommonInfected(iEntity))
			{
				new health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
				if (health > 0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos_new);
					SubtractVectors(entpos_new, pos, distance_iEntity);
					if(GetVectorLength(distance_iEntity) <= Radius - 100)
					{
						DealDamage(Client, iEntity, health + 1, -2130706430, "earth_quake");
						num++;
					}
				}
			}
		}
		/*光球术圈内击杀僵尸结束*/
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) < Radius-200)
					{
						DealDamage(Client, i, LLLZDamage[Client], 0 , "chain_lightning");
						TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 10, 5.0, color, 0);
						TE_SendToAll();
						IsChained[i] = true;
						skypos[0] = entpos[0];
						skypos[1] = entpos[1];
						skypos[2] = entpos[2] + 2000.0;
						TE_SetupBeamPoints(skypos, entpos, g_BeamSprite, 0, 0, 0, 2.0, 5.0, 5.0, 3, 1.0, color, 0);
						TE_SendToAll();
						new Handle:newh;
//						CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
						WritePackCell(newh, Client);
						WritePackCell(newh, i);
						WritePackFloat(newh, entpos[0]);
						WritePackFloat(newh, entpos[1]);
						WritePackFloat(newh, entpos[2]);
					}
				}
			}
			if ((IsCommonInfected(i) || IsWitch(i)) && GetEntProp(i, Prop_Data, "m_iHealth")>0)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) < Radius-200)
				{
					DealDamage(Client, i, LLLZDamage[Client], 0, "chain_lightning");
					TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.5, 1.0, 1.0, 10, 5.0, color, 0);
					TE_SendToAll();
					skypos[0] = entpos[0];
					skypos[1] = entpos[1];
					skypos[2] = entpos[2] + 2000.0;
					TE_SetupBeamPoints(skypos, entpos, g_BeamSprite, 0, 0, 0, 2.0, 5.0, 5.0, 3, 1.0, color, 0);
					TE_SendToAll();
					SetEntProp(i, Prop_Send, "m_bFlashing", 1);

					new Handle:newh;
//					CreateDataTimer(ChainLightningInterval[Client], ChainDamage, newh);
					WritePackCell(newh, Client);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	} else
	{
		if (IsValidPlayer(Client) && !IsFakeClient(Client))
		{
			if(HealingBallExp[Client] > 0)
			{
				//治疗光球术经验加成
				//EXP[Client] += HealingBallExp[Client] / 3 + VIPAdd(Client, HealingBallExp[Client] / 3, 1, true);
				//Cash[Client] += HealingBallExp[Client] / 10 + VIPAdd(Client, HealingBallExp[Client] / 20, 1, false);
				//CPrintToChat(Client, MSG_SKILL_HB_END, HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client] / 3, HealingBallExp[Client] / 20);
				//PrintToserver("[United RPG] %s的治疗光球术结束了! 总共治疗了队友%dHP, 获得%dExp, %d$", NameInfo(Client, simple), HealingBallExp[Client]*500/GetConVarInt(LvUpExpRate), HealingBallExp[Client], HealingBallExp[Client]);
			}
		}
		//HealingBallExp[Client] = 0;
		IsLLLZEnable[Client] = false;
		KillTimer(timer);
		LLLZTimer[Client] = INVALID_HANDLE;
	}
}

//祭祀之光
public Action:MenuFunc_AddLLLZ(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习祭祀之光 目前等级: %d/%d 发动指令: !lllz - 技能点剩余: %d", LLLZLv[Client], LvLimit_LLLZ, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 【固定伤害：装备不加伤害】向准星位置发射光球，每秒对特感造成一定伤害 \n秒杀范围内普通感染者");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", LLLZDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %d", LLLZRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", LLLZDuration[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddLLLZ, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddLLLZ(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(LLLZLv[Client] < LvLimit_LLLZ)
			{
				LLLZLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_LZ, LLLZLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_LZ_LEVEL_MAX);
			MenuFunc_AddLLLZ(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

/* 魔法冲击 */
public Action:UseLLLE(Client, args)
{
	if(GetClientTeam(Client) == 2) LLLEFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:LLLEFunction(Client)
{
	if(JD[Client] != 17)
	{
		CPrintToChat(Client, MSG_NEED_JOB17);
		return Plugin_Handled;
	}

	if(LLLELv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_40);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(!IsLLLEmissReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_LLLE) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_LLLE), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_LLLE);

	new Float:pos[3];
	GetTracePosition(Client, pos);
	EmitAmbientSound(SOUND_TRACINGMISS, pos);

	IsLLLEmissReady[Client] = false;

	new Handle:pack;
	CreateDataTimer(LLLELaunchTime, LLLETimerFunction, pack);
	WritePackCell(pack, Client);
	WritePackFloat(pack, pos[0]);
	WritePackFloat(pack, pos[1]);
	WritePackFloat(pack, pos[2]);

	CPrintToChatAll(MSG_SKILL_LE_ANNOUNCEMISS, Client, LLLELv[Client]);

	return Plugin_Handled;
}

public Action:LLLETimerFunction(Handle:timer, Handle:pack)
{
	new Client;
	new Float:distance;
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];

	ResetPack(pack);
	Client = ReadPackCell(pack);
	pos[0] = ReadPackFloat(pack);
	pos[1] = ReadPackFloat(pack);
	pos[2] = ReadPackFloat(pack);

	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.3, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.3, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.3, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.3, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();
	TE_SetupBeamPoints(pos, entpos, g_BeamSprite, 0, 0, 0, 0.3, 1.0, 1.0, 1, 5.0, GreenColor, 0);
	TE_SendToAll();


	/* Explode */
	LittleFlower(pos, EXPLODE, Client);
	EmitAmbientSound(YLTJ_Sound_Launch, pos);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(0.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(1.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(2.5);
	TE_SetupSparks(pos, NULL_VECTOR, 12, 20);
	TE_SendToAll(3.8);
	for (new i = 1; i <= MaxClients; i++)
    {
        if (IsValidPlayer(i))
        {
			if(GetClientTeam(i) != GetClientTeam(Client) && IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= LLLERadius[Client])
					DealDamage(Client, i, LLLEDamage[Client], 0, "satellite_cannonmiss");

			}
			else if(IsPlayerAlive(i))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <= LLLERadius[Client])
					DealDamage(Client, i, LLLESurvivorDamage[Client], 0, "satellite_cannonmiss");
			}
		}
	}

	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
    {
        if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
        {
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if(distance <= LLLERadius[Client])
				DealDamage(Client, iEntity, RoundToNearest(LLLEDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0, "satellite_cannonmiss");
		}
	}

	LLLEmissCDTimer[Client] = CreateTimer(LLLECDTime[Client], LLLECDTimerFunction, Client);
}
public Action:LLLECDTimerFunction(Handle:timer, any:Client)
{
	LLLEmissCDTimer[Client] = INVALID_HANDLE;
	IsLLLEmissReady[Client] = true;

	if (IsValidPlayer(Client))
		CPrintToChat(Client, MSG_SKILL_SCDE_CHARGEDMISS);

	KillTimer(timer);
}

//魔法冲击
public Action:MenuFunc_AddLLLE(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习魔法冲击 - 目前等级: %d/%d  - 技能点剩余: %d", LLLELv[Client], LvLimit_LLLE, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 对感染者产生强力伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击伤害: %d", LLLEDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "攻击范围: %.1f", LLLERadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.2f秒", LLLECDTime[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddLLLE, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddLLLE(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 1)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(LLLELv[Client] < LvLimit_LLLE)
			{
				LLLELv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_SCMISSDE, LLLELv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_SCDE_LEVEL_MAXMISS);
			MenuFunc_AddLLLE(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//毁灭压制
public Action:MenuFunc_AddLLLS(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习玄冰风暴 目前等级: %d/%d 发动指令: !llls - 技能点剩余: %d", LLLSLv[Client], LvLimit_LLLS, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向准心放出毁灭压制, 冻结范围内敌人 40秒冷却");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻持续: %.2f秒", LLLSDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻伤害: %d", LLLSDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻范围: %d", LLLSRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddLLLS, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddLLLS(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(LLLSLv[Client] < LvLimit_LLLS)
			{
				LLLSLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_IBD, LLLSLv[Client], LLLSDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_IBD_LEVEL_MAX);
			MenuFunc_AddLLLS(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

/* 致命压制 */
public Action:UseLLLS(Client, args)
{
	if(GetClientTeam(Client) == 2) LLLSFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:LLLSFunction(Client)
{
	if(JD[Client] != 17)
	{
		CPrintToChat(Client, MSG_NEED_JOB17);
		return Plugin_Handled;
	}

	if(LLLSLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_35);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if (FreefbCD[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_LLLS) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_LLLS), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_LLLS);
	FreefbCD[Client] = true;
	new ent=CreateEntityByName("tank_rock");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:LLLSPos[3];
	GetClientEyePosition(Client, LLLSPos);
	decl Float:angle[3];
	MakeVectorFromPoints(LLLSPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:LLLSTempPos[3];
	LLLSTempPos[0] = angle[0]*50.0;
	LLLSTempPos[1] = angle[1]*50.0;
	LLLSTempPos[2] = angle[2]*50.0;
	AddVectors(LLLSPos, LLLSTempPos, LLLSPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "80 80 255");

	TeleportEntity(ent, LLLSPos, angle, velocity);
	ActivateEntity(ent);

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateLLLS, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	CPrintToChatAll(MSG_SKILL_LS_ANNOUNCE, Client,LLLSLv[Client]);
	CreateTimer(5.0, Timer_FreefbCD, Client);
	//PrintToserver("[United RPG] %s启动毁灭压制!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdateLLLS(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		if(GetEngineTime() - time > FBZNIceBallLife || DistanceToHit(ent) < 200.0 || v < 200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(LLLSRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			/* Emit impact sound */
			EmitAmbientSound(LLLS_Sound_Impact01, pos);
			EmitAmbientSound(LLLS_Sound_Impact02, pos);

			new Float:SkyLocation[3];
			SkyLocation[0] = pos[0];
			SkyLocation[1] = pos[1];
			SkyLocation[2] = pos[2] + 2000.0;
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, BlueColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 15, 40, 50, 3.7, 3.0, 70.0, 30, 15.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 15, 40, 50, 3.7, 3.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 15, 40, 50, 3.7, 3.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 15, 40, 50, 3.7, 3.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 15, 40, 50, 3.7, 3.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 15, 40, 50, 3.7, 3.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 15, 40, 50, 3.7, 3.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();

			TE_SetupGlowSprite(pos, g_GlowSprite, LLLSDuration[Client], 5.0, 100);
			TE_SendToAll();

			ShowParticle(pos, LLLS_Particle_Ice01, 5.0);

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, RoundToNearest(LLLSDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0 , "ice_ball");
						//FreezePlayer(iEntity, entpos, IceBallDuration[Client]);
						EmitAmbientSound(LLLS_Sound_Freeze, entpos, iEntity, SNDLEVEL_RAIDSIREN);
						TE_SetupGlowSprite(entpos, g_GlowSprite, LLLSDuration[Client], 3.0, 130);
						TE_SendToAll();
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == GetClientTeam(Client))
						continue;

					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, LLLSDamage[Client], 0 , "ice_ball");
							FreezePlayer(i, entpos, LLLSDuration[Client]);
						}
					}
					else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, LLLSTKDamage[Client], 0 , "ice_ball");
							FreezeDPlayer(i, entpos, LLLSDuration[Client]);
						}
					}
				}
			}
			PointPush(Client, pos, 1000, LLLSRadius[Client], 0.5);
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}

//毒龙爆破
public Action:MenuFunc_AddBBBS(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习毒龙爆破 目前等级: %d/%d 发动指令: ！bbbs - 技能点剩余: %d", BBBSLv[Client], LvLimit_BBBS, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 对自身的一定范围内的所有感染者产生爆破伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆破范围: %d", BBBSRange[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆破伤害: %d", BBBSDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.1f", BBBSCD[Client]);

	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddBBBS, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddBBBS(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(BBBSLv[Client] < LvLimit_BBBS)
			{
				BBBSLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "{olive}[技能] {green}毒龙爆破{lightgreen}等级变为{green}Lv.%d{lightgreen}", BBBSLv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}毒龙爆破\x03等级已经上限!");

			MenuFunc_AddBBBS(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}

//毒龙爆破_快捷指令
public Action:UseBBBS(Client, args)
{
	if(GetClientTeam(Client) == 2)
		BBBS_Action(Client);
	else
		CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}


//毒龙爆破_使用
public BBBS_Action(Client)
{
	if(JD[Client] != 14)
	{
		CPrintToChat(Client, MSG_NEED_JOB14);
		return;
	}

	if(BBBSLv[Client] <= 0)
	{
		CPrintToChat(Client, "你没有学习该技能!");
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(BBBS[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return;
	}

	if(MP_BBBS > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_BBBS, MP[Client]);
		return;
	}

	MP[Client] -= MP_BBBS;
	BBBS[Client] = true;
	BBBSAttack(Client);
	CPrintToChatAll("{olive}[技能] {green}%N {blue}启动了{green}Lv.%d{blue}的{olive}幻影爆破{blue}!", Client, BBBSLv[Client]);
	CreateTimer(BBBSCD[Client], BBBS_Stop, Client);
}

//毒龙爆破_冷却
public Action:BBBS_Stop(Handle:timer, any:Client)
{
	if (BBBS[Client])
		BBBS[Client] = false;

	if (IsValidPlayer(Client, false))
		CPrintToChat(Client, "{olive}[技能] {green}幻影爆破{blue}冷却结束了!");

	KillTimer(timer);
}

//毒龙爆破_攻击
public BBBSAttack(Client)
{
	if (!IsValidEntity(Client))
		return;

	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new Float:skypos[3];
	new MaxEnt = GetMaxEntities();

	GetEntPropVector(Client, Prop_Send, "m_vecOrigin", pos);
	SuperTank_LittleFlower(Client, pos, 1);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || !IsValidEntity(i) || i == Client || GetClientTeam(i) == GetClientTeam(Client))
			continue;

		GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
		distance = GetVectorDistance(pos, entpos);
		if (distance <= BBBSRange[Client])
		{
			DealDamage(Client, i, BBBSDamage[Client], 0);
			skypos[0] = entpos[0];
			skypos[1] = entpos[1];
			skypos[2] = entpos[2] + 2000.0;
			TE_SetupBeamPoints(skypos, entpos, g_BeamSprite, 0, 0, 0, 5.0, 5.0, 5.0, 10, 1.0, WhiteColor, 0);
			TE_SendToAll();
		}
	}

	for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
	{
		if(IsValidEntity(iEnt) && IsCommonInfected(iEnt))
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= BBBSRange[Client])
				DealDamage(Client, iEnt, BBBSDamage[Client], 0);
		}

	}
}

//召唤重机枪
public Action:MenuFunc_AddGELIN(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "召唤重机枪 目前等级: %d/%d - 技能点剩余: %d", GELINLv[Client], LvLimit_GELIN, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 召唤出爆菊助手帮你爆坦克菊花!.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "当前攻击伤害: %d", GELINMaxDmg[Client]);
	DrawPanelText(menu, line);
	
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHGELIN, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHGELIN(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(GELINLv[Client] < LvLimit_GELIN)
			{
				GELINLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_HG, GELINLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_HG_LEVEL_MAX);
			MenuFunc_AddGELIN(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

//幻影剑舞
public Action:MenuFunc_AddHYJW(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习幻影剑舞 目前等级: %d/%d 发动指令: !hyjw - 技能点剩余: %d", HYJWLv[Client], LvLimit_HYJW, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: [牺牲所有防御力去提升近战攻速]和[劈砍伤害]");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒", HYJWDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "提速比率: %.2f%%劈砍伤害: %d", 1.0 + HYJWEffect[Client],DMG_MELEE[Client]);
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHYJW, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHYJW(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(HYJWLv[Client] < LvLimit_HYJW)
			{
				HYJWLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_HYJW_MS, HYJWLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_HYJW_MS_LEVEL_MAX);
			MenuFunc_AddHYJW(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

/* 幻影剑舞 */
public Action:UseHYJW(Client, args)
{
	if(GetClientTeam(Client) == 2) HYJWFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:HYJWFunction(Client)
{
	if(JD[Client] != 18)
	{
		CPrintToChat(Client, MSG_NEED_JOB18);
		return Plugin_Handled;
	}

	if(HYJWLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_51);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsHYJWEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_MS_ENABLED);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_HYJW) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_HYJW), MP[Client]);
		return Plugin_Handled;
	}

	if(IsBioShieldEnable[Client])
	{
		PrintHintText(Client, MSG_SKILL_BS_NO_SKILL);
		return Plugin_Handled;
	}

	IsHYJWEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_HYJW);

	HYJWDurationTimer[Client] = CreateTimer(HYJWDuration[Client], HYJWDurationFunction, Client);

	CPrintToChatAll(MSG_SKILL_MS_HYJW, Client, HYJWLv[Client]);

	//PrintToserver("[United RPG] %s启动近战嗜血术!", NameInfo(Client, simple));

	return Plugin_Handled;
}

public Action:HYJWDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	HYJWDurationTimer[Client] = INVALID_HANDLE;
	IsHYJWEnable[Client] = false;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MS_END);
	}

	return Plugin_Handled;
}

//怒气爆发
public Action:MenuFunc_AddNQBF(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习怒气爆发 目前等级: %d/%d 发动指令: ！nqbf - 技能点剩余: %d", NQBFLv[Client], LvLimit_NQBF, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 对自身的造成一定伤害后给予敌人爆发性伤害.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆破范围: %d", NQBFRange[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "爆破伤害: %d", NQBFDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冷却时间: %.1f", NQBFCD[Client]);

	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddNQBF, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddNQBF(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)
				CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(NQBFLv[Client] < LvLimit_NQBF)
			{
				NQBFLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, "{olive}[技能] {green}怒气爆发{lightgreen}等级变为{green}Lv.%d{lightgreen}", NQBFLv[Client]);
			}
			else
				CPrintToChat(Client, "\x03[技能] {green}怒气爆发\x03等级已经上限!");

			MenuFunc_AddNQBF(Client);
		}
		else
			MenuFunc_SurvivorSkill(Client);
	}
}

//怒气爆发_快捷指令
public Action:UseNQBF(Client, args)
{
	if(GetClientTeam(Client) == 2)
		NQBF_Action(Client);
	else
		CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}


//怒气爆发_使用
public NQBF_Action(Client)
{
	if(JD[Client] != 18)
	{
		CPrintToChat(Client, MSG_NEED_JOB18);
		return;
	}

	if(NQBFLv[Client] <= 0)
	{
		CPrintToChat(Client, "你没有学习该技能!");
		return;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return;
	}

	if(NQBF[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return;
	}

	if(MP_NQBF > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, MP_NQBF, MP[Client]);
		return;
	}

	MP[Client] -= MP_NQBF;
	NQBF[Client] = true;
	NQBFAttack(Client);
	CPrintToChatAll("{olive}[技能] {green}%N {blue}启动了{green}Lv.%d{blue}的{olive}怒气爆发{blue}!", Client, NQBFLv[Client]);
	CreateTimer(NQBFCD[Client], NQBF_Stop, Client);
}

//怒气爆发_冷却
public Action:NQBF_Stop(Handle:timer, any:Client)
{
	if (NQBF[Client])
		NQBF[Client] = false;

	if (IsValidPlayer(Client, false))
		CPrintToChat(Client, "{olive}[技能] {green}幻影爆破{blue}冷却结束了!");

	KillTimer(timer);
}

//怒气爆发_攻击
public NQBFAttack(Client)
{
	if (!IsValidEntity(Client))
		return;

	new Float:pos[3];
	new Float:entpos[3];
	new Float:distance;
	new Float:skypos[3];
	new MaxEnt = GetMaxEntities();

	GetEntPropVector(Client, Prop_Send, "m_vecOrigin", pos);
	SuperTank_LittleFlower(Client, pos, 1);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i) || !IsValidEntity(i) || i == Client || GetClientTeam(i) == GetClientTeam(Client))
			continue;

		GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
		distance = GetVectorDistance(pos, entpos);
		if (distance <= NQBFRange[Client])
		{
			DealDamage(Client, i, NQBFDamage[Client], 0);
			skypos[0] = entpos[0];
			skypos[1] = entpos[1];
			skypos[2] = entpos[2] + 2000.0;
			TE_SetupBeamPoints(skypos, entpos, g_BeamSprite, 0, 0, 0, 5.0, 5.0, 5.0, 10, 1.0, WhiteColor, 0);
			TE_SendToAll();
		}
	}

	for (new iEnt = MaxClients + 1; iEnt <= MaxEnt; iEnt++)
	{
		if(IsValidEntity(iEnt) && IsCommonInfected(iEnt))
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", entpos);
			distance = GetVectorDistance(pos, entpos);
			if (distance <= NQBFRange[Client])
				DealDamage(Client, iEnt, NQBFDamage[Client], 0);
		}

	}
}

/* 血之狂暴 */
public Action:UseXZKB(Client, args)
{
	if(GetClientTeam(Client) == 2) XZKBFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
	return Plugin_Handled;
}

public Action:XZKBFunction(Client)
{
	if(JD[Client] != 18)
	{
		CPrintToChat(Client, MSG_NEED_JOB18);
		return Plugin_Handled;
	}

	if(XZKBLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_52);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if(IsXZKBEnable[Client])
	{
		CPrintToChat(Client, MSG_SKILL_XZKB_ENABLEDKB);
		return Plugin_Handled;
	}

	if(!IsXZKBReady[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_XZKB) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_XZKB), MP[Client]);
		return Plugin_Handled;
	}
	IsXZKBEnable[Client] = true;
	MP[Client] -= GetConVarInt(Cost_XZKB);

	XZKBDurationTimer[Client] = CreateTimer(XZKBDuration[Client], XZKBDurationFunction, Client);

	CPrintToChatAll(MSG_SKILL_XZKB_ANNOUNCEKB, Client, XZKBLv[Client], XZKBAFunction(Client));


	return Plugin_Handled;
}

public Action:XZKBDurationFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	XZKBDurationTimer[Client] = INVALID_HANDLE;
	IsXZKBEnable[Client] = false;

	IsXZKBReady[Client] = false;
	XZKBCDTimer[Client] = CreateTimer(XZKBCDTime[Client], XZKBCDTimerFunction, Client);

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_XZKB_ENDKB);
	}

	return Plugin_Handled;
}

public Action:XZKBCDTimerFunction(Handle:timer, any:Client)
{
	KillTimer(timer);
	XZKBCDTimer[Client] = INVALID_HANDLE;
	IsXZKBReady[Client] = true;

	if (IsValidPlayer(Client))
	{
		CPrintToChat(Client, MSG_SKILL_XZKB_CHARGEDKB);
	}

	return Plugin_Handled;
}
/* 血之狂暴 */
public Action:XZKBAFunction(Client)
{
	if(XZKBALv[Client] == 0)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(JD[Client] != 18)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	if(XZKBTimer[Client] != INVALID_HANDLE)
	{
		CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		return Plugin_Handled;
	}

	XZKBACounter[Client] = 0;
	XZKBTimer[Client] = CreateTimer(1.0, XZKBTimerFunction, Client, TIMER_REPEAT);

	CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN, XZKBALv[Client]);


	return Plugin_Handled;
}

public Action:XZKBTimerFunction(Handle:timer, any:Client)
{
	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance;
	new iMaxEntities = GetMaxEntities();
	decl Float:pos[3], Float:entpos[3];
	GetClientAbsOrigin(Client, pos);

	/* Emit impact sound */
//	ShowParticle(pos, FireBall_Particle_Fire01, 5.0);
//	ShowParticle(pos, FireBall_Particle_Fire02, 5.0);
	ShowParticle(pos, FireBall_Particle_Fire03, 5.0);
	new Float:_pos[3];
	GetClientAbsOrigin(Client, _pos);
	pos[0] = _pos[0];
	pos[1] = _pos[1];
	pos[2] = _pos[2]+30.0;
	//(目标, 初始半径(300.0), 最终半径(300.0), 效果1, 效果2, 渲染贴(0), 渲染速率(15), 持续时间(10.0), 播放宽度(20.0),播放振幅(0.0), 颜色(Color[4]), (播放速度)10, (标识)0)
	TE_SetupBeamRingPoint(pos, 0.3, 600.0, g_BeamSprite, g_HaloSprite, 200, 35, 0.7, 13.0, 300.2000, RedColor, 90, 0);//扩散内圈cyanColor
	TE_SendToAll();
	MP[Client] -= 20;

	XZKBACounter[Client]++;

	if(XZKBACounter[Client] <= XZKBADuration[Client])
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			/*光球术圈内击杀僵尸*/
			new Float:entpos_new[3];
			new Float:distance_iEntity[3];
			new num;
			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if (IsCommonInfected(iEntity))
				{
					new health = GetEntProp(iEntity, Prop_Data, "m_iHealth");
					if (health > 0)
					{
						GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos_new);
						SubtractVectors(entpos_new, pos, distance_iEntity);
						if(GetVectorLength(distance_iEntity) <= 400)
						{
							DealDamage(Client, iEntity, health + 0, 0 , "fire_ball");
							num++;
						}
					}
				}
			}
			/*光球术圈内击杀僵尸结束*/
			if (IsValidPlayer(i))
			{
				if(GetClientTeam(i) == 3)
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					distance = GetVectorDistance(pos, entpos);
					if(distance <=XZKBLightningRadius[Client])
					DealDamageRepeat(Client, i, XZKBLightningDamage[Client], 0 , "fire_ball", XZKBLightningInterval[Client], XZKBBDuration[Client]);

				}
				else if(IsPlayerAlive(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
					distance = GetVectorDistance(pos, entpos);
					if(distance <=XZKBLightningRadius[Client])
					DealDamageRepeat(Client, i, XZKBLightningDamage[Client]*0, 0 , "fire_ball");
				}
			}
		}

		for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
		{
			if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
			{
				GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
				distance = GetVectorDistance(pos, entpos);
				if(distance <=XZKBLightningRadius[Client])
				DealDamage(Client, iEntity, XZKBLightningDamage[Client], 0 , "fire_ball");
			}
		}
	}
	else
	{
		if (IsValidPlayer(Client))
		{
			CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN);
		}
		KillTimer(timer);
		XZKBTimer[Client] = INVALID_HANDLE;
	}
	CPrintToChat(Client, MSG_SKILL_MEIXINXI_NOGUN, XZKBLightningLv[Client]);
	return Plugin_Handled;
}
public Action:XZKBDamage(Handle:timer, Handle:h)
{
	decl Float:pos[3];
	ResetPack(h);
	new attacker=ReadPackCell(h);
	new victim=ReadPackCell(h);
	pos[0] = ReadPackFloat(h);
	pos[1] = ReadPackFloat(h);
	pos[2] = ReadPackFloat(h);

	decl color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 128;

	new Float:distance[3];
	new iMaxEntities = GetMaxEntities();
	decl Float:entpos[3];
	new Float:Radius=float(XZKBLightningRadius[attacker]);
	if(victim >= MaxClients + 1)
	{
		if ((IsCommonInfected(victim) || IsWitch(victim)) && GetEntProp(victim, Prop_Data, "m_iHealth")>0)	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);
		if((IsCommonInfected(victim) || IsWitch(victim)))	SetEntProp(victim, Prop_Send, "m_bFlashing", 0);
	} else
	{
		if(IsClientInGame(victim) && IsPlayerAlive(victim) && !IsPlayerGhost(victim))	GetClientAbsOrigin(victim, pos);
		IsXZKBed[victim] = false;
	}

	/* Emit impact Sound */
	for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
	{
		if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0 && iEntity != victim && GetEntProp(iEntity, Prop_Send, "m_bFlashing") != 1)
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
			SubtractVectors(entpos, pos, distance);
			if(GetVectorLength(distance) <= Radius)
			{
				DealDamage(attacker, iEntity, RoundToNearest(XZKBLightningDamage[attacker]/(EnergyEnhanceEffect_Attack[attacker])), 1024 , "chainkb_lightning");
				SetEntProp(iEntity, Prop_Send, "m_bFlashing", 1);

				new Handle:newh;
				CreateDataTimer(XZKBLightningInterval[attacker], XZKBDamage, newh);
				WritePackCell(newh, attacker);
				WritePackCell(newh, iEntity);
				WritePackFloat(newh, entpos[0]);
				WritePackFloat(newh, entpos[1]);
				WritePackFloat(newh, entpos[2]);
			}
		}
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i) && i != victim && !IsXZKBed[i])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
				SubtractVectors(entpos, pos, distance);
				if(GetVectorLength(distance) <= Radius)
				{
					DealDamage(attacker, i, XZKBLightningDamage[attacker], 1024 , "chainkb_lightning");
					IsXZKBed[i] = true;

					new Handle:newh;
					CreateDataTimer(XZKBLightningInterval[attacker], XZKBDamage, newh);
					WritePackCell(newh, attacker);
					WritePackCell(newh, i);
					WritePackFloat(newh, entpos[0]);
					WritePackFloat(newh, entpos[1]);
					WritePackFloat(newh, entpos[2]);
				}
			}
		}
	}
}

//献祭
public Action:MenuFunc_AddXZKB(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习献祭 (究极技能只限学习1级,要消耗1技能点)", XZKBLv[Client], LvLimit_XZKB, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明:启动后持续燃烧范围内敌人，每秒消耗1000MP");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧伤害: %d", XZKBLightningDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "燃烧范围: %d", XZKBLightningRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "持续时间: %.2f秒.", XZKBDuration[Client]);
	DrawPanelText(menu, line);

	Format(line, sizeof(line), "冷却时间: %.2f秒", XZKBCDTime[Client]);
	DrawPanelText(menu, line);

	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddXZKB, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddXZKB(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] < 1)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(XZKBLv[Client] < LvLimit_XZKB)
			{
				XZKBLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_XZKB, XZKBLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_XZKB_LEVEL_MAX);
			MenuFunc_AddXZKB(Client);
		} else MenuFunc_SurvivorSkill(Client);
    }
}


//极冰盛宴
public Action:MenuFunc_AddJBSY(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "学习极冰盛宴 目前等级: %d/%d 发动指令: !jbsy - 技能点剩余: %d", JBSYLv[Client], LvLimit_JBSY, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 向准心放出玄冰风暴, 冻结范围内敌人 40秒冷却");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻持续: %.2f秒", JBSYDuration[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻伤害: %d", JBSYDamage[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "冰冻范围: %d", JBSYRadius[Client]);
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "加成属性: 智力");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");

	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddJBSY, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddJBSY(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(JBSYLv[Client] < LvLimit_JBSY)
			{
				JBSYLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_JBSY, JBSYLv[Client], JBSYDamage[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_JBSY_LEVEL_MAX);
			MenuFunc_AddJBSY(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}


/* 极冰盛宴 */
public Action:UseJBSY(Client, args)
{
	if(GetClientTeam(Client) == 2) JBSYFunction(Client);
	else CPrintToChat(Client, MSG_SKILL_USE_SURVIVORS_ONLY);
}

public Action:JBSYFunction(Client)
{
	if(JD[Client] != 13)
	{
		CPrintToChat(Client, MSG_NEED_JOB13);
		return Plugin_Handled;
	}

	if(JBSYLv[Client] == 0)
	{
		CPrintToChat(Client, MSG_NEED_SKILL_53);
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(Client))
	{
		CPrintToChat(Client, MSG_PLAYER_DIE);
		return Plugin_Handled;
	}

	if (FreefbCD[Client])
	{
		CPrintToChat(Client, MSG_SKILL_CHARGING);
		return Plugin_Handled;
	}

	if(GetConVarInt(Cost_JBSY) > MP[Client])
	{
		PrintHintText(Client, MSG_SKILL_LACK_MP, GetConVarInt(Cost_JBSY), MP[Client]);
		return Plugin_Handled;
	}

	MP[Client] -= GetConVarInt(Cost_JBSY);
	FreefbCD[Client] = true;
	new ent=CreateEntityByName("tank_rock");
	DispatchSpawn(ent);
	decl Float:TracePos[3];
	GetTracePosition(Client, TracePos);
	decl Float:JBSYPos[3];
	GetClientEyePosition(Client, JBSYPos);
	decl Float:angle[3];
	MakeVectorFromPoints(JBSYPos, TracePos, angle);
	NormalizeVector(angle, angle);

	decl Float:JBSYTempPos[3];
	JBSYTempPos[0] = angle[0]*50.0;
	JBSYTempPos[1] = angle[1]*50.0;
	JBSYTempPos[2] = angle[2]*50.0;
	AddVectors(JBSYPos, JBSYTempPos, JBSYPos);

	decl Float:velocity[3];
	velocity[0] = angle[0]*2000.0;
	velocity[1] = angle[1]*2000.0;
	velocity[2] = angle[2]*2000.0;

	DispatchKeyValue(ent, "rendercolor", "80 80 255");

	TeleportEntity(ent, JBSYPos, angle, velocity);
	ActivateEntity(ent);

	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
	SetEntityGravity(ent, 0.1);

	new Handle:h;
	CreateDataTimer(0.1, UpdateJBSY, h, TIMER_REPEAT);
	WritePackCell(h, Client);
	WritePackCell(h, ent);
	WritePackFloat(h,GetEngineTime());

	CPrintToChatAll(MSG_SKILL_JBSY_ANNOUNCE, Client, JBSYLv[Client]);
	CreateTimer(3.0, Timer_FreefbCD, Client);
	//PrintToserver("[United RPG] %s启动了冰球术!", NameInfo(Client, simple));

	return Plugin_Handled;
}
public Action:UpdateJBSY(Handle:timer, Handle:h)
{
	ResetPack(h);
	new Client=ReadPackCell(h);
	new ent=ReadPackCell(h);
	new Float:time=ReadPackFloat(h);

	if(IsRock(ent))
	{
		decl Float:vec[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vec);
		new Float:v=GetVectorLength(vec);
		if(GetEngineTime() - time > FBZNIceBallLife || DistanceToHit(ent) < 200.0 || v < 200.0)
		{
			new Float:distance[3];
			new iMaxEntities = GetMaxEntities();
			decl Float:pos[3], Float:entpos[3];
			new Float:Radius=float(JBSYRadius[Client]);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

			RemoveEdict(ent);

			/* Emit impact sound */
			EmitAmbientSound(JBSY_Sound_Impact01, pos);
			EmitAmbientSound(JBSY_Sound_Impact02, pos);

			new Float:SkyLocation[3];
			SkyLocation[0] = pos[0];
			SkyLocation[1] = pos[1];
			SkyLocation[2] = pos[2] + 2000.0;
			//(目标, 初始半径, 最终半径, 效果1, 效果2, 渲染贴, 渲染速率, 持续时间, 播放宽度,播放振幅, 颜色(Color[4]), (播放速度)10, (标识)0)
			TE_SetupBeamRingPoint(pos, 0.1, Radius, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 10.0, 0.0, BlueColor, 10, 0);//固定外圈BuleColor
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 30.0, 30.0, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();
			TE_SetupBeamPoints(SkyLocation, pos, g_BeamSprite, 0, 0, 0, 2.7, 0.1, 0.1, 10, 10.0, BlueColor, 0);
			TE_SendToAll();

			TE_SetupGlowSprite(pos, g_GlowSprite, JBSYDuration[Client], 5.0, 100);
			TE_SendToAll();

			ShowParticle(pos, JBSY_Particle_Ice01, 5.0);

			for (new iEntity = MaxClients + 1; iEntity <= iMaxEntities; iEntity++)
			{
				if ((IsCommonInfected(iEntity) || IsWitch(iEntity)) && GetEntProp(iEntity, Prop_Data, "m_iHealth")>0)
				{
					GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", entpos);
					SubtractVectors(entpos, pos, distance);
					if(GetVectorLength(distance) <= Radius)
					{
						DealDamage(Client, iEntity, RoundToNearest(JBSYDamage[Client]/(EnergyEnhanceEffect_Attack[Client])), 0 , "ice_ball");
						//FreezePlayer(iEntity, entpos, IceBallDuration[Client]);
						EmitAmbientSound(JBSY_Sound_Freeze, entpos, iEntity, SNDLEVEL_RAIDSIREN);
						TE_SetupGlowSprite(entpos, g_GlowSprite, JBSYDuration[Client], 3.0, 130);
						TE_SendToAll();
					}
				}
			}
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == GetClientTeam(Client))
						continue;

					if(GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsPlayerGhost(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, JBSYDamage[Client], 0 , "ice_ball");
							FreezePlayer(i, entpos, JBSYDuration[Client]);
						}
					}
					else if(GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", entpos);
						SubtractVectors(entpos, pos, distance);
						if(GetVectorLength(distance) <= Radius)
						{
							DealDamage(Client, i, JBSYTKDamage[Client], 0 , "ice_ball");
							FreezeDPlayer(i, entpos, JBSYDuration[Client]);
						}
					}
				}
			}
			PointPush(Client, pos, 1000, JBSYRadius[Client], 0.5);
			return Plugin_Stop;
		}
		return Plugin_Continue;
	} else return Plugin_Stop;
}



//变身坦克
public Action:MenuFunc_AddBSTK(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "变身坦克 目前等级: %d/%d - 技能点剩余: %d", BSTKLv[Client], LvLimit_BSTK, SkillPoint[Client]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "技能说明: 自己变成坦克!.");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "当前攻击伤害: %d", BSTKMaxDmg[Client]);
	DrawPanelText(menu, line);
	
	DrawPanelItem(menu, "学习");
	DrawPanelItem(menu, "返回");
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddHBSTE, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}
public MenuHandler_AddHBSTE(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(param == 1)
		{
			if(SkillPoint[Client] <= 0)	CPrintToChat(Client, MSG_LACK_SKILLS);
			else if(BSTKLv[Client] < LvLimit_BSTK)
			{
				BSTKLv[Client]++, SkillPoint[Client] -= 1;
				CPrintToChat(Client, MSG_ADD_SKILL_HG, BSTKLv[Client]);
			}
			else CPrintToChat(Client, MSG_ADD_SKILL_HG_LEVEL_MAX);
			MenuFunc_AddBSTK(Client);
		} else MenuFunc_SurvivorSkill(Client);
	}
}

/* 给予新人保护BUFF */
public GiveAllRookieBuff()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i, false, false) && PLAYER_LV[i] <= RookieBuff_MinLv)
		{
			if (!HasBuffPlayer[i])
			{
				HasBuffPlayer[i] = true;
				new buffhealth = GetEntProp(i, Prop_Data, "m_iMaxHealth");
				SetEntProp(i, Prop_Data, "m_iMaxHealth", buffhealth >= 100 ? buffhealth + RookieBuff_Health : 100 + RookieBuff_Health);
				new Float:speedbuff = GetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue");
				SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", speedbuff >= 1.0 ? speedbuff + RookieBuff_Speed : 1.0 + RookieBuff_Speed);
				CheatCommand(i, "give", "health");
				PrintHintText(i, "你已获得了[新人Buff]加成,生命值增加 %d, 移动速度增加 %.1f.", RookieBuff_Health, RookieBuff_Speed);
			}
		}
	}
}

/* 还原新人保护BUFF */
public ResetAllRookieBuff()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i, false, false))
		{
			RebuildStatus(i, false);
			HasBuffPlayer[i] = false;
		}
	}
}

/* 保存服务器时间日志 */
stock SaveServerTimeLog(bool:changemap = false)
{
	decl String:t_date[12], String:t_time[12], String:t_text[32], String:t_map[32];
	FormatTime(t_date, sizeof(t_date), "%Y-%m-%d");
	FormatTime(t_time, sizeof(t_time), "%X");
	Format(t_text, sizeof(t_text), "|%s|%s|", t_date, t_time);
	GetCurrentMap(t_map, sizeof(t_map));
	KvJumpToKey(ServerTimeLog, t_text, true);
	if (!changemap)
		KvSetString(ServerTimeLog, "map", t_map);
	else
		KvSetString(ServerTimeLog, "map", "playerchange");
	KvRewind(ServerTimeLog);
	KeyValuesToFile(ServerTimeLog, ServerTimePath);
}

/* 快捷_每日签到 */
public Action:Command_QianDao(Client, args)
{
	PlayerSignXHToday(Client);
	return Plugin_Handled;
}

/* 每日签到 */
public PlayerSignXHToday(Client)
{
	if (IsValidPlayer(Client) && IsPasswordConfirm[Client])
	{
		new today = GetToday();
		if (today > 0 && EveryDaySign[Client] > -1 && EveryDaySign[Client] != today && everyday1[Client] <= 15)
		{
			EveryDaySign[Client] = today;
			EXP[Client] += SIGNAWARD_EXP[Client];
			Cash[Client] += SIGNAWARD_CASH[Client];
			PlayerItem[Client][ITEM_XH][5] += 1;
			everyday1[Client] += 1;
			
			//by MicroLeo
			if(GetConVarBool(h_ArchiveSys))
			{
				SQLiteArchiveSys_ClientSaveToFileSave(Client,false);
			}
			else
			{
				ClientSaveToFileSave(Client);
			}
			//end
			
			CPrintToChatAll("{olive}[每日签到]\x05玩家 \x03 %N \x05已经在今日签到了,获得奖励\x03%dEXP,%d$\x05和\x03随机卷轴\x05!积累签到:%d次", Client, SIGNAWARD_EXP[Client], SIGNAWARD_CASH[Client], everyday1[Client]);
		}
		if (today > 0 && EveryDaySign[Client] > -1 && EveryDaySign[Client] != today && everyday1[Client] <= 15 && VIP[Client] >= 4)
		{
			EveryDaySign[Client] = today;
			EXP[Client] += SIGNAWARD_VIPEXP[Client];
			Cash[Client] += SIGNAWARD_VIPCASH[Client];
			PlayerItem[Client][ITEM_XH][5] += 5;
			everyday1[Client] += 1;
			XB[Client] += 1;
			
			//by MicroLeo
			if(GetConVarBool(h_ArchiveSys))
			{
				SQLiteArchiveSys_ClientSaveToFileSave(Client,false);
			}
			else
			{
				ClientSaveToFileSave(Client);
			}
			//end
			
			CPrintToChatAll("{olive}[每日签到]\x05玩家 \x03 %N \x05已经在今日签到了,获得奖励\x03%dEXP,%d$\x05和\x03随机卷轴\x05!积累签到:%d次 求生币:%d个", Client, SIGNAWARD_EXP[Client], SIGNAWARD_CASH[Client], everyday1[Client], XB[Client]);
		}
		else
			PrintHintText(Client, "[温馨提示]你今日已经签到过了或者您的积累签到次数没有使用,请明天再来签到!");
	}
	else
	{
		CPrintToChat(Client, "\x03【温馨提示】请登录游戏后再签到!");
	}
}

/******************************************************
*	结束
*******************************************************/