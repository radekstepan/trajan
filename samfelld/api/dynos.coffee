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
        winston.debug 'Get all dynos'
        
        req = @req
        res = @res

        # Get all dynos back.
        manifold.getDynos (dynos) ->
            if dynos
                res.writeHead 200, 'content-type': 'application/json'
                res.write JSON.stringify 'dynos': dynos
                res.end()
            else
                res.writeHead 404, 'content-type': 'application/json'
                res.write JSON.stringify 'message': 'No dynos found'
                res.end()

    '/:pid':
        get: (pid) ->
            winston.debug 'Get one dyno'
            
            req = @req
            res = @res

            # Find a single dyno.
            manifold.getDyno pid, (dyno) ->
                if dyno
                    res.writeHead 200, 'content-type': 'application/json'
                    res.write JSON.stringify 'dyno': dyno
                    res.end()
                else                    
                    res.writeHead 404, 'content-type': 'application/json'
                    res.write JSON.stringify 'message': 'Dyno not found'
                    res.end()