//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//Collar Cuff Menu

//=============================================================================
//== OC Cuff - Command forwarder to listen for commands in OpenCollar
//== receives messages from linkmessages send within the collar
//== sends the needed commands out to the cuffs
//==
//==
//== 2009-01-16 Cleo Collins - 1. draft
//==
//==
//=============================================================================

integer g_nCmdChannel    = -190890;        // command channel for sending commands to the main cuff
integer    g_nCmdHandle    = 0;            // command listen handler
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for

// Commands to be send to the Cuffs
string g_szOwnerChangeCmd="OwnerChanged";
string g_szColorChangeCmd="ColorChanged";
string g_szTextureChangeCmd="TextureChanged";
string g_szCuffMenuCmd="CuffMenu";
string g_szSwitchHideCmd="ShowHideCuffs";
string g_szSwitchLockCmd="SwitchLock";

integer g_nRecolor=FALSE; // only send color values on demand
integer g_nRetexture=FALSE; // only send texture values on demand

float g_fMinVersion=3.331;

string submenu = "Cuffs";
string parentmenu = "AddOns";

key g_keyDialogID;

list localbuttons = ["Cuff Menu","Upd. Colors", "Upd. Textures", "(Un)Lock Cuffs", "Show/Hide"];
list buttons;

string g_szPrefix; // sub prefix for databse actions

string g_szOwnerChangeCollarInfo="OpenCuff_OwnerChanged"; // command for the collar to reset owner system
string g_szRLVChangeToCollarInfo="OpenCuff_RLVChanged"; // command to the collar to inform about RLV usage switched
string g_szRLVChangeFromCollarInfo="OpenCollar_RLVChanged"; // command from the collar to inform about RLV usage switched
string g_szCollarMenuInfo="OpenCollar_ShowMenu"; // command for the collar to show the menu

integer g_nLastRLVChange=-1;

list g_lstResetOnOwnerChange=["OpenCollar - auth - 3.","OpenCollar - httpdb - 3.","OpenCollar - settings - 3."]; // scripts to be reseted on ownerchanges to keep system in sync

// chat command for opening the mnu of the cuffs directly
string g_szOpenCuffMenuCommand="cuffmenu";

// variables for automativ updating collor and appearance in the cuffs
string g_szUpdateActive_ON ="Sync On";
string g_szUpdateActive_OFF ="Sync Off";
string g_szUpdateActive_DBsave="cuffautosync";
integer g_nUpdateActive= TRUE;

// preparation for online mode
string g_szOnlineModeCommand="online";
integer g_nOnline=TRUE;

key wearer;

string g_szScriptIdentifier="OpenCollar - cuffs -"; // for checking if already an older version of theis scrip is in the collar

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
integer COMMAND_SAFEWORD = 510;  // new for safeword

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
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST = 7002;//id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE = 7003;//str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START = 7004;//str should be valid anim name.  id should be av
integer CPLANIM_STOP = 7005;//str should be valid anim name.  id should be av

integer ATTACHMENT_REQUEST = 600;
integer ATTACHMENT_RESPONSE = 601;
integer ATTACHMENT_FORWARD = 610;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;


string UPMENU = "^";//when your menu hears this, give the parent menu

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


integer VersionOK()
{
    // checks if the version of the collar fits the needed version for the plugin
    list params = llParseString2List(llGetObjectDesc(), ["~"], []);
    string name = llList2String(params, 0);
    string version = llList2String(params, 1);
    
    if (llGetSubString(name,0,11)=="Delivery Box")
    // the script is in a delivery box, fall silently to sleep
    {
        return FALSE;
    }
    else if (name == "" || version == "")
    {
        llOwnerSay("Description of collar is invalid, please check that you use this plugin only with collar higher than "+llGetSubString((string)g_fMinVersion,0,4)+".");
    }
    else if ((float)version)
    {
        if ((float)version<g_fMinVersion)
        {
            llOwnerSay("Your collar is to old for this plugin. Please update to Version "+llGetSubString((string)g_fMinVersion,0,4)+" or higher.");
        }
        else
        {
            return TRUE;
        }
    }
    else
    {
        llOwnerSay("Description of collar is invalid, please check that you use this plugin only with collar higher than "+llGetSubString((string)g_fMinVersion,0,4)+".");
        
    }
    return FALSE;
}


//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    output debug messages
//=
//===============================================================================


