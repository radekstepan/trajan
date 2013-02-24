#!/usr/bin/env coffee
fs            = require 'fs'
child_process = require 'child_process'
path          = require 'path'

class Processes

    # FILE: './samfelld/processes.json'

    constructor: ->
        # Get previous list.
        # @pids = JSON.parse fs.readFileSync(@FILE).toString('utf-8')

        # Kill any previously running ones.
        # for pid in @pids
        #     # TODO: Maybe `ps -p <pid>` to find out if a node process?
        #     kill = child_process.spawn 'kill', [ pid ]

        #     kill.stdout.on "data", (data) ->
        #     kill.stderr.on "data", (data) ->
        #     kill.on "exit", (code) ->

        # Start anew.
        @pids = []

    # Add a pid.
    save: (pid) ->
        # On us.
        @pids.push pid

        # Into a file.
        # fs.writeFileSync @FILE, JSON.stringify(@pids, null, 4), 'utf-8'

    # Remove a pid.
    remove: (pid) ->
        for i, ppid of @pids
            if ppid is pid
                # Remove on us
                @pids.splice i, 0

        # Into a file.
        # fs.writeFileSync @FILE, JSON.stringify(@pids, null, 4), 'utf-8'

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