# Cyclotron

Extension of [Expedia's Cyclotron](https://github.com/ExpediaInceCommercePlatform/cyclotron) with new widgets, data sources and security based on Smart Community's Authentication and Authorization Control Module (AAC).

## New Features

* Widgets: Time Slider (based on noUiSlider), OpenLayers Map (based on OpenLayers), Google Charts (based on Google Charts)

* Data Sources: OData

* Parameter-based interaction between dashboard components

## Requirements

* AAC ([installation instructions](https://github.com/smartcommunitylab/AAC) )
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
    authProvider: 'AAC'
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

TODO

