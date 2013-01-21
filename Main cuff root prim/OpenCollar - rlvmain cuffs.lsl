//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//new viewer checking method, as of 2.73
//on rez, restart script
//on script start, query db for rlvon setting
//on rlvon response, if rlvon=0 then just switch to checked state.  if rlvon=1 or rlvon=unset then open listener, do @version, start 30 second timer
//on listen, we got version, so stop timer, close listen, turn on rlv flag, and switch to checked state
//on timer, we haven't heard from viewer yet.  Either user is not running RLV, or else they're logging in and viewer could not respond yet when we asked.
//so do @version one more time, and wait another 30 seconds.
//on next timer, give up. User is not running RLV.  Stop timer, close listener, set rlv flag to FALSE, save to db, and switch to checked state.

integer rlvon = FALSE;//set to TRUE if DB says user has turned RLV features on
integer viewercheck = FALSE;//set to TRUE if viewer is has responded to @version message
integer rlvnotify = FALSE;//if TRUE, ownersay on each RLV restriction
integer listener;
float versiontimeout = 30.0;
integer versionchannel = 293847;
integer checkcount;//increment this each time we say @version.  check it each time timer goes off in default state. give up if it's >= 2
integer returnmenu;
string rlvString = "RestrainedLife viewer v1.20";

//"checked" state - HANDLING RLV SUBMENUS AND COMMANDS
//on start, request RLV submenus
//on rlv submenu response, add to list
//on main submenu "RLV", bring up this menu

string parentmenu = "Main";
string submenu = "RLV";
list menulist;
key menuid;
integer RELAY_CHANNEL = -1812221819;
integer verbose;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;
integer COMMAND_RELAY_SAFEWORD = 511;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLVR_CMD = 6010;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed

integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "^";
string TURNON = "*Turn On*";
string TURNOFF = "*Turn Off*";
string CLEAR = "*Clear All*";

key wearer;

integer lastdetach; //unix time of the last detach: used for checking if the detached time was small enough for not triggering the ping mechanism


debug(string str)
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

CheckVersion()
{
    //llOwnerSay("checking version");
    if (verbose)
    {
        Notify(wearer, "Attempting to enable Restrained Life Viewer functions.  " + rlvString+ " or higher is required for all features to work.", TRUE);
    }
    //open listener
    listener = llListen(versionchannel, "", wearer, "");
    //start timer
    llSetTimerEvent(versiontimeout);
    //do ownersay
    checkcount++;
    llOwnerSay("@version=" + (string)versionchannel);
}

DoMenu(key id)
{
    list buttons;
    if (rlvon)
    {
        buttons += [TURNOFF, CLEAR] + llListSort(menulist, 1, TRUE);
    }
    else
    {
        buttons += [TURNON];
    }

    string prompt = "Restrained Life Viewer Options";
    menuid = Dialog(id, prompt, buttons, [UPMENU], 0);
}

key ShortKey()
{//just pick 8 random hex digits and pad the rest with 0.  Good enough for dialog uniqueness.
    string chars = "0123456789abcdef";
    integer length = 16;
    string out;
    integer n;
    for (n = 0; n < 8; n++)
    {
        integer index = (integer)llFrand(16);//yes this is correct; an integer cast rounds towards 0.  See the llFrand wiki entry.
        out += llGetSubString(chars, index, index);
    }
     
    return (key)(out + "-0000-0000-0000-000000000000");
}

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key id = ShortKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
} 

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}


// Book keeping functions



integer SIT_CHANNEL;

list owners;

list sources=[];
list restrictions=[];
list old_restrictions;
list old_sources;

list baked=[];

integer sitlistener;
key sitter=NULL_KEY;
key sittarget=NULL_KEY;


//message map

integer CMD_ADDSRC = 11;
integer CMD_REMSRC = 12;

integer CMD_ML=31;


sendCommand(string cmd)
{
    if (cmd=="thirdview=n")
    {
        llMessageLinked(LINK_THIS,CMD_ML,"on",NULL_KEY);
    }
    else if (cmd=="thirdview=y")
    {
        llMessageLinked(LINK_THIS,CMD_ML,"off",NULL_KEY);
    }
    else llOwnerSay("@"+cmd);
    if (rlvnotify)
    {
        Notify(wearer, "Sent RLV Command: " + cmd, TRUE);
    }

}

