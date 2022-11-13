#pragma semicolon 1
#include <sourcemod>

#define HANDLE_SIZE             1
#define INT_SIZE                1

#define PP_MAX_ENTRY_CHAR       4*120
#define PP_MAX_ENTRY_ID_CHAR    4*60
#define PP_MAX_PANEL_LINES      9
#define ITEMDRAW_WITHNEXT       (1<<5)
#define ITEMDRAW_NO_UPDATE      -1

#define PP_ITEM_CONTROL_DRAWSIZE 4
#define PP_ITEM_BACK_KEY        7
#define PP_ITEM_BACK            "Back"
#define PP_ITEM_BACK_DRAWSIZE   (5 + PP_ITEM_CONTROL_DRAWSIZE)
#define PP_ITEM_NEXT_KEY        8
#define PP_ITEM_NEXT            "Next"
#define PP_ITEM_NEXT_DRAWSIZE   (5 + PP_ITEM_CONTROL_DRAWSIZE)
#define PP_ITEM_EXIT_KEY        9
#define PP_ITEM_EXIT            "Exit"
#define PP_ITEM_EXIT_DRAWSIZE   (5 + PP_ITEM_CONTROL_DRAWSIZE)


#define PP_PACK_START_END_ELEMENT(%1,%2)   (%1 << 16 | %2)
#define PP_UNPACK_START_ELEMENT(%1)        (%1 >> 16)
#define PP_UNPACK_END_ELEMENT(%1)          (%1 & 0x0000FFFF)


enum pp_Items_StructureElements {
    String:     pp_Items_StructureElement_IdStr[PP_MAX_ENTRY_ID_CHAR],
    String:     pp_Items_StructureElement_Str[PP_MAX_ENTRY_CHAR],
                pp_Items_StructureElement_DrawFlags,
                pp_Items_StructureElements_COUNT
}

enum pp_ClientInfos_StructureElements {
    Handle:     pp_Players_StructureElement_Panel,
                pp_Players_StructureElement_Page,
    MenuHandler:pp_Players_StructureElement_Callback,
    Float:      pp_Players_StructureElement_DisplayStartTime,
    Float:      pp_Players_StructureElement_DisplayTimeOut,
                pp_Players_StructureElements_COUNT
}

enum pp_StructureElements {
                pp_StructureElement_Title,
                pp_StructureElement_Items,
                pp_StructureElement_Pages,
                pp_StructureElements_COUNT
}

static pp_StructureElementsSize[_:pp_StructureElements] =
{
    PP_MAX_ENTRY_CHAR,                  // pp_StructureElement_Title
    _:pp_Items_StructureElements_COUNT, // pp_StructureElement_Items
    INT_SIZE,                           // pp_StructureElement_Pages
};

static g_hClientInfos[MAXPLAYERS+1][pp_ClientInfos_StructureElements];

static String:g_sDrawItem[PP_MAX_ENTRY_CHAR];
    
stock Handle:pp_Create()
{
    new Handle:pp = CreateArray(HANDLE_SIZE, _:pp_StructureElements_COUNT);
    
    for (new index = 0; index < _:pp_StructureElements_COUNT; index++)
    {
        SetArrayCell(pp, index, CreateArray(pp_StructureElementsSize[index]));
    }
    
    PushArrayString(GetArrayCell(pp, _:pp_StructureElement_Title), "");
    
    return pp;
}

stock pp_Close(Handle:pp)
{
    for(new index = 0; index < sizeof(g_hClientInfos); index++)
    {
        if(g_hClientInfos[index][pp_Players_StructureElement_Panel] == pp)
            g_hClientInfos[index][pp_Players_StructureElement_Panel] = Handle:0;
    }
    
    for (new index = 0; index < _:pp_StructureElements_COUNT; index++)
    {
        CloseHandle(GetArrayCell(pp, index));
    }
    
    CloseHandle(pp);
}

