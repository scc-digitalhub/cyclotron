###
# HTTP interceptor
###
cyclotronServices.factory 'authInterceptorService', ($injector, $q, $window, $location, configService) ->
    interceptor = {
        request: (config) ->
            userService = $injector.get('userService')
            #http = $injector.get('$http')
            #deferred = $q.defer()

            ###possible check for apikey at every request
            if $location.search().apikey?
                console.log 'apikey', $location.search().apikey
            ###
            if config.url.startsWith(configService.restServiceUrl)
                console.log 'request intercepted', config.url, config.params, 'logged in?', userService.isLoggedIn()
            ###
            if config.url.startsWith(configService.restServiceUrl) and
            configService.authentication.enable == true and userService.isLoggedIn()
                token = if $window.Storage? then $window.sessionStorage.getItem 'accessToken'

                if token?
                    #check if token is still valid or expired
                    url = configService.authentication.tokenValidityEndpoint + '?scope='
                    scopes = configService.authentication.scopes.split(' ')
                    for scope in scopes
                        url = url + scope
                        if _.indexOf(scopes, scope) < (scopes.length - 1)
                            url = url + ','
                    
                    validation = http({
                        method: 'GET'
                        url: url
                        headers:
                            'Accept': 'application/json',
                            'Authorization': 'Bearer ' + token
                    })

                    validation.success (response) ->
                        console.log 'token valid?', response
                        valid = response
                        if valid
                            console.log 'setting header for', token
                            config.headers.Authorization = 'Bearer ' + token
                            deferred.resolve config
                        else
                            #logout and redirect to login page
                            console.log 'token not valid'
                            userService.logout()
                            $location.path('/')
                            deferred.reject 'token not valid'
                else
                    console.log 'WARNING: token not found in session storage'
                    deferred.reject 'token not found'
            else
                deferred.resolve config
            
            return deferred.promise
            ###
            return config
    }

    return interceptor