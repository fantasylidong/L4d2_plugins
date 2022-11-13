#if defined boost_infected_inc_
    #endinput
#endif
#define boost_infected_inc_

#include <boost/sdk>

enum SpecialInfected
{
    Smoker = 1,
    Boomer,
    Hunter,
    Spitter,
    Jockey,
    Charger,
    Witch,
    Tank
};

/**
 * @brief       Add function to private forward.
 * @remarks     Order IS NOT guaranteed.
 * @remarks     Make sure that function signature matches.

 * @return      SAME LEVEL functions CONTINUE TO EXECUTING if Plugin_Continue,
 *              SAME LEVEL functions STOP and EXECUTE LOW LEVEL functions if Plugin_Handled;
 *              LOW LEVEL functions STOP if Plugin_Stop; ONLY USE IT IF YOU KNOW WHAT YOU ARE DOING!
*/
native bool Infected_RegisterForward(const char[] name, Function forward_function);

forward void Infected_OnPlayerDeath(int client);

/**
 * @brief           Called whenever ZombieManager::SpawnSpecial(ZombieClassType,Vector&,QAngle&) is invoked
 * @remarks         Only used for bot special spawns (not players)
 *
 * @param class     Zombie class that will be spawned.
 * @param pos       Vector coordinate where special will be spawned
 * @param ang       QAngle where spcial will be facing
 *
 * @return          Plugin_Stop to block this spawn.
 *                  Change on class will make effect NOMATTER WHAT RETURNED except Plugin_Stop.
 */
forward Action Infected_OnSpawnSpecial(SpecialInfected& class, float pos[3], float ang[3]);

/**
 * @brief Attempts to find a random valid position to spawn a Special Infected
 * @remarks The zombieClass does not matter but different values yield different results:
 * @remarks Using the Tank zombieClass probably searches for a larger area that's clear of objects
 * @remarks —— Different value seems to perfer different area.
 *
 * @param client			Client id to find an area near this player
 * @param zombie_class		Special Infected class to search for a spawn position for
 * @param attempts			How many tries to find a valid location
 * @param vec		    	The vector array to store the valid location on success
 *
 * @return					True on success, false on failure to find valid location
 */
#define Infected_GetRandomPZSpawnPosition SDK_GetRandomPZSpawnPosition

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
#define Infected_SpawnSpecial SDK_SpawnSpecial

public SharedPlugin __pl_boost_infected = 
{
    name = "Boost - Infected",
    file = "boost/infected.smx",
    required = 0,
};

public void __pl_boost_infected_SetNTVOptional()
{
    MarkNativeAsOptional("Infected_RegisterForward");

}