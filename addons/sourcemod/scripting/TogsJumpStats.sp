#pragma semicolon 1
#define PLUGIN_VERSION "1.10.2"	//changelog at bottom
#define TAG "[TOGs Jump Stats] "
#define CSGO_RED "\x07"
#define CSS_RED "\x07FF0000"

#include <sourcemod>
#include <multicolors>
#include <sdktools>
#include <autoexecconfig>
#include <sourcebanspp>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "TOGs Jump Stats",
	author = "That One Guy (based on code from Inami)",
	description = "Player bhop method analysis.",
	version = PLUGIN_VERSION,
	url = "http://www.togcoding.com"
}

ConVar g_hEnableLogs = null;
ConVar g_hReqMultRoundsHyp = null;
ConVar g_hAboveNumber = null;
ConVar g_hAboveNumberFlags = null;
ConVar g_hHypPerf = null;
ConVar g_hHacksPerf = null;
ConVar g_hCooldown = null;
ConVar g_hPatCount = null;
ConVar g_hStatsFlag = null;
char g_sStatsFlag[30];
ConVar g_hAdminFlag = null;
char g_sAdminFlag[30];
ConVar g_hNotificationFlag = null;
char g_sNotificationFlag[30];
ConVar g_hRelogDiff = null;
ConVar g_hFPSMaxMinValue = null;
ConVar g_hBanHacks = null;
ConVar g_hBanPat = null;
ConVar g_hBanHyp = null;
ConVar g_hBanFPSMax = null;

float ga_fAvgJumps[MAXPLAYERS + 1] = {1.0, ...};
float ga_fAvgSpeed[MAXPLAYERS + 1] = {250.0, ...};
float ga_fVel[MAXPLAYERS + 1][3];
float ga_fLastPos[MAXPLAYERS + 1][3];
float ga_fAvgPerfJumps[MAXPLAYERS + 1] = {0.3333, ...};
float ga_fMaxPerf[MAXPLAYERS + 1] = {0.0, ...};

bool ga_bFlagged[MAXPLAYERS + 1];
bool ga_bFlagHypCurrentRound[MAXPLAYERS + 1];
bool ga_bFlagHypLastRound[MAXPLAYERS + 1];
bool ga_bFlagHypTwoRoundsAgo[MAXPLAYERS + 1];
bool ga_bSurfCheck[MAXPLAYERS + 1];
bool ga_bNotificationsPaused[MAXPLAYERS + 1] = {false, ...};

char g_sHypPath[PLATFORM_MAX_PATH];
char g_sHacksPath[PLATFORM_MAX_PATH];
char g_sPatPath[PLATFORM_MAX_PATH];

int ga_iJumps[MAXPLAYERS + 1] = {0, ...};
int ga_iPattern[MAXPLAYERS + 1] = {0, ...};
int ga_iPatternhits[MAXPLAYERS + 1] = {0, ...};
int ga_iAutojumps[MAXPLAYERS + 1] = {0, ...};
int ga_iIgnoreCount[MAXPLAYERS + 1];
int ga_iLastPos[MAXPLAYERS + 1] = {0, ...};
int ga_iNumberJumpsAbove[MAXPLAYERS + 1];

int gaa_iLastJumps[MAXPLAYERS + 1][30];

