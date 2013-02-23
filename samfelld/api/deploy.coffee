#!/usr/bin/env coffee
winston = require 'winston'
tar     = require 'tar'
zlib    = require 'zlib'

# Nice logging.
winston.cli()

# Link to main manifold & processes.
{ manifold } = require '../../samfelld.coffee'

module.exports =
    '/:name':
        post: (name) ->
            winston.debug 'Deploying app'
            
            req = @req
            res = @res

            # Unzip.
            req.pipe(zlib.Gunzip())
            # Untar.
            .pipe(tar.Extract({ 'path': './apps/' }))
            # Handle further...
            .on 'end', ->
                winston.debug 'Spawning app'

                # Manifold.
                pid = manifold.spawn name

                # Respond with the pid of the app being spawned.
                res.writeHead 200, 'content-type': 'application/json'
                res.write JSON.stringify 'pid': pid
                res.end()