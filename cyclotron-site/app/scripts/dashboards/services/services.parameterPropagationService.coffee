#
# Manages propagation of and subscription to parameters
#
cyclotronServices.factory 'parameterPropagationService', ($rootScope, $window, configService, logService) ->
    #mapping of widgets, the events they produce and the parameters associated to such events
    widgetEvents = {}

    #mapping of widgets and the parameters they subscribed to
    subscriptions = {}

    #check if widget generates parameters
    checkSpecificParams = (scope) ->
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
                    section = if param_event.section? then param_event.section else scope.widget.widget
                    if not widgetEvents[scope.widget.widget] then widgetEvents[scope.widget.widget] = {}
                    if not widgetEvents[scope.widget.widget][section] then widgetEvents[scope.widget.widget][section] = {}
                    widgetEvents[scope.widget.widget][section][param_event.event] = param_event.paramName

    #check if widget subscribes to any parameters
    checkParameterSubscription = (scope) ->
        if scope.widget.parameterSubscription?
            subscriptions[scope.widget.widget+scope.randomId] = []
            for param in scope.widget.parameterSubscription
                if not (param of $window.Cyclotron.parameters)
                    scope.widgetContext.dataSourceError = true
                    scope.widgetContext.dataSourceErrorMessage = 'Parameter '+param+' not found among dashboard parameters'
                else
                    subscriptions[scope.widget.widget+scope.randomId].push param
                    parameterListener scope, param
    
    #set value of Cyclotron parameter
    setParameterValue = (parameterName, value) ->
        return unless parameterName? and value?
        console.log 'setting', parameterName, value
        if parameterName of $window.Cyclotron.parameters
            $window.Cyclotron.parameters[parameterName] = value

    #broadcast parameter change
    parameterBroadcaster = (widget, event, value, section) ->
        return unless widget? and event? and value?
        if not section? then section = widget
        paramName = widgetEvents[widget][section][event]
        setParameterValue paramName, value
        console.log 'broadcasting', paramName
        logService.debug 'Broadcasting: '+paramName+':update'
        $rootScope.$broadcast('parameter:'+paramName+':update', {})
    
    #place a listener for parameter changes
    parameterListener = (scope, parameterName) ->
        return unless parameterName?
        console.log 'subscribing to', parameterName
        message = 'parameter:'+parameterName+':update'
        scope.$on message, (event, args) ->
            console.log message, args
            scope.loadWidget()
    
    traverseWidget = (widget, keys, operation) ->
        for key in keys
            if typeof widget[key] == 'object'
                traverseWidget widget[key], _.keys(widget[key]), operation
            else
                widget[key] = operation(widget[key], $window.Cyclotron.parameters)
    
    #check if string contains a placeholder #{} for a parameter
    substitutePlaceholders = (scope) ->
        #check that parameters the widget is subscribed to have a value
        paramsHaveValue = true
        for param in subscriptions[scope.widget.widget+scope.randomId]
            if not $window.Cyclotron.parameters[param]? or _.isEmpty($window.Cyclotron.parameters[param])
                scope.widgetContext.dataSourceError = true
                scope.widgetContext.dataSourceErrorMessage = 'You subscribed to parameter '+param+', but it has no value, therefore the widget cannot be loaded'
                paramsHaveValue = false

        if paramsHaveValue
            widgetConfig = _.keys configService.widgets[scope.widget.widget].properties
            intersect = _.intersection widgetConfig, _.keys(scope.widget)
            clone = _.cloneDeep scope.widget
            substitute = (str, obj) ->
                _.varSub str, obj
            traverseWidget clone, intersect, substitute
            return clone
    
    return {
        checkSpecificParams: checkSpecificParams
        checkParameterSubscription: checkParameterSubscription
        setParameterValue: setParameterValue
        parameterBroadcaster: parameterBroadcaster
        substitutePlaceholders: substitutePlaceholders
    }