int g_iTickCount = 1;
bool g_bDisableAdminMsgs = false;
bool g_bCSGO = false;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	AutoExecConfig_SetFile("togsjumpstats");
	AutoExecConfig_CreateConVar("tjs_version", PLUGIN_VERSION, "TOGs Jump Stats Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCooldown = AutoExecConfig_CreateConVar("tjs_gen_cooldown", "60", "Cooldown time between chat notifications to admins for any given clients that is flagged.", FCVAR_NONE, true, 0.0);
	
	g_hStatsFlag = AutoExecConfig_CreateConVar("tjs_flag_gen", "", "Players with this flag will be able to check stats. Set to \"public\" to let everyone use it.");
	g_hStatsFlag.AddChangeHook(OnCVarChange);
	g_hStatsFlag.GetString(g_sStatsFlag, sizeof(g_sStatsFlag));
	
	g_hAdminFlag = AutoExecConfig_CreateConVar("tjs_flag_adm", "b", "Players with this flag will be able to reset jump stats. Set to \"public\" to let everyone use it.");
	g_hAdminFlag.AddChangeHook(OnCVarChange);
	g_hAdminFlag.GetString(g_sAdminFlag, sizeof(g_sAdminFlag));
	
	g_hNotificationFlag = AutoExecConfig_CreateConVar("tjs_flag_notification", "b", "Players with this flag will see notifications when players are flagged. Set to \"public\" to let everyone use it.");
	g_hNotificationFlag.AddChangeHook(OnCVarChange);
	g_hNotificationFlag.GetString(g_sNotificationFlag, sizeof(g_sNotificationFlag));
	
	g_hRelogDiff = AutoExecConfig_CreateConVar("tjs_flag_relogdiff", "0.05", "Players are re-logged in the same map if they are flagged with a perf that is this much higher than the previous one.", FCVAR_NONE, true, 0.0, true, 1.0);
	
	g_hFPSMaxMinValue = AutoExecConfig_CreateConVar("tjs_fpsmax_minvalue", "60.0", "Minimum value of fps_max to enforce. Players below this will be flagged (other than zero).", FCVAR_NONE, true, 0.0, true, 1.0);
	
	g_hEnableLogs = AutoExecConfig_CreateConVar("tjs_gen_log", "1", "Enable logging player jump stats if a player is flagged (0 = Disabled, 1 = Enabled).", FCVAR_NONE, true, 0.0, true, 1.0);
	
	g_hReqMultRoundsHyp = AutoExecConfig_CreateConVar("tjs_hyp_mult_rounds", "1", "Clients will not be flagged (in logs and admin notifications) for hyperscrolling until they are noted 3 rounds in a row (0 = Disabled, 1 = Enabled).", FCVAR_NONE, true, 0.0, true, 1.0);
	
	g_hAboveNumber = AutoExecConfig_CreateConVar("tjs_hyp_numjumps", "16", "Number of jump commands to use as a threshold for flagging hyperscrollers.", FCVAR_NONE, true, 1.0);

	g_hAboveNumberFlags = AutoExecConfig_CreateConVar("tjs_hyp_threshold", "16", "Out of the last 30 jumps, the number of jumps that must be above tjs_numjumps to flag player for hyperscrolling.", FCVAR_NONE, true, 1.0);
	
	g_hHypPerf = AutoExecConfig_CreateConVar("tjs_hyp_perf", "0.6", "Above this perf ratio (in combination with the other hyperscroll cvars), players will be flagged for hyperscrolling.", FCVAR_NONE, true, 0.0, true, 1.0);

	g_hHacksPerf = AutoExecConfig_CreateConVar("tjs_hacks_perf", "0.8", "Above this perf ratio (ratios range between 0.0 - 1.0), players will be flagged for hacks.", FCVAR_NONE, true, 0.0, true, 1.0);
	
	g_hPatCount = AutoExecConfig_CreateConVar("tjs_pat_count", "18", "Number of jump out of the last 30 that must match to be flagged for pattern jumps (scripts).", FCVAR_NONE, true, 1.0);
	
	g_hBanHacks = AutoExecConfig_CreateConVar("tjs_ban_hacks", "0", "Ban length in minutes (0 = perm, -1 = disabled) for hacks detection.", FCVAR_NONE, true, -1.0);
	
	g_hBanPat = AutoExecConfig_CreateConVar("tjs_ban_pat", "-1", "Ban length in minutes (0 = perm, -1 = disabled) for pattern jumps detection.", FCVAR_NONE, true, -1.0);
	
	g_hBanHyp = AutoExecConfig_CreateConVar("tjs_ban_hyp", "-1", "Ban length in minutes (0 = perm, -1 = disabled) for hyperscroll detection.", FCVAR_NONE, true, -1.0);
	
	g_hBanFPSMax = AutoExecConfig_CreateConVar("tjs_ban_fpsmax", "-1", "Ban length in minutes (0 = perm, -1 = disabled) for FPS Max abuse detection.", FCVAR_NONE, true, -1.0);

	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Post);
	
	BuildPath(Path_SM, g_sHypPath, sizeof(g_sHypPath), "logs/togsjumpstats/hyperscrollers.log");
	BuildPath(Path_SM, g_sHacksPath, sizeof(g_sHacksPath), "logs/togsjumpstats/hacks.log");
	BuildPath(Path_SM, g_sPatPath, sizeof(g_sPatPath), "logs/togsjumpstats/patterns.log");

	RegConsoleCmd("sm_jumps", Command_Jumps, "Gives statistics for player jumps.");
	RegConsoleCmd("sm_stopmsgs", Command_StopAdminMsgs, "Stops admin chat notifications when players are flagged for current map.");
	RegConsoleCmd("sm_enablemsgs", Command_EnableAdminMsgs, "Re-enables admin chat notifications when players are flagged.");
	RegConsoleCmd("sm_msgstatus", Command_MsgStatus, "Check enabled/disabled status of admin chat notifications.");
	RegConsoleCmd("sm_resetjumps", Command_ResetJumps, "Reset statistics for a player.");
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	char sGame[32];
	GetGameFolderName(sGame, sizeof(sGame));
	if(StrEqual(sGame, "csgo", false))
	{
		g_bCSGO = true;
	}
	else
	{
		g_bCSGO = false;
	}
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	
	for(int i = 1; i <= MaxClients; i++)	//late load handler
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}
	
	char sBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "logs/togsjumpstats/");
	if(!DirExists(sBuffer))
	{
		CreateDirectory(sBuffer, 777);
	}
}