stock pp_SetTittle(Handle:pp, String:displayStr[], bool:updateDisplay=false)
{
    new Handle:title = GetArrayCell(pp, _:pp_StructureElement_Title);
    ClearArray(title);
    PushArrayString(title, displayStr);
    
    if(updateDisplay)
    for(new client = 1; client < MaxClients; client++)
    {
        if(IsClientConnected(client) && IsClientInGame(client) && g_hClientInfos[client][pp_Players_StructureElement_Panel] != Handle:0)
        {
            pp_DisplayToClient(pp, client, g_hClientInfos[client][pp_Players_StructureElement_Callback],
                               g_hClientInfos[client][pp_Players_StructureElement_DisplayTimeOut] != Float:MENU_TIME_FOREVER? g_hClientInfos[client][pp_Players_StructureElement_DisplayTimeOut] - (GetGameTime() - g_hClientInfos[client][pp_Players_StructureElement_DisplayStartTime]): Float:MENU_TIME_FOREVER,
                               PP_UNPACK_START_ELEMENT(GetArrayCell(GetArrayCell(pp, _:pp_StructureElement_Pages), g_hClientInfos[client][pp_Players_StructureElement_Page])),
                               .noCallback = true
                              );
        }
    }
}

stock pp_GetTittle(Handle:pp, String:displayStr[], size = sizeof(displayStr))
{
    return GetArrayString(GetArrayCell(pp, _:pp_StructureElement_Title), 0, displayStr, size);
}

stock pp_AddItem(Handle:pp, String:id[], String:displayStr[], drawFlags=ITEMDRAW_DEFAULT, bool:updateDisplay=false)
{
    decl item[pp_Items_StructureElements];
    
    strcopy(item[pp_Items_StructureElement_IdStr], PP_MAX_ENTRY_ID_CHAR, id);
    strcopy(item[pp_Items_StructureElement_Str], PP_MAX_ENTRY_CHAR, displayStr);
    item[pp_Items_StructureElement_DrawFlags] = drawFlags;
    
    new index = PushArrayArray(GetArrayCell(pp, _:pp_StructureElement_Items), item);
    
    if(updateDisplay)
    for(new client = 1; client < MaxClients; client++)
    {
        pp_page_ComputePagination(pp);
        
        if(IsClientConnected(client) && IsClientInGame(client) && g_hClientInfos[client][pp_Players_StructureElement_Panel] != Handle:0)
        {
            decl currentpageStart;
            pp_GetPageStart(pp, g_hClientInfos[client][pp_Players_StructureElement_Page], currentpageStart);
            
            new page = pp_FindPageFromItem(pp, index);
            
            if(-1 <= page - g_hClientInfos[client][pp_Players_StructureElement_Page] <= 1)
                pp_DisplayToClient(pp, client, g_hClientInfos[client][pp_Players_StructureElement_Callback],
                                   g_hClientInfos[client][pp_Players_StructureElement_DisplayTimeOut] != Float:MENU_TIME_FOREVER? g_hClientInfos[client][pp_Players_StructureElement_DisplayTimeOut] - (GetGameTime() - g_hClientInfos[client][pp_Players_StructureElement_DisplayStartTime]): Float:MENU_TIME_FOREVER,
                                   currentpageStart,
                                   .noCallback = true
                                  );
        }
    }
    
    return index;
}

stock bool:pp_UpdateItem(Handle:pp, String:id[], String:displayStr[], drawFlags=ITEMDRAW_NO_UPDATE, bool:updateDisplay=false)
{
    new index = FindStringInArray(GetArrayCell(pp, _:pp_StructureElement_Items), id);
    
    if(index == -1)
       return false;
    
    decl item[pp_Items_StructureElements];
    GetArrayArray(GetArrayCell(pp, _:pp_StructureElement_Items), index, item);
    
    if(!StrEqual("", displayStr))
        strcopy(item[pp_Items_StructureElement_Str], PP_MAX_ENTRY_CHAR, displayStr);
    if(drawFlags != ITEMDRAW_NO_UPDATE)
        item[pp_Items_StructureElement_DrawFlags] = drawFlags;
    
    SetArrayArray(GetArrayCell(pp, _:pp_StructureElement_Items), index, item);
    
    if(updateDisplay)
    for(new client = 1; client < MaxClients; client++)
    {
        if(IsClientConnected(client) && IsClientInGame(client) && g_hClientInfos[client][pp_Players_StructureElement_Panel] != Handle:0)
        {
            new page = pp_FindPageFromItem(pp, index);
            
            if(page == g_hClientInfos[client][pp_Players_StructureElement_Page])
                pp_DisplayToClient(pp, client, g_hClientInfos[client][pp_Players_StructureElement_Callback],
                                   g_hClientInfos[client][pp_Players_StructureElement_DisplayTimeOut] != Float:MENU_TIME_FOREVER? g_hClientInfos[client][pp_Players_StructureElement_DisplayTimeOut] - (GetGameTime() - g_hClientInfos[client][pp_Players_StructureElement_DisplayStartTime]): Float:MENU_TIME_FOREVER,
                                   index,
                                   .noCallback = true
                                  );
        }
    }
    
    return true;
}

