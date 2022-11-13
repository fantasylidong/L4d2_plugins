/**************************************************************************
 *                                                                        *
 *                			pan0s's tool api			 		     	  *
 *                            Author: pan0s                               *
 *                            Version: v1.1                               *
 *                                                                        *
 **************************************************************************/
#include <sdktools>

// Team define
#define TEAM_SPECTATOR       1
#define TEAM_SURVIVOR        2
#define TEAM_INFECTED        3

/**
 * Validates if the client index is valid.
 *
 * @param client        Client index.
 * @return              True if client index is valid, false otherwise.
 */
stock bool IsValidClientIndex(int client)
{
    return (1 <= client <= MaxClients);
}

/****************************************************************************************************/

/**
 * Validates if the client is valid.
 *
 * @param client        Client index.
 * @return              True if client index is valid and client is in game, false otherwise.
 */
stock bool IsValidClient(int client)
{
    return IsValidClientIndex(client) && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client);
}

/**
 * Validates if the client is a infected.
 *
 * @param client        Client index.
 * @return              True if client is valid and the team is infected.
 */
stock bool IsInfected(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == TEAM_INFECTED;
}

/**
 * Validates if the client is a survivor.
 *
 * @param client        Client index.
 * @return              True if the client is valid and the team is Survivor.
 */
stock bool IsSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

/**
 * Validates if the client is valid and alive.
 *
 * @param client        Client index.
 * @return              True if the client is valid and alive
 */
stock bool IsValidClientAndAlive(int client)
{
	return IsValidClient(client) && IsPlayerAlive(client);
}

/**
 * Validates if the client is valid, a survivor and alive.
 *
 * @param client        Client index.
 * @return              True if the client is valid, a survival and alive
 */
stock bool IsSurvivorAlive(int client)
{
	return IsSurvivor(client) && IsPlayerAlive(client);
}

/**
 * Validates if the client is valid, a survivor and dead.
 *
 * @param client        Client index.
 * @return              True if the client is valid, a survival and dead
 */
stock bool IsSurvivorDead(int client)
{
	return IsSurvivor(client) && !IsPlayerAlive(client)
}

/**
 * Check the value is between min and max
 *
 * @param value        	value
 * @param min        	min
 * @param max        	max
 * @return              True if the value is between min and max
 */
stock bool IsBetween(int value, int min, int max)
{
	return value >= min && value <= max;
}

/**
 * Compare two number descending
 *
 * @param val1        	value1
 * @param val1        	value1
 * @return              int
 */
stock int CompareDesc(any val1, any val2)
{
	return view_as<float>(val1) > view_as<float>(val2)? -1 : val1 == val2? 0 : 1;
} 

/**
 * Find the index of a string by a query string.
 *
 * @param buffer       	target string
 * @param size        	size of target string
 * @param query        	query string
 * @param querySize     size of query string
 * @return              -1, if it is not found
 */
stock int IndexOf(char[] buffer, int size, char[] query, int querySize)
{
	int result = -1;
	int i = 0;
	while(i < size)
	{
		if(buffer[i++] == query[0])
		{
			int bIndex = i;
			int qIndex = 1>=querySize? 0: 1;
			if(qIndex == querySize-1) return i-1;
			while(qIndex<querySize && bIndex < size)
			{
				if(buffer[bIndex++] == query[qIndex++])
				{
					if(qIndex == querySize-1) return i-1;
					continue;
				}
				break;
			}
		}
	}
	return result;
}

/**
 * Get the host Public IP
 *
 * @param buffer       	buffer to store the IP
 * @param size        	IP size
 * @return              none
 */
stock void GetHostPublicIP(char[] buffer, int size)
{
	char hostIP[16];
	char status[256];
	char s1[1024];
 	ServerCommandEx(status, sizeof(status), "status");

	char query[] = "public ";
	int idx = IndexOf(status, sizeof(status), query, sizeof(query));
	strcopy(s1, sizeof(s1), status[idx]);
	char query2[] = " ";
	char s2[1024];
	idx = IndexOf(s1, sizeof(s1), query2, sizeof(query2)) +1;
	strcopy(s2, sizeof(s2), s1[idx]);
	char query3[] = ":";
	idx = IndexOf(s2, sizeof(s2), query3, sizeof(query3))-1;
	if(idx != -1)
	{
		for(int i=0; i<sizeof(hostIP); i++)
		{
			hostIP[i] = s2[i];
			if(i>=idx) break;
		}
		strcopy(buffer, size, hostIP);
	}
}

