//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//color

//set textures by uuid, and save uuids instead of texture names to DB

//on getting texture command, give menu to choose which element, followed by menu to pick texture


// Changes for OpenCuffs
// Globla variable for channel and commnad added
// function to send command to slave funtion added
// Sending of messages to slave cuff in Listener added

list elements;
string currentelement = "";
list textures;
string parentmenu = "Appearance";
string submenu = "Textures";
string dbtoken = "textures";

integer length;
list buttons;
list new_buttons;

//dialog handles
key elementid;
key textureid;

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

key wearer;


integer g_nCmdChannel    = -190890;
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for

string    g_szModToken    = "rlac"; // valid token for this module
string g_szTextureChangeCmd="TextureChanged"; // Comand for Cuffs to change the texture

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
    llRegionSay(g_nCmdChannel + 1, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
    //llWhisper(0, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

// End of Changes for OpenCuffs functions


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

TextureMenu(key id, integer page)
{
    //create a list
    list buttons;
    string prompt = "Choose the texture to apply.";
    //build a button list with the dances, and "More"
    //get number of anims
    integer num_textures = llGetInventoryNumber(INVENTORY_TEXTURE);
    integer n;
    for (n=0;n<num_textures;n++)
    {
        string name = llGetInventoryName(INVENTORY_TEXTURE,n);
        buttons += [name];
    }
    textureid = Dialog(id, prompt, buttons, [UPMENU], page);
}

ElementMenu(key av)
{
    string prompt = "Pick which part of the collar you would like to retexture";
    buttons = llListSort(elements, 1, TRUE);
    elementid = Dialog(av, prompt, buttons, [UPMENU], 0);
}

string ElementType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //prim desc will be elementtype~notexture(maybe)
    list params = llParseString2List(desc, ["~"], []);
    if ((~(integer)llListFindList(params, ["notexture"])) || desc == "" || desc == " " || desc == "(No Description)")
    {
        return "notexture";
    }
    else
    {
        return llList2String(llParseString2List(desc, ["~"], []), 0);
    }
}

LoadTextureSettings()
{
    //loop through links, setting each's color according to entry in textures list
    integer n;
    integer linkcount = llGetNumberOfPrims();
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementType(n);
        integer index = llListFindList(textures, [element]);
        string tex = llList2String(textures, index + 1);
        //llOwnerSay(llList2String(textures, index + 1));
        if (index != -1)
        {
            //set link to new texture
            llSetLinkTexture(n, tex, ALL_SIDES);
        }
    }
}

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

SetElementTexture(string element, key tex)
{
    integer nElementFound=FALSE; // making sure we store only needed texture values
    integer nSaveSettings=FALSE; // making sure we store only when really needed
    integer n;
    integer linkcount = llGetNumberOfPrims();
    for (n = 2; n <= linkcount; n++)
    {
        string thiselement = ElementType(n);
        if (thiselement == element)
        {
            nElementFound=TRUE; // the element is there, so we need to save the value later
            //set link to new texture
            llSetLinkTexture(n, tex, ALL_SIDES);
        }
    }

    if (!nElementFound)
        return;

    //change the textures list entry for the current element
    integer index;
    index = llListFindList(textures, [element]);
    if (index == -1)
    {
        textures += [currentelement, tex];
        nSaveSettings=TRUE;
    }
    else
    {
        if (llList2Key(textures,index+1)!=tex)
        {
            nSaveSettings=TRUE;
            textures = llListReplaceList(textures, [tex], index + 1, index + 1);
        }
    }
    //save to httpdb
    if (nSaveSettings)
    {
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(textures, "~"), NULL_KEY);
    }
}

default
{
    state_entry()
    {
        wearer = llGetOwner();
        
        g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset); // get the owner defined channel
        
        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        string prefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (prefix != "")
        {
            dbtoken = prefix + dbtoken;
        }

        //loop through non-root prims, build element list
        integer n;
        integer linkcount = llGetNumberOfPrims();

        //root prim is 1, so start at 2
        for (n = 2; n <= linkcount; n++)
        {
            string element = ElementType(n);
            if (!(~llListFindList(elements, [element])) && element != "notexture")
            {
                elements += [element];
                //llSay(0, "added " + element + " to elements");
            }
        }
        
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);

    }

    link_message(integer sender, integer auth, string str, key id)
    {
        //owner, secowner, group, and wearer may currently change colors
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER && str == "textures")
        {
            if (id!=wearer && auth!=COMMAND_OWNER)
            {
                Notify(id,"You are not allowed to change the textures.", FALSE);
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else
            {
                currentelement = "";
                ElementMenu(id);
            }
        }
        else if (str == "reset" && (auth == COMMAND_OWNER || auth == COMMAND_WEARER))
        {
            //clear saved settings
            //llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
            llResetScript();
        }
        else if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            if (str == "settings")
            {
                Notify(id, "Texture Settings: " + llDumpList2String(textures, ","), FALSE);
            }
            else if (startswith(str, "settexture"))
            {
                if (id!=wearer && auth!=COMMAND_OWNER)
                {
                    Notify(id,"You are not allowed to change the textures.", FALSE);
                }
                else
                {
                    list params = llParseString2List(str, [" "], []);
                    string element = llList2String(params, 1);
                    key tex = (key)llList2String(params, 2);
                    SetElementTexture(element, tex);
                }
            }
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == dbtoken)
            {
                textures = llParseString2List(value, ["~"], []);
                //llInstantMessage(llGetOwner(), "Loaded texture settings.");
                LoadTextureSettings();
            }
        }
        else if (auth == MENUNAME_REQUEST)
        {
            if (str == parentmenu)
            {
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            }
        }
        else if (auth == SUBMENU && str == submenu)
        {
            if (str == submenu)
            {
                //we don't know the authority of the menu requester, so send a message through the auth system
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "textures", id);
            }
        }
        else if (auth == DIALOG_RESPONSE)
        {
            if (llListFindList([elementid, textureid], [id]) != -1)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);

                if (id == elementid)
                {//they just chose an element, now choose a texture
                    if (message == UPMENU)
                    {
                        //main menu
                        llMessageLinked(LINK_THIS, SUBMENU, parentmenu, av);
                    }
                    else
                    {
                        //we just got the element name
                        currentelement = message;
                        TextureMenu(av, page);
                    }
                }
                else if (id == textureid)
                {
                    if (message == UPMENU)
                    {
                        currentelement = "";
                        ElementMenu(av);
                    }
                    else
                    {
                        //got a texture name
                        string tex = (string)llGetInventoryKey(message);
                        //loop through links, setting texture if element type matches what we're changing
                        //root prim is 1, so start at 2
                        SetElementTexture(currentelement, (key)tex);

                        // OpenCuffs: send texturechange to slave cuffs
                        SendCmd("*",g_szTextureChangeCmd+"="+currentelement+"="+tex,NULL_KEY);
            
                        TextureMenu(av, page);
                    }
                }
            }
        }
    }

    on_rez(integer param)
    {
        llResetScript();
    }
}
