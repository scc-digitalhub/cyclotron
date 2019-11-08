#
# Widget for Deck.gl
#
cyclotronApp.controller 'DeckglWidget', ($scope, $element, dashboardService, dataService, parameterPropagationService) ->
    $scope.randomId = '' + Math.floor(Math.random()*1000)
    parameterPropagationService.checkGenericParams $scope
    
    if $scope.genericEventHandlers?.widgetSelection?
        handler = $scope.genericEventHandlers.widgetSelection.handler
        jqueryElem = $($element).closest('.dashboard-widget')
        handler jqueryElem, $scope.genericEventHandlers.widgetSelection.paramName, $scope.widget.name

    deckConfig = {}

    ###
    # View
    ###
    checkViewProperties = (viewState) ->
        if not viewState.longitude?
            $scope.widgetContext.dataSourceError = true
            $scope.widgetContext.dataSourceErrorMessage = 'Longitude is missing'
        else if not viewState.latitude?
            $scope.widgetContext.dataSourceError = true
            $scope.widgetContext.dataSourceErrorMessage = 'Latitude is missing'
        else
            deckConfig.viewState =
                longitude: parseFloat viewState.longitude
                latitude: parseFloat viewState.latitude
                zoom: if viewState.zoom? then parseInt(viewState.zoom, 10) else 0

    ###
    # Layers
    ###
    checkLayerProperties = (layers) ->
        return unless layers? and layers.length > 0 and layers[0]?
        layersToAdd = []
        for layer in layers
            if not layer.type?
                $scope.widgetContext.dataSourceError = true
                $scope.widgetContext.dataSourceErrorMessage = 'Type is missing for some layers'
            else
                if layer.configProperties? then layer.configProperties = _.jsEval(layer.configProperties)
                layersToAdd.push layer
        deckConfig.layersToAdd = layersToAdd
    
    checkAdditionalDeckProps = (additionalProps) ->
        if additionalProps? then deckConfig.additionalDeckProps = _.jsEval(additionalProps)
    
    checkViewProperties($scope.widget.viewState)
    checkLayerProperties($scope.widget.layers)
    checkAdditionalDeckProps($scope.widget.additionalDeckProps)

    ###
    # Datasource
    ###
    $scope.reload = ->
        $scope.dataSource.execute(true)
    
    dsDefinition = dashboardService.getDataSource $scope.dashboard, $scope.widget
    $scope.dataSource = dataService.get dsDefinition

    if $scope.dataSource?
        #use dataSource for layer data
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

            if data?
                layer = _.find deckConfig.layersToAdd, {useDataSource: true}
                if layer? then layer.configProperties.data = data
            
            if $scope.deckConfig?
                $scope.deckConfig.layersToAdd = deckConfig.layersToAdd
            else
                $scope.deckConfig = deckConfig

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
    else
        #use data property for layer data
        $scope.deckConfig = deckConfig

    ###
    Basic layer properties (each subclass has more):
    - id (String, optional)
    - data (Iterable | String | Promise | AsyncIterable | Object, optional), if String it is interpreted as JSON url
    - accessors (get...) to read the data
    - visible (Boolean, optional)
    - opacity (Number, optional)
    - extensions ?
    - pickable (Boolean, optional)
    - onHover (Function, optional)
    - onClick (Function, optional)
    - ...
    ###