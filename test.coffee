#!/usr/bin/env coffee
request  = require 'request'
async    = require 'async'
tar      = require 'tar'
zlib     = require 'zlib'
fstream  = require 'fstream'

{ start } = require './samfelld.coffee'

# Start the service.
async.waterfall [ (cb) ->
    start (cfg) ->
        cb null, cfg

# Package up our app and stream it to the service.
, (cfg, cb) ->
    # Skip fils in `node_modules` directory.
    filter = (props) -> props.path.indexOf('/node_modules/') is -1
    # Make a stream.
    fstream.Reader({ 'path': './example-app', 'type': 'Directory', 'filter': filter })
    # Tar.
    .pipe(tar.Pack())
    # GZip.
    .pipe(zlib.Gzip())
    # Pipe to...
    .pipe(
        # ... the service.
        request.post
            'url': "http://127.0.0.1:#{cfg.deploy_port}/api/deploy/example-app"
            'headers':
                'x-auth-token': cfg.auth_token
        , (err, res, body) ->
            if err then return cb err # request
            if res.statusCode isnt 200 then return cb body # response

            body = JSON.stringify JSON.parse(body), null, 2
            console.log "#{res.statusCode}: #{body}"
            cb null
    )

# We done.
], (err, results) ->
    if err then throw err