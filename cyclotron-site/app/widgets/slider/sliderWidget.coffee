#
# Widget for noUiSlider
#

cyclotronApp.controller 'SliderWidget', ($scope, $window, parameterPropagationService) ->
    # Override the widget feature of exporting data, since there is no data
    $scope.widgetContext.allowExport = false

    # Check configuration
    if not $scope.widget.minValue? or not $scope.widget.maxValue? or
            _.isEmpty($scope.widget.minValue) or _.isEmpty($scope.widget.maxValue)
        $scope.widgetContext.dataSourceError = true
        $scope.widgetContext.dataSourceErrorMessage = 'Minimum or maximum values are missing'
    
    ###
    # TODO handle generic events in the parent of widget controllers
    ###
    # Check parameters
    parameterPropagationService.checkSpecificParams $scope

    if not $scope.widget.dataSourceError?
        # Read configuration
        $scope.momentFormat = if $scope.widget.momentFormat? then $scope.widget.momentFormat else 'YYYY-MM-DD HH:mm'
        timeUnit = if $scope.widget.timeUnit? then $scope.widget.timeUnit else 'days'
        minDateMillis = moment($scope.widget.minValue, $scope.momentFormat).toDate().getTime()
        maxVal = moment($scope.widget.maxValue, $scope.momentFormat).diff minDateMillis, timeUnit
        step = if $scope.widget.step? then parseInt($scope.widget.step, 10) else 1
        timer = undefined
        interval = if $scope.widget.player? and $scope.widget.player.showPlayer
            if $scope.widget.player.interval then parseInt($scope.widget.player.interval, 10) * 1000 else 1000
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
            direction: $scope.widget.direction
            orientation: $scope.widget.orientation
            tooltips: if $scope.widget.tooltips then formatter else false
        
        # Configure slider pips
        if $scope.widget.pips?
            if !$scope.widget.pips.mode? then $scope.widget.pips.mode = 'range'
            if $scope.widget.pips.values?
                if $scope.widget.pips.mode in ['positions', 'values']
                    newvals = (parseInt(num, 10) for num in $scope.widget.pips.values.split ',')
                    $scope.widget.pips.values = newvals
                else if $scope.widget.pips.mode = 'count'
                    $scope.widget.pips.values = parseInt $scope.widget.pips.values, 10
                else delete $scope.widget.pips.values
            if $scope.widget.pips.density?
                $scope.widget.pips.density = parseInt $scope.widget.pips.density, 10
            else $scope.widget.pips.density = 1
            if typeof $scope.widget.pips.format == 'undefined' or $scope.widget.pips.format then $scope.widget.pips.format = formatter
            $scope.sliderconfig.pips = $scope.widget.pips
        
        # Put current time on scope
        $scope.startdatetime = minDateMillis
        $scope.timeunit = timeUnit

        # Function triggered by play/pause button
        updateOnPlay = ->
            #if max slider value is reached, restart
            #if not moment($window.Cyclotron.parameters.currentDateTime).isBefore(moment($scope.widget.maxValue, $scope.momentFormat), timeUnit)
            if not moment($scope.currentDateTime.value).isBefore(moment($scope.widget.maxValue, $scope.momentFormat), timeUnit)
                #$window.Cyclotron.parameters.currentDateTime = moment(minDateMillis).format $scope.momentFormat
                $scope.currentDateTime.value = moment(minDateMillis).format $scope.momentFormat
                $scope.currentSliderVal = 0
            else
                #newDateTime = moment($window.Cyclotron.parameters.currentDateTime).add(1, timeUnit).format $scope.momentFormat
                newDateTime = moment($scope.currentDateTime.value).add(step, timeUnit).format $scope.momentFormat
                #$window.Cyclotron.parameters.currentDateTime = newDateTime
                $scope.currentDateTime.value = newDateTime
                $scope.currentSliderVal = moment(newDateTime, $scope.momentFormat).diff(moment(minDateMillis), timeUnit)

        # Event handler for play/pause button
        $scope.playPause = ->
            if $scope.playing
                clearInterval timer
                $scope.playing = false
            else
                $scope.playing = true
                timer = setInterval updateOnPlay, interval