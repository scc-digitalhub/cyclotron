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
 
/* Session middleware
 * 
 * If `session` is provided in the query string, the session key will be used to
 * load a Session object from the database.  The Session will be attached to the 
 * request.
 * 
 * If an invalid session key is provided, error 401 will be returned.
 */
var auth = require('../routes/auth.js'),
    moment = require('moment'),
    usersAPI = require('../routes/api.users.js');

exports.sessionLoader = function(req, res, next) {
    var errorHandler = function(error){
        console.log(error);
        res.status(500).send(error);
    }

    /* If ?session= provided, attempt to load it into req.session and req.user */
    console.log('Authentication middleware. Session:', req.query.session, 'Apikey:', req.query.apikey, 'Header:', req.header('Authorization'));
    if (req.query.session != undefined) {
        auth.validateSession(req.query.session)
        .then(function (session) {
            req.session = session;
            req.user = session.user;
            next();
        })
        .catch(function () {
            res.status(401).send('Authentication failed: session key provided but not valid.');
        });
    } else if (req.header('Authorization')) {
        //getTokenInfo to verify token type, if necessary check profile and roles and create session
        var bearer = req.header('Authorization');

        auth.getTokenInfo(bearer).then(function(info){
            if(!info.valid){
                res.status(401).send('Authentication failed: token provided but not valid.');
            } else {
                auth.findSession('token', bearer.split(' ')[1])
                .then(function(session){
                    req.session = session;
                    req.user = session.user;
                    next();
                })
                .catch(function(err){
                    if(info.applicationToken){
                        /* Handle client credentials flow */
                        console.log('Session not found, proceed to creating it');
                        auth.getUserRoles(bearer, true).then(function(roles){
                            //create fake user, and assign roles
                            var user = {
                                sAMAccountName: 'client-' + info.username,
                                displayName: 'client-' + info.username,
                                distinguishedName: 'client-' + info.username,
                                mail: 'client-' + info.username,
                                memberOf: auth.setUserMembership(roles)
                            }

                            var tokenExpir = moment().add(info.validityPeriod, 'seconds').subtract(1, 'hours').toDate();
                            //create or update user, create session
                            usersAPI.createSession(user, req.ip, 'token', bearer.split(' ')[1], tokenExpir)
                            .then(function(session){
                                req.session = session;
                                req.user = session.user;
                                next();
                            }, errorHandler);
                        }, errorHandler);
                    } else {
                        /* Handle implicit flow */
                        console.log('Session not found, proceed to creating it');
                        auth.getUserProfile(bearer).then(function(user){
                            auth.getUserRoles(bearer).then(function(roles){
                                user.memberOf = auth.setUserMembership(roles);
                                var tokenExpir = moment().add(info.validityPeriod, 'seconds').subtract(1, 'hours').toDate();
                                
                                //create or update user, create session
                                usersAPI.createSession(user, req.ip, 'token', bearer.split(' ')[1], tokenExpir)
                                .then(function(session){
                                    req.session = session;
                                    req.user = session.user;
                                    next();
                                }, errorHandler);
                            }, errorHandler);
                        }, errorHandler);
                    }
                });
            }
        }, errorHandler);
    } else if (req.query.apikey != undefined) {
        var apikey = req.query.apikey;
        auth.checkApiKey(apikey).then(function(keyInfo){
            auth.findSession('apikey', apikey)
            .then(function(session){
                req.session = session;
                req.user = session.user;
                next();
            })
            .catch(function(err){
                console.log('Apikey session not found, proceed to creating it');
                var user = {
                    sAMAccountName: keyInfo.username,
                    displayName: keyInfo.username,
                    distinguishedName: keyInfo.username,
                    mail: keyInfo.username,
                    memberOf: auth.setUserMembership(keyInfo.roles)
                }

                var keyExpir = moment().add(keyInfo.validity, 'seconds').subtract(1, 'hours').toDate();
                //create or update user, create session
                usersAPI.createSession(user, req.ip, 'apikey', apikey, keyExpir)
                .then(function(session){
                    req.session = session;
                    req.user = session.user;
                    next();
                }, errorHandler);
            })
        }, errorHandler);
    } else {
        next();
    }
};
