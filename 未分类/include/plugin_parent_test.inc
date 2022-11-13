#if defined _plugin_parent_test_included_
  #endinput
#endif
#define _plugin_parent_test_included_

public SharedPlugin __pl_plugin_parent_test = 
{
    name = "plugin_parent_test",
    file = "plugin_parent_test.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_plugin_parent_test_SetNTVOptional()
{
}
#endif