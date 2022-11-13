#if defined _discord_scoreboard_included_
  #endinput
#endif
#define _discord_scoreboard_included_

native void AddEmbed(const char[] title, const char[] description, const char[] url, int color, any ... );

public SharedPlugin __pl_discord_scoreboard = 
{
    name = "discord_scoreboard",
    file = "discord_scoreboard.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_discord_scoreboard_SetNTVOptional()
{
    MarkNativeAsOptional("AddEmbed");
}
#endif