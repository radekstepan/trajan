#!/usr/bin/env coffee
async = require 'async'
fs    = require 'fs'
path  = require 'path'

exports.exit = exit = (message) -> console.log(message) ; process.exit(1)

# Get arguments, no checking.
[ task, args... ] = process.argv[2...]

# Check task.
if task not in [ 'deploy', 'dynos', 'auth', 'env' ] then exit "Unknown task #{task}"

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

# We done.
], (err, keys) ->
    if err then exit err

    # Push the keys to the stack.
    args.push keys

    # Fire the task.
    require(path.resolve __dirname, "./task/#{task}.coffee") args