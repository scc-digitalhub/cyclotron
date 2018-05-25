cyclotronApp.controller 'GchartWidget', ($scope, $window, parameterPropagationService, dashboardService, dataService) ->
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
      $scope.myChartObject = {
        "type": "LineChart",
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
###    
  $scope.myChartObject = {
    "type": "LineChart",
    "displayed": false,
    "data": data   #here data come from dataSource 

    {
      "cols": [
        {
          "id": "month",
          "label": "Month",
          "type": "string",
          "p": {}
        },
        {
          "id": "laptop-id",
          "label": "Laptop",
          "type": "number",
          "p": {}
        },
        {
          "id": "desktop-id",
          "label": "Desktop",
          "type": "number",
          "p": {}
        },
        {
          "id": "server-id",
          "label": "Server",
          "type": "number",
          "p": {}
        },
        {
          "id": "cost-id",
          "label": "Shipping",
          "type": "number"
        }
      ],
      "rows": [
        {
          "c": [
            {
              "v": "January"
            },
            {
              "v": 19,
              "f": "42 items"
            },
            {
              "v": 12,
              "f": "Ony 12 items"
            },
            {
              "v": 7,
              "f": "7 servers"
            },
            {
              "v": 4
            }
          ]
        },
        {
          "c": [
            {
              "v": "February"
            },
            {
              "v": 13
            },
            {
              "v": 1,
              "f": "1 unit (Out of stock this month)"
            },
            {
              "v": 12
            },
            {
              "v": 2
            }
          ]
        },
        {
          "c": [
            {
              "v": "March"
            },
            {
              "v": 24
            },
            {
              "v": 5
            },
            {
              "v": 11
            },
            {
              "v": 6
            }
          ]
        }
      ]
    }
    ,
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
  ###