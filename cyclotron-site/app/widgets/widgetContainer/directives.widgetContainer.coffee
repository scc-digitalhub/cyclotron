cyclotronDirectives.directive 'widgetContainer', ($compile, $window, $timeout, configService, containerLayoutService, logService) ->
    {
        restrict: 'E'
        scope:
            container: '='
            innerWidgets: '='
            page: '='
            pageOverrides: '='
            dashboard: '='
        template: '<div class="dashboard-page dashboard-{{page.theme}} {{page.style}}">' +
            '<div class="container-inner">' +
                '<div class="container-widgetwrapper dashboard-{{widget.theme}} theme-variant-{{widget.themeVariant}}" ng-repeat="widget in innerWidgets track by widget.uid"' +
                ' widget="widget" page="page" page-overrides="pageOverrides" widget-index="$index" layout="layout" dashboard="dashboard" post-layout="postLayout()"></div>' + 
            '</div></div>'
        link: (scope, element, attrs) ->
            $element = $(element) #widget-container, same dimension as $containerWidget
            $containerWidget = $element.children('.dashboard-page')
            $containerInner = $element.find('.container-inner') #actual space for inner widgets, without padding

            masonry = ->
                return unless scope.layout?
                $containerInner.masonry({
                    itemSelector: '.container-widgetwrapper'
                    columnWidth: scope.layout.gridSquareWidth
                    gutter: scope.layout.gutter
                    resize: false
                    transitionDuration: '0.1s'
                    stagger: 5
                })

            updatePage = ->
                # Update the layout -- this triggers all widgets to update
                # Masonry will be called after all widgets have redrawn
                updateLayout = ->

                    # Create a run-once function that triggers Masonry after all the Widgets have drawn themselves
                    scope.postLayout = _.after scope.innerWidgets.length, ->
                        masonry()
                        return

                    containerWidth = $containerWidget.innerWidth()
                    containerHeight = $containerWidget.innerHeight()

                    # Recalculate layout
                    scope.layout = containerLayoutService.getLayout scope.container, containerWidth, containerHeight

                    ###$containerInner.css { 
                        marginRight: '-' + scope.layout.gutter + 'px'
                        marginBottom: '-' + scope.layout.gutter + 'px'
                    }###

                    #Enable/disable scrolling of the container
                    if !scope.layout.scrolling
                        $element.parents().addClass 'fullscreen'
                    else 
                        $element.parents().removeClass 'fullscreen'

                # Update everything
                updateLayout()

                resizeFunction = _.throttle(->
                    scope.$apply updateLayout
                , 65)

                #Update on element resizing
                $element.on 'resize', resizeFunction

                scope.$on '$destroy', ->
                    $element.off 'resize', resizeFunction

                return

            #
            # Watch the container widget and update the layout
            #

            scope.$watch 'container', (container, oldValue) ->
                return if _.isUndefined(container)                
                updatePage()

            #
            # Cleanup
            #
            scope.$on '$destroy', ->
                # Uninitialize Masonry if still present
                if $containerInner.data('masonry')
                    $containerInner.masonry('destroy')
            
            return
    }