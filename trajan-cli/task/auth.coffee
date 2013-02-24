#!/usr/bin/env coffee
async   = require 'async'
fs      = require 'fs'

{ exit } = require '../cli.coffee'

module.exports = ([ address, key ]) ->
    unless address and key then exit 'Insufficient parameters'

    # Have we provided port or go default?
    if (address.split(':')).length isnt 2 then address = address + ':9002'

    # Keys file.
    file = process.env.HOME + '/.trajan'

    # Check if keys file exists.
    async.waterfall [ (cb) ->
        fs.exists file, (exists) -> cb null, exists
        
    # Grab the existing tokens?
    , (exists, cb) ->
        if exists
            fs.readFile file, 'utf8', (err, data) ->
                if err then cb err
                else
                    try
                        cb null, JSON.parse data
                    catch e # problem parsing JSON
                        cb null, {}
        else
            cb null, {}

    # Add our token/override.
    , (keys, cb) ->
        keys[address] = key

        # Write it, nicely.
        fs.writeFile file, JSON.stringify(keys, null, 4), (err) ->
            if err then cb err
            else cb null
    
    # We done.
    ], (err, results) ->
        if err then exit err