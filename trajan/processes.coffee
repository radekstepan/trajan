#!/usr/bin/env coffee
{ exec } = require 'child_process'

class Processes

    constructor: ->
        # Start anew.
        @pids = []

    # Add a pid.
    save: (pid) ->
        # On us.
        @pids.push pid

    # Remove a pid.
    remove: (pid) ->
        for i, ppid of @pids
            if ppid is pid
                # Remove on us
                @pids.splice i, 0

    # Get stats about a process.
    getStats: (pid, cb) ->
        # Total VM size in kB.
        exec "ps -p #{pid} -o %cpu,%mem,cmd", (err, stdout, stderr) ->
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