stock bool:pp_GetMenuItem(Handle:pp, itemIndex, String:id[], idsize, &drawFlags=ITEMDRAW_DEFAULT, String:displayStr[]="", displaySize=sizeof(displayStr))
{
    new Handle:items = GetArrayCell(pp, _:pp_StructureElement_Items);
    
    if(itemIndex >= GetArraySize(items))
        return false;
    
    new item[pp_Items_StructureElements];
    GetArrayArray(items, itemIndex, item);
    
    strcopy(id, idsize, item[pp_Items_StructureElement_IdStr]);
    strcopy(displayStr, displaySize, item[pp_Items_StructureElement_Str]);
    drawFlags = item[pp_Items_StructureElement_DrawFlags];
    
    return true;
}

stock pp_RedrawItem(const String:text[])
{
    strcopy(g_sDrawItem, sizeof(g_sDrawItem), text);
}

stock pp_Page_GetLinkedLines(Handle:items, itemIndex, maxItems)
{
    new itemLines = 1;
    new currentItem = itemIndex;
    
    while(currentItem <= maxItems && (GetArrayCell(items, currentItem, _:pp_Items_StructureElement_DrawFlags) & ITEMDRAW_WITHNEXT != 0))
    {
        currentItem++;
        itemLines++;
    }
    return itemLines;
}

stock pp_page_WhatCanIDraw(Handle:items, &itemStartEnd)
{
    new remainingLines = PP_MAX_PANEL_LINES - 2; // Exit + Next button
    
    new startItem  = PP_UNPACK_START_ELEMENT(itemStartEnd);
    new endItem    = PP_UNPACK_END_ELEMENT(itemStartEnd);
    
    new currentItem = startItem;
    new validEndItem = startItem;
    
    new neededLines = 0;
    
    if(startItem != 0)
        remainingLines -= 1; // Back button
    else if(endItem+1 == remainingLines)
        remainingLines += 1; // No need of both back and next
        
    do{
        neededLines = pp_Page_GetLinkedLines(items, currentItem, endItem);
        currentItem += neededLines;
        remainingLines -= neededLines;
        if(remainingLines >= 0)
            validEndItem = currentItem-1;
        
    }
    while(currentItem <= endItem && remainingLines >= 0);
    
    itemStartEnd = PP_PACK_START_END_ELEMENT(startItem, validEndItem);
}

stock pp_page_ComputePagination(Handle:pp)
{
    new Handle:items = GetArrayCell(pp, _:pp_StructureElement_Items);
    new Handle:pages = GetArrayCell(pp, _:pp_StructureElement_Pages);
    
    ClearArray(pages);
    
    new endItem = GetArraySize(items)-1;
    new itemStartEnd = PP_PACK_START_END_ELEMENT(0, endItem);
   
    do{
        pp_page_WhatCanIDraw(items, itemStartEnd);
        PushArrayCell(pages, itemStartEnd);
        itemStartEnd = PP_PACK_START_END_ELEMENT(PP_UNPACK_END_ELEMENT(itemStartEnd) + 1, endItem);
    }
    while(PP_UNPACK_START_ELEMENT(itemStartEnd) <= endItem);
}

