public Menu SpecialMenu(int client)
{
	N_MenuSpecialMenu[client] = new Menu(SpecialMenuHandler);
	char line[2048];
	
	if(NCvar[CSpecial_PluginStatus].BoolValue)
		Format(line, sizeof(line), "+|NS|+ 特感玩家菜单\n刷特进程[%s]\n特感数量[%d] 刷特时间[%d]", !GetSpecialRunning() ? "未开始" : "已开始", GetSpecialMax(), GetSpecialRespawnInterval());
	else
		Format(line, sizeof(line), "+|NS|+ 特感菜单\n插件已关闭");
		
	N_MenuSpecialMenu[client].SetTitle(line);

	Format(line, sizeof(line), "插件目前状态 [%s]", !NCvar[CSpecial_PluginStatus].BoolValue ? "关" : "开");
	N_MenuSpecialMenu[client].AddItem("tgstat", line);

	if(NCvar[CSpecial_PluginStatus].BoolValue)
	{
		Format(line, sizeof(line), "随机特感状态 [%s]", !NCvar[CSpecial_Random_Mode].BoolValue ? "关" : "开");
		N_MenuSpecialMenu[client].AddItem("tgrandom", line);
		
		Format(line, sizeof(line), "快速反应状态 [%s]", !GetSpecialAssault() ? "关" : "开");
		N_MenuSpecialMenu[client].AddItem("tgfast", line);

		char nowmode[64], spawnmode[64];
		
		switch(NCvar[CSpecial_Default_Mode].IntValue)
		{
			case 1: Format(nowmode, sizeof(nowmode), "猎人");
			case 2: Format(nowmode, sizeof(nowmode), "牛子");
			case 3: Format(nowmode, sizeof(nowmode), "猴子");
			case 4: Format(nowmode, sizeof(nowmode), "口水");
			case 5: Format(nowmode, sizeof(nowmode), "胖子");
			case 6: Format(nowmode, sizeof(nowmode), "舌头");
			default: Format(nowmode, sizeof(nowmode), "默认");
		}
		Format(line, sizeof(line), "特感游戏模式 [%s]", nowmode);
		N_MenuSpecialMenu[client].AddItem("tgmode", line);
		
		switch(GetSpecialSpawnMode())
		{
			case 0: Format(spawnmode, sizeof(spawnmode), "引擎");
			case 1: Format(spawnmode, sizeof(spawnmode), "普通");
			case 2: Format(spawnmode, sizeof(spawnmode), "噩梦");
			case 3: Format(spawnmode, sizeof(spawnmode), "地狱");
		}
		Format(line, sizeof(line), "特感刷新模式 [%s]", spawnmode);
		N_MenuSpecialMenu[client].AddItem("tgspawn", line);

		if(GetSpecialSpawnMode() != 0)
		{
			char ismode[64];
			switch(NCvar[CSpecial_IsModeInNormal].IntValue)
			{
				case 1: Format(ismode, sizeof(ismode), "1");
				case 2: Format(ismode, sizeof(ismode), "2");
			}
			Format(line, sizeof(line), "刷特子模式 [%s]", ismode);
			N_MenuSpecialMenu[client].AddItem("ismodenormal", line);
		}
		
		Format(line, sizeof(line), "全局刷特时间 [%ds]", NCvar[CSpecial_Spawn_Time].IntValue);
		if(!NCvar[CSpecial_Spawn_Time_DifficultyChange].BoolValue)
			N_MenuSpecialMenu[client].AddItem("tgtime", line);
		else
			N_MenuSpecialMenu[client].AddItem("tgtime", line, ITEMDRAW_DISABLED);
	
		Format(line, sizeof(line), "初始刷特数量 [%d]", NCvar[CSpecial_Num].IntValue);
		N_MenuSpecialMenu[client].AddItem("tgnum", line);
	
		Format(line, sizeof(line), "进人增加数量 [%d]", NCvar[CSpecial_AddNum].IntValue);
		N_MenuSpecialMenu[client].AddItem("tgadd", line);
		
		Format(line, sizeof(line), "初始玩家数量 [%d]", NCvar[CSpecial_PlayerNum].IntValue);
		N_MenuSpecialMenu[client].AddItem("tgpnum", line);
	
		Format(line, sizeof(line), "玩家增加数量 [%d]", NCvar[CSpecial_PlayerAdd].IntValue);
		N_MenuSpecialMenu[client].AddItem("tgpadd", line);
		
		Format(line, sizeof(line), "是否算入观察 [%s]", !NCvar[CSpecial_PlayerCountSpec].BoolValue ? "否" : "是");
		N_MenuSpecialMenu[client].AddItem("tgpcspec", line);
		
		Format(line, sizeof(line), "不算死亡玩家 [%s]", !NCvar[CSpecial_Num_NotCul_Death].BoolValue ? "否" : "是");
		N_MenuSpecialMenu[client].AddItem("tgnculdea", line);

		Format(line, sizeof(line), "克活着时刷新 [%s]", !NCvar[CSpecial_Spawn_Tank_Alive].BoolValue ? "否" : "是");
		N_MenuSpecialMenu[client].AddItem("tgtanklive", line);

		if(!NCvar[CSpecial_Spawn_Tank_Alive].BoolValue)
		{
			Format(line, sizeof(line), "克存活踢出特感");
			N_MenuSpecialMenu[client].AddItem("tgtankprolive", line);
		}
		
		Format(line, sizeof(line), "根据难度改变刷特时间 [%s]", !NCvar[CSpecial_Spawn_Time_DifficultyChange].BoolValue ? "否" : "是");
		N_MenuSpecialMenu[client].AddItem("tgautotime", line);

		if(NCvar[CSpecial_Spawn_Time_DifficultyChange].BoolValue)
		{
			Format(line, sizeof(line), "简单难度刷特时间 [%d]", NCvar[CSpecial_Spawn_Time_Easy].IntValue);
			N_MenuSpecialMenu[client].AddItem("tgtimeeasy", line);
			
			Format(line, sizeof(line), "普通难度刷特时间 [%d]", NCvar[CSpecial_Spawn_Time_Normal].IntValue);
			N_MenuSpecialMenu[client].AddItem("tgtimenormal", line);
			
			Format(line, sizeof(line), "高级难度刷特时间 [%d]", NCvar[CSpecial_Spawn_Time_Hard].IntValue);
			N_MenuSpecialMenu[client].AddItem("tgtimehard", line);
			
			Format(line, sizeof(line), "专家难度刷特时间 [%d]", NCvar[CSpecial_Spawn_Time_Impossible].IntValue);
			N_MenuSpecialMenu[client].AddItem("tgtimeexpert", line);
		}
		
		Format(line, sizeof(line), "特感种类数量 [默认模式]");
		N_MenuSpecialMenu[client].AddItem("tgcustom", line);

		Format(line, sizeof(line), "特感刷新几率");
		N_MenuSpecialMenu[client].AddItem("tgcustomweight", line);

		if(GetSpecialSpawnMode() > 1)
		{
			Format(line, sizeof(line), "特感刷新方位");
			N_MenuSpecialMenu[client].AddItem("tgcustomdirchance", line);

			Format(line, sizeof(line), "特感刷新区域");
			N_MenuSpecialMenu[client].AddItem("tgcustomspawnarea", line);

			Format(line, sizeof(line), "特感刷新最大距离");
			N_MenuSpecialMenu[client].AddItem("tgcustommaxdis", line);

			Format(line, sizeof(line), "特感刷新最小距离");
			N_MenuSpecialMenu[client].AddItem("tgcustommindis", line);
		}
		else
		{
			Format(line, sizeof(line), "特感刷新最大距离 [%d]", GetSpecialSpawnMaxDis_());
			N_MenuSpecialMenu[client].AddItem("tgcustommaxdisnor", line);

			Format(line, sizeof(line), "特感刷新最小距离 [%d]", GetSpecialSpawnMinDis_());
			N_MenuSpecialMenu[client].AddItem("tgcustommindisnor", line);

			Format(line, sizeof(line), "游戏预设特感刷新最大距离");
			N_MenuSpecialMenu[client].AddItem("tgcustommaxdisreset", line);

			Format(line, sizeof(line), "游戏预设特感刷新最小距离");
			N_MenuSpecialMenu[client].AddItem("tgcustommindisreset", line);
		}

		Format(line, sizeof(line), "显示插件提示 [%s]", !NCvar[CSpecial_Show_Tips].BoolValue ? "否" : "是");
		N_MenuSpecialMenu[client].AddItem("tgtips", line);

		Format(line, sizeof(line), "使用聊天框提示 [%s]", !NCvar[CSpecial_Show_Tips_Chat].BoolValue ? "否" : "是");
		N_MenuSpecialMenu[client].AddItem("tgtipschat", line);
	}
	
	Format(line, sizeof(line), "重载配置文件");
	N_MenuSpecialMenu[client].AddItem("tgreload", line);

	Format(line, sizeof(line), "写入配置文件");
	N_MenuSpecialMenu[client].AddItem("tgfilewr", line);

	Format(line, sizeof(line), "重置配置文件");
	N_MenuSpecialMenu[client].AddItem("tgreset", line);
	
	Format(line, sizeof(line), "具体如何设置请查看CFG\n或插件说明\n插件版本:%s", PLUGIN_VERSION);
	N_MenuSpecialMenu[client].AddItem("info", line, ITEMDRAW_DISABLED);
	
	N_MenuSpecialMenu[client].ExitBackButton = true;
	return N_MenuSpecialMenu[client];
}

