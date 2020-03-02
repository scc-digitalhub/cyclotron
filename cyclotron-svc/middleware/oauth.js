
/* OAuth middleware
 * 
 * If a Bearer token is provided via Authorization header, try to validate with oauth 
 * provider via either JWT validation or Token Introspection.
 * 
 * Do note that a user must ALREADY exists in cyclotron to be able to call 
 * the API via token. Login at least once via GUI to create the user.
 * 
 * If an invalid Bearer token is provided, error 401 will be returned.
 */
var config = require('../config/config'),
    oauthAPI = require('../routes/api.oauth.js');

exports.oauthLoader = function (req, res, next) {

    if (req.header('Authorization')) {
        var bearer = req.header('Authorization');
        token = bearer.replace("Bearer ", "");
        var userp;
        //check JWT
        if (config.oauth.useJWT === true) {
            userp = oauthAPI.getUserFromJWT(token);
        } else {
            userp = oauthAPI.getUserFromIntrospection(token);
        }
        userp
            .then(function (user) {
                req.user = user;
                next();
            })
            .catch(function (error) {
                res.status(401).send('Authentication failed: token provided but not valid.');
            });
    } else {
        next();
    }

};


