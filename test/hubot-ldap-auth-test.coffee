Helper = require 'hubot-test-helper'
LdapServer = require './helpers/ldapserver'
chai = require 'chai'
expect = chai.expect

LDAP_ENTITIES = require './mocks/ldap-data'
ROOT_DN = 'dc=example,dc=com'
LDAP_PORT = 10389


process.env.HUBOT_LDAP_AUTH_LDAP_URL = 'ldap://127.0.0.1:10389'

process.env.HUBOT_LDAP_AUTH_BIND_DN = 'cn=root,dc=example,dc=com'
process.env.HUBOT_LDAP_AUTH_BIND_PASSWORD = 'secret'
process.env.HUBOT_LDAP_AUTH_SEARCH_BASE_DN = 'dc=example,dc=com'

process.env.HUBOT_LDAP_AUTH_USER_FILTER_SEARCH = 'cn={0}'

process.env.HUBOT_LDAP_AUTH_HUBOT_USER_ATTRIBUTE = 'name'
process.env.HUBOT_LDAP_AUTH_GROUP_LDAP_ATTRIBUTE = 'cn'
process.env.HUBOT_LDAP_AUTH_USER_LDAP_ATTRIBUTE = 'cn'
process.env.HUBOT_LDAP_AUTH_ROLES_TO_INCLUDE = ''

initializeRoom = (scripts) ->
  scripts = '../src/hubot-ldap-auth.coffee' if not scripts
  helper = new Helper scripts
  room = helper.createRoom()
  room.robot.brain.userForId 1,
    name: "Bob Dylan"
  room.robot.brain.userForId 2,
    name: "Neil Young"
  room.robot.brain.userForId 3,
    name: "John Wayne"
  room.robot.brain.userForId 4,
    name: "Kurt Cobain"
  room

describe 'hubot-ldap-auth', ->
  room = null
  ldapServer = null

  before ->
    ldapServer = new LdapServer(ROOT_DN, LDAP_ENTITIES)
    ldapServer.start LDAP_PORT, (port) =>

  after ->
    ldapServer.stop()


  afterEach ->
    if room then room.destroy()

  context 'using membership attribute', ->
    beforeEach (done) ->
      process.env.HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_ATTRIBUTE = 'memberOf'
      process.env.HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_SEARCH_METHOD = 'attribute'
      room = initializeRoom()
      setTimeout done, 3000

    it 'hubot what roles do i have', ->
      room.user.say('Bob Dylan', 'hubot what roles do i have').then =>
        expect(room.messages).to.eql [
          ['Bob Dylan', 'hubot what roles do i have'],
          ['hubot', '@Bob Dylan Bob Dylan has the following roles: developers, ops.']
        ]

    it 'hubot what roles do someone else have', ->
      room.user.say('Neil Young', 'hubot what roles do Bob Dylan have').then =>
        expect(room.messages).to.eql [
          ['Neil Young', 'hubot what roles do Bob Dylan have'],
          ['hubot', '@Neil Young Bob Dylan has the following roles: developers, ops.']
        ]

    it 'who has roles', ->
      room.user.say('Bob Dylan', 'hubot who has ops role').then =>
        expect(room.messages).to.eql [
          ['Bob Dylan', 'hubot who has ops role'],
          ['hubot', "@Bob Dylan The following people have the 'ops' role: Bob Dylan, John Wayne, Neil Young"]
        ]

  context 'using membership filter', ->
    beforeEach (done) ->
      process.env.HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_FILTER = 'member={0}'
      process.env.HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_SEARCH_METHOD = 'filter'
      room = initializeRoom()
      setTimeout done, 3000

    it 'hubot what roles do i have', ->
      room.user.say('Bob Dylan', 'hubot what roles do i have').then =>
        expect(room.messages).to.eql [
          ['Bob Dylan', 'hubot what roles do i have'],
          ['hubot', '@Bob Dylan Bob Dylan has the following roles: developers, ops.']
        ]

    it 'hubot what roles do someone else have', ->
      room.user.say('Neil Young', 'hubot what roles do Bob Dylan have').then =>
        expect(room.messages).to.eql [
          ['Neil Young', 'hubot what roles do Bob Dylan have'],
          ['hubot', '@Neil Young Bob Dylan has the following roles: developers, ops.']
        ]

  context 'using predefined roles', ->
    beforeEach (done) ->
      process.env.HUBOT_LDAP_AUTH_ROLES_TO_INCLUDE = 'ops'
      room = initializeRoom()
      setTimeout done, 3000

    it 'hubot what roles do i have', ->
      room.user.say('Bob Dylan', 'hubot what roles do i have').then =>
        expect(room.messages).to.eql [
          ['Bob Dylan', 'hubot what roles do i have'],
          ['hubot', '@Bob Dylan Bob Dylan has the following roles: ops.']
        ]

    it 'hubot what roles do someone else have', ->
      room.user.say('Neil Young', 'hubot what roles do Bob Dylan have').then =>
        expect(room.messages).to.eql [
          ['Neil Young', 'hubot what roles do Bob Dylan have'],
          ['hubot', '@Neil Young Bob Dylan has the following roles: ops.']
        ]

  context 'using listener roles', ->
    beforeEach (done) ->
      process.env.HUBOT_LDAP_AUTH_USE_ONLY_LISTENER_ROLES = 'true'
      room = initializeRoom(['../src/hubot-ldap-auth.coffee', './mocks/mock-hubot-module-with-listeners.coffee'])
      setTimeout done, 3000

    it 'hubot what roles do i have', ->
      room.user.say('Bob Dylan', 'hubot what roles do i have').then =>
        expect(room.messages).to.eql [
          ['Bob Dylan', 'hubot what roles do i have'],
          ['hubot', '@Bob Dylan Bob Dylan has the following roles: developers.']
        ]

    it 'hubot what roles do someone else have', ->
      room.user.say('Neil Young', 'hubot what roles do Bob Dylan have').then =>
        expect(room.messages).to.eql [
          ['Neil Young', 'hubot what roles do Bob Dylan have'],
          ['hubot', '@Neil Young Bob Dylan has the following roles: developers.']
        ]

    it 'hubot no roles found for user', ->
      room.user.say('Neil Young', 'hubot what roles does Kurt Cobain have').then =>
        expect(room.messages).to.eql [
          ['Neil Young', 'hubot what roles does Kurt Cobain have'],
          ['hubot', '@Neil Young Kurt Cobain has no roles.']
        ]