Debug(string szMsg)
{
    //llOwnerSay(llGetScriptName() + ": " + szMsg);
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
    integer chan = (integer)("0x"+llGetSubString((string)wearer,3,8)) + g_nCmdChannelOffset;
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

//===============================================================================
//= parameters   :   string    szColorString   string with objectnames and colors
//=
//= return        :    none
//=
//= description  :    break up the Itemnams and Color into seveal commands
//=                    and send them out to the cuffs
//=
//===============================================================================


SendRecoloring (string szColorString)
{
    list lstColorList=llParseString2List(szColorString, ["~"], []);
    integer nColorCount=llGetListLength(lstColorList);
    integer i;
    for (i=0;i<nColorCount;i=i+2)
    {
        llRegionSay(g_nCmdChannel,"occ|*|"+g_szColorChangeCmd+"="+llList2String(lstColorList,i)+"="+llList2String(lstColorList,i+1)+"|" + (string)wearer);
    }

}

//===============================================================================
//= parameters   :   string    szTextureString   string with objectnames and texture IDs
//=
//= return        :    none
//=
//= description  :    break up the Itemnams and texture IDs into several commands
//=                    and send them out to the cuffs
//=
//===============================================================================


SendRetexturing (string szTextureString)
{
    list lstTextureList=llParseString2List(szTextureString, ["~"], []);
    integer nTextureCount=llGetListLength(lstTextureList);
    integer i;
    for (i=0;i<nTextureCount;i=i+2)
    {
        llRegionSay(g_nCmdChannel,"occ|*|"+g_szTextureChangeCmd+"="+llList2String(lstTextureList,i)+"="+llList2String(lstTextureList,i+1)+"|" + (string)wearer);
    }

}
//===============================================================================
//= parameters   :   string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    gets called when a command to save into the HTTPDB is detected
//=                    analyzes if the save would need any update in th cuffs
//=
//===============================================================================

Analyse_HTTPDB_Save(string szMsg)
{

    // split the message into token and message
    list lstParams = llParseString2List(szMsg, ["="], []);
    string szToken = llList2String(lstParams, 0);
    string szValue = llList2String(lstParams, 1);

    // now scheck if we have to take action
    if ((szToken=="owner")||(szToken=="secowners")||(szToken=="group")||(szToken=="openaccess")||(szToken=="blacklist"))
    {
        if (g_nOnline)
        {
            // owner right have been changed,, inform the cuffs
            llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szOwnerChangeCmd+"="+szToken+"|" + (string)wearer);
        }
    }
    else if (g_nUpdateActive && (szToken==g_szPrefix+"colorsettings"))
    {

        // for now active updating on every click is not in use

        // owner right have been changed,, inform the cuffs
        SendRecoloring(szValue);


    }
    else if (g_nUpdateActive && (szToken==g_szPrefix+"textures"))
    {
        // for now active updating on every click is not in use

        // owner right have been changed,, inform the cuffs
        SendRetexturing(szValue);

    }

}


//===============================================================================
//= parameters   :   string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    gets called when a command to delete a value stored in the HTTPDB is detected
//=                    analyzes if the delete would need any update in th cuffs
//=
//===============================================================================

Analyse_HTTPDB_Delete(string szMsg)
{
    if ((szMsg=="owner")||(szMsg=="secowners")||(szMsg=="group")||(szMsg=="openaccess")||(szMsg=="blacklist"))
    {
        // owner right have been changed,, inform the cuffs
        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szOwnerChangeCmd+"="+szMsg+"|" + (string)wearer);
    }

}


//===============================================================================
//= parameters   :   none
//=
//= return        :    none
//=
//= description  :    display an error message if more than one plugin of the same version is found
//=
//===============================================================================

DoubleScriptCheck()
{
    integer l=llStringLength(g_szScriptIdentifier)-1;
    string s;
    integer i;
    integer c=0;
    integer m=llGetInventoryNumber(INVENTORY_SCRIPT);
    for(i=0;i<m;i++)
    {
        s=llGetSubString(llGetInventoryName(INVENTORY_SCRIPT,i),0,l);
        if (g_szScriptIdentifier==s)
        {
            c++;
        }
    }
    if (c>1)
    {
        llOwnerSay ("There is more than one version of the Cuffs plugin in your collar. Please make sure you only keep the latest version of this plugin in your collar and delete all other versions.");
    }
}


ScriptReseter()
{
    integer i;
    integer j;
    integer nMaxScripts=llGetInventoryNumber(INVENTORY_SCRIPT);
    integer nMaxResetScripts=llGetListLength(g_lstResetOnOwnerChange);
    string sz_CurrentScript;
    for (i=0;i<nMaxScripts;i++)
    {
        sz_CurrentScript=llGetInventoryName(INVENTORY_SCRIPT,i);
        for (j=0;j<nMaxResetScripts;j++)
        {
            if (nStartsWith(sz_CurrentScript,llList2String(g_lstResetOnOwnerChange,j)))
            {
                llResetOtherScript(sz_CurrentScript);
                llSleep(1.5);
            }
        }
    }

}

