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

1. Clone this repository and ensure that MongoDB is running.

2. Install the REST API and create the configuration file `cyclotron-svc/config/config.js`. Paste in it the content of `sample.config.js`, which contains the configurable properties of the API, such as MongoDB instance and AAC endpoints.

3. Install Cyclotron website.

## API Configuration with AAC

Open `cyclotron-svc/config/config.js` and update the properties according to your needs. To use AAC as authentication provider, be sure to set the following properties:

    enableAuth: true
    authProvider: 'AAC'




4. Start the service in node:

        node app.js

### Website

4. Build and run the service:

        gulp server

5. Update the configuration file at `_public/js/conf/configService.js` as needed.  Gulp automatically populates this file from `sample.configService.js` if it does not exist.
