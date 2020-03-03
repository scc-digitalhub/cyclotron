
/* Api Key middleware
 * 
 * If an api key is provided via query param, try to validate with apiKey 
 * provider.
 * 
 * Do note that a user must ALREADY exists in cyclotron to be able to call 
 * the API via apikey. Login at least once via GUI to create the user.
 * 
 * If an invalid apikey is provided, error 401 will be returned.
 */
var apikeyAPI = require('../routes/api.apikey.js');

exports.apikeyLoader = function (req, res, next) {
    //skip requests directed to apikey login
    if (req.query.apikey != undefined && req.path != '/users/apikey') {
        var apikey = req.query.apikey;
        apikeyAPI.getUserFromApiKey(apikey)
            .then(function (user) {
                req.user = user;
                next();
            })
            .catch(function (error) {
                res.status(401).send('Authentication failed: apikey provided but not valid.');
            });
    } else {
        next();
    }

};


