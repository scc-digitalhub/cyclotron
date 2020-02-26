
/*******************************************************************************
 * Copyright 2020 Fondazione Bruno Kessler
 * 
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 * 
 *        http://www.apache.org/licenses/LICENSE-2.0
 * 
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 ******************************************************************************/

/* 
* API for APIKEY operations
* 
*/

var config = require('../config/config'),
    _ = require('lodash'),
    apiUsers = require('./api.users.js'),
    moment = require('moment'),
    auth = require('./auth'),
    request = require('request'),
    Promise = require('bluebird');


/*
* OAuth2 
*/
exports.login = function (req, res) {
    if (req.query.apikey != undefined) {
        //fetch from param
        var apikey = req.query.apikey;

        //TODO implement a session.maxDuration property and check apiKey
        //for now use a fixed duration
        var sessionExpire = moment().add(config.apikey.validity, 'seconds').toDate();

        validateApiKey(apikey)
            .then(function (info) {
                console.log(info);

                //extract normalized roles
                var roles = [];
                _.each(info.roles, function (r) {
                    roles.push(r.authority);
                });

                //build user object 
                var u = {
                    sAMAccountName: info.userId,
                    displayName: info.username,
                    distinguishedName: info.username,
                    email: null,
                    memberOf: getUserMembership(roles)
                }

                return u;

            })
            .then(function (user) {
                console.log(user);
                return user;
            })
            .then(user => apiUsers.createSession(user, req.ip, 'apikey', apikey, sessionExpire))
            .then(function (session) {
                //TODO evaluate if apiKey access supports admin
                //disabled for now
                //session.user.admin = _.includes(config.admins, session.user.distinguishedName);

                /* Finally, passport.js login */
                req.login(session.user, { session: false }, function (err) {
                    if (err) {
                        console.log(err);
                        res.status(500).send(err);
                    } else {
                        res.send(session);
                    }
                });

                /* Cleanup expired sessions */
                auth.removeExpiredSessions();

                return session;
            })
            .catch(function (error) {
                console.log(error);
                res.status(500).send(error);
            });

    } else {
        console.log('Api key parameter missing from request');
        res.status(401).send('Api key parameter missing from request');
    }

}

/* Retrieve info associated to OAuth2 token. */
var validateApiKey = function (key) {
    console.log("check apikey for " + key);


    var options = {
        url: config.apikey.apikeyCheckEndpoint + '?apiKey=' + key,
        headers: {
            'Accept': 'application/json',
            'Authorization': "Basic " + new Buffer(config.oauth.clientId + ":" + config.oauth.clientSecret).toString("base64")
        }
    };


    return new Promise(function (resolve, reject) {
        request(options, function (error, response, body) {
            if (!error && response.statusCode == 200) {
                var info = JSON.parse(response.body);
                resolve(info);
            } else {
                console.log(error);
                reject('error validating apikey');
            }
        });
    });
};


/* Receives an array of AAC roles and converts them to groups */
var getUserMembership = function (roles) {
    //["components/cyclotron/<group>:ROLE_PROVIDER"]
    console.log("filter roles for " + config.oauth.parentSpace)
    var groups = [];
    var rolesFiltered = _.filter(roles, function (role) {
        return role.startsWith(config.oauth.parentSpace) && role.includes(':');
    });
    console.log(rolesFiltered);
    _.each(rolesFiltered, function (r) {
        var authority = r.slice(config.oauth.parentSpace.length).split(':');
        var group = authority[0];
        var role = authority[1];
        if (group.startsWith('/')) { group = group.slice(1) }

        if (group.length > 0) {
            var suffix = '_viewers';
            //TODO evaluate if editor access is supported via apiKey
            //disabled now
            // //check if role matches one of editors
            // if (_.includes(config.oauth.editorRoles, role)) {
            //     suffix = '_editors';
            // }

            groups.push(group + suffix);
            //edit permission implies also viewing permission
            if (suffix == '_editors') {
                groups.push(group + '_viewers');
            }
        }
    });

    return groups;
};
