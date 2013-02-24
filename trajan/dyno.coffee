#!/usr/bin/env coffee
async         = require 'async'
child_process = require 'child_process'
{ _ }         = require 'underscore'
path          = require 'path'
wrench        = require 'wrench'

{ log, cfg, processes } = require path.resolve(__dirname, '../trajan.coffee')

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
    spawn: (cb) ->
        # Change status.
        @status = 'spawning'

        # App dir.
        @process = child_process.fork "#{@dir}/start.js",
            # Boost with env vars from live config file.
            'env': _.extend @env, process.env
            # Cannot pipe out to a file so make it silent.
            'silent': true

        # Save pid.
        processes.save @pid = @process.pid

        log.debug "Spawning dyno #{(@id+'').bold}"

        # Say when process is dead.
        @process.on 'exit', (code) =>
            log.warn "Dyno #{(@id+'').bold} exited"
            # Remove it from the going down stack.
            @manifold.removeDyno @id
            # Remove from pids.
            processes.remove @pid

        # Messaging from the process.
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