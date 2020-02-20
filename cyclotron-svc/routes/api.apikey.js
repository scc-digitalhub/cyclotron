
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
    api = require('./api'),
    passport = require('passport'),
    auth = require('./auth'),
    mongoose = require('mongoose'),
    request = require('request'),
    Promise = require('bluebird');



// /* Retrieve info associated to OAuth2 token. */
// exports.checkApiKey = function (key) {
//     console.log("check apikey for " + key);

//     var options = {
//         url: config.oauth.apikeyCheckEndpoint + '?apiKey=' + key,
//         headers: {
//             'Accept': 'application/json'
//         }
//     };

//     return new Promise(function (resolve, reject) {
//         request(options, function (error, response, body) {
//             if (!error && response.statusCode == 200) {
//                 var info = JSON.parse(response.body);
//                 resolve(info);
//             } else {
//                 console.log(error);
//                 reject('error validating apikey');
//             }
//         });
//     });
// };
