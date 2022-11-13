#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "Countdown Test",
    author = "devilesk",
    description = "Countdown Test.",
    version = "1.0.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public OnPluginStart() {
	RegConsoleCmd("sm_starttest", Command_StartTest);
	RegConsoleCmd("sm_stoptest", Command_StopTest);
	RegConsoleCmd("sm_checktest", Command_CheckTest);
}

public Action:Command_StartTest(client, args)  {
    PrintToChatAll("Starting countdown");
	InitiateCountdown();
}

public Action:Command_CheckTest(client, args)  {
    PrintToChatAll("IsCountdownRunning: %i", IsCountdownRunning());
    PrintToChatAll("HasCountdownElapsed: %i", HasCountdownElapsed());
}

public Action:Command_StopTest(client, args)  {
    PrintToChatAll("Stopping countdown");
	HideCountdown();
	StopCountdown();
}

CountdownTimer:CountdownPointer()
{
	return L4D2Direct_GetScavengeRoundSetupTimer();
}

InitiateCountdown()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowVGUIPanel(i, "ready_countdown", _, true);
		}
	}

	CTimer_Start(CountdownPointer(), 30.0);
}

bool:IsCountdownRunning()
{
	return CTimer_HasStarted(CountdownPointer());
}

bool:HasCountdownElapsed()
{
	return CTimer_IsElapsed(CountdownPointer());
}

StopCountdown()
{
	CTimer_Invalidate(CountdownPointer());
}

HideCountdown()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowVGUIPanel(i, "ready_countdown", _, false);
		}
	}
}

stock PrintDebug(const String:Message[], any:...) {
    if (GetConVarBool(g_hCvarDebug)) {
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
    }
}