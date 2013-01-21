// Open collar time script tweaked for use in Open collar Cuffs.
// Put it in the main cuff (right forearm)
// Changes to the original timer Plugin are marked in the code.
// - Removed RLV button
// - Unleash is now used for unchain (releasing the sub from Cuff pose and removing the chains.)
// added prefixes to the HTTP tokes for locking

list times;
integer timeslength;
integer currenttime;
integer ontime;
integer lasttime;
integer firstontime;
integer firstrealtime;
integer lastrez;
integer n;//for loops
string message;
integer MAX_TIME=0x7FFFFFFF;

integer ATTACHMENT_COMMAND = 602;
integer ATTACHMENT_FORWARD = 610;
//these can change
integer TIMER_TOMESSAGE=609;
integer TIMER_FROMMESSAGE=610;
integer REAL_TIME=1;
integer REAL_TIME_EXACT=5;
integer ON_TIME=3;
integer ON_TIME_EXACT=7;

key wearer;
integer interfaceChannel;
// end time keeper

// Template for creating a OpenCOllar Plugin - OpenCollar Version 3.0xx

//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//Collar Cuff Menu

string submenu = "Timer"; // Name of the submenu
// changed for cuffs
string parentmenu = "Main"; // name of the menu, where the menu plugs in

// added for cuffs
string g_szPrefix; // prefix for storing to the DB

key menuid;
key onmenuid;
key realmenuid;

//key g_keyWearer; // key of the current wearer to reset only on owner changes

list localbuttons = ["realtime","online"]; // any local, not changing buttons which will be used in this plugin, leave emty or add buttons as you like
list timebuttons = ["clear","+00:01","+00:05","+00:30","+03:00","+24:00","-00:01","-00:05","-00:30","-03:00","-24:00"];

integer onrunning;
integer onsettime;
integer ontimeupat;
//integer lastontime;
//integer clocktimeatlastontime;
integer realrunning;
integer realsettime;
integer realtimeupat;
//integer lastrealtime;
//integer clocktimeatlastrealtime;

integer unlockcollar;
integer collarlocked;
integer clearRLVrestions;
integer unleash;
integer both;
integer whocanchangetime;
integer whocanchangeleash;
integer whocanchangeothersettings;


//integer clocktime;
integer timechange;
//integer onupdated;
//integer realupdated;

//integer whichmenu;
//key menuwho;

list buttons;

//OpenCollae MESSAGE MAP
// messages for authenticating users
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
// added so when the sub is locked out they can use postions
integer COMMAND_WEARERLOCKEDOUT = 521;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

// messages for storing and retrieving values from http db
integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer LOCALSETTING_SAVE = 2500;
integer LOCALSETTING_REQUEST = 2501;
integer LOCALSETTING_RESPONSE = 2502;
integer LOCALSETTING_DELETE = 2503;
integer LOCALSETTING_EMPTY = 2504;

// messages for creating OC menu structure
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

// messages for RLV commands
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..

// messages for poses and couple anims
integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST = 7002;//id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE = 7003;//str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START = 7004;//str should be valid anim name.  id should be av
integer CPLANIM_STOP = 7005;//str should be valid anim name.  id should be av

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

integer WEARERLOCKOUT=620;


// menu option to go one step back in menustructure
string UPMENU = "^";
string MORE = ">";

Notify(key id, string msg, integer alsoNotifyWearer)
{
    if (id == wearer)
    {
        llOwnerSay(msg);
    }
    else
    {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer)
        {
            llOwnerSay(msg);
        }
    }
}


//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    output debug messages
//=
//===============================================================================


debug(string szMsg)
{
    //llOwnerSay(llGetScriptName() + ": " + szMsg);
}

//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    integer TRUE/FALSE
//=
//= description  :    checks if a string begin with another string
//=
//===============================================================================

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
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

//===============================================================================
//= parameters   :    string    keyID   key of person requesting the menu
//=
//= return        :    none
//=
//= description  :    build menu and display to user
//=
//===============================================================================

