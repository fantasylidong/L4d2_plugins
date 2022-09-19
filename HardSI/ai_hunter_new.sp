#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar
	g_hLungeInterval,
	g_hFastPounceProximity,
	g_hPounceVerticalAngle,
	g_hPounceAngleMean,
	g_hPounceAngleStd,
	g_hStraightPounceProximity,
	g_hAimOffsetSensitivityHunter,
	g_hWallDetectionDistance;

float
	g_fLungeInterval,
	g_fFastPounceProximity,
	g_fPounceVerticalAngle,
	g_fPounceAngleMean,
	g_fPounceAngleStd,
	g_fStraightPounceProximity,
	g_fWallDetectionDistance,
	g_fAimOffsetSensitivityHunter,
	g_fCanLungeTime[MAXPLAYERS + 1];

bool
	g_bHasQueuedLunge[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "AI HUNTER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart() {	
	g_hFastPounceProximity = CreateConVar("ai_fast_pounce_proximity", "1000.0", "At what distance to start pouncing fast");
	g_hPounceVerticalAngle = CreateConVar("ai_pounce_vertical_angle", "9.0", "Vertical angle to which AI hunter pounces will be restricted");
	g_hPounceAngleMean = CreateConVar("ai_pounce_angle_mean", "10.0", "Mean angle produced by Gaussian RNG");
	g_hPounceAngleStd = CreateConVar("ai_pounce_angle_std", "20.0", "One standard deviation from mean as produced by Gaussian RNG");
	g_hStraightPounceProximity = CreateConVar("ai_straight_pounce_proximity", "350.0", "Distance to nearest survivor at which hunter will consider pouncing straight");
	g_hAimOffsetSensitivityHunter = CreateConVar("ai_aim_offset_sensitivity_hunter", "180.0", "If the hunter has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius", _, true, 0.0, true, 180.0);
	g_hWallDetectionDistance = CreateConVar("ai_wall_detection_distance", "-1.0", "How far in front of himself infected bot will check for a wall. Use '-1' to disable feature");
	g_hLungeInterval = FindConVar("z_lunge_interval");

	FindConVar("hunter_pounce_ready_range").SetFloat(2000.0);
	FindConVar("hunter_pounce_max_loft_angle").SetFloat(0.0);
	FindConVar("hunter_leap_away_give_up_range").SetFloat(0.0);
	FindConVar("z_pounce_silence_range").SetFloat(999999.0);
	FindConVar("hunter_committed_attack_range").SetFloat(999999.0);
	FindConVar("z_pounce_crouch_delay").SetFloat(0.1);

	g_hLungeInterval.AddChangeHook(vCvarChanged);
	g_hFastPounceProximity.AddChangeHook(vCvarChanged);
	g_hPounceVerticalAngle.AddChangeHook(vCvarChanged);
	g_hPounceAngleMean.AddChangeHook(vCvarChanged);
	g_hPounceAngleStd.AddChangeHook(vCvarChanged);
	g_hStraightPounceProximity.AddChangeHook(vCvarChanged);
	g_hAimOffsetSensitivityHunter.AddChangeHook(vCvarChanged);
	g_hWallDetectionDistance.AddChangeHook(vCvarChanged);
	
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("ability_use", Event_AbilityUse);
}

public void OnPluginEnd() {
	FindConVar("hunter_committed_attack_range").RestoreDefault();
	FindConVar("hunter_pounce_ready_range").RestoreDefault();
	FindConVar("hunter_leap_away_give_up_range").RestoreDefault();
	FindConVar("hunter_pounce_max_loft_angle").RestoreDefault();
	FindConVar("z_pounce_crouch_delay").RestoreDefault();
}

public void OnConfigsExecuted() {
	vGetCvars();
}

void vCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars();
}

void vGetCvars() {
	g_fLungeInterval = g_hLungeInterval.FloatValue;
	g_fFastPounceProximity = g_hFastPounceProximity.FloatValue;
	g_fPounceVerticalAngle = g_hPounceVerticalAngle.FloatValue;
	g_fPounceAngleMean = g_hPounceAngleMean.FloatValue;
	g_fPounceAngleStd = g_hPounceAngleStd.FloatValue;
	g_fStraightPounceProximity = g_hStraightPounceProximity.FloatValue;
	g_fAimOffsetSensitivityHunter = g_hAimOffsetSensitivityHunter.FloatValue;
	g_fWallDetectionDistance = g_hWallDetectionDistance.FloatValue;
}

