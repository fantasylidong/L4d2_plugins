#pragma semicolon 1
#pragma newdecls required

#define MAXMSGLEN       192

Handle g_hCvarDebug = INVALID_HANDLE;
Handle g_hCvarExpireTime = INVALID_HANDLE;
Handle g_hCvarCheckSender = INVALID_HANDLE;
ArrayList g_hMsgTime;
ArrayList g_hMsgSender;
ArrayList g_hMsgText;
int g_iMsgCount = 0;

public Plugin myinfo = {
    name = "Chat Spam Throttle",
    author = "devilesk",
    description = "Chat filter to prevent spamming the same message too often.",
    version = "0.3.0",
    url = "https://github.com/devilesk/rl4d2l-plugins"
}

public void OnPluginStart() {
    g_hCvarDebug = CreateConVar("chat_spam_throttle_debug", "0", "Chat Spam Throttle debug mode", 0, true, 0.0, true, 1.0);
    g_hCvarExpireTime = CreateConVar("chat_spam_throttle_time", "20", "Time in seconds before a message can be repeated.", 0, true, 0.0);
    g_hCvarCheckSender = CreateConVar("chat_spam_throttle_check_sender", "1", "Allow repeating messages sent by someone else.", 0);
    g_hMsgTime = new ArrayList(32);
    g_hMsgSender = new ArrayList(32);
    g_hMsgText = new ArrayList(MAXMSGLEN);
}

public void OnMapStart() {
    g_hMsgTime.Clear();
    g_hMsgSender.Clear();
    g_hMsgText.Clear();
    g_iMsgCount = 0;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] args) {
    char message[MAXMSGLEN];
    PrintDebug("[OnClientSayCommand] command: %s, args: %s", command, args);
    if (args[0] == '!' || args[0] == '/') return Plugin_Continue;
    strcopy(message, MAXMSGLEN, args);
    FilterMessage(message);
    if(FindMessage(client, message) != -1) {
        PrintToChat(client, "You are sending that message too often.");
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public int FindMessage(int client, const char[] message) {
    int expireTime = GetTime() - GetConVarInt(g_hCvarExpireTime);
    bool bCheckSender = GetConVarBool(g_hCvarCheckSender);
    char msg[MAXMSGLEN];
    for (int i = g_iMsgCount - 1; i >= 0; i--) {
        if (g_hMsgTime.Get(i) < expireTime) {
            UntrackMessage(i);
            continue;
        }
        if (bCheckSender && client != g_hMsgSender.Get(i)) continue;
        g_hMsgText.GetString(i, msg, sizeof(msg));
        if (!StrEqual(message, msg, false)) continue;
        PrintDebug("[FindMessage] match %s, %s", message, msg);
        return i;
    }
    PrintDebug("[FindMessage] no match %s, %s", message, msg);
    TrackMessage(client, message);
    return -1;
}

public void UntrackMessage(int index) {
    g_hMsgTime.Erase(index);
    g_hMsgSender.Erase(index);
    g_hMsgText.Erase(index);
    g_iMsgCount--;
}

public void TrackMessage(int client, const char[] message) {
    g_hMsgTime.Push(GetTime());
    g_hMsgSender.Push(client);
    g_hMsgText.PushString(message);
    g_iMsgCount++;
}

// Based on Unicode Name Filter https://forums.alliedmods.net/showthread.php?p=2207177?p=2207177
public void FilterMessage(char[] message) {
    TrimString(message);

    int charMax = strlen(message);
    int charIndex;
    int copyPos = 0;

    char strippedString[MAXMSGLEN];

    for (charIndex = 0; charIndex < charMax; charIndex++) {
        // Reach end of string. Break.
        if (message[copyPos] == 0) {
            strippedString[copyPos] = 0;
            break;
        }

        if (GetCharBytes(message[charIndex]) > 1) continue;

        if (IsAlphaNumeric(message[charIndex]) || IsCharSpace(message[charIndex])) {
            strippedString[copyPos] = message[charIndex];
            copyPos++;
            continue;
        }
    }

    // Copy back to passing parameter.
    strcopy(message, MAXMSGLEN, strippedString);
    
    PrintDebug("[FilterMessage] message: %s", message);
}

public bool IsAlphaNumeric(int characterNum) {
    return ((characterNum >= 48 && characterNum <= 57)
        ||  (characterNum >= 65 && characterNum <= 90)
        ||  (characterNum >= 97 && characterNum <= 122));
}

stock void PrintDebug(const char[] Message, any ...) {
    if (GetConVarBool(g_hCvarDebug)) {
        char DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        LogMessage(DebugBuff);
    }
}