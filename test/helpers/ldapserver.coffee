ldap = require('ldapjs');

class LdapServer
  constructor: (rootDn, ldapEntities) ->
    @ldapServer = ldap.createServer()
    @directoryEntities = Object.keys(ldapEntities).map (key) ->
      entry = ldapEntities[key]
      entry.dn = if key.endsWith(",#{rootDn}") then key else "#{key},#{rootDn}"
      entry
    .reduce (a, e) ->
      a[e.dn] = e
      a
    , {}

    @directoryEntities[rootDn] =
      dn: rootDn
      objectclass: 'organization'

    @ldapServer.search rootDn, (req, res, next) =>
      dn = req.dn.toString()
      entry = @_getEntry(dn)
      if !entry
        return next(new ldap.NoSuchObjectError(dn))

      scopeCheck = null
      switch req.scope
        when 'base'
          if req.filter.matches(entry)
            res.send { dn: dn, attributes: entry }
          res.end()
          return next()

        when 'sub'
          scopeCheck = (k) -> req.dn.equals(k) || req.dn.parentOf(k)

        when 'one'
          scopeCheck = (k) ->
            if req.dn.equals(k) then return true
            parent = ldap.parseDN(k).parent()
            if parent then parent.equals(req.dn) else false

      for k, v of @directoryEntities
        if !scopeCheck(k) then return
        if req.filter.matches(v)
          res.send {dn: k, attributes: v}
      res.end()
      next()

    @ldapServer.bind rootDn, (req, res, next) =>
      dn = req.dn.toString()
      credentials = req.credentials
      entry = @_getEntry dn
      if credentials && entry && credentials == entry.userPassword
        res.end()
        return next()
      next(new ldap.InvalidCredentialsError(dn))

  start: (port, cb) ->
    @ldapServer.listen port, () =>
      if cb then cb(port)

  stop: () ->
    @ldapServer.emit('close')
    @ldapServer = null

  _getEntry: (dn) ->
    dn = dn.replace(/ /g, '')
    @directoryEntities[dn]

module.exports = LdapServer