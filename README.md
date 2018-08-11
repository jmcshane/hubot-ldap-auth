# Hubot LDAP Authorization

[![npm version](https://badge.fury.io/js/hubot-ldap-auth.svg)](https://badge.fury.io/js/hubot-ldap-auth)

This module is derived from the [hubot-auth](https://github.com/hubot-scripts/hubot-auth) module and it delegates the main functions of authorization to an LDAP server using the [ldapjs](http://ldapjs.org/client.html) LDAP client.  In the implementation, it is meant to be a drop in replacement for the existing module so that the other integrations that exist around hubot-auth can continue to function properly.  All modifying actions have been removed from the auth client so that the LDAP server can act as a service providing authorization details to Hubot, rather than providing Hubot ability to do such modifications.  Theoretically, this would be a separate script to do such an integration, but it is not in the scope of this module.

## Configuration

* `HUBOT_LDAP_AUTH_LDAP_URL` - the URL to the LDAP server
* `HUBOT_LDAP_AUTH_BIND_DN` - the bind DN to authenticate with
* `HUBOT_LDAP_AUTH_BIND_PASSWORD` - the bind password to authenticate with
* `HUBOT_LDAP_AUTH_TLS_OPTIONS_CA` - the full path to a CA certificate file in PEM format. Passed to TLS connection layer when connecting via ldaps://
* `HUBOT_LDAP_AUTH_TLS_OPTIONS_CERT` - the full path to a certificate file in PEM format. Passed to TLS connection layer when connecting via ldaps://
* `HUBOT_LDAP_AUTH_TLS_OPTIONS_KEY` - the full path to a private key file in PEM format. Passed to TLS connection layer when connecting via ldaps://
* `HUBOT_LDAP_AUTH_TLS_OPTIONS_CIPHERS` - cipher suite string. Passed to TLS connection layer when connecting via ldaps://
* `HUBOT_LDAP_AUTH_TLS_OPTIONS_SECURE_PROTOCOL` - ssl method to use. Passed to TLS connection layer when connecting via ldaps://
* `HUBOT_LDAP_AUTH_USER_SEARCH_FILTER` - the ldap filter search for a specific user - e.g. 'cn={0}' where '{0}' will be replaced by the hubot user attribute
* `HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_ATTRIBUTE` - the member attribute within the user object
* `HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_FILTER` - the membership filter to find groups based on user DN - e.g. 'member={0}' where '{0}' will be replaced by user DN
* `HUBOT_LDAP_AUTH_GROUP_MEMBERSHIP_SEARCH_METHOD` - (filter | attribute) - how to find groups belong to users
* `HUBOT_LDAP_AUTH_ROLES_TO_INCLUDE` - comma separated group names that will be used as roles, all the rest of the groups will be filtered out
* `HUBOT_LDAP_AUTH_USE_ONLY_LISTENER_ROLES` - if true, groups will be filtered by all listener options, all the rest of the groups will be filtered out
* `HUBOT_LDAP_AUTH_SEARCH_BASE_DN` - search DN to start finding users and groups within the ldap directory
* `HUBOT_LDAP_AUTH_USER_LDAP_ATTRIBUTE` - the ldap attribute to match hubot users within the ldap directory
* `HUBOT_LDAP_AUTH_HUBOT_USER_ATTRIBUTE` - the hubot user attribute to search for a user within the ldap directory
* `HUBOT_LDAP_AUTH_GROUP_LDAP_ATTRIBUTE` - the ldap attribute of a group that will be used as role name
* `HUBOT_LDAP_AUTH_LDAP_REFRESH_TIME` - time in millisecods to refresh the roles and users
* `HUBOT_LDAP_AUTH_DN_ATTRIBUTE_NAME` - the dn attribute name, used for queries by DN. In ActiveDirectory should be distinguishedName

## Integration with Hubot

This script is meant to be used with the [hubot-auth-middleware](https://github.com/HelloFax/hubot-auth-middleware) project which uses the auth plugin in Hubot to determine whether a user can take a particular action.  See the [README.md](https://github.com/HelloFax/hubot-auth-middleware/blob/master/README.md) of that project for more details on configuring roles for user actions.

In order to set up this plugin, first install it in the project:

    npm install hubot-ldap-auth --save

Then, add the script to the `external-scripts.json` file:

    [
      "hubot-ldap-auth"
    ]
