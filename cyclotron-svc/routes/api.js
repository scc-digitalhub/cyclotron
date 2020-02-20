/*
 * Copyright (c) 2013-2015 the original author or authors.
 *
 * Licensed under the MIT License (the "License");
 * you may not use this file except in compliance with the License. 
 * You may obtain a copy of the License at
 *
 *     http://www.opensource.org/licenses/mit-license.php
 *
 * Unless required by applicable law or agreed to in writing, 
 * software distributed under the License is distributed on an 
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
 * either express or implied. See the License for the specific 
 * language governing permissions and limitations under the License. 
 */ 

var _ = require('lodash'),
    config = require('../config/config');

var auth = require('./auth.js'),
    crypto = require('./api.crypto.js'),
    dashboards = require('./api.dashboards.js'),
    data = require('./api.data.js'),
    exporter = require('./api.exports.js'),
    ldap = require('./api.ldap.js'),
    oauth = require('./api.oauth.js'),
    apikey = require('./api.apikey.js'),
    proxy = require('./api.proxy.js'),
    revisions = require('./api.revisions.js'),
    tags = require('./api.tags.js'),
    users = require('./api.users.js'),
    wms = require('./api.wms.js');

var notAllowed = function (req, res) {
    res.status(405).send('Not Allowed');
};

var requiresAuth = function (req, res, next) {
    if (auth.isUnauthenticated(req)) {
        return res.status(401).send('Authentication required: session key, bearer token or apikey must be provided.');
    } else {
        next();
    }
};

var requiresPermission = function (req, res, next) {
    if (_.isUndefined(req.query.dashboard)) {
        return res.status(401).send('Missing dashboard query parameter.');
    } else {
        auth.findDashboardById(req.query.dashboard)
        .then(function(dashboard){
            if(auth.hasViewPermission(dashboard, req)){
                console.log('---------user is authorized to proceed');
                next();
            } else {
                return res.status(401).send('Unauthorized.');
            }
        })
        .catch(function(err){
            return res.status(401).send(err);
        });
    }
};

/* General purpose callback for outputting models */
exports.getCallback = function (res, err, obj) {
    if (err) {
        console.log(err);
        res.status(500).send(err);
    } else if (_.isUndefined(obj) || _.isNull(obj)) 
        res.status(404).send('Not found');
    else {
        res.send(obj);
    }
};

