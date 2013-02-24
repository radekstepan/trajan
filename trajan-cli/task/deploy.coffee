#!/usr/bin/env coffee
request = require 'request'
async   = require 'async'
tar     = require 'tar'
zlib    = require 'zlib'
fstream = require 'fstream'
fs      = require 'fs'
{ _ }   = require 'underscore'

{ exit } = require '../cli.coffee'

module.exports = ([ address, dir, keys ]) ->
    unless address and dir then exit 'Insufficient parameters'

    # Have we provided port or go default?
    if (address.split(':')).length isnt 2 then address = address + ':9002'

    # Inject default key in testing mode.
    if process.env.NODE_ENV is 'test' then keys[address] = 'abc'

    # Do we have a key for us?
    unless key = keys[address] then exit 'API token key not provided'

    # Get the app name from config.json.
    async.waterfall [ (cb) ->
        fs.readFile dir + '/package.json', 'utf8', (err, data) ->
            if err then cb err
            else cb null, JSON.parse(data).name

    # Package up our app and stream it to the service.
    , (name, cb) ->
        # Skip files in `node_modules` directory.
        filter = (props) -> props.path.indexOf('/node_modules/') is -1
        # Make a stream.
        fstream.Reader({ 'path': dir, 'type': 'Directory', 'filter': filter })
        # Tar.
        .pipe(tar.Pack())
        # GZip.
        .pipe(zlib.Gzip())
        # Pipe to...
        .pipe(
            # ... the service.
            request.post
                'url': "http://#{address}/api/deploy/#{name}"
                'headers':
                    'x-auth-token': key
            , (err, res, body) ->
                if err then return cb err # request
                if res.statusCode isnt 200 then return cb body # response
                cb null
        )
    # We done.
    ], (err, results) ->
        if err then exit err