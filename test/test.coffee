ldap = require 'ldapjs'
chai = require 'chai'
expect = chai.expect
client = ldap.createClient {
  url: 'ldap://127.0.0.1:10389'
}

process.env.LDAP_URL = 'ldap://127.0.0.1:10389'
describe 'ldap', ->

  context 'carry out an ldap search', ->
    beforeEach (done) ->
      getValue()
      done()

    it 'should complete', ->
      expect(true).to.be.true
      console.log(perfectSquares())


perfectSquares = ->
  num = 0
  x = ->
    loop
      num += 1
      yield num * num
  return x().next().value
  return

getValue = ->
  opts = 
    filter: "(&(objectclass=groupOfNames)(member=o=jmcshane,dc=example,dc=com))"
    scope: 'sub'
    sizeLimit: 2
    attributes: [
      'cn'
      'member'
    ]
  client.search 'dc=example,dc=com', opts, (err, res) ->
    if err
      console.log err
      expect(false).to.be.true
    res.on 'searchEntry', (entry) ->
      console.log 'entry: ' + JSON.stringify(entry.object)
    res.on 'searchReference', (referral) ->
      console.log 'referral: ' + referral.uris.join()
    res.on 'error', (err) ->
      console.error 'error: ' + err.message
    res.on 'end', (result) ->
      console.log 'status: ' + result.status
      #setTimeout done, 0
