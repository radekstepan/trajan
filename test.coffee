request  = require 'request'

{ deploy } = require './samfelld.coffee'

# Make continuous requests.
do poll = ->
    setTimeout ->
        request
            'method': 'GET'
            'uri': "http://127.0.0.1:8000/api"
        , (err, res, body) ->
            if err then return winston.error err
            console.log "#{res.statusCode}: #{body}"
            poll()
    , 1000

# Continuously deploy.
do refresh = ->
    setTimeout ->
        deploy()
        refresh()
    , 4000