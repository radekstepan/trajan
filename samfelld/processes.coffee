#!/usr/bin/env coffee
fs            = require 'fs'
child_process = require 'child_process'
path          = require 'path'
winston       = require 'winston'

{ cfg } = require path.resolve __dirname, '../samfelld.coffee'

# Nice logging.
winston.cli()

class Processes

    # Link to the file.
    file: path.resolve __dirname, '../processes.json'

    constructor: ->
        # Create if it does not exist.
        if fs.existsSync @file
            # Get previous list.
            file = fs.readFileSync(@file).toString('utf-8')
            # Kill any previously running ones.
            for pid in JSON.parse(file) then do (pid) ->
                winston.warn "Killing process #{(pid+'').bold}"
                # TODO: Maybe `ps -p <pid>` to find out if a node process?
                child_process.exec "kill #{pid}"

        # Start anew.
        @pids = []

    # Add a pid.
    save: (pid) ->
        # On us.
        @pids.push pid

        # Into a file.
        fs.writeFileSync @file, JSON.stringify(@pids, null, 4), 'utf-8'

    # Remove a pid.
    remove: (pid) ->
        for i, ppid of @pids
            if ppid is pid
                # Remove on us
                @pids.splice i, 0

        # Into a file.
        fs.writeFileSync @file, JSON.stringify(@pids, null, 4), 'utf-8'

    # Get stats about a process.
    getStats: (pid, cb) ->
        # Total VM size in kB.
        child_process.exec "ps -p #{pid} -o %cpu,%mem,cmd", (err, stdout, stderr) ->
            if err or stderr.length isnt 0 then cb null
            else
                # Trim whitespace from ends.
                trim = (str) -> str.replace(/^\s\s*/, '').replace(/\s\s*$/, '')
                # Remove extra whitespace.
                spaces = (str) -> str.replace(/\s\s+/g, ' ')

                # Parse the output.
                [ cpu, mem, cmd... ] = spaces(trim(stdout.split('\n')[1])).split(' ')

                cb
                    'cpu': cpu + '%'
                    'mem': mem + '%'
                    'cmd': cmd

module.exports = Processes