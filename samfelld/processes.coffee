#!/usr/bin/env coffee
fs            = require 'fs'
child_process = require 'child_process'

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

    # Get memory usage for a process.
    getUsage: (pid, cb) ->
        # Total VM size in kB.
        child_process.exec "ps -p #{pid} -o vsize=", (err, stdout, stderr) ->
            if err or stderr then cb null
            else
                # Convert to a nice value.
                cb (parseInt(stdout) / 1024).toFixed(1) + ' MB'

module.exports = Processes