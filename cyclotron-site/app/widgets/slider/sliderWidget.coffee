#
# Widget for noUiSlider
#
#import { NouiFormatter } from 'nouislider'

#export class TimeFormatter implements NouiFormatter

cyclotronApp.controller 'SliderWidget', ($scope, dashboardService, dataService) ->
    # Override the widget feature of exporting data, since there is no data
    $scope.widgetContext.allowExport = false
    
    minDate = moment($scope.widget.minDate, 'DD/MM/YYYY').toDate().getTime()
    maxDate = moment($scope.widget.maxDate, 'DD/MM/YYYY').diff minDate, 'days'

    # Create formatter
    formatter =
        to: (value) ->
            moment(minDate).add(value, 'days').format 'DD/MM/YYYY'
        from: (value) ->
            moment(value, 'DD/MM/YYYY').diff minDate, 'days'

    # Create slider configuration
    $scope.sliderconfig =
        start: 0
        range:
            'min': 0
            'max': maxDate
        step: 1
        direction: $scope.widget.direction
        orientation: $scope.widget.orientation
        tooltips: formatter
        pips:
            mode: 'count'
            stepped: true
            density: 2
            values: 5
            format: formatter
###
    getChart = ->
        defaults =
            credits:
                enabled: false
            exporting:
                enabled: false
            plotOptions: {}
            title:
                text:  null

        # Merge dashboard options with the defaults
        chart = _.merge(defaults, $scope.widget.highchart)
        chart = _.compile(chart, {}, ['series'], true)
        return chart

    getSeries = (series, seriesData = $scope.rawData) ->
        # Compile top-level properties
        series = _.compile series, [], [], false
        return series

    $scope.createChart = ->

        # Get the chart options
        chart = getChart()

        # Load the series from the chart
        $scope.series = series = chart.series

        # Expand each series with the actual data and apply to the chart
        chart.series = _.map series, (s) -> getSeries(s, $scope.rawData)

        # Set the highcharts object so the directive picks it up.
        $scope.highchart = chart

    $scope.reload = ->
        if $scope.dataSource
            $scope.dataSource.execute(true)

    # Load Main data source
    dsDefinition = dashboardService.getDataSource $scope.dashboard, $scope.widget
    $scope.dataSource = dataService.get dsDefinition

    # Initialize
    if $scope.dataSource?
        # Data Source (re)loaded
        $scope.$on 'dataSource:' + dsDefinition.name + ':data', (event, eventData) ->
            $scope.widgetContext.dataSourceError = false
            $scope.widgetContext.dataSourceErrorMessage = null

            data = eventData.data[dsDefinition.resultSet].data
            data = $scope.filterAndSortWidgetData(data)

            # Check for no data
            if data?
                $scope.rawData = data
                $scope.createChart()

        # Data Source error
        $scope.$on 'dataSource:' + dsDefinition.name + ':error', (event, data) ->
            $scope.widgetContext.dataSourceError = true
            $scope.widgetContext.dataSourceErrorMessage = data.error

        # Initialize the Data Source
        $scope.dataSource.init dsDefinition
###
