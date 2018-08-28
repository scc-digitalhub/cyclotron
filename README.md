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

## API Configuration with AAC

Open `cyclotron-svc/config/config.js` and update the properties according to your needs (remember to configure the same properties in the website config file, e.g. the API server URL. To use AAC as authentication provider, be sure to set the following properties with the correct AAC URLs:

    enableAuth: true
    authProvider: 'aac'
    oauth: {
        userProfileEndpoint: 'http://localhost:8080/aac/basicprofile/me'
        userRolesEndpoint: 'http://localhost:8080/aac/userroles/me'
        scopes: 'profile.basicprofile.me,user.roles.me'
        tokenValidityEndpoint: 'http://localhost:8080/aac/resources/access'
        tokenInfoEndpoint: 'http://localhost:8080/aac/resources/token'
        tokenRolesEndpoint: 'http://localhost:8080/aac/userroles/token'
        apikeyCheckEndpoint: 'http://localhost:8080/aac/apikeycheck'
        parentSpace: 'components/cyclotron'
    }

Do the same with `cyclotron-site/_public/js/conf/configService.js`. Be sure to set the following properties under `authentication` (you will set the client ID later):

    enable: true
    authProvider: 'aac'
    authorizationURL: 'http://localhost:8080/aac/eauth/authorize'
    clientID: ''
    callbackDomain: 'http://localhost:8088'
    scopes: 'profile.basicprofile.me user.roles.me'
    userProfileEndpoint: 'http://localhost:8080/aac/basicprofile/me'
    tokenValidityEndpoint: 'http://localhost:8080/aac/resources/access'

## Client Application Configuration on AAC

Log in to AAC with a provider user and click "New App" to create a client application. In the Settings tab:

* add Cyclotron website as redirect URL: `http://localhost:8088/,http://localhost:8088` (change the domain if it runs on a different host and port)
* check all the Grant Types and at least `internal` as identity provider (this must be approved on the Admin account under tab Admin -> IdP Approvals)

In the API Access tab:

* under Basic Profile Service, check `profile.basicprofile.me` to give access to user profiles to the client app
* under Role Management Service, check `user.roles.me` to give access to user roles

In the Overview tab, copy `clientId` property, then go back to `cyclotron-svc/config/config.js` and add it in the `authentication` section.

Now you can (re)start Cyclotron API and website

**NOTE**: if you need to change the API port you can do it in the configuration file, but changing Cyclotron website port can only be done in `cyclotron-site/gulpfile.coffee`, inside the Gulp task named `webserver` (line 281): update `port` and `open` properties as needed.

## Using Cyclotron API

### AAC Roles and Cyclotron Permissions

**NOTE**: read Data Model section on AAC page to understand the concepts of *role* and *space*.

In Cyclotron you can restrict access to a dashboard by specifiying a set of **viewers** and **editors**. These can be either users or *groups*. If you use AAC as authentication provider, then groups correspond to AAC *spaces*. By default, owners of a space in AAC have the role `ROLE_PROVIDER`. In the AAC console, in the tab User Roles, owners (providers) of a space can add other users to it and assign them roles.

When a user logs in via AAC, Cyclotron reads their roles from AAC and assigns them certain groups depending on such roles. Precisely, Cyclotron checks whether the user has roles `ROLE_PROVIDER`, `reader` or `writer` in some spaces. Here are some examples of roles:

* user A is provider of space T1 and reader of space T2:
```
{context":"components/cyclotron","space":"T1","role":"ROLE_PROVIDER","authority":"components/cyclotron/T1:ROLE_PROVIDER"}
{context":"components/cyclotron","space":"T2","role":"reader","authority":"components/cyclotron/T2:reader"}
```
* user B is reader of space T1:
```
{context":"components/cyclotron","space":"T1","role":"reader","authority":"components/cyclotron/T1:reader"}
```
* user C is writer of space T1:
```
{context":"components/cyclotron","space":"T1","role":"writer","authority":"components/cyclotron/T1:writer"}
```
When these users log in to Cyclotron via AAC they are assigned the following property:

* user A: `memberOf: ['T1_viewers', 'T1_editors', 'T2_viewers']`
* user B: `memberOf: ['T1_viewers']`
* user C: `memberOf: ['T1_viewers', 'T1_editors']`

**Note 1**: providers and writers are equally considered editors by Cyclotron, i.e., user A as provider of T1 is member of T1_editors group.

**Note 2**: editors can also view, i.e., users A and C being members of T1_editors are also members of T1_viewers; but viewers cannot edit, i.e., groups *<group_name>\_viewers* cannot be assigned as editors of a dashboard.

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

NOTE: if a dashboard has no editors or viewers specified, by default the permissions are restricted to the dashboard creator only.

Resuming the example above, suppose user A wants to restrict access to its dashboard:
* dashboard editors list: can contain only group T1_editors or its members (e.g. user C)
* dashboard viewers list: can contain groups T1_editors, T1_viewers and T2_viewers or their members (e.g. users B and C)

Each editor or viewer specified in the lists must have three mandatory properties: `category` (either "User" or "Group"), `displayName` (used for readability purpose) and `dn` (unique name that identifies the user or group; corresponds to `distinguishedName` property in Cyclotron API User model).

Example: user A restricts edit permissions to themselves and gives view permissions to the whole group T2 (if only T2_editors or only T2_viewers is added, the other one is added automatically):

    "editors": [{
        "category": "User",
        "displayName": "John Doe",
        "dn": "A"
    }],
    "viewers": [{
        "category": "Group",
        "displayName": "T2",
        "dn": "T2_viewers"
    },{
        "category": "Group",
        "displayName": "T2",
        "dn": "T2_editors"
    }]

If authentication is enabled, only dashboards that have no restriction on viewers can be viewed anonymously.


