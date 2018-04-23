#
# Widget for noUiSlider
#

cyclotronApp.controller 'SliderWidget', ($scope, $timeout) ->
    # Override the widget feature of exporting data, since there is no data
    $scope.widgetContext.allowExport = false
    
    # Read configuration
    timeUnit = if $scope.widget.formatter? then $scope.widget.formatter else 'days'
    minDateMillis = moment($scope.widget.minValue, 'YYYY-MM-DD HH:mm').toDate().getTime()
    maxVal = moment($scope.widget.maxValue, 'YYYY-MM-DD HH:mm').diff minDateMillis, timeUnit
    step = $scope.widget.step
    timer = undefined
    interval = if $scope.widget.player? and $scope.widget.player.showPlayer
        if $scope.widget.player.interval then parseInt($scope.widget.player.interval, 10) * 1000 else 1000
    else undefined
    $scope.playing = false
    $scope.currentSliderVal = 0
    
    # Formatter
    formatter =
        to: (value) ->
            moment(minDateMillis).add(value, timeUnit).format 'YYYY-MM-DD HH:mm'
        from: (value) ->
            moment(value, 'YYYY-MM-DD HH:mm').diff minDateMillis, timeUnit

    # Create slider configuration
    $scope.sliderconfig =
        start: $scope.currentSliderVal
        range:
            'min': 0
            'max': maxVal
        step: 1
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
        if not moment(Cyclotron.parameters.currentDateTime).isBefore(moment($scope.widget.maxValue, 'YYYY-MM-DD HH:mm'), timeUnit)
            $timeout ->
                Cyclotron.parameters.currentDateTime = moment(minDateMillis).format 'YYYY-MM-DD HH:mm'
                $scope.currentSliderVal = 0
                console.log 'val set to 0', Cyclotron.parameters.currentDateTime
        
        newDateTime = moment(Cyclotron.parameters.currentDateTime).add(1, timeUnit).format 'YYYY-MM-DD HH:mm'
        Cyclotron.parameters.currentDateTime = newDateTime
        $scope.currentSliderVal = moment(newDateTime).diff(moment(minDateMillis), timeUnit)

    # Event handler for play/pause button
    $scope.playPause = ->
        if $scope.playing
            clearInterval timer
            $scope.playing = false
        else
            $scope.playing = true
            timer = setInterval updateOnPlay, interval