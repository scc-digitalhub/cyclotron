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

/* 
 * Service for authentication/authorization.
 */

var config = require('../config/config'),
    _ = require('lodash'),
    api = require('./api'),
    mongoose = require('mongoose'),
    moment = require('moment'),
    uuid = require('node-uuid'),
    Promise = require('bluebird'),
    request = require('request');

var Sessions = mongoose.model('session');
var Dashboards = mongoose.model('dashboard2');

var getExpiration = function () {
    return moment().add(24, 'hour').toDate();
}

/* Removes all Sessions for a given username. */
exports.removeActiveSessions = function (username) {
    return Sessions.removeAsync({ sAMAccountName: username });
};

/* Removes a specific Session from the database. */
exports.removeSession = function (key) {
    return Sessions.findOneAndRemoveAsync({ key: key });
};

/* Removes all expired Sessions from the database. */
exports.removeExpiredSessions = function () {
    return Sessions.removeAsync({
        expiration: { $lt: Date.now() }
    });
};

/* Creates, saves, and returns a new Session. 
 * Value is either the session key (for access via credentials), the API key (for apikey sessions) or the access token (for token sessions).
 */
exports.createNewSession = function (ipAddress, sessionType, value, expiration, user) {
    var key = uuid.v4();
    var session = new Sessions({
        key: key,
        sAMAccountName: user.sAMAccountName,
        user: user._id,
        ipAddress: ipAddress,
        expiration: expiration || getExpiration(),
        type: sessionType || 'credentials',
        value: value || key
    });

    return session.saveAsync();
};

// /* Find a Session by type and value. */
// exports.findSession = function (type, value) {
//     return new Promise(function(resolve, reject){
//         Sessions.findOne({
//             type: type,
//             value: value
//         })
//         .populate('user')
//         .exec()
//         .then(function (session) {
//             if (session == null) {
//                 reject('Session invalid');
//             }
//             resolve(session);
//         });
//     });

// };

/* Validate and extend Session. */
exports.validateSession = function (key) {
    return new Promise(function (resolve, reject) {
        Sessions.findOne({
            key: key,
            expiration: { $gt: Date.now() }
        })
            .populate('user')
            .exec()
            .then(function (session) {
                if (session == null) {
                    reject('Session invalid');
                }

                //for sessions created via login with credentials, extend validity
                if (session.type == 'credentials') {
                    Sessions.updateOne({ key: key }, { $set: { expiration: getExpiration() } }).exec()
                }

                session.user.admin = _.includes(config.admins, session.user.distinguishedName);
                resolve(session);
            });
    });
    /*
    return new Promise(function (resolve, reject) {
        Sessions.findOneAndUpdate({ 
            key: key, 
            expiration: { $gt: Date.now() } 
        }, {
            $set: {
                expiration: getExpiration()
            }
        })
        .populate('user')
        .exec()
        .then(function (session) {
            if (session == null) {
                reject('Session invalid');
            }

            session.user.admin = _.includes(config.admins, session.user.distinguishedName);
            resolve(session);
        });
    });
    */
};

/* Returns true if the current user is unauthenticated, else false. */
exports.isUnauthenticated = function (req) {
    if (config.enableAuth != true) {
        /* Short-circuit if authentication is disabled */
        return false;
    }

    // //req.session is set by session middleware if session key param is present
    // return _.isUndefined(req.session);

    //req.user is set by middleware
    return _.isUndefined(req.user);
};

/* Returns true if the current user has admin permissions */
exports.isAdmin = function (req) {
    if (config.enableAuth != true) {
        /* Short-circuit if authentication is disabled */
        return true;
    }

    if (req.user == null) {
        return false;
    }

    var user = req.user;

    if (_.includes(config.admins, user.distinguishedName)) {
        return true;
    }

    return false;
};

/* Returns true if the current user has permission to edit the given dashboard, else false. */
exports.hasEditPermission = function (dashboard, req) {
    if (config.enableAuth != true) {
        /* Short-circuit if authentication is disabled */
        return true;
    }

    if (req.user == null) {
        return false;
    }

    var user = req.user;

    /* By default, everyone can edit */
    if (_.isEmpty(dashboard.editors)) {
        return true;
    }

    /* Admin override */
    if (_.includes(config.admins, user.distinguishedName)) {
        console.log('Has permission due to ADMIN');
        return true;
    }

    /* If user is in Editors, or a member of a group that is */
    return _.some(dashboard.editors, function (editor) {
        if (user.distinguishedName === editor.dn ||
            _.includes(user.memberOf, editor.dn)) {
            console.log('Has Permission due to ' + editor.dn);
            return true;
        }
    });
};

/* Returns true if the current user has permission to view the given dashboard, else false. */
exports.hasViewPermission = function (dashboard, req) {
    if (config.enableAuth != true) {
        /* Short-circuit if authentication is disabled */
        return true;
    }

    if (req.user == null) {
        return false;
    }

    var user = req.user;

    /* By default, everyone can view */
    if (_.isEmpty(dashboard.viewers)) {
        return true;
    }

    /* Admin override */
    if (_.includes(config.admins, user.distinguishedName)) {
        console.log('Has permission due to ADMIN');
        return true;
    }

    /* All Editors can View */
    if (exports.hasEditPermission(dashboard, req)) {
        return true;
    }

    /* If user is in Viewers, or a member of a group that is */
    return _.some(dashboard.viewers, function (viewer) {
        if (user.distinguishedName === viewer.dn ||
            _.includes(user.memberOf, viewer.dn)) {
            console.log('Has Permission due to ' + viewer.dn);
            return true;
        }
    });
};

/* Retrieves the user id for the current user. */
exports.getUserId = function (req) {
    if (req.user != null) {
        //TODO extend for non-session based users
        return req.user._id;
    } else {
        return null;
    }
};

/* Retrieves the current user. */
exports.getUser = function (req) {
    if (req.user != null) {
        return req.user;
    } else {
        return null;
    }
};


//TODO move to another file
/* Find a Dashboard by id. */
exports.findDashboardById = function (id) {
    return new Promise(function (resolve, reject) {
        Dashboards.findById(id)
            .exec()
            .then(function (dashboard) {
                if (dashboard == null) {
                    reject('Dashboard ID invalid');
                }
                resolve(dashboard);
            });
    });
};