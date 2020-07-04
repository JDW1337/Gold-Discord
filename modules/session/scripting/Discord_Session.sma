#include <amxmodx>
#include <amxmisc>
#include <discord>

#pragma semicolon 1

enum
{
    STEAM,
    NAME,
    LENGTH
}

static const webhook[] = "session";
static const flag[] = "u";

public plugin_init()
{
    register_plugin("[Discord] Session", "1.0", "JDW");
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    if (is_user_bot(id) || !has_flag(id, flag))
        return;

    new buffer[LENGTH][128];

    if (Discord_StartMessage())
    {
        Discord_SetStringParam(USERNAME, "Admin Session");
        Discord_SetStringParam(TITLE, "Admin disconnected from server");
        Discord_SetCellParam(COLOR, 0xff0);

        get_user_authid(id, buffer[STEAM], sizeof buffer[]);
        get_user_name(id, buffer[NAME], sizeof buffer[]);

        server_print(buffer[STEAM]);

        format(buffer[STEAM], sizeof buffer[], 
              "[**%s**] (%s)", 
              buffer[NAME], buffer[STEAM]);

        Discord_AddField("Administrator", buffer[STEAM], true);

        FormatTime(get_user_time(id), buffer[STEAM], sizeof buffer[]);
        Discord_AddField("Session length", buffer[STEAM], true);

        Discord_SendMessage(webhook);
    }
}

FormatTime(time, buffer[], maxlen)
{
    new days, hours, minutes, seconds, len;

    days = time / (60 * 60 * 24);
    hours = (time - (days * (60 * 60 * 24))) / (60 * 60);
    minutes = (time - (days * (60 * 60 * 24)) - (hours * (60 * 60))) / 60;
    seconds = time % 60;

    buffer[0] = 0;

    if (days)
        len += formatex(buffer[len], maxlen - len, "%d %s", days, "days");

    if (hours) 
        len += formatex(buffer[len], maxlen - len, "%s%d %s", days ? " " : "", hours, "hours");

    if (minutes)
        len += formatex(buffer[len], maxlen - len, "%s%d %s", (days || hours) ? " " : "", minutes, "minutes");

    if (seconds)
        formatex(buffer[len], maxlen - len, "%s%d %s", (days || hours || minutes) ? " " : "", seconds, "seconds");
}