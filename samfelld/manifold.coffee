#!/usr/bin/env coffee
async         = require 'async'
child_process = require 'child_process'
{ _ }         = require 'underscore'
winston       = require 'winston'
path          = require 'path'

{ processes } = require path.resolve(__dirname, '../samfelld.coffee')

# Nice logging.
winston.cli()

class Manifold

    # All dynos we know of.
    dynos: {}

    # Proxy ports of online dynos to use.
    ports: []

    # Spawn an app into a dyno.
    spawn: (name) ->
        # Example app to launch.
        app = child_process.fork path.resolve(__dirname, "../apps/#{name}/start.js"),
            # 'env': _.extend { 'PORT': 7000 }, process.env
            'silent': true # cannot pipe out to a file :(

        # Save pid.
        processes.save app.pid

        winston.info "Starting app #{('pid '+app.pid).bold}"

        manifold = @

        # Say when app is dead.
        app.on 'exit', (code) ->
            winston.warn "App #{('pid '+@pid).bold} exited"
            # Remove it from the going down stack.
            manifold.removeDyno @pid
            # Remove from pids.
            processes.remove @pid

        # Messaging from the app.
        app.on 'message', (data) ->
            switch data.message
                when 'online'
                    winston.info "App online on port #{(data.port+'').bold}"
                    
                    # Offline existing app(s).
                    manifold.offlineDynos()

                    # Save us as a new online app.
                    manifold.saveDyno { 'ref': @, 'pid': @pid, 'port': data.port }

        # Just return the pid.
        app.pid
    
    # Get an available dyno port.
    getPort: ->
        if port = @ports.shift()
            @ports.push port
            return port

    # Get back a dyno.
    getDyno: (pid, cb) ->
        pid = parseInt pid
        if dyno = @dynos[pid]
            # Now get the stats about the process.
            processes.getStats pid, (stats) ->
                # Form a deep copy obj wo/ ref.
                obj = {}
                ( obj[key] = dyno[key] for key in [ 'port', 'pid', 'status' ] )
                # Boost w/ stats?
                if stats then obj.stats = stats
                # We done...
                cb dyno
        else
            cb null

    # Get all dynos back.
    getDynos: (cb) ->
        fns = []
        for pid, dyno of @dynos then do (dyno) ->
            # Add a bound function to stats booster.
            fns.push (_cb) ->
                processes.getStats dyno.pid, (stats) ->
                    # Form a deep copy obj wo/ ref.
                    obj = {}
                    ( obj[key] = dyno[key] for key in [ 'port', 'pid', 'status' ] )
                    # Boost w/ stats?
                    if stats then obj.stats = stats
                    # We done...
                    _cb null, obj

        # One big parallel run.
        async.parallel fns, (err, dynos) ->
            if err then throw err
            else cb dynos

    # Remove a dyno that has wound down.
    removeDyno: (pid) -> delete @dynos[pid]
    
    # Ask existing dynos to wind down.
    offlineDynos: ->
        for pid, dyno of @dynos when dyno.status is 'up'
            # Send the message.
            dyno.ref.send 'Die'
            # Set the status to going down.
            dyno.status = 'down'
            # Remove from available ports.
            idx = @ports.indexOf dyno.port
            @ports.splice idx, 1

    # Save a dyno that has come online.
    saveDyno: (dyno) ->
        # The status.
        dyno.status = 'up'
        # The dict.
        @dynos[dyno.pid] = dyno
        # The port.
        @ports.push dyno.port

module.exports = Manifold