public void OnCVarChange(ConVar hCVar, const char[] sOldValue, const char[] sNewValue)
{
	if(hCVar == g_hStatsFlag)
	{
		g_hStatsFlag.GetString(g_sStatsFlag, sizeof(g_sStatsFlag));
	}
	else if(hCVar == g_hAdminFlag)
	{
		g_hAdminFlag.GetString(g_sAdminFlag, sizeof(g_sAdminFlag));
	}
	else if(hCVar == g_hNotificationFlag)
	{
		g_hNotificationFlag.GetString(g_sNotificationFlag, sizeof(g_sNotificationFlag));
	}
}

public Action Event_RoundStart(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
	if(g_hReqMultRoundsHyp.IntValue)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(ga_bFlagHypLastRound[i])
			{
				ga_bFlagHypTwoRoundsAgo[i] = true;
			}
			else
			{
				ga_bFlagHypTwoRoundsAgo[i] = false;
			}
			
			if(ga_bFlagHypCurrentRound[i])
			{
				ga_bFlagHypLastRound[i] = true;
			}
			else
			{
				ga_bFlagHypLastRound[i] = false;
			}
			
			ga_bFlagHypCurrentRound[i] = false;
		}
	}
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			QueryClientConVar(i, "fps_max", ClientConVar, i);
		}
	}
	
}

public int ClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] sCVarName, const char[] sCVarValue)
{
	float fValue = StringToFloat(sCVarValue);
	if((fValue < g_hFPSMaxMinValue.FloatValue) && fValue)	//if non-zero and less 
	{
		char sMsg[32];
		Format(sMsg, sizeof(sMsg), "fps_max-%s", sCVarValue);
		LogFlag(client, sMsg);
		if(!g_bDisableAdminMsgs)
		{
			NotifyAdmins(client, sMsg);
		}
	}
}

