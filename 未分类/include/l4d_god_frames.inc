#if defined _godframes_included
  #endinput
#endif
#define _godframes_included

/**
 * @brief		Forward when an invulnerable client is taking damage.
 * @brief		You can modify damage and return Plugin_Handled or Plugin_Changed etc like OnTakeDamage.
 *
 * @param		client		The client who is invulnerable.
 * @param		attacker	The attacker damaging the client.
 * @param		damage		Amount of damage being dealt.
 * @return		none.
 */
forward Action OnTakeDamage_Invulnerable(int client, int attacker, float &damage);