DoMenu(key keyID)
{
    debug("timeremaning:"+(string)(ontimeupat-ontime));
    string prompt = "Pick an option.";
    list mybuttons = localbuttons + buttons;

    //fill in your button list and additional prompt here
    prompt += "\n Online timer - "+int2time(onsettime);
    if (onrunning==1)
    {
        prompt += "\n Online timer - "+int2time(ontimeupat-ontime)+" left";
        //mybuttons += ["stop online"];
    }
    else
    {
        prompt += "\n Online timer - not running";
        //mybuttons += ["start online"];
    }
    prompt += "\n Realtime timer - "+int2time(realsettime);
    if (realrunning==1)
    {
        prompt += "\n Realtime timer - "+int2time(realtimeupat-currenttime)+" left";
        //mybuttons += ["stop realtime"];
    }
    else
    {
        prompt += "\n Realtime timer - not running";
        //mybuttons += ["start realtime"];
    }
    if (realrunning || onrunning)
    {
        mybuttons += ["stop"];
    }
    else if (realsettime || onsettime)
    {
        mybuttons += ["start"];
    }
    if (unlockcollar)
    {
        prompt += "\n the cuffs will be unlocked when the timer goes off";
        mybuttons += ["(*)unlock"];
    }
    else
    {
        prompt += "\n the cuffs will not be unlocked when the timer goes off";
        mybuttons += ["()unlock"];
    }
    if (unleash)
    {
        prompt += "\n the cuffs will be unchained when the timer goes off";
        mybuttons += ["(*)unchain"]; //changed Button from unleash to unchain for use in cuffs
    }
    else
    {
        prompt += "\n the cuffs will not be unchained when the timer goes off";
        mybuttons += ["()unchain"]; //changed Button from unleash to unchain for use in cuffs
    }
    //if (clearRLVrestions) //comented out for use in cuffs RLV restrictions does not make sense there.
    //{
    //comented out for use in cuffs RLV restrictions does not make sense there.
    //prompt += "\n the RLV restions will be cleared when the timer goes off";
    //mybuttons += ["(*)clearRLV"];
    //}
    //else
    //{
    //comented out for use in cuffs RLV restrictions does not make sense there.
    //prompt += "\n the RLV restions will not be cleared when the timer goes off";
    //mybuttons += ["()clearRLV"];
    //}

    llListSort(localbuttons, 1, TRUE); // resort menu buttons alphabetical

    menuid = Dialog(keyID, prompt, mybuttons, [UPMENU], 0);
}
DoOnMenu(key keyID)
{
    string prompt = "Pick an option.";
    prompt += "\n Online timer - "+int2time(onsettime);
    if (onrunning)
    {
        prompt += "\n Online timer - "+int2time(ontimeupat-ontime)+" left";
    }
    else
    {
        prompt += "\n Online timer - not running";
    }
    onmenuid = Dialog(keyID, prompt, timebuttons, [UPMENU], 0);
}
DoRealMenu(key keyID)
{
    string prompt = "Pick an option.";
    //fill in your button list and additional prompt here
    prompt += "\n Realtime timer - " + int2time(realsettime);
    if (realrunning)
    {
        prompt += "\n Realtime timer - "+int2time(realtimeupat-currenttime)+" left";
    }
    else
    {
        prompt += "\n Realtime timer - not running";
    }
    realmenuid = Dialog(keyID, prompt, timebuttons, [UPMENU], 0);
}


//===============================================================================
//= parameters   :    none
//=
//= return        :   string     DB prefix from the description of the collar
//=
//= description  :    prefix from the description of the collar
//=
//===============================================================================

string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

string int2time(integer time)
{
    if (time<0) time=0;
    integer secs=time%60;
    time = (time-secs)/60;
    integer mins=time%60;
    time = (time-mins)/60;
    integer hours=time%24;
    integer days = (time-hours)/24;

    //this is the onley line that needs changing...
    return ( (string)days+" days "+
        llGetSubString("0"+(string)hours,-2,-1) + ":"+
        llGetSubString("0"+(string)mins,-2,-1) + ":"+
        llGetSubString("0"+(string)secs,-2,-1) );
    //return (string)days+":"+(string)hours+":"+(string)mins+":"+(string)secs;
}

