#if defined boost_tank_inc_
    #endinput
#endif
#define boost_tank_inc_

// Forwards
forward Action OnTankPunchPre(int client);
forward Action OnTankPunchPost(int client, int& sequence);
forward Action OnTankThrowPre(int client);
forward void OnTankThrowPost(int client);
forward Action OnTankTakeDamage(int client, int& attacker, int& inflictor, float& damage, int& damage_type, int& weapon, float damage_force[3], float damage_position[3], int damage_custom);