/**
 * split the string to string array
 *
 * @param source       	source string
 * @param buffer        buffer to store the splited string
 * @return              none
 */
stock void SplitStringEx(const char[] source, int size, char[][] buffer, int[] sizes, char splitSymbol)
{
	int buffIdx[2];
	for(int i=0; i<size; i++)
	{
		if(source[i] == splitSymbol && i != 0)
		{
			buffIdx[0]++;
			buffIdx[1] = 0;

			if(buffIdx[0] >= sizes[0]) break;
			continue;
		}
		if(buffIdx[1] +1 >= sizes[1]) continue;
		buffer[buffIdx[0]][buffIdx[1]++] = source[i];
	}
}

/**
 * split the IP to string array
 *
 * @param source       	source iP
 * @param buffer        buffer to store the splited IP
 * @return              none
 */
stock void SplitIP(const char[] source, char[][] buffer)
{
	int buffIdx[2];
	for(int i=0; i<16; i++)
	{
		if(source[i] == '.' && i != 0)
		{
			buffIdx[0]++;
			buffIdx[1] = 0;
			continue;
		}
		buffer[buffIdx[0]][buffIdx[1]++] = source[i];
	}
}

/**
 * Check the IP is Private IP or Local IP
 *
 * @param source       	source iP
 * @return              none
 */
stock bool IsPrivateIP(const char[] IP, bool bIncludeLocal = false)
{
	char buffer[5][3];
	SplitIP(IP, buffer);
	int IPs[4];
	for(int i =0; i<4; i++) IPs[i] = StringToInt(buffer[i]);
	if(bIncludeLocal && IPs[0] == 127 && IPs[1] == 0 && IPs[2] == 0 && IPs[3] == 1) return true;
	else if(IPs[0] == 10) return true;
	else if(IPs[0] == 172 && (IPs[1]>=16 && IPs[1]<=31)) return true;
	else if(IPs[0] == 192 && (IPs[1] == 168)) return true;
	return false;
}

/**
 * Get the Client IP, if it is local/private IP, return Host iP
 *
 * @param client       	client index
 * @param buffer       	buffer to store IP
 * @param size       	size of iP
 * @return              none
 */
stock void GetClientIPEx(int client, char[] buffer, int size)
{
	GetClientIP(client, buffer, size);
	if(IsPrivateIP(buffer))
	{
		GetHostPublicIP(buffer, size);
	}
}

// Store all weapons name
stock const char g_sWeapons[][] = 
{
    "smg",
    "smg_silenced",
    "smg_mp5",
    "rifle",
    "rifle_desert",
    "rifle_ak47",
    "rifle_sg552",
    "rifle_m60",
    "hunting_rifle",
    "sniper_military",
    "sniper_awp",
    "sniper_scout",
    "pumpshotgun",
    "shotgun_chrome",
    "autoshotgun",
    "shotgun_spas",
    "pistol",
    "pistol_magnum",
    "grenade_launcher",
    "katana",
    "fireaxe",
    "machete",
    "knife",
    "chainsaw",
    "pitchfork",
    "shovel",
    "golfclub",
    "electric_guitar",
    "tonfa",
    "baseball_bat",
    "cricket_bat",
    "frying_pan",
    "crowbar",
    "pipe_bomb",
    "molotov",
    "none",
	"dual_pistols",
	"player",
	"entityflame", // molotov / other fire damage
	"inferno", // molotov / other fire damage
    "grenade_launcher_projectile",
};

// Store all weapons name
stock const char g_sGuns[][] = 
{
    "smg",
    "smg_silenced",
    "smg_mp5",
    "rifle",
    "rifle_desert",
    "rifle_ak47",
    "rifle_sg552",
    "rifle_m60",
    "hunting_rifle",
    "sniper_military",
    "sniper_awp",
    "sniper_scout",
    "pumpshotgun",
    "shotgun_chrome",
    "autoshotgun",
    "shotgun_spas",
    "pistol",
    "pistol_magnum",
    "grenade_launcher",
};

stock const char g_sMelees[][] = 
{
	"katana",           			// 0
	"fireaxe",          			// 1
    "machete",          			// 2
	"flamethrower",					// 3	
    "knife",            			// 4
    "chainsaw",         			// 5
	"pitchfork",					// 6
	"shovel",						// 7
	"golfclub",						// 8
    "electric_guitar",  			// 9
    "tonfa",            			// 10
    "baseball_bat",     			// 11
    "cricket_bat",      			// 12
    "frying_pan",       			// 13
    "crowbar",          			// 14
};

