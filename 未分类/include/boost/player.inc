#if defined boost_player_inc_
    #endinput
#endif
#define boost_player_inc_

/*************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************
 
          OnClientConnect   OnClientConnected     OnClientAuthorized                 OnClientPutInServer                                                OnClientDisconnect  OnClientDisconnect_Post  OnMapEnd  OnMapStart  OnClientConnect  OnClientConnected  OnClientAuthorized    OnClientPutInServer                                                OnClientDisconnect   OnClientDisconnect_Post
                 |                                                                            |                                                                                                                                                                                                                                                                  |                       |
 ________________|__________________|______________________|__________________________________|__________________________________________________________________|_____________________|_________________|__________|_____________|__________________|__________________|_____________________|__________________________________________________________________|_______________________|__________________
   Disconnected                                  Connecting                                                                                                                                           Playing                                                                                                                                                          Disconnecting        Disconnectted
                   |                                                                            |                                                                                                                                                                                                                                                                  |                        |
            OnPlayerConnect                                                             OnPlayerConnected                                                                                                                                                                                                                                                  OnPlayerDisconnect      OnPlayerDisconnected
 
 *************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************/

/**
 * @brief       Add function to private forward.
 *
 * @remarks     Order IS NOT guaranteed.
 * @remarks     Make sure that function signature matches.
 * @remarks     IN MOST OCCASIONS YOU NEED NOT TO USE IT.
 *
 * @return      SAME LEVEL functions CONTINUE TO EXECUTING if Plugin_Continue,
 *              SAME LEVEL functions STOP and EXECUTE LOW LEVEL functions if Plugin_Handled;
 *              LOW LEVEL functions STOP if Plugin_Stop; ONLY USE IT IF YOU KNOW WHAT YOU ARE DOING!
*/
native bool Player_RegisterForward(const char[] name, Function forward_function);

/**
 * @brief           Called on player trying to connect.
 *
 * @param client    Client id that trying to connect.
 *
 * @return          Connection will be rejected if return Plugin_Stop.
*/
forward Action Player_OnPlayerConnect(int client);

/**
 * @brief           Called when player already fully connected into server.
 *
 * @param client    Client id that connected.
*/
forward void Player_OnPlayerConnected(int client);

/**
 * @brief           Called when player dies.
 *
 * @param client    Client id that dies.
*/
forward void Player_OnPlayerDeath(int client);

/**
 * @brief           Called when player disconnects.
 *
 * @param client    Client id that disconnects.
*/
forward void Player_OnPlayerDisconnect(int client);

forward void Player_OnPlayerDisconnected(int client);

public SharedPlugin __pl_boost_player = 
{
    name = "Boost - Player",
    file = "boost/player.smx",
    required = 0,
};

public void __pl_boost_player_SetNTVOptional()
{
    MarkNativeAsOptional("Player_RegisterForward");

}