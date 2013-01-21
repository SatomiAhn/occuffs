// removed remote stuff for the cuffs

//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//DEFAULT STATE

//on state entry, get db prefix from desc
//look for default settings notecard.  if there, start reading
//if not there, move straight to ready state
    
//on httpdb link message, stick command on queue

//READY STATE
//on state_entry, send new link message for each item on queue
//before sending HTTPDB_EMPTY on things, check default settings list.  send default if present

key wearer = NULL_KEY;

string parentmenu = "Help/Debug";
string syncfromdb = "Sync<-DB";
//string synctodb = "Sync<-DB"; //we still lack the subsystem for requesting settings from all scripts
string DUMPCACHE = "Dump Cache";
string onlinebutton; // will be initialized after

string onlineON = "(*)Online";
string onlineOFF = "( )Online";

// integer remoteon = FALSE;
float timeout = 30.0;
string queueurl = "http://collarcmds.appspot.com/";
key queueid;

list defaults;
list requestqueue;//requests are stuck here until we're done reading the notecard and web settings
string card = "defaultsettings";
integer line;
key dataid;


list dbcache;
list localcache;//stores settings that we dont' want to save to DB because they change so frequently
key allid;
string ALLTOKEN = "_all";

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb
integer HTTPDB_REQUEST_NOCACHE = 2005;

integer LOCALSETTING_SAVE = 2500;
integer LOCALSETTING_REQUEST = 2501;
integer LOCALSETTING_RESPONSE = 2502;
integer LOCALSETTING_DELETE = 2503;
integer LOCALSETTING_EMPTY = 2504;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;


//5000 block is reserved for IM slaves

//5000 block is reserved for IM slaves

string HTTPDB = "http://collardata.appspot.com/db/"; //db url
// key    reqid_load;                          // request id

//string dbprefix = "oc_";  //deprecated.  only appearance-related tokens should be prefixed now
//on a per-plugin basis

list tokenids;//strided list of token names and their corresponding request ids, so that token names can be returned in link messages

integer online=TRUE; //are we syncing with http or not?

integer remenu=FALSE; // should the menu appear after the link message is handled?

list g_lstKeep_on_Cleanup=["owner","secowners","openaccess","group","groupname","rlvon","locked","prefix"]; // values to be restored when a database cleanup is performed

integer g_nScriptCount; // number of script to resend if the coutn changes

debug (string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

Notify(key id, string msg, integer alsoNotifyWearer) {
    if (id == wearer) {
        llOwnerSay(msg);
    } else {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer) {
            llOwnerSay(msg);
        }
    }    
}

integer CacheValExists(list cache, string token)
{
    integer index = llListFindList(cache, [token]);
    if (index == -1)
    {
        return FALSE;
    }    
    else
    {
        return TRUE;
    }
}

list SetCacheVal(list cache, string token, string value)
{
    integer index = llListFindList(cache, [token]);
    if (index == -1)
    {
        cache += [token, value];
    }
    else
    {     
        cache = llListReplaceList(cache, [value], index + 1, index + 1);
    }  
    return cache;
}

string GetCacheVal(list cache, string token)
{
    integer index = llListFindList(cache, [token]);
    return llList2String(cache, index + 1);
}

list DelCacheVal(list cache, string token)
{
    integer index = llListFindList(cache, [token]);
    if (index != -1)
    {
        cache = llDeleteSubList(cache, index, index + 1);
    }    
    return cache;
}

// Save a value to httpdb with the specified name.
httpdb_save( string name, string value ) 
{
    llHTTPRequest( HTTPDB + name, [HTTP_METHOD, "PUT"], value );
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit
}

// Load named data from httpdb.
httpdb_load( string name ) 
{
    tokenids += [name, llHTTPRequest( HTTPDB + name, [HTTP_METHOD, "GET"], "" )];
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit    
}

httpdb_delete(string name) {
    //httpdb_request( HTTPDB_DELETE, "DELETE", name, "" );
    llHTTPRequest(HTTPDB + name, [HTTP_METHOD, "DELETE"], "");
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit        
}

CheckQueue()
{
    debug("querying queue");
    queueid = llHTTPRequest(queueurl, [HTTP_METHOD, "GET"], "");
}

