#
# Manages propagation of and subscription to parameters
#
cyclotronServices.factory 'parameterPropagationService', ($rootScope, $window, configService, logService) ->
    #mapping of widgets, the events they produce and the parameters associated to such events
    _widgetEvents = {}

    #mapping of widgets and the parameters they subscribed to
    _subscriptions = {}

    #mapping of parameters and the datasources subscribed to them
    _dsSubscriptions = {}

    #mapping of widget IDs and names
    _widgetNames = {}
    
    #set value of Cyclotron parameter
    _setParameterValue = (parameterName, value) ->
        return unless parameterName? and value?
        if parameterName of $window.Cyclotron.parameters
            if $window.Cyclotron.parameters[parameterName] == value
                #value is unchanged
                return false
            else
                console.log 'setting', parameterName, value
                $window.Cyclotron.parameters[parameterName] = value
    
    #place a listener for parameter changes
    _parameterListener = (scope, parameterName) ->
        return unless parameterName?
        console.log 'subscribing to', parameterName
        message = 'parameter:'+parameterName+':update'
        scope.$on message, (event, args) ->
            console.log message, args
            scope.loadWidget()

    #check if widget generates parameters
    checkSpecificParams = (scope, optSection) ->
        if scope.widget.specificEvents? and not _.isEmpty(scope.widget.specificEvents) and not
                (scope.widget.specificEvents.length == 1 and not scope.widget.specificEvents[0]?)
            for param_event in scope.widget.specificEvents
                if not param_event.paramName? or not param_event.event?
                    scope.widgetContext.dataSourceError = true
                    scope.widgetContext.dataSourceErrorMessage = 'Parameter name or event are missing'
                else if not (param_event.paramName of $window.Cyclotron.parameters)
                    scope.widgetContext.dataSourceError = true
                    scope.widgetContext.dataSourceErrorMessage = 'Parameter '+param_event.paramName+' not found among dashboard parameters'
                else
                    scope.sourceOfParams = true
                    widget = scope.widget.widget + scope.randomId
                    section = if param_event.section? then param_event.section else if optSection? then optSection else widget
                    if not _widgetEvents[widget] then _widgetEvents[widget] = {}
                    if not _widgetEvents[widget][section] then _widgetEvents[widget][section] = {}
                    _widgetEvents[widget][section][param_event.event] = param_event.paramName

    #check if widget generates generic (i.e. not specific to widget type) parameters
    checkGenericParams = (scope) ->
        if scope.widget.genericEvents? and not _.isEmpty(scope.widget.genericEvents) and not
                (scope.widget.genericEvents.length == 1 and not scope.widget.genericEvents[0]?)
            if not scope.widget.name?
                scope.widgetContext.dataSourceError = true
                scope.widgetContext.dataSourceErrorMessage = 'Widget name is missing. It is required for the generation of specific parameters.'
            else
                for param_event in scope.widget.genericEvents
                    if not param_event.paramName? or not param_event.event?
                        scope.widgetContext.dataSourceError = true
                        scope.widgetContext.dataSourceErrorMessage = 'Parameter name or event are missing'
                    else if not (param_event.paramName of $window.Cyclotron.parameters)
                        scope.widgetContext.dataSourceError = true
                        scope.widgetContext.dataSourceErrorMessage = 'Parameter '+param_event.paramName+' not found among dashboard parameters'
                    else
                        _widgetNames[scope.randomId] = scope.widget.name
                        if not scope.genericEventHandlers then scope.genericEventHandlers = {}
                        if param_event.event == 'clickOnWidget'
                            eventHandler = (jqueryElem, param, value) ->
                                jqueryElem.on 'click', ->
                                    oldValue = $window.Cyclotron.parameters[param]
                                    if oldValue == value
                                        jqueryElem.removeAttr 'style'
                                        #reset parameter to default value
                                        paramDefinition = _.find scope.dashboard.parameters, { name: param }
                                        _setParameterValue param, paramDefinition?.defaultValue
                                        $rootScope.$broadcast('parameter:'+param+':update', {})
                                    else
                                        _setParameterValue param, value
                                        jqueryElem.css 'border', '1px solid red'
                                        $rootScope.$broadcast('parameter:'+param+':update', {})

                                        #if another widget was previously selected, deselect it
                                        _.each _widgetNames, (name, id) ->
                                            if name == oldValue
                                                oldElem = $('#' + id).closest('.dashboard-widget')
                                                oldElem.removeAttr 'style'

                            scope.genericEventHandlers.widgetSelection = {
                                paramName: param_event.paramName,
                                handler: eventHandler
                            }

    #check if widget subscribes to any parameters
    checkParameterSubscription = (scope) ->
        if scope.widget.parameterSubscription?
            _subscriptions[scope.widget.widget+scope.randomId] = []
            for param in scope.widget.parameterSubscription
                if not (param of $window.Cyclotron.parameters)
                    scope.widgetContext.dataSourceError = true
                    scope.widgetContext.dataSourceErrorMessage = 'Parameter '+param+' not found among dashboard parameters. Cannot subscribe to it.'
                else
                    _subscriptions[scope.widget.widget+scope.randomId].push param
                    _parameterListener scope, param
    
    #check if datasource subscribes to any parameters
    checkDSParameterSubscription = (dsOptions) ->
        if dsOptions.parameterSubscription.length > 0
            for param in dsOptions.parameterSubscription
                if not _.isEmpty(param) and (param of $window.Cyclotron.parameters)
                    if not _dsSubscriptions[param]? then _dsSubscriptions[param] = []
                    _dsSubscriptions[param].push dsOptions.name

    #broadcast parameter change
    parameterBroadcaster = (widget, event, value, section) ->
        return unless widget? and event? and value?
        if not section? then section = widget
        paramName = _widgetEvents[widget][section][event]
        changed = _setParameterValue paramName, value

        if changed
            #notify widget
            console.log 'broadcasting', paramName
            logService.debug 'Broadcasting: '+paramName+':update'
            $rootScope.$broadcast('parameter:'+paramName+':update', {})

            #re-execute datasources
            if _dsSubscriptions[paramName]?
                for ds in _dsSubscriptions[paramName]
                    $window.Cyclotron.dataSources[ds].execute(true)
    
    _traverseObject = (obj, keys, operation) ->
        for key in keys
            if typeof obj[key] == 'object'
                _traverseObject obj[key], _.keys(obj[key]), operation
            else
                obj[key] = operation(obj[key], $window.Cyclotron.parameters)

    #check if widget properties contain placeholders #{} for parameters and substitute them with their value
    substitutePlaceholders = (scope) ->
        paramsHaveValue = true
        clone = _.cloneDeep scope.widget
        #check that parameters the widget is subscribed to have a value
        for param in _subscriptions[scope.widget.widget+scope.randomId]
            if not $window.Cyclotron.parameters[param]? or _.isEmpty($window.Cyclotron.parameters[param])
                scope.widgetContext.dataSourceError = true
                scope.widgetContext.dataSourceErrorMessage = 'You subscribed to parameter '+param+', but it has no value, therefore the widget cannot be loaded'
                paramsHaveValue = false

        if paramsHaveValue
            widgetConfig = _.keys configService.widgets[scope.widget.widget].properties
            intersect = _.intersection widgetConfig, _.keys(scope.widget)
            substitute = (str, obj) ->
                _.varSub str, obj
            
            _traverseObject clone, intersect, substitute
        return clone
    
    #check if datasource properties contain placeholders #{} for parameters and substitute them with their value
    substituteDSPlaceholders = (dsOptions) ->
        paramsHaveValue = true
        for param of _dsSubscriptions
            if _dsSubscriptions[param].includes dsOptions.name
                if not $window.Cyclotron.parameters[param]? or _.isEmpty($window.Cyclotron.parameters[param])
                    paramsHaveValue = false
        
        if paramsHaveValue
            keys = _.keys(dsOptions)
            clone = _.cloneDeep dsOptions
            substitute = (str, obj) ->
                _.varSub str, obj
            _traverseObject clone, keys, substitute
            return clone
        else return dsOptions
    
    return {
        checkSpecificParams: checkSpecificParams
        checkParameterSubscription: checkParameterSubscription
        parameterBroadcaster: parameterBroadcaster
        substitutePlaceholders: substitutePlaceholders
        checkDSParameterSubscription: checkDSParameterSubscription
        substituteDSPlaceholders: substituteDSPlaceholders
        checkGenericParams: checkGenericParams
    }