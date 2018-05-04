#
cyclotronDirectives.directive 'slider', ($window, configService) ->
    {
        restrict: 'C'
        scope:
            sliderconfig: '='
            startdatetime: '='
            timeunit: '='
            ngModel: '='
        
        link: (scope, element, attrs) ->
            sliderElement = element[0]
            sliderCreated = false
            classes = sliderElement.className
            createSlider = ->
                try
                    if sliderCreated == false
                        noUiSlider.create sliderElement, scope.sliderconfig
                        #create parameter currentDateTime
                        $window.Cyclotron.parameters.currentDateTime = moment(scope.startdatetime).format 'YYYY-MM-DD HH:mm'
                        
                        sliderElement.noUiSlider.on('set', (values, handle) ->
                            newDateTime = moment(scope.startdatetime).add(values[handle], scope.timeunit).format 'YYYY-MM-DD HH:mm'
                            if _.isEqual(newDateTime, $window.Cyclotron.parameters.currentDateTime)
                                #slider has just been created or parameter was set in updateOnPlay()
                                $window.Cyclotron.functions.parameterBroadcaster('currentDateTime')
                            else
                                $window.Cyclotron.parameters.currentDateTime = newDateTime
                                $window.Cyclotron.functions.parameterBroadcaster('currentDateTime')
                        )
                        sliderCreated = true
                catch e
                    console.log(e)
            
            scope.$watch 'sliderconfig', (sliderconfig) ->
                #TODO check if slider has already been created
                createSlider()
            
            scope.$watch 'ngModel', (ngModel) ->
                sliderElement.noUiSlider.set ngModel
            
            # Update on window resizing
            resizeFunction = _.debounce createSlider, 100, { leading: false, maxWait: 300 }
            $(window).on 'resize', resizeFunction

            # Cleanup
            scope.$on '$destroy', ->
                $(window).off 'resize', resizeFunction
                sliderElement.noUiSlider.destroy()
                sliderCreated = false
                delete $window.Cyclotron.parameters['currentDateTime'] #necessary?
            
            return
    }