public int SpecialMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(client))
			{
				MenuPageItem[client] = GetMenuSelectionPosition();
				char items[50];
				N_MenuSpecialMenu[client] = null;
				
				cleanplayerwait(client);
				menu.GetItem(selection, items, sizeof(items));
				
				bool NeedOpenMenu = true;
				
				if(StrEqual(items, "tgstat"))
				{
					SwitchPlugin(client);
				}
				if(StrEqual(items, "tgrandom"))
				{
					SwitchRandom(client);
				}
				if(StrEqual(items, "tgmode"))
				{
					SpecialMenuMode(client);
					NeedOpenMenu = false;
				}
				if(StrEqual(items, "tgspawn"))
				{
					SpecialMenuSpawn(client);
					NeedOpenMenu = false;
				}
				if(StrContains(items, "tgtime", false) != -1)
				{
					WaitingForTgtime[client] = true;
					WaitingForTgTimeType[client] = items;
					PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的时间 \x03范围[3 - 120]", NEKOTAG);
					PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				}
				if(StrEqual(items, "tgnum"))
				{
					WaitingForTgnum[client] = true;
					PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的初始特感数量 \x03范围[1 - 32]", NEKOTAG);
					PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				}
				if(StrEqual(items, "tgadd"))
				{
					WaitingForTgadd[client] = true;
					PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的增加数量 \x03范围[0 - 8]", NEKOTAG);
					PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				}
				if(StrEqual(items, "tgpnum"))
				{
					WaitingForPnum[client] = true;
					PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的初始玩家数量 \x03范围[1 - 32]", NEKOTAG);
					PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				}
				if(StrEqual(items, "tgpadd"))
				{
					WaitingForPadd[client] = true;
					PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的玩家增加数量 \x03范围[0 - 8]", NEKOTAG);
					PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				}
				if(StrEqual(items, "tgcustom"))
				{
					SpecialMenuCustom(client).Display(client, MENU_TIME);
					NeedOpenMenu = false;
				}
				if(StrEqual(items, "tgcustomweight"))
				{
					SpecialMenuCustomWeight(client).Display(client, MENU_TIME);
					NeedOpenMenu = false;
				}
				if(StrEqual(items, "tgcustomdirchance"))
				{
					SpecialMenuCustomDirChance(client).Display(client, MENU_TIME);
					NeedOpenMenu = false;
				}
				if(StrEqual(items, "tgcustomspawnarea"))
				{
					SpecialMenuCustomSpawnArea(client).Display(client, MENU_TIME);
					NeedOpenMenu = false;
				}
				if(StrEqual(items, "tgcustommaxdisnor"))
				{
					WaitingForTgCustomMaxDisNor[client] = true;
					PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置最大距离 \x03范围[不能小于1，不要小于最小距离]", NEKOTAG);
					PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				}
				if(StrEqual(items, "tgcustommindisnor"))
				{
					WaitingForTgCustomMinDisNor[client] = true;
					PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置最小距离 \x03范围[不能小于1，不要超过最大距离]", NEKOTAG);
					PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				}
				if(StrEqual(items, "tgcustommaxdisreset"))
				{
					SetSpecialSpawnMaxDis_default();
				}
				if(StrEqual(items, "tgcustommindisreset"))
				{
					SetSpecialSpawnMinDis_default();
				}
				if(StrEqual(items, "tgcustommaxdis"))
				{
					SpecialMenuCustomMaxDis(client).Display(client, MENU_TIME);
					NeedOpenMenu = false;
				}
				if(StrEqual(items, "tgcustommindis"))
				{
					SpecialMenuCustomMinDis(client).Display(client, MENU_TIME);
					NeedOpenMenu = false;
				}
				if(StrEqual(items, "tgreload"))
				{
					AutoExecConfig_OnceExec();
					SetMaxSpecialsCount();
				}
				if(StrEqual(items, "tgfast"))
					NCvar[CSpecial_Fast_Response].SetBool(!NCvar[CSpecial_Fast_Response].BoolValue);
				if(StrEqual(items, "tgpcspec"))
					NCvar[CSpecial_PlayerCountSpec].SetBool(!NCvar[CSpecial_PlayerCountSpec].BoolValue);
				if(StrEqual(items, "tgnculdea"))
					NCvar[CSpecial_Num_NotCul_Death].SetBool(!NCvar[CSpecial_Num_NotCul_Death].BoolValue);
				if(StrEqual(items, "tgtanklive"))
					NCvar[CSpecial_Spawn_Tank_Alive].SetBool(!NCvar[CSpecial_Spawn_Tank_Alive].BoolValue);
				if(StrEqual(items, "tgtankprolive"))
					NCvar[CSpecial_Spawn_Tank_Alive_Pro].SetBool(!NCvar[CSpecial_Spawn_Tank_Alive_Pro].BoolValue);
				if(StrEqual(items, "tgtips"))
					NCvar[CSpecial_Show_Tips].SetBool(!NCvar[CSpecial_Show_Tips].BoolValue);
				if(StrEqual(items, "tgtipschat"))
					NCvar[CSpecial_Show_Tips_Chat].SetBool(!NCvar[CSpecial_Show_Tips_Chat].BoolValue);
				if(StrEqual(items, "tgautotime"))
					NCvar[CSpecial_Spawn_Time_DifficultyChange].SetBool(!NCvar[CSpecial_Spawn_Time_DifficultyChange].BoolValue);
				if(StrEqual(items, "ismodenormal"))
				{
					if(NCvar[CSpecial_IsModeInNormal].IntValue == 1)
						NCvar[CSpecial_IsModeInNormal].SetInt(2);
					else
						NCvar[CSpecial_IsModeInNormal].SetInt(1);
					if(NCvar[CSpecial_Show_Tips].BoolValue)
						ModeTips();
				}
				if(StrEqual(items, "tgfilewr"))
					UpdateConfigFile(false);
				if(StrEqual(items, "tgreset"))
					UpdateConfigFile(true);
				if(NeedOpenMenu)
					CreateTimer(0.2, Timer_ReloadMenu, GetClientUserId(client));
			}
		}
		case MenuAction_End:
		{
			delete menu;
			if(IsValidClient(client))
				N_MenuSpecialMenu[client] = null;
		}
	}
	return 0;
}

