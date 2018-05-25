#
# Widget for OpenLayers map
#
cyclotronApp.controller 'OpenLayersMapWidget', ($scope, parameterPropagationService, dashboardService, dataService) ->
    $scope.randomId = '' + Math.floor(Math.random()*1000)
    mapConfig = {} #map configuration, .layersToAdd, .groups, .overlays, .controls
    firstLoad = true

    ###
    # View
    ###
    checkViewProperties = (widget) ->
        if not widget.center?.x? or not widget.center?.y? or
                _.isEmpty(widget.center.x) or _.isEmpty(widget.center.y)
            $scope.widgetContext.dataSourceError = true
            $scope.widgetContext.dataSourceErrorMessage = 'X or Y coordinates are missing'
        else if not widget.zoom?
            $scope.widgetContext.dataSourceError = true
            $scope.widgetContext.dataSourceErrorMessage = 'Zoom property is missing'
        else
            mapConfig.center = [parseFloat(widget.center.x), parseFloat(widget.center.y)]
            mapConfig.zoom = parseInt widget.zoom, 10

    ###
    # Layers
    ###

    #configuration object for layers
    $scope.layerOptions =
        'Image':
            olClass: ol.layer.Image
            sources:
                'ImageArcGISRest':
                    srcClass: ol.source.ImageArcGISRest
                    configRequired: false
                    config:
                        url: ''
                'ImageCanvas':
                    srcClass: ol.source.ImageCanvas
                    configRequired: true
                    config:
                        canvasFunction: ->
                'ImageMapGuide':
                    srcClass: ol.source.ImageMapGuide
                    configRequired: false
                    config:
                        url: ''
                'ImageStatic':
                    srcClass: ol.source.ImageStatic
                    configRequired: true
                    config:
                        url: ''
                        imageExtent: undefined
                'ImageWMS':
                    srcClass: ol.source.ImageWMS
                    configRequired: true
                    config:
                        url: ''
                        params: {}
                'Raster':
                    srcClass: ol.source.Raster
                    configRequired: true
                    config:
                        sources: []
        'Tile':
            olClass: ol.layer.Tile
            sources:
                'BingMaps':
                    srcClass: ol.source.BingMaps
                    configRequired: true
                    config:
                        key: ''
                        imagerySet: ''
                'CartoDB':
                    srcClass: ol.source.CartoDB
                    configRequired: true
                    config:
                        account: ''
                'OSM':
                    srcClass: ol.source.OSM
                    configRequired: false
                    config:
                        url: ''
                'Stamen':
                    srcClass: ol.source.Stamen
                    configRequired: true
                    config:
                        layer: ''
                'TileArcGISRest':
                    srcClass: ol.source.TileArcGISRest
                    configRequired: false
                    config:
                        url: ''
                'TileDebug':
                    srcClass: ol.source.TileDebug
                    configRequired: true
                    config:
                        projection: undefined
                'TileJSON':
                    srcClass: ol.source.TileJSON
                    configRequired: true
                    config:
                        url: ''
                'TileUTFGrid':
                    srcClass: ol.source.TileUTFGrid
                    configRequired: true
                    config:
                        url: ''
                'TileWMS':
                    srcClass: ol.source.TileWMS
                    configRequired: true
                    config:
                        params: {}
                'WMTS':
                    srcClass: ol.source.WMTS
                    configRequired: true
                    config:
                        tileGrid: undefined
                        layer: ''
                        style: ''
                        matrixSet: ''
                'XYZ':
                    srcClass: ol.source.XYZ
                    configRequired: false
                    config:
                        url: ''
                'Zoomify':
                    srcClass: ol.source.Zoomify
                    configRequired: true
                    config:
                        url: ''
                        size: undefined
        'Heatmap':
            olClass: ol.layer.Heatmap
            sources:
                'Cluster':
                    srcClass: ol.source.Cluster
                    configRequired: true
                    config:
                        source: undefined
                'Vector':
                    srcClass: ol.source.Vector
                    configRequired: false
                    config:
                        url: ''
                        format: undefined
        'VectorTile':
            olClass: ol.layer.VectorTile
            sources:
                'VectorTile':
                    srcClass: ol.source.VectorTile
                    configRequired: false
                    config:
                        url: ''
    
    checkLayerProperties = (widget) ->
        if not widget.layers? or
                (widget.layers.length == 1 and not widget.layers[0]?)
            #set default layer, i.e., OSM map with no configuration
            defaultLayer =
                type: 'Tile'
                source:
                    name: 'OSM'
                    configuration: '{}'
            mapConfig.layersToAdd = [defaultLayer]
        else
            #check that each layer is valid
            for layer in widget.layers
                layerType = if layer.type? then layer.type else null
                layerSource = if layer.source? then layer.source else null
                configObj = if layerSource?.configuration? then _.jsEval layerSource.configuration  else null
                sourcesKeys =  if layerType? then _.keys($scope.layerOptions[layerType].sources) else null
                
                configKeys = if layerType? and layerSource? and layerSource.name?
                then _.keys($scope.layerOptions[layerType].sources[layerSource.name].config)
                else null

                #allow VectorTile to skip source tests since source is not required
                if layerType == 'VectorTile' and not layerSource?
                    continue

                #check that both type and source are defined
                if (layerType and not layerSource) or (layerSource and not layerType)
                    $scope.widgetContext.dataSourceError = true
                    $scope.widgetContext.dataSourceErrorMessage = 'Type or source are missing for some layers'
                #check that source name is defined and can be passed to the layer
                else if not layerSource.name? or layerSource.name not in sourcesKeys
                    $scope.widgetContext.dataSourceError = true
                    $scope.widgetContext.dataSourceErrorMessage = 'Source name for '+layerType+' layer is missing or the source you selected cannot be used. Please refer to the help page.'
                #check that source configuration is valid
                else if $scope.layerOptions[layerType].sources[layerSource.name].configRequired and
                        (not configObj or not _.isEmpty(_.difference(_.keys(configObj), configKeys)))
                    $scope.widgetContext.dataSourceError = true
                    $scope.widgetContext.dataSourceErrorMessage = 'Configuration is missing or invalid for source '+layerSource.name+'. Please refer to the help page.'
            if $scope.widgetContext.dataSourceError == false
                mapConfig.layersToAdd = widget.layers

    setOverlays = (overlays, groupName) ->
        overlaysChecked = []
        for overlay in overlays
            if overlay?
                if not overlay.name? or _.isEmpty(overlay.name)
                    $scope.widgetContext.dataSourceError = true
                    $scope.widgetContext.dataSourceErrorMessage = 'Some overlay name is missing'
                    return
                else
                    overlayToPush = {group: groupName}
                    overlayToPush.id = overlay.name
                    if overlay.position?.x? and overlay.position?.y? and not
                            (_.isEmpty(overlay.position.x) or _.isEmpty(overlay.position.y))
                        overlayToPush.position = [parseFloat(overlay.position.x), parseFloat(overlay.position.y)]
                    if overlay.positioning? then overlayToPush.positioning = overlay.positioning
                    if overlay.template?
                        overlayToPush.template = _.jsExec overlay.template
                    overlaysChecked.push overlayToPush
        return overlaysChecked

    ###
    # Overlays
    ###
    checkOverlayProperties = (widget) ->
        if widget.overlayGroups? and not _.isEmpty(widget.overlayGroups)
            if not mapConfig.overlays? and not mapConfig.groups?
                mapConfig.overlays = []
                mapConfig.groups = {}
                for group in widget.overlayGroups
                    if group?
                        #check group properties
                        if not group.name? or _.isEmpty(group.name)
                            $scope.widgetContext.dataSourceError = true
                            $scope.widgetContext.dataSourceErrorMessage = 'Overlay group name is missing'
                        else if not group.cssClass? or _.isEmpty(group.cssClass)
                            $scope.widgetContext.dataSourceError = true
                            $scope.widgetContext.dataSourceErrorMessage = 'Overlay group CSS class is missing'
                        else if not group.overlays? or _.isEmpty(group.overlays) or
                                (group.overlays.length == 1 and not group.overlays[0]?)
                            $scope.widgetContext.dataSourceError = true
                            $scope.widgetContext.dataSourceErrorMessage = 'Overlay group must have at least one overlay'
                        else
                            mapConfig.groups[group.name] =
                                cssClass: group.cssClass
                                cssClassSelected: group.cssClassSelected || ''
                                currentOverlay: ''
                            
                            mapConfig.overlays = setOverlays group.overlays, group.name
            else
                console.log 'not first load'
                #substitute old overlay content
                for group in widget.overlayGroups
                    newOverlays = setOverlays group.overlays, group.name
                    for overlay, index in newOverlays
                        if not _.isEqual(overlay.template, mapConfig.overlays[index].template)
                            mapConfig.overlays[index].template = overlay.template

    ###
    # Controls
    ###

    #configuration object for controls
    $scope.controlOptions =
        'Attribution': ol.control.Attribution
        'MousePosition': ol.control.MousePosition
        'OverviewMap': ol.control.OverviewMap
        'ScaleLine': ol.control.ScaleLine
        'Zoom': ol.control.Zoom
        'ZoomSlider': ol.control.ZoomSlider
        'ZoomExtent': ol.control.ZoomExtent

    checkControlProperties = (widget) ->
        if widget.controls? and not mapConfig.controls?
            mapConfig.controls = []
            for control in widget.controls
                if control?
                    mapConfig.controls.push control.control
    
    ###
    # Datasource
    ###
    $scope.reload = ->
        $scope.dataSource.execute(true)
    
    dsDefinition = dashboardService.getDataSource $scope.dashboard, $scope.widget
    $scope.dataSource = dataService.get dsDefinition
    
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

            if data?
                console.log 'data', data
                ovData = _.cloneDeep data
                _.each ovData, (row, index) -> row.__index = index
                
                if not mapConfig.overlays? and not mapConfig.groups?
                    mapConfig.overlays = []
                    mapConfig.groups = {}

                    for group in ovData
                        if not group.name? or _.isEmpty(group.name)
                            $scope.widgetContext.dataSourceError = true
                            $scope.widgetContext.dataSourceErrorMessage = 'Datasource objects must have a name'
                        else if not group.cssClass? or _.isEmpty(group.cssClass)
                            $scope.widgetContext.dataSourceError = true
                            $scope.widgetContext.dataSourceErrorMessage = 'Datasource objects must have a CSS class'
                        else if not group.overlays? or _.isEmpty(group.overlays)
                            $scope.widgetContext.dataSourceError = true
                            $scope.widgetContext.dataSourceErrorMessage = 'Datasource objects must have at least one overlay'
                        else
                            mapConfig.groups[group.name] =
                                cssClass: group.cssClass
                                cssClassSelected: group.cssClassSelected || ''
                                currentOverlay: ''
                            
                            mapConfig.overlays = setOverlays group.overlays, group.name
                else
                    console.log 'not first load'
                    #substitute old overlay content
                    for group in ovData
                        newOverlays = setOverlays group.overlays, group.name
                        for overlay, index in newOverlays
                            if not _.isEqual(overlay.template, mapConfig.overlays[index].template)
                                mapConfig.overlays[index].template = overlay.template

            $scope.widgetContext.loading = false

        # Data Source error
        $scope.$on 'dataSource:' + dsDefinition.name + ':error', (event, data) ->
            $scope.widgetContext.dataSourceError = true
            $scope.widgetContext.dataSourceErrorMessage = data.error
            $scope.widgetContext.nodata = null
            $scope.widgetContext.loading = false
            mapConfig.overlays = []
            mapConfig.groups = {}

        # Data Source loading
        $scope.$on 'dataSource:' + dsDefinition.name + ':loading', ->
            $scope.widgetContext.loading = true
        
        # Initialize the Data Source
        $scope.dataSource.init dsDefinition

    else 
        # Override the widget feature of exporting data, since there is no data
        $scope.widgetContext.allowExport = false

    $scope.loadWidget = ->
        console.log '(re)loading widget', $scope.randomId
        $scope.widgetContext.loading = true
        #set parameters (only at first loading)
        if firstLoad
            parameterPropagationService.checkSpecificParams $scope
            parameterPropagationService.checkParameterSubscription $scope
            firstLoad = false
        
        #substitute any placeholder with parameter values, then check the configuration
        widgedWithoutPlaceholders = parameterPropagationService.substitutePlaceholders $scope
        checkViewProperties(widgedWithoutPlaceholders)
        checkLayerProperties(widgedWithoutPlaceholders)
        if $scope.dataSource?
            $scope.reload()
        else
            checkOverlayProperties(widgedWithoutPlaceholders)
        checkControlProperties(widgedWithoutPlaceholders) #done only once because it cannot be parametric

        $scope.mapConfig = mapConfig
        $scope.widgetContext.loading = false
    
    $scope.loadWidget()