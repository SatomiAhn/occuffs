//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//color

//on getting color command, give menu to choose which element, followed by menu to pick color

// Changes for OpenCuffs
// Globla variable for channel and commnad added
// function to send command to slave funtion added
// Sending of messages to slave cuff in Listener added


string parentmenu = "Main";
string submenu = "Cuff Poses";
string dbtoken = "cuffmenu";
list localbuttons = ["Stop all"]; //["Arms", "Legs", "Stop all"];
list buttons;

// stay mode when legs are cuffed
string      g_szStayModeFixed = "Stay: Fixed";
string      g_szStayModeSlow = "Stay: Slow";
string      g_szStayModeFree = "Stay: Free";
string      g_szStayModeToken1 = "stay";
integer     g_nStayModeFixed = FALSE; // instead of false we use a very high value
integer     g_nStayModeAuth = FALSE; // instead of false we use a very high value

// RLV restriction when chained
string      g_szRLVModeEnabled = "(*) RLV Restricions";
string      g_szRLVModeDisabled = "( ) RLV Restricions";
string      g_szRLVModeToken = "rest";
integer     g_nRLVModeAuth = FALSE;

key g_keyDialogID;


//MESSAGE MAP
//integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505; //deprecated.  Too laggy to make every single script parse a link message any time anyone says anything
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;  // new for safeword


//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from DB
integer LM_SETTING_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

//5000 block is reserved for IM slaves

string UPMENU = "^";

//=============================================================================
//== OpenCuff - armCuff - main/menu module
//== sends token of the cuff and calls the arm and leg cuff menus
//==
//==
//== 2009-01-16 Jenny Sigall - 1. draft
//== 2009-02-16 Jenny Sigall - combined with OpenCollar scripts
//==
//==
//=============================================================================

//===============================================================================
// AK - Cuff - functions & variables
//===============================================================================
string    g_szModToken    = "rlac";         // valid token for this module

integer    LM_CUFF_CMD        = -551001;        // used as channel for linkemessages - sending commands
integer    LM_CUFF_ANIM    = -551002;        // used as channel for linkedmessages - sending animation cmds

key        g_keyWearer        = NULL_KEY;        // key of the owner/wearer

integer    g_nDebug        = FALSE;
integer    g_nShowScript    = FALSE;

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
// END AK - Cuff - functions & variables
//===============================================================================

//===============================================================================
//= parameters   :   none
//=
//= return        :    string prefix for the object in the form of "oc_"
//=
//= description  :    generate the prefix from the object desctiption
//=
//===============================================================================


string szGetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

//===============================================================================
//= parameters   :    key keyID   Target for the message
//=                string szMsg   Message to SEND
//=                integer nAlsoNotifyWearer Boolean to notify the wearer as well
//=
//= return        :    none
//=
//= description  :    send a message to a receiver and if needed to the wearer as well
//=
//===============================================================================



