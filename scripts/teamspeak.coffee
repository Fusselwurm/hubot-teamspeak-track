# Description
#   Allows Hubot to track who enters/exits a TeamSpeak server, as well as report on who is currently connected
#
# Dependencies:
#   "node-teamspeak": "1.0.4"
#
# Configuration:
#   HUBOT_TEAMSPEAK_IP
#   HUBOT_TEAMSPEAK_USER (ServerQuery user)
#   HUBOT_TEAMSPEAK_PASSWORD (ServerQuery password)
#   HUBOT_TEAMSPEAK_OUT_ROOM (comma seperated list of all rooms to output to)
#
# Commands:
#   hubot teamspeak - <replies with a comma seperated list of all connected users>
#
# Notes:
#   Bot runs through TeamSpeak's ServerQuery interface
#
# Author:
#   dmillerw

host = process.env.HUBOT_TEAMSPEAK_IP
user = process.env.HUBOT_TEAMSPEAK_USER
password = process.env.HUBOT_TEAMSPEAK_PASSWORD
voice_port = process.env.HUBOT_TEAMSPEAK_VOICE_PORT
enabled = true

TeamSpeak = require 'node-teamspeak'
util = require 'util'


dehighlight = (nick) ->
  (nick || '').split('').join('\ufeff')

sortCaseInsensitive = (a, b) ->
  a.toLowerCase().charCodeAt(0) - b.toLowerCase().charCodeAt(0)

wrapInBackticks = (u) -> '`' + u + '`'

module.exports = (robot) ->
  unless host
    robot.logger.warning "Missing TeamSpeak IP!"
    enabled = false

  unless user
    robot.logger.warning "Missing TeamSpeak ServerQuery user"
    enabled = false

  unless password
    robot.logger.warning "Missing TeamSpeak ServerQuery password"
    enabled = false

  if enabled
    client = new TeamSpeak host
    active_users = {}
    ignored_users = {}
    channels = {}
    rooms = process.env.HUBOT_TEAMSPEAK_OUT_ROOM.split(",")

    send_message = (message) ->
      for room in rooms
        robot.messageRoom room, message

    client.send "login", {client_login_name: user, client_login_password: password}, (err, resp) ->
      if voice_port
        client.send "use", {port: voice_port}
      client.send "servernotifyregister", {event: "channel", id: 0}

      client.send "clientlist", (err, resp) ->
        for el in resp
          if el.client_type isnt 1
            active_users[el.clid] = {name: el.client_nickname}


      client.on "cliententerview", (event) ->
        if (event.client_nickname.match(/Unknown\s+from\s+/))
          ignored_users[event.clid] = true
          return
        active_users[event.clid] = {name: event.client_nickname}
        send_message dehighlight(active_users[event.clid].name) + " has entered TeamSpeak"

      client.on "clientleftview", (event) ->
        if (ignored_users[event.clid])
          delete ignored_users[event.clid];
          return
        send_message dehighlight(active_users[event.clid]?.name) + " has left TeamSpeak." + (event.invokerid && (" Reason: " + event.reasonmsg) || "")
        active_users[event.clid] = null

      client.on "clientmoved", (event) ->
        if (ignored_users[event.clid])
          return


      # Here to keep the TeamSpeak connection alive
      setInterval ->
        client.send "whoami", (err, resp) ->
      , 180000
      true

      robot.respond /teamspeak/i, (msg) ->
        client.send "channellist", (err, resp) ->
          channels = {}
          for c in resp
            c.users = []
            channels[c.cid] = c

          channels[0] =
            cid: 0,
            pid: 0,
            channel_order: 0,
            channel_name: 'Unbekannter Channel',
            total_clients: 0,
            channel_needed_subscribe_power: 0,
            users: []

          client.send "clientlist", (err, resp) ->

            for el in resp
              if el.client_type isnt 1
                channels[el.cid || 0].users.push el.client_nickname

            msg = []
            for cid of channels
              c = channels[cid]
              if c.users.length > 0
                msg.push "*" + c.channel_name + "* (" + c.total_clients + "): " + c.users.sort(sortCaseInsensitive).map(dehighlight).join(", ")

            if msg.length > 0
              send_message "Im Teamspeak sind " + resp.length + " Benutzer :\n" + msg.join("\n")
            else
              send_message "Durch den leeren Teamspeakserver weht ein kalter Wind."
