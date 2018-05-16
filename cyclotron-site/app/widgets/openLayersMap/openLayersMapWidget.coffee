#
# Widget for OpenLayers map
#
cyclotronApp.controller 'OpenLayersMapWidget', ($scope, parameterPropagationService) ->
    #dataSource

    ###
    # Parameters
    ###
    parameterPropagationService.checkSpecificParams $scope
    parameterPropagationService.checkParameterSubscription $scope

    ###
    # View
    ###
    if not $scope.widget.center?.x? or not $scope.widget.center?.y? or
            _.isEmpty($scope.widget.center.x) or _.isEmpty($scope.widget.center.y)
        $scope.widgetContext.dataSourceError = true
        $scope.widgetContext.dataSourceErrorMessage = 'X or Y coordinates are missing'
    else if not $scope.widget.zoom?
        $scope.widgetContext.dataSourceError = true
        $scope.widgetContext.dataSourceErrorMessage = 'Zoom property is missing'
    else
        $scope.center = [parseFloat($scope.widget.center.x), parseFloat($scope.widget.center.y)]
        $scope.zoom = parseInt $scope.widget.zoom, 10

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
    
    if not $scope.widget.layers? or
            ($scope.widget.layers.length == 1 and not $scope.widget.layers[0]?)
        #set default layer, i.e., OSM map with no configuration
        defaultLayer =
            type: 'Tile'
            source:
                name: 'OSM'
                configuration: '{}'
        $scope.layersToAdd = [defaultLayer]
    else
        #check that each layer is valid
        for layer in $scope.widget.layers
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
            $scope.layersToAdd = $scope.widget.layers

    ###
    # Overlays
    ###
    if $scope.widget.overlayGroups? and not _.isEmpty($scope.widget.overlayGroups)
        $scope.overlayGroups = []
        for group in $scope.widget.overlayGroups
            if group?
                if not group.name? or _.isEmpty(group.name)
                    $scope.widgetContext.dataSourceError = true
                    $scope.widgetContext.dataSourceErrorMessage = 'Overlay group name is missing'
                else if not group.cssClass? or _.isEmpty(group.cssClass)
                    $scope.widgetContext.dataSourceError = true
                    $scope.widgetContext.dataSourceErrorMessage = 'Overlay group CSS class is missing'
                else if not group.overlays? or _.isEmpty(group.overlays) or
                        (group.overlays.length == 1 and not group.overlays[0]?)
                    $scope.widgetContext.dataSourceError = true
                    $scope.widgetContext.dataSourceErrorMessage = 'No overlay is defined for group '+group.name
                else
                    groupProperties = {name: group.name, cssClass: group.cssClass}
                    if group.cssClassSelected? then groupProperties.cssClassSelected = group.cssClassSelected
                    groupProperties.overlays = []
                    for overlay in group.overlays
                        if overlay?
                            overlayProperties = {}
                            if not overlay.name? or _.isEmpty(overlay.name)
                                $scope.widgetContext.dataSourceError = true
                                $scope.widgetContext.dataSourceErrorMessage = 'Overlay name is missing'
                            else
                                overlayProperties.id = overlay.name
                                if overlay.position?.x? and overlay.position?.y? and not
                                        (_.isEmpty(overlay.position.x) or _.isEmpty(overlay.position.y))
                                    overlayProperties.position = [parseFloat(overlay.position.x), parseFloat(overlay.position.y)]
                                if overlay.positioning? then overlayProperties.positioning = overlay.positioning
                                overlayProperties.generation = if overlay.generation? then overlay.generation else 'inline'
                                groupProperties.overlays.push overlayProperties
                    groupProperties.overlaySelected = ''
                    $scope.overlayGroups.push groupProperties
        console.log 'groups', $scope.overlayGroups
    
    ###
    # Controls
    ###