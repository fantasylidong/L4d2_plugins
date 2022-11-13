#if defined boost_director_inc_
    #endinput
#endif
#define boost_director_inc_

#include <boost/sdk>

/**
 * @brief       Add function to private forward.
 * @remarks     Order IS NOT guaranteed.
 * @remarks     Make sure that function signature matches.

 * @return      SAME LEVEL functions CONTINUE TO EXECUTING if Plugin_Continue,
 *              SAME LEVEL functions STOP and EXECUTE LOW LEVEL functions if Plugin_Handled;
 *              LOW LEVEL functions STOP if Plugin_Stop; ONLY USE IT IF YOU KNOW WHAT YOU ARE DOING!
*/
native bool Director_RegisterForward(const char[] name, Function forward_function);

forward void Director_OnFirstSurvivorLeftSafeArea(int client);

forward void Director_OnRoundStart();

public SharedPlugin __pl_boost_director = 
{
    name = "Boost - Director",
    file = "boost/director.smx",
    required = 0,
};

public void __pl_boost_director_SetNTVOptional()
{
    MarkNativeAsOptional("Director_RegisterForward");

}