
#define SOUNDS_MENU_SELECT "buttons/button14.wav"
#define SOUNDS_MENU_EXIT "buttons/combine_button7.wav"

stock sounds_PlayToClient(clientIndex,
                            const String:sndPath[],
                            entity = SOUND_FROM_PLAYER,
                            channel = SNDCHAN_AUTO,
                            level = SNDLEVEL_NORMAL,
                            flags = SND_NOFLAGS,
                            Float:volume = SNDVOL_NORMAL,
                            pitch = SNDPITCH_NORMAL,
                            speakerentity = -1,
                            const Float:origin[3] = NULL_VECTOR,
                            const Float:dir[3] = NULL_VECTOR,
                            bool:updatePos = true,
                            Float:soundtime = 0.0)
{
   new clients[1];
   
   clients[0] = clientIndex;
   entity = (entity == SOUND_FROM_PLAYER) ? clientIndex : entity;
   
   EmitSound(clients, 1, sndPath, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);	
}

stock sounds_PlayToClients( clientIndexes[],
                            clientCount,
                            const String:sndPath[],
                            entity = SOUND_FROM_PLAYER,
                            channel = SNDCHAN_AUTO,
                            level = SNDLEVEL_NORMAL,
                            flags = SND_NOFLAGS,
                            Float:volume = SNDVOL_NORMAL,
                            pitch = SNDPITCH_NORMAL,
                            speakerentity = -1,
                            const Float:origin[3] = NULL_VECTOR,
                            const Float:dir[3] = NULL_VECTOR,
                            bool:updatePos = true,
                            Float:soundtime = 0.0)
{  
   EmitSound(clientIndexes, clientCount, sndPath, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);	
}

stock sounds_PlayToAll(  const String:sndPath[],
                            entity = SOUND_FROM_PLAYER,
                            channel = SNDCHAN_AUTO,
                            level = SNDLEVEL_NORMAL,
                            flags = SND_NOFLAGS,
                            Float:volume = SNDVOL_NORMAL,
                            pitch = SNDPITCH_NORMAL,
                            speakerentity = -1,
                            const Float:origin[3] = NULL_VECTOR,
                            const Float:dir[3] = NULL_VECTOR,
                            bool:updatePos = true,
                            Float:soundtime = 0.0)
{
   EmitSoundToAll(sndPath, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);	
}
