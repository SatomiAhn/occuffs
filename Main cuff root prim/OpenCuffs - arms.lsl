//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//color

//on getting color command, give menu to choose which element, followed by menu to pick color

// Changes for OpenCuffs
// Globla variable for channel and commnad added
// function to send command to slave funtion added
// Sending of messages to slave cuff in Listener added


list elements;
string parentmenu = "Cuff Poses";
string submenu = "Arm Cuffs";
string dbtoken = "cuff-arms";
list buttons;

integer lastrank = 10000; //in this integer, save the rank of the person who posed the av, according to message map.  10000 means unposed

key g_keyDialogID;

key g_keyWearer;

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

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

//5000 block is reserved for IM slaves

string UPMENU = "^";

//===============================================================================
// AK - Cuff - functions & variables
//===============================================================================
string    g_szActAnim        = "";
integer g_nCmdChannel    = -190890;
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for


list    g_lstLocks;
list    g_lstAnims;
list    g_lstChains;

integer pos_line;
string pos_file;
key pos_query;

LoadLocks(string file)
{
    pos_line = 0;
    pos_file = file;
    g_lstLocks = g_lstAnims = g_lstChains = [];
    LoadLocksNextLine();
}

LoadLocksNextLine()
{
    pos_query = llGetNotecardLine( pos_file, pos_line);
}

integer LoadLocksParse( key queryid, string data)
{
    if ( pos_query != queryid ) return 0;
    if ( data == EOF )
    {
        akDebug(pos_file+" loaded, "+(string)llGetListLength(g_lstLocks)+" locks active.","",0,0);
        g_lstLocks = ["*Stop*"] + g_lstLocks;
        g_lstAnims = [""] + g_lstAnims;
        g_lstChains = [""] + g_lstChains;
        return -1;
    }
    pos_line ++;
    LoadLocksNextLine();

    if (llGetSubString(data,0,0)=="#")
        // comment, no need to parse that
    {
        return 1;
    }

    list lock = llParseString2List( data, ["|"], [] );
    if ( llGetListLength(lock) != 3 )
    {
        return 1;
    }
    g_lstLocks += (list)llList2String(lock,0);
    g_lstAnims += (list)llList2String(lock,1);
    g_lstChains += (list)llList2String(lock,2);
    return 1;
}


integer    LM_CUFF_CMD        = -551001;        // used as channel for linkemessages - sending commands
integer    LM_CUFF_ANIM    = -551002;        // used as channel for linkedmessages - sending animation cmds
integer    LM_CUFF_CHAINTEXTURE = -551003;   // used as channel for linkedmessages - sending the choosen texture to the cuff

list    g_lstModTokens    = ["rlac","orlac","irlac"]; // list of attachment points in this cuff, only need for the main cuff, so i dont want to read that from prims

integer    g_nDebug        = FALSE;
integer    g_nShowScript    = FALSE;

string g_szLGChainTexture="";

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
//= parameters   :  string szMsg        output message
//=                 string szFunc        function name if not ""
//=                 integer nScript        send scriptname ?
//=                 integer nChannel    channel to be sent on -1 = llOwnerSay
//=
//= description  : Function for debug output.
//=                If g_nDebug is FALSE = no output is sent
//=                If g_nShowScript is FALSE = scriptname always shown
//=
//===============================================================================
akDebug(string szMsg, string szFunc, integer nScript, integer nChannel)
{
    if ( g_nDebug )
    {
        string    szOutput    = "\nDebug Output :\n=============";

        if( szFunc != "" )
            szOutput += "\nFunction : " + szFunc;

        if ( nScript || g_nShowScript)
            szOutput += "\nScript : " + llGetScriptName();

        szOutput += "\n" + szMsg + "\n=============";

        if ( nChannel == -1 )
            llOwnerSay(szOutput);
        else
            llWhisper(nChannel, szOutput);
    }
}

