#if defined _team_consistency_included
	#endinput
#endif
#define _team_consistency_included

native void ClearTeamConsistency();

public SharedPlugin __pl_team_consistency =
{
	name = "team_consistency",
	file = "team_consistency.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_team_consistency_SetNTVOptional()
{
	MarkNativeAsOptional("ClearTeamConsistency");
}
#endif
