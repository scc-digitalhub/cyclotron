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

var config = require('./config/config');

var _ = require('lodash'),
    express = require('express'),
    morgan = require('morgan'),
    errorHandler = require('errorhandler'),
    bodyParser = require('body-parser'),
    compression = require('compression'),
    serveStatic = require('serve-static');

var mongo = require('./mongo');

var app = module.exports = express();

app.enable('trust proxy');
app.set('port', process.env.PORT || config.port);

app.use(morgan('combined'));
app.use(compression());

/* Support for non-Unicode charsets (e.g. ISO-8859-1) */
app.use(bodyParser.text({ 
    type: '*/*', 
    limit: (config.requestLimit || '1mb') 
}));

app.use(function(req, res, next) {
    if (req.is('application/json')) {
        req.body = req.body ? JSON.parse(req.body) : {}
    }
    next();
});

/* API Documentation */
app.use(serveStatic(__dirname + '/docs'));

/* Cross-origin requests */
var cors = require('./middleware/cors');
app.use(cors.allowCrossDomain);

/* Optional: Authentication */
if (config.enableAuth == true) {
    /* Custom session management */
    var session = require('./middleware/session');
    app.use(session.sessionLoader);

    /* Passport.js LDAP authentication */
    var passport = require('passport'),
        LdapStrategy = require('passport-ldapauth'),
        OAuth2Strategy = require('passport-oauth').OAuth2Strategy,
        request = require('request');

    app.use(passport.initialize());

    passport.use(new LdapStrategy({
        server: {
            url: config.ldap.url,
            bindDn: config.ldap.adminDn,
            bindCredentials: config.ldap.adminPassword,
            searchBase: config.ldap.searchBase,
            searchFilter: config.ldap.searchFilter
        },
        usernameField: 'username',
        passwordField: 'password'
    }));

    /*
    OAuth2Strategy.prototype.userProfile = function(accessToken, done){
        console.log('strategy prototype');
        var options = {
            url: config.oauth.userProfileEndpoint,
            headers: {
                'User-Agent': 'request',
                'Authorization': 'Bearer ' + accessToken,
            }
        };

        request(options, function(error, response, body){
            console.log('callback of request to profile', body);
            if(error || response.statusCode !== 200){
                console.log('there is an error');
                return done(error);
            };
            var info = JSON.parse(body);
            return done(null, info.user);
        });
    }
    */

    passport.serializeUser(function(user, done){
        done(null, user);
    });

    passport.deserializeUser(function(obj, done){
        done(null, obj);
    });

    passport.use('provider', new OAuth2Strategy({
            authorizationURL: config.oauth.authorizationURL,
            tokenURL: config.oauth.tokenURL,
            clientID: config.oauth.clientID,
            clientSecret: config.oauth.clientSecret,
            callbackURL: config.oauth.callbackURLServer + '/auth/provider/callback',
            passReqToCallback: true
        },
        function(req, accessToken, refreshToken, profile, done){
            console.log('verify callback:', accessToken, refreshToken, profile);
            process.nextTick(function(){
                req.session.accessToken = accessToken;
                return done(null, profile);
            });
        }
    ));
}

/* Optional: Analytics */
if (config.analytics && config.analytics.enable == true) {
    if (config.analytics.analyticsEngine == 'elasticsearch') {
        /* Initialize Elasticsearch for Analytics */
        var elasticsearch = require('./elastic');
    }
}

/* Initialize SSL root CAs */
var cas = require('ssl-root-cas/latest')
  .inject();

/* Optional: Load Additional Trusted Certificate Authorities */
if (_.isArray(config.trustedCa) && !_.isEmpty(config.trustedCa)) {
    _.each(config.trustedCa, function(ca) {
        console.log('Loading trusted CA: ' + ca);
        cas.addFile(ca);
    });
}

if ('development' == app.get('env')) {
  app.use(errorHandler());
}

/* Initialize JSON API */
var api = require('./routes/api');
api.bindRoutes(app);

/* Start server */
var port = app.get('port');
app.listen(port, function(){
    console.log('Cyclotron running on port %d', port);
});
