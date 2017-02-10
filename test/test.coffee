ldap = require 'ldapjs'
client = ldap.createClient {
  url: 'ldap://127.0.0.1:10389'
}

opts = 
  filter: '(&(objectclass=groupOfNames)(cn=grp2))'
  scope: 'base'
  sizeLimit: 1
  attributes: [
    'cn'
    'member'
  ]
client.search 'dc=example,dc=com', opts, (err, res) ->
  assert.ifError err
  res.on 'searchEntry', (entry) ->
    console.log 'entry: ' + JSON.stringify(entry.object)
  res.on 'searchReference', (referral) ->
    console.log 'referral: ' + referral.uris.join()
  res.on 'error', (err) ->
    console.error 'error: ' + err.message
  res.on 'end', (result) ->
    console.log 'status: ' + result.status