DumpCache(string whichcache)
{
    list cache;
    string out;
    if (whichcache == "local")
    {
        cache=localcache;
        out = "Local Settings Cache:";
    }
    else
    {
        cache=dbcache;
        out = "DB Settings Cache:";
    }

       
    integer n;
    integer stop = llGetListLength(cache);

    for (n = 0; n < stop; n = n + 2)
    {
        //handle strlength > 1024
        string add = llList2String(cache, n) + "=" + llList2String(cache, n + 1) + "\n";
        if (llStringLength(out + add) > 1024)
        {
            //spew and clear
            llWhisper(0, "\n" + out);
            out = add;
        }
        else
        {
            //keep adding
            out += add;            
        }
    }
    llWhisper(0, "\n" + out);  
}


init()
{
    if (wearer == NULL_KEY)
    {//if we just started, save owner key
        wearer = llGetOwner();
    }
    else if (wearer != llGetOwner())
    {//we've changed hands.  reset script
        llResetScript();
    }

    if (!online) // don't lose settings in memory in offline mode
    {
        llOwnerSay("Running in offline mode. Using cached values only.");
        state ready;
        return;
    }
    defaults = [];//in case we just switched from the ready state, clean this now to avoid duplicates.    
    if (llGetInventoryType(card) == INVENTORY_NOTECARD)
    {
        line = 0;
        dataid = llGetNotecardLine(card, line);
    }
    else
    {
        //default settings card not found, prepare for 'ready' state
        if (online) allid = llHTTPRequest(HTTPDB + ALLTOKEN, [HTTP_METHOD, "GET"], "");
    }    
}

SendValues()
{
    //loop through all the settings and defaults we've got
    //settings first
    integer n;
    integer stop = llGetListLength(dbcache);
    for (n = 0; n < stop; n = n + 2)
    {
        string token = llList2String(dbcache, n);
        string value = llList2String(dbcache, n + 1);
        llMessageLinked(LINK_SET, HTTPDB_RESPONSE, token + "=" + value, NULL_KEY);
    }
    
    //now loop through defaults, sending only if there's not a corresponding token in dbcache
    stop = llGetListLength(defaults);
    for (n = 0; n < stop; n = n + 2)
    {
        string token = llList2String(defaults, n);
        string value = llList2String(defaults, n + 1);
        if (!CacheValExists(dbcache, token))
        {
            llMessageLinked(LINK_SET, HTTPDB_RESPONSE, token + "=" + value, NULL_KEY);
        }
    }
    
    //and now loop through localcache
    stop = llGetListLength(localcache);
    for (n = 0; n < stop; n = n + 2)
    {
        string token = llList2String(localcache, n);
        string value = llList2String(localcache, n + 1);
        llMessageLinked(LINK_SET, LOCALSETTING_RESPONSE, token + "=" + value, NULL_KEY);
        debug("sent local: " + token + "=" + value);
    }        
}    

default
{
    state_entry()
    {       
        init();
    }

    on_rez(integer param)
    {
        if (llGetOwner()!=wearer) llResetScript();
        init();
    }
    
    dataserver(key id, string data)
    {
        if (id == dataid)
        {
            if (data != EOF)
            {
                integer index = llSubStringIndex(data, "=");
                string token = llGetSubString(data, 0, index - 1);
                string value = llGetSubString(data, index + 1, -1);
                if (token=="online")
                {
                    online = (integer) value;
                }
                defaults += [token, value];
                line++;
                dataid = llGetNotecardLine(card, line);                
            }
            else
            {
                //done reading notecard, switch to ready state
                if (online) allid = llHTTPRequest(HTTPDB + ALLTOKEN, [HTTP_METHOD, "GET"], "");
                else
                {
                    llOwnerSay("Running in offline mode. Using defaults and dbcached values.");
                    state ready;
                }
            }
        }
    }
    
    http_response(key id, integer status, list meta, string body)
    {  
        if (id == allid)
        {
            if (status == 200)
            {
                //got all settings page, parse it
                dbcache = [];
                list lines = llParseString2List(body, ["\n"], []);
                integer stop = llGetListLength(lines);
                integer n;
                for (n = 0; n < stop; n++)
                {
                    list params = llParseString2List(llList2String(lines, n), ["="], []);
                    string token = llList2String(params, 0);
                    string value = llList2String(params, 1);
                    dbcache = SetCacheVal(dbcache, token, value);
                }
                if (llStringLength(body)>=2040)
                {
                    string prefix;
                    if (CacheValExists(dbcache, "prefix"))
                    {
                        prefix=GetCacheVal(dbcache, "prefix");
                    }
                    else
                    {
                        string s=llKey2Name(wearer);
                        integer i=llSubStringIndex(s," ")+1;
    
                        prefix=llToLower(llGetSubString(s,0,0)+llGetSubString(s,i,i));
                    }
                    llOwnerSay("ATTENTION: Settings loaded from web database, but the answer was so long that SL probably truncated it. This means, that your settings are probably not correctly saved anymore. This usually happens when you tested a lot of different collars. To fix this, you can type \""+prefix+"cleanup\" in open chat, this will clear ALL your saved values but the owners, lock and RLV. Sorry for inconvenience.");
                }
                else
                {
                    llOwnerSay("Settings loaded from web database.");
                }
             }
            else
            {
                llOwnerSay("Unable to contact web database.  Using defaults and dbcached values.");
            }
            state ready;
        }
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == HTTPDB_REQUEST || num == HTTPDB_SAVE || num == HTTPDB_DELETE)
        {
            //we don't want to process these yet so queue them til done reading the notecard
            requestqueue += [num, str, id];
        }
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }      
}

