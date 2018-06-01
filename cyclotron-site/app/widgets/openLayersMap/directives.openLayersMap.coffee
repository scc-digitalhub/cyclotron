#
cyclotronDirectives.directive 'map', ($window, $timeout, $compile, parameterPropagationService) ->
    {
        restrict: 'C'
        scope:
            mapConfig: '='
            layerOptions: '='
            sourceOfParams: '='
            widgetType: '='
            controlOptions: '='
        
        link: (scope, element, attrs) ->
            map = null
            currentMapConfig = null
            resize = ->
                #TODO improve
                if map?
                    map.updateSize()
            
            createOverlays = ->
                $timeout ->
                    console.log 'adding overlays to', attrs.id
                    for overlay in scope.mapConfig.overlays
                        overlayElem = document.getElementById overlay.id

                        if overlay.template?
                            content = $compile(overlay.template)(scope)
                            angular.element(overlayElem).append content
                        
                        overlayElem.addEventListener 'click', ->
                            group = this.getAttribute('group')
                            if scope.mapConfig.groups[group].currentOverlay == this.id
                                #either nothing happens or reset scope.mapConfig.groups[group].currentOverlay to ''
                            else
                                scope.mapConfig.groups[group].currentOverlay = this.id
                                #broadcast parameter change if needed
                                if scope.sourceOfParams
                                    parameterPropagationService.parameterBroadcaster scope.widgetType, 'clickOnOverlay', scope.mapConfig.groups[group].currentOverlay, group
                        
                        #add overlay to map
                        config =
                            element: overlayElem
                        if overlay.position? then config.position = ol.proj.fromLonLat(overlay.position)
                        if overlay.positioning? then config.positioning = overlay.positioning
                        map.addOverlay(new ol.Overlay(config))
            
            createMap = ->
                if not map?
                    #create map layers: each layer is structured as {type: string, source: {name: string, configuration: string}}
                    mapLayers = []
                    _.each scope.mapConfig.layersToAdd, (layer) ->
                        options = scope.layerOptions[layer.type]
                        layerConfig = {}
                        if layer.source?
                            configObj = if layer.source.configuration? then _.jsEval layer.source.configuration else {}
                            layerConfig.source = new options.sources[layer.source.name].srcClass(configObj)
                        mapLayers.push new options.olClass(layerConfig)

                    #create map view
                    mapView = new ol.View({
                        center: ol.proj.fromLonLat scope.mapConfig.center
                        zoom: scope.mapConfig.zoom
                    })

                    #create map
                    map = new ol.Map({
                        target: attrs.id
                        layers: mapLayers
                        view: mapView
                        controls: []
                    })
                    
                    #if there are overlays, create them and add them to the map
                    if scope.mapConfig.overlays? and scope.mapConfig.overlays.length > 0
                        createOverlays()

                    #if there are controls, create them and add them to the map
                    if scope.mapConfig.controls? and scope.mapConfig.controls.length > 0
                        _.each scope.mapConfig.controls, (control) ->
                            map.addControl(new scope.controlOptions[control]())

                    console.log 'map created'
                else
                    map.updateSize()

            #if layer source has changed (i.e. because it is parametric), update it on the map
            updateLayers = (newConfig) ->
                console.log 'updating layers'
                _.each newConfig.layersToAdd, (layer, index) ->
                    if layer.source?.configuration? and not
                            _.isEqual(layer.source.configuration, currentMapConfig.layersToAdd[index].source.configuration)
                        currentLayer = map.getLayers().getArray()[index]
                        configObj = _.jsEval layer.source.configuration
                        newSource = new scope.layerOptions[layer.type].sources[layer.source.name].srcClass(configObj)
                        currentLayer.setSource(newSource)
                currentMapConfig.layersToAdd = _.cloneDeep newConfig.layersToAdd

            #if overlay content has changed (i.e. because it is parametric), update it on the map
            updateOverlays = (newConfig) ->
                console.log 'updating overlays'
                if map.getOverlays().getLength() == 0
                    #map has no overlay yet (i.e. overlays are provided by a datasource which has just finished executing)
                    createOverlays()
                    currentMapConfig.overlays = _.cloneDeep newConfig.overlays
                else
                    _.each newConfig.overlays, (overlay, index) ->
                        if not _.isEqual(overlay.template, currentMapConfig.overlays[index].template)
                            newContent = $compile(overlay.template)(scope)
                            overlayElem = document.getElementById overlay.id
                            angular.element(overlayElem).contents().remove()
                            angular.element(overlayElem).append newContent
                    currentMapConfig.overlays = _.cloneDeep newConfig.overlays
            
            scope.$watch('mapConfig', (mapConfig, oldMapConfig) ->
                return unless mapConfig
                console.log 'mapConfig changed', attrs.id
                if map?
                    #check each property to find what is different and update the map accordingly
                    for key in _.keys(mapConfig)
                        if not _.isEqual(mapConfig[key], currentMapConfig[key])
                            switch key
                                when 'zoom' then map.getView().setZoom(mapConfig.zoom)
                                when 'center' then map.getView().setCenter(ol.proj.fromLonLat(mapConfig.center))
                                when 'layersToAdd' then updateLayers(mapConfig)
                                when 'overlays' then updateOverlays(mapConfig)
                else
                    console.log 'creating map'
                    currentMapConfig = _.cloneDeep mapConfig
                    createMap()
            , true)
            
            # Update on window resizing
            resizeFunction = _.debounce resize, 100, { leading: false, maxWait: 300 }
            $(window).on 'resize', resizeFunction

            # Cleanup
            scope.$on '$destroy', ->
                console.log 'destroy was called'
                $(window).off 'resize', resizeFunction
                map.setTarget(null)
                map = null
            
            return
    }
