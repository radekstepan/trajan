#!/usr/bin/env coffee
child_process = require 'child_process'
{ _ }         = require 'underscore'
async         = require 'async'
tar           = require 'tar'
zlib          = require 'zlib'
path          = require 'path'

# Link to main manifold & config.
{ log, cfg, manifold } = require path.resolve(__dirname, '../../trajan.coffee')

module.exports =
    '/:name':
        post: (name) ->
            log.info 'Deploy task running'
            
            req = @req
            res = @res

            # Unpack.
            async.waterfall [ (cb) ->
                # A new temp directory.
                temp = cfg.temp_dir + '/' + (new Date()).getTime()

                # Unzip.
                req.pipe(zlib.Gunzip())
                # Untar.
                .pipe(tar.Extract({ 'strip': true, 'path': dir = path.resolve(__dirname, "../../#{temp}") }))
                # Handle further...
                .on 'end', -> cb null, temp, dir

            # Create shell dynos.
            , (temp, dir, cb) ->
                fns = ( ( (_cb) -> manifold.newDyno(name, _cb) ) for i in [0...cfg.dyno_count] )
                async.parallel fns, (err, dynos) ->
                    if err and err.length isnt 0
                        res.writeHead 500, 'content-type': 'application/json'
                        res.write JSON.stringify 'error': err
                        res.end()
                        # Bad.
                        cb err
                    else
                        # Respond with the ids of the dynos being deployed & spawned.
                        res.writeHead 200, 'content-type': 'application/json'
                        res.write JSON.stringify 'ids': _.pluck(dynos, 'id')
                        res.end()
                        # Good.
                        cb null, temp, dir, dynos

            # Npm install.
            , (temp, dir, dynos, cb) ->
                log.debug 'Installing dependencies through npm'

                # Exec npm install.
                child_process.exec "cd #{dir} ; npm install -d", (err, stderr, stdout) ->
                    if err then cb err
                    else cb null, temp, dynos

            # Dyno deploy.
            , (temp, dynos, cb) ->
                fns = ( for dyno in dynos then do (dyno) -> ( (_cb) -> dyno.deploy temp, _cb ) )
                async.parallel fns, (err, done) ->
                    if err and err.length isnt 0 then cb err
                    else cb null, dynos

            # Dyno spawn.
            , (dynos, cb) ->
                fns = ( for dyno in dynos then do (dyno) -> ( (_cb) -> dyno.spawn _cb ) )
                async.parallel fns, (err, done) ->
                    if err and err.length isnt 0 then cb err
                    else
                        log.debug 'Finished spawning dynos'
                        # Now we need to offline past dynos.
                        manifold.offlineDynos()
                        cb null

            ], (err, results) ->
                if err then log.error err