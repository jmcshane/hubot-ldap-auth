Helper = require('hubot-test-helper')
chai = require 'chai'
expect = chai.expect

process.env.LDAP_URL = 'ldap://127.0.0.1:10389'

helper = new Helper '../src/hubot-ldap-auth.coffee'


describe 'hubot-ldap-auth', ->
  room = null

  beforeEach ->
    room = helper.createRoom()

  afterEach ->
    room.destroy()

  context 'testing synchronicity', ->
    beforeEach (done) ->
      room.user.say 'user1', 'hubot what roles do i have'
      setTimeout done, 100

    it 'should run', ->
      expect(true).to.be.true
