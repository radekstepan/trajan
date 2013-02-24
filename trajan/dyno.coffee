#!/usr/bin/env coffee
async         = require 'async'
child_process = require 'child_process'
{ _ }         = require 'underscore'
winston       = require 'winston'
path          = require 'path'
wrench        = require 'wrench'

{ processes, cfg } = require path.resolve(__dirname, '../trajan.coffee')

# Nice logging.
winston.cli()

class Dyno

    # Default status - a shell of a future self.
    status: 'shell'

    # Id by manifold, app name, link to manifold.
    constructor: (@id, @name, @manifold) ->

    # Deploy from source dir to our target dir.
    deploy: (source, cb) ->
        winston.debug "Deploying dyno #{(@id+'').bold}"

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
            # 'env': _.extend { 'PORT': 7000 }, process.env
            'silent': true # cannot pipe out to a file :(

        # Save pid.
        processes.save @pid = @process.pid

        winston.debug "Spawning dyno #{(@id+'').bold}"

        # Say when process is dead.
        @process.on 'exit', (code) =>
            winston.warn "Dyno #{(@id+'').bold} exited"
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
                    winston.debug "Dyno #{(@id+'').bold} ready on port #{(@port+'').bold}"
                    # Change our status to ready for using.
                    @status = 'ready'
                    # Call back.
                    cb()

module.exports = Dyno