handlecommand(key id, string command)
{
    string str=llToLower(command);
    list args = llParseString2List(str,["="],[]);
    string com = llList2String(args,0);
    if (llGetSubString(com,-1,-1)==":") com=llGetSubString(com,0,-2);
    string val = llList2String(args,1);
    if (val=="n"||val=="add") addrestriction(id,com);
    else if (val=="y"||val=="rem") remrestriction(id,com);
    else if (com=="clear") release(id,val);
    else
    {
        sendCommand(str);
        if (sitter==NULL_KEY&&llGetSubString(str,0,3)=="sit:")
        {
            sitter=id;
            //debug("Sitter:"+(string)(sitter));
            sittarget=(key)llGetSubString(str,4,-1);
            //debug("Sittarget:"+(string)(sittarget));
        }
    }
}

addrestriction(key id, string behav)
{
    integer source=llListFindList(sources,[id]);
    integer restr;
    // lock the collar for the first coming relay restriction  (change the test if we decide that collar restrictions should un/lock)
    if (id != NULL_KEY && (sources == [] || sources == [NULL_KEY])) applyadd("detach");
    if (source==-1)
    {
        sources+=[id];
        restrictions+=[behav];
        restr=-1;
        if (id!=NULL_KEY) llMessageLinked(LINK_THIS, CMD_ADDSRC,"",id);
    }
    else
    {
        list srcrestr = llParseString2List(llList2String(restrictions,source),["/"],[]);
        restr=llListFindList(srcrestr, [behav]);
        if (restr==-1)
        {
            restrictions=llListReplaceList(restrictions,[llDumpList2String(srcrestr+[behav],"/")],source, source);
        }
    }
    if (restr==-1)
    {
        applyadd(behav);
        if (behav=="unsit")
        {
            sitlistener=llListen(SIT_CHANNEL,"",wearer,"");
            sendCommand("getsitid="+(string)SIT_CHANNEL);
            sitter=id;
        }
    }
}

applyadd (string behav)
{
    integer restr=llListFindList(baked, [behav]);
    if (restr==-1)
    {
        //if (baked==[]) sendCommand("detach=n");  removed this as locking is owner privilege
        baked+=[behav];
        sendCommand(behav+"=n");
        //debug(behav);
    }
}

remrestriction(key id, string behav)
{
    integer source=llListFindList(sources,[id]);
    integer restr;
    if (source!=-1)
    {
        list srcrestr = llParseString2List(llList2String(restrictions,source),["/"],[]);
        restr=llListFindList(srcrestr,[behav]);
        if (restr!=-1)
        {
            if (llGetListLength(srcrestr)==1)
            {
                restrictions=llDeleteSubList(restrictions,source, source);
                sources=llDeleteSubList(sources,source, source);
                if (id!=NULL_KEY) llMessageLinked(LINK_THIS, CMD_REMSRC,"",id);
            }
            else
            {
                srcrestr=llDeleteSubList(srcrestr,restr,restr);
                restrictions=llListReplaceList(restrictions,[llDumpList2String(srcrestr,"/")] ,source,source);
            }
            if (behav=="unsit"&&sitter==id)
            {
                sitter=NULL_KEY;
                sittarget=NULL_KEY;
            }
            applyrem(behav);
        }
    }
    // unlock the collar for the last going relay restriction (change the test if we decide that collar restrictions should un/lock)
    if (id != NULL_KEY && (sources == [] || sources == [NULL_KEY])) applyrem("detach");
}

applyrem(string behav)
{
    integer restr=llListFindList(baked, [behav]);
    if (restr!=-1)
    {
        integer i;
        integer found=FALSE;
        for (i=0;i<=llGetListLength(restrictions);i++)
        {
            list srcrestr=llParseString2List(llList2String(restrictions,i),["/"],[]);
            if (llListFindList(srcrestr, [behav])!=-1) found=TRUE;
        }
        if (!found)
        {
            baked=llDeleteSubList(baked,restr,restr);
            if (behav!="no_hax") sendCommand(behav+"=y");
        }
    }
    //    if (baked==[]) sendCommand("detach=y");
}