public void OnClientPutInServer(int client)
{
	ga_bNotificationsPaused[client] = false;
	ga_bFlagged[client] = false;
	ga_bFlagHypCurrentRound[client] = false;
	ga_bFlagHypLastRound[client] = false;
	ga_bFlagHypTwoRoundsAgo[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	if(HasFlags(client, g_sAdminFlag))
	{
		CreateTimer(30.0, TimerCB_CheckForFlags, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action TimerCB_CheckForFlags(Handle hTimer, any iUserID)
{
	int client = GetClientOfUserId(iUserID);
	int iCount = 0;
	if(IsValidClient(client))
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				if(ga_bFlagged[i])
				{
					iCount++;
				}
			}
		}
		if(iCount)
		{
			PrintToChat(client, "%s%s%i players have been flagged for jump stats! Please check everyone's stats!", TAG, g_bCSGO ? CSGO_RED : CSS_RED, iCount);
		}
	}
}

public void Event_PlayerJump(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsValidClient(client))
	{
		return;
	}
	
	ga_fAvgJumps[client] = (ga_fAvgJumps[client] * 9.0 + float(ga_iJumps[client])) / 10.0;
	
	float a_fVelVectors[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", a_fVelVectors);
	a_fVelVectors[2] = 0.0;
	float speed = GetVectorLength(a_fVelVectors);
	ga_fAvgSpeed[client] = (ga_fAvgSpeed[client] * 9.0 + speed) / 10.0;
	
	gaa_iLastJumps[client][ga_iLastPos[client]] = ga_iJumps[client];
	ga_iLastPos[client]++;
	if(ga_iLastPos[client] == 30)
	{
		ga_iLastPos[client] = 0;
	}
	
	if(ga_fAvgJumps[client] > 15.0)
	{
		if((ga_iPatternhits[client] > 0) && (ga_iJumps[client] == ga_iPattern[client]))
		{
			ga_iPatternhits[client]++;
			if(ga_iPatternhits[client] > g_hPatCount.IntValue)
			{
				if(!ga_bNotificationsPaused[client])
				{
					if(!g_bDisableAdminMsgs)
					{
						NotifyAdmins(client, "Pattern Jumps");
					}
				}
				
				if((ga_fAvgPerfJumps[client] - g_hRelogDiff.FloatValue) > ga_fMaxPerf[client])
				{
					LogFlag(client, "pattern jumps", ga_bFlagged[client]);
					ga_fMaxPerf[client] = ga_fAvgPerfJumps[client];
				}
			}
		}
		else if((ga_iPatternhits[client] > 0) && (ga_iJumps[client] != ga_iPattern[client]))
		{
			ga_iPatternhits[client] -= 2;
		}
		else
		{
			ga_iPattern[client] = ga_iJumps[client];
			ga_iPatternhits[client] = 2;
		}
	}
	
	if(ga_fAvgJumps[client] > 14.0)
	{
		//check if more than 8 of the last 30 jumps were above 12
		ga_iNumberJumpsAbove[client] = 0;
		
		for(int i = 0; i < 29; i++)	//count
		{
			if((gaa_iLastJumps[client][i]) > (g_hAboveNumber.IntValue - 1))	//threshhold for # jump commands
			{
				ga_iNumberJumpsAbove[client]++;
			}
		}
		if((ga_iNumberJumpsAbove[client] > (g_hAboveNumberFlags.IntValue - 1)) && (ga_fAvgPerfJumps[client] >= g_hHypPerf.FloatValue))	//if more than #
		{
			if(g_hReqMultRoundsHyp.IntValue)
			{
				if(ga_bFlagHypTwoRoundsAgo[client] && ga_bFlagHypLastRound[client])
				{						
					if(!ga_bNotificationsPaused[client])
					{
						if(!g_bDisableAdminMsgs)
						{
							NotifyAdmins(client, "Hyperscroll (3 rounds in a row)");
						}
					}
					
					if((ga_fAvgPerfJumps[client] - g_hRelogDiff.FloatValue) > ga_fMaxPerf[client])
					{
						LogFlag(client, "hyperscroll (3 rounds in a row)", ga_bFlagged[client]);
						ga_fMaxPerf[client] = ga_fAvgPerfJumps[client];
					}
				}
				else
				{
					ga_bFlagHypCurrentRound[client] = true;
				}	
			}
			else
			{
				if(!ga_bNotificationsPaused[client])
				{
					if(!g_bDisableAdminMsgs)
					{
						NotifyAdmins(client, "Hyperscroll");
					}
				}
				
				if((ga_fAvgPerfJumps[client] - g_hRelogDiff.FloatValue) > ga_fMaxPerf[client])
				{
					LogFlag(client, "hyperscroll", ga_bFlagged[client]);
					ga_fMaxPerf[client] = ga_fAvgPerfJumps[client];
				}
			}
		}
	}
	else if(ga_iJumps[client] > 1)
	{
		ga_iAutojumps[client] = 0;
	}

	ga_iJumps[client] = 0;
	float a_fTempVectors[3];
	a_fTempVectors = ga_fLastPos[client];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", ga_fLastPos[client]);
	
	float len = GetVectorDistance(ga_fLastPos[client], a_fTempVectors, true);
	if(len < 30.0)
	{   
		ga_iIgnoreCount[client] = 2;
	}
	
	if(ga_fAvgPerfJumps[client] >= g_hHacksPerf.FloatValue)
	{
		if(!ga_bNotificationsPaused[client])
		{
			if(!g_bDisableAdminMsgs)
			{
				NotifyAdmins(client, "Hacks");
			}
		}
		
		if((ga_fAvgPerfJumps[client] - g_hRelogDiff.FloatValue) > ga_fMaxPerf[client])
		{
			LogFlag(client, "hacks", ga_bFlagged[client]);
			ga_fMaxPerf[client] = ga_fAvgPerfJumps[client];
		}
	}
}

public Action Command_StopAdminMsgs(int client, int iArgs)
{
	if(!HasFlags(client, g_sAdminFlag) && IsValidClient(client))
	{
		ReplyToCommand(client, "%sYou do not have access to this command!", TAG);
		return Plugin_Handled;
	}
	
	StopMsgs(client);
	
	return Plugin_Handled;
}

public Action Command_MsgStatus(int client, int iArgs)
{
	if(!HasFlags(client, g_sAdminFlag) && IsValidClient(client))
	{
		ReplyToCommand(client, "%sYou do not have access to this command!", TAG);
		return Plugin_Handled;
	}
	
	if(g_bDisableAdminMsgs)
	{
		ReplyToCommand(client, "%sAdmin chat notifications for flagged players is currently disabled!", TAG);
	}
	else
	{
		ReplyToCommand(client, "%sAdmin chat notifications for flagged players is currently enabled.", TAG);
	}
	
	return Plugin_Handled;
}

void StopMsgs(any client)
{
	g_bDisableAdminMsgs = true;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC, true) && !IsFakeClient(i))
		{
			if(i > 0)
			{
				CPrintToChat(i, "%s%s%N has disabled admin notices for bhop cheats until map changes!", TAG, g_bCSGO ? CSGO_RED : CSS_RED, client);
			}
		}
	}
}

void EnableMsgs(any client)
{
	g_bDisableAdminMsgs = false;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC, true) && !IsFakeClient(i))
		{
			if(i > 0)
			{
				CPrintToChat(i, "%s%s%N has re-enabled admin notices for bhop cheats!", TAG, g_bCSGO ? CSGO_RED : CSS_RED, client);
			}
		}
	}
}

