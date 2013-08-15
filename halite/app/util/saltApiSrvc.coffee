###
usage:

mainApp = angular.module("MainApp", [... 'saltApiSrvc'])


mainApp.controller 'MyCtlr', ['$scope', ...,'SaltApiSrvc',
    ($scope,...,SaltApiSrvc) ->

    $scope.saltApiCallPromise = SaltApiSrvc.act $scope, [{'name':'John'}]
    $scope.saltApiCallPromise.success (data, status, headers, config) ->
        console.log("SaltApi call success")
        $scope.result = data
        return true

    $scope.saltApiLoginPromise = SaltApiSrvc.login $scope, 'usernamestring', 'passwordstring'
    $scope.saltApiLoginPromise.success (data, status, headers, config) ->
        console.log("SaltApi login success")
        $scope.result = data
        return true

###


saltApiSrvc = angular.module("saltApiSrvc", ['appConfigSrvc', 'appPrefSrvc', 'appStoreSrvc'])

saltApiSrvc.factory "SaltApiSrvc", ['$http', 'Configuration', 'AppPref', 'SessionStore',
    ($http, Configuration, AppPref, SessionStore) ->
        saltApi = AppPref.get('saltApi')
        if saltApi.scheme or saltApi.host or saltApi.port # absolute
            if not saltApi.scheme
                saltApi.scheme = "http"
            if not saltApi.host
                saltApi.host = "localhost"
            if saltApi.port
                saltApi.port = ":#{saltApi.port}"
            base = "#{saltApi.scheme}://#{saltApi.host}#{saltApi.port}#{saltApi.prefix}"
        else # relative
            base = "#{saltApi.prefix}"


        # Remove noise header; not used by salt-api
        delete $http.defaults.headers.common['X-Requested-With']
        $http.defaults.useXDomain = true # enable cors on IE

        servicer =
            run: ($scope, cmds) ->
                headers =
                    "X-Auth-Token": SessionStore.get('saltApiAuth')?.token

                config =
                    headers: headers
                url = "#{base}/"
                $http.post( url, cmds, config  )
                .success((data, status, headers, config) ->
                    #console.log "act token"
                    #console.log SessionStore.get('saltApiAuth')?.token
                    return true
                )
                .error((data, status, headers, config) ->
                    $scope.errorMsg = "Call Failed!"
                    return true
                )
            act: ($scope, cmds) ->
                headers =
                    "X-Auth-Token": SessionStore.get('saltApiAuth')?.token

                config =
                    headers: headers
                url = "#{base}/"
                $http.post( url, cmds, config  )
                .success((data, status, headers, config) ->
                    #console.log "act token"
                    #console.log SessionStore.get('saltApiAuth')?.token
                    return true
                )
                .error((data, status, headers, config) ->
                    $scope.errorMsg = "Call Failed!"
                    return true
                )
            action: ($scope, cmds) ->
                headers =
                    "X-Auth-Token": SessionStore.get('saltApiAuth')?.token
                config =
                    headers: headers
                url = "#{base}/"
                
                $scope.command.lastCmd = cmds
                if not angular.isArray(cmds)
                    cmds = [cmds]
                
                $http.post( url, cmds, config  )
                .success((data, status, headers, config) ->
                    $scope.command.history[JSON.stringify($scope.command.lastCmd)] = 
                        $scope.command.lastCmd
                    #console.log "act token"
                    #console.log SessionStore.get('saltApiAuth')?.token
                    return true
                )
                .error((data, status, headers, config) ->
                    $scope.errorMsg = "Call Failed!"
                    return true
                )
            login: ($scope, username, password) ->
                reqData =
                    "username": username
                    "password": password
                    "eauth": saltApi.eauth

                url = "#{base}/login"
                $http.post( url, reqData)
                .success((data, status, headers, config) ->
                    return true
                )
                .error((data, status, headers, config) ->
                    $scope.errorMsg = "Login Failed!"
                    return true
                )
            logout: ($scope) ->
                headers =
                    "X-Auth-Token": SessionStore.get('saltApiAuth')?.token
                config =
                    headers: headers
                url = "#{base}/logout"
                $http.post( url, {}, config)
                .success((data, status, headers, config) ->
                    return true
                )
                .error((data, status, headers, config) ->
                    $scope.errorMsg = "Logout Failed!"
                    return true
                )
        
        return servicer

    ]

###
usage:

mainApp = angular.module("MainApp", [... 'saltApiSrvc'])

mainApp.controller 'MyCtlr', ['$scope', ...,'SaltApiEvtSrvc',
    ($scope,...,SaltApiEvtSrvc) ->

    $scope.saltApiCallPromise = SaltApiSrvc.act $scope, [{'name':'John'}]
    $scope.saltApiCallPromise.success (data, status, headers, config) ->
        console.log("SaltApi call success")
        $scope.result = data
        return true

    $scope.saltApiLoginPromise = SaltApiSrvc.login $scope, 'usernamestring', 'passwordstring'
    $scope.saltApiLoginPromise.success (data, status, headers, config) ->
        console.log("SaltApi login success")
        $scope.result = data
        return true

###
saltApiSrvc.factory "SaltApiEvtSrvc", [ '$rootScope', '$http', 'AppPref', 'SessionStore', '$q',
    ($rootScope, $http, AppPref, SessionStore, $q) ->
        saltApi = AppPref.get('saltApi')
        if saltApi.scheme or saltApi.host or saltApi.port # absolute
            if not saltApi.scheme
                saltApi.scheme = "http"
            if not saltApi.host
                saltApi.host = "localhost"
            if saltApi.port
                saltApi.port = ":#{saltApi.port}"
            base = "#{saltApi.scheme}://#{saltApi.host}#{saltApi.port}#{saltApi.prefix}"
        else # relative
            base = "#{saltApi.prefix}"

        # Remove noise header; not used by salt-api
        delete $http.defaults.headers.common['X-Requested-With']
        $http.defaults.useXDomain = true # enable cors on IE
        
        defer = null
        sse = null
        
        onError = (event) ->
            #console.log "SSE Error:"
            #console.log event
            defer?.reject "SSE Errored"
            return true
        
        onOpen = (event) ->
            console.log "SSE Open:" 
            console.log event 
            $rootScope.$apply(defer?.resolve(event))
            return true
        
        onMessage = (event) ->
            console.log "SSE Message:" 
            data = angular.fromJson(event.data)
            #console.log(data)
            servicer.process?(data)
            return true
 
        servicer =
            close: ($scope) ->
                sse?.close()
            
            events: ($scope, process) ->
                token = SessionStore.get('saltApiAuth')?.token
                url = "#{base}/events/#{token}"
                #console.log "event url"
                #console.log url
                sse = new EventSource(url);
                sse.onerror = onError
                sse.onopen =onOpen
                sse.onmessage = onMessage
                @process = process #callback to process an event with data
                defer = $q.defer()  #on the creation of the stream
                return defer.promise

        return servicer

    ]