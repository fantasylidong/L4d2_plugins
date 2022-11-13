#if defined boost_sdk_inc_
    #endinput
#endif
#define boost_sdk_inc_

/**
 * @brief       Add function to private forward.
 *
 * @remarks     Order IS NOT guaranteed.
 * @remarks     Make sure that function signature matches.

 * @return      SAME LEVEL functions CONTINUE TO EXECUTING if Plugin_Continue,
 *              SAME LEVEL functions STOP and EXECUTE LOW LEVEL functions if Plugin_Handled;
 *              LOW LEVEL functions STOP if Plugin_Stop; ONLY USE IT IF YOU KNOW WHAT YOU ARE DOING!
*/
native bool SDK_RegisterForward(const char[] name, Function forward_function);

/**
 * @brief Attempts to find a random valid position to spawn a Special Infected.
 *
 * @remarks The zombieClass does not matter but different values yield different results:
 * @remarks Using the Tank zombieClass probably searches for a larger area that's clear of objects
 * @remarks —— Different value seems to perfer different area.
 *
 * @param client            Client id to find an area near this player
 * @param zombie_class      Special Infected class to search for a spawn position for
 * @param attempts          How many tries to find a valid location
 * @param vec               The vector array to store the valid location on success
 *
 * @return                  True on success, false on failure to find valid location
 */
native bool SDK_GetRandomPZSpawnPosition(int client, int zombie_class, int attempts, float vec[3]);

/**
 * @brief       Calls ZombieManager::SpawnSpecial(ZombieClassType,Vector&,QAngle&)
 *
 * @remarks     Only used for bot special spawns (not players)
 *
 * @param pos   Vector coordinate where the SI will be spawned
 * @param ang   QAngle where the SI will be facing
 *
 * @return      Entity index of the spawned SI
 */
native int SDK_SpawnSpecial(int zombie_class, const float pos[3], const float ang[3]);

public SharedPlugin __pl_boost_sdk = 
{
    name = "Boost - SDK",
    file = "boost/sdk.smx",
    required = 0,
};

public void __pl_boost_sdk_SetNTVOptional()
{
    MarkNativeAsOptional("SDK_RegisterForward");

    MarkNativeAsOptional("SDK_GetRandomPZSpawnPosition");
    MarkNativeAsOptional("SDK_SpawnSpecial");
}