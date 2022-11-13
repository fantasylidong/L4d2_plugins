#if defined _f18airstrike_included_
  #endinput
#endif
#define _f18airstrike_included_


/**
 * @brief Creates an F-18 AirStrike at the location and from the direction specified.
 *
 * @param		origin0    Float: origin vector index [0].
 * @param		origin1    Float: origin vector index [1].
 * @param		origin2    Float: origin vector index [2].
 * @param		direction    Float: angle direction for the jet to appear.
 * @return		none.
 */
native F18_ShowAirstrike(Float:origin0, Float:origin1, Float:origin2, Float:direction);


/**
 * @brief Sets when the plugin is turned on or off.
 *
 * @param		pluginstate		0=Off, 1=On.
 * @noreturn
 */
forward F18_OnPluginState(pluginstate);


/**
 * @brief Sets when the plugin is active/inactive in a round.
 *
 * @param		roundstate		0=Started, 1=Stopped.
 * @noreturn
 */
forward F18_OnRoundState(roundstate);


/**
 * @brief Called when an AirStrike is created, XYZ vector position of where the AirStrike originates
 *
 * @param		x    Float: origin vector index [0].
 * @param		y    Float: origin vector index [1].
 * @param		z    Float: origin vector index [2].
 * @noreturn
 */
forward F18_OnAirstrike(Float:x, Float:y, Float:z);


/**
 * @brief Called when the missile impacts, XYZ vector position of where the explosion is
 *
 * @param		x    Float: origin vector index [0].
 * @param		y    Float: origin vector index [1].
 * @param		z    Float: origin vector index [2].
 * @noreturn
 */
forward F18_OnMissileHit(Float:x, Float:y, Float:z);