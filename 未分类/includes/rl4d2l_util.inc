#if defined _rl4d2l_util_
  #endinput
#endif
#define _rl4d2l_util_

stock void StrToLower(char[] arg) {
    for (int i = 0; i < strlen(arg); i++) {
        arg[i] = CharToLower(arg[i]);
    }
}

stock int GetCurrentMapLower(char[] buffer, int buflen) {
    int iBytesWritten = GetCurrentMap(buffer, buflen);
    StrToLower(buffer);
    return iBytesWritten;
}