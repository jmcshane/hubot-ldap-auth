# Hubot LDAP Authorization

[![npm version](https://badge.fury.io/js/hubot-ldap-auth.svg)](https://badge.fury.io/js/hubot-ldap-auth)

This module is derived from the [hubot-auth](https://github.com/hubot-scripts/hubot-auth) module and it delegates the main functions of authorization to an LDAP server using the [ldapjs](http://ldapjs.org/client.html) LDAP client.  In the implementation, it is meant to be a drop in replacement for the existing module so that the other integrations that exist around hubot-auth can continue to function properly.  All modifying actions have been removed from the auth client so that the LDAP server can act as a service providing authorization details to Hubot, rather than providing Hubot ability to do such modifications.  Theoretically, this would be a separate script to do such an integration, but it is not in the scope of this module.

## Configuration

* `LDAP_URL` - the client will attempt to bind a session to the LDAP server using this URL
* `LDAP_SEARCH_BASE_DN` - the base dn for the ldap search user
* `LDAP_GROUP_OBJECT_CLASS` - the object class to use to find LDAP groups
* `LDAP_USER_OBJECT_CLASS` - the user object class to identify users from LDAP
* `USER_LDAP_ATTRIBUTE` - the ldap attribute that matches an attribute from `USER_HIPCHAT_ATTRIBUTE`
* `USER_HIPCHAT_ATTRIBUTE` - the hipchat user attribute that matches a value in LDAP
* `LDAP_REFRESH_TIME` - set to 6 hours to reset the roles and users, can be done on demand.  Is requeried every time the app starts up

## Integration with Hubot

This script is meant to be used with the [hubot-auth-middleware](https://github.com/HelloFax/hubot-auth-middleware) project which uses the auth plugin in Hubot to determine whether a user can take a particular action.  See the [README.md](https://github.com/HelloFax/hubot-auth-middleware/blob/master/README.md) of that project for more details on configuring roles for user actions.

In order to set up this plugin, first install it in the project:

    npm install hubot-ldap-auth --save

Then, add the script to the `external-scripts.json` file:

    [
      "hubot-ldap-auth"
    ]