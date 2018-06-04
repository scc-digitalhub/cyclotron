cyclotronApp.controller 'GchartWidget', ($scope, $element, parameterPropagationService, dashboardService, dataService) ->
  $scope.randomId = '' + Math.floor(Math.random()*1000)
  parameterPropagationService.checkGenericParams $scope

  if $scope.genericEventHandlers?.widgetSelection?
    handler = $scope.genericEventHandlers.widgetSelection.handler
    jqueryElem = $($element).closest('.dashboard-widget')
    handler jqueryElem, $scope.genericEventHandlers.widgetSelection.paramName, $scope.widget.name
  
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
      console.log 'chart selected:', $scope.widget.chartType
      $scope.myChartObject = {
        "type": $scope.widget.chartType,
        "displayed": false,
        "data": data[0],
        "options": {
          "title": "Sales per month",
          "isStacked": "true",
          "fill": 20,
          "displayExactValues": true,
          "vAxis": {
            "title": "Sales unit",
            "gridlines": {
              "count": 10
            }
          },
          "hAxis": {
            "title": "Date"
          }
        },
        "formatters": {}
      }

      $scope.widgetContext.loading = false

    # Data Source error
    $scope.$on 'dataSource:' + dsDefinition.name + ':error', (event, data) ->

    # Data Source loading
    $scope.$on 'dataSource:' + dsDefinition.name + ':loading', ->
        $scope.widgetContext.loading = true

    # Initialize the Data Source
    $scope.dataSource.init dsDefinition
