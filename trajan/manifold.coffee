#!/usr/bin/env coffee
async   = require 'async'
path    = require 'path'

{ log, processes } = require path.resolve __dirname, '../trajan.coffee'
Dyno               = require path.resolve __dirname, './dyno.coffee'

class Manifold

    # An increasing id count.
    id: 0

    # All dynos we know of.
    dynos: {}

    # Proxy ports of online dynos to use.
    ports: []
    
    # Get an available dyno port.
    getPort: ->
        if port = @ports.shift()
            @ports.push port
            return port

    # Get back a dyno.
    getDyno: (id, cb) ->
        id = parseInt id
        if dyno = @dynos[id]
            # Now get the stats about the process.
            processes.getStats dyno.pid, (stats) ->
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
        for id, dyno of @dynos then do (dyno) ->
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
    removeDyno: (id) -> delete @dynos[id]
    
    # Ask existing dynos to wind down.
    offlineDynos: ->
        for id, dyno of @dynos when dyno.status is 'up'
            # Send the message.
            dyno.process.send 'Die'
            # Set the status to going down.
            dyno.status = 'down'
            # Remove from available ports.
            idx = @ports.indexOf dyno.port
            @ports.splice idx, 1

        # Now make all ready ones available for use.
        for id, dyno of @dynos when dyno.status is 'ready'
            dyno.status = 'up'
            # Push to the stack of ports.
            @ports.push dyno.port
            # Say it.
            log.info "Dyno #{(dyno.id+'').bold} accepting connections on port #{(dyno.port+'').bold}"

    # Generate a new shell dyno instance
    newDyno: (name, env, cb) ->
        # Do we already have a name?
        if @name and name isnt @name then cb 'App names do not match'
        else
            # Save the name.
            @name = name

            id = @id++
            # Instantiate the obj and save on us.
            @dynos[id] = dyno = new Dyno id, name, env, @

            # Return the dyno.
            cb null, dyno

module.exports = Manifold