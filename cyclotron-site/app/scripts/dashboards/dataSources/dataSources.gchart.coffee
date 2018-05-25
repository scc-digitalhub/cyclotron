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
# Mock Data Source
# Injected by the DataService as needed
# Supports one property, 'format', that determines whether the mock data 
# should be object-based or row-based.
#
cyclotronDataSources.factory 'gchartDataSource', ($q, dataSourceFactory, logService) ->

    # Ducati initializations
    getDucatiFunction = ->
        gb = 2500
        rn = 70
        grossBookings = -> Math.floor(gb + (Math.random() * 5000 - 2500))
        roomNights = -> Math.floor(rn + (Math.random() * 170 - 70))
        startTime = moment().startOf('minute')
        
        return (num) ->
            return {
                id: num
                _time: moment(startTime).add(num, 'minutes').unix()
                grossbookingvalue: grossBookings()
                roomnightcount: roomNights()
            }
    
    runner = (options, state) ->
        q = $q.defer()    

        if !options.format? || options.format == 'object'
            state.cache = [ 
                {
                    "cols": [
                        {
                        "id": "month",
                        "label": "Month",
                        "type": "string",
                        "p": {}
                        },
                        {
                        "id": "laptop-id",
                        "label": "Laptop",
                        "type": "number",
                        "p": {}
                        },
                        {
                        "id": "desktop-id",
                        "label": "Desktop",
                        "type": "number",
                        "p": {}
                        },
                        {
                        "id": "server-id",
                        "label": "Server",
                        "type": "number",
                        "p": {}
                        },
                        {
                        "id": "cost-id",
                        "label": "Shipping",
                        "type": "number"
                        }
                    ],
                    "rows": [
                        {
                        "c": [
                            {
                            "v": "January"
                            },
                            {
                            "v": 19,
                            "f": "42 items"
                            },
                            {
                            "v": 12,
                            "f": "Ony 12 items"
                            },
                            {
                            "v": 7,
                            "f": "7 servers"
                            },
                            {
                            "v": 4
                            }
                        ]
                        },
                        {
                        "c": [
                            {
                            "v": "February"
                            },
                            {
                            "v": 13
                            },
                            {
                            "v": 1,
                            "f": "1 unit (Out of stock this month)"
                            },
                            {
                            "v": 12
                            },
                            {
                            "v": 2
                            }
                        ]
                        },
                        {
                        "c": [
                            {
                            "v": "March"
                            },
                            {
                            "v": 24
                            },
                            {
                            "v": 5
                            },
                            {
                            "v": 11
                            },
                            {
                            "v": 6
                            }
                        ]
                        }
                    ]
                }
                ###
                {color: "red", number: 1, state: "WA", status: "green"}
                {state: "CA", color: "green", number: 41, status: "green"}
                {state: "CA", color: "red", number: 2, status: "green"}
                {color: "red", number: 15, state: "WA", country: "USA", status: "green"}
                {color: "blue", number: 23, state: "CO", status: "yellow"}
                {color: "black", number: 45, state: "WA", status: "red"}
                {color: "green", number: 32, state: "WA", status: "yellow"}
                {color: "green", number: 99, state: "WA", status: "yellow"}
                {color: "black", number: 1, state: "WA", status: "red"}
                {color: "black", number: 45, state: "CA", status: "red"}
                {color: "white", number: 24, state: "AK", status: "red"}
                {color: "white", number: 16, state: "AK", status: "yellow"}
                ###
            ]

        else if options.format == 'pie'
            state.cache = [ 
                {browser: "Firefox", percent: 45, isSliced: true},
                {browser: "IE", percent: 26.8, isSliced: false},
                {browser: "Chrome", percent: 12.8, isSliced: false},
                {browser: "Safari", percent: 8.5, isSliced: false},
                {browser: "Opera", percent: 6.2, isSliced: false},
                {browser: "Other", percent: 0.7, isSliced: false}
            ]

        else if options.format == 'ducati'
            if state.cache?
                state.cache.push state.ducati(_.last(state.cache).id + 1)
                state.cache = _.tail(state.cache)
            else
                state.ducati = getDucatiFunction()
                state.cache = (state.ducati(num) for num in [0..10])

        q.resolve
            '0':
                data: state.cache
                columns: null

        q.promise

    dataSourceFactory.create 'gcart', runner
