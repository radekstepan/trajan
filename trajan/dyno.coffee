#!/usr/bin/env coffee
async     = require 'async'
{ spawn } = require 'child_process'
{ _ }     = require 'underscore'
path      = require 'path'
wrench    = require 'wrench'
winston   = require 'winston'
fs        = require 'fs'

{ log, cfg, processes } = require path.resolve __dirname, '../trajan.coffee'

class Dyno

    # Default status - a shell of a future self.
    status: 'shell'

    # Id by manifold, app name, link to manifold.
    constructor: (@id, @name, @env, @manifold) ->

    # Deploy from source dir to our target dir.
    deploy: (source, cb) ->
        log.debug "Deploying dyno #{(@id+'').bold}"

        # Form paths.
        source = path.resolve __dirname, "../#{source}"
        destination = @dir = path.resolve __dirname, "../#{cfg.apps_dir}/#{@name}-#{@id}"
        
        # Remove any previous directory.
        wrench.rmdirRecursive destination, (err) ->
            # Do the copy.
            wrench.copyDirRecursive source, destination, (err) =>
                if err then @status = 'error'
                cb err

    # Spawn this instance after it has been unpacked.
    spawn: (start, cb) ->
        log.debug "Spawning dyno #{(@id+'').bold}"

        # Change status.
        @status = 'spawning'

        # stdin, stdout, stderr
        stdio = [
            'ignore'
            fs.openSync(@dir + '/stdout.log', 'a')
            fs.openSync(@dir + '/stderr.log', 'a')
            'ipc'
        ]

        # Launch a Node.js process.
        @process = spawn 'node', [ "#{@dir}/#{start}" ],
            # Boost with env vars from live config file.
            'env': _.extend @env, process.env
            # If I die, you die.
            'detached': false
            # Create an IPC channel between master & child.
            'stdio': stdio

        # Save pid.
        processes.save @pid = @process.pid

        # Say when process is dead.
        @process.on 'exit', (code) =>
            log.warn "Dyno #{(@id+'').bold} exited"
            # Remove it from the going down stack.
            @manifold.removeDyno @id
            # Remove from pids.
            processes.remove @pid

        # IPC JSON response from a child Node.js process.
        @process.on 'message', (data) =>
            switch data.message
                when 'online'
                    # Save the port.
                    @port = data.port
                    log.debug "Dyno #{(@id+'').bold} ready on port #{(@port+'').bold}"
                    # Change our status to ready for using.
                    @status = 'ready'
                    # Call back.
                    cb()

module.exports = Dyno