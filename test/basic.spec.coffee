#!/usr/bin/env coffee
assert    = require('chai').assert

request   = require 'request'
async     = require 'async'
tar       = require 'tar'
zlib      = require 'zlib'
fstream   = require 'fstream'
path      = require 'path'
{ _ }     = require 'underscore'

{ start } = require '../trajan.coffee'

CFG = null

# ----------------------------------------------------------------------------------------------------

describe 'Basic test', ->

    before (done) ->
        start (cfg) ->
            CFG = cfg
            done()

    describe 'deploy app', ->
        it 'spawns two dynos', (done) ->
            # Package up our app and stream it to the service.
            async.waterfall [ (cb) ->
                # Skip files in `node_modules` directory.
                filter = (props) -> props.path.indexOf('/node_modules/') is -1
                # Make a stream.
                fstream.Reader({ 'path': (path.resolve __dirname, './example-app'), 'type': 'Directory', 'filter': filter })
                # Tar.
                .pipe(tar.Pack())
                # GZip.
                .pipe(zlib.Gzip())
                # Pipe to...
                .pipe(
                    # ... the service.
                    request.post
                        'url': "http://127.0.0.1:#{CFG.deploy_port}/api/deploy/example-app"
                        'headers':
                            'x-auth-token': CFG.auth_token
                    , (err, res, body) ->
                        if err then return cb err # request
                        if res.statusCode isnt 200 then return cb body # response

                        # body = JSON.stringify JSON.parse(body), null, 2
                        # console.log "#{res.statusCode}: #{body}"
                        cb null, JSON.parse(body).ids.length
                )

            # Keep checking for up status from both dynos.
            , (length, cb) ->
                do check = ->
                    request.get
                        'url': "http://127.0.0.1:#{CFG.deploy_port}/api/dynos"
                        'headers':
                            'x-auth-token': CFG.auth_token
                    , (err, res, body) ->
                        if err then return cb err # request
                        if res.statusCode isnt 200 then return cb body # response

                        # Check all dynos now.
                        up = true
                        for dyno in JSON.parse(body).dynos
                            if dyno.status isnt 'up' then up = false

                        unless up then setTimeout check, 500
                        else cb null, length

            # Make requests to all dynos.
            , (length, cb) ->
                fns = ( for i in [0...length]
                    (_cb) ->
                        request.get
                            'url': "http://127.0.0.1:#{CFG.proxy_port}/api"
                        , (err, res, body) ->
                            if err then return _cb err # request
                            if res.statusCode isnt 200 then return _cb body # response

                            # Get the response.
                            _cb null, body
                )
                async.parallel fns, (err, results) ->
                    if err and err.length isnt 0 then cb err
                    else cb null, results

            # We done.
            ], (err, results) ->
                assert.equal err, null
                assert.lengthOf _.unique(results), 2
                
                done()