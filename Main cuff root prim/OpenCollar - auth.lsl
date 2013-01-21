//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

//save owner, secowners, and group key
//check credentials when messages come in on COMMAND_NOAUTH, send out message on appropriate channel
//reset self on owner change

key wearer;
//key owner;
//string ownername;
list owners;//strided list in form key,name
key group = "";
string groupname;
integer groupenabled = FALSE;
list secowners;//strided list in the form key,name
list blacklist;//list of blacklisted UUID
string tmpname; //used temporarily to store new owner or secowner name while retrieving key

string  wikiURL = "http://code.google.com/p/opencollar/wiki/UserDocumentation";
string parentmenu = "Main";
string submenu = "Owners";

string requesttype; //may be "owner" or "secowner" or "remsecowner"
key httpid;
key grouphttpid;

string ownerstoken = "owner";
string secownerstoken = "secowners";
string blacklisttoken = "blacklist";

//dialog handlers
key authmenuid;
key sensormenuid;

//added for attachment auth
integer interfaceChannel = -12587429;

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
integer COMMAND_BLACKLIST = 520;
// added so when the sub is locked out they can use postions 
integer COMMAND_WEARERLOCKEDOUT = 521;
//added for attachment auth (garvin)
integer ATTACHMENT_REQUEST = 600;
integer ATTACHMENT_RESPONSE = 601;

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

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

//this can change
integer WEARERLOCKOUT=620;

string UPMENU = "^";

string setowner = "Add Owner";
string setsecowner = "Add Secowner";
string setblacklist = "Add Blacklisted";
string setgroup = "Set Group";
string reset = "Reset All";
string remowner = "Rem Owner";
string remsecowner = "Rem Secowner";
string remblacklist = "Rem Blacklisted";
string unsetgroup = "Unset Group";
string listowners = "List Owners";
string setopenaccess = "SetOpenAccess";
string unsetopenaccess = "UnsetOpenAccess";
string setlimitrange = "LimitRange";
string unsetlimitrange = "UnLimitRange";

//request types
string ownerscan = "ownerscan";
string secownerscan = "secownerscan";
string blacklistscan = "blacklistscan";

integer openaccess; // 0: disabled, 1: openaccess
integer limitrange=1; // 0: disabled, 1: limited
integer wearerlockout;

integer remenu = FALSE;

key dialoger;//the person using the dialog.  needed in the sensor event when scanning for new owners to add

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

list AddUniquePerson(list container, key id, string name, string type)
{
    integer index = llListFindList(container, [(string)id]);
    if (index == -1)
    {   //owner is not already in list.  add him/her
        container += [(string)id, name];
    }
    else
    {   //owner is already in list.  just replace the name
        container = llListReplaceList(container, [name], index + 1, index + 1);
    }    
    
    if (id != wearer)
    {
        Notify(wearer, "Added " + name + " to " + type + ".", FALSE);
    }    
    
    Notify(id, "You have been added to the " + type + " list on " + llKey2Name(wearer) + "'s collar.\nFor help concerning the collar usage either say \"*help\" in chat or go to " + wikiURL + " .",FALSE);    
    return container;
}

NewPerson(key id, string name, string type)
{//adds new owner, secowner, or blacklisted, as determined by type.
    if (type == "owner")
    {        
        owners = AddUniquePerson(owners, id, name, requesttype);        
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, ownerstoken + "=" + llDumpList2String(owners, ","), "");
        //added for attachment interface to announce owners have changed
        llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");        
    }
    else if (type == "secowner")
    {   
        secowners = AddUniquePerson(secowners, id, name, requesttype);
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, secownerstoken + "=" + llDumpList2String(secowners, ","), "");
        //added for attachment interface to announce owners have changed
        llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");
    }    
    else if (type == "blacklist")
    {           
        blacklist = AddUniquePerson(blacklist, id, name, requesttype);
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, blacklisttoken + "=" + llDumpList2String(blacklist, ","), "");
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

