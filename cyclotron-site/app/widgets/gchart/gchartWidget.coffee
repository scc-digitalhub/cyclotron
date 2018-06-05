cyclotronApp.controller 'GchartWidget', ($scope, $element, parameterPropagationService, dashboardService, dataService) ->
  $scope.randomId = '' + Math.floor(Math.random()*1000)
  parameterPropagationService.checkGenericParams $scope

  if $scope.genericEventHandlers?.widgetSelection?
    handler = $scope.genericEventHandlers.widgetSelection.handler
    jqueryElem = $($element).closest('.dashboard-widget')
    handler jqueryElem, $scope.genericEventHandlers.widgetSelection.paramName, $scope.widget.name
  
  options = if $scope.widget.options? then _.jsEval($scope.widget.options) else null
  
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
      console.log 'data', data
      #isStacked, fill, displayExactValues, vAxis{title, gridlines{count}}, hAxis{title}
      if $scope.widget.chartType?
        $scope.myChartObject = {
          type: $scope.widget.chartType,
          data: data[0]
        }
        if options? then $scope.myChartObject.options = options
      else
        $scope.widgetContext.dataSourceError = false
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