public void OnMapEnd() {
	for (int i = 1; i <= MaxClients; i++)
		g_fCanLungeTime[i] = 0.0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_fCanLungeTime[client] = 0.0;
	g_bHasQueuedLunge[client] = false;
}

void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
		return;

	static char sUse[16];
	event.GetString("ability", sUse, sizeof(sUse));
	if (strcmp(sUse, "ability_lunge") == 0)
		vHunter_OnPounce(client);
}

public Action OnPlayerRunCmd(int client, int &buttons) {
	if (!IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 3 || GetEntProp(client, Prop_Send, "m_isGhost"))
		return Plugin_Continue;

	static int flags;
	flags = GetEntityFlags(client);
	if (flags & FL_DUCKING == 0 || flags & FL_ONGROUND == 0 || !GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
		return Plugin_Continue;
	
	buttons &= ~IN_ATTACK2;

	static float vPos[3];
	GetClientAbsOrigin(client, vPos);
	if (fNearestSurDistance(client, vPos) > g_fFastPounceProximity)
		return Plugin_Changed;

	buttons &= ~IN_ATTACK;	
	if (!g_bHasQueuedLunge[client]) {
		g_bHasQueuedLunge[client] = true;
		g_fCanLungeTime[client] = GetGameTime() + g_fLungeInterval;
	}
	else if (g_fCanLungeTime[client] < GetGameTime()) {
		buttons |= IN_ATTACK;
		g_bHasQueuedLunge[client] = false;
	}	

	return Plugin_Changed;
}

float fNearestSurDistance(int client, const float vPos[3]) {
	static int i;
	static int iCount;
	static float vTar[3];
	static float fDistance[MAXPLAYERS + 1];

	iCount = 0;
	for (i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			GetClientAbsOrigin(i, vTar);
			fDistance[iCount++] = GetVectorDistance(vPos, vTar);
		}
	}

	if (!iCount)
		return -1.0;

	SortFloats(fDistance, iCount, Sort_Ascending);
	return fDistance[0];
}

void vHunter_OnPounce(int client) {	
	static int iEnt;
	static float vPos[3];
	GetClientAbsOrigin(client, vPos);
	if (g_fWallDetectionDistance > 0.0 && bHitWall(client, vPos)) {
		iEnt = GetEntPropEnt(client, Prop_Send, "m_customAbility");
		vAngleLunge(iEnt, GetRandomInt(0, 1) ? 45.0 : 315.0);
	}
	else {	
		if (bIsBeingWatched(client, g_fAimOffsetSensitivityHunter) && fNearestSurDistance(client, vPos) > g_fStraightPounceProximity) {
			iEnt = GetEntPropEnt(client, Prop_Send, "m_customAbility");
			vAngleLunge(iEnt, fGaussianRNG(g_fPounceAngleMean, g_fPounceAngleStd));
			vLimitLungeVerticality(iEnt);				
		}	
	}
}

#define OBSTACLE_HEIGHT 18.0
bool bHitWall(int client, float vStart[3]) {
	vStart[2] += OBSTACLE_HEIGHT;
	static float vAng[3];
	static float vEnd[3];
	GetClientEyeAngles(client, vAng);
	GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vAng, vAng);
	vEnd = vAng;
	ScaleVector(vEnd, g_fWallDetectionDistance);
	AddVectors(vStart, vEnd, vEnd);

	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vStart, vEnd, view_as<float>({-16.0, -16.0, 0.0}), view_as<float>({16.0, 16.0, 36.0}), MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	if (TR_DidHit(hTrace)) {
		static float vPlane[3];
		TR_GetPlaneNormal(hTrace, vPlane);
		if (RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vPlane))) > 150.0) {
			delete hTrace;
			return true;
		}
	}

	delete hTrace;
	return false;
}

