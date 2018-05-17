#
# Manages propagation of and subscription to parameters
#
cyclotronServices.factory 'parameterPropagationService', ($rootScope, $window, configService, logService) ->
    #mapping of widgets, the events they produce and the parameters associated to such events
    widgetEvents = {}

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
            scope.parametersToSubscribe = []
            for param in scope.widget.parameterSubscription
                if not (param of $window.Cyclotron.parameters)
                    scope.widgetContext.dataSourceError = true
                    scope.widgetContext.dataSourceErrorMessage = 'Parameter '+param+' not found among dashboard parameters'
                else
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
    
    return {
        checkSpecificParams: checkSpecificParams
        checkParameterSubscription: checkParameterSubscription
        setParameterValue: setParameterValue
        parameterBroadcaster: parameterBroadcaster
        parameterListener: parameterListener
    }