Notify(key keyID, string szMsg, integer nAlsoNotifyWearer)
{
    if (keyID == g_keyWearer)
    {
        llOwnerSay(szMsg);
    }
    else
    {
        llInstantMessage(keyID,szMsg);
        if (nAlsoNotifyWearer)
        {
            llOwnerSay(szMsg);
        }
    }
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

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page, integer iAuth)
{
    key id = ShortKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`") + "|" + (string) iAuth, id);
    return id;
}

DoMenu(key id, integer iAuth)
{
    string prompt = "Pick an option.";
    list mybuttons = llListSort(localbuttons + buttons, 1, TRUE);

    //fill in your button list here

    if (g_nStayModeAuth>0)
    {
        if (g_nStayModeFixed)
        {
            mybuttons += [g_szStayModeFixed];
        }
        else
        {
            mybuttons += [g_szStayModeSlow];
        }
    }
    else
    {
        mybuttons += [g_szStayModeFree];
    }

    if (g_nRLVModeAuth>0)
    {
        mybuttons += [g_szRLVModeEnabled];
    }
    else
    {
        mybuttons += [g_szRLVModeDisabled];
    }

    g_keyDialogID=Dialog(id, prompt, mybuttons, [UPMENU], 0, iAuth);
}

//===============================================================================
//= parameters   :    list    lstIn   list of menu buttons
//=
//= return        :   list    updated list of menu buttons
//=
//= description  :    resort menu button top to do and fills the menu to be user finldy
//=
//===============================================================================



integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

init()
{

    g_keyWearer = llGetOwner();
    llMessageLinked(LINK_THIS, LM_CUFF_CMD, "settoken=" + g_szModToken, g_keyWearer);

    akDebug(llGetScriptName ()+" ready - Memory : " + (string)llGetFreeMemory(), "init", FALSE, -1);

    g_szStayModeToken1=szGetDBPrefix() + g_szStayModeToken1;
    g_szRLVModeToken=szGetDBPrefix() + g_szRLVModeToken;


    llSleep(1.0);
    llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);

}

integer UserCommand(integer iNum, string sStr, key kID)
{
    if (iNum > COMMAND_WEARER || iNum < COMMAND_OWNER) return FALSE; // sanity check
    //owner, secowner, group, and wearer may currently change colors
    if (sStr == "reset" && (iNum == COMMAND_OWNER || kID == g_keyWearer))
    {
        //clear saved settings
        llMessageLinked(LINK_THIS, LM_SETTING_DELETE, dbtoken, NULL_KEY);
        llResetScript();
    }
    if (sStr == "refreshmenu")
    {
        buttons = [];
        llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, NULL_KEY);
    }

    else if (startswith(sStr,"staymode"))
    {
        if ((g_nStayModeAuth!=0)&&(g_nStayModeAuth<iNum))
        {
            Notify(kID,"You are not allowed to change the stay mode.",FALSE);
        }
        else if (sStr=="staymode=off")
            // disable the stay mode
        {
            g_nStayModeAuth=FALSE;
            llMessageLinked(LINK_THIS,LM_SETTING_DELETE,g_szStayModeToken1,"");
            llMessageLinked(LINK_THIS, LM_CUFF_CMD, "staymode=off", NULL_KEY);
            Notify(kID,llKey2Name(g_keyWearer)+ " will now be able to move, even when the legs are bound.", TRUE);
        }
        else if (sStr=="staymode=slow")
            // enable the slow mode
        {
            g_nStayModeAuth=iNum;
            g_nStayModeFixed=FALSE;
            llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_szStayModeToken1+"="+(string)iNum+",S","");
            llMessageLinked(LINK_THIS, LM_CUFF_CMD, "staymode=slow", NULL_KEY);
            Notify(kID,llKey2Name(g_keyWearer)+ " will now only able to move very slowly, when the legs are bound.", TRUE);
            
        }
        else if (sStr=="staymode=on")
            // enable the stay mode
        {
            g_nStayModeAuth=iNum;
            g_nStayModeFixed=TRUE;
            llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_szStayModeToken1+"="+(string)iNum+",F","");
            llMessageLinked(LINK_THIS, LM_CUFF_CMD, "staymode=on", NULL_KEY);
            Notify(kID,llKey2Name(g_keyWearer)+ " will now NOT be able to move, when the legs are bound.", TRUE);
            
        }

    }
    else if (sStr=="rlvmode=off")
        // disable the stay mode
    {
        if (g_nRLVModeAuth>=iNum)
        {
            g_nRLVModeAuth=FALSE;
            llMessageLinked(LINK_THIS,LM_SETTING_DELETE,g_szRLVModeToken,"");
            llMessageLinked(LINK_THIS, LM_CUFF_CMD, "rlvmode=off", NULL_KEY);
            Notify(kID,llKey2Name(g_keyWearer)+ " will now NOT be under RLV restrictions when bound.", TRUE);
        }
        else
        {
            Notify(kID,"You are not allowed to change the restriction mode.",FALSE);
        }
    }
    else if (sStr=="rlvmode=on")
        // enable the stay mode
    {
        g_nRLVModeAuth=iNum;
        llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_szRLVModeToken+"="+(string)iNum,"");
        llMessageLinked(LINK_THIS, LM_CUFF_CMD, "rlvmode=on", NULL_KEY);
        Notify(kID,llKey2Name(g_keyWearer)+ " will now be under RLV restrictions when bound.", TRUE);
    }


    else if (sStr == "menu "+ submenu||sStr == submenu)
    {
            DoMenu(kID, iNum);
    }        
    return TRUE;
}

default
{
    state_entry()
    {
        init();
    }

    link_message(integer nSenderNum, integer nNum, string szMsg, key keyID)
    {
        if ( nNum == LM_CUFF_CMD )
        {
            if ( szMsg == "reset" )
            {
                llResetScript();
            }
        }
        else if ( UserCommand(nNum, szMsg, keyID) ) {}
        else if (nNum == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (nNum == MENUNAME_RESPONSE)
        {
            list parts = llParseString2List(szMsg, ["|"], []);
            if (llList2String(parts, 0) == submenu)
            {//someone wants to stick something in our menu
                string button = llList2String(parts, 1);
                if (llListFindList(buttons, [button]) == -1)
                {
                    buttons = llListSort(buttons + [button], 1, TRUE);
                }
            }
        }
        else if (nNum == COMMAND_SAFEWORD)
        {
            llMessageLinked(LINK_THIS, COMMAND_OWNER, "*:Stop", keyID);  // (SA) was COMMAND_NOAUTH... TODO : check what is actually needed
        }
        else if (nNum == LM_SETTING_RESPONSE)
        {
            if (startswith(szMsg,g_szStayModeToken1))
            {
                list l=llParseString2List(llGetSubString(szMsg,llStringLength(g_szStayModeToken1)+1,-1),[","],[]);
                integer n=(integer)llList2String(l,0);
                string s=llList2String(l,1);
                if (n>0)
                {
                    g_nStayModeAuth=n;
                    if (s=="F") //fixed
                    {
                        llMessageLinked(LINK_THIS, LM_CUFF_CMD, "staymode=on", NULL_KEY);
            g_nStayModeFixed=TRUE;
            }
            else
            {
            llMessageLinked(LINK_THIS, LM_CUFF_CMD, "staymode=slow", NULL_KEY);
            g_nStayModeFixed=FALSE;
            }
        }
        else
        {
            g_nStayModeAuth=FALSE;
            llMessageLinked(LINK_THIS, LM_CUFF_CMD, "staymode=off", NULL_KEY);
        }

        }
        else if (startswith(szMsg,g_szRLVModeToken))
        {
        integer n=(integer)llGetSubString(szMsg,llStringLength(g_szRLVModeToken)+1,-1);
        if (n>0)
        {
            g_nRLVModeAuth=n;
            llMessageLinked(LINK_THIS, LM_CUFF_CMD, "rlvmode=on", NULL_KEY);
        }
        else
        {
            g_nRLVModeAuth=FALSE;
            llMessageLinked(LINK_THIS, LM_CUFF_CMD, "rlvmode=off", NULL_KEY);
        }
        }
    }
    else if (nNum == DIALOG_RESPONSE)
    {
        if(keyID == g_keyDialogID)
        {

        list menuparams = llParseString2List(szMsg, ["|"], []);
        key AV = (key)llList2String(menuparams, 0);
        string message = llList2String(menuparams, 1);
        integer page = (integer)llList2String(menuparams, 2);
        integer iAuth = (integer)llList2String(menuparams, 3);

        if (message == UPMENU)
        {
            llMessageLinked(LINK_THIS, iAuth, "menu " + parentmenu, AV);
        }
        else if (~llListFindList(localbuttons, [message]))
        {
            if ( message == "Stop all" )
            {
                llMessageLinked(LINK_THIS, iAuth, "*:Stop", AV);
                // Cleo: Call the menu again
                DoMenu(AV, iAuth);
            }
        }
        else if (~llListFindList(buttons, [message]))
        {
            //we got a submenu selection
            llMessageLinked(LINK_THIS, iAuth, "menu " + message, AV);
        }
        else if (message==g_szStayModeFixed)
            // disable the stay mode
        {
            llMessageLinked(LINK_THIS, iAuth, "staymode=off", AV);
            DoMenu(AV, iAuth);
        }
        else if (message==g_szStayModeSlow)
            // disable the stay mode
        {
            llMessageLinked(LINK_THIS, iAuth, "staymode=on", AV);
            DoMenu(AV, iAuth);
        }
        else if (message==g_szStayModeFree)
            // enable the stay mode
        {
            llMessageLinked(LINK_THIS, iAuth, "staymode=slow", AV);
            DoMenu(AV, iAuth);
        }
        else if (message==g_szRLVModeEnabled)
            // disable the stay mode
        {
            llMessageLinked(LINK_THIS, iAuth, "rlvmode=off", AV);
            DoMenu(AV, iAuth);
        }
        else if (message==g_szRLVModeDisabled)
            // enable the stay mode
        {
            llMessageLinked(LINK_THIS, iAuth, "rlvmode=on", AV);
            DoMenu(AV, iAuth);
        }
        }
    }
    }

    //on_rez(integer param)
    //{
    // Cleo: Why reset here, is that really needed
    // llMessageLinked(LINK_THIS, LM_CUFF_CMD, "reset", NULL_KEY);
    //}

    changed(integer change)
    {
        // Cleo: But reset on user change cant hurt
        if (change==CHANGED_OWNER)
        {
            llMessageLinked(LINK_THIS, LM_CUFF_CMD, "reset", NULL_KEY);
        }
    }
}