release(key id, string pattern)
{
    integer source=llListFindList(sources,[id]);
    if (source!=-1)
    {
        list srcrestr=llParseString2List(llList2String(restrictions,source),["/"],[]);
        integer i;
        if (pattern!="")
        {
            for (i=0;i<=llGetListLength(srcrestr);i++)
            {
                string  behav=llList2String(srcrestr,i);
                if (llSubStringIndex(behav,pattern)!=-1) remrestriction(id,behav);
            }
        }
        else
        {
            restrictions=llDeleteSubList(restrictions,source, source);
            sources=llDeleteSubList(sources,source, source);
            llMessageLinked(LINK_THIS, CMD_REMSRC,"",id);
            for (i=0;i<=llGetListLength(srcrestr);i++)
            {
                string  behav=llList2String(srcrestr,i);
                applyrem(behav);
                if (behav=="unsit"&&sitter==id)
                {
                    sitter=NULL_KEY;
                    sittarget=NULL_KEY;
                }
            }
        }
    }
}


safeword (integer collartoo)
{
    //    integer index=llListFindList(sources,[NULL_KEY]);
    //    list collarrestr=llParseString2List(llList2String(restrictions,index),["/"],[]);
    sendCommand("clear");
    baked=[];
    sources=[];
    restrictions=[];
    sendCommand("no_hax=n");
//    integer i;
    if (!collartoo) llMessageLinked(LINK_THIS,RLV_REFRESH,"",NULL_KEY);
}


// End of book keeping functions

