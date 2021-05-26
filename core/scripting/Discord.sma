#include <amxmodx>
#include <grip>
#include <discord>

#pragma semicolon 1

static const params[][] = 
{
    "username",
    "avatar_url",
    "content",
    "color",
    "title_url",
    "title",
    "author_name",
    "author_avatar",
    "author_url",
    "fields",
    "timestamp",
    "footer_text",
    "footer_image",
    "embed_thumb",
    "embed_image"
};

new Trie:webHooks,
    Trie:message,
    GripRequestOptions:requestOptions;

public plugin_init()
{
    register_plugin("[Discord] Core", "1.0", "JDW");

    requestOptions = grip_create_default_options();
    grip_options_add_header(requestOptions, "Content-Type", "application/json");

    new SMCParser:parser = SMC_CreateParser();

    if (parser == Invalid_SMCParser)
        set_fail_state("Error creating parser descriptor");

    SMC_SetParseStart(parser, "OnParseStart");
    SMC_SetReaders(parser, "OnKeyValue");
    SMC_SetParseEnd(parser, "OnParseEnd");

    new path[PLATFORM_MAX_PATH];
    get_localinfo("amxx_configsdir", path, PLATFORM_MAX_PATH);
    add(path, PLATFORM_MAX_PATH, "/discord.cfg");

    if(!file_exists(path))
        set_fail_state("File(%s) not found", path);

    SMC_ParseFile(parser, path);

    SMC_DestroyParser(parser);
}

public plugin_natives()
{
    register_native("Discord_StartMessage", "Native_StartMessage");
    register_native("Discord_CancelMessage", "Native_CancelMessage");
    register_native("Discord_SendMessage", "Native_SendMessage");

    register_native("Discord_SetStringParam", "Native_SetStringParam");
    register_native("Discord_SetCellParam", "Native_SetCellParam");
    register_native("Discord_AddField", "Native_AddField");

    register_native("Discord_WebHookExists", "Native_WebHookExists");
}

public OnParseStart(SMCParser:handle, any:data)
{
    if (webHooks == Invalid_Trie)
        webHooks = TrieCreate();
}

public SMCResult:OnKeyValue(SMCParser:handle, const key[], const value[], any:data)
{
    if (webHooks != Invalid_Trie)
    {
        TrieSetString(webHooks, key, value);

        return SMCParse_Continue;
    }

    return SMCParse_HaltFail;
}

public OnParseEnd(SMCParser:handle, bool:halted, bool:failed, any:data)
{
    if (webHooks == Invalid_Trie || failed)
        set_fail_state("Error during config parsing");
}

bool:ValidMessage()
{
    if (message != Invalid_Trie)
        return true;

    log_error(AMX_ERR_NATIVE, "No one message in prepare progress");

    return false;
}

CancelMessage()
{
    if (message != Invalid_Trie)
        TrieDestroy(message);
}

public OnNextTick(data)
{
    CancelMessage();
}

BuildMap(param, param_string[] = "", param_string2[] = "", short = false, param_num = 0)
{  
    switch(param)
    {
        case USERNAME: TrieSetString(message, params[USERNAME], param_string);
        case AVATAR_URL: TrieSetString(message, params[AVATAR_URL], param_string);
        case CONTENT: TrieSetString(message, params[CONTENT], param_string);
        case COLOR: TrieSetCell(message, params[COLOR], param_num);
        case TITLE_URL: TrieSetString(message, params[TITLE_URL], param_string);
        case TITLE: TrieSetString(message, params[TITLE], param_string);
        case AUTHOR_NAME: TrieSetString(message, params[AUTHOR_NAME], param_string);
        case AUTHOR_AVATAR: TrieSetString(message, params[AUTHOR_AVATAR], param_string);
        case AUTHOR_URL: TrieSetString(message, params[AUTHOR_URL], param_string);
        case TIMESTAMP: TrieSetCell(message, params[TIMESTAMP], param_num);
        case FOOTER_TEXT: TrieSetString(message, params[FOOTER_TEXT], param_string);
        case FOOTER_IMAGE: TrieSetString(message, params[FOOTER_IMAGE], param_string);
        case EMBED_THUMB: TrieSetString(message, params[EMBED_THUMB], param_string);
        case EMBED_IMAGE: TrieSetString(message, params[EMBED_IMAGE], param_string);
    }

    if (param == FIELDS)
    {
        new Trie:collection = TrieCreate();
        new Array:array;

        if (!TrieGetCell(message, params[FIELDS], array))
            array = ArrayCreate();

        TrieSetString(collection, "title", param_string);
        TrieSetString(collection, "text", param_string2);
        TrieSetCell(collection, "short", short);

        ArrayPushCell(array, collection);
        TrieSetCell(message, params[FIELDS], array);
    }
}

