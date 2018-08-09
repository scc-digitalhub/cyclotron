#
# Widget for noUiSlider
#

cyclotronApp.controller 'SliderWidget', ($scope, $interval, $element, parameterPropagationService) ->
    # Override the widget feature of exporting data, since there is no data
    $scope.widgetContext.allowExport = false
    $scope.randomId = '' + Math.floor(Math.random()*1000)
    firstLoad = true
    timer = null

    # Check configuration
    checkConfiguration = (widget) ->
        if not widget.minValue? or not widget.maxValue? or
                _.isEmpty(widget.minValue) or _.isEmpty(widget.maxValue)
            $scope.widgetContext.dataSourceError = true
            $scope.widgetContext.dataSourceErrorMessage = 'Minimum or maximum values are missing'
        else
            # Read configuration
            $scope.momentFormat = if widget.momentFormat? then widget.momentFormat else 'YYYY-MM-DD HH:mm'
            timeUnit = if widget.timeUnit? then widget.timeUnit else 'days'
            minDateMillis = moment(widget.minValue, $scope.momentFormat).toDate().getTime()
            maxVal = moment(widget.maxValue, $scope.momentFormat).diff minDateMillis, timeUnit
            step = if widget.step? then parseInt(widget.step, 10) else 1
            interval = if widget.player? and widget.player.showPlayer
                if widget.player.interval then parseInt(widget.player.interval, 10) * 1000 else 1000
            else undefined
            $scope.playing = false
            $scope.currentSliderVal = 0
            $scope.currentDateTime = {value: ''}
            
            # Formatter
            formatter =
                to: (value) ->
                    moment(minDateMillis).add(value, timeUnit).format $scope.momentFormat
                from: (value) ->
                    moment(value, $scope.momentFormat).diff minDateMillis, timeUnit

            # Create slider configuration
            $scope.sliderconfig =
                start: $scope.currentSliderVal
                range:
                    'min': 0
                    'max': maxVal
                step: step
                direction: widget.direction
                orientation: widget.orientation
                tooltips: if widget.tooltips then formatter else false
            
            # Configure slider pips
            if widget.pips?
                if !widget.pips.mode? then widget.pips.mode = 'range'
                if widget.pips.values?
                    if widget.pips.mode in ['positions', 'values']
                        newvals = (parseInt(num, 10) for num in widget.pips.values.split ',')
                        widget.pips.values = newvals
                    else if widget.pips.mode = 'count'
                        widget.pips.values = parseInt widget.pips.values, 10
                    else delete widget.pips.values
                if widget.pips.density?
                    widget.pips.density = parseInt widget.pips.density, 10
                else widget.pips.density = 1
                if typeof widget.pips.format == 'undefined' or widget.pips.format then widget.pips.format = formatter
                $scope.sliderconfig.pips = widget.pips
            
            # Put current time on scope
            $scope.startdatetime = minDateMillis
            $scope.timeunit = timeUnit

            # Function triggered by play/pause button
            updateOnPlay = ->
                #if max slider value is reached, restart
                if not moment($scope.currentDateTime.value).isBefore(moment(widget.maxValue, $scope.momentFormat), timeUnit)
                    $scope.currentDateTime.value = moment(minDateMillis).format $scope.momentFormat
                    $scope.currentSliderVal = 0
                else
                    newDateTime = moment($scope.currentDateTime.value).add(step, timeUnit).format $scope.momentFormat
                    $scope.currentDateTime.value = newDateTime
                    $scope.currentSliderVal = moment(newDateTime, $scope.momentFormat).diff(moment(minDateMillis), timeUnit)

            # Event handler for play/pause button
            $scope.playPause = ->
                if $scope.playing
                    $interval.cancel timer
                    $scope.playing = false
                else
                    $scope.playing = true
                    timer = $interval updateOnPlay, interval

    $scope.loadWidget = ->
        $scope.widgetContext.loading = true
        #set parameters (only at first loading)
        if firstLoad
            parameterPropagationService.checkSpecificParams $scope
            parameterPropagationService.checkParameterSubscription $scope
            parameterPropagationService.checkGenericParams $scope

            if $scope.genericEventHandlers?.widgetSelection?
                handler = $scope.genericEventHandlers.widgetSelection.handler
                jqueryElem = $($element).closest('.dashboard-widget')
                handler jqueryElem, $scope.genericEventHandlers.widgetSelection.paramName, $scope.widget.name
            firstLoad = false
        
        widgedWithoutPlaceholders = parameterPropagationService.substitutePlaceholders $scope
        checkConfiguration(widgedWithoutPlaceholders)
        $scope.widgetContext.loading = false
    
    $scope.loadWidget()

    angular.element ->
        if $scope.widget.player?.startOnPageReady
            #start player automatically
            $scope.playPause()

    # Cleanup
    $scope.$on '$destroy', ->
        if timer?
            $interval.cancel timer
            timer = null