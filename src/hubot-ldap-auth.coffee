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
client = LDAP.createClient {
  url: process.env.LDAP_URL
}


baseDn = process.env.LDAP_SEARCH_BASE_DN or "dc=example,dc=com"

groupObjectClass = process.env.LDAP_GROUP_OBJECT_CLASS or "groupOfNames"
userObjectClass = process.env.LDAP_USER_OBJECT_CLASS or "inetOrgPerson"
userNameAttribute = process.env.LDAP_USER_NAME_ATTRIBUTE or "cn"
groupNameAttribute = process.env.LDAP_GROUP_NAME_ATTRIBUTE or "cn"

@typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

module.exports = (robot) ->

  class Auth

    hasRole: (user, roles) ->
      userRoles = @userRoles(user)
      if userRoles?
        roles = [roles] if typeof roles is 'string'
        for role in roles
          return true if role in userRoles
      return false

    #When the user list comes back from LDAP, we can transform it by putting an @ symbol
    #before the user attribute or we can override this behavior with the
    #robot.authPlugin.ldapToHipchat function
    usersWithRole: (role) ->
      ((robot.authPlugin.ldapToHipchat or (a) -> "@#{a}") user for user in @getUsersFromRole role)

    #First apply a transformation to the user object
    #  - defaults to get the user name
    #  - overridden by robot.authPlugin.userTransform
    #Then get the user DN from LDAP
    #  - defaults to the @getDnForUser
    #  - overridden by robot.authPlugin.getDnForUser
    userRoles: (user) ->
      userTransform = robot.authPlugin.userTransform or @getUserName
      dnFunc = robot.authPlugin.getDnForUser or @getDnForUser
      @getRolesForUser dnFunc userTransform user

    @getUserName: (user) ->
      user.name

    #The default implementation searches for a user using the cn attribute
    #This can be overridden using two things
    #  - robot.authPlugin.filterProvider - function that returns a filter query
    #  - process.env.LDAP_USER_NAME_ATTRIBUTE - user name attribute in LDAP
    @getDnForUser: (user) ->
      filter = robot.authPlugin.filterProvider or @getDefaultFilter
      @dnSearch filter user

    @getDefaultFilter: (user)->
      @dnSearch "(&(objectclass=#{userObjectClass})(#{userNameAttribute}=#{user}))"

    @dnSearch: (filter) ->
      opts = {
        filter: filter
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
        filter: "(&(objectclass=#{groupObjectClass})(member=#{dn}))"
        scope: 'sub'
        sizeLimit: 200
        attributes: [
          "#{groupNameAttribute}"
        ]
      }
      @executeSearch opts, [], (arr, entry) ->
        arr.push entry.cn
        arr

    @getUsersFromRole: (role) ->
      users = []
      opts = {
        filter: "(&(objectclass=#{groupObjectClass})(#{groupNameAttribute}=#{role}))"
        scope: 'sub'
        sizeLimit: 200
        attributes: [
          'member'
        ]     
      }
      @executeSearch opts, [], (arr, entry) ->
        memberResp = entry.member
        if typeisArray memberResp
          arr.concat memberResp
        else
          arr.push memberResp
        arr

    @executeSearch: (opts, val, cb) ->
      deferred = Q.defer()
      search baseDn, opts, (err, res) ->
        if err then deferred.reject err
        res.on 'searchEntry', (entry) ->
          val = cb(val,entry)
        res.on 'end', (result) ->
          setTimeout ->
            deferred.resolve arr
          ,0
      deferred.promise;

  robot.auth = new Auth

  if !robot.authPlugin then robot.authPlugin = {}

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