#if defined boost_string_inc_
    #endinput
#endif
#define boost_string_inc_


public SharedPlugin __pl_boost_string = 
{
	name = "BoostString",
	file = "string.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_boost_string_SetNTVOptional()
{
	
}