public Action Command_EnableAdminMsgs(int client, int iArgs)
{
	if(!HasFlags(client, g_sAdminFlag) && IsValidClient(client))
	{
		ReplyToCommand(client, "%sYou do not have access to this command!", TAG);
		return Plugin_Handled;
	}
	
	EnableMsgs(client);
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	g_bDisableAdminMsgs = false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ga_bNotificationsPaused[i] = false;
			ga_bFlagHypCurrentRound[i] = false;
			ga_bFlagHypLastRound[i] = false;
			ga_bFlagHypTwoRoundsAgo[i] = false;
		}
	}
}

void NotifyAdmins(int client, char[] sFlagType)
{
	if(IsValidClient(client))
	{
		if(StrContains(sFlagType, "fps_max", false) == -1)
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsValidClient(i) && HasFlags(i, g_sNotificationFlag))
				{
					CPrintToChat(i, "%s%s'%N' has been flagged for '%s'! Please check their jump stats!", TAG, g_bCSGO ? CSGO_RED : CSS_RED, client, sFlagType);
					PerformStats(i, client);
				}
			}
		
			ga_bNotificationsPaused[client] = true;
			CreateTimer(g_hCooldown.FloatValue, UnPause_TimerMonitor, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			char a_sTempArray[2][32];
			ExplodeString(sFlagType, "-", a_sTempArray, sizeof(a_sTempArray), sizeof(a_sTempArray[]));
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsValidClient(i) && HasFlags(i, g_sNotificationFlag))
				{
					CPrintToChat(i, "%s%s'%N' has been flagged for having fps_max set to %s! Please enforce a minimum value of %5.1f.", TAG, g_bCSGO ? CSGO_RED : CSS_RED, client, a_sTempArray[1], g_hFPSMaxMinValue.FloatValue);
					PerformStats(i, client);
				}
			}
		}
	}
}