state ready
{
    state_entry()
    {       
        llSleep(1.0);
        
        // send the values stored in the cache
        SendValues();  
        
        // and store the number of scripts
        g_nScriptCount=llGetInventoryNumber(INVENTORY_SCRIPT);
        
        //tell the world about our menu button
        //        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + synctodb, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + syncfromdb, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + DUMPCACHE, NULL_KEY);
        if (online) onlinebutton=onlineON;
        else onlinebutton=onlineOFF;
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + onlinebutton, NULL_KEY);
//        CheckQueue();
//        llSetTimerEvent(timeout);   
        
        //resend any requests that came while we weren't looking
        integer n;
        integer stop = llGetListLength(requestqueue);
        for (n = 0; n < stop; n = n + 3)
        {
            llMessageLinked(LINK_THIS, (integer)llList2String(requestqueue, n), llList2String(requestqueue, n + 1), (key)llList2String(requestqueue, n + 2));
        }
        requestqueue = [];
        
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        //HandleRequest(num, str, id);
        //debug("Link Message: num=" + (string)num + ", str=" + str + ", id=" + (string)id);
        if (num == HTTPDB_SAVE)
        {
            //save the token, value  
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (online) httpdb_save(token, value);  
            dbcache = SetCacheVal(dbcache, token, value);
        }
        else if (num == HTTPDB_REQUEST)
        {
            //check the dbcache for the token
            if (CacheValExists(dbcache, str))
            {          
                llMessageLinked(LINK_SET, HTTPDB_RESPONSE, str + "=" + GetCacheVal(dbcache, str), NULL_KEY);            
            }
            else if (CacheValExists(defaults, str))
            {
                llMessageLinked(LINK_SET, HTTPDB_RESPONSE, str + "=" + GetCacheVal(defaults, str), NULL_KEY);               
            }
            else
            {
                llMessageLinked(LINK_SET, HTTPDB_EMPTY, str, NULL_KEY);            
            }
        }
        else if (num == HTTPDB_REQUEST_NOCACHE)
        {
            //request the token
            if (online) httpdb_load(str);        
        }
        else if (num == HTTPDB_DELETE)
        {
            dbcache = DelCacheVal(dbcache, str);       
            if (online) httpdb_delete(str);
        }    
//        else if (num == HTTPDB_RESPONSE && str == "remoteon=1")
//        {
//            remoteon = TRUE;
//            CheckQueue();
//            llSetTimerEvent(timeout);
//        }
//        else if (num == HTTPDB_RESPONSE && str == "remoteon=0")
//        {
//            remoteon = FALSE;
//            llSetTimerEvent(0.0);
//        }    
        else if (num == LOCALSETTING_SAVE)
        {// add/set a setting in the local cache
            debug("localsave: " + str);
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);            
            localcache = SetCacheVal(localcache, token, value);
        }
        else if (num == LOCALSETTING_REQUEST)
        {//return a setting from the local cache
            if (CacheValExists(localcache, str))
            {//return value
                llMessageLinked(LINK_SET, LOCALSETTING_RESPONSE, str + "=" + GetCacheVal(localcache, str), "");
            }
            else
            {//return empty
                llMessageLinked(LINK_SET, LOCALSETTING_EMPTY, str, "");
            }
        }
        else if (num == LOCALSETTING_DELETE)
        {//remove a setting from the local cache
            localcache = DelCacheVal(localcache, str);
        }
        else if (num == COMMAND_OWNER || num == COMMAND_WEARER || (num == COMMAND_SECOWNER && id == wearer))
        {
            if (str == "cachedump")
            {
                DumpCache("db");
                DumpCache("local");
            }
            else if (str == "reset" || str == "runaway")
            {
                dbcache = [];
                localcache = [];
                if (online)
                {
                    llHTTPRequest(HTTPDB + ALLTOKEN, [HTTP_METHOD, "DELETE"], "");
                    llSleep(2.0);
                    //save that we got a reset command:
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "lastReset=" + (string)llGetUnixTime(), "");
                }
                // moved to Auth to allow owner notification on runaway
                // llSleep(1.0);
                // llMessageLinked(LINK_THIS, COMMAND_OWNER, "resetscripts", id);
 //no more self resets
                //llResetScript();        
            }
