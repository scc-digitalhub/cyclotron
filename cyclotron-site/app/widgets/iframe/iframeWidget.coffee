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
# Iframe Widget
#
cyclotronApp.controller 'IframeWidget', ($scope, $element, parameterPropagationService) ->
    #check parameters
    $scope.randomId = '' + Math.floor(Math.random()*1000)
    parameterPropagationService.checkParameterSubscription $scope
    parameterPropagationService.checkGenericParams $scope

    if $scope.genericEventHandlers?.widgetSelection?
        handler = $scope.genericEventHandlers.widgetSelection.handler
        jqueryElem = $($element).closest('.dashboard-widget')
        handler jqueryElem, $scope.genericEventHandlers.widgetSelection.paramName, $scope.widget.name

    #substitute any parameter placeholders in the configuration
    widgetWithoutPlaceholders = parameterPropagationService.substitutePlaceholders $scope

    # Override the widget feature of exporting data, since there is no data
    $scope.widgetContext.allowExport = false
    
    $scope.getUrl = ->
        return '' if _.isEmpty($scope.widget.url)

        url = widgetWithoutPlaceholders.url

        if url.indexOf('http') != 0
            url = 'http://' + url

        return $scope.$sce.trustAsResourceUrl(url)

    $scope.loadWidget = ->
        #update configuration with new parameter values
        widgetWithoutPlaceholders = parameterPropagationService.substitutePlaceholders $scope