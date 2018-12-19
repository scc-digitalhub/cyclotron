#
# Functions related to OpenLayers widget
#

cyclotronServices.factory 'openLayersService', ($http, $q, configService) ->
    exports = {

        getFeatureInfoJson: (source, layer, coordinate, resolution, projection) ->
            params = {'INFO_FORMAT': 'application/json', 'QUERY_LAYERS': layer}
            url = source.getGetFeatureInfoUrl(coordinate, resolution, projection, params)
            
            post = $http.post(configService.restServiceUrl + '/wms', { url })

            deferred = $q.defer()

            post.success (data) ->
                deferred.resolve(data)
            
            post.error (error) ->
                deferred.reject(error)
            
            return deferred.promise
    }

    return exports
