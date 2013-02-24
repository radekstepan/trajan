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
    dynos:
        'up': []
        'down': []

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
        if dyno = @dynos.up.shift()
            @stack.push dyno
            return dyno.port

    _findDyno: (pid) ->
        # Enforce int.
        pid = parseInt pid
        # All statuses.
        for status in [ 'up', 'down' ]
            pkg = (dyno) -> { 'port': dyno.port, 'pid': dyno.pid, 'status': status }
            if (dyno = ( pkg(dyno) for dyno in @dynos[status] when dyno.pid is pid ).pop())
                return dyno

    # Get back a dyno.
    getDyno: (pid, cb) ->
        if dyno = @_findDyno pid
            # Now get the stats about the process.
            processes.getStats pid, (stats) ->
                if stats then dyno.stats = stats
                cb dyno
        else
            cb null

    # Get all dynos back.
    getDynos: (cb) ->
        fns = []
        for status in [ 'up', 'down' ]
            for dyno in @dynos[status] then do (dyno) ->
                # Add a bound function to stats booster.
                fns.push (_cb) ->
                    processes.getStats dyno.pid, (stats) ->
                        # Build a package.
                        pkg = { 'port': dyno.port, 'pid': dyno.pid, 'status': status }
                        # Stats?
                        if stats then pkg.stats = stats
                        # Cb then.
                        _cb null, pkg

        # One big parallel run.
        async.parallel fns, (err, dynos) ->
            if err then throw err
            cb dynos

    # Remove a dyno that has wound down.
    removeDyno: (pid) -> delete @dynos.down[pid]
    
    # Ask existing dynos to wind down.
    offlineDynos: ->
        while dyno = @dynos.up.pop()
            # Send the message.
            dyno.ref.send('Die')
            # Push to winding down ones.
            @dynos.down.push dyno

    # Save a dyno that has come online.
    saveDyno: (obj) -> @dynos.up.push obj

module.exports = Manifold