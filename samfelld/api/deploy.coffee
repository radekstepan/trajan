#!/usr/bin/env coffee
child_process = require 'child_process'
async         = require 'async'
winston       = require 'winston'
tar           = require 'tar'
zlib          = require 'zlib'
path          = require 'path'

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
            .pipe(tar.Extract({ 'strip': true, 'path': path = path.resolve(__dirname, "../../#{temp}") }))
            # Handle further...
            .on 'end', ->
                # Generate new ids of shell dynos in sync.
                ids = [] ; dynos = []
                try
                    for i in [0...cfg.dyno_count]
                        dynos.push dyno = manifold.newDyno name
                        ids.push dyno.id
                catch e
                    res.writeHead 500, 'content-type': 'application/json'
                    res.write JSON.stringify 'error': e.message
                    return res.end()

                # Respond with the ids of the dynos being deployed & spawned.
                res.writeHead 200, 'content-type': 'application/json'
                res.write JSON.stringify 'ids': ids
                res.end()

                winston.debug 'Installing dependencies through npm'

                # Exec npm install.
                child_process.exec "cd #{path} ; npm install -d", (err, stderr, stdout) ->
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