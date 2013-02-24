#!/usr/bin/env coffee
path  = require 'path'
fs    = require 'fs'
async = require 'async'

# Link to main manifold.
{ log, cfg } = require path.resolve(__dirname, '../../trajan.coffee')

module.exports =
    '/:name':
        post: (name) ->
            log.debug 'Setting env var'

            req = @req
            res = @res

            # Get key, value pair.
            key = req.body.key
            value = req.body.value

            # Is value an int?
            if not isNaN(parseFloat(value)) and isFinite(value) then value = +value

            # Where to?
            file = path.resolve __dirname, '../../config.json'

            async.waterfall [ (cb) ->
                # Read the live config file.
                fs.readFile file, 'utf8', (err, data) ->
                    if err then cb err
                    else
                        try
                            obj = JSON.parse data
                        catch e
                            cb e

                        # Boost the new env.
                        obj.env ?= {}
                        obj.env[name] ?= {}
                        obj.env[name][key] = value
                        # Go on...
                        cb null, obj

            , (obj, cb) ->
                # Write into the config file.
                fs.writeFile file, JSON.stringify(obj, null, 4), (err) ->
                    if err then cb err
                    else cb null
            ], (err) ->
                if err
                    res.writeHead 500, 'content-type': 'application/json'
                    res.write JSON.stringify 'status': 'error'
                    res.end()
                else
                    res.writeHead 200, 'content-type': 'application/json'
                    res.write JSON.stringify 'status': 'ok'
                    res.end()