stock Handle:pp_Drawpage(Handle:pp, client, itemStartEnd, bool:hasBackButton, bool:hasNextButton)
{
    new Handle:items = GetArrayCell(pp, _:pp_StructureElement_Items);
    
    new Handle:hPanel = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
    new pageKeys = 0;
    
    decl String:text[PP_MAX_ENTRY_CHAR];
    
    new currentItem = PP_UNPACK_START_ELEMENT(itemStartEnd);
    new endItem = PP_UNPACK_END_ELEMENT(itemStartEnd);
    new usedLines = 0;
    new currentKey = 0;
    
    pp_GetTittle(pp, text);
    SetPanelTitle(hPanel, text);
    
    new MenuHandler:callback = g_hClientInfos[client][pp_Players_StructureElement_Callback];
    pp_CallClientCallback(pp, callback, client, MenuAction_Display, client, pp);
    
    new item[pp_Items_StructureElements];
    
    do{
        GetArrayArray(items, currentItem, item);
        
        strcopy(g_sDrawItem, sizeof(g_sDrawItem), item[pp_Items_StructureElement_Str]);
        pp_CallClientCallback(pp, callback, client, MenuAction_DisplayItem, client, currentItem);
        
        DrawPanelItem(hPanel, g_sDrawItem, item[pp_Items_StructureElement_DrawFlags] & ~ITEMDRAW_WITHNEXT);
        
        if(!(item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_DISABLED   ||
             item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_RAWLINE    ||
             item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_NOTEXT     ||
             item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_SPACER))
            pageKeys |= 1 << currentKey;
        
        if(!(item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_RAWLINE))
            currentKey++;
        
        if(!(item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_NOTEXT))
            usedLines++;
        
        currentItem++;
    }
    while(currentItem <= endItem);
    
    new FirstControlItem = PP_MAX_PANEL_LINES - 3;
    if(!hasBackButton)
    {
        FirstControlItem++;
        if(!hasNextButton)
            FirstControlItem++;
    }
    
    while(usedLines < FirstControlItem) // Back + Next + Exit
    {
        DrawPanelItem(hPanel, "", ITEMDRAW_SPACER);
        usedLines++;
        currentKey++;
    }
    
    while(currentKey < FirstControlItem) // Back + Next + Exit
    {
        DrawPanelItem(hPanel, "", ITEMDRAW_NOTEXT);
        currentKey++;
    }
    
    new String:constrolStr[50];
    if(hasBackButton)
    {
        Format(constrolStr, sizeof(constrolStr), "%T", PP_ITEM_BACK, client);
        DrawPanelItem(hPanel, constrolStr, ITEMDRAW_DEFAULT);
        pageKeys |= 1 << currentKey;
        currentKey++;
    }
    
    if(hasNextButton)
    {
        Format(constrolStr, sizeof(constrolStr), "%T", PP_ITEM_NEXT, client);
        DrawPanelItem(hPanel, constrolStr, ITEMDRAW_DEFAULT);
        pageKeys |= 1 << currentKey;
        currentKey++;
    }
    else if(hasBackButton)
    {
        DrawPanelItem(hPanel, "", ITEMDRAW_SPACER);
        currentKey++;
    }
    
    Format(constrolStr, sizeof(constrolStr), "%T", PP_ITEM_EXIT, client);
    DrawPanelItem(hPanel, constrolStr, ITEMDRAW_DEFAULT);
    pageKeys |= 1 << currentKey;
        
    SetPanelKeys(hPanel, pageKeys);
    
    return hPanel;
}

stock pp_Closepages(Handle:pp)
{    
    for(new index = 0; index < sizeof(g_hClientInfos); index++)
    {
        if(g_hClientInfos[index][pp_pages_StructureElements_pageHandle] == pp)
            g_hClientInfos[index][pp_pages_StructureElements_pageHandle] = INVALID_HANDLE;
    }
    
    ClearArray(pages);
}

stock pp_FindPageFromItem(Handle:pp, item, &itemStartEnd=0, &bool:hasBackButton=false, &bool:hasNextButton=false)
{
    new Handle:pages = GetArrayCell(pp, _:pp_StructureElement_Pages);
    new size = GetArraySize(pages);
    
    for(new index = 0; index < size; index++)
    {
        itemStartEnd = GetArrayCell(pages, index);
        
        if(
            PP_UNPACK_START_ELEMENT(itemStartEnd) <= item &&
            PP_UNPACK_END_ELEMENT(itemStartEnd) >= item
           )
        {
           hasBackButton = (index != 0);
           hasNextButton = (index != size - 1);
           return index;
        }
    }
    
    return -1;
}

stock bool:pp_GetPageStart(Handle:pp, page, &itemStart)
{
    new Handle:pages = GetArrayCell(pp, _:pp_StructureElement_Pages);
    new size = GetArraySize(pages);
    
    if(page >= size)
        return false;
    
    new itemStartEnd = GetArrayCell(pages, page);
    itemStart = PP_UNPACK_START_ELEMENT(itemStartEnd);
    return true;
}

