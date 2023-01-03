public SharedPlugin __pl_TogsJumpStats = 
{
    name = "TogsJumpStats",
    file = "TogsJumpStats.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
}

#if defined _TogsJumpStats_Included
	#endinput
#endif
#define _TogsJumpStats_Included

forward void TJS_OnClientDetected(int client, char[] sReason, char[] sStats);