public Action SpecialMenuMode(int client)
{
	Menu menu = new Menu(SpecialMenuModeHandler);
	char line[1024];
	
	Format(line, sizeof(line), "+|NS|+ 选择特感模式\n选择一个模式");
	menu.SetTitle(line);
	
	Format(line, sizeof(line), "默认模式");
	menu.AddItem("7", line);
	Format(line, sizeof(line), "猎人模式");
	menu.AddItem("1", line);
	Format(line, sizeof(line), "牛子模式");
	menu.AddItem("2", line);
	Format(line, sizeof(line), "猴子模式");
	menu.AddItem("3", line);
	Format(line, sizeof(line), "口水模式");
	menu.AddItem("4", line);
	Format(line, sizeof(line), "胖子模式");
	menu.AddItem("5", line);
	Format(line, sizeof(line), "舌头模式");
	menu.AddItem("6", line);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME);
	return Plugin_Handled;
}

public int SpecialMenuModeHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(client))
			{
				char items[30];
				menu.GetItem(selection, items, sizeof(items));
				NCvar[CSpecial_Default_Mode].SetInt(StringToInt(items, sizeof(items)));

				if(NCvar[CSpecial_Show_Tips].BoolValue)
					ModeTips();

				if(NCvar[CSpecial_Random_Mode].BoolValue)
				{
					NCvar[CSpecial_Random_Mode].SetBool(false);
					PrintToChat(client, "\x05%s \x04关闭了随机特感", NEKOTAG);
				}
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
			}
		}
		case MenuAction_Cancel:
		{
			if(IsValidClient(client) && selection == MenuCancel_ExitBack)
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

public Action SpecialMenuSpawn(int client)
{
	Menu menu = new Menu(SpecialMenuSpawnHandler);
	char line[1024];
	
	Format(line, sizeof(line), "+|NS|+ 选择刷特模式\n选择一个模式");
	menu.SetTitle(line);
	
	Format(line, sizeof(line), "引擎刷特");
	menu.AddItem("0", line);
	Format(line, sizeof(line), "普通刷特");
	menu.AddItem("1", line);
	Format(line, sizeof(line), "噩梦刷特");
	menu.AddItem("2", line);
	Format(line, sizeof(line), "地狱刷特");
	menu.AddItem("3", line);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME);
	return Plugin_Handled;
}

