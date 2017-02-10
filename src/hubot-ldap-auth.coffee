# Description
#   Delegate authorization for Hubot user actions to LDAP
#
# Configuration:
#
# Commands:
#   hubot what roles does <user> have - Find out what roles a user has
#   hubot what roles do I have - Find out what roles you have
#
# Notes:
#   * returns bool true or false
#

LDAP = require 'ldapjs'
client = ldap.createClient {
  url: process.env.LDAP_URL
}


module.exports = (robot) ->

  class Auth

    hasRole: (user, roles) ->
      userRoles = @userRoles(user)
      if userRoles?
        roles = [roles] if typeof roles is 'string'
        for role in roles
          return true if role in userRoles
      return false

    usersWithRole: (role) ->
      @getUsersFromRole role

    userRoles: (user) ->
      @getRolesForUser @getCnForUser user

    @getCnForUser: (user) ->
      "cn=bob"

    @getRolesForUser: (user) ->
      ["grp1", "grp2"]

    @getUsersFromRole: (role) ->
      ["user1", "jane"]

  robot.auth = new Auth

  robot.respond /what roles? do(es)? @?(.+) have\?*$/i, (msg) ->
    name = msg.match[2].trim()
    if name.toLowerCase() is 'i' then name = msg.message.user.name
    user = robot.brain.userForName(name)
    return msg.reply "#{name} does not exist" unless user?
    userRoles = robot.auth.userRoles(user)

    if userRoles.length == 0
      msg.reply "#{name} has no roles."
    else
      msg.reply "#{name} has the following roles: #{userRoles.join(', ')}."

  robot.respond /who has (["'\w: -_]+) role\?*$/i, (msg) ->
    role = msg.match[1]
    userNames = robot.auth.usersWithRole(role) if role?

    if userNames.length > 0
      msg.reply "The following people have the '#{role}' role: #{userNames.join(', ')}"
    else
      msg.reply "There are no people that have the '#{role}' role."