bool bTraceEntityFilter(int entity, int contentsMask) {
	if (entity <= MaxClients)
		return false;

	static char cls[9];
	GetEntityClassname(entity, cls, sizeof cls);
	if ((cls[0] == 'i' && strcmp(cls[1], "nfected") == 0) || (cls[0] == 'w' && strcmp(cls[1], "itch") == 0))
		return false;

	return true;
}

bool bIsBeingWatched(int client, float fOffsetThreshold) {
	static int iTarget;
	if (bIsAliveSur((iTarget = GetClientAimTarget(client))) && fGetPlayerAimOffset(client, iTarget) > fOffsetThreshold)
		return false;

	return true;
}

float fGetPlayerAimOffset(int client, int iTarget) {
	static float vAng[3];
	static float vPos[3];
	static float vDir[3];
	GetClientEyeAngles(iTarget, vAng);
	vAng[0] = vAng[2] = 0.0;
	GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vAng, vAng);

	GetClientAbsOrigin(client, vPos);
	GetClientAbsOrigin(iTarget, vDir);
	vPos[2] = vDir[2] = 0.0;
	MakeVectorFromPoints(vDir, vPos, vDir);
	NormalizeVector(vDir, vDir);

	return RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vDir)));
}

void vAngleLunge(int iEnt, float fTurnAngle) {	
	static float vLunge[3];
	GetEntPropVector(iEnt, Prop_Send, "m_queuedLunge", vLunge);
	fTurnAngle = DegToRad(fTurnAngle);

	static float vForcedLunge[3];
	vForcedLunge[0] = vLunge[0] * Cosine(fTurnAngle) - vLunge[1] * Sine(fTurnAngle);
	vForcedLunge[1] = vLunge[0] * Sine(fTurnAngle) + vLunge[1] * Cosine(fTurnAngle);
	vForcedLunge[2] = vLunge[2];

	SetEntPropVector(iEnt, Prop_Send, "m_queuedLunge", vForcedLunge);	
}

void vLimitLungeVerticality(int iEnt) {
	static float vLunge[3];
	GetEntPropVector(iEnt, Prop_Send, "m_queuedLunge", vLunge);

	static float fVertAngle;
	fVertAngle = DegToRad(g_fPounceVerticalAngle);	

	static float vFlatLunge[3];
	vFlatLunge[1] = vLunge[1] * Cosine(fVertAngle) - vLunge[2] * Sine(fVertAngle);
	vFlatLunge[2] = vLunge[1] * Sine(fVertAngle) + vLunge[2] * Cosine(fVertAngle);
	vFlatLunge[0] = vLunge[0] * Cosine(fVertAngle) + vLunge[2] * Sine(fVertAngle);
	vFlatLunge[2] = vLunge[0] * -Sine(fVertAngle) + vLunge[2] * Cosine(fVertAngle);
	
	SetEntPropVector(iEnt, Prop_Send, "m_queuedLunge", vFlatLunge);
}

/** 
 * Thanks to Newteee:
 * Random number generator fit to a bellcurve. Function to generate Gaussian Random Number fit to a bellcurve with a specified mean and std
 * Uses Polar Form of the Box-Muller transformation
*/
float fGaussianRNG(float fMean, float fStd) {
	static float fX1;
	static float fX2;
	static float fW;

	do {
		fX1 = 2.0 * GetRandomFloat(0.0, 1.0) - 1.0;
		fX2 = 2.0 * GetRandomFloat(0.0, 1.0) - 1.0;
		fW = Pow(fX1, 2.0) + Pow(fX2, 2.0);
	} while (fW >= 1.0);
	
	static const float e = 2.71828;
	fW = SquareRoot(-2.0 * (Logarithm(fW, e) / fW));

	static float fY1;
	static float fY2;
	fY1 = fX1 * fW;
	fY2 = fX2 * fW;

	static float fZ1;
	static float fZ2;
	fZ1 = fY1 * fStd + fMean;
	fZ2 = fY2 * fStd - fMean;

	return GetRandomFloat(0.0, 1.0) < 0.5 ? fZ1 : fZ2;
}

bool bIsAliveSur(int client) {
	return 0 < client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}