// Event weapon ID to String
stock const char g_sWeaponNames[][] =
{
	"weapon_none", "weapon_pistol", "weapon_smg",                                            // 102
	"weapon_pumpshotgun", "weapon_autoshotgun", "weapon_rifle",                              // 3
	"weapon_hunting_rifle", "weapon_smg_silenced", "weapon_shotgun_chrome",                  // 6
	"weapon_rifle_desert", "weapon_sniper_military", "weapon_shotgun_spas",                  // 9
	"weapon_first_aid_kit", "weapon_molotov", "weapon_pipe_bomb",                            // 12
	"weapon_pain_pills", "weapon_gascan", "weapon_propanetank",                              // 15
	"weapon_oxygentank", "weapon_melee", "weapon_chainsaw",                                  // 18
	"weapon_grenade_launcher", "weapon_ammo_pack", "weapon_adrenaline",                      // 21
	"weapon_defibrillator", "weapon_vomitjar", "weapon_rifle_ak47",                          // 24
	"weapon_gnome", "weapon_cola_bottles", "weapon_fireworkcrate",                           // 27
	"weapon_upgradepack_incendiary", "weapon_upgradepack_explosive", "weapon_pistol_magnum", // 30
	"weapon_smg_mp5", "weapon_rifle_sg552", "weapon_sniper_awp",                             // 33
	"weapon_sniper_scout", "weapon_rifle_m60", "weapon_tank_claw",                           // 36
	"weapon_hunter_claw", "weapon_charger_claw", "weapon_boomer_claw",                       // 39
	"weapon_smoker_claw", "weapon_spitter_claw", "weapon_jockey_claw",                       // 42
	"weapon_machinegun", "vomit", "splat",                                                   // 45
	"pounce", "lounge", "pull",                                                              // 48
	"choke", "rock", "physics",                                                              // 51
	"ammo", "upgrade_item"                                                                   // 54
};

// Game difficulties
stock const char g_sDifficulties[][] = {"Easy", "Normal", "Hard", "Impossible"};

// Gamemodes
stock const char g_sGamemodes[][] = {"Survival", "Coop", "Scavenge", "Realism", "Versus", "Teamscavenge", "Teamversus"};

enum struct Weapon
{
	int id;
	char name[32];
	char activeName[32];
	int slot;
	int clips;

	bool IsGun(bool bActive = false)
	{
		if(bActive)
		{
			for(int i=0; i<sizeof(g_sGuns); i++)
				if(StrEqual(this.activeName, g_sGuns[i], false)) return true;
		}
		else
		{
			for(int i=0; i<sizeof(g_sGuns); i++)
				if(StrEqual(this.name, g_sGuns[i], false)) return true;
		}
		return false;
	}

	bool IsMelee(bool bActive = false)
	{
		if(bActive)
		{
			for(int i=0; i<sizeof(g_sMelees); i++)
				if(StrEqual(this.activeName, g_sMelees[i], false)) return true;
		}
		else
		{
			for(int i=0; i<sizeof(g_sMelees); i++)
				if(StrEqual(this.name, g_sMelees[i], false)) return true;
		}
		return false;
	}

	bool IsGunOrMelee(bool bActive = false)
	{
		return this.IsGun(bActive) || this.IsMelee(bActive);
	}

	void UpdateActiveName(int client)
	{
		int id = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", 0);
		if(id == -1) return;
		GetEdictClassname(id, this.activeName, 32);
		this.SetActiveNameToPure(client);
	}

	void UpdateName()
	{
		Format(this.name, 32, "%s", g_sWeaponNames[this.id]);
	}

	// Get weapons name by event weaponId
	void SetActiveNameToPure(int client)
	{
		if(StrEqual(this.activeName, "weapon_melee") || StrEqual(this.activeName, "melee"))
		{
			GetEntPropString(GetPlayerWeaponSlot(client, 1), Prop_Data, "m_strMapSetScriptName", this.activeName, 32);
		}
		else
		{
			int index = IndexOf(this.activeName, 32, "weapon_", 7);
			if(index != -1)
				Format(this.activeName, 32, "%s", this.activeName[index+7]);
		}
	}

	// Get weapons name by event weaponId
	void SetNameToPure(int client)
	{
		if(StrEqual(this.name, "weapon_melee") || StrEqual(this.name, "melee"))
		{
			int entity = GetPlayerWeaponSlot(client, 1);
			GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", this.name, 32);
		}
		else
		{
			int index = IndexOf(this.name, 32, "weapon_", 7);
			if(index != -1)
				Format(this.name, 32, "%s", this.name[index+7]);
		}
	}

}