public int SpecialMenuSpawnHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(client))
			{
				char items[30], mat[30];
				menu.GetItem(selection, items, sizeof(items));
				int ModeNum = StringToInt(items, sizeof(items));
				NCvar[CSpecial_Spawn_Mode].SetInt(ModeNum);
				SetSpecialSpawnMode(ModeNum);
				switch(ModeNum)
				{
					case 0:Format(mat, sizeof(mat), "引擎");
					case 1:Format(mat, sizeof(mat), "普通");
					case 2:Format(mat, sizeof(mat), "噩梦");
					case 3:Format(mat, sizeof(mat), "地狱");
				}
				PrintToChatAll("\x05%s \x04特感刷新方式更改为 \x03%s刷特模式", NEKOTAG, mat);
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
			}
		}
		case MenuAction_Cancel:
		{
			if(IsValidClient(client) && selection == MenuCancel_ExitBack)
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

public Menu SpecialMenuCustomSpawnArea(int client)
{
	N_SpecialMenuCustomSpawnArea[client] = new Menu(SpecialMenuCustomSpawnAreaHandler);
	char line[1024];
	
	Format(line, sizeof(line), "+|NS|+ 更改特感刷新区域\n请选择一项切换\n仅在梦魇和炼狱模式有效");
	N_SpecialMenuCustomSpawnArea[client].SetTitle(line);
	
	Format(line, sizeof(line), "牛子 目前区域[%s]", GetSpecialSpawnArea(CHARGER) ? "任何" : "官方");
	N_SpecialMenuCustomSpawnArea[client].AddItem("charger", line);
	Format(line, sizeof(line), "胖子 目前区域[%s]", GetSpecialSpawnArea(BOOMER) ? "任何" : "官方");
	N_SpecialMenuCustomSpawnArea[client].AddItem("boomer", line);
	Format(line, sizeof(line), "口水 目前区域[%s]", GetSpecialSpawnArea(SPITTER) ? "任何" : "官方");
	N_SpecialMenuCustomSpawnArea[client].AddItem("spitter", line);
	Format(line, sizeof(line), "舌头 目前区域[%s]", GetSpecialSpawnArea(SMOKER) ? "任何" : "官方");
	N_SpecialMenuCustomSpawnArea[client].AddItem("smoker", line);
	Format(line, sizeof(line), "猴子 目前区域[%s]", GetSpecialSpawnArea(JOCKEY) ? "任何" : "官方");
	N_SpecialMenuCustomSpawnArea[client].AddItem("jockey", line);
	Format(line, sizeof(line), "猎人 目前区域[%s]", GetSpecialSpawnArea(HUNTER) ? "任何" : "官方");
	N_SpecialMenuCustomSpawnArea[client].AddItem("hunter", line);
	
	N_SpecialMenuCustomSpawnArea[client].ExitBackButton = true;
	return N_SpecialMenuCustomSpawnArea[client];
}

public int SpecialMenuCustomSpawnAreaHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(client))
			{
				char buffer[30];
				menu.GetItem(selection, buffer, sizeof(buffer));
				if(StrEqual(buffer, "charger"))
					NCvar[CSpecial_Charger_Spawn_Area].SetBool(!NCvar[CSpecial_Charger_Spawn_Area].BoolValue);
				if(StrEqual(buffer, "boomer"))
					NCvar[CSpecial_Boomer_Spawn_Area].SetBool(!NCvar[CSpecial_Boomer_Spawn_Area].BoolValue);
				if(StrEqual(buffer, "spitter"))
					NCvar[CSpecial_Spitter_Spawn_Area].SetBool(!NCvar[CSpecial_Spitter_Spawn_Area].BoolValue);
				if(StrEqual(buffer, "smoker"))
					NCvar[CSpecial_Smoker_Spawn_Area].SetBool(!NCvar[CSpecial_Smoker_Spawn_Area].BoolValue);
				if(StrEqual(buffer, "jockey"))
					NCvar[CSpecial_Jockey_Spawn_Area].SetBool(!NCvar[CSpecial_Jockey_Spawn_Area].BoolValue);
				if(StrEqual(buffer, "hunter"))
					NCvar[CSpecial_Hunter_Spawn_Area].SetBool(!NCvar[CSpecial_Hunter_Spawn_Area].BoolValue);
				SpecialMenuCustomSpawnArea(client).Display(client, MENU_TIME);
			}
		}
		case MenuAction_Cancel:
		{
			if(IsValidClient(client) && selection == MenuCancel_ExitBack)
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
		}
		case MenuAction_End:
		{
			delete menu;
			if(IsValidClient(client))
				N_SpecialMenuCustomSpawnArea[client] = null;
		}
	}
	return 0;
}

