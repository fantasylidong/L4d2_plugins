/*
enum PluginStatusEx		// most constants are defined as "PluginStatus" enum in core.inc
{
	Plugin_Running		// successful load/reload operation
	Plugin_Paused		
	Plugin_Error		
	Plugin_Loaded		
	Plugin_Failed		
	Plugin_Created		
	Plugin_Uncompiled	
	Plugin_BadLoad		
	Plugin_Evicted		
	-1					// for INVALID_HANDLE, like <DISABLED> plugins (also, it's a default value for "pre"-forwards)
}
*/

/**
 * Called once, before and after all other forwards raised during single update cycle
 *
 * @param pre			1 - plugins update sequence is started
 *						0 - plugins update sequence is ended
 *	-
 * @noreturn
 */
forward void AP_OnPluginUpdate(int pre);

/**
 * Called before and after each single plugin is loaded
 *
 * @param path			path of the plugin operated, relative to /plugins/ folder
 * @param pre			1 - plugin is about to load (you can block plugin loading in this call)
 *						0 - plugin loading is finished, with any status (see the "status" value in this call)
 * @param status		See the "PluginStatusEx" enum. Only "Plugin_Running" value should be considered as successful.
 *	-
 * @return				Plugin_Stop (or any non-zero value) - to block plugin from loading
 *						Plugin_Continue - don't interfere with default behavior
 */
forward Action AP_OnPluginLoad(char[] path, int pre, int status);

/**
 * Called before and after each single plugin is reloaded
 *
 * @param path			path of the plugin operated, relative to /plugins/ folder
 * @param pre			1 - plugin is about to reload (you can block plugin reloading in this call)
 *						0 - plugin reloading is finished, with any status (see the "status" value in this call)
 * @param status		See the "PluginStatusEx" enum. Only "Plugin_Running" value should be considered as successful.
 *	-
 * @return				Plugin_Stop (or any non-zero value) - to block plugin from loading
 *						Plugin_Continue - don't interfere with default behavior
 */
forward Action AP_OnPluginReload(char[] path, int pre, int status);

/**
 * Called before and after each single plugin is unloaded
 *
 * @param path			path of the plugin operated, relative to /plugins/ folder
 * @param pre			1 - plugin is about to unload (you can prevent plugin unloading in this call)
 *						0 - plugin is unloaded
 *	-
 * @return				Plugin_Stop (or any non-zero value) - to block plugin from loading
 *						Plugin_Continue - don't interfere with default behavior
 */
forward Action AP_OnPluginUnload(char[] path, int pre);

/*
	Notice:
	
	 - these forwards doesn't report about actions made by other plugins including sourcemod itself, like:
	 
	  > when you manually load/reload/unload plugin via console;
	  > when SM load/reload/unload plugin between OnMapEnd and OnMapStart events (map transition).

*/