public Action UnPause_TimerMonitor(Handle hTimer, any iUserID)
{
	int client = GetClientOfUserId(iUserID);
	if(IsValidClient(client))
	{
		ga_bNotificationsPaused[client] = false;
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	ga_iJumps[client] = 0;
	ga_fAvgJumps[client] = 5.0;
	ga_fAvgSpeed[client] = 250.0;
	ga_fAvgPerfJumps[client] = 0.3333;
	ga_iPattern[client] = 0;
	ga_iPatternhits[client] = 0;
	ga_iAutojumps[client] = 0;
	ga_iIgnoreCount[client] = 0;
	ga_bFlagged[client] = false;
	ga_bFlagHypCurrentRound[client] = false;
	ga_bFlagHypLastRound[client] = false;
	ga_bFlagHypTwoRoundsAgo[client] = false;
	ga_fVel[client][2] = 0.0;
	int i;
	while(i < 30)
	{
		gaa_iLastJumps[client][i] = 0;
		i++;
	}
}

public void OnGameFrame()
{
	if(g_iTickCount > 1*MaxClients)
	{
		g_iTickCount = 1;
	}
	else
	{
		if(g_iTickCount % 1 == 0)
		{
			int client = g_iTickCount / 1;
			if(ga_bSurfCheck[client] && IsClientInGame(client) && IsPlayerAlive(client))
			{	
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", ga_fVel[client]);
				if(ga_fVel[client][2] < -290)
				{
					ga_iIgnoreCount[client] = 2;
				}
				
			}
		}
		g_iTickCount++;
	}
}

void LogFlag(int client, const char[] sType, bool bAlreadyFlagged = false)
{
	if(IsValidClient(client))
	{
		char sStats[256], sLogMsg[300];
		GetClientStats(client, sStats, sizeof(sStats));
		Format(sLogMsg, sizeof(sLogMsg), "%s %s%s", sStats, sType, (bAlreadyFlagged ? " (already flagged this map)" : ""));

		if(StrEqual(sType, "hacks", false))
		{
			if(g_hEnableLogs.BoolValue)
			{
				LogToFileEx(g_sHacksPath, sLogMsg);
			}
			
			if(g_hBanHacks.IntValue != -1)
			{
				SBPP_BanPlayer(0, client, g_hBanHacks.IntValue, "Bhop hack");
			}
		}
		else if(StrEqual(sType, "pattern jumps", false))
		{
			if(g_hEnableLogs.BoolValue)
			{
				LogToFileEx(g_sPatPath, sLogMsg);
			}
			
			if(g_hBanPat.IntValue != -1)
			{
				SBPP_BanPlayer(0, client, g_hBanPat.IntValue, "Pattern jump");
			}
		}
		else if(StrEqual(sType, "hyperscroll", false) || StrEqual(sType, "hyperscroll (3 rounds in a row)", false))
		{
			if(g_hEnableLogs.BoolValue)
			{
				LogToFileEx(g_sHypPath, sLogMsg);
			}
			
			if(g_hBanHyp.IntValue != -1)
			{
				SBPP_BanPlayer(0, client, g_hBanHyp.IntValue, "Hyperscroll");
			}
		}
		else if(StrContains(sType, "fps_max", false) != -1)
		{
			char a_sTempArray[2][32];
			ExplodeString(sType, "-", a_sTempArray, sizeof(a_sTempArray), sizeof(a_sTempArray[]));
			Format(sLogMsg, sizeof(sLogMsg), "%L has fps_max set to %s (min. accepted value set to %i)! This can be used as a glitch to get high perfect percentages!", client, a_sTempArray[1], g_hFPSMaxMinValue.IntValue);
			
			if(g_hEnableLogs.BoolValue)
			{
				LogToFileEx(g_sHacksPath, sLogMsg);
			}
			
			if(g_hBanFPSMax.IntValue != -1)
			{
				SBPP_BanPlayer(0, client, g_hBanFPSMax.IntValue, "FPS max");
			}
		}
		ga_bFlagged[client] = true;
	}
}

public Action Command_Jumps(int client, int iArgs)
{
	if(iArgs != 1)
	{
		ReplyToCommand(client, "%sUsage: sm_jumps <#userid|name|@all>", TAG);
		return Plugin_Handled;
	}
	
	if(IsValidClient(client))
	{
		if(!HasFlags(client, g_sStatsFlag))
		{
			ReplyToCommand(client, "%sYou do not have access to this command!", TAG);
			return Plugin_Handled;
		}
	}
	
	char sArg[65];
	GetCmdArg(1, sArg, sizeof(sArg));

	char sTargetName[MAX_TARGET_LENGTH];
	int a_iTargets[MAXPLAYERS], iTargetCount;
	bool bTN_Is_ML;

	if((iTargetCount = ProcessTargetString(sArg, client, a_iTargets, MAXPLAYERS, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bTN_Is_ML)) <= 0)
	{
		ReplyToCommand(client, "Not found or invalid parameter.");
		return Plugin_Handled;
	}

	SortedStats(client, a_iTargets, iTargetCount);
	
	if(IsValidClient(client))
	{
		ReplyToCommand(client, "%sCheck console for output!", TAG);
	}

	return Plugin_Handled;
}

public Action Command_ResetJumps(int client, int iArgs)
{
	if(iArgs != 1)
	{
		ReplyToCommand(client, "%sUsage: sm_resetjumps <#userid|name|@all>", TAG);
		return Plugin_Handled;
	}
	
	if(IsValidClient(client))
	{
		if(!HasFlags(client, g_sAdminFlag) && IsValidClient(client))
		{
			ReplyToCommand(client, "%sYou do not have access to this command!", TAG);
			return Plugin_Handled;
		}
	}
	
	char sArg[65];
	GetCmdArg(1, sArg, sizeof(sArg));

	char sTargetName[MAX_TARGET_LENGTH];
	int a_iTargets[MAXPLAYERS], iTargetCount;
	bool bTN_Is_ML;

	if((iTargetCount = ProcessTargetString(sArg, client, a_iTargets, MAXPLAYERS, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bTN_Is_ML)) <= 0)
	{
		ReplyToCommand(client, "Not found or invalid parameter.");
		return Plugin_Handled;
	}
	
	for(int i = 0; i < iTargetCount; i++)
	{
		int target = a_iTargets[i];
		if(IsValidClient(target))
		{
			ResetJumps(target);
			ReplyToCommand(client, "%sStats are now reset for player %N.", TAG, target);
		}
	}

	return Plugin_Handled;
}

void ResetJumps(int target)
{
	for(int i = 0; i < 29; i++)
	{
		gaa_iLastJumps[target][i] = 0;
	}
}

void PerformStats(int client, int target)
{
	char sStats[300];
	GetClientStats(target, sStats, sizeof(sStats));
	if(IsValidClient(client))
	{
		PrintToConsole(client, "Flagged: %i || %s", ga_bFlagged[target], sStats);
	}
	else
	{
		PrintToServer("Flagged: %i || %s", ga_bFlagged[target], sStats);
	}
}

void SortedStats(int client, int[] a_iTargets, int iCount)
{
	float[][] a_fPerfs = new float[iCount][2];
	int iValidCount = 0;
	for(int i = 0; i < iCount; i++)
	{
		if(IsValidClient(a_iTargets[i]))
		{
			a_fPerfs[i][0] = ga_fAvgPerfJumps[a_iTargets[i]] * 1000;
			iValidCount++;
		}
		else
		{
			a_fPerfs[i][0] = -1.0;
		}
		a_fPerfs[i][1] = float(a_iTargets[i]);
	}
	
	SortCustom2D(a_fPerfs, iCount, SortPerfs); 
	
	char[][] a_sStats = new char[iValidCount][300];
	int k = 0;
	char sMsg[300];
	for(int j = 0; j < iCount; j++)
	{
		int target = RoundFloat(a_fPerfs[j][1]);
		if(IsValidClient(target) && (a_fPerfs[j][0] != -1.0))
		{
			//save to another array to display them in order, since the get stats takes time and therefor they can sometimes come out of order slightly
			char sStats[300];
			GetClientStats(target, sStats, sizeof(sStats));
			Format(sMsg, sizeof(sMsg), "Flagged: %d || %s", ga_bFlagged[target], sStats);
			strcopy(a_sStats[k], 300, sMsg);
			k++;
		}
	}
	
	if(IsValidClient(client))
	{
		for(int m = 0; m < iValidCount; m++)
		{
			PrintToConsole(client, a_sStats[m]);
		}
	}
	else
	{
		for(int m = 0; m < iValidCount; m++)
		{
			PrintToServer(a_sStats[m]);
		}
	}
	
}

public int SortPerfs(int[] x, int[] y, const int[][] aArray, Handle hHndl) 
{ 
    if(view_as<float>(x[0]) > view_as<float>(y[0])) 
	{
        return -1;
	}
    return view_as<float>(x[0]) < view_as<float>(y[0]); 
} 

void GetClientStats(int client, char[] sStats, int iLength)
{
	char sMap[128];
	GetCurrentMap(sMap, sizeof(sMap));
	Format(sStats, iLength, "Perf: %4.1f%% || Avg: %-4.1f / %5.1f || %L || Map: %s || Last: ",
		ga_fAvgPerfJumps[client]*100, ga_fAvgJumps[client], ga_fAvgSpeed[client], client, sMap);
	Format(sStats, iLength, "%s%i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i", sStats, 
		gaa_iLastJumps[client][0], gaa_iLastJumps[client][1], gaa_iLastJumps[client][2], gaa_iLastJumps[client][3], gaa_iLastJumps[client][4], gaa_iLastJumps[client][5],
		gaa_iLastJumps[client][6], gaa_iLastJumps[client][7], gaa_iLastJumps[client][8], gaa_iLastJumps[client][9], gaa_iLastJumps[client][10], gaa_iLastJumps[client][11],
		gaa_iLastJumps[client][12], gaa_iLastJumps[client][13], gaa_iLastJumps[client][14], gaa_iLastJumps[client][15], gaa_iLastJumps[client][16], gaa_iLastJumps[client][17],
		gaa_iLastJumps[client][18], gaa_iLastJumps[client][19], gaa_iLastJumps[client][20], gaa_iLastJumps[client][21], gaa_iLastJumps[client][22], gaa_iLastJumps[client][23],
		gaa_iLastJumps[client][24], gaa_iLastJumps[client][25], gaa_iLastJumps[client][26], gaa_iLastJumps[client][27], gaa_iLastJumps[client][28], gaa_iLastJumps[client][29]);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float a_fVel[3], float a_fAngles[3], int &weapon)
{
	if(IsPlayerAlive(client))
	{
		static bool bHoldingJump[MAXPLAYERS + 1];
		static bLastOnGround[MAXPLAYERS + 1];
		if(buttons & IN_JUMP)
		{
			if(!bHoldingJump[client])
			{
				bHoldingJump[client] = true;//started pressing +jump
				ga_iJumps[client]++;
				if(bLastOnGround[client] && (GetEntityFlags(client) & FL_ONGROUND))
				{
					ga_fAvgPerfJumps[client] = (ga_fAvgPerfJumps[client] * 9.0 + 0) / 10.0;
				   
				}
				else if(!bLastOnGround[client] && (GetEntityFlags(client) & FL_ONGROUND))
				{
					ga_fAvgPerfJumps[client] = (ga_fAvgPerfJumps[client] * 9.0 + 1) / 10.0;
				}
			}
		}
		else if(bHoldingJump[client]) 
		{
			bHoldingJump[client] = false;//released (-jump)
			
		}
		bLastOnGround[client] = GetEntityFlags(client) & FL_ONGROUND;  
	}
	
	return Plugin_Continue;
}

bool HasFlags(int client, char[] sFlags)
{
	if(StrEqual(sFlags, "public", false) || StrEqual(sFlags, "", false))
	{
		return true;
	}
	else if(StrEqual(sFlags, "none", false))	//useful for some plugins
	{
		return false;
	}
	else if(!client)	//if rcon
	{
		return true;
	}
	else if(CheckCommandAccess(client, "sm_not_a_command", ADMFLAG_ROOT, true))
	{
		return true;
	}
	
	AdminId id = GetUserAdmin(client);
	if(id == INVALID_ADMIN_ID)
	{
		return false;
	}
	int flags, clientflags;
	clientflags = GetUserFlagBits(client);
	
	if(StrContains(sFlags, ";", false) != -1) //check if multiple strings
	{
		int i = 0, iStrCount = 0;
		while(sFlags[i] != '\0')
		{
			if(sFlags[i++] == ';')
			{
				iStrCount++;
			}
		}
		iStrCount++; //add one more for stuff after last comma
		
		char[][] a_sTempArray = new char[iStrCount][30];
		ExplodeString(sFlags, ";", a_sTempArray, iStrCount, 30);
		bool bMatching = true;
		
		for(i = 0; i < iStrCount; i++)
		{
			bMatching = true;
			flags = ReadFlagString(a_sTempArray[i]);
			for(int j = 0; j <= 20; j++)
			{
				if(bMatching)	//if still matching, continue loop
				{
					if(flags & (1<<j))
					{
						if(!(clientflags & (1<<j)))
						{
							bMatching = false;
						}
					}
				}
			}
			if(bMatching)
			{
				return true;
			}
		}
		return false;
	}
	else
	{
		flags = ReadFlagString(sFlags);
		for(int i = 0; i <= 20; i++)
		{
			if(flags & (1<<i))
			{
				if(!(clientflags & (1<<i)))
				{
					return false;
				}
			}
		}
		return true;
	}
}

bool IsValidClient(int client, bool bAllowBots = false)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}
	return true;
}

