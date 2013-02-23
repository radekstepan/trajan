#!/usr/bin/env coffee
request  = require 'request'

{ start } = require './samfelld.coffee'

# Start.
start (cfg) ->
    # Then deploy.
    request
        'method': 'POST'
        'uri': "http://127.0.0.1:#{cfg.deploy_port}/api/deploy"
        'headers':
            'x-auth-token': 'abc'
    , (err, res, body) ->
        if err then throw err

        body = JSON.stringify JSON.parse(body), null, 2
        console.log "#{res.statusCode}: #{body}"

        { pid } = JSON.parse body

        do status = ->
            # Get all dynos.
            request
                'method': 'GET'
                'uri': "http://127.0.0.1:#{cfg.deploy_port}/api/dynos"
                'headers':
                    'x-auth-token': 'abc'
            , (err, res, body) ->
                if err then throw err

                body = JSON.stringify JSON.parse(body), null, 2
                console.log "#{res.statusCode}: #{body}"
                
                # Check again.
                setTimeout status, 1000