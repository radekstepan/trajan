#!/usr/bin/env coffee
request = require 'request'
async   = require 'async'
tar     = require 'tar'
zlib    = require 'zlib'
fstream = require 'fstream'
fs      = require 'fs'
{ _ }   = require 'underscore'

{ exit } = require '../cli.coffee'

module.exports = ([ address, dir, env, keys ]) ->
    unless address and dir and env then exit 'Insufficient parameters'

    # Have we provided port or go default?
    if (address.split(':')).length isnt 2 then address = address + ':9002'

    # Inject default key in testing mode.
    if process.env.NODE_ENV is 'test' then keys[address] = 'abc'

    # Do we have a key for us?
    unless key = keys[address] then exit 'API token key not provided'

    # Do we have a nice key=value env?
    [ k, v ] = env.split('=')
    unless k and v then exit 'Environment misconfigured, not `key=value`'

    # Get the app name from config.json.
    async.waterfall [ (cb) ->
        fs.readFile dir + '/package.json', 'utf8', (err, data) ->
            if err then cb err
            else cb null, JSON.parse(data).name

    # Post the env variables.
    , (name, cb) ->
        request.post
            'url': "http://#{address}/api/env/#{name}"
            'headers':
                'x-auth-token': key
            'json':
                'key': k
                'value': v
        , (err, res, body) ->
            if err then return cb err # request
            if res.statusCode isnt 200 then return cb body # response
            cb null
    
    # We done.
    ], (err, results) ->
        if err then exit err