Name2Key(string formattedname)
{   //formatted name is firstname+lastname
    httpid = llHTTPRequest("http://w-hat.com/name2key?terse=1&name=" + formattedname, [HTTP_METHOD, "GET"], "");
}

AuthMenu(key av)
{
    string prompt = "Pick an option.";
    list buttons = [setowner, setsecowner, setblacklist, remowner, remsecowner, remblacklist];    
      
    if (group=="") buttons += [setgroup];    //set group  
    else buttons += [unsetgroup];    //unset group
    
    if (openaccess) buttons += [unsetopenaccess];    //set open access
    else buttons += [setopenaccess];    //unset open access

    if (limitrange) buttons += [unsetlimitrange];    //set ranged
    else buttons += [setlimitrange];    //unset open ranged

    buttons += [reset];    
        
    //list owners
    buttons += [listowners];   

    authmenuid = Dialog(av, prompt, buttons, [UPMENU], 0);   
}

RemPersonMenu(key id, list people, string type)
{
    requesttype = type;
    string prompt = "Choose the person to remove.";
    list buttons;    
    //build a button list with the dances, and "More"
    //get number of secowners
    integer num= llGetListLength(people);
    integer n;
    for (n=1; n <= num/2; n = n + 1)
    {
        string name = llList2String(people, 2*n-1);
        if (name != "")
        {
          prompt += "\n" + (string)(n) + " - " + name;
          buttons += [(string)(n)];
         }
    }  
    buttons += ["Remove All"];

    sensormenuid = Dialog(id, prompt, buttons, [UPMENU], 0);    
}

integer in_range(key id) {
    if (limitrange) {
        integer range = 20;
        vector avpos = llList2Vector(llGetObjectDetails(id, [OBJECT_POS]), 0);
        if (llVecDist(llGetPos(), avpos) > range) {
            //llOwnerSay(llKey2Name(id) + " is not in range...");
            llDialog(id, "\n\nNot in range...", [], 298479);
            return FALSE;
            }
        else {
            //llOwnerSay(llKey2Name(id) + " In range...");
            return TRUE;
            }
        }
    else {
       return TRUE;
    }
}

integer UserAuth(string id, integer attachment)
{
    //Nan: the auth script in 3.3 had a separate UserAuthAttach function that was identical to this one except omitted 
    //the lockout block (the first "if").  I've added the "attachment" argument to this function in 3.4 to accomplish the same thing
    //Let's try not to duplicate code if we don't have to!
    integer auth;
    if (wearerlockout && id == (string)wearer && !attachment)
    {
        auth = COMMAND_WEARERLOCKEDOUT;
    }
    else if (~llListFindList(owners, [(string)id]))
    {
        auth = COMMAND_OWNER;
    }
    else if (llGetListLength(owners) == 0 && id == (string)wearer)
    {
        //if no owners set, then wearer's cmds have owner auth
        auth = COMMAND_OWNER;
    }
    else if (~llListFindList(blacklist, [(string)id]))
    {
        auth = COMMAND_BLACKLIST;
    }
    else if (~llListFindList(secowners, [(string)id]))
    {
        auth = COMMAND_SECOWNER;
    }
    else if (id == (string)wearer)
    {
        auth = COMMAND_WEARER;
    }
    else if (openaccess)
    {
        if (in_range((key)id))
            auth = COMMAND_GROUP;
        else
            auth = COMMAND_EVERYONE;
    }           
    else if (llSameGroup(id) && groupenabled && id != (string)wearer)
    {
        if (in_range((key)id))
            auth = COMMAND_GROUP;
        else
            auth = COMMAND_EVERYONE;
        
    } 
    else
    {
        auth = COMMAND_EVERYONE;
    }
    return auth;
}

