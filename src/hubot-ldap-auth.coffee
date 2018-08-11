# Description
#   Delegate authorization for Hubot user actions to LDAP
#
# Configuration:
#   HUBOT_LDAP_AUTH_LDAP_URL - the URL to the LDAP server
#   HUBOT_LDAP_AUTH_BIND_DN - the bind DN to authenticate with
#   HUBOT_LDAP_AUTH_BIND_PASSWORD - the bind password to authenticate with
#   HUBOT_LDAP_AUTH_TLS_OPTIONS_CA - the full path to a CA certificate file in PEM format. Passed to TLS connection layer when connecting via ldaps://
#   HUBOT_LDAP_AUTH_TLS_OPTIONS_CERT - the full path to a certificate file in PEM format. Passed to TLS connection layer when connecting via ldaps://
#   HUBOT_LDAP_AUTH_TLS_OPTIONS_KEY - the full path to a private key file in PEM format. Passed to TLS connection layer when connecting via ldaps://
#   HUBOT_LDAP_AUTH_TLS_OPTIONS_CIPHERS - cipher suite string. Passed to TLS connection layer when connecting via ldaps://
#   HUBOT_LDAP_AUTH_TLS_OPTIONS_SECURE_PROTOCOL - ssl method to use. Passed to TLS connection layer when connecting via ldaps://
#   HUBOT_LDAP_AUTH_USER_SEARCH_FILTER - the ldap filter search for a specific user - e.g. 'cn={0}' where '{0}' will be replaced by the hubot user attribute
#   HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_ATTRIBUTE - the member attribute within the user object
#   HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_FILTER - the membership filter to find groups based on user DN - e.g. 'member={0}' where '{0}' will be replaced by user DN
#   HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_SEARCH_METHOD - (filter | attribute) - how to find groups belong to users
#   HUBOT_LDAP_AUTH_ROLES_TO_INCLUDE - comma separated group names that will be used as roles, all the rest of the groups will be filtered out
#   HUBOT_LDAP_AUTH_USE_ONLY_LISTENER_ROLES - if true, groups will be filtered by all listener options, all the rest of the groups will be filtered out
#   HUBOT_LDAP_AUTH_SEARCH_BASE_DN - search DN to start finding users and groups within the ldap directory
#   HUBOT_LDAP_AUTH_USER_LDAP_ATTRIBUTE - the ldap attribute to match hubot users within the ldap directory
#   HUBOT_LDAP_AUTH_HUBOT_USER_ATTRIBUTE - the hubot user attribute to search for a user within the ldap directory
#   HUBOT_LDAP_AUTH_GROUP_LDAP_ATTRIBUTE - the ldap attribute of a group that will be used as role name
#   HUBOT_LDAP_AUTH_LDAP_REFRESH_TIME - time in millisecods to refresh the roles and users
#   HUBOT_LDAP_AUTH_DN_ATTRIBUTE_NAME - the dn attribute name, used for queries by DN. In ActiveDirectory should be distinguishedName
#
# Commands:
#   hubot what roles does <user> have - Find out what roles a user has
#   hubot what roles do I have - Find out what roles you have
#   hubot refreh roles
#   hubot who has <roleName> role
#
# Notes:
#   * returns bool true or false
#
_ = require 'lodash'
LDAP = require 'ldapjs'
Q = require 'q'
fs = require 'fs'

