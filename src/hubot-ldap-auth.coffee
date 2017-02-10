# Description
#   Delegate authorization for Hubot user actions to LDAP
#
# Configuration:
#   LDAP_URL - the URL to the LDAP server
# Commands:
#   hubot what roles does <user> have - Find out what roles a user has
#   hubot what roles do I have - Find out what roles you have
#
# Notes:
#   * returns bool true or false
#

LDAP = require 'ldapjs'
Q = require 'q'
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
      @getRolesForUser @getDnForUser user

    @getDnForUser: (user) ->
      opts = {
        filter: "(&(objectclass=inetOrgPerson)(cn=#{user}))"
        scope: 'sub'
        sizeLimit: 1
        attributes: [
          'dn'
        ]
      }
      @executeSearch opts, "", (output, entry) ->
        entry.dn

    @getRolesForUser: (dn) ->
      opts = {
        filter: "(&(objectclass=groupOfNames)(member=#{dn}))"
        scope: 'sub'
        sizeLimit: 200
        attributes: [
          'cn'
        ]     
      }
      @executeSearch opts, [], (arr, entry) ->
        arr.push entry.cn
        arr

    @getUsersFromRole: (role) ->
      users = []
      opts = {
        filter: "(&(objectclass=inetOrgPerson)(cn=#{role}))"
        scope: 'sub'
        sizeLimit: 200
        attributes: [
          'cn'
          'member'
        ]     
      }
      @executeSearch opts, [], (arr, entry) ->
        arr.concat entry.member
        arr


    @executeSearch: (opts, val, cb) ->
      deferred = Q.defer()
      search 'dc=example,dc=com', opts, (err, res) ->
        if err then deferred.reject err
        res.on 'searchEntry', (entry) ->
          val = cb(val,entry)
        res.on 'end', (result) ->
          deferred.resolve arr
      deferred.promise;

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