stock bool:pp_GetPageInfo(Handle:pp, page, key, &itemStartEnd, &selectedElement)
{
    new Handle:items = GetArrayCell(pp, _:pp_StructureElement_Items);
    new Handle:pages = GetArrayCell(pp, _:pp_StructureElement_Pages);
    new size = GetArraySize(pages);
    
    if(page >= size)
        return false;
    
    itemStartEnd = GetArrayCell(pages, page);
    new firstItem = PP_UNPACK_START_ELEMENT(itemStartEnd);
    new item[pp_Items_StructureElements];
    new pageKeys = 0;
    selectedElement = -1;
    new currentKey = 0;
    
    for(new index = firstItem; index <= PP_UNPACK_END_ELEMENT(itemStartEnd); index++)
    {
        GetArrayArray(items, index, item);
        
        if(!(item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_DISABLED   ||
             item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_RAWLINE    ||
             item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_NOTEXT     ||
             item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_SPACER))
        {
            pageKeys |= 1 << currentKey;
            if(currentKey == key-1)
                selectedElement = index;
        }
        
        if(!(item[pp_Items_StructureElement_DrawFlags] & ITEMDRAW_RAWLINE))
            currentKey++;
    }
    
    if(page != 0)
        pageKeys |= 1 << (PP_ITEM_BACK_KEY - 1);
    if(page < size)
        pageKeys |= 1 << (PP_ITEM_NEXT_KEY - 1);
    
    pageKeys |= 1 << (PP_ITEM_EXIT_KEY - 1);
    
    return (1 <= key) &&  (key <= PP_ITEM_EXIT_KEY) && (((1 << (key-1)) & pageKeys) != 0);
}

stock any:pp_CallClientCallback(Handle:pp, MenuHandler:callback, client, MenuAction:action, any:param1, any:param2)
{
    new any:result;
    
    if(_:callback == 0)
        return -1;
    
    Call_StartFunction(INVALID_HANDLE, callback);
    Call_PushCell(pp);
    Call_PushCell(action);
    Call_PushCell(param1);
    Call_PushCell(param2);
    Call_Finish(result);
    
    return result;
}

stock bool:pp_DisplayToClient(Handle:pp, client, MenuHandler:Callback, Float:timeOut = Float:MENU_TIME_FOREVER, startItem=0, bool:noCallback = false)
{
    new itemStartEnd;
    new bool:hasBackButton;
    new bool:hasNextButton;
    
    pp_page_ComputePagination(pp);
    
    new page = pp_FindPageFromItem(pp, startItem, itemStartEnd, hasBackButton, hasNextButton);
    
    if(page == -1)
        return false;
    
    if(!noCallback && g_hClientInfos[client][pp_Players_StructureElement_Panel] != Handle:0)
    {
        new Handle:oldPp = g_hClientInfos[client][pp_Players_StructureElement_Panel];
        new MenuHandler:oldCallback = g_hClientInfos[client][pp_Players_StructureElement_Callback];
        pp_CallClientCallback(oldPp, oldCallback, client, MenuAction_Cancel, client, MenuCancel_Interrupted);
        pp_CallClientCallback(oldPp, oldCallback, client, MenuAction_End, MenuAction_Cancel, MenuCancel_Interrupted);
    }
    
    if(!noCallback)
        pp_CallClientCallback(pp, Callback, client, MenuAction_Start, 0, 0);
    
    g_hClientInfos[client][pp_Players_StructureElement_Panel] = pp;
    g_hClientInfos[client][pp_Players_StructureElement_Page] = page;
    g_hClientInfos[client][pp_Players_StructureElement_Callback] = Callback;
    g_hClientInfos[client][pp_Players_StructureElement_DisplayStartTime] = GetGameTime();
    g_hClientInfos[client][pp_Players_StructureElement_DisplayTimeOut] = timeOut;
    
    new Handle:hPannel = pp_Drawpage(pp, client, itemStartEnd, hasBackButton, hasNextButton);
    SendPanelToClient(hPannel, client, pp_MenuHandlerCallback, RoundToCeil(timeOut));
    CloseHandle(hPannel);
    
    return true;
}

