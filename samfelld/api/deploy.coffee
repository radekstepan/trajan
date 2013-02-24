#!/usr/bin/env coffee
async   = require 'async'
winston = require 'winston'
tar     = require 'tar'
zlib    = require 'zlib'
path    = require 'path'

# Nice logging.
winston.cli()

# Link to main manifold & config.
{ manifold, cfg } = require path.resolve(__dirname, '../../samfelld.coffee')

module.exports =
    '/:name':
        post: (name) ->
            winston.info 'Deploy task running'
            
            req = @req
            res = @res

            # Pipe to a temp directory
            temp = cfg.temp_dir + '/' + (new Date()).getTime()

            # Unzip.
            req.pipe(zlib.Gunzip())
            # Untar.
            .pipe(tar.Extract({ 'strip': true, 'path': path.resolve(__dirname, "../../#{temp}") }))
            # Handle further...
            .on 'end', ->
                winston.debug 'App piped'

                # Generate new ids of shell dynos in sync.
                ids = [] ; dynos = []
                for i in [0...cfg.dyno_count]
                    dynos.push dyno = manifold.newDyno name
                    ids.push dyno.id

                # Respond with the ids of the dynos being deployed & spawned.
                res.writeHead 200, 'content-type': 'application/json'
                res.write JSON.stringify 'ids': ids
                res.end()

                # Now deploy all of them in async.
                fns = ( for dyno in dynos then do (dyno) -> ( (cb) -> dyno.deploy temp, cb ) )
                
                async.parallel fns, (err, done) ->
                    if err and err.length isnt 0 then return winston.error err
                    winston.debug 'Finished deploying dynos'

                    # Now spawn all of them.
                    fns = ( for dyno in dynos then do (dyno) -> ( (cb) -> dyno.spawn cb ) )
                    async.parallel fns, (err, done) ->
                        if err and err.length isnt 0 then return winston.error err
                        winston.debug 'Finished spawning dynos'

                        # Now we need to offline past dynos.
                        manifold.offlineDynos()