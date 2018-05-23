# Description:
#   Auth-middleware test listeners - used in the test suite
#
# Dependencies:
#
# Configuration:
#
# Commands:
#
module.exports = (robot) ->

  roleRejOptions = { "id": "reject-role", "auth": "true", "roles": "developers" }
  robot.hear /amTest reject role/, roleRejOptions, (msg) ->
    msg.reply "reject role fail"

