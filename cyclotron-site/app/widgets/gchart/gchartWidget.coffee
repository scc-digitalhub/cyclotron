cyclotronApp.controller 'GchartWidget', ($scope, $element, $timeout, parameterPropagationService, dashboardService, dataService) ->
    $scope.randomId = '' + Math.floor(Math.random()*1000)
    parameterPropagationService.checkGenericParams $scope

    if $scope.genericEventHandlers?.widgetSelection?
        handler = $scope.genericEventHandlers.widgetSelection.handler
        jqueryElem = $($element).closest('.dashboard-widget')
        handler jqueryElem, $scope.genericEventHandlers.widgetSelection.paramName, $scope.widget.name

    currentChart = null
    currentOptions = null

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

            if _.isEmpty(data) then $scope.widgetContext.nodata = 'No data to display'

            options = if $scope.widget.options? then _.jsEval(_.jsExec($scope.widget.options)) else null
            currentOptions = _.cloneDeep options
            
            if $scope.widget.chartType?
                columns = []
                rows = []
                formatters = {}

                if $scope.widget.formatters? and not _.isEmpty($scope.widget.formatters)
                    for f in $scope.widget.formatters
                        if f?.columnName? and f?.formatter?
                            form = _.jsEval f.formatter
                            if _.isFunction(form) then formatters[f.columnName] = form

                #if the columns are not defined in $scope.widget.columns, infer column labels and types from the first row
                for key of data[0]
                    if $scope.widget.columns?
                        col = _.find $scope.widget.columns, (c) ->
                            return c.name? and c.name == key
                        if col? and col.type?
                            #use column definition for type, role and label
                            column = {type: col.type}
                            if col.role? then column.p = {role: col.role} else column.label = col.name
                            columns.push column
                        else
                            #infer from first data row
                            if _.isBoolean(data[0][key]) then columns.push {type: 'boolean', label: key}
                            else if data[0][key] == parseInt(data[0][key]) or data[0][key] == parseFloat(data[0][key])
                                columns.push {type: 'number', label: key}
                            else columns.push {type: 'string', label: key}
                    else
                        if _.isBoolean(data[0][key]) then columns.push {type: 'boolean', label: key}
                        else if data[0][key] == parseInt(data[0][key]) or data[0][key] == parseFloat(data[0][key])
                            columns.push {type: 'number', label: key}
                        else columns.push {type: 'string', label: key}

                ###
                if $scope.widget.columns? and not _.isEmpty($scope.widget.columns)
                    for col in $scope.widget.columns
                        if col? and col.type? and col.name?
                            column = {type: col.type}
                            if col.role? then column.p = {role: col.role} else column.label = col.name
                            columns.push column
                        else
                            $scope.widgetContext.dataSourceError = true
                            $scope.widgetContext.dataSourceErrorMessage = 'Columns must have name and type specified'
                else
                    #infer column labels and types from the first row
                    for key of data[0]
                        if _.isBoolean(data[0][key]) then columns.push {type: 'boolean', label: key}
                        else if data[0][key] == parseInt(data[0][key]) or data[0][key] == parseFloat(data[0][key])
                            columns.push {type: 'number', label: key}
                        else columns.push {type: 'string', label: key}
                ###
        
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

    checkVisibility = ->
        return $element.parent().height()
    
    $scope.$watch checkVisibility, (newHeight) ->
        #update chart height when widget height changes, unless chart has fixed height
        if not currentOptions?.height? then $scope.myChartObject?.options?.height = newHeight