//===============================================================================
//= parameters   :  integer nOffset        Offset to make sure we use really a unique channel
//=
//= description  : Function which calculates a unique channel number based on the owner key, to reduce lag
//=
//= returns      : Channel number to be used
//===============================================================================
integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)llGetOwner(),3,8)) + g_nCmdChannelOffset;
    if (chan>0)
    {
        chan=chan*(-1);
    }
    if (chan > -10000)
    {
        chan -= 30000;
    }
    return chan;
}


//===============================================================================
//= parameters   :    string    szSendTo    prefix of receiving modul
//=                    string    szCmd       message string to send
//=                    key        keyID        key of the AV or object
//=
//= retun        :    none
//=
//= description  :    Sends the command with the prefix and the UUID
//=                    on the command channel
//=
//===============================================================================
SendCmd( string szSendTo, string szCmd, key keyID )
{
    llRegionSay(g_nCmdChannel + 1, llList2String(g_lstModTokens,0) + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
    //llWhisper(0, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

//===============================================================================
//= parameters   :    key        keyID    key of the calling AV or object
//=                   string  szChain    chain info string
//=                 string  szLink  link or unlin the chain
//=
//= retun        :
//=
//= description  :    devides the chain string into single chain commands
//=                    delimiter = ~
//=                    single chains are redirected to Chains
//=
//===============================================================================
DoChains( key keyID, string szChain, string szLink )
{
    list    lstParsed = llParseString2List( szChain, [ "~" ], [] );

    integer nCnt = llGetListLength(lstParsed);
    integer i = 0;

    for (i = 0; i < nCnt; i++ )
    {
        Chains(keyID, llList2String(lstParsed, i), szLink);
    }

    lstParsed = [];
}

//===============================================================================
//= parameters   :    string    szMsg    Lock name forced from calling AV
//=                    key        keyID    key of the calling AV
//=
//= retun        :    none
//=
//= description  :    Sends the Anim & chain LM with the ID of the calling AV
//=
//===============================================================================
Chains(key keyID, string szChain, string szLink)
{
    list    lstParsed    = llParseString2List( szChain, [ "=" ], [] );
    string    szTo        = llList2String(lstParsed,0);
    string    szFrom        = llList2String(lstParsed,1);
    string    szCmd;
    if (szLink=="link")
    {
        if (g_szLGChainTexture=="")
        {
            szCmd="link";
        }
        else
        {
            szCmd="link "+g_szLGChainTexture;
        }
    }
    else
    {
        szCmd="unlink";
    }

    if ( llListFindList(g_lstModTokens,[szTo]) != -1 )
    {
        llMessageLinked( LINK_SET, LM_CUFF_CMD, "chain=" + szChain + "=" + szCmd, llGetKey() );
    }
    else
    {

        SendCmd(szTo, "chain=" + szChain + "=" + szCmd, llGetKey());
    }
}

CallAnim( string szMsg, key keyID )
{

    integer nIdx    = -1;
    string    szAnim    = "";
    string    szChain    = "";

    if ( g_szActAnim != "")
        nIdx    = llListFindList(g_lstLocks, [g_szActAnim]);

    if ( nIdx != -1 )
    {
        szChain    = llList2String(g_lstChains, nIdx);
        //llMessageLinked( LINK_SET, LM_CUFF_CMD, "chain=" + szChain + "=unlink", keyID );
        DoChains(keyID, szChain, "unlink");
    }


    if ( szMsg == "Stop" )
    {
        g_szActAnim = "";
        llMessageLinked( LINK_SET, LM_CUFF_ANIM, "a:Stop", keyID );
    }
    else
    {
        nIdx = llListFindList(g_lstLocks, [szMsg]);
        if (nIdx != -1 )
        {
            g_szActAnim = szMsg;

            szAnim    = llList2String(g_lstAnims, nIdx);
            szChain    = llList2String(g_lstChains, nIdx);

            llMessageLinked( LINK_SET, LM_CUFF_ANIM, "a:"+szAnim, keyID );
            DoChains(keyID, szChain, "link");
        }
    }

    // llMessageLinked( LINK_SET, LM_CUFF_CMD, "chain=rlac=llac=link", keyID );
    // SendCmd("lwc", "chain=llac=rlac=link", llGetKey());
}

//===============================================================================
// END AK - Cuff - Functions
//===============================================================================

DoMenu(key id)
{
    string prompt = "Pick an option.";
    list mybuttons = buttons + g_lstLocks;

    //fill in your button list here


    g_keyDialogID=Dialog(id, prompt, mybuttons, [UPMENU], 0);
}



integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

default
{
    state_entry()
    {
        g_nCmdChannel= nGetOwnerChannel(g_nCmdChannelOffset);

        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);

        akDebug(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory(), "", FALSE, -1);
        //llOwnerSay(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory());
        //        g_lstModTokens = GetCuffNames();
        LoadLocks("Arm Cuffs");
        
        g_keyWearer=llGetOwner();
    }
    dataserver( key queryid, string data ) {
        if ( LoadLocksParse( queryid, data ) ) return;
    }
    changed(integer change) {
        if ( change & CHANGED_INVENTORY ) {
            LoadLocks("Arm Cuffs");
        }
    }

    link_message(integer sender, integer auth, string str, key id)
    {
        //owner, secowner, group, and wearer may currently change colors
        if (str == "reset" && (auth == COMMAND_OWNER || auth == COMMAND_WEARER))
        {
            //clear saved settings
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
            llResetScript();
        }
        else if (auth==LM_CUFF_CHAINTEXTURE)
        {
            g_szLGChainTexture=str;
            if (g_szActAnim!="")
            {
                CallAnim(g_szActAnim,llGetOwner());
            }

        }
        else if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            if ( str == "unlock" )
            {   
                lastrank = 10000; 
            }
            else if ( startswith(str,"*:") || startswith(str,"a:") )
            {
                //llOwnerSay("Bing:"+(string)auth+";"+(string)lastrank+";"+str);
                if (auth <= lastrank)
                {
                    if (llGetSubString(str, 2,-1)=="Stop")
                    {
                        lastrank = 10000;
                    }
                    else if ( id == g_keyWearer )
                    {
                        lastrank = 10000;
                    }
                    else
                    {
                        lastrank=auth;
                    }

                    CallAnim(llGetSubString(str, 2,-1), id);
                    //llMessageLinked(LINK_THIS, ANIM_STOP, currentpose, NULL_KEY);
                    //currentpose = "";
                }
            }
            else if (str == "refreshmenu")
            {
                buttons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, NULL_KEY);
            }
        }
        else if (auth == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            //we don't know the authority of the menu requester, so send a message through the auth system
            //llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "Cuffs", id);
            DoMenu(id);
        }
        else if ( auth == LM_CUFF_CMD )
        {
            string szToken = llGetSubString(str, 0,1);

            if ( str == "reset")
            {
                llResetScript();
            }
            //else if ( szToken == "*:" || szToken == "a:" )
            //{
            //    CallAnim(llGetSubString(str, 2,-1), id);
            //}
            // set the receiver/module token of this module
            //            else if ( llGetSubString(str,0,8)  == "settoken=" )
            //            {
            //                g_szModToken = llGetSubString(str,9,-1);
            //            }
        }
        else if ( auth == DIALOG_RESPONSE)
        {
            if (id==g_keyDialogID)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                key AV = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                if (message == UPMENU)
                {
                    llMessageLinked(LINK_THIS, SUBMENU, parentmenu, AV);
                }
                else if (~llListFindList(g_lstLocks, [message]))
                {
                    if (message=="*Stop*")
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "a:Stop", AV);
                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "a:"+message, AV);
                    }
                    //CallAnim(message, AV);
                    DoMenu(AV);
                }
            }
        }
    }

    on_rez(integer param)
    {
        if (g_keyWearer!=llGetOwner())
        {
            llResetScript();
        }
        else if (g_szActAnim!="")
        {
            llSleep(4.0); // wiat till hopefully everyone is ready before rebuilding anims and chains
            CallAnim(g_szActAnim,llGetKey());
        }
    }
}
