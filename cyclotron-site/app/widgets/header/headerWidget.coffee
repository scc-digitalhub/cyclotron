###
# Copyright (c) 2013-2015 the original author or authors.
#
# Licensed under the MIT License (the "License");
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at
#
#     http://www.opensource.org/licenses/mit-license.php
#
# Unless required by applicable law or agreed to in writing, 
# software distributed under the License is distributed on an 
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
# either express or implied. See the License for the specific 
# language governing permissions and limitations under the License. 
###

#
# Header Widget
#
cyclotronApp.controller 'HeaderWidget', ($scope, $sce, $element, configService, parameterPropagationService) ->
    #check parameters
    $scope.randomId = '' + Math.floor(Math.random()*1000)
    parameterPropagationService.checkParameterSubscription $scope
    parameterPropagationService.checkGenericParams $scope

    if $scope.genericEventHandlers?.widgetSelection?
        handler = $scope.genericEventHandlers.widgetSelection.handler
        jqueryElem = $($element).closest('.dashboard-widget')
        handler jqueryElem, $scope.genericEventHandlers.widgetSelection.paramName, $scope.widget.name

    #update configuration with new parameter values
    widgetWithoutPlaceholders = null

    # Override the widget feature of exporting data, since there is no data
    $scope.widgetContext.allowExport = false

    $scope.loadWidget = ->
        #update configuration with new parameter values
        widgetWithoutPlaceholders = parameterPropagationService.substitutePlaceholders $scope
    
        $scope.headerTitle = _.compile widgetWithoutPlaceholders.headerTitle

        # Load user-specified format if defined
        if $scope.headerTitle.showTitle == true 
            $scope.showTitle = true
            $scope.title = _.jsExec(widgetWithoutPlaceholders.title) || _.jsExec($scope.dashboard.displayName) || $scope.dashboard.name

            $scope.pageNameSeparator ?= ''

        if widgetWithoutPlaceholders.customHtml?
            $scope.showCustomHtml = true

            $scope.customHtml = ->
                $sce.trustAsHtml _.jsExec(widgetWithoutPlaceholders.customHtml)

        $scope.showParameters = widgetWithoutPlaceholders.parameters?.showParameters == true

        # If Parameters are show in the Widget...
        if $scope.showParameters
            $scope.showUpdateButton = widgetWithoutPlaceholders.parameters.showUpdateButton
            $scope.updateButtonLabel = widgetWithoutPlaceholders.parameters.updateButtonLabel || 'Update'

            $scope.parameters = _.filter $scope.dashboard.parameters, { editInHeader: true }

            # Filter further using the Widget's parametersIncluded property
            if _.isArray(widgetWithoutPlaceholders.parameters.parametersIncluded) and widgetWithoutPlaceholders.parameters.parametersIncluded.length > 0
                $scope.parameters = _.filter $scope.parameters, (param) ->
                    _.contains widgetWithoutPlaceholders.parameters.parametersIncluded, param.name

            updateEventHandler = _.jsEval widgetWithoutPlaceholders.parameters.updateEvent
            if !_.isFunction(updateEventHandler) then updateEventHandler = null

            $scope.updateButtonClick = ->
                updateEventHandler() unless _.isNull updateEventHandler
                parameterPropagationService.parameterBroadcaster 'header', null, null, null, $scope.parameters
    
    $scope.loadWidget()
    ###
    Since header widget updates parameters, although non-automatically, which might be used by parametric elements,
    parameter change is broadcasted in updateButtonClick() (for all $scope.parameters) and in directive's updateParameter().

    TODO: add option "notify widgets of parameter changes" in the configuration and broadcast only if true
    ###