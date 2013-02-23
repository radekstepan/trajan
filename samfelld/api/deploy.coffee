#!/usr/bin/env coffee
child_process = require 'child_process'
{ _ }         = require 'underscore'
winston       = require 'winston'

# Nice logging.
winston.cli()

# Link to main manifold & processes.
{ manifold, processes } = require '../../samfelld.coffee'

exports.post = ->
    winston.debug 'Deploying app'
    
    req = @req
    res = @res

    # Example app to launch.
    app = child_process.fork './example-app/start.js',
        # 'env': _.extend { 'PORT': 7000 }, process.env
        'silent': true

    # Save pid.
    processes.save app.pid

    winston.info "Deploying app #{('pid '+app.pid).bold}"

    # Say when app is dead.
    app.on 'exit', onExit

    # Messaging from the app.
    app.on 'message', onMessage

    # Respond with the pid of the app being deployed.
    res.writeHead 200, 'content-type': 'application/json'
    res.write JSON.stringify 'pid': app.pid
    res.end()

onExit = (code) ->
    winston.warn "App #{('pid '+@pid).bold} exited"
    # Remove it from the going down stack.
    manifold.removeDyno @pid
    # Remove from pids.
    processes.remove @pid

onMessage = (data) ->
    switch data.message
        when 'online'
            winston.info "App online on port #{(data.port+'').bold}"
            
            # Offline existing app(s).
            manifold.offlineDynos()

            # Save us as a new online app.
            manifold.saveDyno { 'ref': @, 'pid': @pid, 'port': data.port }