###
# Note: generic events and parameter subscription are currently not handled, i.e., cannot be used
# on the Container Widget itself.
#
# Scope properties inherited from dashboardPage:
# - widget
# - layout
# - dashboard
# - page
# - pageOverrides
###

cyclotronApp.controller 'WidgetContainerWidget', ($scope) ->
    # Set layout defaults
    $scope.widget.layout.gridWidthAdjustment = $scope.widget.layout.gridWidthAdjustment || 0
    $scope.widget.layout.gridHeightAdjustment = $scope.widget.layout.gridHeightAdjustment || 0
    $scope.widget.layout.gutter = $scope.widget.layout.gutter || 10
    $scope.widget.layout.margin = $scope.widget.layout.margin || 10
    $scope.widget.layout.borderWidth = $scope.widget.layout.borderWidth || null
    $scope.widget.layout.scrolling = $scope.widget.layout.scrolling || true

    # Contained widgets
    $scope.innerWidgets = $scope.widget?.gridItems || []
    
    $scope.container = $scope.widget

    # Override the widget feature of exporting data, since there is no data
    $scope.widgetContext.allowExport = false