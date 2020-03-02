
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
    Promise = require('bluebird'),
    jwks = require('jwks-rsa'),
    jwt = require('jsonwebtoken');




/*
* OAuth2 
*/
exports.login = function (req, res) {

    //TODO rework to clear up callback..
    if (req.header('Authorization')) {
        //extract token 
        var bearer = req.header('Authorization');
        token = bearer.replace("Bearer ", "");

        //TODO implement a session.maxDuration property and check
        var sessionExpire = moment().add(1, 'hours').toDate();
        var userp;

        //check JWT
        if (config.oauth.useJWT === true) {
            userp = new Promise(
                function (resolve, reject) {
                    //parse as JWT
                    resolve(jwt.decode(token, { complete: true, json: true }));
                })
                .then(function (decoded) {
                    console.log(decoded);
                    var tokenExpire = moment.unix(decoded.payload.exp).toDate();
                    console.log("set expire to " + tokenExpire);
                    sessionExpire = tokenExpire;
                    return decoded;
                })
                .then(function (decoded) {
                    if (_.isEmpty(config.oauth.jwksEndpoint)) {
                        //use clientSecret as key
                        return config.oauth.clientSecret;
                    } else {
                        return getJWKey(decoded.header);
                    }
                }).then(function (verifyKey) {
                    //verify sync, will throw error if invalid
                    var voptions = {
                        'audience': config.oauth.clientId
                    }
                    if (!!config.oauth.issuer) {
                        voptions['issuer'] = config.oauth.issuer;
                    }
                    var payload = jwt.verify(token, verifyKey, voptions);
                    console.log("token is valid");

                    //build user object 
                    var u = {
                        sAMAccountName: payload.sub,
                        displayName: payload.name,
                        distinguishedName: payload.username,
                        email: payload.email,
                        memberOf: getUserMembership(payload.roles)
                    }

                    return u;

                }).catch(function (error) {
                    console.log(error);
                    return error;
                });

        } else {
            //validate via introspection
            userp = getTokenInfo(token)
                .then(function (info) {
                    console.log(info);
                    var tokenExpire = moment.unix(info.exp).toDate();
                    return tokenExpire;
                })
                .then(function (tokenExpire) {
                    console.log("set expire to " + tokenExpire);
                    sessionExpire = tokenExpire;
                    return sessionExpire;
                })
                .then(() => getUserProfile(token))
                .then(function (profile) {
                    console.log(profile)
                    //build user object 
                    var u = {
                        sAMAccountName: profile.sub,
                        displayName: profile.name,
                        distinguishedName: profile.username,
                        email: profile.email,
                        memberOf: getUserMembership(profile.roles)
                    }

                    return u;
                }).catch(function (error) {
                    console.log(error);
                    return error;
                });

        }

        //build session for user
        userp
            .then(function (user) {
                if (!_.has(user, 'sAMAccountName', 'displayName', 'distinguishedName')) {
                    throw 'invalid user';
                }
                console.log(user);
                return user;
            })
            .then(user => apiUsers.createSession(user, req.ip, 'token', token, sessionExpire))
            .then(function (session) {
                session.user.admin = _.includes(config.admins, session.user.distinguishedName);

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
                return res.status(500).send(error);
            });
    } else {
        console.log('Authorization header missing from request');
        return res.status(401).send('Authorization header missing from request');
    }
};


exports.getUserFromIntrospection = function (token) {
    return getTokenInfo(token)
        .then(() => getUserProfile(token))
        .then(function (profile) {
            console.log(profile)
            //build user object 
            var u = {
                sAMAccountName: profile.sub,
                displayName: profile.name,
                distinguishedName: profile.username,
                email: profile.email,
                memberOf: getUserMembership(profile.roles)
            }

            return u;
        }).catch(function (error) {
            console.log(error);
            return error;
        });
}


exports.getUserFromJWT = function (token) {
    return new Promise(
        function (resolve, reject) {
            //parse as JWT
            resolve(jwt.decode(token, { complete: true, json: true }));
        })
        .then(function (decoded) {
            if (_.isEmpty(config.oauth.jwksEndpoint)) {
                //use clientSecret as key
                return config.oauth.clientSecret;
            } else {
                return getJWKey(decoded.header);
            }
        }).then(function (verifyKey) {
            //verify sync, will throw error if invalid
            var voptions = {
                'audience': config.oauth.clientId
            }
            if (!!config.oauth.issuer) {
                voptions['issuer'] = config.oauth.issuer;
            }
            var payload = jwt.verify(token, verifyKey, voptions);
            console.log("token is valid");

            //build user object 
            var u = {
                sAMAccountName: payload.sub,
                displayName: payload.name,
                distinguishedName: payload.username,
                email: payload.email,
                memberOf: getUserMembership(payload.roles)
            }

            return u;

        }).catch(function (error) {
            console.log(error);
            return error;
        });
}

/* Get JWKS and extract RSA key */
var getJWKey = function (header) {
    var client = jwks({
        jwksUri: config.oauth.jwksEndpoint
    });

    return new Promise(function (resolve, reject) {
        client.getSigningKey(header.kid, function (err, key) {
            if (!err && key) {
                var signingKey = key.publicKey || key.rsaPublicKey;
                resolve(signingKey);
            } else {
                console.log(error);
                reject('error retrieving jwks');
            }
        });
    });
};


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

                //reject invalid tokens
                if (!info.active) {
                    reject('invalid token');
                } else {
                    resolve(info);
                }
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
        var authority = r.slice(config.oauth.parentSpace.length).split(':');
        var group = authority[0];
        var role = authority[1];
        if (group.startsWith('/')) { group = group.slice(1) }

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

