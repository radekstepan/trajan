#!/usr/bin/env coffee
child_process = require 'child_process'
{ _ }         = require 'underscore'
winston       = require 'winston'

# Nice logging.
winston.cli()

# Link to main apps storage.
{ apps } = require '../samfelld.coffee'

module.exports =
    get: ->
        winston.debug 'Get status of all apps'
        
        req = @req
        res = @res

        res.writeHead 200, 'content-type': 'application/json'
        res.write JSON.stringify 'apps': apps
        res.end()

    '/:pid':
        get: (pid) ->
            winston.debug 'Get status of one app'
            
            req = @req
            res = @res

            # Find the app.
            app = ( app for app in apps.up when app.pid is parseInt(pid) ).pop()
            if app
                res.writeHead 200, 'content-type': 'application/json'
                res.write JSON.stringify 'app':
                    'status': 'up'
                    'port': app.port
                res.end()
            else
                res.writeHead 200, 'content-type': 'application/json'
                res.write JSON.stringify 'app':
                    'status': 'down'
                res.end()