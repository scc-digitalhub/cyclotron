# Cyclotron

Extension of [Expedia's Cyclotron](https://github.com/ExpediaInceCommercePlatform/cyclotron) with new widgets, data sources and security based on Smart Community's Authentication and Authorization Control Module (AAC).

## New Features

* Widgets: Time Slider (based on [noUiSlider](https://refreshless.com/nouislider/)), OpenLayers Map (based on [OpenLayers](https://openlayers.org/)), Google Charts (based on [Google Charts](https://developers.google.com/chart/))

* Data Sources: OData (based on [OData](https://www.odata.org/))

* Parameter-based interaction between dashboard components

* New authentication methods (see below)

## Requirements

* AAC ([installation instructions](https://github.com/smartcommunitylab/AAC))
* Node.js
* MongoDB (2.6+) ([installation instructions](http://docs.mongodb.org/manual/installation/))

## Installation

Note that the detailed installation procedure is only summarized here and is better described on [Expedia's page](https://github.com/ExpediaInceCommercePlatform/cyclotron).

0. Ensure that MongoDB and AAC are running. Cyclotron will automatically create a database named "cyclotron".

1. Clone this repository.

2. Install the REST API and create the configuration file `cyclotron-svc/config/config.js`. Paste in it the content of `sample.config.js`, which contains the configurable properties of the API, such as MongoDB instance and AAC endpoints.

3. Install Cyclotron website.

4. Start both:

* API: from `cyclotron-svc` run the command `node app.js`
* website: from `cyclotron-site` run the command `gulp server`

Now Cyclotron is running with its default settings and authentication is disabled. Proceed to configure authentication via AAC.

## Authentication Configuration with OAuth2

This fork supports OAuth2/OpenID as login method, via *implicit flow*.
The module is usable with any *OAuth2/OIDC-compliant* identity provider, but some advanced functionalities such as role mapping and permission evaluators are available only when using **AAC** as IdP.

Remember to set the same configuration (when needed) to both backend and frontend, without exposing private variables.

### Frontend configuration
Open `cyclotron-site/_public/js/conf/configService.js` and set the following properties under `authentication`:

```
authentication: {
  enable: true,
  authProvider: 'aac',
  authorizationURL: 'http://localhost:8080/aac/eauth/authorize',
  clientID: '<clientID>',
  callbackDomain: 'http://localhost:8088',
  scopes: 'openid profile user.roles.me'
}
```

### Backend configuration
Open `cyclotron-svc/config/config.js` and update the properties according to your needs:

```
    enableAuth: true,
    authProvider: 'aac',

    oauth: {
        useJWT: <true|false>,
        clientId: '<clientId>',
        clientSecret: '<clientSecret>',
        jwksEndpoint: 'http://localhost:8080/aac/jwk',
        tokenIntrospectionEndpoint: 'http://localhost:8080/aac/oauth/introspect',
        userProfileEndpoint: 'http://localhost:8080/aac/userinfo',
        parentSpace: 'components/cyclotron',
        editorRoles: ['ROLE_PROVIDER','ROLE_EDITOR']
    },
```

In order to use **JWTs** as bearer tokens, and locally verify them, please set ``useJWT:true`` and provide only one of these two configurations:

* populate ``jwksEndpoint`` with the JWKS uri to use public/private key verification via RSA
* set ``clientSecret`` and leave ``jwksEndpoint`` empty to use simmetric HMAC with clientSecret as key

Examples:

```
#JWT + public RSA key
oauth: {
    useJWT: true,
    clientId: '<clientId>',
    clientSecret: '',
    jwksEndpoint: 'http://localhost:8080/aac/jwk',
    tokenIntrospectionEndpoint: '',
    userProfileEndpoint: '',
},

#JWT + private HMAC key
oauth: {
    useJWT: true,
    clientId: '<clientId>',
    clientSecret: '<clientSecret>',
    jwksEndpoint: '',
    tokenIntrospectionEndpoint: '',
    userProfileEndpoint: '',
},

```

Do note that the default validation will check for a valid signature and for the correspondence between ``clientId`` and ``audience``.
If you want to also validate the *issuer* of JWT tokens set the corresponding property in config:

```
oauth: {
    issuer: <issuer>
}
```

Alternatively, you can use **opaque tokens** as bearer, and thus leverage *OAuth2 introspection* plus *OpenID userProfile*. This configuration requires ``useJWT:false`` and all the endpoints properly populated (except ``jwksEndpoint``).

Example:
```
#opaque oauth
oauth: {
    useJWT: false,
    clientId: '<clientId>',
    clientSecret: '<clientSecret>',
    jwksEndpoint: '',
    tokenIntrospectionEndpoint: 'http://localhost:8080/aac/oauth/introspect',
    userProfileEndpoint: 'http://localhost:8080/aac/userinfo',
},

```

### Role mapping
By default, valid users are given the permission to create and manage their own dashboards, but can not access private dashboards without a proper role. A dashboard is private if the ability to **view** and/or **edit** it is restricted to specific users or *groups*.

Cyclotron supports two different roles:
* ``viewers``
* ``editors``

When using an external IdP (such as AAC) it is possible to map **roles** and **groups** by defining a context for the component space and a mapping for the **editor** role (i.e. a list of external roles that must be mapped as **editor** role in Cyclotron):

```
oauth: {
    parentSpace: 'components/cyclotron',
    editorRoles: ['ROLE_PROVIDER','ROLE_EDITOR']
},
```

As such, Cyclotron dynamically assigns roles to users at login, by deriving their **group memberships** and their role inside such groups from the IdP user profile. Any role that is not included in ``editorRoles`` will be mapped as **viewer**.

By setting ``parentSpace`` we define a prefix for roles obtained from the IdP, which is then used to derive the group from the following pattern:

```
<parentSpace>/<groupName>:<roleName>
```

For example, the upstream role ``components/cyclotron/testgroup:ROLE_PROVIDER`` with the given configuration can be translated to:

* (``parentSpace=components/cyclotron``)
* ``group=testgroup``
* ``role=editor``

because the upstream ``ROLE_PROVIDER`` role is recognized as an editor role.

The upstream role ``components/cyclotron/testgroup:ROLE_USER`` will be translated to:

* (``parentSpace=components/cyclotron``)
* ``group=testgroup``
* ``role=viewer``

Without a direct mapping to a given group, the system won't assign any role to the current user in such group. The user won't thus be able to access any dashboard restricted to that group.

## Client Application Configuration on AAC

Log in to AAC as a provider user and click "New App" to create a client application. In the Settings tab:

* add Cyclotron website as redirect URL: `http://localhost:8088/,http://localhost:8088` (change the domain if it runs on a different host and port)
* check all the Grant Types and at least `internal` as identity provider (this must be approved on the Admin account under tab Admin -> IdP Approvals)

In the API Access tab:

* under OpenID Connect, check `openid` and `profile`
* under User Profile Service, check `profile.basicprofile.me` to give access to user profiles to the client app
* under Role Service, check `user.roles.me` to give access to user roles

You can find `clientId` and `clientSecret` properties in the Overview tab. Add `clientId` to `cyclotron-site/_public/js/conf/configService.js` and `cyclotron-svc/config/config.js`. Add `clientSecret` as well if needed.

Now you can (re)start Cyclotron API and website with authentication enabled. Most services will now be protected and will require login and specific privileges.

**NOTE**: if you need to change the API port you can do it in the configuration file, but changing Cyclotron website port can only be done in `cyclotron-site/gulpfile.coffee`, inside the Gulp task named `webserver` (line 281): update `port` and `open` properties as needed.

## Authentication Methods on Cyclotron

On the **web app**, login can be performed:

* via LDAP by providing username and password
* via OAuth2/OpenID, i.e., being redirected to an identity provider (e.g. AAC) for authentication

On the **API**, requests can be authenticated:

* via session key, which is the internal mechanism used by Cyclotron web app to authenticate its requests to the API
* via `Authentication` HTTP header
* via API key

The Authentication header must provide a valid token issued by the IdP. It is used by the web app if login is performed via OAuth2/OpenID and can be used to request API services directly:
```
GET /dashboards/mydashboard HTTP/1.1 
Host: localhost:8077 
Accept: application/json 
Authorization: Bearer <my_token>
```

The API key is issued by the IdP and can be passed as query parameter in the URL to request API services:
```
http://localhost:8077/dashboards/mydashboard?apikey=<my_apikey>
```

## Using Cyclotron API

### AAC Roles and Cyclotron Permissions
**NOTE**: refer to AAC documentation on its Data Model if you are not familiar with the concepts of "role" and "space".

If you use AAC as authentication provider, then Cyclotron *groups* correspond to AAC *spaces*. By default, owners of a space in AAC have the role `ROLE_PROVIDER`. In the AAC console, in the tab User Roles, owners (providers) of a space can add other users to it and assign them roles.

Suppose you configured `oauth.editorRoles=['ROLE_PROVIDER','ROLE_EDITOR']` and the following AAC roles exist:

* user A is provider of space T1 and user of space T2:
```
components/cyclotron/T1:ROLE_PROVIDER
components/cyclotron/T2:ROLE_USER
```
* user B is user of space T1:
```
components/cyclotron/T1:ROLE_USER
```
* user C is editor of space T1:
```
components/cyclotron/T1:ROLE_EDITOR
```

When these users log in to Cyclotron via AAC they are assigned the following property:

* user A: `memberOf: ['T1_viewers', 'T1_editors', 'T2_viewers']`
* user B: `memberOf: ['T1_viewers']`
* user C: `memberOf: ['T1_viewers', 'T1_editors']`

**NOTE**: editors can also view, i.e., users A and C being members of T1_editors are also members of T1_viewers; but viewers cannot edit, i.e., groups *<group_name>\_viewers* cannot be assigned as editors of a dashboard.

### Creating Private and Public Dashboards

When authentication is enabled, if a dashboard has no editors or viewers specified when it is created, by default both edit and view permissions are restricted to the dashboard creator only, who is allowed to change this behaviour later on. In order to allow anyone to view a dashboard, even anonymously, its view permissions can be given to the system role **Public**. Edit permissions can be given to **Public** as well, in which case the dashboard is editable by every user.

If you want to restrict access to a dashboard, you can give view/edit permissions either to specific users or to groups you are a member of. Some examples are provided in the next section.

### Restricting Access to Dashboards in JSON

If you create a dashboard as a JSON document (either by POSTing it on the API or via JSON document editor on the website), this is its skeleton:

    {
        "tags": [],
        "name": "foo",
        "dashboard": {
            "name": "foo",
            "pages": [],
            "sidebar": {
                "showDashboardSidebar": true
            }
        },
        "editors": [],
        "viewers": []
    }

Resuming the examples above, suppose user A wants to restrict access to its dashboard:
* dashboard editors list: can contain only group **T1_editors** or its members (e.g. user C)
* dashboard viewers list: can contain groups **T1_viewers** (*not* T1_editors as it is already a subset of T1_viewers, since editors are automatically also viewers) and **T2_viewers** or their members (e.g. users B and C)

Each editor or viewer specified in the lists must have three mandatory properties: `category` (either "User" or "Group"), `displayName` (used for readability purpose) and `dn` (unique name that identifies the user or group; corresponds to `distinguishedName` property in Cyclotron API User model).

Example 1. User A restricts edit permissions to themselves and gives view permissions to group T2:

    "editors": [{
        "category": "User",
        "displayName": "John Doe",
        "dn": "A"
    }],
    "viewers": [{
        "category": "Group",
        "displayName": "T2",
        "dn": "T2_viewers"
    }]

Example 2. User A restricts both edit and view permissions to group T2, i.e., every T2 member can view but only editor members can edit:

    "editors": [{
        "category": "Group",
        "displayName": "T2",
        "dn": "T2_editors"
    }],
    "viewers": [{
        "category": "Group",
        "displayName": "T2",
        "dn": "T2_viewers"
    }]

In short: use *<group_name>\_editors* syntax for editors and *<group_name>\_viewers* syntax for viewers.

**NOTE**: the system role **Public** is represented by the following properties:

    {
        "category": "System",
        "displayName": "Public",
        "dn": "_public"
    }

### Testing

If you want to test the authorization mechanism (e.g. on Postman), you can use the following URLs, setting the `Authorization` header with an appropriate token:

* to create a dashboard, POST on `http://localhost:8077/dashboards`

* to update a dashboard, PUT on `http://localhost:8077/dashboards/{dashboard_name}`

* to retrieve a dashboard, GET on `http://localhost:8077/dashboards/{dashboard_name}`

## Deployment