public Menu SpecialMenuCustomDirChance(int client)
{
	N_SpecialMenuCustomDirChance[client] = new Menu(SpecialMenuCustomDirChanceHandler);
	char line[1024];
	
	Format(line, sizeof(line), "+|NS|+ 更改特感刷新方位概率\n请选择一项更改\n概率越高越容易刷在前方，概率越低越容易刷在后方");
	N_SpecialMenuCustomDirChance[client].SetTitle(line);
	
	Format(line, sizeof(line), "牛子 目前概率[%d]", GetSpecialSpawnDirChance(CHARGER));
	N_SpecialMenuCustomDirChance[client].AddItem("charger", line);
	Format(line, sizeof(line), "胖子 目前概率[%d]", GetSpecialSpawnDirChance(BOOMER));
	N_SpecialMenuCustomDirChance[client].AddItem("boomer", line);
	Format(line, sizeof(line), "口水 目前概率[%d]", GetSpecialSpawnDirChance(SPITTER));
	N_SpecialMenuCustomDirChance[client].AddItem("spitter", line);
	Format(line, sizeof(line), "舌头 目前概率[%d]", GetSpecialSpawnDirChance(SMOKER));
	N_SpecialMenuCustomDirChance[client].AddItem("smoker", line);
	Format(line, sizeof(line), "猴子 目前概率[%d]", GetSpecialSpawnDirChance(JOCKEY));
	N_SpecialMenuCustomDirChance[client].AddItem("jockey", line);
	Format(line, sizeof(line), "猎人 目前概率[%d]", GetSpecialSpawnDirChance(HUNTER));
	N_SpecialMenuCustomDirChance[client].AddItem("hunter", line);
	
	N_SpecialMenuCustomDirChance[client].ExitBackButton = true;
	return N_SpecialMenuCustomDirChance[client];
}

public int SpecialMenuCustomDirChanceHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(client))
			{
				cleanplayerwait(client);
				char buffer[30];
				menu.GetItem(selection, buffer, sizeof(buffer));
				WaitingForTgCustomDirChanceItem[client] = buffer;
				WaitingForTgCustomDirChance[client] = true;
				N_SpecialMenuCustomDirChance[client] = null;
				PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的方位概率 \x03范围[1 - 100]", NEKOTAG);
				PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				SpecialMenuCustomDirChance(client).Display(client, MENU_TIME);
			}
		}
		case MenuAction_Cancel:
		{
			if(IsValidClient(client) && selection == MenuCancel_ExitBack)
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
		}
		case MenuAction_End:
		{
			delete menu;
			if(IsValidClient(client))
				N_SpecialMenuCustomDirChance[client] = null;
		}
	}
	return 0;
}

public Menu SpecialMenuCustomWeight(int client)
{
	N_SpecialMenuCustomWeight[client] = new Menu(SpecialMenuCustomWeightHandler);
	char line[1024];
	
	Format(line, sizeof(line), "+|NS|+ 更改特感刷新概率\n请选择一项更改\n概率最高的刷新最多");
	N_SpecialMenuCustomWeight[client].SetTitle(line);
	
	Format(line, sizeof(line), "牛子 目前概率[%d]", GetSpecialSpawnWeight(CHARGER));
	N_SpecialMenuCustomWeight[client].AddItem("charger", line);
	Format(line, sizeof(line), "胖子 目前概率[%d]", GetSpecialSpawnWeight(BOOMER));
	N_SpecialMenuCustomWeight[client].AddItem("boomer", line);
	Format(line, sizeof(line), "口水 目前概率[%d]", GetSpecialSpawnWeight(SPITTER));
	N_SpecialMenuCustomWeight[client].AddItem("spitter", line);
	Format(line, sizeof(line), "舌头 目前概率[%d]", GetSpecialSpawnWeight(SMOKER));
	N_SpecialMenuCustomWeight[client].AddItem("smoker", line);
	Format(line, sizeof(line), "猴子 目前概率[%d]", GetSpecialSpawnWeight(JOCKEY));
	N_SpecialMenuCustomWeight[client].AddItem("jockey", line);
	Format(line, sizeof(line), "猎人 目前概率[%d]", GetSpecialSpawnWeight(HUNTER));
	N_SpecialMenuCustomWeight[client].AddItem("hunter", line);
	
	N_SpecialMenuCustomWeight[client].ExitBackButton = true;
	return N_SpecialMenuCustomWeight[client];
}

public int SpecialMenuCustomWeightHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(client))
			{
				cleanplayerwait(client);
				char buffer[30];
				menu.GetItem(selection, buffer, sizeof(buffer));
				WaitingForTgCustomWeightItem[client] = buffer;
				WaitingForTgCustomWeight[client] = true;
				N_SpecialMenuCustomWeight[client] = null;
				PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的概率 \x03范围[1 - 100]", NEKOTAG);
				PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				SpecialMenuCustomWeight(client).Display(client, MENU_TIME);
			}
		}
		case MenuAction_Cancel:
		{
			if(IsValidClient(client) && selection == MenuCancel_ExitBack)
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
		}
		case MenuAction_End:
		{
			delete menu;
			if(IsValidClient(client))
				N_SpecialMenuCustomWeight[client] = null;
		}
	}
	return 0;
}

public Menu SpecialMenuCustom(int client)
{
	N_SpecialMenuCustom[client] = new Menu(SpecialMenuCustomHandler);
	char line[1024];
	
	Format(line, sizeof(line), "+|NS|+ 更改特感数量\n默认模式生效，选择一项更改");
	N_SpecialMenuCustom[client].SetTitle(line);
	
	Format(line, sizeof(line), "牛子 目前数量[%d]", GetSpecialSpawnLimit(CHARGER));
	N_SpecialMenuCustom[client].AddItem("charger", line);
	Format(line, sizeof(line), "胖子 目前数量[%d]", GetSpecialSpawnLimit(BOOMER));
	N_SpecialMenuCustom[client].AddItem("boomer", line);
	Format(line, sizeof(line), "口水 目前数量[%d]", GetSpecialSpawnLimit(SPITTER));
	N_SpecialMenuCustom[client].AddItem("spitter", line);
	Format(line, sizeof(line), "舌头 目前数量[%d]", GetSpecialSpawnLimit(SMOKER));
	N_SpecialMenuCustom[client].AddItem("smoker", line);
	Format(line, sizeof(line), "猴子 目前数量[%d]", GetSpecialSpawnLimit(JOCKEY));
	N_SpecialMenuCustom[client].AddItem("jockey", line);
	Format(line, sizeof(line), "猎人 目前数量[%d]", GetSpecialSpawnLimit(HUNTER));
	N_SpecialMenuCustom[client].AddItem("hunter", line);
	Format(line, sizeof(line), "玩家(包括bot)+特感最多32位置\n请合理分配");
	N_SpecialMenuCustom[client].AddItem("tips", line, ITEMDRAW_DISABLED);
	
	N_SpecialMenuCustom[client].ExitBackButton = true;
	return N_SpecialMenuCustom[client];
}

public int SpecialMenuCustomHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(client))
			{
				cleanplayerwait(client);
				char buffer[30];
				menu.GetItem(selection, buffer, sizeof(buffer));
				WaitingForTgCustomItem[client] = buffer;
				WaitingForTgCustom[client] = true;
				N_SpecialMenuCustom[client] = null;
				PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的数量 \x03范围[0 - 32]", NEKOTAG);
				PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				SpecialMenuCustom(client).Display(client, MENU_TIME);
			}
		}
		case MenuAction_Cancel:
		{
			if(IsValidClient(client) && selection == MenuCancel_ExitBack)
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
		}
		case MenuAction_End:
		{
			delete menu;
			if(IsValidClient(client))
				N_SpecialMenuCustom[client] = null;
		}
	}
	return 0;
}

public Menu SpecialMenuCustomMaxDis(int client)
{
	N_SpecialMenuCustomMaxDis[client] = new Menu(SpecialMenuCustomMaxDisHandler);
	char line[1024];
	
	Format(line, sizeof(line), "+|NS|+ 更改特感刷新距离\n请选择一项更改\n梦魇地狱模式生效");
	N_SpecialMenuCustomMaxDis[client].SetTitle(line);
	
	Format(line, sizeof(line), "牛子 目前最大距离[%d]", GetSpecialSpawnMaxDis(CHARGER));
	N_SpecialMenuCustomMaxDis[client].AddItem("charger", line);
	Format(line, sizeof(line), "胖子 目前最大距离[%d]", GetSpecialSpawnMaxDis(BOOMER));
	N_SpecialMenuCustomMaxDis[client].AddItem("boomer", line);
	Format(line, sizeof(line), "口水 目前最大距离[%d]", GetSpecialSpawnMaxDis(SPITTER));
	N_SpecialMenuCustomMaxDis[client].AddItem("spitter", line);
	Format(line, sizeof(line), "舌头 目前最大距离[%d]", GetSpecialSpawnMaxDis(SMOKER));
	N_SpecialMenuCustomMaxDis[client].AddItem("smoker", line);
	Format(line, sizeof(line), "猴子 目前最大距离[%d]", GetSpecialSpawnMaxDis(JOCKEY));
	N_SpecialMenuCustomMaxDis[client].AddItem("jockey", line);
	Format(line, sizeof(line), "猎人 目前最大距离[%d]", GetSpecialSpawnMaxDis(HUNTER));
	N_SpecialMenuCustomMaxDis[client].AddItem("hunter", line);
	
	N_SpecialMenuCustomMaxDis[client].ExitBackButton = true;
	return N_SpecialMenuCustomMaxDis[client];
}

public int SpecialMenuCustomMaxDisHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(client))
			{
				cleanplayerwait(client);
				char buffer[30];
				menu.GetItem(selection, buffer, sizeof(buffer));
				WaitingForTgCustomMaxDisItem[client] = buffer;
				WaitingForTgCustomMaxDis[client] = true;
				N_SpecialMenuCustomMaxDis[client] = null;
				PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的最大距离 \x03范围[不能小于1，不要小于最小距离", NEKOTAG);
				PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				SpecialMenuCustomMaxDis(client).Display(client, MENU_TIME);
			}
		}
		case MenuAction_Cancel:
		{
			if(IsValidClient(client) && selection == MenuCancel_ExitBack)
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
		}
		case MenuAction_End:
		{
			delete menu;
			if(IsValidClient(client))
				N_SpecialMenuCustomMaxDis[client] = null;
		}
	}
	return 0;
}

public Menu SpecialMenuCustomMinDis(int client)
{
	N_SpecialMenuCustomMinDis[client] = new Menu(SpecialMenuCustomMinDisHandler);
	char line[1024];
	
	Format(line, sizeof(line), "+|NS|+ 更改特感刷新距离\n请选择一项更改\n梦魇地狱模式生效");
	N_SpecialMenuCustomMinDis[client].SetTitle(line);
	
	Format(line, sizeof(line), "牛子 目前最小距离[%d]", GetSpecialSpawnMinDis(CHARGER));
	N_SpecialMenuCustomMinDis[client].AddItem("charger", line);
	Format(line, sizeof(line), "胖子 目前最小距离[%d]", GetSpecialSpawnMinDis(BOOMER));
	N_SpecialMenuCustomMinDis[client].AddItem("boomer", line);
	Format(line, sizeof(line), "口水 目前最小距离[%d]", GetSpecialSpawnMinDis(SPITTER));
	N_SpecialMenuCustomMinDis[client].AddItem("spitter", line);
	Format(line, sizeof(line), "舌头 目前最小距离[%d]", GetSpecialSpawnMinDis(SMOKER));
	N_SpecialMenuCustomMinDis[client].AddItem("smoker", line);
	Format(line, sizeof(line), "猴子 目前最小距离[%d]", GetSpecialSpawnMinDis(JOCKEY));
	N_SpecialMenuCustomMinDis[client].AddItem("jockey", line);
	Format(line, sizeof(line), "猎人 目前最小距离[%d]", GetSpecialSpawnMinDis(HUNTER));
	N_SpecialMenuCustomMinDis[client].AddItem("hunter", line);
	
	N_SpecialMenuCustomMinDis[client].ExitBackButton = true;
	return N_SpecialMenuCustomMinDis[client];
}

public int SpecialMenuCustomMinDisHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(IsValidClient(client))
			{
				cleanplayerwait(client);
				char buffer[30];
				menu.GetItem(selection, buffer, sizeof(buffer));
				WaitingForTgCustomMinDisItem[client] = buffer;
				WaitingForTgCustomMinDis[client] = true;
				N_SpecialMenuCustomMinDis[client] = null;
				PrintToChat(client, "\x05%s \x04请在聊天框输入你想设置的最小距离 \x03范围[不能小于1，不要超过最大距离]", NEKOTAG);
				PrintToChat(client, "\x05%s \x04输入 \x03!cancel \x04即可取消这次操作", NEKOTAG);
				SpecialMenuCustomMinDis(client).Display(client, MENU_TIME);
			}
		}
		case MenuAction_Cancel:
		{
			if(IsValidClient(client) && selection == MenuCancel_ExitBack)
				SpecialMenu(client).DisplayAt(client, MenuPageItem[client], MENU_TIME);
		}
		case MenuAction_End:
		{
			delete menu;
			if(IsValidClient(client))
				N_SpecialMenuCustomMinDis[client] = null;
		}
	}
	return 0;
}