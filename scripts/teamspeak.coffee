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

SERVER_GROUP_NONE = 14
SERVER_GROUP_AMBASSADOR = 20 #?

TeamSpeak = require 'node-teamspeak'
util = require 'util'

messages =
  empty: ['The TeamSpeak server is empty']

getRandomMessage = (type) ->
  availableCount = messages[type].length
  if (availableCount == 0)
    return ''
  messages[type][Math.floor(Math.random() * availableCount)]

fs = require 'fs'
fs.readFile __dirname + '/../messages/server-empty.txt', (err, data) ->
  if (data)
    extractedMessages = data.toString().split('\n').filter((e) -> e.trim())
    if (extractedMessages.length)
      messages.empty = extractedMessages

active_users = {}
ignored_users = {}
groups = {}

dehighlight = (nick) ->
  if (nick && nick.indexOf('_') == 0)
    return nick
  (nick || '').split('').join('\ufeff')

sortCaseInsensitive = (a, b) ->
  a.toLocaleLowerCase().localeCompare(b.toLocaleLowerCase())

getServerGroups = (userEvent) ->
  ('' + userEvent.client_servergroups).split(',').map((sgid) -> parseInt(sgid))

getDecoratedNick = (userEvent) ->
  isAdler = getServerGroups(userEvent).filter((sgid) -> groups[sgid]?.name == 'A').length > 0
  nick = userEvent.client_nickname
  if nick and not isAdler
    nick = '_' + nick + '_'

  nick

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
    rooms = process.env.HUBOT_TEAMSPEAK_OUT_ROOM.split(",")

    send_message = (message) ->
      for room in rooms
        robot.messageRoom room, message

    announceUserConnect = (userEvent) ->
      nickName = getDecoratedNick(userEvent)
      if (getServerGroups(userEvent).indexOf(SERVER_GROUP_NONE) != -1)
        send_message "@here new user " + nickName + " has entered TeamSpeak"
      else if (getServerGroups(userEvent).indexOf(SERVER_GROUP_AMBASSADOR) != -1)
        send_message "@here :crown: " + nickName + " has entered TeamSpeak"
      else
        send_message dehighlight(nickName) + " has entered TeamSpeak"


    client.send "login", {client_login_name: user, client_login_password: password}, (err, resp) ->
      if voice_port
        client.send "use", {port: voice_port}
      client.send "servernotifyregister", {event: "channel", id: 0}

      client.send "servergrouplist", (err, resp) ->
        for g in resp
          groups[g.sgid] = g

      client.send "clientlist", ["groups"], (err, resp) ->
        for el in resp
          if el.client_type isnt 1
            active_users[el.clid] = {name: el.client_nickname}


      client.on "cliententerview", (event) ->
        if (event.client_unique_identifier == 'ServerQuery')
          ignored_users[event.clid] = true
          return
        active_users[event.clid] = {name: event.client_nickname}
        announceUserConnect(event)

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

      robot.respond /teamspeak|get_users/i, (msg) ->
        client.send "channellist", (err, channelArray) ->
          channelMap = {}
          for c in channelArray
            c.users = []
            channelMap[c.cid] = c

          channelMap[0] =
            cid: 0,
            pid: 0,
            channel_order: 0,
            channel_name: 'Unbekannter Channel',
            total_clients: 0,
            channel_needed_subscribe_power: 0,
            users: []

          client.send "clientlist", ["groups"], (err, connectedClients) ->

            for el in connectedClients
              if el.client_type isnt 1
                channelMap[el.cid || 0].users.push getDecoratedNick(el)

            msg = []
            for cid of channelMap
              c = channelMap[cid]
              if c.users.length > 0
                msg.push "*" + c.channel_name + "* (" + c.total_clients + "): " + c.users.sort(sortCaseInsensitive).map(dehighlight).join(", ")

            if msg.length > 0
              send_message "Im Teamspeak sind " + (connectedClients.length - 1) + " Benutzer :\n" + msg.join("\n")
            else
              send_message (getRandomMessage 'empty')