exports.bindRoutes = function (app) {

    /* Dashboards Types */
    app.get('/dashboards', dashboards.get); //now search results are filtered according to user permissions
    app.post('/dashboards', requiresAuth, dashboards.putPostSingle); //requires EDIT permission
    app.all('/dashboards', notAllowed);

    app.get('/dashboards/:name', dashboards.getSingle); //requires auth if viewers restricted, requires VIEW permission
    app.post('/dashboards/:name', notAllowed);
    app.put('/dashboards/:name', requiresAuth, dashboards.putPostSingle); //requires EDIT permission
    app.delete('/dashboards/:name', requiresAuth, dashboards.deleteSingle); //requires EDIT permission

    app.put('/dashboards/:name/tags', requiresAuth, dashboards.putTagsSingle); //requires EDIT permission
    app.all('/dashboards/:name/tags', notAllowed);

    app.get('/dashboards/:name/revisions', revisions.get); //requires no permissions but excludes dashboard from results
    app.all('/dashboards/:name/revisions', notAllowed);
    
    app.get('/dashboards/:name/revisions/:rev', revisions.getSingle); //requires auth if viewers restricted, requires VIEW permission
    app.all('/dashboards/:name/revisions/:rev', notAllowed);
    app.get('/dashboards/:name/revisions/:rev/diff/:rev2', revisions.diff); //requires auth if viewers restricted, requires VIEW permission

    app.get('/dashboards/:name/likes', dashboards.getLikes); //TODO it shows user profiles, disable?
    app.post('/dashboards/:name/likes', requiresAuth, dashboards.likeDashboard);
    app.delete('/dashboards/:name/likes', requiresAuth, dashboards.unlikeDashboard);
    app.all('/dashboards/:name/likes', notAllowed);

    app.get('/dashboardnames', dashboards.getNames);
    app.all('/dashboardnames', notAllowed);

    app.get('/tags', tags.get);
    app.all('/tags', notAllowed);

    app.get('/searchhints', tags.getSearchHints);
    app.all('/searchhints', notAllowed);

    app.post('/export/data', exporter.dataAsync); //NOTE receives some data, writes it to a file and returns a download url (/exports/{filekey})
    app.get('/export/:name/pdf', exporter.pdf); //requires auth if viewers restricted, requires VIEW permission
    app.post('/export/:name/pdf', exporter.pdfAsync); //requires auth if viewers restricted, requires VIEW permission
    app.all('/export/:name/pdf', notAllowed);
    app.all('/export', notAllowed);

    app.all('/exportstatus/:key', exporter.status);

    app.get('/exports/:file', exporter.serve);

    app.post('/proxy', proxy.proxy); //NOTE encrypts a request (used for datasources)

    app.get('/users', users.get); //TODO it shows all user profiles, restrict access to admin? never used by client
    app.get('/users/search', requiresAuth, users.search);
    app.get('/users/oauth', oauth.login);
    app.get('/users/:name', users.getSingle); //TODO it shows user profile given a username, restrict access? never used by client

    app.post('/users/login', users.login);
    app.all('/users/login', notAllowed);
    app.post('/users/validate', users.validate); //validates a session key
    app.all('/users/validate', notAllowed);
    app.all('/users/logout', users.logout); //removes a session by session key

    app.get('/ldap/search', ldap.search);

    app.get('/crypto/ciphers', crypto.ciphers); //returns ciphers used by crypto algorithms (never used in client)
    app.post('/crypto/encrypt', crypto.encrypt); //encrypts a string (can be used for some datasource properties)
    app.all('/crypto/*', notAllowed);

    app.post('/wms', wms.getFeatureInfo);

    /* Enable analytics via Config */
    if (config.analytics && config.analytics.enable == true) {
        var analytics = null;
        var statistics = null;
        
        /* Load Analytics backend: Elasticsearch or MongoDB (default) */
        if (config.analytics.analyticsEngine == 'elasticsearch') {
            analytics = require('./api.analytics-elasticsearch.js');
            statistics = require('./api.statistics-elasticsearch.js');
        } else {
            analytics = require('./api.analytics.js');
            statistics = require('./api.statistics.js');
        }

        app.get('/statistics', statistics.get);
    
        app.post('/analytics/pageviews', analytics.recordPageView);
        app.get('/analytics/pageviews/recent', requiresAuth, requiresPermission, analytics.getRecentPageViews);

        app.post('/analytics/datasources', analytics.recordDataSource);
        app.get('/analytics/datasources/recent', requiresAuth, requiresPermission, analytics.getRecentDataSources);

        app.post('/analytics/events', analytics.recordEvent);
        app.get('/analytics/events/recent', analytics.getRecentEvents);

        app.get('/analytics/pageviewsovertime', requiresAuth, requiresPermission, analytics.getPageViewsOverTime);
        app.get('/analytics/visitsovertime', requiresAuth, requiresPermission, analytics.getVisitsOverTime);
        app.get('/analytics/uniquevisitors', requiresAuth, requiresPermission, analytics.getUniqueVisitors);
        app.get('/analytics/browsers', requiresAuth, requiresPermission, analytics.getBrowserStats);
        app.get('/analytics/widgets', requiresAuth, requiresPermission, analytics.getWidgetStats);

        app.get('/analytics/datasourcesbytype', requiresAuth, requiresPermission, analytics.getDataSourcesByType);
        app.get('/analytics/datasourcesbyname', requiresAuth, requiresPermission, analytics.getDataSourcesByName);
        app.get('/analytics/datasourcesbyerrormessage', requiresAuth, requiresPermission, analytics.getDataSourcesByErrorMessage);

        app.get('/analytics/pageviewsbypage', requiresAuth, requiresPermission, analytics.getPageViewsByPage);

        app.get('/analytics/topdashboards', analytics.getTopDashboards);

        app.get('/analytics/delete', analytics.deleteAnalyticsForDashboard); //allowed only if ADMIN
    }
    app.all('/analytics', notAllowed);
    app.all('/analytics/*', notAllowed);

    app.get('/data', data.get);
    app.post('/data', data.putPostSingle);
    app.all('/data', notAllowed);

    app.get('/data/:key', data.getSingle);
    app.post('/data/:key', notAllowed);
    app.put('/data/:key', data.putPostSingle);
    app.delete('/data/:key', data.deleteSingle);

    app.get('/data/:key/data', data.getSingleData);
    app.put('/data/:key/data', data.putData);
    app.post('/data/:key/append', data.appendData);
    app.post('/data/:key/upsert', data.upsertData);
    app.post('/data/:key/remove', data.removeData);
};
