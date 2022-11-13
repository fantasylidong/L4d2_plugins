#include <sourcemod>

#define TEAM_SURVIVOR 2
#define	TEAM_INFECTED 3

enum
{
    ZombieClass_Common = 0,
    ZombieClass_Smoker,
    ZombieClass_Boomer,
    ZombieClass_Hunter,
    ZombieClass_Spitter,
    ZombieClass_Jockey,
    ZombieClass_Charger,
    ZombieClass_Witch,
    ZombieClass_Tank,
    ZombieClass_Total,
};

enum
{
    ZombieClass_WitchL4D1 = ZombieClass_Spitter,
    ZombieClass_TankL4D1 = ZombieClass_Jockey,
    ZombieClass_TotalL4D1 = ZombieClass_Charger,
};

enum
{
    Survivor_Nick = 0,
    Survivor_Rochelle,
    Survivor_Coach,
    Survivor_Ellis,
    Survivor_Bill,
    Survivor_Zoey,
    Survivor_Louis,
    Survivor_Francis,
    Survivor_Total,
};

char survivorFilters[Survivor_Total][] =
{
    "@nick",
    "@rochelle",
    "@coach",
    "@ellis",
    "@bill",
    "@zoey",
    "@louis",
    "@francis",
};

char infectedFilters[ZombieClass_Total][] =
{
    "",
    "@smoker",
    "@boomer",
    "@hunter",
    "@spitter",
    "@jockey",
    "@charger",
    "",
    "@tank",
};

char survivorPhrases[Survivor_Total][] =
{
    "nick characters",
    "rochelle characters",
    "coach characters",
    "ellis characters",
    "bill characters",
    "zoey characters",
    "louis characters",
    "francis characters",
};

char infectedPhrases[ZombieClass_Total][] =
{
    "",
    "infected smokers",
    "infected boomers",
    "infected hunters",
    "infected spitters",
    "infected jockeys",
    "infected chargers",
    "",
    "infected tanks",
};

EngineVersion g_EngineVersion = Engine_Unknown;

int GetCharacterFromModel(const char[] modelName)
{
    static char survivorModels[Survivor_Total][] =
    {
        "gambler",
        "producer",
        "coach",
        "mechanic",
        "namvet",
        "teenangst",
        "manager",
        "biker",
    };
    
    int i = Survivor_Nick;
    if (g_EngineVersion == Engine_Left4Dead) {
        i = Survivor_Bill;
    }
    
    for (; i < Survivor_Total; i++) {
        // "models/survivors/survivor_"
        if (strncmp(modelName[26], survivorModels[i], strlen(survivorModels[i])) != 0) {
            continue;
        }
        
        return i;
    }
    
    return -1;
}

public bool FilterSurvivor(const char[] pattern, Handle clients)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) {
            continue;
        }
        
        if (GetClientTeam(i) != TEAM_SURVIVOR) {
            continue;
        }
        
        char modelName[128];
        GetEntPropString(i, Prop_Data, "m_ModelName", modelName, sizeof(modelName));
        
        if (strncmp(modelName, "models/survivors/survivor_", 26) != 0) {
            continue;
        }
        
        int characterId = GetCharacterFromModel(modelName);
        if (characterId == -1) {
            continue;
        }
        
        if (strcmp(survivorFilters[ characterId ], pattern) != 0) {
            continue;
        }
        
        PushArrayCell(clients, i);
    }

    return true;
}

public bool FilterInfected(const char[] pattern, Handle clients)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) {
            continue;
        }
        
        if (GetClientTeam(i) != TEAM_INFECTED) {
            continue;
        }
        
        if (GetEntProp(i, Prop_Send, "m_isGhost") != 0) {
            continue;
        }
        
        int zombieClass = GetEntProp(i, Prop_Send, "m_zombieClass");
        if (zombieClass < ZombieClass_Smoker) {
            continue;
        }
        
        if (g_EngineVersion == Engine_Left4Dead && zombieClass >= ZombieClass_WitchL4D1) {
            // Add index difference for L4D1
            zombieClass += ZombieClass_Witch - ZombieClass_WitchL4D1;
        }
        
        if (zombieClass >= ZombieClass_Total || zombieClass == ZombieClass_Witch) {
            continue;
        }
        
        if (strcmp(infectedFilters[ zombieClass ], pattern) != 0) {
            continue;
        }
        
        PushArrayCell(clients, i);
    }

    return true;
}

public bool FilterAllSurvivors(const char[] pattern, Handle clients)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) {
            continue;
        }
        
        if (GetClientTeam(i) != TEAM_SURVIVOR) {
            continue;
        }
        
        PushArrayCell(clients, i);
    }

    return true;
}

public bool FilterAllInfected(const char[] pattern, Handle clients)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) {
            continue;
        }
        
        if (GetClientTeam(i) != TEAM_INFECTED) {
            continue;
        }
        
        if (GetEntProp(i, Prop_Send, "m_isGhost") != 0) {
            continue;
        }
        
        PushArrayCell(clients, i);
    }

    return true;
}

public void OnPluginStart()
{
    int i = Survivor_Nick;
    if (g_EngineVersion == Engine_Left4Dead) {
        i = Survivor_Bill;
    }
    
    for (; i < Survivor_Total; i++) {
        AddMultiTargetFilter(survivorFilters[i], FilterSurvivor, survivorPhrases[i], false);
    }
    
    for (i = ZombieClass_Smoker; i < ZombieClass_Total; i++) {
        if (i == ZombieClass_Witch || i == ZombieClass_WitchL4D1 && g_EngineVersion == Engine_Left4Dead) {
            i = ZombieClass_Tank;
        }
        
        AddMultiTargetFilter(infectedFilters[i], FilterInfected, infectedPhrases[i], false);
    }
    
    AddMultiTargetFilter("@survivors", FilterAllSurvivors, "all survivors", false);
    AddMultiTargetFilter("@infected", FilterAllInfected, "all infected", false);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_EngineVersion = GetEngineVersion();
    switch (g_EngineVersion) {
        case Engine_Left4Dead2, Engine_Left4Dead:
        {
            return APLRes_Success;
        }
    }

    strcopy(error, err_max, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");

    return APLRes_SilentFailure;
}

public Plugin myinfo =
{
    name = "[L4D/2] Common Target Filters",
    author = "shqke",
    description = "Allows to target infected and survivors using filters",
    version = "1.0",
    url = "https://github.com/shqke/sp_public"
};