stock void GetSlotAndClips(const int client, const char[] weapon, int& slot, int& cilps, bool bHeavyIncluded)
{
	if(bHeavyIncluded)
	{
		if (StrEqual(weapon, "grenade_launcher"))
		{
			slot = 0;
			cilps = 1;
		}
		else if (StrEqual(weapon, "rifle_m60"))
		{
			slot = 0;
			cilps = 150;
		}
	}
	else if (StrEqual(weapon, "pumpshotgun") || StrEqual(weapon, "shotgun_chrome"))
	{
		slot = 0;
		cilps = 8;
	}
	else if (StrEqual(weapon, "autoshotgun") || StrEqual(weapon, "shotgun_spas"))
	{
		slot = 0;
		cilps = 10;
	}
	else if (StrEqual(weapon, "hunting_rifle") || StrEqual(weapon, "sniper_scout"))
	{
		slot = 0;
		cilps = 15;
	}
	else if (StrEqual(weapon, "sniper_awp"))
	{
		slot = 0;
		cilps = 20;
	}
	else if (StrEqual(weapon, "sniper_military"))
	{
		slot = 0;
		cilps = 30;
	}
	else if (StrEqual(weapon, "rifle_ak47"))
	{
		slot = 0;
		cilps = 40;
	}
	else if (StrEqual(weapon, "smg") || StrEqual(weapon, "smg_silenced") || StrEqual(weapon, "smg_mp5") || StrEqual(weapon, "rifle") || StrEqual(weapon, "rifle_sg552"))
	{
		slot = 0;
		cilps = 50;
	}
	else if (StrEqual(weapon, "rifle_desert"))
	{
		slot = 0;
		cilps = 60;
	}
	else if (StrEqual(weapon, "pistol"))
	{
		slot = 1;
		if (GetEntProp(GetPlayerWeaponSlot(client, 1), Prop_Send, "m_isDualWielding") > 0)
			cilps = 30;
		else
			cilps = 15;
	}
	else if (StrEqual(weapon, "pistol_magnum"))
	{
		slot = 1;
		cilps = 8;
	}
	else if (StrEqual(weapon, "chainsaw"))
	{
		slot = 1;
		cilps = 30;
	}
}

enum struct GameSetting
{
	char difficulty[24];
	char mode[24];

	void RefreshMode()
	{
		ConVar cvar = FindConVar("mp_gamemode");
		cvar.GetString(this.mode, 24);
	}

	void RefreshDifficulty()
	{
		ConVar cvar = FindConVar("z_difficulty");
		cvar.GetString(this.difficulty, 24);
	}

	void Refresh()
	{
		this.RefreshMode();
		this.RefreshDifficulty();
	}

	void TranslateDiffculty(int client, char[] buffer)
	{
		Format(buffer, 24, "%T", this.difficulty, client);
	}

	void TranslateMode(int client, char[] buffer)
	{
		Format(buffer, 24, "%T", this.mode, client);
	}
}

stock int GetEventClient(Event event, const char[] id)
{
	return GetClientOfUserId(event.GetInt(id));
}

/**************************************************************************
 *                                                                        *
 *          	 	     	 New color inc   				    	      *
 *                          Author: Ernecio (updated by pan0s)            *
 *                           Version: 1.0.1                               *
 *                                                                        *
 **************************************************************************/
enum
{
	SERVER_INDEX	= 0,
	NO_INDEX		= -1,
	NO_PLAYER		= -2,
	BLUE_INDEX		= 2,
	RED_INDEX		= 3,
}

stock const char CTag[][] 				= { "{DEFAULT}", "{ORANGE}", "{CYAN}", "{RED}", "{BLUE}", "{GREEN}" };
stock const char CTagCode[][] 			= { "\x01", "\x04", "\x03", "\x03", "\x03", "\x05" };
stock const bool CTagReqSayText2[] 	= { false, false, true, true, true, false };
stock const int CProfile_TeamIndex[] 	= { NO_INDEX, NO_INDEX, SERVER_INDEX, RED_INDEX, BLUE_INDEX, NO_INDEX };

/**
 * @note Prints a message to a specific client in the chat area.
 * @note Supports color tags.
 *
 * @param client 		Client index.
 * @param sMessage 		Message (formatting rules).
 * @return 				No return
 * 
 * On error/Errors:   If the client is not connected an error will be thrown.
 */
