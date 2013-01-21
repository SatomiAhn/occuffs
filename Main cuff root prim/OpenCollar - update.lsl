//on attach and on state_entry, http request for update

string g_szBaseurl = "http://collardata.appspot.com/updater/check?";
string g_szBETA_name=" BETA";

string g_szItemname;
string g_szVersion;

key g_keyHTTPprequest;
key g_keyBeta_HTTPrequest;

CheckForUpdate()
{
    list params = llParseString2List(llGetObjectDesc(), ["~"], []);
    g_szItemname = llList2String(params, 0);
    g_szVersion = llList2String(params, 1);
    if (g_szItemname == "" || g_szVersion == "")
    {
        llOwnerSay("You have changed my description.  Automatic updates are disabled.");
    }
    else if ((float)g_szVersion)
    {
        string url = g_szBaseurl;
        url += "object=" + llEscapeURL(g_szItemname);
        url += "&version=" + llEscapeURL(g_szVersion);
        g_keyHTTPprequest = llHTTPRequest(url, [HTTP_METHOD, "GET",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");
    }
}

default
{
    state_entry()
    {
        CheckForUpdate();
    }

    on_rez(integer param)
    {
        llResetScript();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id == g_keyHTTPprequest)
        {
            
            if (llGetListLength(llParseString2List(body, ["|"], [])) == 2)
            {
                llOwnerSay("There is a new version of me available.  An update should be delivered in 30 seconds or less.");
                //client side is done now.  server has queued the delivery,
                //and in-world giver will send us our object when it next
                //pings the server
            }
            else if ((body=="current")||(llGetSubString(body,0,2)=="NSO"))
            {
                float v=((float)g_szVersion)*10;
                v=v-llFloor(v);
                if (v>=0.20)
                {
                    string url = g_szBaseurl;
                    url += "object=" + llEscapeURL(g_szItemname + g_szBETA_name);
                    url += "&version=" + llEscapeURL(g_szVersion);
                    g_keyBeta_HTTPrequest = llHTTPRequest(url, [HTTP_METHOD, "GET",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");
                }
            }
        }
        else if (request_id == g_keyBeta_HTTPrequest)
        {
            if (llGetListLength(llParseString2List(body, ["|"], [])) == 2)
            {
                llOwnerSay("There is a new Beta version of me available.  An update should be delivered in 30 seconds or less.");
                //client side is done now.  server has queued the delivery,
                //and in-world giver will send us our object when it next
                //pings the server
            }
        }
        
    }
}
