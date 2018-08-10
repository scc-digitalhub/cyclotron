###
# Copyright (c) 2013-2015 the original author or authors.
#
# Licensed under the MIT License (the "License");
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at
#
#     http://www.opensource.org/licenses/mit-license.php
#
# Unless required by applicable law or agreed to in writing, 
# software distributed under the License is distributed on an 
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
# either express or implied. See the License for the specific 
# language governing permissions and limitations under the License. 
###

cyclotronServices.factory 'userService', ($http, $localForage, $q, $rootScope, $window, $location, configService, logService) ->

    loggedIn = false
    currentSession = null

    exports = {
        authEnabled: configService.authentication.enable

        cachedUserId: null

        cachedUsername: null

        isLoggedIn: -> 
            return true unless configService.authentication.enable
            loggedIn && currentSession?

        isAdmin: -> currentSession?.user?.admin == true

        currentSession: -> currentSession

        currentUser: -> currentSession?.user

        setLoggedOut: ->
            loggedIn = false
            currentSession = null

        isNewUser: true

        notNewUser: (update = true) ->
            return unless exports.isNewUser

            # Save flag indicating this is no longer a new user
            $localForage.setItem('newUser', 0).then ->
                # Change field accordingly 
                exports.isNewUser = false if update
                logService.debug 'User is not longer a New User'

    }

    # Load cached username
    $localForage.getItem('username').then (username) ->
        if username?
            exports.cachedUsername = username

    # Load cached userId (not UID)
    $localForage.getItem('cachedUserId').then (userId) ->
        if userId?
            exports.cachedUserId = userId

    # Load New User quality
    $localForage.getItem('newUser').then (value) ->
        if value == 0
            logService.debug 'User is definitely not a New User'
            exports.isNewUser = false
        else if value > 0
            logService.debug 'User is definitely a New User'
        else
            logService.debug 'User is probably a New User'
            $localForage.setItem 'newUser', 1

    exports.login = (username, password) ->
        return if _.isEmpty(username) || _.isEmpty(password)

        post = $http.post(configService.restServiceUrl + '/users/login',
            { username, password })

        deferred = $q.defer()

        post.success (session) ->
            currentSession = session
            
            # Store session and username in localstorage
            $localForage.setItem 'session', session
            $localForage.setItem 'username', username
            $localForage.setItem 'cachedUserId', session.user._id
            exports.cachedUsername = username
            exports.cachedUserId = session.user._id

            loggedIn = true

            $rootScope.$broadcast 'login', { }
            if $window.Cyclotron?
                $window.Cyclotron.currentUser = session.user
            alertify.success('Logged in as <strong>' + session.user.name + '</strong>', 2500)

            deferred.resolve(session)

        post.error (error) ->
            exports.setLoggedOut()
            deferred.reject(error)

        return deferred.promise

    exports.loadExistingSession = (hideAlerts = false) ->
        console.log 'loading existing session', currentSession?, $location.path()
        return currentSession if currentSession?

        deferred = $q.defer()
        errorHandler = ->
            exports.setLoggedOut()
            deferred.resolve(null)

        if configService.authentication.enable == true

            $localForage.getItem('session').then (existingSession) ->
                console.log('session stored?', existingSession?)

                if existingSession?
                    console.log 'trying to validate session'
                    validator = $http.post(configService.restServiceUrl + '/users/validate', { key: existingSession.key })
                    validator.success (session) ->
                        currentSession = session
                        loggedIn = true

                        alertify.log('Logged in as <strong>' + session.user.name + '</strong>', 2500) unless hideAlerts
                        deferred.resolve(session)

                    validator.error (error) ->
                        $localForage.removeItem('session')
                        alertify.log('Previous session expired', 2500) unless hideAlerts
                        errorHandler()
                else
                    errorHandler()
            , errorHandler
        else
            errorHandler()

        return deferred.promise

    exports.logout = ->
        deferred = $q.defer()

        if currentSession?
            promise = $http.post(configService.restServiceUrl + '/users/logout', { key: currentSession.key })
            promise.success ->
                exports.setLoggedOut()
                $localForage.removeItem('session')
                
                $rootScope.$broadcast('logout')
                if $window.Cyclotron?
                    $window.Cyclotron.currentUser = null
                alertify.log('Logged Out', 2500)
                deferred.resolve()

            promise.error (error) ->
                alertify.error('Error during logout', 2500)
                deferred.reject()

        return deferred.promise

    exports.search = (query, permissionType) ->

        deferred = $q.defer()

        #if authentication via ldap, search on ldap, else search among database users
        promise = undefined
        if configService.authentication.authProvider == 'ldap'
            promise = $http.get(configService.restServiceUrl + '/ldap/search', { params: { q: query } })
        else
            promise = $http.get(configService.restServiceUrl + '/users/search', { params: { q: query, session: exports.currentSession()?.key, permission: permissionType } })

        promise.success (results) ->
            console.log 'results', results
            deferred.resolve(results)
        promise.error (error) ->
            logService.error('UserService error: ' + error)
            deferred.reject()
            
        return deferred.promise

    exports.hasEditPermission = (dashboard) ->
        return true unless configService.authentication.enable

        # Non-authenticated users cannot edit
        return false unless exports.isLoggedIn()

        # User is Admin
        return true if exports.isAdmin()

        # No edit permissions defined
        return true if _.isEmpty(dashboard?.editors)

        # User is in the editors list, or they are a member of a group that is
        return _.any dashboard.editors, (editor) ->
            return (currentSession.user.distinguishedName == editor.dn) || 
                _.contains(currentSession.user.memberOf, editor.dn)

    exports.hasViewPermission = (dashboard) ->
        return true unless configService.authentication.enable

        # Assume non-authenticated users can view
        return true unless exports.isLoggedIn()

        # User is Admin
        return true if exports.isAdmin()

        # No view permissions defined
        return true if _.isEmpty(dashboard?.viewers)

        # If user can edit, they can view
        return true if exports.hasEditPermission(dashboard)

        # User is in the viwers list, or they are a member of a group that is
        return _.any dashboard.viewers, (viewer) ->
            return (currentSession.user.distinguishedName == viewer.dn) || 
                _.contains(currentSession.user.memberOf, viewer.dn)

    exports.likesDashboard = (dashboard) ->
        return false unless configService.authentication.enable
        
        # Must be logged in to like a dashboard
        return false unless exports.isLoggedIn()

        return _.contains dashboard.likes, currentSession.user._id
    
    exports.aacLogin = ->
        console.log 'requesting aac login'

        authorizationUrl = configService.authentication.authorizationURL
        clientID = configService.authentication.clientID
        scope = configService.authentication.scopes
        redirectUri = configService.authentication.callbackDomain

        requestUrl = authorizationUrl + '?response_type=token&client_id=' + clientID + '&redirect_uri=' + redirectUri + '&scope=' + scope

        $window.location = requestUrl
    
    exports.storeAccessToken = () ->
        console.log 'redirection worked'
        hash = $location.path().substr(1)
        params = hash.split('&')
        tokenProperties = {}

        _.each params, (value) ->
            keyValuePair = value.split('=')
            key = keyValuePair[0]
            val = keyValuePair[1]
            tokenProperties[key] = val

        deferred = $q.defer()

        get = $http({
            method: 'GET'
            url: configService.restServiceUrl + '/users/oauth'
            headers:
                'Authorization': 'Bearer ' + tokenProperties.access_token
        })

        get.success (session) ->
            console.log 'session successfully created'

            currentSession = session
            
            # Store session and username in localstorage
            $localForage.setItem 'session', session
            $localForage.setItem 'username', session.user.sAMAccountName
            $localForage.setItem 'cachedUserId', session.user._id
            exports.cachedUsername = session.user.sAMAccountName
            exports.cachedUserId = session.user._id

            loggedIn = true

            $rootScope.$broadcast 'login', { }
            if $window.Cyclotron?
                $window.Cyclotron.currentUser = session.user
            alertify.success('Logged in as <strong>' + session.user.name + '</strong>', 2500)
                
            deferred.resolve(session)
            #finally redirect to home page
            $location.path('/').replace()

        get.error (error) ->
            console.log 'error or API sent an error response', error
            exports.setLoggedOut()
            deferred.reject(error)
            $location.path('/').replace()

    return exports
