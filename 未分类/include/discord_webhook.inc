#if defined _discord_webhook_included_
  #endinput
#endif
#define _discord_webhook_included_

native void FormatEmbed(String:buffer[], bufferLen, const String:title[], const String:description[], const String:url[], color, any ... );
native void FormatEmbed2(String:buffer[], bufferLen, const String:title[], const String:description[], const String:url[], color, const String:fields[] );
native void FormatEmbedRequest(String:buffer[], bufferLen, const String:message[]);
native void SendEmbedToDiscord(const String:webhook[], const String:title[], const String:description[], const String:url[], color, any ... );
native void SendMessageToDiscord(const String:webhook[], const String:message[]);
native void SendToDiscord(const String:webhook[], const String:message[]);

public SharedPlugin __pl_discord_webhook = 
{
    name = "discord_webhook",
    file = "discord_webhook.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_discord_webhook_SetNTVOptional()
{
    MarkNativeAsOptional("FormatEmbed");
    MarkNativeAsOptional("FormatEmbed2");
    MarkNativeAsOptional("FormatEmbedRequest");
    MarkNativeAsOptional("SendEmbedToDiscord");
    MarkNativeAsOptional("SendMessageToDiscord");
    MarkNativeAsOptional("SendToDiscord");
}
#endif