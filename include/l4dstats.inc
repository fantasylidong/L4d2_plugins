#if defined  _l4d2_stats_included_
 #endinput
#endif
#define _l4d2_stats_included_
native int l4dstats_GetClientScore(int client);
native int l4dstats_IsTopPlayer(int client, int ranklimit);
native int l4dstats_GetClientPlayTime(int client);
native int l4dstats_AdddClientScore(int client, int Score); 
forward void l4dstats_AnnounceGameTime(int client);