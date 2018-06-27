cyclotronApp.controller 'GchartWidget', ($scope, $element, parameterPropagationService, dashboardService, dataService) ->
    $scope.randomId = '' + Math.floor(Math.random()*1000)
    parameterPropagationService.checkGenericParams $scope

    if $scope.genericEventHandlers?.widgetSelection?
        handler = $scope.genericEventHandlers.widgetSelection.handler
        jqueryElem = $($element).closest('.dashboard-widget')
        handler jqueryElem, $scope.genericEventHandlers.widgetSelection.paramName, $scope.widget.name

    options = if $scope.widget.options? then _.jsEval($scope.widget.options) else null

    currentChart = null

    dsDefinition = dashboardService.getDataSource $scope.dashboard, $scope.widget
    $scope.dataSource = dataService.get dsDefinition

    # Initialize
    if $scope.dataSource?
        $scope.dataVersion = 0
        $scope.widgetContext.loading = true

        # Data Source (re)loaded
        $scope.$on 'dataSource:' + dsDefinition.name + ':data', (event, eventData) ->
            return unless eventData.version > $scope.dataVersion
            $scope.dataVersion = eventData.version

            $scope.widgetContext.dataSourceError = false
            $scope.widgetContext.dataSourceErrorMessage = null

            data = eventData.data[dsDefinition.resultSet].data
            data = $scope.filterAndSortWidgetData(data)

            if $scope.widget.chartType?
                columns = []
                rows = []
                formatters = {}

                if $scope.widget.formatters? and not _.isEmpty($scope.widget.formatters)
                    for f in $scope.widget.formatters
                        if f?.columnName? and f?.formatter?
                            form = _.jsEval f.formatter
                            if _.isFunction(form) then formatters[f.columnName] = form

                if $scope.widget.columns? and not _.isEmpty($scope.widget.columns)
                    for col in $scope.widget.columns
                        if col? and col.type?
                            column = {type: col.type}
                            if col.name? then column.label = col.name
                            columns.push column
                        else
                            $scope.widgetContext.dataSourceError = true
                            $scope.widgetContext.dataSourceErrorMessage = 'Columns must have name and type specified'
                else
                    #infer column labels from the first row and assign string as type
                    for key of data[0]
                        if _.isBoolean(data[0][key]) then columns.push {type: 'boolean', label: key}
                        else if data[0][key] == parseInt(data[0][key]) or data[0][key] == parseFloat(data[0][key])
                            columns.push {type: 'number', label: key}
                        else columns.push {type: 'string', label: key}
        
                for row in data
                    c = []
                    for key of row
                        val = if key in _.keys(formatters) then formatters[key](row[key]) else row[key]
                        c.push {'v': val}
                    rows.push {'c': c}

                chartObject = {
                    type: $scope.widget.chartType,
                    data: {'cols': columns, 'rows': rows}
                }
                if options?
                    # handle Google Charts hidden element by setting a fixed size
                    if not options.height? then options.height = $element.parent().height()
                    chartObject.options = options
                
                if $scope.myChartObject?
                    $scope.myChartObject.data = chartObject.data
                else
                    $scope.myChartObject = _.cloneDeep chartObject
                    currentChart = _.cloneDeep chartObject
            else
                $scope.widgetContext.dataSourceError = true
                $scope.widgetContext.dataSourceErrorMessage = 'Chart type is missing'

            $scope.widgetContext.loading = false

        # Data Source error
        $scope.$on 'dataSource:' + dsDefinition.name + ':error', (event, data) ->
            $scope.widgetContext.dataSourceError = true
            $scope.widgetContext.dataSourceErrorMessage = data.error
            $scope.widgetContext.nodata = null
            $scope.widgetContext.loading = false

        # Data Source loading
        $scope.$on 'dataSource:' + dsDefinition.name + ':loading', ->
            $scope.widgetContext.loading = true

        # Initialize the Data Source
        $scope.dataSource.init dsDefinition