//            else if (str == "remoteon")
//            {
//                if (online)
//                {
//                    remoteon = TRUE;
//                    //do http request for cmd list
//                    CheckQueue();
//                    //set timer to do same
//                    llSetTimerEvent(timeout);
//                    Notify(id, "Remote On.",TRUE);
//                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "remoteon=1", NULL_KEY);
//                }
//                else Notify(id, "Sorry, remote control only works in online mode.", FALSE);
//            }
//            else if (str == "remoteoff")
//            {
//                //wearer can't turn remote off
//                if (num != COMMAND_OWNER)
//                {
//                    Notify(id, "Sorry, only the primary owner can turn off the remote.",FALSE);
//                }
//                else
//                {
//                    remoteon = FALSE;
//                    llSetTimerEvent(0.0);
//                    Notify(id, "Remote Off.", TRUE);   
//                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "remoteon=0", NULL_KEY);                 
//                }                   
//            }
            else if (str == "online")
            {
                //wearer can't change online mode
                if (num != COMMAND_OWNER || id != wearer)
                {
                    Notify(id, "Sorry, only a self-owned wearer can enable online mode.", FALSE);
                }
                else
                {
                    online = TRUE;
                    llMessageLinked(LINK_THIS, MENUNAME_REMOVE, parentmenu + "|" + onlinebutton, NULL_KEY);
                    // sned online notification to other scripts using a variable "online"    
                    llMessageLinked(LINK_THIS, HTTPDB_RESPONSE,"online=1",NULL_KEY);
                    Notify(id, "Online mode enabled. Restoring settings from database.", TRUE);
                    state default;
                }
                if (remenu) {remenu=FALSE; llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);}
            }
            else if (str == "offline")
            {
                //wearer can't change online mode
                if (num != COMMAND_OWNER || id != wearer)
                {
                    Notify(id, "Sorry, only a self-owned wearer can enable offline mode.", FALSE);
                }
                else
                {
                    online = FALSE;
                    llMessageLinked(LINK_THIS, MENUNAME_REMOVE, parentmenu + "|" + onlinebutton, NULL_KEY);
                    onlinebutton = onlineOFF;
                    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + onlinebutton, NULL_KEY);
                    // sned online notification to other scripts using a variable "online"    
                    llMessageLinked(LINK_THIS, HTTPDB_RESPONSE,"online=0",NULL_KEY);
                    Notify(id, "Online mode disabled.", TRUE);
     
                }                   
                if (remenu) {remenu=FALSE; llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);}
            }
            else if (str == "cleanup")
                // delete vaues stored in the DB and restores thr most important setting
            {
                if (!online)
                // if we are ofline, we dont do anything
                {
                    llOwnerSay("Your collar is offline mode, so you cannot perform a cleanup of the HTTP database.");
                }
                else
                {
                    // we are online, so we inform the user
                    llOwnerSay("The settings from the database will now be deleted. After that the settings for the following values will restored, but you might need to restore settings for badword, colors, textures etc.: "+llList2CSV(g_lstKeep_on_Cleanup)+".\nThe cleanup may take about 1 minute.");
                    // delete the values fromt he db and take a nap
                    llHTTPRequest(HTTPDB + ALLTOKEN, [HTTP_METHOD, "DELETE"], "");
                    llSleep(3.0);
                    // before we dbcache the settings to be restored
                    integer m=llGetListLength(g_lstKeep_on_Cleanup);
                    integer i;
                    string t;
                    string v;
                    list tempdbcache;
                    for (i=0;i<m;i++)
                    {
                        t=llList2String(g_lstKeep_on_Cleanup,i);
                        if (CacheValExists(dbcache, t))
                        {
                            tempdbcache+=[t,GetCacheVal(dbcache, t)];
                        }
                    }
                    // now we can clean the dbcache
                    dbcache=[];
                    // and restore the values we 
                    m=llGetListLength(tempdbcache);
                    for (i=0;i<m;i=i+2)
                    {
                        t=llList2String(tempdbcache,i);
                        v=llList2String(tempdbcache,i+1);
                        httpdb_save(t, v);
                        dbcache = SetCacheVal(dbcache, t, v);
                    }
                    llOwnerSay("The cleanup has been performed. You can use the collar normaly again, but some of your previous settings may need to be redone. Resetting now.");
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "lastReset=" + (string)llGetUnixTime(), "");
                
                    llSleep(1.0);

                    llMessageLinked(LINK_THIS, COMMAND_OWNER, "resetscripts", id);
                }

            }            
        }
        else if (num == SUBMENU)
        {
            if (str == syncfromdb)
            {
                //notify that we're refreshing
                Notify(id, "Refreshing settings from web database.", TRUE);
                //return parent menu
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
                //refetch settings
                state default;            
            }
            else if (str == DUMPCACHE)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "cachedump", id);

                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else if (str == onlinebutton)
            {
                if (online) llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "offline", id);
                else llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "online", id);
                remenu = TRUE;
            }
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            //            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + synctodb, NULL_KEY);
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + syncfromdb, NULL_KEY);
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + DUMPCACHE, NULL_KEY);        
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + onlinebutton, NULL_KEY);
        }
    }
    
    http_response( key id, integer status, list meta, string body ) 
    {
        integer index = llListFindList(tokenids, [id]);
        if ( index != -1 ) 
        {
            string token = llList2String(tokenids, index - 1);            
            if (status == 200)
            {
                string out = token + "=" + body;
                llMessageLinked(LINK_SET, HTTPDB_RESPONSE, out, NULL_KEY); 
                dbcache = SetCacheVal(dbcache, token, body);                            
            }
            else if (status == 404)
            {
                //check defaults, send if present, else send HTTPDB_EMPTY                
                //integer index = llListFindList(defaults, [token]);
                index = llListFindList(defaults, [token]);
                if (index == -1)
                {
                    llMessageLinked(LINK_SET, HTTPDB_EMPTY, token, NULL_KEY); 
                }
                else
                {
                    llMessageLinked(LINK_SET, HTTPDB_RESPONSE, token + "=" + llList2String(defaults, index + 1), NULL_KEY);                     
                }             
            }
            //remove token, id from list
            tokenids = llDeleteSubList(tokenids, index - 1, index);
        }
        else if (id == queueid)//got a queued remote command
        {                             
            if (status == 200)
            {               
                //parse page, send cmds
                list lines = llParseString2List(body, ["\n"], []);
                integer n;
                integer stop = llGetListLength(lines);
                for (n = 0; n < stop; n++)
                {
                    //each line is pipe-delimited
                    list line = llParseString2List(llList2String(lines, n), ["|"], []);
                    string str = llList2String(line, 0);
                    key sender = (key)llList2String(line, 1);
                    debug("got queued cmd: " + str + " from " + (string)sender);
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, str, sender);
                }
            }
        }     
    }

    on_rez(integer param)
    {
        if (llGetOwner()!=wearer) llResetScript();
        state default;
    }
    
//    timer()
//    {
//        if (remoteon)
//        {
//            CheckQueue();
//        }
//        else
//        {
//            //technically we should never get here, but if we do we should shut down the timer.
//            llSetTimerEvent(0.0);
//        }
//    }
    
    changed(integer change)
    {
        if ((change==CHANGED_INVENTORY)&&(g_nScriptCount!=llGetInventoryNumber(INVENTORY_SCRIPT)))
        // number of scripts changed
        {
            // resend values and store new number
            SendValues();
            g_nScriptCount=llGetInventoryNumber(INVENTORY_SCRIPT);
        }
    }
}