/*
CHANGE LOG
----------------------------
1.3 05/17/14
	* Initial release.
	* Changelog started.
1.4:
	* Fixed issue with players still being flagged for hyperscroll after rejoining server (due to not clearing the "3 rounds in a row" booleans).
	* Made sm_jumps command public so that regular players can use it (per request).
1.5:
	* Removed commands to target all and converted to multi-target filters.
	* Converted all commands to console commands and to use the "HasFlags" filter.
	* Added a few lines to ignore bots.
	* Added a cvar for the number of identical jump numbers required to flag someone for pattern jumps. It was hard coded at 15 before.
	* Added cvar to set required flags for using stats commands.
	* When players are flagged and admins get the chat message, it now prints the stats to chat as well.
1.6:
	* Added code to make it so that after players are logged, it will add another log if they make it to higher perf rates, although there will still be a small cooldown time (10 sec).
	* Made a parallel version with no admin menu, since the admin menu can be made through the adminmenu_custom.txt file from sourcemod.
	* Reformatted stats output.
1.7:
	* Removed cool down time on re-log functionality, converting it to a cvar of what amount of a higher perf it must be to re-log.
	* Added CS:GO Support (chat colors, etc).
1.8:
	* Added tag at the end of logs if they were already flagged, and the log is just due to higher perf while still passing threshold.
	* Added check on round start for all players fps_max values to be above or equal to a set threshold (60 by default).
	* Fixed opposite sign needed for relogging if perf higher than when logged + cvar tolerance.
1.8.2.nm:
	* Added notifications for admins 30 seconds after connect to tell them if a player was flagged before they joined.
1.9.0.nm:
	* Removed <tog> include.
	* Changed g_iDisableAdminMsgs to boolean, since it was being used like one (only two options).
	* Replaced global cache of game folder name (for checking if CS:GO) with global cached boolean, thus not needing to check the game name each time, but rather check boolean value.
	* Cleaned up variable names all throughout the plugin and did general cleanup, deleting unneccesary code (havent touched this plugin in a long time).
1.9.1.nm
	* Broke apart GetClientStats formatting function to enforce 32 arg max (it had 35).
	* Converted to new syntax.
1.9.2
	* Made admin notification after connecting only show if a player has been flagged.
	* Added code to create log folder if it doesn't exist.
1.9.3
	* Fixed logs indication regarding whether a player has "already been flagged this map".
	* Changed console stats output from using %d to use %i for the "flagged" boolean output. Shouldn't make a difference as I can see, but made the change due to a report of the flag not functioning properly.
1.9.4
	* Added cvar for admin notification flags.
1.9.5
	* Minor edit to low fps_max detection - zero values were supposed to be allowed, but slipped through due to float decimals extending past string compared against. Fixed.
1.10.0
	* Added options to use sourcebans to ban for detections (defaults to bans for hacks only - scripts, hyperscroll, and fps_max abuse default to no ban).
1.10.1
	* Added alternative if sourcebans is not enabled. Renamed ban length CVars to no longer imply sourcebans (SB).
1.10.2
	* Moved notifications to its own flag cvar (tjs_flag_notification). Renamed flag cvars to update descriptions. Enforced new cvar.
	* Deleted tjs_gen_notifications, which is now redundant to tjs_flag_notification (set to "none" to disable - equivalent to tjs_gen_notifications 0).
*/

/*
To Do:
	* Add cfg option to disable hyperscroll detection...maybe if jumps is set to 0?
	* Code in natives to ignore a client. This would allow other plugins to ignore them, give them bhop hacks, later turn off hacks, then re-enable this plugin checking them.
	
need to add checks into togsjumpstats to see if sourcebans is loaded
RegPluginLibrary("sourcebans");
BanClient(
*/