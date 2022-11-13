#pragma semicolon 1

//#define BoostForward 40.0 // Bhop
// Velocity
new Handle:hCvarTankBhop;

public Tank_OnModuleStart() 
{
	hCvarTankBhop = CreateConVar("ai_tank_bhop", "1", "Flag to enable bhop facsimile on AI tanks");
}
// Tank bhop and blocking rock throw
public Action:Tank_OnPlayerRunCmd( tank, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon )
 {
	// block rock throws
	if( bool:GetConVarBool(hCvarTankBhop) ) 
	{
		//buttons &= ~IN_ATTACK2;
		new flags = GetEntityFlags(tank);
		// Get the player velocity:
		new Float:fVelocity[3];
		GetEntPropVector(tank, Prop_Data, "m_vecVelocity", fVelocity);
		new Float:currentspeed = SquareRoot(Pow(fVelocity[0],2.0)+Pow(fVelocity[1],2.0));
		//PrintCenterTextAll("Tank Speed: %.1f", currentspeed);
		
		// Get Angle of Tank
		decl Float:clientEyeAngles[3];
		GetClientEyeAngles(tank,clientEyeAngles);
		
		// LOS and survivor proximity
		new Float:tankPos[3];
		GetClientAbsOrigin(tank, tankPos);
		new iSurvivorsProximity = GetSurvivorProximity(tankPos);
		new bool:bHasSight = bool:GetEntProp(tank, Prop_Send, "m_hasVisibleThreats"); //Line of sight to survivors
		if( bHasSight && (600 > iSurvivorsProximity > 170) && currentspeed > 200.0 ) 
		{ 
			
			if (flags & FL_ONGROUND) 
			{
				buttons |= IN_DUCK;
				buttons |= IN_ATTACK2;
				buttons |= IN_JUMP;
				
				
				if(buttons & IN_FORWARD) 
				{
					Client_Push( tank, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
					buttons &= ~IN_ATTACK2;
				}	
				
				if(buttons & IN_BACK) 
				{
					Client_Push( tank, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
						
				if(buttons & IN_MOVELEFT) 
				{
					Client_Push( tank, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
						
				if(buttons & IN_MOVERIGHT)
				{
					Client_Push( tank, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
				
			}
			
			//Block Jumping and Crouching when on ladder
			if (GetEntityMoveType(tank) & MOVETYPE_LADDER)
			{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
		if(buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT) 
		{
			
		}
		else
		{
			buttons &= ~IN_ATTACK2;
		}
	}
	return Plugin_Continue;	
}