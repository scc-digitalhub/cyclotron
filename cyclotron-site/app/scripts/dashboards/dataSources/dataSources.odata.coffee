#
# OData Data Source
#
# Performs an HTTP action (GET, POST, etc), with various options.  
# 
# All options documented here are available: https://github.com/mikeal/request#requestoptions-callback
#
# Always proxies requests through the Cyclotron service.
#
# Properties:
#
cyclotronDataSources.factory 'odataDataSource', ($q, $http, configService, dataSourceFactory, logService) ->

    getProxyRequest = (options) ->
        url = new URI(_.jsExec options.url)

        if options.queryParameters?
            # Get and update existing query params (if any)
            queryParams = url.search(true)
            _.forIn options.queryParameters, (value, key) ->
                queryParams[_.jsExec(key)] = _.jsExec value

            url.search queryParams

        # Format: https://github.com/mikeal/request#requestoptions-callback
        proxyBody =
            url: url.toString()
            method: 'GET'
            json: true
            headers:
                'Accept': 'application/json, text/plain'

        if options.options?
            compiledOptions = _.compile(options.options, {})
            _.assign(proxyBody, compiledOptions)

        if options.awsCredentials?
            # Add required properties for AWS request signing
            proxyBody.host = url.hostname()
            proxyBody.path = url.path() + url.search()
            proxyBody.awsCredentials = options.awsCredentials

        return proxyBody
    
    processResponse = (response, responseAdapter, reject) ->
        # Convert the result based on the selected adapter
        switch responseAdapter
            when 'raw'
                return response
            when 'primitive_prop'
                return response.value
            when 'single_entity'
                #remove OData properties
                _.forIn response, (val, key) ->
                    if key.startsWith('@')
                        delete response[key]
                return response
            when 'entity_set'
                return response.value
            else
                reject('Unknown responseAdapter value "' + responseAdapter + '"')

    runner = (options) ->

        q = $q.defer()

        # Runner Failure
        errorCallback = (error, status) ->
            if error == '' && status == 0
                # CORS error
                error = 'Cross-Origin Resource Sharing error with the server.'

            q.reject error

        # Successful Result
        successCallback = (result) ->
            console.log 'data before any processing', _.cloneDeep(result.body)
            if result.body.error?
                logService.error result.body.error.message
                q.reject result.body.error.message
            else
                responseAdapter = _.jsExec options.responseAdapter
                data = processResponse result.body, responseAdapter, q.reject
                console.log 'data after processing', data
                if _.isNull data
                    logService.debug 'OData result is null.'
                    data = []

                q.resolve
                    '0':
                        data: data
                        columns: null

        # Generate proxy URLs
        proxyUri = new URI(_.jsExec(options.proxy) || configService.restServiceUrl)
            .protocol ''     # Remove protocol to work with either HTTP/HTTPS
            .segment 'proxy' # Append /proxy endpoint
            .toString()

        # Do the request, wiring up success/failure handlers        
        req = $http.post proxyUri, getProxyRequest(options)
        
        # Add callback handlers to promise
        req.success successCallback
        req.error errorCallback

        return q.promise

    dataSourceFactory.create 'OData', runner