module.exports = (inputRobot) ->
  robot = inputRobot

  ldapURL = process.env.HUBOT_LDAP_AUTH_LDAP_URL
  bindDn = process.env.HUBOT_LDAP_AUTH_BIND_DN
  bindPassword = process.env.HUBOT_LDAP_AUTH_BIND_PASSWORD

  tlsOptions = {
    ca: if process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_CA then [ fs.readFileSync process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_CA ] else null,
    cert: if process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_CERT then [ fs.readFileSync process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_CERT ] else null,
    key: if process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_KEY then [ fs.readFileSync process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_KEY ] else null,
    ciphers: if process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_CIPHERS then process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_CIPHERS else null,
    secureProtocol: if process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_SECURE_PROTOCOL then process.env.HUBOT_LDAP_AUTH_TLS_OPTIONS_SECURE_PROTOCOL else null,
  }

  userSearchFilter = process.env.HUBOT_LDAP_AUTH_USER_SEARCH_FILTER or 'cn={0}'
  dnAttributeName = process.env.HUBOT_LDAP_AUTH_DN_ATTRIBUTE_NAME or 'dn'
  groupMembershipAttribute = process.env.HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_ATTRIBUTE or 'memberOf'
  groupMembershipFilter = process.env.HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_FILTER or 'member={0}'
  groupMembershipSearchMethod = process.env.HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_SEARCH_METHOD or 'attribute' # filter | attribute
  rolesToInclude = if process.env.HUBOT_LDAP_AUTH_ROLES_TO_INCLUDE and process.env.HUBOT_LDAP_AUTH_ROLES_TO_INCLUDE != '' \
    then process.env.HUBOT_LDAP_AUTH_ROLES_TO_INCLUDE.toLowerCase().split(',')
  useOnlyListenerRoles = process.env.HUBOT_LDAP_AUTH_USE_ONLY_LISTENER_ROLES == 'true'

  baseDn = process.env.HUBOT_LDAP_AUTH_SEARCH_BASE_DN or "dc=example,dc=com"

  ldapUserNameAttribute = process.env.HUBOT_LDAP_AUTH_USER_LDAP_ATTRIBUTE or "cn"
  hubotUserNameAttribute = process.env.HUBOT_LDAP_AUTH_HUBOT_USER_ATTRIBUTE or "name"
  groupNameAttribute = process.env.HUBOT_LDAP_AUTH_GROUP_LDAP_ATTRIBUTE or "cn"
  ldapRefreshTime = process.env.HUBOT_LDAP_AUTH_LDAP_REFRESH_TIME or 21600000

  robot.logger.info "Starting ldap search with ldapURL: #{ldapURL}, bindDn: #{bindDn}, userSearchFilter: #{userSearchFilter},
  groupMembershipFilter: #{groupMembershipFilter}, groupMembershipAttribute: #{groupMembershipAttribute}, groupMembershipSearchMethod: #{groupMembershipSearchMethod},
    rolesToInclude: #{rolesToInclude}, useOnlyListenerRoles: #{useOnlyListenerRoles}, baseDn: #{baseDn},
    ldapUserNameAttribute: #{ldapUserNameAttribute}, hubotUserNameAttribute: #{hubotUserNameAttribute}, groupNameAttribute: #{groupNameAttribute}"

  client = LDAP.createClient({
    url: ldapURL,
    bindDN: bindDn,
    bindCredentials: bindPassword,
    tlsOptions: tlsOptions
  })

  getDnForUser = (userAttr, user) ->
    dnSearch(getUserFilter(userAttr)).then (value) -> { user: user, dn: value }


  getUserFilter = (userAttr)->
    userSearchFilter.replace(/\{0\}/g, userAttr)

  dnSearch = (filter) ->
    opts = {
      filter: filter
      scope: 'sub',
      attributes: [
        dnAttributeName
      ],
      sizeLimit: 1
    }
    executeSearch(opts).then (value) ->
      if not value or value.length == 0
        return
      else if value[0] and value[0].objectName
        ret = value[0].objectName.toString().replace(/, /g, ',')
        ret

  getGroupNamesByDn = (dns) ->
    filter = dns.map (dn) -> "(#{dnAttributeName}=#{dn})"
    filter = "(|#{filter.join('')})"
    opts = {
        filter: filter
        scope: 'sub'
        sizeLimit: dns.length
        attributes: [
          groupNameAttribute
        ]
      }
    executeSearch(opts).then (entries) ->
      entries.map (value) -> value.attributes[0].vals[0].toString()

  getGroupsDNsForUser = (user) ->
    if groupMembershipSearchMethod == 'attribute'
      filter = "(#{dnAttributeName}=#{user.dn})"
      attribute = groupMembershipAttribute
    else
      filter = groupMembershipFilter.replace(/\{0\}/g, user.dn)
      attribute = dnAttributeName
    robot.logger.debug "Getting groups DNs for user: #{user.dn}, filter = #{filter}, attribute = #{attribute}"
    opts = {
      filter: filter
      scope: 'sub'
      sizeLimit: 200
      attributes: [
        attribute
      ]
    }
    executeSearch(opts).then (value) ->
      _.flattenDeep value.map (entry) -> entry.attributes[0].vals.map (v) -> v.toString()

  executeSearch = (opts) ->
    deferred = Q.defer()
    client.search baseDn, opts, (err, res) ->
      arr = []
      if err
        deferred.reject err
      res.on 'searchEntry', (entry) ->
        arr.push entry
      res.on 'error', (err) ->
        deferred.reject err
      res.on 'end', (result) ->
        deferred.resolve arr
    deferred.promise

  loadListeners = (isOneTimeRequest) ->
    if !isOneTimeRequest
      setTimeout ->
        loadListeners()
      , 21600000
    robot.logger.info "Loading users and roles from LDAP"
    listenerRoles = loadListenerRoles()
      .map (e) -> e.toLowerCase()
    promises = []
    users = robot.brain.users()
    for userId in Object.keys users
      user = users[userId]
      if !user.dn
        userAttr = user[hubotUserNameAttribute]
        if userAttr
          ret = getDnForUser userAttr, user
          promises.push ret
        else
          user.dn = undefined

    promises.forEach (promise) ->
      promise.then (entry) ->
        entry.user.dn = entry.dn
        if entry.user.dn
          robot.logger.debug "Found DN for user #{entry.user.name}, DN: #{entry.user.dn}"
        entry.user

      .then (user) ->
        if not user.dn
          throw new Error("User #{user.name} does not have a dn, skipping")
        getGroupsDNsForUser(user)
        .then (groupDns) -> {user: user, groups: groupDns}

      .then (entry) ->
        getGroupNamesByDn(entry.groups)
        .then (groupNames) -> {user: entry.user, groupNames: groupNames}

      .then (entry) ->
        entries = entry.groupNames
        robot.logger.debug "groupNames for #{entry.user.name} are #{entries}"
        filterRoles = if useOnlyListenerRoles then listenerRoles else rolesToInclude
        if filterRoles and filterRoles.length > 0
          entries = entries.filter (e) -> e.toLowerCase() in filterRoles
        robot.logger.debug "groupNames for #{entry.user.name} are #{entries} - after filter"

        entry.user.roles = _.sortBy(entries)
        entry.user.roles
        entry.user
      .then (user) ->
        brainUser = robot.brain.userForId user.id
        brainUser.roles = user.roles
        brainUser.dn = user.dn
        robot.brain.save()

      .catch (err) ->
        robot.logger.error "Error while getting user groups", err

      .done()
    robot.logger.info "Users and roles were loaded from LDAP"


  loadListenerRoles = () ->
    rolesToSearch = []
    for listener in robot.listeners
      roles = listener.options?.roles or []
      roles = [roles] if typeof roles is 'string'
      for role in roles
        if role not in rolesToSearch
          rolesToSearch.push role
    rolesToSearch

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

  robot.brain.on 'loaded', ->
    setTimeout ->
      loadListeners()
    , 0

  robot.respond /refresh roles/i, (msg) ->
    loadListeners(true)

  robot.respond /what roles? do(es)? @?(.+) have\?*$/i, (msg) ->
    name = msg.match[2].trim()
    if name.toLowerCase() is 'i' then name = msg.message.user.name
    user = robot.brain.usersForFuzzyName(name) or {name: name}
    if user and user.length > 0 then user = user[0]
    return msg.reply "#{name} does not exist" unless user?
    userRoles = robot.auth.userRoles(user)

    if userRoles.length == 0
      msg.reply "#{name} has no roles."
    else
      msg.reply "#{user.name} has the following roles: #{userRoles.join(', ')}."

  robot.respond /who has (["'\w: -_]+) role\?*$/i, (msg) ->
    role = msg.match[1]
    userNames = robot.auth.usersWithRole(role) if role?

    if userNames.length > 0
      msg.reply "The following people have the '#{role}' role: #{_.sortBy(userNames).join(', ')}"
    else
      msg.reply "There are no people that have the '#{role}' role."