default
{    

        on_rez(integer start)
        {
            if (llGetOwner()!=wearer)
            {
                llResetScript();
            }
        }

        state_entry()
        {
            wearer = llGetOwner();
            //request setting from DB
            llSleep(1.0);
            llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "rlvon", NULL_KEY);
            SIT_CHANNEL=9999 + llFloor(llFrand(9999999.0));
        }

        link_message(integer sender, integer num, string str, key id)
        {
            
            if (num == HTTPDB_SAVE)
            {
                list params = llParseString2List(str, ["="], []);
                string token = llList2String(params, 0);
                string value = llList2String(params, 1);
                if(token == "owner" && llStringLength(value) > 0)
                {
                    owners = llParseString2List(value, [","], []);
                    debug("owners: " + value);
                }
            }
            else if (num == HTTPDB_RESPONSE)
            {
                list params = llParseString2List(str, ["="], []);
                string token = llList2String(params, 0);
                string value = llList2String(params, 1);
                if(token == "owner" && llStringLength(value) > 0)
                {
                    owners = llParseString2List(value, [","], []);
                    debug("owners: " + value);                
                }
                else if (str == "rlvon=0")
                {//RLV is turned off in DB.  just switch to checked state without checking viewer
                    //llOwnerSay("rlvdb false");
                    state checked;
                    llMessageLinked(LINK_THIS, RLV_OFF, "", NULL_KEY);

                }
                else if (str == "rlvon=1")
                {//DB says we were running RLV last time it looked.  do @version to check.
                    //llOwnerSay("rlvdb true");
                    rlvon = TRUE;
                    //check viewer version
                    CheckVersion();
                }
                else if (str == "rlvnotify=1")
                {
                    rlvnotify = TRUE;
                }
                else if (str == "rlvnotify=0")
                {
                    rlvnotify = FALSE;
                }
                else if (str == "rlvon=unset")
                {
                    CheckVersion();
                }
            }
            else if ((num == HTTPDB_EMPTY && str == "rlvon"))
            {
                CheckVersion();
            }
            else if (num == MENUNAME_REQUEST && str == parentmenu)
            {
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            }
            else if (num == SUBMENU && str == submenu)
            {
                if (num == SUBMENU)
                {   //someone clicked "RLV" on the main menu.  Tell them we're not ready yet.
                    Notify(id, "Still querying for viewer version.  Please try again in a minute.", FALSE);
                    llResetScript();//Nan: why do we reset here?!  
                }
                else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)//Nan: this code can't even execute! EVER!
                {//someone used "RLV" chat command.  Tell them we're not ready yet.
                    Notify(id, "Still querying for viewer version.  Please try again in a minute.", FALSE);
                    llResetScript();
                }
            }
        }

        listen(integer channel, string name, key id, string message)
        {
            if (channel == versionchannel)
            {
                //llOwnerSay("heard " + message);
                llListenRemove(listener);
                llSetTimerEvent(0.0);
                //get the version to send to rlv plugins
                string rlvVersion = llList2String(llParseString2List(message, [" "], []), 2);
                list temp = llParseString2List(rlvVersion, ["."], []);
                string majorV = llList2String(temp, 0);
                string minorV = llList2String(temp, 1);
                rlvVersion = llGetSubString(majorV, -1, -1) + llGetSubString(minorV, 0, 1);
                llMessageLinked(LINK_THIS, RLV_VERSION, rlvVersion, NULL_KEY);
                //this is already TRUE if rlvon=1 in the DB, but not if rlvon was unset.  set it to true here regardless, since we're setting rlvon=1 in the DB
                rlvon = TRUE;
                llMessageLinked(LINK_THIS, RLV_VERSION, rlvVersion, NULL_KEY);
                
                //someone thought it would be a good idea to use a whisper instead of a ownersay here
                //for both privacy and spamminess reasons, I've reverted back to an ownersay. --Nan
                llOwnerSay("Restrained Life functions enabled. " + message + " detected.");
                viewercheck = TRUE;

                llMessageLinked(LINK_THIS, RLV_ON, "", NULL_KEY);

                state checked;
            }
        }

        timer()
        {
            llListenRemove(listener);
            llSetTimerEvent(0.0);
            if (checkcount == 1)
            {   //the viewer hasn't responded after 30 seconds, but maybe it was still logging in when we did @version
                //give it one more chance
                CheckVersion();
            }
            else if (checkcount >= 2)
            {   //we've given the viewer a full 60 seconds
                viewercheck = FALSE;
                rlvon = FALSE;
                llMessageLinked(LINK_THIS, RLV_OFF, "", NULL_KEY);


                //            llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=0", NULL_KEY); <--- what was the point???
                //else the user normally logs in with RLv, but just not this time
                //in which case, leave it turned on in the database, until user manually changes it
                //i think this should always be said
                //            if (verbose)
                //            {
                Notify(wearer,"Could not detect Restrained Life Viewer.  Restrained Life functions disabled.",TRUE);
                //            }
                if (llGetListLength(restrictions) > 0 && llGetListLength(owners) > 0) {
                    string msg = llKey2Name(wearer)+" appears to have logged in without using the Restrained Life Viewer.  Their Restrained Life functions have been disabled.";
                    if (llGetListLength(owners) == 2) {
                        // only 1 owner
                        Notify(wearer,"Your owner has been notified.",FALSE);
                        Notify(llList2Key(owners,0), msg, FALSE);
                    } else {
                        Notify(wearer,"Your owners have been notified.",FALSE);
                        integer i;
                        for(i=0; i < llGetListLength(owners); i+=2) {
                            Notify(llList2Key(owners,i), msg, FALSE);
                        }
                    }
                }

                //DEBUG force rlvon and viewercheck for now, during development
                //viewercheck = TRUE;
                //rlvon = TRUE;
                //llOwnerSay("DEBUG: rlv on");

                state checked;
            }
        }
    }

