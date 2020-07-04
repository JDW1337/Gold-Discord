#include <amxmodx>
#include <discord>

#pragma semicolon 1

static const webHook[] = "example";

public plugin_init()
{
    register_plugin("[Discord] Example", "1.0", "JDW");

    register_clcmd("say /example", "ExampleCommand");
}

public ExampleCommand(id)
{
    if (Discord_StartMessage())
    {
        Discord_SetStringParam(USERNAME, "JDW");
        Discord_SetStringParam(CONTENT, "Hello, world"); 
        Discord_AddField("Field", "Test");
        Discord_SendMessage(webHook);
    }

    return PLUGIN_HANDLED;
}