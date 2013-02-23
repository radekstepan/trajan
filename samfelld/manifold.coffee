#!/usr/bin/env coffee
{ processes } = require '../samfelld.coffee'

class Manifold

    # All dynos we know of.
    dynos:
        'up': []
        'down': []

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
            ret = (dyno) -> { 'port': dyno.port, 'status': status }
            if (dyno = ( ret(dyno) for dyno in @dynos[status] when dyno.pid is pid ).pop())
                return dyno

    # Get back a dyno.
    getDyno: (pid, cb) ->
        if dyno = @_findDyno pid
            # Now get the usage.
            processes.getUsage pid, (data) ->
                dyno.memory = data
                cb dyno
        else
            cb null

    # Get all dynos back.
    getDynos: (cb) ->

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