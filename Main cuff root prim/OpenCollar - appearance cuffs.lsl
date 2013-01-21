//handle appearance menu
//handle saving position on detach, and restoring it on httpdb_response

// Changes for OpenCuffs:
// Removed local menus Pos and Rot
// Removed Restoring of Pos and Rot
// no nudging
// added chain texture menu
// added hide menu, hide can be disabled from defaultsettings

string submenu = "Appearance";
string parentmenu = "Main";

key g_keyMenuDialogID;
key g_keyChainDialogID;


integer g_nEnableHideMode=TRUE;
integer g_nHidden=FALSE;
string g_szHiddenTRUE="(*) Hidden";
string g_szHiddenFALSE="( ) Hidden";
string g_szHiddenToken="hide";
string g_szHideModeToken="hidemode";

// OpenCuffs: Chains instead of Pos or Rot
list localbuttons = ["Chains","Resync Cuffs"];
// name of buttons for the different chains in the chain  menu
list ChainMenuButtons = ["Thin Gold","OC Standard","Pink Chain","Black Chain","Rope"];
// LG command sequence to be send
list ChainMenuCommands = ["texture 6993a4d6-9155-d5cd-8434-a009b822d5a0 size 0.08 0.08 life 1 gravity 0.3","texture 245ea72d-bc79-fee3-a802-8e73c0f09473 size 0.07 0.07 life 1 gravity 0.3","texture 4c762c43-87d4-f6ba-55f4-f978b3cc4169 size 0.07 0.07 life 0.5 gravity 0.4 color 0.8 0.0 0.8","texture 4c762c43-87d4-f6ba-55f4-f978b3cc4169 size 0.07 0.07 life 0.5 gravity 0.4 color 0.1 0.1 0.1","texture 9de57a7d-b9d7-1b11-9be7-f0a42651755e size 0.07 0.07 life 0.5 gravity 0.3"];
// Currenlty used default for chains, has to be resubmitted on every rez of a cuff
integer ChainCurrent = -1;
// Token for saving
string chaintoken = "chaindefault";

list buttons;


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

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;


// Message Mapper Cuff Communication
integer    LM_CUFF_CMD        = -551001;
integer    LM_CUFF_ANIM    = -551002;
integer    LM_CUFF_CHAINTEXTURE = -551003;   // used as channel for linkedmessages - sending the choosen texture to the cuff

integer g_nCmdChannel    = -190890;        // command channel
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for

string    g_szModToken    = "rlac"; // valid token for this module
string g_szHideCmd="HideMe"; // Comand for Cuffs to change the colors
string g_szSwitchHideCmd="ShowHideCuffs";


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

//===============================================================================
//= parameters   :  integer nOffset        Offset to make sure we use really a unique channel
//=
//= description  : Function which calculates a unique channel number based on the owner key, to reduce lag
//=
//= returns      : Channel number to be used
//===============================================================================
integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)llGetOwner(),3,8)) + nOffset;
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
    llRegionSay(g_nCmdChannel + 1, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
    //llWhisper(0, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

ShowHideCuff()
{
    if (!g_nHidden)
    {
        llSetLinkAlpha(LINK_SET,1.0,ALL_SIDES);
        llMessageLinked(LINK_THIS,HTTPDB_DELETE,g_szHiddenToken,NULL_KEY);
    }
    else
    {
        llSetLinkAlpha(LINK_SET,0.0,ALL_SIDES);
        llMessageLinked(LINK_THIS,HTTPDB_SAVE,g_szHiddenToken+"=1",NULL_KEY);
    }

    // OpenCuffs: send show/hide to slave cuffs
    SendCmd("*",g_szHideCmd+"="+(string)g_nHidden,NULL_KEY);
}

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}


SendDefChainCommand()
{
    //    llWhisper(g_nLockGuardChannel,"lockguard "+(string)llGetKey()+" "+ChainTarget+" "+llList2String(ChainMenuCommands,ChainCurrent));
    string s;
    if ((ChainCurrent>=0) && (ChainCurrent<llGetListLength(ChainMenuButtons)))
    {
        s=llList2String(ChainMenuCommands,ChainCurrent);
    }
    else
    {
        s="";
    }
    llMessageLinked(LINK_SET,LM_CUFF_CHAINTEXTURE,s,NULL_KEY);

}