integer ObjectAuth(key obj, key objownerkey)
{
    integer auth;
    if (~llListFindList(owners, [(string)objownerkey]))
    {
        auth = COMMAND_OWNER;
    }
    else if (llGetListLength(owners) == 0 && objownerkey == wearer)
    {
        //if no owners set, then wearer's objects' cmds have owner auth
        auth = COMMAND_OWNER;
    }
    else if (~llListFindList(secowners, [(string)objownerkey]))
    {
        auth = COMMAND_SECOWNER;          
    }
    else if ((string)llGetObjectDetails(obj, [OBJECT_GROUP]) == (string)group && objownerkey != wearer)
    {//meaning that the command came from an object set to our control group, and is not owned by the wearer
        auth = COMMAND_GROUP;        
    }    
    else if (openaccess && llListFindList(blacklist,[objownerkey])==-1)
    {
        auth = COMMAND_GROUP;
    }             
    else if (objownerkey == wearer)
    {
        auth = COMMAND_WEARER;
    }
    else
    {
        auth = COMMAND_EVERYONE;
    }            
    return auth;
}

list RemovePerson(list people, string name, string token, key cmdr)
{
    //where "people" is a 2-strided list in form key,name
    //looks for strides identified by "name", removes them if found, and returns the list
    //also handles notifications so as to reduce code duplication in the link message event
    debug("removing: " + name);
    //all our comparisons will be cast to lower case first
    name = llToLower(name);
    integer change = FALSE;
    integer n;
    key keyRemovedPerson;
    //loop from the top and work down, so we don't skip when we remove things
    for (n = llGetListLength(people) - 1; n >= 0; n = n - 2)
    {
        string thisname = llToLower(llList2String(people, n));
        debug("checking " + thisname);
        if (name == thisname)
        {   //remove name and key
            keyRemovedPerson=llList2String(people,n - 1);
            people = llDeleteSubList(people, n - 1, n);
            change = TRUE;
        }
    }
    
    if (change)
    {
        if (token == ownerstoken || token == secownerstoken)
        {// is it about owners?
            if (keyRemovedPerson!=wearer)
                // if it isnt the wearer, we are nice and notify them 
            {
                if (token == ownerstoken)
                {
                    Notify(keyRemovedPerson,"You have been removed as owner on the collar of " + llKey2Name(wearer) + ".",FALSE);
                }
                else
                {
                    Notify(keyRemovedPerson,"You have been removed as secowner on the collar of " + llKey2Name(wearer) + ".",FALSE);
                }
            }
            //whisper to attachments about owner and secowner changes
            llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");
        }
        //save to db
        if (llGetListLength(people)>0)
        {
            llMessageLinked(LINK_THIS, HTTPDB_SAVE, token + "=" + llDumpList2String(people, ","), "");
        }
        else
        {
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, token, "");
        }        
        Notify(cmdr, name + " removed from list.", TRUE);                  
    }    
    else
    {
        Notify(cmdr, "Error: '" + name + "' not in list.",FALSE);
    }
    return people;
}

integer isKey(string in) {
    if ((key)in) return TRUE;
    return FALSE;
}

integer OwnerCheck(key id)
{//checks whether id has owner auth.  returns TRUE if so, else notifies person that they don't have that power
 //used in menu processing for when a non owner clicks an owner-only button
    if (UserAuth(id, FALSE) == COMMAND_OWNER)
    {
        return TRUE;
    }
    else
    {
        Notify(id, "Sorry, only an owner can do that.", FALSE);
        return FALSE;
    }
}

NotifyInList(list StrideList, string ownertype)
{
    integer i;
    integer l=llGetListLength(StrideList);
    key k;
    string subname = llKey2Name(wearer);
    for (i = 0; i < l; i = i +2)
    {
        k = (key)llList2String(StrideList,i);
        if (k != wearer)
        {
            Notify(k,"You have been removed as " + ownertype + " on the collar of " + subname + ".",FALSE);
        }
    }
}


