{
  "realm": "${KEYCLOAK_REALM}",
  "enabled": true,
  "displayName": "Elastic Labs",

  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,

  "identityProviders": [
    {
      "alias": "google",
      "providerId": "google",
      "enabled": true,
      "trustEmail": true,
      "firstBrokerLoginFlowAlias": "first broker login",
      "config": {
        "clientId": "${KEYCLOAK_GOOGLE_CLIENT_ID}",
        "clientSecret": "${KEYCLOAK_GOOGLE_CLIENT_SECRET}",
        "defaultScope": "openid email profile"
      }
    }
  ],

  "clients": [
    {
      "clientId": "oauth2-proxy",
      "name": "oauth2-proxy",
      "enabled": true,
      "protocol": "openid-connect",

      "publicClient": false,
      "secret": "${OAUTH2_PROXY_CLIENT_SECRET}",

      "redirectUris": [
        "https://labs.${BASE_DOMAIN}/oauth2/callback",
        "https://admin.${BASE_DOMAIN}/oauth2/callback"
      ],

      "webOrigins": [
        "https://labs.${BASE_DOMAIN}",
        "https://admin.${BASE_DOMAIN}"
      ],

      "standardFlowEnabled": true,
      "directAccessGrantsEnabled": false,

      "attributes": {
        "pkce.code.challenge.method": "S256"
      },

      "defaultClientScopes": [
        "web-origins",
        "profile",
        "email"
      ]
    }
  ]
}