#!/usr/bin/env coffee
request = require 'request'
async   = require 'async'

{ exit } = require '../cli.coffee'

module.exports = ([ address ]) ->
    unless address then exit 'Insufficient parameters'

    # Have we provided port or go default?
    if (address.split(':')).length isnt 2 then address = address + ':9002'

    # Get the app name from config.json.
    async.waterfall [ (cb) ->
        # ... the service.
        request.get
            'url': "http://#{address}/api/dynos"
            'headers':
                'x-auth-token': 'abc'
        , (err, res, body) ->
            if err then return cb err # request
            if res.statusCode isnt 200 then return cb body # response
            cb null, body
    
    # We done.
    ], (err, results) ->
        if err then exit err
        else console.log results