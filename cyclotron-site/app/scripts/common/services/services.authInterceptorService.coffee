###
# HTTP interceptor
###
cyclotronServices.factory 'authInterceptorService', ($injector, $location, configService) ->
    interceptor = {
        request: (config) ->
            userService = $injector.get('userService')

            ###possible check for apikey at every request
            if $location.search().apikey?
                console.log 'apikey', $location.search().apikey
            ###

            #if config.url.startsWith(configService.restServiceUrl)
            #    console.log 'request intercepted', config.url, config.params, 'logged in?', userService.isLoggedIn()
            
            return config
    }

    return interceptor