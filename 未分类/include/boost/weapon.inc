#if defined boost_weapon_inc_
    #endinput
#endif
#define boost_weapon_inc_

enum WeaponId
{
	NONE,             // 0
	PISTOL,           // 1
	SMG,              // 2
	PUMPSHOTGUN,      // 3
	AUTOSHOTGUN,      // 4
	RIFLE,            // 5
	HUNTING_RIFLE,    // 6
	SMG_SILENCED,     // 7
	SHOTGUN_CHROME,   // 8
	RIFLE_DESERT,     // 9
	SNIPER_MILITARY,  // 10
	SHOTGUN_SPAS,     // 11
	FIRST_AID_KIT,    // 12
	MOLOTOV,          // 13
	PIPE_BOMB,        // 14
	PAIN_PILLS,       // 15
	GASCAN,           // 16
	PROPANE_TANK,     // 17
	OXYGEN_TANK,      // 18
	MELEE,            // 19
	CHAINSAW,         // 20
	GRENADE_LAUNCHER, // 21
	AMMO_PACK,        // 22
	ADRENALINE,       // 23
	DEFIBRILLATOR,    // 24
	VOMITJAR,         // 25
	RIFLE_AK47,       // 26
	GNOME_CHOMPSKI,   // 27
	COLA_BOTTLES,     // 28
	FIREWORKS_BOX,    // 29
	INCENDIARY_AMMO,  // 30
	FRAG_AMMO,        // 31
	PISTOL_MAGNUM,    // 32
	SMG_MP5,          // 33
	RIFLE_SG552,      // 34
	SNIPER_AWP,       // 35
	SNIPER_SCOUT,     // 36
	RIFLE_M60,        // 37
	TANK_CLAW,        // 38
	HUNTER_CLAW,      // 39
	CHARGER_CLAW,     // 40
	BOOMER_CLAW,      // 41
	SMOKER_CLAW,      // 42
	SPITTER_CLAW,     // 43
	JOCKEY_CLAW,      // 44
	MACHINEGUN,       // 45
	VOMIT,            // 46
	SPLAT,            // 47
	POUNCE,           // 48
	LOUNGE,           // 49
	PULL,             // 50
	CHOKE,            // 51
	ROCK,             // 52
	PHYSICS,          // 53
	AMMO,             // 54
	UPGRADE_ITEM      // 55
};

const char[][] WEAPONS_MODEL =
{
	"weapon_none",
	"weapon_pistol",
	"weapon_smg",
	"weapon_pumpshotgun",
	"weapon_autoshotgun",
	"weapon_rifle",
	"weapon_hunting_rifle",
	"weapon_smg_silenced",
	"weapon_rifle_desert",
	"weapon_sniper_military",
	"weapon_shotgun_spas",
	"weapon_first_aid_kit",
	"weapon_molotov",
	"weapon_pipe_bomb",
	"weapon_pain_pills",
	"weapon_gascan",
	"weapon_propanetank",
	"weapon_oxygentank",
	"weapon_melee",
	"weapon_chainsaw",
	"weapon_grenade_launcher",
	"weapon_ammo_pack",
	"weapon_adrenaline",
	"weapon_defibrillator",
	"weapon_vomitjar",
	"weapon_rifle_ak47",
	"weapon_gnome",
	"weapon_cola_bottles",
	"weapon_fireworkcrate",
	"weapon_upgradepack_incendiary",
	"weapon_upgradepack_explosive",
	"weapon_pistol_magnum",
	"weapon_smg_mp5",
	"weapon_rifle_sg552",
	"weapon_sniper_awp",
	"weapon_sniper_scout",
	"weapon_rifle_m60",
	"weapon_tank_claw",
	"weapon_hunter_claw",
	"weapon_charger_claw",
	"weapon_boomer_claw",
	"weapon_smoker_claw",
	"weapon_spitter_claw",
	"weapon_jockey_claw",
	"weapon_machinegun",
	"vomit",
	"splat",
	"pounce",
	"lounge",
	"pull",
	"choke",
	"rock",
	"physics",
	"ammo",
	"upgrade_item"
};

const float WEAPON_RELOAD_INTERVAL[WeaponId] = {
    0.0
};