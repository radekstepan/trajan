#!/usr/bin/env coffee
child_process = require 'child_process'
{ _ }         = require 'underscore'
winston       = require 'winston'

# Nice logging.
winston.cli()

# Link to main apps storage.
{ apps } = require '../samfelld.coffee'

module.exports = ->
    winston.debug 'Deploying app'
    
    req = @req
    res = @res

    # Example app to launch.
    app = child_process.fork './example-app/start.js',
        # 'env': _.extend { 'PORT': 7000 }, process.env
        'silent': true

    winston.info "Deploying app #{('pid '+app.pid).bold}"

    # Say when app is dead.
    app.on 'exit', onExit

    # Messaging from the app.
    app.on 'message', onMessage

onExit = (code) ->
    winston.warn "App #{('pid '+@pid).bold} exited"
    # Remove it from the going down stack.
    for i, ch of apps.down
        if ch.pid is @pid
            return apps.down.splice 0, i

onMessage = (data) ->
    switch data.message
        when 'online'
            winston.info "App online on port #{(data.port+'').bold}"
            
            # Offline existing app(s).
            while apps.up.length isnt 0
                ch = apps.up.pop()
                # Send message.
                ch.ref.send 'Die'
                # To down stack.
                apps.down.push ch

            # Save us as a new online app.
            obj =
                'ref': @
                'pid': @pid
                'port': data.port

            apps.up.push obj