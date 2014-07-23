Hubot TeamSpeak Tracker
=====================
Allows Hubot to track who enters/exits a TeamSpeak server, as well as report on who is currently connected

Configuration
============
* HUBOT_TEAMSPEAK_IP
* HUBOT_TEAMSPEAK_USER (ServerQuery user)
* HUBOT_TEAMSPEAK_PASSWORD (ServerQuery password)
* HUBOT_TEAMSPEAK_OUT_ROOM (comma seperated list of all rooms to output to)

Dependencies
============
* `node-teamspeak` >= 1.0.5

Commands
============
* hubot teamspeak - <replies with a comma seperated list of all connected users>

Install
============
npm install hubot-teamspeak-track