state checked
{
    on_rez(integer param)
    {
        if (llGetOwner()!=wearer)
        {
            llResetScript();
        }

        if (llGetUnixTime()-lastdetach > 15) state default; //reset only if the detach delay was long enough (it could be an automatic reattach)
        else
        {
            integer i;
            for (i = 0; i < llGetListLength(baked); i++)
            {
                sendCommand(llList2String(baked,i)+"=n");
            }
            llMessageLinked(LINK_THIS, RLV_REFRESH, "", NULL_KEY); // wake up other plugins anyway (tell them that RLV is still active, as it is likely they did reset themselves
        }
    }
    
    
/* Bad!  (would prevent reattach on detach)    
//Nan: please use regular double slashes to comment things out.  That's the only way your comment will turn orange, which i think is an important visual cue for other people who have to read your script.
//    attach(key id)
//    {
//        if (id == NULL_KEY && rlvon && viewercheck)
//        {
//            llOwnerSay("@clear");
//        }
//    }
*/

    attach(key id)
    {
        if (id == NULL_KEY) lastdetach = llGetUnixTime(); //remember when the collar was detached last
    }
    
    state_entry()
    {
        menulist = [];//clear this list now in case there are old entries in it
        //we only need to request submenus if rlv is turned on and running
        if (rlvon && viewercheck)
        {   //ask RLV plugins to tell us about their rlv submenus
            llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
            //initialize restrictions and protect against the "arbitrary string on arbitrary channel" exploit
            sendCommand("clear");
            sendCommand("no_hax=n");
            //ping inworld object so that they reinstate their restrictions
            integer i;
            for (i=0;i<llGetListLength(sources);i++)
            {
                if ((key)llList2String(sources,i)) llShout(RELAY_CHANNEL,"ping,"+llList2String(sources,i)+",ping,ping");
                //debug("ping,"+llList2String(sources,i)+",ping,ping");
            }
            old_restrictions=restrictions;
            old_sources=sources;
            restrictions=[];
            sources=[];
            baked=[];
            llSetTimerEvent(2);
            //tell rlv plugins to reinstate restrictions
            llMessageLinked(LINK_THIS, RLV_REFRESH, "", NULL_KEY);
        }
        //llOwnerSay("entered checked state.  rlvon=" + (string)rlvon + ", viewercheck=" + (string)viewercheck);
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        // added chat command for menu:
        else if (llToUpper(str) == submenu)
        {
            if (num == SUBMENU)
            {   //someone clicked "RLV" on the main menu.  Give them our menu now
                DoMenu(id);
            }
            else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            { //someone used the chat command
                DoMenu(id);
            }
        }
        else if (str == "rlvon")
        {
            if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            {
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=1", NULL_KEY);
                rlvon = TRUE;
                verbose = TRUE;
                state default;
            }
        }
        else if (startswith(str, "rlvnotify") && num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            string onoff = llList2String(llParseString2List(str, [" "], []), 1);
            if (onoff == "on")
            {
                rlvnotify = TRUE;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvnotify=1", NULL_KEY);
            }
            else if (onoff == "off")
            {
                rlvnotify = FALSE;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvnotify=0", NULL_KEY);
            }
        }
        else if (num == DIALOG_RESPONSE)
        {
            debug(str);                    
            if (id == menuid)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(menuparams, 0);          
                string message = llList2String(menuparams, 1);                                         
                integer page = (integer)llList2String(menuparams, 2); 
                debug(message);
                if (message == TURNON)
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvon", av);
                }
                else if (message == TURNOFF)
                {
                    returnmenu = TRUE;
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvoff", av);
                }
                else if (message == CLEAR)
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "clear", av);
                    DoMenu(av);
                }
                else if (message == UPMENU)
                {
                    llMessageLinked(LINK_THIS, SUBMENU, parentmenu, av);
                }
                else if (llListFindList(menulist, [message]) != -1 && rlvon)
                {
                    llMessageLinked(LINK_SET, SUBMENU, message, av);
                }                                       
            }
        }
        else if (num == DIALOG_TIMEOUT)
        {
            if (id == menuid)
            {
                returnmenu = FALSE;
            }
        }             

        //these are things we only do if RLV is ready to go
        if (rlvon && viewercheck)
        {   //if RLV is off, don't even respond to RLV submenu events
            if (num == MENUNAME_RESPONSE)
            {    //str will be in form of "parentmenu|menuname"
                list params = llParseString2List(str, ["|"], []);
                string thisparent = llList2String(params, 0);
                string child = llList2String(params, 1);
                if (thisparent == submenu)
                {     //add this str to our menu buttons
                    if (llListFindList(menulist, [child]) == -1)
                    {
                        menulist += [child];
                    }
                }
            }
            else if (num == MENUNAME_REMOVE)
            {    //str will be in form of "parentmenu|menuname"
                list params = llParseString2List(str, ["|"], []);
                string thisparent = llList2String(params, 0);
                string child = llList2String(params, 1);
                if (thisparent == submenu)
                {
                    integer index = llListFindList(menulist, [child]);
                    if (index != -1)
                    {
                        menulist = llDeleteSubList(menulist, index, index);
                    }
                }
            }
            else if (num == RLV_CMD)
            {
                list commands=llParseString2List(str,[","],[]);
                integer i;
                for (i=0;i<llGetListLength(commands);i++) handlecommand(NULL_KEY,llList2String(commands,i));
            }
            else if (num == RLV_CMD||num == RLVR_CMD)
            {
                handlecommand(id,str);
            }
            else if (num == COMMAND_RLV_RELAY && llGetSubString(str,-43,-1)==","+(string)wearer+",!pong")
            {
                if (id==sitter) sendCommand("sit:"+(string)sittarget+"=force");
                integer sourcenum=llListFindList(old_sources, [id]);
                integer j;
                list restr=llParseString2List(llList2String(old_restrictions,sourcenum),["/"],[]);
                for (j=0;j<llGetListLength(restr);j++) addrestriction(id,llList2String(restr,j));
            }
            else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            {
                debug("cmd: " + str);
                if (str == "clear")
                {
                    if (num == COMMAND_WEARER)
                    {
                        Notify(wearer,"Sorry, but the sub cannot clear RLV settings.",TRUE);
                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, RLV_CLEAR, "", NULL_KEY);
                        safeword(TRUE);
                    }
                }
                else if (str == "rlvon")
                {
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=1", NULL_KEY);
                    rlvon = TRUE;
                    verbose = TRUE;
                    state default;
                }
                else if (str == "rlvoff")
                {
                    if (num == COMMAND_OWNER)
                    {
                        rlvon = FALSE;
                        llMessageLinked(LINK_THIS, HTTPDB_SAVE, "rlvon=0", NULL_KEY);
                        safeword(TRUE);
                        llMessageLinked(LINK_THIS, RLV_OFF, "", NULL_KEY);


                    }
                    else
                    {
                        Notify(id, "Sorry, only owner may disable Restrained Life functions", FALSE);
                    }

                    if (returnmenu)
                    {
                        returnmenu = FALSE;
                        DoMenu(id);
                    }
                }
                else if (str=="showrestrictions")
                {
                    string out="You are being restricted by the following object";
                    if (llGetListLength(sources)==2) out+=":";
                    else out+="s:";
                    integer i;
                    for (i=0;i<llGetListLength(sources);i++)
                        if (llList2String(sources,i)!=NULL_KEY) out+="\n"+llKey2Name((key)llList2String(sources,i))+" ("+llList2String(sources,i)+"): "+llList2String(restrictions,i);
                    else out+="\nThis collar: "+llList2String(restrictions,i);
                    Notify(id,out,FALSE);
                }
            }
            else if (num == COMMAND_SAFEWORD)
            {// safeword used, clear rlv settings
                llMessageLinked(LINK_THIS, RLV_CLEAR, "", NULL_KEY);
                safeword(TRUE);
            }
            else if (num == HTTPDB_SAVE) {
                list params = llParseString2List(str, ["="], []);
                string token = llList2String(params, 0);
                string value = llList2String(params, 1);
                if(token == "owner" && llStringLength(value) > 0)
                {
                    owners = llParseString2List(value, [","], []);
                    debug("owners: " + value);
                }
            }
            else if (num == HTTPDB_RESPONSE)
            {
                list params = llParseString2List(str, ["="], []);
                string token = llList2String(params, 0);
                string value = llList2String(params, 1);
                if(token == "owner" && llStringLength(value) > 0)
                {
                    owners = llParseString2List(value, [","], []);
                    debug("owners: " + value);                
                }
                else if (str == "rlvnotify=1")
                {
                    rlvnotify = TRUE;
                }
                else if (str == "rlvnotify=0")
                {
                    rlvnotify = FALSE;
                }
            }
            else if (num==COMMAND_RELAY_SAFEWORD)
            {
                safeword(FALSE);
            }       
        }        
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel==SIT_CHANNEL)
        {
            sittarget=message;
            llListenRemove(sitlistener);
        }

    }

    timer()
    {
        llSetTimerEvent(0.0);
            old_sources=[];
            old_restrictions=[];
    }
}