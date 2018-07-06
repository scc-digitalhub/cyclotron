#
# Widget for OpenLayers map
#
cyclotronApp.controller 'OpenLayersMapWidget', ($scope, $element, parameterPropagationService, dashboardService, dataService) ->
    $scope.randomId = '' + Math.floor(Math.random()*1000)
    $scope.widgetId = $scope.widget.widget + $scope.randomId
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
                    config: ['attributions', 'crossOrigin', 'hidpi', 'imageLoadFunction', 'logo', 'params', 'projection', 'ratio', 'resolutions', 'url']
                'ImageCanvas':
                    srcClass: ol.source.ImageCanvas
                    configRequired: true
                    config: ['attributions', 'canvasFunction', 'logo', 'projection', 'ratio', 'resolutions', 'state']
                'ImageMapGuide':
                    srcClass: ol.source.ImageMapGuide
                    configRequired: false
                    config: ['url', 'displayDpi', 'metersPerUnit', 'hidpi', 'useOverlay', 'projection', 'ratio', 'resolutions', 'imageLoadFunction', 'params']
                'ImageStatic':
                    srcClass: ol.source.ImageStatic
                    configRequired: true
                    config: ['attributions', 'crossOrigin', 'imageExtent', 'imageLoadFunction', 'logo', 'projection', 'imageSize', 'url']
                'ImageWMS':
                    srcClass: ol.source.ImageWMS
                    configRequired: true
                    config: ['attributions', 'crossOrigin', 'hidpi', 'serverType', 'imageLoadFunction', 'logo', 'params', 'projection', 'ratio', 'resolutions', 'url']
                'Raster':
                    srcClass: ol.source.Raster
                    configRequired: true
                    config: ['sources', 'operation', 'lib', 'threads', 'operationType']
        'Tile':
            olClass: ol.layer.Tile
            sources:
                'BingMaps':
                    srcClass: ol.source.BingMaps
                    configRequired: true
                    config: ['cacheSize', 'hidpi', 'culture', 'key', 'imagerySet', 'maxZoom', 'reprojectionErrorThreshold', 'tileLoadFunction', 'wrapX', 'transition']
                'CartoDB':
                    srcClass: ol.source.CartoDB
                    configRequired: true
                    config: ['attributions', 'cacheSize', 'crossOrigin', 'logo', 'projection', 'maxZoom', 'minZoom', 'wrapX', 'config', 'map', 'account']
                'OSM':
                    srcClass: ol.source.OSM
                    configRequired: false
                    config: ['attributions', 'cacheSize', 'crossOrigin', 'maxZoom', 'opaque', 'reprojectionErrorThreshold', 'tileLoadFunction', 'url', 'wrapX']
                'Stamen':
                    srcClass: ol.source.Stamen
                    configRequired: true
                    config: ['cacheSize', 'layer', 'minZoom', 'maxZoom', 'opaque', 'reprojectionErrorThreshold', 'tileLoadFunction', 'url', 'wrapX']
                'TileArcGISRest':
                    srcClass: ol.source.TileArcGISRest
                    configRequired: false
                    config: ['attributions', 'cacheSize', 'crossOrigin', 'params', 'logo', 'tileGrid', 'projection', 'reprojectionErrorThreshold', 'tileLoadFunction', 'url', 'wrapX', 'transition', 'urls']
                'TileDebug':
                    srcClass: ol.source.TileDebug
                    configRequired: true
                    config: ['projection', 'tileGrid', 'wrapX']
                'TileJSON':
                    srcClass: ol.source.TileJSON
                    configRequired: true
                    config: ['attributions', 'cacheSize', 'crossOrigin', 'jsonp', 'reprojectionErrorThreshold', 'tileJSON', 'tileLoadFunction', 'url', 'wrapX', 'transition']
                'TileUTFGrid':
                    srcClass: ol.source.TileUTFGrid
                    configRequired: true
                    config: ['jsonp', 'preemptive', 'tileJSON', 'url']
                'TileWMS':
                    srcClass: ol.source.TileWMS
                    configRequired: true
                    config: ['attributions', 'cacheSize', 'params', 'crossOrigin', 'gutter', 'hidpi', 'logo', 'tileClass', 'tileGrid', 'projection', 'reprojectionErrorThreshold', 'serverType', 'tileLoadFunction', 'url', 'wrapX', 'transition', 'urls']
                'WMTS':
                    srcClass: ol.source.WMTS
                    configRequired: true
                    config: ['attributions', 'cacheSize', 'crossOrigin', 'logo', 'tileGrid', 'projection', 
                        'reprojectionErrorThreshold', 'requestEncoding', 'layer', 'url', 'wrapX', 'transition', 'urls', 
                        'style', 'tileClass', 'tilePixelRatio', 'version', 'format', 'matrixSet', 'dimensions', 'tileLoadFunction']
                'XYZ':
                    srcClass: ol.source.XYZ
                    configRequired: false
                    config: ['attributions', 'cacheSize', 'crossOrigin', 'logo', 'opaque', 'projection', 'reprojectionErrorThreshold', 
                        'maxZoom', 'minZoom', 'tileGrid', 'tileLoadFunction', 'tilePixelRatio', 'tileSize', 'tileUrlFunction', 'url', 'urls', 'wrapX', 'transition']
                'Zoomify':
                    srcClass: ol.source.Zoomify
                    configRequired: true
                    config: ['attributions', 'cacheSize', 'crossOrigin', 'logo', 'projection', 'reprojectionErrorThreshold', 
                        'url', 'tierSizeCalculation', 'size', 'extent', 'transition', 'tileSize']
        'Heatmap':
            olClass: ol.layer.Heatmap
            sources:
                'Cluster':
                    srcClass: ol.source.Cluster
                    configRequired: true
                    config: ['attributions', 'distance', 'extent', 'geometryFunction', 'format', 'logo', 'projection', 'source', 'wrapX']
                'Vector':
                    srcClass: ol.source.Vector
                    configRequired: false
                    config: ['attributions', 'features', 'format', 'loader', 'logo', 'overlaps', 'strategy', 'url', 'useSpatialIndex', 'wrapX']
        'VectorTile':
            olClass: ol.layer.VectorTile
            sources:
                'VectorTile':
                    srcClass: ol.source.VectorTile
                    configRequired: false
                    config: ['attributions', 'cacheSize', 'format', 'logo', 'overlaps', 'projection', 'state', 'tileClass', 'tileGrid', 'tileLoadFunction', 'tileUrlFunction', 'url', 'urls', 'wrapX', 'transition']
    
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
                then $scope.layerOptions[layerType].sources[layerSource.name].config
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
                    overlay.name = 'ov' + Math.floor(Math.random()*1000)
                if not overlay.cssClass? or _.isEmpty(overlay.cssClass)
                    $scope.widgetContext.dataSourceError = true
                    $scope.widgetContext.dataSourceErrorMessage = 'Overlay CSS class is missing'
                
                overlayToPush = {group: groupName, cssClass: overlay.cssClass}
                overlayToPush.id = overlay.name
                if overlay.cssClassSelected? then overlayToPush.cssClassSelected = overlay.cssClassSelected
                if overlay.position?.x? and overlay.position?.y? and not
                        ((_.isString(overlay.position.x) and _.isEmpty(overlay.position.x)) or (_.isString(overlay.position.y) and  _.isEmpty(overlay.position.y)))
                    overlayToPush.position = [parseFloat(overlay.position.x), parseFloat(overlay.position.y)]
                if overlay.positioning? then overlayToPush.positioning = overlay.positioning
                if overlay.template?
                    overlayToPush.template = _.jsExec overlay.template
                overlaysChecked.push overlayToPush
        return overlaysChecked

    updateOverlays = (groups) ->
        for group in groups
            newOverlays = setOverlays group.overlays, group.name
            for overlay, index in newOverlays
                if not _.isEqual(overlay.template, mapConfig.overlays[index].template)
                    mapConfig.overlays[index].template = overlay.template
                if not _.isEqual(overlay.cssClass, mapConfig.overlays[index].cssClass)
                    mapConfig.overlays[index].cssClass = overlay.cssClass
                if not _.isEqual(overlay.cssClassSelected, mapConfig.overlays[index].cssClassSelected)
                    mapConfig.overlays[index].cssClassSelected = overlay.cssClassSelected
                if not _.isEqual(overlay.position, mapConfig.overlays[index].position)
                    mapConfig.overlays[index].position = overlay.position
                if not _.isEqual(overlay.positioning, mapConfig.overlays[index].positioning)
                    mapConfig.overlays[index].positioning = overlay.positioning

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
                        else if not group.overlays? or _.isEmpty(group.overlays) or
                                (group.overlays.length == 1 and not group.overlays[0]?)
                            $scope.widgetContext.dataSourceError = true
                            $scope.widgetContext.dataSourceErrorMessage = 'Overlay group must have at least one overlay'
                        else
                            mapConfig.groups[group.name] =
                                currentOverlay: group.initiallySelected || ''
                            
                            mapConfig.overlays = mapConfig.overlays.concat(setOverlays group.overlays, group.name)
            else
                #substitute old overlay content
                updateOverlays(widget.overlayGroups)

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
        'ZoomToExtent': ol.control.ZoomToExtent

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
    
    #returns [{name: '', position: {x: '', y: ''}, positioning: '', template: '', cssClass: '', cssClassSelected: ''}]
    mapOverlays = (overlayList, mapping) ->
        copy = []
        for ov in overlayList
            mapped = {}
            mapped.cssClass = ov[mapping.cssClassField]
            if mapping.cssClassSelectedField? then mapped.cssClassSelected = ov[mapping.cssClassSelectedField] else ''
            if mapping.overlayIdField? then mapped.name = ov[mapping.overlayIdField]
            if mapping.positionField?
                mapped.position = {x: ov[mapping.positionField][0], y: ov[mapping.positionField][1]}
            else if mapping.xField? and mapping.yField?
                mapped.position = {x: ov[mapping.xField], y: ov[mapping.yField]}
            if mapping.positioningField? then mapped.positioning = ov[mapping.positioningField]
            if mapping.templateField? then mapped.template = ov[mapping.templateField]
            copy.push mapped
        return copy
    
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
            isUpdate = eventData.isUpdate

            if data?
                console.log 'isUpdate:', isUpdate, 'data:', $scope.ovData?
                if !isUpdate or !$scope.ovData?
                    $scope.ovData = _.cloneDeep data
                    _.each $scope.ovData, (row, index) -> row.__index = index

                    mapConfig.overlays = []
                    mapConfig.groups = {}
                    mapping = if $scope.widget.dataSourceMapping? then $scope.widget.dataSourceMapping else null

                    #read datasource mapping
                    if not mapping? or not (mapping.overlayListField? and mapping.cssClassField?)
                        $scope.widgetContext.dataSourceError = true
                        $scope.widgetContext.dataSourceErrorMessage = 'DataSource mapping is not defined. Mapping for at least Overlay List Field and CSS Class Field  must be provided'
                    else
                        $scope.mapping =
                            groupIdField: if mapping.identifierField? then mapping.identifierField else null
                            cssClassField: mapping.cssClassField
                            cssClassSelectedField: if mapping.cssClassOnSelectionField? then mapping.cssClassOnSelectionField else null
                            initiallySelectedField: if mapping.initiallySelectedField? then mapping.initiallySelectedField else null
                            overlayListField: mapping.overlayListField
                            overlayIdField: if mapping.overlayIdField? then mapping.overlayIdField else null
                            positionField: if mapping.positionField? then mapping.positionField else null
                            xField: if mapping.xField? then mapping.xField else null
                            yField: if mapping.yField? then mapping.yField else null
                            positioningField: if mapping.positioningField? then mapping.positioningField else null
                            templateField: if mapping.templateField? then mapping.templateField else null

                        for group in $scope.ovData
                            group.name = if $scope.mapping.groupIdField? then group[$scope.mapping.groupIdField] else 'group' + Math.floor(Math.random()*1000)
                            mapConfig.groups[group.name] =
                                currentOverlay: group[$scope.mapping.initiallySelectedField] || ''
                            
                            group.overlays = mapOverlays group[$scope.mapping.overlayListField], $scope.mapping
                            delete group[$scope.mapping.overlayListField]
                            
                            mapConfig.overlays = mapConfig.overlays.concat(setOverlays group.overlays, group.name)

                            parameterPropagationService.checkSpecificParams $scope, group.name
                else
                    oldData = _.cloneDeep $scope.ovData
                    console.log 'check old data', oldData
                    $scope.ovData = _.cloneDeep data
                    _.each $scope.ovData, (row, index) -> row.__index = index

                    for group, i in $scope.ovData
                        group.name = oldData[i].name
                        group.overlays = mapOverlays group[$scope.mapping.overlayListField], $scope.mapping
                        delete group[$scope.mapping.overlayListField]
                    
                    console.log 'about to update overlays'

                    updateOverlays $scope.ovData

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
        
        #substitute any placeholder with parameter values, then check the configuration
        if firstLoad
            #when using a datasource, the call to checkSpecificParams is done after the overlay groups
            #have been parsed and their names, i.e. sections of the map, are already known
            if not $scope.dataSource? then parameterPropagationService.checkSpecificParams $scope
            parameterPropagationService.checkParameterSubscription $scope
            parameterPropagationService.checkGenericParams $scope

            if $scope.genericEventHandlers?.widgetSelection?
                handler = $scope.genericEventHandlers.widgetSelection.handler
                jqueryElem = $($element).closest('.dashboard-widget')
                handler jqueryElem, $scope.genericEventHandlers.widgetSelection.paramName, $scope.widget.name
            firstLoad = false
        
        widgetWithoutPlaceholders = parameterPropagationService.substitutePlaceholders $scope

        checkViewProperties(widgetWithoutPlaceholders)
        checkLayerProperties(widgetWithoutPlaceholders)
        checkControlProperties(widgetWithoutPlaceholders) #done only once because it cannot be parametric
        if not $scope.dataSource?
            checkOverlayProperties(widgetWithoutPlaceholders)

        $scope.mapConfig = mapConfig
    
    $scope.loadWidget()