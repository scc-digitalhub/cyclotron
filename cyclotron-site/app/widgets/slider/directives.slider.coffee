# Inspired by: https://github.com/rootux/angular-highcharts-directive
cyclotronDirectives.directive 'slider', ($window, configService) ->
    {
        restrict: 'C'
        scope:
            sliderconfig: '='
        
        link: (scope, element, attrs) ->
            sliderElement = element[0]
            classes = sliderElement.className
            console.log(classes)
            createSlider = ->
                try
                    noUiSlider.create sliderElement, scope.sliderconfig
                    sliderElement.noUiSlider.on('change', (values, handle) ->
                        console.log values[handle]
                        #console.log scope.dashboard.parameters
                        console.log $window.Cyclotron.parameters
                    )
                    console.log(sliderElement.className)
                catch e
                    console.log(e)
            
            scope.$watch 'sliderconfig', (sliderconfig) ->
                #TODO check if slider has already been created
                createSlider()
            
            # Update on window resizing
            resizeFunction = _.debounce createSlider, 100, { leading: false, maxWait: 300 }
            $(window).on 'resize', resizeFunction

            # Cleanup
            scope.$on '$destroy', ->
                $(window).off 'resize', resizeFunction
                return
    }
    ###
    {
        restrict: 'CA',
        replace: false,
        scope:
            chart: '='
            addshift: '='

        link: (scope, element, attrs) ->
            $element = $(element)
            $parent = $element.parent()
            $title = $parent.children('h1')

            # Reference to Highcharts Chart object
            highchartsObj = null

            resize = ->
                # Set height
                parentHeight = $parent.height()

                if $title.length
                    $element.height(parentHeight - $title.height())
                else
                    $element.height(parentHeight)

                # Set highcharts size
                if highchartsObj?
                    highchartsObj.setSize($parent.width(), $element.height(), false)
 
            chartDefaults =
                chart:
                    renderTo: element[0]
                    height: attrs.height || null
                    width: attrs.width || null

            chartConfig = configService.widgets.chart
            
            # Update when charts data changes
            scope.$watch('chart', (chart) ->
                return unless chart

                # Resize the container div (highcharts auto-sizes to the container div)
                resize()

                # Create or Update
                if highchartsObj? && _.isEqual(_.omit(scope.currentChart, 'series'), _.omit(chart, 'series'))
                    seriesToRemove = []

                    # Update each series with new data
                    _.each highchartsObj.series, (aSeries) ->
                        newSeries = _.find chart.series, { name: aSeries.name }

                        if scope.addshift
                            # Get original series array from the scope
                            originalSeries = _.find scope.chartSeries, { name: aSeries.name }
                        else
                            aSeries.setData(newSeries.data, false)
                            

                    # Add new series to the chart
                    _.each chart.series, (toSeries, index) ->
                        existingSeries = _.find highchartsObj.series, { name: toSeries.name }

                        if !existingSeries?
                            highchartsObj.addSeries(toSeries, false)

                    # Remove any missing series
                    _.each seriesToRemove, (aSeries) ->
                        aSeries.remove(false)

                    # Redraw at once
                    highchartsObj.redraw()

                else
                    # Clean up old chart if exists
                    if highchartsObj?
                        highchartsObj.destroy()

                    newChart = _.cloneDeep(chart)
                    scope.currentChart = chart

                    # Apply defaults 
                    _.merge(newChart, chartDefaults, _.default)

                    scope.chartSeries = newChart.series
                    highchartsObj = new Highcharts.Chart(newChart)

            , true)

            #
            # Resize when layout changes
            #
            resizeFunction = _.debounce resize, 100, { leading: false, maxWait: 300 }
            $(window).on 'resize', resizeFunction

            #
            # Cleanup
            #
            scope.$on '$destroy', ->
                $(window).off 'resize', resizeFunction
                
                if highchartsObj?
                    highchartsObj.destroy()
                    highchartsObj = null

            return
    }
    ###