TimerWhentOff()
{
    if(both && (onrunning || realrunning))
    {
        return;
    }
    llMessageLinked(LINK_THIS, WEARERLOCKOUT, "off", "");
    onsettime=realsettime=0;
    onrunning=realrunning=0;
    ontimeupat=realtimeupat=0;
    whocanchangetime=504;
    if(unlockcollar)
    {
        llMessageLinked(LINK_THIS, COMMAND_OWNER, "unlock", wearer);
    }
    if(clearRLVrestions)
    {
        llMessageLinked(LINK_THIS, COMMAND_OWNER, "clear", wearer);
        if(!unlockcollar && collarlocked)
        {
            llSleep(2);
            llMessageLinked(LINK_THIS, COMMAND_OWNER, "lock", wearer);
        }
    }
    if(unleash)
    {
        //changed to Stop to release from animation in cuffs
        llMessageLinked(LINK_THIS, COMMAND_OWNER, "*:Stop", "");
        //llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "*:Stop", "5f616b34-b5be-4bc1-a28f-b73b11b7271d");
    }
    unlockcollar=clearRLVrestions=unleash=0;
    Notify(wearer, "The timer has expired", TRUE);
}

default
{
    state_entry()
    {
        lasttime=llGetUnixTime();
        llSetTimerEvent(1);
        wearer = llGetOwner();
        interfaceChannel = (integer)("0x" + llGetSubString(wearer,30,-1));
        if (interfaceChannel > 0)
        {
            interfaceChannel = -interfaceChannel;
        }
        firstontime=MAX_TIME;
        firstrealtime=MAX_TIME;
        llMessageLinked(LINK_THIS, TIMER_FROMMESSAGE, "timer|sendtimers", "");
        llWhisper(interfaceChannel, "timer|sendtimers");

        //end of timekeeper
        //wearer=llGetOwner();

        // sleep a sceond to allow all scripts to be initialized
        llSleep(1.0);
        // send reequest to main menu and ask other menus if the wnt to register with us
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);

        //set settings
        unlockcollar=0;
        clearRLVrestions=0;
        unleash=0;
        both=0;
        whocanchangetime=504;
        whocanchangeleash=504;
        whocanchangeothersettings=504;

        // added for cuffs, we read the prefix from the dexcription, too lock the cuffs
        g_szPrefix = GetDBPrefix();


    }
    on_rez(integer start_param)
    {
        lasttime=lastrez=llGetUnixTime();
        llMessageLinked(LINK_THIS, TIMER_FROMMESSAGE, "timer|sendtimers", "");
        llWhisper(interfaceChannel, "timer|sendtimers");
        if (realrunning == 1 || onrunning == 1)
        {
            llMessageLinked(LINK_THIS, WEARERLOCKOUT, "on", "");
            debug("timer is running real:"+(string)realrunning+" on:"+(string)onrunning);
        }
    }

    // listen for likend messages fromOC scripts
    link_message(integer sender, integer num, string str, key id)
    {
        list info  = llParseString2List (str, ["|"], []);
        if((num==TIMER_TOMESSAGE || num==ATTACHMENT_FORWARD)&&llList2String(info, 0)=="timer")//request for us
        {
            debug(str);
            string command = llList2String(info, 1);
            integer type = llList2Integer(info, 2);
            if(command=="settimer")
            {
                //should check values but I am not yet.
                if(type==REAL_TIME)
                {
                    integer newtime = llList2Integer(info, 3) +currenttime;
                    times=times+[REAL_TIME,newtime];
                    if(firstrealtime>newtime)
                    {
                        firstrealtime=newtime;
                    }
                    message="timer|timeis|"+(string)REAL_TIME+"|"+(string)currenttime;
                }
                else if(type==REAL_TIME_EXACT)
                {
                    integer newtime = llList2Integer(info, 3);
                    times=times+[REAL_TIME,newtime];
                    if(firstrealtime>newtime)
                    {
                        firstrealtime=newtime;
                    }
                }
                else if(type==ON_TIME)
                {
                    integer newtime = llList2Integer(info, 3) +ontime;
                    times=times+[ON_TIME,newtime];
                    if(firstontime>newtime)
                    {
                        firstontime=newtime;
                    }
                    message="timer|timeis|"+(string)ON_TIME+"|"+(string)ontime;
                }
                else if(type==ON_TIME_EXACT)
                {
                    integer newtime = llList2Integer(info, 3) +ontime;
                    times=times+[ON_TIME,newtime];
                    if(firstontime>newtime)
                    {
                        firstontime=newtime;
                    }
                }
            }
            else if(command=="gettime")
            {
                if(type==REAL_TIME)
                {
                    message="timer|timeis|"+(string)REAL_TIME+"|"+(string)currenttime;
                }
                else if(type==ON_TIME)
                {
                    message="timer|timeis|"+(string)ON_TIME+"|"+(string)ontime;
                }
            }
            else
            {
                return;
                //message got sent to us or something went wrong
            }
            if(num==ATTACHMENT_FORWARD)
            {
                llWhisper(interfaceChannel, message);//need to wispear
            }
            else if(num==TIMER_TOMESSAGE)
            {
                llMessageLinked(LINK_THIS, TIMER_FROMMESSAGE, message, "");//inside script
            }
        }
        else if(num == COMMAND_WEARERLOCKEDOUT && str == "menu")
        {
            Notify(id , "You are locked out of the cuffs until the timer expires", FALSE);
        }
        else if (num == LOCALSETTING_DELETE )
        {
            if (str == "leashedto")
            {
                whocanchangeleash=504;
            }
        }
        else if (num == HTTPDB_DELETE)
        {
            // added prefix for cuffs
            if (str == g_szPrefix + "locked")
            {
                collarlocked=0;
            }
        }
        else if (num == LOCALSETTING_SAVE)
        {
            if (llGetSubString(str, 0, 8) == "leashedto")
            {
                integer temp = llList2Integer( llParseString2List( str , [","] , [] ) , -1 );
                if (temp < whocanchangeleash)
                {
                    whocanchangeleash=temp;
                    unleash=0;
                }
            }
        }
        else if (num == HTTPDB_SAVE)
        {
            // added prefix for cuffs
            if (str == g_szPrefix + "locked=1")
            {
                collarlocked=1;
            }
        }
        else if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            // added prefix for cuffs
            if (token == g_szPrefix + "locked")
            {
                collarlocked=(integer)value;
            }
        }
        else if (num == SUBMENU && str == submenu)
        {
            //someone asked for our menu
            //give this plugin's menu to id
            DoMenu(id);
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
            // our parent menu requested to receive buttons, so send ours
        {

            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == MENUNAME_RESPONSE)
            // a button is sned ot be added to a plugin
        {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == submenu)
            {//someone wants to stick something in our menu
                string button = llList2String(parts, 1);
                if (llListFindList(buttons, [button]) == -1)
                    // if the button isnt in our benu yet, than we add it
                {
                    buttons = llListSort(buttons + [button], 1, TRUE);
                }
            }
        }
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            // a validated command from a owner, secowner, groupmember or the wear has been received
            // can also be used to listen to chat commands
        {
            if (llToLower(str) == "timer")
            {
                DoMenu(id);
            }
            else if(llGetSubString(str, 0, 5) == "timer ")
            {
                string message=llGetSubString(str, 6, -1);
                //we got a response for something we handle locally
                if (message == "realtime")
                {
                    // do What has to be Done
                    debug("realtime");
                    // and restart the menu if wantend/needed
                    DoRealMenu(id);
                }
                else if (message == "online")
                {
                    // do What has to be Done
                    debug("online");
                    // and restart the meuu if wantend/needed
                    DoOnMenu(id);
                }
                else if (message == "start")
                {
                    // do What has to be Done
                    whocanchangetime = num;
                    if(realsettime)
                    {
                        //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realsettime), "");
                        realtimeupat=currenttime+realsettime;
                        llMessageLinked(LINK_THIS, WEARERLOCKOUT, "on", "");

                        realrunning=1;
                    }
                    else
                    {
                        realrunning=3;
                    }
                    if(onsettime)
                    {
                        //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(onsettime), "");
                        ontimeupat=ontime+onsettime;
                        llMessageLinked(LINK_THIS, WEARERLOCKOUT, "on", "");

                        onrunning=1;
                    }
                    else
                    {
                        onrunning=3;
                    }
                    // and restart the meuu if wantend/needed
                    DoMenu(id);
                }
                else if (message == "stop")
                {
                    // do What has to be Done
                    TimerWhentOff();
                    // and restart the meuu if wantend/needed
                    DoMenu(id);
                }
                else if(message=="(*)unlock")
                {
                    if(num == COMMAND_OWNER)
                    {
                        unlockcollar=0;
                        DoMenu(id);
                    }
                    else
                    {
                        Notify(id,"Only the owner can change if the cuffs unlock when the timer runs out.",FALSE);
                    }
                }
                else if(message=="()unlock")
                {
                    if(num == COMMAND_OWNER)
                    {
                        unlockcollar=1;
                        DoMenu(id);
                    }
                    else
                    {
                        Notify(id,"Only the owner can change if the cuffs unlock when the timer runs out.",FALSE);
                    }
                }
                else if(message=="(*)clearRLV")
                {
                    if(num == COMMAND_WEARER)
                    {
                        Notify(id,"You canot change if the RLV settings are cleared",FALSE);
                    }
                    else
                    {
                        clearRLVrestions=0;
                        DoMenu(id);
                    }
                }
                else if(message=="()clearRLV")
                {
                    if(num == COMMAND_WEARER)
                    {
                        Notify(id,"You canot change if the RLV settings are cleared",FALSE);
                    }
                    else
                    {
                        clearRLVrestions=1;
                        DoMenu(id);
                    }
                }
                else if(message=="(*)unchain")
                {
                    if(num <= whocanchangeleash)
                    {
                        unleash=0;
                        DoMenu(id);
                    }
                    else
                    {
                        Notify(id,"Only the someone who can leash the sub can change if the cuffs unleash when the timer runs out.",FALSE);
                    }
                }
                else if(message=="()unchain")
                {
                    if(num <= whocanchangeleash)
                    {
                        unleash=1;
                        DoMenu(id);
                    }
                    else
                    {
                        Notify(id,"Only the someone who can leash the sub can change if the collar unleashes when the timer runs out.",FALSE);
                    }
                }
            }
            if(llGetSubString(str, 0, 1) == "on")
            {
                string message=llGetSubString(str, 2, -1);
                if (num <= whocanchangetime)
                {
                    if (message == "clear")
                    {
                        onsettime=ontimeupat=0;
                        if(onrunning == 1)
                        {
                            //unlock
                            onrunning=0;
                            TimerWhentOff();
                        }
                    }
                    else if (message == "+00:01")
                    {
                        timechange=1*60;
                        onsettime += timechange;
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                        }
                        else if(onrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(onsettime), "");
                            ontimeupat=ontime+onsettime;
                            onrunning=1;
                        }
                    }
                    else if (message == "+00:05")
                    {
                        timechange=5*60;
                        onsettime += timechange;
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                        }
                        else if(onrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(onsettime), "");
                            ontimeupat=ontime+onsettime;
                            onrunning=1;
                        }
                    }
                    else if (message == "+00:30")
                    {
                        timechange=30*60;
                        onsettime += timechange;
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                        }
                        else if(onrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(onsettime), "");
                            ontimeupat=ontime+onsettime;
                            onrunning=1;
                        }
                    }
                    else if (message == "+03:00")
                    {
                        timechange=3*60*60;
                        onsettime += timechange;
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                        }
                        else if(onrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(onsettime), "");
                            ontimeupat=ontime+onsettime;
                            onrunning=1;
                        }
                    }
                    else if (message == "+24:00")
                    {
                        timechange=24*60*60;
                        onsettime += timechange;
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                        }
                        else if(onrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(onsettime), "");
                            ontimeupat=ontime+onsettime;
                            onrunning=1;
                        }
                    }
                    else if (message == "-00:01")
                    {
                        timechange=-1*60;
                        onsettime += timechange;
                        if (onsettime<0)
                        {
                            onsettime=0;
                        }
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            if (ontimeupat<=ontime)
                            {
                                //unlock
                                onrunning=onsettime=ontimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                            }
                        }
                    }
                    else if (message == "-00:05")
                    {
                        timechange=-5*60;
                        onsettime += timechange;
                        if (onsettime<0)
                        {
                            onsettime=0;
                        }
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            if (ontimeupat<=ontime)
                            {
                                //unlock
                                onrunning=onsettime=ontimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                            }
                        }
                    }
                    else if (message == "-00:30")
                    {
                        timechange=-30*60;
                        onsettime += timechange;
                        if (onsettime<0)
                        {
                            onsettime=0;
                        }
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            if (ontimeupat<=ontime)
                            {
                                //unlock
                                onrunning=onsettime=ontimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                            }
                        }
                    }
                    else if (message == "-03:00")
                    {
                        timechange=-3*60*60;
                        onsettime += timechange;
                        if (onsettime<0)
                        {
                            onsettime=0;
                        }
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            if (ontimeupat<=ontime)
                            {
                                //unlock
                                onrunning=onsettime=ontimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                            }
                        }
                    }
                    else if (message == "-24:00")
                    {
                        timechange=-24*60*60;
                        onsettime += timechange;
                        if (onsettime<0)
                        {
                            onsettime=0;
                        }
                        if (onrunning==1)
                        {
                            ontimeupat += timechange;
                            if (ontimeupat<=ontime)
                            {
                                //unlock
                                onrunning=onsettime=ontimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)ON_TIME+"|"+(string)(ontimeupat-lastontime), "");
                            }
                        }
                    }
                    else
                    {
                        return;
                    }
                }
                DoOnMenu(id);
            }
            else if(llGetSubString(str, 0, 3) == "real")
            {
                string message=llGetSubString(str, 4, -1);
                if (num <= whocanchangetime)
                {
                    if (message == "clear")
                    {
                        realsettime=realtimeupat=0;
                        if(realrunning == 1)
                        {
                            //unlock
                            realrunning=0;
                            TimerWhentOff();
                        }
                    }
                    else if (message == "+00:01")
                    {
                        timechange=1*60;
                        realsettime += timechange;
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                        }
                        else if(realrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realsettime), "");
                            realtimeupat=currenttime+realsettime;
                            realrunning=1;
                        }
                    }
                    else if (message == "+00:05")
                    {
                        timechange=5*60;
                        realsettime += timechange;
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                        }
                        else if(realrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realsettime), "");
                            realtimeupat=currenttime+realsettime;
                            realrunning=1;
                        }
                    }
                    else if (message == "+00:30")
                    {
                        timechange=30*60;
                        realsettime += timechange;
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                        }
                        else if(realrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realsettime), "");
                            realtimeupat=currenttime+realsettime;
                            realrunning=1;
                        }
                    }
                    else if (message == "+03:00")
                    {
                        timechange=3*60*60;
                        realsettime += timechange;
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                        }
                        else if(realrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realsettime), "");
                            realtimeupat=currenttime+realsettime;
                            realrunning=1;
                        }
                    }
                    else if (message == "+24:00")
                    {
                        timechange=24*60*60;
                        realsettime += timechange;
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                        }
                        else if(realrunning==3)
                        {
                            //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realsettime), "");
                            realtimeupat=currenttime+realsettime;
                            realrunning=1;
                        }
                    }
                    else if (message == "-00:01")
                    {
                        timechange=-1*60;
                        realsettime += timechange;
                        if (realsettime<0)
                        {
                            realsettime=0;
                        }
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            if (realtimeupat<=currenttime)
                            {
                                //unlock
                                realrunning=realsettime=realtimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                            }
                        }
                    }
                    else if (message == "-00:05")
                    {
                        timechange=-5*60;
                        realsettime += timechange;
                        if (realsettime<0)
                        {
                            realsettime=0;
                        }
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            if (realtimeupat<=currenttime)
                            {
                                //unlock
                                realrunning=realsettime=realtimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                            }
                        }
                    }
                    else if (message == "-00:30")
                    {
                        timechange=-30*60;
                        realsettime += timechange;
                        if (realsettime<0)
                        {
                            realsettime=0;
                        }
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            if (realtimeupat<=currenttime)
                            {
                                //unlock
                                realrunning=realsettime=realtimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                            }
                        }
                    }
                    else if (message == "-03:00")
                    {
                        timechange=-3*60*60;
                        realsettime += timechange;
                        if (realsettime<0)
                        {
                            realsettime=0;
                        }
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            if (realtimeupat<=currenttime)
                            {
                                //unlock
                                realrunning=realsettime=realtimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                            }
                        }
                    }
                    else if (message == "-24:00")
                    {
                        timechange=-24*60*60;
                        realsettime += timechange;
                        if (realsettime<0)
                        {
                            realsettime=0;
                        }
                        if (realrunning==1)
                        {
                            realtimeupat += timechange;
                            if (realtimeupat<=currenttime)
                            {
                                //unlock
                                realrunning=realsettime=realtimeupat=0;
                                TimerWhentOff();
                            }
                            else
                            {
                                //llMessageLinked(LINK_THIS, TIMER_TOMESSAGE, "timer|settimer|"+(string)REAL_TIME+"|"+(string)(realtimeupat-lastrealtime), "");
                            }
                        }
                    }
                    else
                    {
                        return;
                    }
                }
                DoRealMenu(id);
            }
        }
        else if (num == DIALOG_RESPONSE)
        {
            if (llListFindList([menuid, onmenuid, realmenuid], [id]) != -1)
            {//this is one of our menus
                list menuparams = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                if (id == menuid)
                {

                    // request to change to parrent menu
                    if (message == UPMENU)
                    {
                        //give av the parent menu
                        llMessageLinked(LINK_THIS, SUBMENU, parentmenu, av);
                    }
                    else if (llListFindList(buttons, [message]))
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "timer "+message, av);
                    }
                    else if (~llListFindList(buttons, [message]))
                    {
                        //we got a command which another command pluged into our menu
                        llMessageLinked(LINK_THIS, SUBMENU, message, av);
                    }
                }
                else if (id == onmenuid)
                {
                    if (message == UPMENU)
                    {
                        DoMenu(av);
                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "on"+message, av);
                    }
                }
                else if (id == realmenuid)
                {
                    if (message == UPMENU)
                    {
                        DoMenu(av);
                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "real"+message, av);
                    }
                }
            }
        }
    }

    timer()
    {
        currenttime=llGetUnixTime();
        if (currenttime<(lastrez+60))
        {
            return;
        }
        if ((currenttime-lasttime)<60)
        {
            ontime+=currenttime-lasttime;
        }
        if(ontime>=firstontime)
        {
            //could store which is need but if both are trigered it will have to send both anyway I prefer not to check for that.
            message="timer|timeis|"+(string)ON_TIME+"|"+(string)ontime;
            llWhisper(interfaceChannel, message);
            llMessageLinked(LINK_THIS, TIMER_FROMMESSAGE, message, "");

            firstontime=MAX_TIME;
            timeslength=llGetListLength(times);
            for(n = 0; n < timeslength; n = n + 2)// send notice and find the next time.
            {
                if(llList2Integer(times, n)==ON_TIME)
                {
                    while(llList2Integer(times, n+1)<=ontime&&llList2Integer(times, n)==ON_TIME&&times!=[])
                    {
                        times=llDeleteSubList(times, n, n+1);
                        timeslength=llGetListLength(times);
                    }
                    if(llList2Integer(times, n)==ON_TIME&&llList2Integer(times, n+1)<firstontime)
                    {
                        firstontime=llList2Integer(times, n+1);
                    }
                }
            }
        }
        if(currenttime>=firstrealtime)
        {
            //could store which is need but if both are trigered it will have to send both anyway I prefer not to check for that.
            message="timer|timeis|"+(string)REAL_TIME+"|"+(string)currenttime;
            llWhisper(interfaceChannel, message);
            llMessageLinked(LINK_THIS, TIMER_FROMMESSAGE, message, "");

            firstrealtime=MAX_TIME;
            timeslength=llGetListLength(times);
            for(n = 0; n < timeslength; n = n + 2)// send notice and find the next time.
            {
                if(llList2Integer(times, n)==REAL_TIME)
                {
                    while(llList2Integer(times, n+1)<=currenttime&&llList2Integer(times, n)==REAL_TIME)
                    {
                        times=llDeleteSubList(times, n, n+1);
                        timeslength=llGetListLength(times);
                    }
                    if(llList2Integer(times, n)==REAL_TIME&&llList2Integer(times, n+1)<firstrealtime)
                    {
                        firstrealtime=llList2Integer(times, n+1);
                    }
                }
            }
        }
        if(onrunning == 1 && ontimeupat<=ontime)
        {
            TimerWhentOff();
        }
        if(realrunning == 1 && realtimeupat<=currenttime)
        {
            TimerWhentOff();
        }
        lasttime=currenttime;
    }

}