stock void CPrintToChat( int client, const char[] sMessage, any ... )
{
	if ( client <= 0 || client > MaxClients )
		ThrowError( "Invalid client index %d", client );
	
	if ( !IsClientInGame( client ) )
		ThrowError( "Client %d is not in game", client );
	
	static char sBuffer[250];
	static char sCMessage[250];
	SetGlobalTransTarget(client);
	Format( sBuffer, sizeof( sBuffer ), "\x01%s", sMessage );
	VFormat( sCMessage, sizeof( sCMessage ), sBuffer, 3 );
	
	int index = CFormat( sCMessage, sizeof( sCMessage ) );
	if( index == NO_INDEX )
		PrintToChat( client, sCMessage );
	else
		CSayText2( client, index, sCMessage );
}

/**
 * @note Prints a message to all clients in the chat area.
 * @note Supports color tags.
 *
 * @param client		Client index.
 * @param sMessage 		Message (formatting rules)
 * @return 				No return
 */
stock void CPrintToChatAll( const char[] sMessage, any ... )
{
	static char sBuffer[250];
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && !IsFakeClient( i ) )
		{
			SetGlobalTransTarget( i );
			VFormat( sBuffer, sizeof( sBuffer ), sMessage, 2 );
			CPrintToChat( i, sBuffer );
		}
	}
}

/**
 * @note Replaces color tags in a string with color codes
 *
 * @param sMessage    String.
 * @param maxlength   Maximum length of the string buffer.
 * @return			  Client index that can be used for SayText2 author index
 * 
 * On error/Errors:   If there is more then one team color is used an error will be thrown.
 */
stock int CFormat( char[] sMessage, int maxlength )
{	
	int iRandomPlayer = NO_INDEX;
	
	for ( int i = 0; i < sizeof(CTagCode); i++ )													//	Para otras etiquetas de color se requiere un bucle.
	{
		if ( StrContains( sMessage, CTag[i]) == -1 ) 										//	Si no se encuentra la etiqueta, omitir.
			continue;
		else if ( !CTagReqSayText2[i] )
			ReplaceString( sMessage, maxlength, CTag[i], CTagCode[i] ); 					//	Si la etiqueta no necesita Saytext2 simplemente reemplazará.
		else																				//	La etiqueta necesita Saytext2.
		{	
			if ( iRandomPlayer == NO_INDEX )												//	Si no se especificó un cliente aleatorio para la etiqueta, reemplaca la etiqueta y busca un cliente para la etiqueta.
			{
				iRandomPlayer = CFindRandomPlayerByTeam( CProfile_TeamIndex[i] ); 			//	Busca un cliente válido para la etiqueta, equipo de infectados oh supervivientes.
				if ( iRandomPlayer == NO_PLAYER ) 
					ReplaceString( sMessage, maxlength, CTag[i], CTagCode[5] ); 			//	Si no se encuentra un cliente valido, reemplasa la etiqueta con una etiqueta de color verde.
				else 
					ReplaceString( sMessage, maxlength, CTag[i], CTagCode[i] ); 			// 	Si el cliente fue encontrado simplemente reemplasa.
			}
			else 																			//	Si en caso de usar dos colores de equipo infectado y equipo de superviviente juntos se mandará un mensaje de error.
				ThrowError("Using two team colors in one message is not allowed"); 			//	Si se ha usadó una combinación de colores no validad se registrara en la carpeta logs.
		}
	}
	
	return iRandomPlayer;
}

/**
 * @note Founds a random player with specified team
 *
 * @param color_team  Client team.
 * @return			  Client index or NO_PLAYER if no player found
 */
stock int CFindRandomPlayerByTeam( int color_team )
{
	if ( color_team == SERVER_INDEX )
		return 0;
	else
		for ( int i = 1; i <= MaxClients; i ++ )
			if ( IsClientInGame( i ) && GetClientTeam( i ) == color_team )
				return i;

	return NO_PLAYER;
}

/**
 * @note Sends a SayText2 usermessage to a client
 *
 * @param sMessage 		Client index
 * @param maxlength 	Author index
 * @param sMessage 		Message
 * @return 				No return.
 */
stock void CSayText2( int client, int author, const char[] sMessage )
{
	Handle hBuffer = StartMessageOne( "SayText2", client );
	BfWriteByte( hBuffer, author );
	BfWriteByte( hBuffer, true );
	BfWriteString( hBuffer, sMessage );
	EndMessage();
}