ChainMenu(key id)
{
    string prompt = "Choose the standard chains for the collar.\nUse 'Resend' to resend the chain standards if they got out of sync (due to lag or asyncronus attaching). \nCurrent Chain: ";
    if (ChainCurrent==-1)
    {
        prompt+="Default from cuff";
    }
    else if ((ChainCurrent>=0) && (ChainCurrent<llGetListLength(ChainMenuButtons)))
    {
        prompt+=llList2String(ChainMenuButtons,ChainCurrent);
    }
    else
        // THis should hopefully not happen
    {
        prompt+="Undefined, please choose a new standard texture!";
        ChainCurrent=-1;
    }
    list mybuttons = ChainMenuButtons+["Resend"];
    g_keyChainDialogID=Dialog(id, prompt, mybuttons, [UPMENU], 0);
}


DoMenu(key id)
{
    string prompt = "Pick an option.";
    list mybuttons = llListSort(localbuttons + buttons, 1, TRUE);
    if (g_nEnableHideMode)
    {
        if (g_nHidden)
        {
            mybuttons=g_szHiddenTRUE+mybuttons;
        }
        else
        {
            mybuttons=g_szHiddenFALSE+mybuttons;
        }
    }
    g_keyMenuDialogID=Dialog(id, prompt, mybuttons, [UPMENU],0);
}


string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

default
{
    state_entry()
    {
        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        string prefix = GetDBPrefix();

        // get unique channel numbers for the command and cuff channel, cuff channel wil be used for LG chains of cuffs as well
        g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset);


        if (prefix != "")
        {
            chaintoken = prefix + chaintoken;
            g_szHiddenToken=prefix + g_szHiddenToken;
        }
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        llSleep(3.0);
        SendDefChainCommand();

    }

    on_rez(integer param)
    {
        llResetScript();
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == SUBMENU && str == submenu)
        {
            //someone asked for our menu
            //give this plugin's menu to id
            DoMenu(id);
        }
        else if (num==LM_CUFF_CMD)
        {
            if (str==g_szSwitchHideCmd)
            {
                g_nHidden=!g_nHidden;
                ShowHideCuff();
            }
        }
        else if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == chaintoken)
            {
                ChainCurrent=(integer)value;
                SendDefChainCommand();
            }
            else if (token == g_szHiddenToken)
            {
                llSetLinkAlpha(LINK_SET,0.0,ALL_SIDES);
                g_nHidden=TRUE;
            }
            else if (token == g_szHideModeToken)
            {
                g_nEnableHideMode=(integer)value;
            }


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
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            if (str == "refreshmenu")
            {
                buttons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, NULL_KEY);
            }
        }
        else if (num == DIALOG_RESPONSE)
        {
            if(id == g_keyMenuDialogID)
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
                    //we got a response for something we handle locally
                    if (message == "Chains")
                    {
                        ChainMenu(AV);
                    }
                    //we got a response for something we handle locally
                    if (message == "Resync Cuffs")
                    {
                        SendDefChainCommand();
                        llMessageLinked(LINK_THIS,COMMAND_NOAUTH,"resend_appearance", AV);
                    }

                }
                else if (~llListFindList(buttons, [message]))
                {
                    //we got a submenu selection
                    llMessageLinked(LINK_THIS, SUBMENU, message, AV);
                }
                else if ((message==g_szHiddenTRUE)||(message==g_szHiddenFALSE))
                {
                    g_nHidden=!g_nHidden;
                    DoMenu(AV);
                    ShowHideCuff();
                }

            }
            if(id == g_keyChainDialogID)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                key AV = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);


                if (message == UPMENU)
                {
                    DoMenu(AV);
                    return;

                }
                else if (~llListFindList(ChainMenuButtons, [message]))
                {
                    ChainCurrent=llListFindList(ChainMenuButtons, [message]);
                    SendDefChainCommand();
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, chaintoken + "=" + (string)ChainCurrent, NULL_KEY);
                    ChainMenu(AV);
                }
                else if (message=="Resend")
                {
                    SendDefChainCommand();
                }
            }
        }
    }

}

