# Description
#   Delegate authorization for Hubot user actions to LDAP
#
# Configuration:
#   LDAP_URL - the URL to the LDAP server
# Commands:
#   hubot what roles does <user> have - Find out what roles a user has
#   hubot what roles do I have - Find out what roles you have
#   hubot refreh roles
#
# Notes:
#   * returns bool true or false
#

LDAP = require 'ldapjs'
Q = require 'q'
robot = null
client = LDAP.createClient {
  url: process.env.LDAP_URL
}


baseDn = process.env.LDAP_SEARCH_BASE_DN or "dc=example,dc=com"

groupObjectClass = process.env.LDAP_GROUP_OBJECT_CLASS or "groupOfNames"
userObjectClass = process.env.LDAP_USER_OBJECT_CLASS or "inetOrgPerson"
ldapUserNameAttribute = process.env.USER_LDAP_ATTRIBUTE or "cn"
hipchatUserNameAttribute = process.env.USER_HIPCHAT_ATTRIBUTE or "id"
groupNameAttribute = process.env.LDAP_GROUP_NAME_ATTRIBUTE or "cn"
ldapRefreshTime = process.env.LDAP_REFRESH_TIME or 21600000

#The default implementation searches for a user using the cn attribute
#This can be overridden by process.env.USER_LDAP_ATTRIBUTE
#which should be an attribute in LDAP that matches an attribute in Hipchat
getDnForUser = (userAttr, user, cb) ->
  dnSearch getDefaultFilter(userAttr), user, cb

getDefaultFilter = (userAttr)->
  "(&(objectclass=#{userObjectClass})(#{ldapUserNameAttribute}=#{userAttr}))"

dnSearch = (filter, user, cb) ->
  opts = {
    filter: filter
    scope: 'sub'
    sizeLimit: 1
    attributes: [
      'dn'
    ]
  }
  return executeSearch opts, "", (output, entry) ->
    user.dn = entry.object.dn

attrSearchFromFilter = (filter, attr) ->
  opts = {
    filter: filter
    scope: 'sub'
    sizeLimit: 1
    attributes: [
      "#{attr}"
    ]
  }
  return executeSearch opts, "", (output, entry) ->
    entry.object["#{attr}"]

getRolesForUser = (dn) ->
  val = dn.next()
  while not val.done
    val = dn.next()
  opts = {
    filter: "(&(objectclass=#{groupObjectClass})(member=#{val.value}))"
    scope: 'sub'
    sizeLimit: 200
    attributes: [
      "#{groupNameAttribute}"
    ]
  }
  return executeSearch opts, [], (arr, entry) ->
    arr.push entry.cn
    arr

getUsersFromRole = (role) ->
  users = []
  opts = {
    filter: "(&(objectclass=#{groupObjectClass})(#{groupNameAttribute}=#{role}))"
    scope: 'sub'
    sizeLimit: 200
    attributes: [
      'member'
    ]     
  }
  return executeSearch opts, [], (arr, entry) ->
    if !arr then arr = []
    newEntries = entry.attributes[0]._vals.map (val) -> val.toString()
    arr = arr.concat newEntries
    arr

executeSearch = (opts, val, cb) ->
  deferred = Q.defer()
  client.search baseDn, opts, (err, res) ->
    if err
      deferred.reject err
    res.on 'searchEntry', (entry) ->
      val = cb(val,entry)
    res.on 'end', (result) ->
      setTimeout ->
        deferred.resolve val
      ,0

  deferred.promise

getUserForDn = (dn) ->
  attrSearchFromFilter "(&(objectclass=#{userObjectClass})(dn=#{dn}))", "#{ldapUserNameAttribute}"

loadListeners = (robot, isOneTimeRequest) ->
  if !isOneTimeRequest
    setTimeout ->
      loadListeners(robot)
    , 21600000
  promises = []
  users = robot.brain.users()
  for userId in Object.keys users
    user = users[userId]
    if !user.dn
      userAttr = user[hipchatUserNameAttribute]
      if userAttr
        promises << getDnForUser userAttr, user, (dn, user) -> 
          user.dn = dn
      else
        user.dn = undefined
    if !user.roles
      user.roles = []
  Q.all(promises)
  .then (val) ->
    loadRoles robot

loadRoles = (robot) ->
  rolesToSearch = []
  for listener in robot.listeners
    roles = listener.options?.roles or []
    roles = [roles] if typeof roles is 'string'
    for role in roles
      if role not in rolesToSearch
        rolesToSearch.push role
  for role in rolesToSearch
    evaluateRole robot,role

evaluateRole = (robot, role) ->
  if !role or role.length is 0
    return
  getUsersFromRole(role)
  .then (userDns) ->
    evaluateRoleWithDns robot, role, userDns

evaluateRoleWithDns = (robot, role, userDns) ->
  users = robot.brain.users()
  for userId in Object.keys users
    user = users[userId]
    if user.dn in userDns
      if role not in user.roles
        user.roles.push role
    else
      if role in user.roles
        user.roles = user.roles.filter (word) -> word isnt role

module.exports = (inputRobot) ->

  robot = inputRobot

  class Auth

    hasRole: (user, roles) ->
      userRoles = @userRoles(user)
      if userRoles?
        roles = [roles] if typeof roles is 'string'
        for role in roles
          return true if role in userRoles
      return false

    usersWithRole: (role) ->
      users = []
      for own key, user of robot.brain.data.users
        if @hasRole(user, role)
          users.push(user.name)
      users      

    userRoles: (user) ->
      if user.roles?
        return user.roles
      return []

  robot.auth = new Auth

  setTimeout ->
    loadListeners(robot)
  , 1000

  if !robot.authPlugin then robot.authPlugin = {}

  robot.respond /refresh roles/i, (msg) ->
    loadListeners(robot, true)

  robot.respond /what roles? do(es)? @?(.+) have\?*$/i, (msg) ->
    name = msg.match[2].trim()
    if name.toLowerCase() is 'i' then name = msg.message.user.name
    user = robot.brain.userForName(name) or {name: name}
    return msg.reply "#{name} does not exist" unless user?
    userRoles = robot.auth.userRoles(user)

    if userRoles.length == 0
      msg.reply "#{name} has no roles."
    else
      robot.logger.error userRoles
      msg.reply "#{name} has the following roles: #{userRoles.join(', ')}."

  robot.respond /who has (["'\w: -_]+) role\?*$/i, (msg) ->
    role = msg.match[1]
    userNames = robot.auth.usersWithRole(role) if role?

    if userNames.length > 0
      msg.reply "The following people have the '#{role}' role: #{userNames.join(', ')}"
    else
      msg.reply "There are no people that have the '#{role}' role."