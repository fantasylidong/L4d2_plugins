// I dont think it's a good idea to set a limit on SteamID
// because it wont have a terminator
// But I assume that the type of SteamID64 is UInt64
// The max value of UInt64 is 18,446,744,073,709,551,615
// so the max length of SteamID64 is 20 + 1 = 21
// It seems like that the length of the first and second section of Steam3 are constant
// and the third section is SteamID64 - 76,561,197,960,265,728
// so the max length of Steam3 is 4 + 20 + 1 = 25
// Steam2 is also called SteamID32 or just SteamID
// The third section of Steam2 is the third section of Steam3 / 2
// and the remainder is the second part of Steam2
// So the max length of Steam2 is 10 + 20 + 1 = 31
#define MAX_LENGTH_Steam2 30        // Ex. STEAM_0:0:204195052
#define MAX_LENGTH_Steam3 25        // Ex. [U:1:408390104]
#define MAX_LENGTH_SteamID64 21     // Ex. 76561198368655832