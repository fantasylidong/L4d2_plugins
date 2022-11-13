#if defined  _bosspercent_included_
    #endinput
#endif
#define _bosspercent_included_

/**
 * Triggers a refresh of percent values which are displayed by the boss percent plugin.
 *
 * @note    To concord your custom boss percents with the ready-up footer, use a timer of ~5.5s in round_start
 * @return          True if no error occured during the refresh
 */
native bool:UpdateBossPercents();

public SharedPlugin:__pl_bosspercent =
{
    name = "l4d_boss_percent",
    file = "l4d_boss_percent.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_bosspercent_SetNTVOptional()
{
    MarkNativeAsOptional("UpdateBossPercents");
}

// vim: ft=sourcepawn et sw=8
