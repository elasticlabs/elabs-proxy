# 🔐 Production OIDC Setup (Keycloak + Google + GitHub)

This guide describes a **production-grade OIDC setup** using:

* Keycloak as Identity Provider
* Google & GitHub as external identity providers
* OAuth2 Proxy as authentication gateway
* NGINX (SWAG) as reverse proxy

---

# 🧱 Architecture

```text
User
  → https://labs.<domain>
    → NGINX (SWAG)
      → oauth2-proxy
        → Keycloak
          → Google / GitHub
```

---

# 🌍 Conventions

To keep things consistent:

* `auth.<domain>` → Keycloak
* `labs.<domain>` → protected applications
* `admin.<domain>` → admin tools (optional)

👉 All applications are exposed under:

```text
https://labs.<domain>/<app>
```

---

# 🔑 Step 1 — Keycloak Setup

## Create Realm

* Name: `main` (or your choice)

---

## Disable Public Registration (IMPORTANT)

In Keycloak:

* Realm Settings → Login

Set:

```text
User registration = OFF
```

👉 Only known users can authenticate.

---

## Create OAuth2 Client (for oauth2-proxy)

* Client ID: `oauth2-proxy`
* Client Type: OpenID Connect
* Access Type: confidential

### Configuration

| Field               | Value                                   |
| ------------------- | --------------------------------------- |
| Root URL            | `https://labs.<domain>`                 |
| Valid Redirect URIs | `https://labs.<domain>/oauth2/callback` |
| Web Origins         | `https://labs.<domain>`                 |

Save and copy:

👉 **Client Secret**

---

# 🌐 Step 2 — Google Login Configuration

👉 This is the most error-prone part.

Go to:

👉 https://console.cloud.google.com/

---

## 2.1 Create Project

* Create a new project
* Enable:

  * **Google Identity Services API**

---

## 2.2 Configure OAuth Consent Screen

* User Type: External
* App name: your project name
* Support email: your email
* Add scopes:

  * `openid`
  * `email`
  * `profile`

👉 Add your email as **test user** (mandatory in dev)

---

## 2.3 Create OAuth Client ID

* Type: **Web Application**

### Fill EXACTLY:

#### Name

```text
keycloak-google
```

#### Authorized JavaScript origins

```text
https://auth.<domain>
```

#### Authorized redirect URIs

```text
https://auth.<domain>/realms/<realm>/broker/google/endpoint
```

⚠️ Example:

```text
https://auth.elasticlabs.co/realms/elabs/broker/google/endpoint
```

---

## 🚨 Common Error

If you see:

```text
You can't sign in because the app doesn't comply with Google's OAuth 2.0 policy
```

👉 It means:

> ❌ redirect_uri is NOT registered exactly

✔️ Fix:

* Copy EXACT redirect URI from Keycloak
* Paste into Google Console
* No trailing slash mistakes

---

## Retrieve Credentials

* `GOOGLE_CLIENT_ID`
* `GOOGLE_CLIENT_SECRET`

---

## Configure in Keycloak

* Identity Providers → Google

Fill:

* Client ID
* Client Secret

---

# 🐙 Step 3 — GitHub Login

Go to:

👉 https://github.com/settings/developers

---

## Create OAuth App

### Settings

| Field                      | Value                                                         |
| -------------------------- | ------------------------------------------------------------- |
| Homepage URL               | `https://labs.<domain>`                                       |
| Authorization callback URL | `https://auth.<domain>/realms/<realm>/broker/github/endpoint` |

---

## Retrieve

* `GITHUB_CLIENT_ID`
* `GITHUB_CLIENT_SECRET`

---

## Configure in Keycloak

* Identity Providers → GitHub

---

# 👥 Step 4 — User Access Control

## Strategy

* No public registration
* Only users with known emails can access
* Access controlled via **Keycloak groups**

---

## Create Groups

Example:

```text
/dev
/admin
/observability
```

---

## Assign Users

* Import users via:

  * Google login (first login creates user)
* Then:

  * Assign them to groups manually

---

## Restrict Access by Email Domain (optional)

In oauth2-proxy:

```env
OAUTH2_PROXY_EMAIL_DOMAINS=yourcompany.com
```

---

# 🔗 Step 5 — Group Mapping → Applications

## In oauth2-proxy

Enable headers:

```env
OAUTH2_PROXY_SET_XAUTHREQUEST=true
```

---

## In NGINX

Headers available:

```nginx
X-Forwarded-User
X-Forwarded-Email
X-Forwarded-Groups
```

---

## Example: Protect Admin Route

```nginx
location /admin/ {
    auth_request /oauth2/auth;

    # allow only admin group
    if ($http_x_forwarded_groups !~* "admin") {
        return 403;
    }

    proxy_pass http://admin-app;
}
```

---

## Grafana Integration

Grafana supports OIDC:

* Map:

  * groups → roles
* Example:

```env
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups[*], 'admin') && 'Admin' || 'Viewer'
```

---

# 🔐 Step 6 — oauth2-proxy Configuration

```env
OAUTH2_PROXY_PROVIDER=oidc
OAUTH2_PROXY_OIDC_ISSUER_URL=https://auth.<domain>/realms/<realm>

OAUTH2_PROXY_CLIENT_ID=oauth2-proxy
OAUTH2_PROXY_CLIENT_SECRET=...

OAUTH2_PROXY_COOKIE_SECRET=...

OAUTH2_PROXY_REDIRECT_URL=https://labs.<domain>/oauth2/callback

OAUTH2_PROXY_SCOPE=openid profile email
OAUTH2_PROXY_EMAIL_DOMAINS=*

OAUTH2_PROXY_SET_XAUTHREQUEST=true
```

---

# 🧪 Step 7 — Validation Flow

1. Open:

```text
https://labs.<domain>
```

2. Redirect:

```text
/oauth2/start → Keycloak
```

3. Login via:

* Google
* GitHub

4. Return:

```text
labs.<domain>
```

---

# 🚫 Security Hardening

* Disable Keycloak registration ✅
* Restrict users via groups ✅
* Restrict domains (optional) ✅
* Use HTTPS everywhere ✅
* Avoid wildcard server_name ❌

---

# 🧠 Key Takeaways

* Google OAuth errors are **almost always redirect URI issues**
* Keycloak = identity + grouping
* oauth2-proxy = enforcement layer
* NGINX = routing + access control

---

# 🚀 Next Steps

* Automate config via `envsubst`
* Add RBAC per service
* Integrate logs in Grafana (Loki + Tempo)

---