// CallBack
public pp_MenuHandlerCallback(Handle:menu, MenuAction:action, param1, param2)
{
    if(action == MenuAction_Select)
    {
        if(g_hClientInfos[param1][pp_Players_StructureElement_Panel] == Handle:0)
            return;
        
        new itemStartEnd;
        new selectedElement;
        
        new Handle:oldPp = g_hClientInfos[param1][pp_Players_StructureElement_Panel];
        new MenuHandler:oldCallback = g_hClientInfos[param1][pp_Players_StructureElement_Callback];
        
        if(
            !pp_GetPageInfo(g_hClientInfos[param1][pp_Players_StructureElement_Panel], g_hClientInfos[param1][pp_Players_StructureElement_Page], param2, itemStartEnd, selectedElement)
          )
        {
            sounds_PlayToClient(param1, SOUNDS_MENU_EXIT);
            g_hClientInfos[param1][pp_Players_StructureElement_Panel] = Handle:0;
            pp_CallClientCallback(oldPp, oldCallback,  param1, MenuAction_Cancel, param1, MenuCancel_Exit);
            pp_CallClientCallback(oldPp, oldCallback, param1, MenuAction_End, MenuAction_Cancel, MenuCancel_Exit);
            return;
        }
        
        if(param2 == PP_ITEM_EXIT_KEY)
        {
            sounds_PlayToClient(param1, SOUNDS_MENU_EXIT);
            g_hClientInfos[param1][pp_Players_StructureElement_Panel] = Handle:0;
            pp_CallClientCallback(oldPp, oldCallback, param1, MenuAction_Cancel, param1, MenuCancel_Exit);
            pp_CallClientCallback(oldPp, oldCallback, param1, MenuAction_End, MenuAction_Cancel, MenuCancel_Exit);
            return;
        }
        
        if(param2 == PP_ITEM_BACK_KEY)
        {
            sounds_PlayToClient(param1, SOUNDS_MENU_SELECT);
            pp_DisplayToClient(
                                g_hClientInfos[param1][pp_Players_StructureElement_Panel],
                                param1,
                                g_hClientInfos[param1][pp_Players_StructureElement_Callback], 
                                g_hClientInfos[param1][pp_Players_StructureElement_DisplayTimeOut] != Float:MENU_TIME_FOREVER? g_hClientInfos[param1][pp_Players_StructureElement_DisplayTimeOut] - (GetGameTime() - g_hClientInfos[param1][pp_Players_StructureElement_DisplayStartTime]): Float:MENU_TIME_FOREVER,
                                PP_UNPACK_START_ELEMENT(itemStartEnd) - 1,
                                .noCallback = true
                              );
            return;
        }
        
        if(param2 == PP_ITEM_NEXT_KEY)
        {
            sounds_PlayToClient(param1, SOUNDS_MENU_SELECT);
            pp_DisplayToClient(
                                g_hClientInfos[param1][pp_Players_StructureElement_Panel],
                                param1,
                                g_hClientInfos[param1][pp_Players_StructureElement_Callback], 
                                g_hClientInfos[param1][pp_Players_StructureElement_DisplayTimeOut] != Float:MENU_TIME_FOREVER? g_hClientInfos[param1][pp_Players_StructureElement_DisplayTimeOut] - (GetGameTime() - g_hClientInfos[param1][pp_Players_StructureElement_DisplayStartTime]): Float:MENU_TIME_FOREVER,
                                PP_UNPACK_END_ELEMENT(itemStartEnd) + 1,
                                .noCallback = true
                              );
            return;
        }
        
        sounds_PlayToClient(param1, SOUNDS_MENU_SELECT);
        g_hClientInfos[param1][pp_Players_StructureElement_Panel] = Handle:0;
        pp_CallClientCallback(oldPp, oldCallback, param1, MenuAction_Select, param1, selectedElement);
        pp_CallClientCallback(oldPp, oldCallback, param1, MenuAction_End, MenuEnd_Selected, 0);
        
    }
    else if(action == MenuAction_End)
    {
        new Handle:oldPp = g_hClientInfos[param1][pp_Players_StructureElement_Panel];
        new MenuHandler:oldCallback = g_hClientInfos[param1][pp_Players_StructureElement_Callback];
        
        g_hClientInfos[param1][pp_Players_StructureElement_Panel] = Handle:0;
        pp_CallClientCallback(oldPp, oldCallback, param1, MenuAction_Cancel, param1, param2);
        pp_CallClientCallback(oldPp, oldCallback, param1, MenuAction_End, MenuAction_Cancel, param2);
    }
}

stock pp_OnClientDisconnect(client)
{
    if(g_hClientInfos[client][pp_Players_StructureElement_Panel] != Handle:0)
    {
        new Handle:oldPp = g_hClientInfos[client][pp_Players_StructureElement_Panel];
        new MenuHandler:oldCallback = g_hClientInfos[client][pp_Players_StructureElement_Callback];
        
        g_hClientInfos[client][pp_Players_StructureElement_Panel] = Handle:0;
        pp_CallClientCallback(oldPp, oldCallback, client, MenuAction_Cancel, client, MenuCancel_Disconnected);
        pp_CallClientCallback(oldPp, oldCallback, client, MenuAction_End, MenuAction_Cancel, MenuCancel_Disconnected);
    }
}
