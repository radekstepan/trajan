#!/usr/bin/env coffee
child_process = require 'child_process'
{ _ }         = require 'underscore'
path          = require 'path'

# Link to main manifold.
{ log, manifold } = require path.resolve(__dirname, '../../trajan.coffee')

module.exports =
    get: ->
        log.debug 'Get all dynos'
        
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

    '/:id':
        get: (id) ->
            log.debug 'Get one dyno'
            
            req = @req
            res = @res

            # Find a single dyno.
            manifold.getDyno id, (dyno) ->
                if dyno
                    res.writeHead 200, 'content-type': 'application/json'
                    res.write JSON.stringify 'dyno': dyno
                    res.end()
                else                    
                    res.writeHead 404, 'content-type': 'application/json'
                    res.write JSON.stringify 'message': 'Dyno not found'
                    res.end()