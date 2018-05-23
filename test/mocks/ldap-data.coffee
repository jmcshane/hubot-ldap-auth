module.exports =
  'cn=root':
    objectclass: 'organizationalRole'
    cn: 'root'
    userPassword: 'secret'

  'ou=groups':
    objectclass: 'organizationalUnit'
  'cn=admins,ou=groups':
    objectclass: 'group'
    cn: 'admins'
    member: [
      'cn=Kurt Cobain,ou=users,dc=example,dc=com',
    ]
  'cn=developers,ou=groups':
    objectclass: 'group'
    cn: 'developers'
    member: [
      'cn=Bob Dylan,ou=users,dc=example,dc=com',
      'cn=John Wayne,ou=users,dc=example,dc=com',
    ]
  'cn=ops,ou=groups':
    objectclass: 'group'
    cn: 'ops'
    member: [
      'cn=John Wayne,ou=users,dc=example,dc=com',
      'cn=Neil Young,ou=users,dc=example,dc=com',
      'cn=Bob Dylan,ou=users,dc=example,dc=com',
    ]

  'ou=users':
    objectclass: 'organizationalUnit'
  'cn=Bob Dylan,ou=users':
    cn: 'Bob Dylan'
    sn: 'Dylan'
    objectClass: 'inetOrgPerson'
    memberOf: [
      'cn=ops,ou=groups,dc=example,dc=com',
      'cn=developers,ou=groups,dc=example,dc=com',
    ]
  'cn=Neil Young,ou=users':
    cn: 'Neil Young'
    sn: 'Young'
    objectClass: 'inetOrgPerson'
    memberOf: [
      'cn=ops,ou=groups,dc=example,dc=com',
    ]
  'cn=John Wayne,ou=users':
    cn: 'John Wayne'
    sn: 'Wayne'
    objectClass: 'inetOrgPerson'
    memberOf: [
      'cn=ops,ou=groups,dc=example,dc=com',
      'cn=developers,ou=groups,dc=example,dc=com',
    ]
  'cn=Kurt Cobain,ou=users':
    cn: 'Kurt Cobain'
    sn: 'Cobain'
    objectClass: 'inetOrgPerson'
    memberOf: [
      'cn=admins,ou=groups,dc=example,dc=com',
    ]
