# Hubot LDAP Authorization

This module is derived from the [hubot-auth](https://github.com/hubot-scripts/hubot-auth) module and it delegates the main functions of authorization to an LDAP server using the [ldapjs](http://ldapjs.org/client.html) LDAP client.  In the implementation, it is meant to be a drop in replacement for the existing module so that the other integrations that exist around hubot-auth can continue to function properly.  All modifying actions have been removed from the auth client so that the LDAP server can act as a service providing authorization details to Hubot, rather than providing Hubot ability to do such modifications.  Theoretically, this would be a separate script to do such an integration, but it is not in the scope of this module.

## Configuration

* `LDAP_URL` - the client will attempt to bind a session to the LDAP server using this URL
