# Inspired by: https://github.com/rootux/angular-highcharts-directive
cyclotronDirectives.directive 'slider', ($window, $rootScope, configService) ->
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
                        if $window.Cyclotron.parameters.currentDateTime?
                            $window.Cyclotron.parameters.currentDateTime = moment(scope.startdatetime).format 'YYYY-MM-DD HH:mm'
                        
                        noUiSlider.create sliderElement, scope.sliderconfig
                        sliderElement.noUiSlider.on('change', (values, handle) ->
                            newDateTime = moment(scope.startdatetime).add(values[handle], scope.timeunit).format 'YYYY-MM-DD HH:mm'
                            $window.Cyclotron.parameters.currentDateTime = newDateTime
                            $rootScope.$broadcast('parameter:currentDateTime:changed')
                        )
                        sliderElement.noUiSlider.on('set', (values,handle) ->
                            console.log('set',values[handle])
                            $rootScope.$broadcast('parameter:currentDateTime:changed')
                        )
                        sliderCreated = true
                catch e
                    console.log(e)
            
            scope.$watch 'sliderconfig', (sliderconfig) ->
                #TODO check if slider has already been created
                createSlider()
            
            scope.$watch 'ngModel', (ngModel) ->
                #WARN when end of playing is reached, watch is not triggered with value 0
                console.log ngModel
                sliderElement.noUiSlider.set ngModel
            
            # Update on window resizing
            resizeFunction = _.debounce createSlider, 100, { leading: false, maxWait: 300 }
            $(window).on 'resize', resizeFunction

            # Cleanup
            scope.$on '$destroy', ->
                $(window).off 'resize', resizeFunction
                sliderElement.noUiSlider.destroy()
                sliderCreated = false
                delete $window.Cyclotron.parameters['currentTime']
            
            return
    }
