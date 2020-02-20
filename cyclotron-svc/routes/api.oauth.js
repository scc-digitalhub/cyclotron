
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
* API for OAUTH2 operations
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

    if (req.header('Authorization')) {
        try {
            //extract token 
            var bearer = req.header('Authorization');
            token = bearer.replace("Bearer ", "");

            //TODO check if jwksUri provided, then try as JWT

            //validate via introspection
            getTokenInfo(token).then(function (info) {
                if (!info.active) {
                    res.status(401).send('Authentication failed: token provided but not valid.');
                } else {
                    var tokenExpire = moment.unix(info.exp).toDate();
                    //TODO implement a session.maxDuration property and check
                    var sessionExpire = tokenExpire;

                    //get userinfo
                    getUserProfile(token).then(function (profile) {
                        console.log(profile)
                        //build user object 
                        var user = {
                            sAMAccountName: profile.sub,
                            displayName: profile.name,
                            distinguishedName: profile.username,
                            email: profile.email,
                            memberOf: getUserMembership(profile.roles)
                        }

                        apiUsers.createSession(user, req.ip, 'token', token, sessionExpire).then(function (session) {
                            session.user.admin = _.includes(config.admins, session.user.distinguishedName);

                            /* Finally, passport.js login */
                            req.login(user, { session: false }, function (err) {
                                if (err) {
                                    console.log(err);
                                    res.status(500).send(err);
                                } else {
                                    res.send(session);
                                }
                            });

                            /* Cleanup expired sessions */
                            auth.removeExpiredSessions();
                        }).catch(function (err) {
                            console.log(err);
                            res.status(500).send(err);
                        });


                    }).catch(function (error) {
                        console.log(error);
                        res.status(500).send(error);
                    });


                }
            }).catch(function (error) {
                console.log(error);
                res.status(500).send(error);
            });

        }
        catch (e) {
            console.log(e);
            res.status(500).send(e);
        }
    } else {
        console.log('Authorization header missing from request');
        res.status(401).send('Authorization header missing from request');
    }
};


// exports.oauthLogin = function (req, res) {

//     if (req.header('Authorization')) {
//         try {
//             var session = req.session;
//             console.log(session);
//             session.user.admin = _.includes(config.admins, session.user.distinguishedName);

//             // Check that user roles are up to date
//             var bearer = req.header('Authorization');
//             auth.getUserRoles(bearer).then(function (roles) {
//                 session.user.memberOf = auth.setUserMembership(roles);
//                 console.log('user', session.user.memberOf, session.user.sAMAccountName);

//                 //save roles
//                 Users.update({ sAMAccountName: session.user.sAMAccountName }, { $set: { memberOf: session.user.memberOf } }).exec()

//                 //finish login
//                 req.login(session.user, { session: false }, function (err) {
//                     if (err) {
//                         console.log(err);
//                         res.status(500).send(err);
//                     } else {
//                         console.log('sending session with', session.user);
//                         res.send(session);
//                     }
//                 });
//             })
//                 .catch(function (error) {
//                     console.log(error);
//                     res.status(500).send(error);
//                 });

//             // Cleanup expired sessions
//             auth.removeExpiredSessions();
//         }
//         catch (e) {
//             console.log(e);
//             res.status(500).send(e);
//         }
//     } else {
//         console.log('Authorization header missing from request');
//         res.status(401).send('Authorization header missing from request');
//     }
// };

/* Retrieve info associated to OAuth2 token. */
var getTokenInfo = function (token) {
    console.log("get tokenInfo for " + token);

    // //cleanup token if passed via auth header
    // if(bearer.startsWith("Bearer ")) {
    //     bearer = bearer.replace("Bearer ", "");
    // }
    var options = {
        url: config.oauth.tokenIntrospectionEndpoint,
        headers: {
            'Accept': 'application/json',
            'Authorization': "Basic " + new Buffer(config.oauth.clientId + ":" + config.oauth.clientSecret).toString("base64")
        },
        form: {
            'token': token
        }
    };

    return new Promise(function (resolve, reject) {
        request.post(options, function (error, response, body) {
            if (!error && response.statusCode == 200) {
                var info = JSON.parse(response.body);
                resolve(info);
            } else {
                console.log(error);
                reject('error retrieving token info');
            }
        });
    });
};

/* Retrieve user profile from provider, w/roles. */
var getUserProfile = function (token) {
    console.log("get user profile for " + token);

    var options = {
        url: config.oauth.userProfileEndpoint,
        headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ' + token
        }
    };

    return new Promise(function (resolve, reject) {
        request(options, function (error, response, body) {
            console.log("userprofile is ")
            console.log(body)
            if (!error && response.statusCode == 200) {
                var profile = JSON.parse(response.body);
                resolve({
                    sub: profile.sub,
                    name: profile.name,
                    username: profile.username,
                    email: (_.has(profile, 'email') ? profile.email : profile.username),
                    roles: (_.has(profile, 'roles') ? profile.roles : []),
                    groups: (_.has(profile, 'groups') ? profile.groups : [])
                });
            } else {
                console.log(error);
                reject('error retrieving user profile');
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
        console.log(role);
        var authority = r.slice(config.oauth.parentSpace.length).split(':');
        var group = authority[0];
        var role = authority[1];
        if (group.startsWith('/')) { group = group.slice(1) }

        console.log('process group ' + group);
        if (group.length > 0) {
            var suffix = '_viewers';
            //check if role matches one of editors
            if (_.includes(config.oauth.editorRoles, role)) {
                suffix = '_editors';
            }

            groups.push(group + suffix);
            //edit permission implies also viewing permission
            if (suffix == '_editors') {
                groups.push(group + '_viewers');
            }
        }
    });

    return groups;
};


var validateJWTToken = function (token) {
    return new Promise(function (resolve, reject) {
        //TODO
    });
}