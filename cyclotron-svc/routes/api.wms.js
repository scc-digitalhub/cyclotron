/*
 * Retrieve feature info from WMS server in JSON format
 */

var request = require('request'),
    _ = require('lodash');

exports.getFeatureInfo = function (req, res) {
    if (req.body && req.body.url && !_.isEmpty(req.body.url)){
        var url = req.body.url;
        console.log('url received:', url);
        request({url: url}, function(error, response, body){
            if (error){
                console.log('error:', error);
                return res.status(500).send(error);
            } else {
                try {
                    res.send(JSON.parse(body));
                } catch (err) {
                    console.log(err.message);
                    res.status(400).send('Response body cannot be parsed as JSON');
                }
            }
        });
    };
};