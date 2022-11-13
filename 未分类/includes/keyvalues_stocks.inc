#include <keyvalues>
#include <textparse>

#if defined __keyvalues_stocks__
#endinput
#endif
#define __keyvalues_stocks__


static Handle:kvparser;
static Handle:currentKv;

// parser state tracking
static bool:justStarted;

stock AddFileToKeyValues(Handle:kv, const String:file[])
{
        if(kvparser == INVALID_HANDLE) kvparser=InitParser();
        currentKv=kv;
        justStarted=true;
        SMC_ParseFile(kvparser, file);
        currentKv=INVALID_HANDLE;
}

static Handle:InitParser()
{
        new Handle:parser = SMC_CreateParser();
        SMC_SetReaders(parser, KVAdder_NewSection, KVAdder_KeyValue, KVAdder_EndSection);
        return parser;
}

public SMCResult:KVAdder_NewSection(Handle:smc, const String:name[], bool:opt_quotes)
{
        decl String:buf[255];
        if(justStarted)
        {
                justStarted=false;
                KvGetSectionName(currentKv, buf, sizeof(buf));
                if(StrEqual(name, buf))
                {
                        return SMCParse_Continue;
                }
        }
        KvJumpToKey(currentKv, name, true);        
        return SMCParse_Continue;
}

public SMCResult:KVAdder_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
        KvSetString(currentKv, key, value);
        return SMCParse_Continue;
}

public SMCResult:KVAdder_EndSection(Handle:smc)
{
        KvGoBack(currentKv);
}
