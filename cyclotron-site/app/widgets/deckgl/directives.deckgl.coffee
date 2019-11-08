#
###
deck.DeckGL properties:
- container (DOMElement | String, optional)
###
cyclotronDirectives.directive 'theDeck', ($window, $timeout, $compile, parameterPropagationService, logService) ->
    {
        restrict: 'C'
        scope:
            deckConfig: '='
        
        link: (scope, element, attrs) ->
            currentDeck = null
            currentDeckConfig = null

            resize = ->
                #currentDeck.redraw(false) #redraw deck if necessary
                if currentDeck?
                    console.log 'resizing deck'

            createDeck = ->
                console.log 'creating deck'

                deckLayers = []
                _.each scope.deckConfig.layersToAdd, (layer) ->
                    deckLayers.push new deck[layer.type](layer.configProperties)

                currentDeck = new deck.DeckGL({
                    container: attrs.id
                    viewState: scope.deckConfig.viewState
                    controller: true #default MapController to make the map interactive
                    layers: deckLayers
                })

                if scope.deckConfig.additionalDeckProps?
                    #add additional properties
                    currentDeck.setProps scope.deckConfig.additionalDeckProps

            scope.$watch('deckConfig', (deckConfig, oldDeckConfig) ->
                return unless deckConfig
                if currentDeck?
                    #update deck layers
                    newLayers = []
                    _.each deckConfig.layersToAdd, (layer) ->
                        newLayers.push new deck[layer.type](layer.configProperties)
                    
                    currentDeck.setProps {layers: newLayers}
                    currentDeckConfig.layersToAdd = _.cloneDeep deckConfig.layersToAdd
                else
                    currentDeckConfig = _.cloneDeep deckConfig
                    createDeck()
            , true)

            # Update on window resizing
            resizeFunction = _.debounce resize, 100, { leading: false, maxWait: 300 }
            $(window).on 'resize', resizeFunction

            # Cleanup
            scope.$on '$destroy', ->
                $(window).off 'resize', resizeFunction
                currentDeck.finalize() #free resources immediately rather than waiting for garbage collection
                currentDeck = null

            return
    }