SendMessage(webhook[])
{
    new GripJSONValue:collection = grip_json_init_object();

    new buffer[1024], number, GripJSONValue:tempObject, bool:mark;

    if (TrieGetString(message, "username", buffer, sizeof buffer))
    {
        grip_json_object_set_string(collection, "username", buffer);
    }

    if (TrieGetString(message, "avatar_url", buffer, sizeof buffer))
    {
        grip_json_object_set_string(collection, "avatar_url", buffer);
    }

    if (TrieGetString(message, "content", buffer, sizeof buffer))
    {
        grip_json_object_set_string(collection, "content", buffer);
    }

    new GripJSONValue:arrayEmbeds = grip_json_init_array();
    new GripJSONValue:objectEmbeds = grip_json_init_object();

    if (TrieGetCell(message, "color", number))
    {
        grip_json_object_set_number(objectEmbeds, "color", number);
    }

    if (TrieGetString(message, "title_url", buffer, sizeof buffer))
    {
        grip_json_object_set_string(objectEmbeds, "title_url", buffer);
    }

    if (TrieGetString(message, "title", buffer, sizeof buffer))
    {
        grip_json_object_set_string(objectEmbeds, "title", buffer);
    }

    if (TrieGetCell(message, "timestamp", number))
    {
        format_time(buffer, sizeof buffer, "%Y-%m-%dT%H:%M:%SZ", number);
        grip_json_object_set_string(objectEmbeds, "timestamp", buffer);
    }

    if (TrieGetString(message, "embed_thumb", buffer, sizeof buffer))
    {
        tempObject = grip_json_init_object();
        grip_json_object_set_string(tempObject, "url", buffer);
        grip_json_object_set_value(objectEmbeds, "thumbnail", tempObject);
        grip_destroy_json_value(tempObject);
    }

    if (TrieGetString(message, "embed_image", buffer, sizeof buffer))
    {
        tempObject = grip_json_init_object();
        grip_json_object_set_string(tempObject, "url", buffer);
        grip_json_object_set_value(objectEmbeds, "image", tempObject);
        grip_destroy_json_value(tempObject);
    }

    tempObject = grip_json_init_object();

    if (TrieGetString(message, "author_name", buffer, sizeof buffer))
    {
        grip_json_object_set_string(tempObject, "name", buffer);
        mark = true;
    }

    if (TrieGetString(message, "author_avatar", buffer, sizeof buffer))
    {
        grip_json_object_set_string(tempObject, "icon_url", buffer);
        mark = true;
    }

    if (TrieGetString(message, "author_url", buffer, sizeof buffer))
    {
        grip_json_object_set_string(tempObject, "url", buffer);
        mark = true;
    }

    if (mark)
    {
        grip_json_object_set_value(objectEmbeds, "author", tempObject);
        mark = false;
    }

    grip_destroy_json_value(tempObject);

    tempObject = grip_json_init_object();

    if (TrieGetString(message, "footer_text", buffer, sizeof buffer))
    {
        grip_json_object_set_string(tempObject, "text", buffer);
        mark = true;
    }

    if (TrieGetString(message, "footer_image", buffer, sizeof buffer))
    {
        grip_json_object_set_string(tempObject, "icon_url", buffer);
        mark = true;
    }

    if (mark)
    {
        grip_json_object_set_value(objectEmbeds, "footer", tempObject);
        mark = false;
    }

    grip_destroy_json_value(tempObject);
    
    new Array:array;

    if (TrieGetCell(message, "fields", array))
    {
        new GripJSONValue:fields = grip_json_init_array();
        new Trie:map;

        for (new i; i < ArraySize(array); i++)
        {
            map = ArrayGetCell(array, i);
            tempObject = grip_json_init_object();

            if (TrieGetString(map, "title", buffer, sizeof buffer))
            {
                grip_json_object_set_string(tempObject, "name", buffer);
            }

            if (TrieGetString(map, "text", buffer, sizeof buffer))
            {
                grip_json_object_set_string(tempObject, "value", buffer);
            }

            if (TrieGetCell(map, "short", mark))
            {
                grip_json_object_set_bool(tempObject, "inline", mark);
            }

            grip_json_array_append_value(fields, tempObject);
            grip_destroy_json_value(tempObject);
            TrieDestroy(map);
        }

        ArrayDestroy(array);

        grip_json_object_set_value(objectEmbeds, "fields", fields);
        grip_destroy_json_value(fields);    
    }

    grip_json_array_append_value(arrayEmbeds, objectEmbeds);
    grip_json_object_set_value(collection, "embeds", arrayEmbeds);

    new GripBody:body = grip_body_from_json(collection);

    if (body > Invalid_GripBody && TrieGetString(webHooks, webhook, buffer, sizeof buffer))
    {
        grip_request(buffer, body, GripRequestTypePost, "HandleRequest", requestOptions);
    }

    grip_destroy_body(body);

    grip_destroy_json_value(objectEmbeds);
    grip_destroy_json_value(arrayEmbeds);
    grip_destroy_json_value(collection);
}

public HandleRequest() {}

public Native_StartMessage(plugin_id, argc)
{
    if (message != Invalid_Trie)
    {
        log_error(AMX_ERR_NATIVE, "Couldn't start another message: currently we processing another message.");
        return false;
    }

    message = TrieCreate();
    RequestFrame("OnNextTick");

    return true;
}

public Native_CancelMessage(plugin_id, argc)
{
    CancelMessage();
}

public Native_SendMessage(plugin_id, argc)
{
    new buffer[64];
    get_string(1, buffer, sizeof buffer);

    SendMessage(buffer);
    CancelMessage();
}

public Native_SetStringParam(plugin_id, argc)
{
    if (!ValidMessage()) return;

    new buffer[1024];

    if (argc == 2)
    {
        get_string(2, buffer, sizeof buffer);
    }
    else if(argc > 2)
    {
        vdformat(buffer, sizeof buffer, 2, 3);
    }

    BuildMap(get_param(1), buffer);
}

public Native_SetCellParam(plugin_id, argc)
{
    if (!ValidMessage()) return;

    BuildMap(get_param(1), _, _, _, get_param(2));
}

public Native_AddField(plugin_id, argc)
{
    if (!ValidMessage()) return;

    new title[512], text[512], inline;

    get_string(1, title, sizeof title);
    get_string(2, text, sizeof text);

    inline = get_param(3);

    BuildMap(FIELDS, title, text, inline);
}

public Native_WebHookExists(plugin_id, argc)
{
    new buffer[256];
    get_string(1, buffer, sizeof buffer);

    return TrieKeyExists(message, buffer);
}