default
{
    state_entry()
    {   //until set otherwise, wearer is owner
        debug((string)llGetFreeMemory());
        wearer = llGetOwner();
        //added for attachment auth
        interfaceChannel = (integer)("0x" + llGetSubString(wearer,30,-1));
        if (interfaceChannel > 0) interfaceChannel = -interfaceChannel;

        llSleep(1.0);//giving time for others to reset before populating menu      
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            
    }
    
    link_message(integer sender, integer num, string str, key id)
    {  //authenticate messages on COMMAND_NOAUTH
        if (num == COMMAND_NOAUTH)
        {
            integer auth = UserAuth((string)id, FALSE);
            llMessageLinked(LINK_SET, auth, str, id);              
            debug("noauth: " + str + " from " + (string)id + " who has auth " + (string)auth);                 
        }
        else if (num == COMMAND_OBJECT)
        {   //on object sent a command, see if that object's owner is an owner or secowner in the collar
            //or if the object is set to the same group, and group is enabled in the collar
            //or if object is owned by wearer
            key objownerkey = llGetOwnerKey(id);   
            integer auth = ObjectAuth(id, objownerkey);
            llMessageLinked(LINK_SET, auth, str, id);              
            debug("noauth: " + str + " from object " + (string)id + " who has auth " + (string)auth);
        }
        else if (str == "settings" || str == "listowners")
        {   //say owner, secowners, group
            if (num == COMMAND_OWNER || id == wearer)
            {
            //Nan: This used to be in a function called SendOwnerSettings, but it was *only* called here, and 
            //that's a waste of     
            //Do Owners list            
            integer n;
            integer length = llGetListLength(owners);
            string ostring;
            for (n = 0; n < length; n = n + 2)
            {
                ostring += "\n" + llList2String(owners, n + 1) + " (" + llList2String(owners, n) + ")";
            }
            Notify(id, "Owners: " + ostring,FALSE);     
            
            //Do Secowners list
            length = llGetListLength(secowners);
            string sostring;
            for (n = 0; n < length; n = n + 2)
            {
                sostring += "\n" + llList2String(secowners, n + 1) + " (" + llList2String(secowners, n) + ")";
            }
            Notify(id, "Secowners: " + sostring,FALSE);                        
            length = llGetListLength(blacklist);
            string blstring;
            for (n = 0; n < length; n = n + 2)
            {
                blstring += "\n" + llList2String(blacklist, n + 1) + " (" + llList2String(blacklist, n) + ")";
            }
            Notify(id, "Black List: " + blstring,FALSE);                        
            Notify(id, "Group: " + groupname,FALSE);            
            Notify(id, "Group Key: " + (string)group,FALSE);     
            string val; if (openaccess) val="true"; else val="false";
            Notify(id, "Open Access: "+ val,FALSE);
            string valr; if (limitrange) valr="true"; else valr="false";
            Notify(id, "LimitRange: "+ valr,FALSE);
        }     
            else if (str == "listowners")
            {
                Notify(id, "Sorry, you are not allowed to see the owner list.",FALSE);
            }
        }
        else if (str == "runaway" || str == "reset")
        {
            // alllow only for the wearer
            if (num == COMMAND_OWNER || id == wearer)
            {    //IM Owners
                Notify(wearer, "Running away from all owners started, your owners wil now be notified!",FALSE);
                integer n;
                integer stop = llGetListLength(owners);
                for (n = 0; n < stop; n += 2)
                {
                    key owner = (key)llList2String(owners, n);
                    if (owner != wearer)
                    {
                        Notify(owner, llKey2Name(wearer) + " has run away!",FALSE);
                    }
                }
                Notify(wearer, "Runaway finished, the collar will now reset!",FALSE);
                // moved reset request from settings to here to allow noticifation of owners.
                llMessageLinked(LINK_THIS, COMMAND_OWNER, "resetscripts", id);
                llResetScript();
            }
        }
        else if ((str == "owners") && num >= COMMAND_OWNER && num <=COMMAND_WEARER)
        {   //give owner menu
            AuthMenu(id);    
        }     
        else if (num == COMMAND_OWNER)
        { //respond to messages to set or unset owner, group, or secowners.  only owner may do these things            
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            if (command == "owner")
            { //set a new owner.  use w-hat name2key service.  benefits: not case sensitive, and owner need not be present
                //if no owner at all specified:
                if (llList2String(params, 1) == "")
                {
                    AuthMenu(id);
                    return;
                }
                requesttype = "owner";
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //record owner name
                tmpname = llDumpList2String(params, " ");
                //sensor for the owner name to get the key or set the owner directly if it is the wearer
                if(llToLower(tmpname) == llToLower(llKey2Name(wearer)))
                {
                    NewPerson(wearer, tmpname, "owner");
                }
                else
                {
                    dialoger = id;
                    llSensor("","", AGENT, 20.0, PI);
                }
            }
            else if (command == "remowner")
            { //remove secowner, if in the list
                requesttype = "";//Nan: this used to be set to "remowner" but that NEVER gets filtered on elsewhere in the script.  Just clearing it now in case later filtering relies on it being cleared.  I hate this requesttype variable with a passion
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //name of person concerned
                tmpname = llDumpList2String(params, " ");
                if (tmpname=="")
                {
                    RemPersonMenu(id, owners, "remowner");
                }
                else if(llToLower(tmpname) == "remove all")
                {
                    Notify(id, "Removing of all owners started!",TRUE);

                    NotifyInList(owners, ownerstoken);
                    
                    owners = [];
                    llMessageLinked(LINK_THIS, HTTPDB_DELETE, ownerstoken, "");
                    Notify(id, "Everybody was removed from the owner list!",TRUE);
                }
                else
                {
                    owners = RemovePerson(owners, tmpname, ownerstoken, id);
                }                                                         
            }            
            else if (command == "secowner")
            { //set a new secowner
                requesttype = "secowner";
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //record owner name
                tmpname = llDumpList2String(params, " ");
                if (tmpname=="")
                {
                    requesttype = secownerscan;
                    dialoger = id;                    
                    llSensor("", "", AGENT, 10.0, PI);
                }
                else if (llGetListLength(secowners) == 20)
                {
                    Notify(id, "The maximum of 10 secowners is reached, please clean up or use SetGroup",FALSE);
                }
                else
                {//sensor for the owner name to get the key or set the owner directly if it is the wearer
                    if(llToLower(tmpname) == llToLower(llKey2Name(wearer)))
                    {
                        NewPerson(wearer, tmpname, "secowner");
                    }
                    else
                    {
                        dialoger = id;                        
                        llSensor("","", AGENT, 20.0, PI);
                    }
                }             
            }
            else if (command == "remsecowner")
            { //remove secowner, if in the list
                requesttype = "";
                //requesttype = "remsecowner";//Nan: we never parse on requesttype == remsecowner, so this makes little sense
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //name of person concerned
                tmpname = llDumpList2String(params, " ");
                if (tmpname=="")
                {
                    RemPersonMenu(id, secowners, "remsecowner");
                }
                else if(llToLower(tmpname) == "remove all")
                {
                    Notify(id, "Removing of all secowners started!",TRUE);

                    NotifyInList(secowners, secownerstoken);

                    secowners = [];
                    llMessageLinked(LINK_THIS, HTTPDB_DELETE, "secowners", "");
                    Notify(id, "Everybody was removed from the secondary owner list!",TRUE);
                }
                else
                {
                    secowners = RemovePerson(secowners, tmpname, secownerstoken, id);
                }                                                     
            }
            else if (command == "blacklist")
            { //blacklist an avatar
                requesttype = "blacklist";
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //record blacklisted name
                tmpname = llDumpList2String(params, " ");
                if (tmpname=="")
                {
                    requesttype = blacklistscan;
                    dialoger = id;                    
                    llSensor("", "", AGENT, 10.0, PI);
                }
                else if (llGetListLength(blacklist) == 20)
                {
                    Notify(id, "The maximum of 10 blacklisted is reached, please clean up.",FALSE);
                }
                else
                {   //sensor for the blacklisted name to get the key
                    dialoger = id;                
                    llSensor("","", AGENT, 20.0, PI);
                }             
            }
            else if (command == "remblacklist")
            { //remove blacklisted, if in the list
                requesttype = "";
                //requesttype = "remblacklist";//Nan: we never filter on requesttype == "remblacklist", so this makes no sense.
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //name of person concerned
                tmpname = llDumpList2String(params, " ");
                if (tmpname=="")
                {
                    RemPersonMenu(id, blacklist, "remblacklist");
                }
                else if(llToLower(tmpname) == "remove all")
                {
                    blacklist = [];
                    llMessageLinked(LINK_THIS, HTTPDB_DELETE, blacklisttoken, "");
                    Notify(id, "Everybody was removed from black list!", TRUE);
                }
                else
                {
                    blacklist = RemovePerson(blacklist, tmpname, blacklisttoken, id);          
                }                                               
            }
            else if (command == "setgroup")
            {
                requesttype = "group";
                //if no arguments given, use current group, else use key provided
                if (isKey(llList2String(params, 1)))
                {
                    group = (key)llList2String(params, 1);
                }
                else
                {
                    //record current group key
                    group = (key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0);                    
                }
                
                if (group != "")
                {
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "group=" + (string)group, "");           
                    groupenabled = TRUE;
                    dialoger = id;
                    //get group name from 
                    grouphttpid = llHTTPRequest("http://groupname.scriptacademy.org/" + (string)group, [HTTP_METHOD, "GET"], "");
                }
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
            }
            else if (command == "setgroupname")
            {
                groupname = llDumpList2String(llList2List(params, 1, -1), " ");
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "groupname=" + groupname, "");
            }
            else if (command == "unsetgroup")
            {
                group = "";
                groupname = "";
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "group", "");                          
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "groupname", "");                
                groupenabled = FALSE;
                Notify(id, "Group unset.", FALSE);
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
                //added for attachment interface to announce owners have changed
                llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");
            }
            else if (command == "setopenaccess")
            {
                openaccess = TRUE;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "openaccess=" + (string) openaccess, "");
                Notify(id, "Open access set.", FALSE);
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
            }
            else if (command == "unsetopenaccess")
            {
                openaccess = FALSE;
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "openaccess", "");
                Notify(id, "Open access unset.", FALSE);
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
                //added for attachment interface to announce owners have changed
                llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");
            }
            else if (command == "setlimitrange")
            {
                limitrange = TRUE;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "limitrange=" + (string) limitrange, "");
                Notify(id, "Range limited set.", FALSE);
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
            }
            else if (command == "unsetlimitrange")
            {
                limitrange = FALSE;
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "limitrange", "");
                Notify(id, "Range limited unset.", FALSE);
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
            }
            else if (command == "reset")
            {
                llResetScript();      
            }
        }
        else if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == ownerstoken)
            {
                owners = llParseString2List(value, [","], []);
            }
            else if (token == "group")
            {
                group = (key)value;
                //check to see if the object's group is set properly
                if (group != "")
                {
                    if ((key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0) == group)
                    {
                        groupenabled = TRUE;
                    }
                    else
                    {
                        groupenabled = FALSE;
                    }
                }
                else
                {
                    groupenabled = FALSE;
                }                        
            }
            else if (token == "groupname")
            {
                groupname = value;
            }
            else if (token == "openaccess")
            {
                openaccess = (integer)value;
            }
            else if (token == "limitrange")
            {
                limitrange = (integer)value;
            }
            else if (token == "secowners")
            {
                secowners = llParseString2List(value, [","], [""]);
            }
            else if (token == "blacklist")
            {
                blacklist = llParseString2List(value, [","], [""]);
            }
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, "");
        }
        else if (num == SUBMENU && str == submenu)
        {
            AuthMenu(id);
        }
        else if (num == COMMAND_SAFEWORD)
        {
            string subName = llKey2Name(wearer);
            string subFirstName = llList2String(llParseString2List(subName, [" "], []), 0);
            integer n;
            integer stop = llGetListLength(owners);
            for (n = 0; n < stop; n += 2)
            {
                key owner = (key)llList2String(owners, n);
                Notify(owner, "Your sub " + subName + " has used the safeword. Please check on " + subFirstName +"'s well-being and if further care is required.",FALSE);                
            }
            //added for attachment interface (Garvin)
            llWhisper(interfaceChannel, "CollarCommand|499|safeword");
        }
        //added for attachment auth (Garvin)
        else if (num == ATTACHMENT_REQUEST)
        {
            integer auth = UserAuth((string)id, TRUE);
            llMessageLinked(LINK_THIS, ATTACHMENT_RESPONSE, (string)auth, id);
        }
        else if (num == WEARERLOCKOUT)
        {
            if (str == "on")
            {
                wearerlockout=TRUE;
                debug("lockouton");
            }
            else if (str == "off")
            {
                wearerlockout=FALSE;
                debug("lockoutoff");
            }
        }
        else if (num == DIALOG_RESPONSE)
        {
            if (llListFindList([authmenuid, sensormenuid], [id]) != -1)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(menuparams, 0);          
                string message = llList2String(menuparams, 1);                                         
                integer page = (integer)llList2String(menuparams, 2);                
                if (id == authmenuid)
                {
                    //authmenuid responds to setowner, setsecowner, setblacklist, remowner, remsecowner, remblacklist
                    //setgroup, unsetgroup, setopenaccess, unsetopenaccess                
                    if (message == UPMENU)
                    {
                        llMessageLinked(LINK_THIS, SUBMENU, parentmenu, av);
                    }
                    else if (message == setowner)
                    {   
                        //if(~llListFindList(owners, [av]))
                        if (OwnerCheck(av))
                        {
                            requesttype = ownerscan;
                            dialoger = av;                
                            llSensor("", "", AGENT, 10.0, PI);
                        }
                    }
                    else if (message == setsecowner)
                    {   
                        if (OwnerCheck(av))
                        {
                            requesttype = secownerscan;
                            dialoger = av;                
                            llSensor("", "", AGENT, 10.0, PI);
                        }
                    }
                    else if (message == setblacklist)
                    {
                        if (OwnerCheck(av))
                        {
                            requesttype = blacklistscan;
                            dialoger = av;                
                            llSensor("", "", AGENT, 10.0, PI);
                        }
                    }       
                    else if (message == remowner)
                    {
                        if (OwnerCheck(av))
                        {
                            RemPersonMenu(av, owners, "remowner");
                        }
                    }        
                    else if (message == remsecowner)
                    {   //popup list of secowner if owner clicked
                        if (OwnerCheck(av))
                        {
                            RemPersonMenu(av, secowners, "remsecowner");
                        }
                    }
                    else if (message == remblacklist)
                    {   //popup list of secowner if owner clicked
                        if (OwnerCheck(av))
                        {
                            RemPersonMenu(av, blacklist, "remblacklist");
                        }
                    }     
                    else if (message == setgroup)
                    {
                        remenu = TRUE;
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "setgroup", av);
                    }       
                    else if (message == unsetgroup)
                    {
                        remenu = TRUE;
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unsetgroup", av);      
                    }
                    else if (message == setopenaccess)
                    {
                        remenu = TRUE;
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "setopenaccess", av);
                    }
                    else if (message == unsetopenaccess)
                    {
                        remenu = TRUE;
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unsetopenaccess", av);
                    }
                    else if (message == setlimitrange)
                    {
                        remenu = TRUE;
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "setlimitrange", av);
                    }
                    else if (message == unsetlimitrange)
                    {
                        remenu = TRUE;
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unsetlimitrange", av);
                    }
                    else if (message == reset)
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "reset", av);            
                    }
                    else if (message == listowners)
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "listowners", av);
                        AuthMenu(av);
                    }    
                }
                else if (id == sensormenuid)
                {    
                    if ((integer)message)
                    {
                        if (OwnerCheck(av))
                        {
                            //build a chat command to send to remove the person
                            string cmd = requesttype;
                            //convert the menu button number to a name
                            if (requesttype == "remowner")
                            {
                                cmd += " " + llList2String(owners, (integer)message*2 - 1);
                            }
                            else if(requesttype == "remsecowner")
                            {
                                cmd += " " + llList2String(secowners, (integer)message*2 - 1);
                            }
                            else if(requesttype == "remblacklist")
                            {
                                cmd += " " + llList2String(blacklist, (integer)message*2 - 1);
                            }
                            llMessageLinked(LINK_THIS, COMMAND_OWNER, cmd, av);
                        }
                    }
                    else if (message == "Remove All")
                    {
                        if (OwnerCheck(av))
                        {
                            //requesttype should be remowner, remsecowner, or remblacklist
                            llMessageLinked(LINK_SET, COMMAND_OWNER, requesttype + " Remove All", av);
                        }
                    }
                    else if(requesttype == ownerscan)
                    {
                        llMessageLinked(LINK_THIS, COMMAND_OWNER, "owner " + message, av);
                    }
                    else if(requesttype == secownerscan)
                    {
                        llMessageLinked(LINK_THIS, COMMAND_OWNER, "secowner " + message, av);
                    }
                    else if(requesttype == blacklistscan)
                    {
                        llMessageLinked(LINK_THIS, COMMAND_OWNER, "blacklist " + message, av);
                    }
                   AuthMenu(av); 
                }                                
            }

        }
    }    
    
    sensor(integer num_detected)
    {
        if(requesttype == "owner" || requesttype == "secowner" || requesttype == "blacklist")
        {
            integer i;
            integer foundAvi = FALSE;
            for (i = 0; i < num_detected; i++)
            {//see if sensor picked up person with name we were given in chat command (tmpname).  case insensitive
                if(llToLower(tmpname) == llToLower(llDetectedName(i)))
                {
                    foundAvi = TRUE;
                    NewPerson(llDetectedKey(i), llDetectedName(i), requesttype);
                    i = num_detected;//a clever way to jump out of the loop.  perhaps too clever?
                }
            }
            if(!foundAvi)
            {
                if(tmpname == llKey2Name(wearer))
                {
                    NewPerson(wearer, llKey2Name(wearer), requesttype);
                }
                else
                {
                    list temp = llParseString2List(tmpname, [" "], []);
                    Name2Key(llDumpList2String(temp, "+"));
                }
            }
        }
        else if(requesttype == ownerscan || requesttype == secownerscan || requesttype == blacklistscan)
        {
            list buttons;
            string name;
            integer i;
            
            for(i = 0; i < num_detected; i++)
            {
                name = llDetectedName(i);
                buttons += [name];
            }
            //add wearer if not already in button list
            name = llKey2Name(wearer);
            if (llListFindList(buttons, [name]) == -1)
            {
                buttons = [name] + buttons;
            }
            string text = "Select who you would like to add.\nIf the one you want to add does not show, move closer and repeat or use the chat command.";
            sensormenuid = Dialog(dialoger, text, buttons, [UPMENU], 0);
        }
    }
    
    no_sensor()
    {
        if(requesttype == "owner" || requesttype == "secowner" || requesttype == "blacklist")
        {
            //reformat name with + in place of spaces
            Name2Key(llDumpList2String(llParseString2List(tmpname, [" "], []), "+"));
        }
        else if(requesttype == ownerscan || requesttype == secownerscan || requesttype == blacklistscan)
        {
            Notify(dialoger, "Nobody is in 10m range to be shown, either move closer or use the chat command to add someone who is not with you at this moment or offline.",FALSE);
        }
    }
    
    on_rez(integer param)
    {
        llResetScript();
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            wearer = llGetOwner();
        }
    }
    
    http_response(key id, integer status, list meta, string body)
    {
        if (id == httpid)
        {   //here's where we add owners or secowners, after getting their keys
            if (status == 200)
            {
                debug(body);
                if (isKey(body))
                {
                    NewPerson((key)body, tmpname, requesttype);//requesttype will be owner, secowner, or blacklist
                }
                else
                {
                    Notify(dialoger, "Error: unable to retrieve key for '" + tmpname + "'.", FALSE);
                }
            }
        }
        else if (id == grouphttpid)
        {
            if (status == 200)
            {
                groupname = body;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "groupname=" + groupname, "");                
                if (groupname == "X")
                {
                    Notify(dialoger, "Group set to (group name hidden)", FALSE);
                }
                else
                {
                    Notify(dialoger, "Group set to " + groupname, FALSE);
                }                
            }
        }
    }
}