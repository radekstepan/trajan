#!/usr/bin/env coffee
child_process = require 'child_process'
{ _ }         = require 'underscore'
winston       = require 'winston'

# Nice logging.
winston.cli()

# Link to main manifold.
{ manifold } = require '../../samfelld.coffee'

module.exports =
    get: ->
        winston.debug 'Get status of all apps'
        
        req = @req
        res = @res

        res.writeHead 200, 'content-type': 'application/json'
        res.write JSON.stringify 'dynos': manifold
        res.end()

    '/:pid':
        get: (pid) ->
            winston.debug 'Get status of one app'
            
            req = @req
            res = @res

            # Find a single dyno.
            if dyno = manifold.getDyno(pid)
                res.writeHead 200, 'content-type': 'application/json'
                res.write JSON.stringify 'dyno': dyno
                res.end()
            else
                res.writeHead 404, 'content-type': 'application/json'
                res.write JSON.stringify 'message': 'Dyno not found'
                res.end()