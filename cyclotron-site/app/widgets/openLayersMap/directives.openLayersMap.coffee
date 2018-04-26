#
cyclotronDirectives.directive 'map', ($window) ->
    {
        restrict: 'C'
        #scope:
        
        link: (scope, element, attrs) ->
            mapLayers = [
                new ol.layer.Tile({
                    source: new ol.source.OSM()
                })
            ]

            mapView = new ol.View({
                center: ol.proj.fromLonLat [37.41, 8.82]
                zoom: 4
            })

            mapConfig =
                target: attrs.id
                layers: mapLayers
                view: mapView

            createMap = ->
                map = new ol.Map(mapConfig)
                console.log 'here'
            
            createMap()
            
            #scope.$watch 'sliderconfig', (sliderconfig) ->
            
            # Update on window resizing
            resizeFunction = _.debounce createMap, 100, { leading: false, maxWait: 300 }
            $(window).on 'resize', resizeFunction

            # Cleanup
            scope.$on '$destroy', ->
                $(window).off 'resize', resizeFunction
                #sliderElement.noUiSlider.destroy()
            
            return
    }
