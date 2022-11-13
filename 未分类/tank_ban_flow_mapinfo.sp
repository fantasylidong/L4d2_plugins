#include <sourcemod>

public void OnPluginStart()
{
	RegConsoleCmd("sm_uei", uei);
	RegConsoleCmd("sm_gogo", gogo);
}

public Action uei(int a, int b)
{
	if (b != 1) return Plugin_Handled;
	
	char buffer[PLATFORM_MAX_PATH];
	GetCmdArgString(buffer, sizeof buffer);
	StripQuotes(buffer);
	
	if (!FileExists(buffer))
	{
		ReplyToCommand(a, "Unable to open file: \"%s\"", buffer);
		return Plugin_Handled;
	}
	
	KeyValues kv = new KeyValues("MapInfo");
	if (!kv.ImportFromFile(buffer))
	{
		ReplyToCommand(a, "Unable to import from file: \"%s\"", buffer);
		return Plugin_Handled;
	}
	
	if (!kv.GotoFirstSubKey())
	{
		ReplyToCommand(a, "Unable to read first sub key: \"%s\"", buffer);
		return Plugin_Handled;
	}
	
	ArrayList aList = new ArrayList(2);
	
	do
	{
		if (kv.GetNum("tank_ban_flow_min", -1) == -1)
			continue;
		
		aList.Clear();
		
		aList.Push(kv.GetNum("tank_ban_flow_min"));
		aList.Set(0, kv.GetNum("tank_ban_flow_max"), 1);
		
		kv.DeleteKey("tank_ban_flow_min");
		kv.DeleteKey("tank_ban_flow_max");
		
		if (kv.GetNum("tank_ban_flow_min_b", -1) != -1)
		{
			aList.Push(kv.GetNum("tank_ban_flow_min_b"));
			aList.Set(1, kv.GetNum("tank_ban_flow_max_b"), 1);
			
			kv.DeleteKey("tank_ban_flow_min_b");
			kv.DeleteKey("tank_ban_flow_max_b");
		
			if (kv.GetNum("tank_ban_flow_min_c", -1) != -1)
			{
				aList.Push(kv.GetNum("tank_ban_flow_min_c"));
				aList.Set(2, kv.GetNum("tank_ban_flow_max_c"), 1);
			
				kv.DeleteKey("tank_ban_flow_min_c");
				kv.DeleteKey("tank_ban_flow_max_c");
			}
		}
		
		int size = aList.Length;
		
		kv.JumpToKey("tank_ban_flow", true);
		
		for (int i = 1; i <= size; i++)
		{
			char key[2];
			IntToString(i, key, 2);
			kv.JumpToKey(key, true);
			kv.SetNum("min", aList.Get(i-1, 0));
			kv.SetNum("max", aList.Get(i-1, 1));
			kv.GoBack();
		}
		
		kv.GoBack();
	}
	while (kv.GotoNextKey());
	
	kv.Rewind();
	kv.ExportToFile(buffer);
	
	ReplyToCommand(a, "Finished processing file: \"%s\"", buffer);
	return Plugin_Handled;
}

public Action gogo(int a, int b)
{
	if (b != 1) return Plugin_Handled;
	
	char buffer[PLATFORM_MAX_PATH];
	GetCmdArgString(buffer, sizeof buffer);
	StripQuotes(buffer);
	
	if (!FileExists(buffer))
	{
		ReplyToCommand(a, "Unable to open file: \"%s\"", buffer);
		return Plugin_Handled;
	}
	
	KeyValues kv = new KeyValues("MapInfo");
	if (!kv.ImportFromFile(buffer))
	{
		ReplyToCommand(a, "Unable to import from file: \"%s\"", buffer);
		return Plugin_Handled;
	}
	
	if (!kv.GotoFirstSubKey())
	{
		ReplyToCommand(a, "Unable to read first sub key: \"%s\"", buffer);
		return Plugin_Handled;
	}
	
	ArrayList aList = new ArrayList(2);
	
	do
	{
		if (kv.GetNum("witch_ban_flow_min", -1) == -1)
			continue;
		
		aList.Clear();
		
		aList.Push(kv.GetNum("witch_ban_flow_min"));
		aList.Set(0, kv.GetNum("witch_ban_flow_max"), 1);
		
		kv.DeleteKey("witch_ban_flow_min");
		kv.DeleteKey("witch_ban_flow_max");
		
		if (kv.GetNum("witch_ban_flow_min_b", -1) != -1)
		{
			aList.Push(kv.GetNum("witch_ban_flow_min_b"));
			aList.Set(1, kv.GetNum("witch_ban_flow_max_b"), 1);
			
			kv.DeleteKey("witch_ban_flow_min_b");
			kv.DeleteKey("witch_ban_flow_max_b");
		
			if (kv.GetNum("witch_ban_flow_min_c", -1) != -1)
			{
				aList.Push(kv.GetNum("witch_ban_flow_min_c"));
				aList.Set(2, kv.GetNum("witch_ban_flow_max_c"), 1);
			
				kv.DeleteKey("witch_ban_flow_min_c");
				kv.DeleteKey("witch_ban_flow_max_c");
			}
		}
		
		int size = aList.Length;
		
		kv.JumpToKey("witch_ban_flow", true);
		
		for (int i = 1; i <= size; i++)
		{
			char key[2];
			IntToString(i, key, 2);
			kv.JumpToKey(key, true);
			kv.SetNum("min", aList.Get(i-1, 0));
			kv.SetNum("max", aList.Get(i-1, 1));
			kv.GoBack();
		}
		
		kv.GoBack();
	}
	while (kv.GotoNextKey());
	
	kv.Rewind();
	kv.ExportToFile(buffer);
	
	ReplyToCommand(a, "Finished processing file: \"%s\"", buffer);
	return Plugin_Handled;
}