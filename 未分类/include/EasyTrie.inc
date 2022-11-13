#if defined _easytrie_included
 #endinput
#endif
#define _easytrie_included

stock Handle:EasyHTTP_CreateParams()
{
	new Handle:m_hData = CreateDataPack();
	WritePackCell(m_hData, CreateArray(64));
	WritePackCell(m_hData, CreateTrie());
	ResetPack(m_hData);

	return m_hData;
}

stock EasyHTTP_WriteParamString(Handle:data, const String:key[], const String:value[])
{
	new Handle:m_hKeys = ReadPackCell(data);
	new Handle:m_hValues = ReadPackCell(data);
	ResetPack(data);

	PushArrayString(m_hKeys, key);
	SetTrieString(m_hValues, key, value);
}

stock EasyHTTP_WriteParamInt(Handle:data, const String:key[], const value)
{
	new Handle:m_hKeys = ReadPackCell(data);
	new Handle:m_hValues = ReadPackCell(data);
	ResetPack(data);

	new String:m_szValue[32];
	Format(STRING(m_szValue), "%d", value);

	PushArrayString(m_hKeys, key);
	SetTrieString(m_hValues, key, m_szValue);
}

stock EasyHTTP_WriteParamFloat(Handle:data, const String:key[], const Float:value)
{
	new Handle:m_hKeys = ReadPackCell(data);
	new Handle:m_hValues = ReadPackCell(data);
	ResetPack(data);

	new String:m_szValue[32];
	Format(STRING(m_szValue), "%.3f", value);

	PushArrayString(m_hKeys, key);
	SetTrieString(m_hValues, key, m_szValue);
}

stock EasyHTTP_DestroyParams(Handle:data)
{
	ResetPack(data);
	new Handle:m_hKeys = ReadPackCell(data);
	new Handle:m_hValues = ReadPackCell(data);

	CloseHandle(m_hKeys);
	CloseHandle(m_hValues);
	CloseHandle(data);
}