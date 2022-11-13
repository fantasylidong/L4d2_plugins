#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

char txtBufer[128];    // Буферная переменная для хранения текста
Menu g_MapMenu = null; // Для работы меню
int winner = 0; // Номер карты, которая победила в голосовании. индекс 0 = mapSequence[0]
int clientVotes[MAXPLAYERS + 1][14]; // В массиве содержатся все игроки и их голоса за каждую карту

public Plugin myinfo =  {
	name = "AutoMapSwitcher", 
	author = "pa4H", 
	description = "", 
	version = "1.0", 
	url = "vk.com/pa4h1337"
};

char mapSequence[][32] =  { // Последовательность карт
	"c8m1_apartment", "c2m1_highway", "c1m1_hotel", "c11m1_greenhouse", "c5m1_waterfront", "c3m1_plankcountry", "c4m1_milltown_a", 
	"c6m1_riverbank", "c7m1_docks", "c9m1_alleys", "c10m1_caves", 
	"c12m1_hilltop", "c13m1_alpinecreek", "c14m1_junkyard"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_mapvote", mapVote);
	RegConsoleCmd("sm_votemap", mapVote);
	RegConsoleCmd("sm_mv", mapVote);
	RegConsoleCmd("sm_rtv", mapVote);
	
	HookEvent("versus_round_start", Event_VersusRoundStart, EventHookMode_Pre);		  // Начало раунда
	HookEvent("versus_match_finished", Event_VersusMatchFinished, EventHookMode_Pre); // Конец раунда
	
	LoadTranslations("pa4HAutoMapChanger.phrases");
}

public void Event_VersusRoundStart(Event hEvent, const char[] sEvName, bool bDontBroadcast) // Срабатывает после выхода из saferoom
{
	if (L4D_IsMissionFinalMap() && GameRules_GetProp("m_bInSecondHalfOfRound") == 0) // Если играем последную карту и идёт первая половина карты
	{
		g_MapMenu = BuildMapMenu(); // Генерируем пункты меню
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsFakeClient(i) && IsClientInGame(i)) 
			{
				clearClientVotes(i);      // Очищаем все голоса
				g_MapMenu.Display(i, 15); // Показываем меню всем настоящим игрокам
			}
		}
		
		CreateTimer(15.0, Timer_EndVote, 0, TIMER_FLAG_NO_MAPCHANGE); // Создаем таймер после которого закончится голосование
	}
}

public void Event_VersusMatchFinished(Event hEvent, const char[] sEvName, bool bDontBroadcast) // Версус закончился
{
	Format(txtBufer, sizeof(txtBufer), "%t", "NextMap", mapSequence[winner]);
	CPrintToChatAll(txtBufer); // "Следующая карта Нет милосердию"
	CreateTimer(10.0, Timer_ChangeMap, 0, TIMER_FLAG_NO_MAPCHANGE); // Через 10 секунд меняем карту
}

public Action Timer_EndVote(Handle hTimer, any UserId)
{
	int buf = 0;
	for (int c = 0; c < MAXPLAYERS + 1; c++)
	{
		for (int i = 0; i < 14; i++)
		{
			if (clientVotes[c][i] > buf) { buf = clientVotes[c][i]; winner = i; } // Узнаем победившую карту
		}
	}
	Format(txtBufer, sizeof(txtBufer), "%t", "VoteWinner", mapSequence[winner]);
	CPrintToChatAll(txtBufer); // Выводим в чат победившую карту
	
	return Plugin_Handled;
}

public Action Timer_ChangeMap(Handle hTimer, any UserId)
{
	ServerCommand("changelevel %s", mapSequence[winner]);
	//changelevel(mapSequence[winner]); // Меняем карту
	return Plugin_Stop;
}

Menu BuildMapMenu() // Здесь строится меню
{
	Menu menu = new Menu(Menu_VotePoll); // Внутри скобок обработчик нажатий меню
	Format(txtBufer, sizeof(txtBufer), "%t", "SelectMap"); 
	menu.SetTitle(txtBufer); // Заголовок меню
	
	for (int i = 0; i < sizeof(mapSequence); i++) // Выводим все карты из массива mapSequence
	{
		Format(txtBufer, sizeof(txtBufer), "%t", mapSequence[i]); // Даём: "c1m1_hotel", получаем: "Вымерший центр"
		menu.AddItem(mapSequence[i], txtBufer); // Добавляем в меню "Вымерший центр"
	}
	
	return menu;
}

public Menu_VotePoll(Menu menu, MenuAction action, int client, int selectedItem) // Обработчик нажатия кнопок в меню
{
	if (action == MenuAction_End) // Вышли из меню?
	{
		delete g_MapMenu; // Удаляем
	}
	
	if (action == MenuAction_Select) // Если нажали кнопку от 1 до 7 включительно
	{
		clearClientVotes(client); // Чистим голоса человека который нажал кнопку в меню
		clientVotes[client][selectedItem] += 1; // Добавляем голос за карту человеку, нажавшиму на кнопку
		
		CPrintToChatAll("Client %i selected item: %d ", client, selectedItem); // debug
	}
}
void clearClientVotes(int client) // Очищаем голоса конкретного игрока
{
	for (int i = 0; i < 14; i++)
	{
		clientVotes[client][i] = 0;
	}
}

public Action mapVote(int client, int args) // !mapvote
{
	if (L4D_IsMissionFinalMap() == true) 
	{
		g_MapMenu = BuildMapMenu();
		g_MapMenu.Display(client, 15);
	}
	else // Если играем не последнюю карту
	{
		Format(txtBufer, sizeof(txtBufer), "%t", "VoteOnlyOnFinal");
		CPrintToChat(client, txtBufer);
	}
	return Plugin_Handled;
} 