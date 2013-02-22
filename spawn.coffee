child_process = require 'child_process'

# Utilities.
{ _ } = require 'underscore'
request = require 'request'

# Nice logging.
winston = require 'winston'
winston.cli()

# Example app to launch.
# child = child_process.spawn 'coffee', [ './example-app/server.coffee' ],
child = child_process.fork './example-app/start.js',
    'env': _.extend { 'PORT': 7000 }, process.env
    'silent': true # use when forking

winston.info "Spawning process pid #{child.pid}"

# Handle output when spawning.
# child.stdout.on 'data', (data) -> winston.debug data
# child.stderr.on 'data', (data) -> winston.error data

# Say when child is dead.
child.on 'exit', (code) -> winston.warn 'Child process exited'

# Messaging from the child.
child.on 'message', (data) ->
    switch data.message
        when 'online'
            winston.info "Child says it is online on port #{data.port}"
            # Oh noes, I am making a request...
            winston.debug 'Making a request to the child'
            request
                'method': 'GET'
                'uri': "http://127.0.0.1:#{data.port}/api/long"
            , (err, res, body) ->
                if err then return winston.error err
                winston.data "#{res.statusCode}: #{body}"
        
        when 'busy'
            winston.debug 'Child says it is busy'
            # Try making a request now.
            request
                'method': 'GET'
                'uri': "http://127.0.0.1:#{data.port}/api/long"
            , (err, res, body) ->
                if err then return winston.error err
                winston.data res.statusCode

# Kill app in 3s.
setTimeout ->
    # When spawning.
    # winston.warn "Sending SIGKILL to #{child.pid}"
    # process.kill child.pid, 'SIGKILL'

    # When forking.
    winston.warn "Asking process #{child.pid} to die"
    child.send 'Die'
, 3000