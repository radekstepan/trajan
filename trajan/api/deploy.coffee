#!/usr/bin/env coffee
{ exec } = require 'child_process'
{ _ }    = require 'underscore'
async    = require 'async'
tar      = require 'tar'
zlib     = require 'zlib'
path     = require 'path'
fs       = require 'fs'

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

            # Get env vars for this app.
            , (temp, dir, cb) ->
                # Read the live config file.
                fs.readFile path.resolve(__dirname, '../../config.json'), 'utf8', (err, data) ->
                    if err then cb err
                    else
                        # Any pertinent config for us?
                        c = JSON.parse(data)
                        c.env ?= {}
                        env = c.env[name] or {}

                        cb null, temp, dir, env

            # Create shell dynos.
            , (temp, dir, env, cb) ->
                fns = ( ( (_cb) -> manifold.newDyno(name, env, _cb) ) for i in [0...cfg.dyno_count] )
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
                exec "cd #{dir} ; npm install -d", (err, stderr, stdout) ->
                    if err then cb err
                    else cb null, temp, dir, dynos

            # Dyno deploy.
            , (temp, dir, dynos, cb) ->
                fns = ( for dyno in dynos then do (dyno) -> ( (_cb) -> dyno.deploy temp, _cb ) )
                async.parallel fns, (err, done) ->
                    if err and err.length isnt 0 then cb err
                    else cb null, dir, dynos

            # Read the `config.json` file.
            , (dir, dynos, cb) ->
                log.debug 'Reading package.json file'

                fs.readFile dir + '/package.json', 'utf8', (err, data) ->
                    if err then cb err
                    else
                        # Parse the JSON file.
                        json = JSON.parse data
                        # Do we have the start script?
                        unless json.scripts and start = json.scripts.start
                            return cb 'Missing `scripts.start` in package.json'
                        # Does it match the profile?
                        unless /^([^\ ]*)\.js$/.test start
                            return cb 'Invalid `scripts.start` in package.json; provide a single Node.js file'

                        cb null, dynos, start

            # Dyno spawn.
            , (dynos, start, cb) ->
                fns = ( for dyno in dynos then do (dyno) -> ( (_cb) -> dyno.spawn start, _cb ) )
                async.parallel fns, (err, done) ->
                    if err and err.length isnt 0 then cb err
                    else
                        log.debug 'Finished spawning dynos'
                        # Now we need to offline past dynos.
                        manifold.offlineDynos()
                        cb null

            ], (err, results) ->
                if err then log.error err