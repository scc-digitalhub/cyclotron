#
cyclotronDirectives.directive 'slider', ($window, configService, parameterPropagationService) ->
    {
        restrict: 'C'
        scope:
            sliderconfig: '='
            startdatetime: '='
            enddatetime: '='
            timeunit: '='
            ngModel: '='
            currentDateTime: '='
            twoHandles: '='
            momentformat: '='
            paramsGenerated: '='
            sourceOfParams: '='
        
        link: (scope, element, attrs) ->
            sliderElement = element[0]
            sliderCreated = false
            createSlider = ->
                try
                    if sliderCreated == false
                        noUiSlider.create sliderElement, scope.sliderconfig

                        if scope.twoHandles
                            scope.currentDateTime.value = [moment(scope.startdatetime).format(scope.momentformat), moment(scope.enddatetime).format(scope.momentformat)]

                            sliderElement.noUiSlider.on('set', (values, handle) ->
                                newDateTime = moment(scope.startdatetime).add(values[handle], scope.timeunit).format scope.momentformat
                                console.log 'new date on handle', handle, newDateTime

                                if not _.isEqual(newDateTime, scope.currentDateTime.value[handle])
                                    scope.currentDateTime.value[handle] = newDateTime
                                
                                if scope.sourceOfParams
                                    sections = ['first', 'second']
                                    parameterPropagationService.parameterBroadcaster (scope.$parent.widget.widget + scope.$parent.randomId), 'dateTimeChange', scope.currentDateTime.value[handle], sections[handle]
                            )
                        else
                            #store current value in the scope
                            scope.currentDateTime.value = moment(scope.startdatetime).format scope.momentformat
                            
                            sliderElement.noUiSlider.on('set', (values, handle) ->
                                newDateTime = moment(scope.startdatetime).add(values[handle], scope.timeunit).format scope.momentformat
                                if not _.isEqual(newDateTime, scope.currentDateTime.value)
                                    scope.currentDateTime.value = newDateTime
                                
                                if scope.sourceOfParams
                                    parameterPropagationService.parameterBroadcaster (scope.$parent.widget.widget + scope.$parent.randomId), 'dateTimeChange', scope.currentDateTime.value
                            )
                        sliderCreated = true
                catch e
                    console.log(e)
            
            scope.$watch 'sliderconfig', (sliderconfig) ->
                #TODO check if slider has already been created and check differences between old and new config
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
            
            return
    }
