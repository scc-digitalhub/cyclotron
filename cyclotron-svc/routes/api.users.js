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
 * API for Users and Session Management
 */

var config = require('../config/config'),
    _ = require('lodash'),
    api = require('./api'),
    passport = require('passport'),
    auth = require('./auth'),
    mongoose = require('mongoose'),
    request = require('request'),
    Promise = require('bluebird');

var crypto = require('crypto'); 
    
var Users = mongoose.model('user');
    Sessions = mongoose.model('session');

var createSession = exports.createSession = function (user, ip, type = null, value = null, expiration = null) {
    /* Ensure memberOf list is an array */
    var userMemberOf = user.memberOf || []
    if (_.isString(userMemberOf)) {
        userMemberOf = [userMemberOf];
    }

    var email = null;
    var emailHash = null;

    if (!_.isUndefined(user.mail)) {
        email = user.mail.trim().toLowerCase();
        emailHash = crypto.createHash('md5').update(email).digest('hex')
    }

    /* Logged In, Store User in /users */
    return Users.findOneAndUpdateAsync({ sAMAccountName: user.sAMAccountName }, { 
        $set: {
            name: user.displayName,
            sAMAccountName: user.sAMAccountName,
            email: email,
            emailHash: emailHash,
            distinguishedName: user.distinguishedName,
            givenName: user.givenName || user.displayName,
            title: user.title || null,
            department: user.department || null,
            division: user.division || null,
            lastLogin: new Date(),
            memberOf: userMemberOf
        }, 
        $inc: { 
            timesLoggedIn: 1 
        },
        $setOnInsert: {
            firstLogin: new Date()
        }
    }, { 
        new: true,
        upsert: true
    })
    .then(_.partial(auth.createNewSession, ip, type, value, expiration))
    .spread(function (session) {
        return session.populateAsync('user');
    });
}

/* Gets all Users */
exports.get = function (req, res) {
    Users.find().exec(_.wrap(res, api.getCallback));
};

/* Gets a single User */
exports.getSingle = function (req, res) {
    var name = req.params.name.toLowerCase();
    Users.findOne({ sAMAccountName: name }).exec(_.wrap(res, api.getCallback));
};

/* Login as a User */
exports.login = function (req, res) {

    /* Handle DOMAIN/username and DOMAIN\username by stripping off the DOMAIN */
    if (req.body.username != null) {
        var split = req.body.username.split(/\\|\//);
        if (split.length > 1) {
            req.body.username = split[1];
        }
    }

    passport.authenticate('ldapauth', function (err, user, info) {

        if (err) {
            console.log(err);
            return res.status(500).send('Authentication error: ' + err);
        }
        if (!user) {
            return res.status(401).send('Authentication failure: invalid user or password.');
        }

        createSession(user, req.ip).then(function (session) {
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
        })
        .catch(function (err) {
            console.log(err);
            res.status(500).send(err);
        });
    })(req, res);
};

/* Test a Session key for validity, returning the Session if valid. */
exports.validate = function (req, res) {
    var key = req.body.key;

    if (_.isNull(key)) {
        return res.status(400).send('No session key provided.');
    }

    auth.validateSession(key).then(function (session) {
        res.send(session);
    }).catch(function (err) {
        res.status(403).send(err);
    });
};

/* Logout of an active Session */
exports.logout = function (req, res) {
    var key = req.body.key;

    if (_.isNull(key)) {
        return res.status(400).send('No session key provided.');
    }

    auth.removeSession(key).then(function (session) {
        if (_.isNull(session)) {
            res.status(401).send('Session not found.');
        } else {
            req.logout();
            res.send('OK');
        }
    }).catch(function (err) {
        res.status(500).send(err);
    });
};

exports.oauthLogin = function (req, res) {
    console.log('is already done:', req.session, req.user);
    if(req.header('Authorization')){
        try {
            var session = req.session;
            session.user.admin = _.includes(config.admins, session.user.distinguishedName);

            req.login(session.user, { session: false }, function (err) {
                if (err) {
                    console.log(err);
                    res.status(500).send(err);
                } else {
                    console.log('sending session as response');
                    res.send(session);
                }
            });

            // Cleanup expired sessions
            auth.removeExpiredSessions();
        }
        catch(e) {
            console.log(e);
            res.status(500).send(e);
        }
    } else {
        console.log('Authorization header missing from request');
        res.status(401).send('Authorization header missing from request');
    }
};

exports.search = function (req, res) {
    var nameFilter = req.query.q || ''
    var permissionFilter = '_' + req.query.permission //possible value: editors, viewers
    var sessionKey = req.query.session || req.session.key

    Sessions.findOne({key: sessionKey})
    .populate('user')
    .exec()
    .then(function (session) {
        if (session == null) {
            return res.status(500).send('Invalid session key');
        }

        var groups = _.filter(session.user.memberOf, function(group){
            var allowed = true;
            //exclude viewers-only if searching for editors
            if(permissionFilter == '_editors' && !_.includes(group, permissionFilter)) { allowed = false};
            return allowed;
        });
        //TODO if user is not member of any group, can he give permissions?
        var allowedGroups = _.filter(groups, function(group){
            //exclude groups that do not contain the query string
            return _.includes(group, nameFilter);
        });
        
        Users.find({
            memberOf: {$in: groups},
            $or: [ { sAMAccountName: { $regex: nameFilter} }, { displayName: { $regex: nameFilter} } ]
        })
        .lean()
        .exec()
        .then(function(results){
            if(results == []){
                console.log('No users found that match the search string and are members of the allowed groups');
            }
            //categories: Security Group, Group, User, Distribution List
            _.each(results, function(user){
                user.category = 'User';
                user.displayName = user.name || user.givenName;
                user.mail = user.email;
                user.dn = user.distinguishedName;
            });
            
            //add groups to result
            _.each(allowedGroups, function(group){
                results.push({
                    category: 'Group',
                    dn: group,
                    displayName: group.split('_')[0]
                })
            })
            res.send(results);
        });
    });

};