DoMenu(key id)
{
    string prompt = "Pick an option.";

    list mybuttons = localbuttons + buttons;

    //fill in your button list here


    if (g_nUpdateActive)
    {
        prompt += " Colors and textures will be sycronized automatically to your cuffs, when you change them on the collar.";
        mybuttons+=[g_szUpdateActive_OFF];
    }
    else
    {
        prompt += " Colors and textures will NOT be sycronized automatically to your cuffs, when you change them on the collar.";
        mybuttons+=[g_szUpdateActive_ON];
    }
    g_keyDialogID=Dialog(id, prompt, mybuttons, [UPMENU],0);
}




string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}


default
{
    state_entry()
    {
        if (!VersionOK()) state WrongVersion;
        
        wearer=llGetOwner();

        DoubleScriptCheck();

        g_nCmdChannel= nGetOwnerChannel(g_nCmdChannelOffset);

        // wait for all scripst to be ready
        llSleep(1.0);

        // any submenu want to register?
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);

        // include ourselft into parent menu
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);

        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        g_szPrefix = GetDBPrefix();

        // How is our memory?
        Debug("Available memory for "+llGetScriptName()+": "+(string)llGetFreeMemory());
    }

    on_rez(integer param)
    {
        llResetScript();
    }

    attach(key id)
    {
        if (id == NULL_KEY)
            // any last words?
        {

        }
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == SUBMENU && str == submenu)
        {
            //someone asked for our menu
            //give this plugin's menu to id
            DoMenu(id);
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {

            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == MENUNAME_RESPONSE)
        {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == submenu)
            {//someone wants to stick something in our menu
                string button = llList2String(parts, 1);
                if (llListFindList(buttons, [button]) == -1)
                {
                    buttons = llListSort(buttons + [button], 1, TRUE);
                }
            }
        }
        else if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if ((g_nRecolor)&&(token == g_szPrefix+"colorsettings"))
            {
                llOwnerSay("Recoloring:"+value);
                SendRecoloring(value);
                g_nRecolor=FALSE;
            }
            else if ((g_nRetexture)&&(token == g_szPrefix+"textures"))
            {
                SendRetexturing(value);
                g_nRetexture=FALSE;
            }
            else if (token == g_szPrefix+g_szUpdateActive_DBsave)
            {
                g_nUpdateActive=(integer)value;
            }
            else if (token==g_szOnlineModeCommand)
                // is the collar in online mode?
            {
                if (value=="1")
                {
                    g_nOnline=TRUE;
                }
                else
                {
                    g_nOnline=FALSE;
                }

            }

        }

        else if (num == HTTPDB_SAVE)
        {
            // the collar saves to the HTTDB, so anaylye the command
            Analyse_HTTPDB_Save(str);
        }
        else if (num == HTTPDB_DELETE)
        {
            // the collar saves to the HTTDB, so anaylye the command
            Analyse_HTTPDB_Delete(str);
        }
        else if ((num == ATTACHMENT_FORWARD) || (num == COMMAND_OBJECT))
        {
            if (llGetOwnerKey(id)==wearer)
            {
                if (nStartsWith(str,g_szOwnerChangeCollarInfo))
                    // an message from an object has been received, is it the cuff inform  about an owner change?
                {
                    if (g_nOnline)
                    {
                        // to properly handle onwerchnages we have to reset the httpdb so it reparses the seetings and the auth scripts
                        llOwnerSay("Setting in the owner system changed, reloading to syncronize!");
                        // now for resetting
                        ScriptReseter();
                    }
                    else
                    {
                        llOwnerSay("The owners of your cuffs changed, but will not be kept in sync as your collar is in offline modus!");
                    }
                }
                else if (nStartsWith(str,g_szRLVChangeToCollarInfo))
                    // an message from an object has been received, is it the cuff inform  about an RLV change?
                {
                    // to properly handle changes we run the command through the auth system
                    list lstCmdList = llParseString2List( str, [ "=" ], [] );
                    if (llList2String(lstCmdList,1)=="on")
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvon", llList2Key(lstCmdList,2));

                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvoff", llList2Key(lstCmdList,2));

                    }
                    g_nLastRLVChange=llGetUnixTime();
                }
                else if (nStartsWith(str,g_szCollarMenuInfo))
                    // an message from an object has been received, is it the cuff inform they want to see the collar menu
                {
                    // to properly handle changes we run the command through the auth system
                    list lstCmdList = llParseString2List( str, [ "=" ], [] );
                    if (llList2String(lstCmdList,1)=="on")
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "menu", llList2Key(lstCmdList,2));
                    }
                }
            }
        }

        // check for RLV changes from auth system
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            // check if a owner command comes through and if it is about disabling RLV
        {
            if (str == "rlvon" )
            {
                if(llGetUnixTime()>g_nLastRLVChange+10)
                {
                    llRegionSay(g_nCmdChannel,"occ|*|"+g_szRLVChangeFromCollarInfo+"=on="+(string)id+"|" + (string)wearer);
                }
            }
            else if (str == "refreshmenu")
            {
                buttons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, NULL_KEY);

            }
            else if (str == llToLower(submenu))
                // open Collar Cuff menu on chatcommand
            {
                DoMenu(id);
            }
            else if (str == g_szOpenCuffMenuCommand)
                // send command to cuffs to open menu command on chat menu received my the collar
            {
                // Send open command to cuff
                llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szCuffMenuCmd+"="+(string)id+"|" +(string)wearer);
            }
            else if ( (str=="runaway") && (num ==COMMAND_OWNER || id == wearer) )
            {
                if (g_nOnline)
                {
                    // owner right have been changed,, inform the cuffs
                    llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szOwnerChangeCmd+"=owner|" + (string)wearer);
                }
            }

            else if (num == COMMAND_OWNER)
                // check if a owner command comes through and if it is about enabling RLV
            {
                if (str == "rlvoff" )
                {
                    if(llGetUnixTime()>g_nLastRLVChange+10)
                    {
                        llRegionSay(g_nCmdChannel,"occ|*|"+g_szRLVChangeFromCollarInfo+"=off="+(string)id+"|" + (string)wearer);
                    }
                }
            }
        }
        else if (num == COMMAND_SAFEWORD )
            // safeword has been issued
        {
            llRegionSay(g_nCmdChannel,"occ|*|SAFEWORD|" + (string)wearer);
        }

        else if (num == DIALOG_RESPONSE)
        {
            if(id == g_keyDialogID)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                key AV = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                if (message == UPMENU)
                {
                    //give id the parent menu
                    llMessageLinked(LINK_THIS, SUBMENU, parentmenu, AV);
                }
                else if (~llListFindList(localbuttons, [message]))
                {
                    //we got a response for something we handle locally
                    if (message == "Upd. Colors")
                    {
                        // only send color values on demand
                        g_nRecolor=TRUE;
                        llMessageLinked(LINK_THIS, HTTPDB_REQUEST, g_szPrefix+"colorsettings", NULL_KEY);
                        DoMenu(AV);


                    }
                    else if (message == "Upd. Textures")
                    {
                        Debug("Bing");
                        // only send texture values on demand
                        g_nRetexture=TRUE;
                        llMessageLinked(LINK_THIS, HTTPDB_REQUEST, g_szPrefix+"textures", NULL_KEY);
                        DoMenu(AV);

                    }
                    else if (message == "Cuff Menu")
                    {
                        // Send open command to cuff
                        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szCuffMenuCmd+"="+(string)AV+"|" +(string)wearer);
                    }
                    else if (message == "(Un)Lock Cuffs")
                    {
                        // action 2
                        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szSwitchLockCmd+"="+(string)AV+"|" +(string)wearer);
                        DoMenu(AV);
                    }
                    else if (message == "Show/Hide")
                    {
                        // action 2
                        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szSwitchHideCmd+"|" +(string)wearer);
                        DoMenu(AV);
                    }
                }
                else if (message == "Sync On")
                {
                    // action 2
                    g_nUpdateActive=!g_nUpdateActive;
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, g_szPrefix+g_szUpdateActive_DBsave+"="+(string)g_nUpdateActive, NULL_KEY);
                    DoMenu(AV);
                }
                else if (message == "Sync Off")
                {
                    // action 2
                    g_nUpdateActive=!g_nUpdateActive;
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, g_szPrefix+g_szUpdateActive_DBsave+"="+(string)g_nUpdateActive, NULL_KEY);
                    DoMenu(AV);
                }
                else if (~llListFindList(buttons, [message]))
                {
                    //we got a submenu selection
                    llMessageLinked(LINK_THIS, SUBMENU, message, AV);
                }
            }
        }
    }

    changed (integer change)
    {
        if (change & CHANGED_OWNER)
        {
            wearer = llGetOwner();
        }
    }


}

state WrongVersion
{
    state_entry()
    {
        
    }
    
    on_rez(integer param)
    {
        llResetScript();
    }

}