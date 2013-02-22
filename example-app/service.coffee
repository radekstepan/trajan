flatiron = require '../node_modules/flatiron'
director = require '../node_modules/director'

# Are we exiting?
exiting = false
# Stack of our jobs.
jobs = []
# Our (future) port.
port = null

# Use Flatiron.
app = flatiron.app
app.use flatiron.plugins.http,
    'before': [
        (req, res, next) ->
            # Do not accept new connections when exiting.
            if exiting
                res.writeHead 503, 'connection': 'close'
                res.end('Server is in the process of restarting')
            else
                # Business as usual.
                next()
    ]

# Director routes.
app.router = new director.http.Router
    '/api':
        # A long job.
        '/long':        
            get: ->
                console.log 'Child is handling request'
                jobs.push true
                setTimeout =>
                    # Respond.
                    @res.writeHead 200, 'content-type': 'application/json'
                    @res.write JSON.stringify 'message': 'Hello World!'
                    @res.end()
                    # Finished "this" job.
                    jobs.pop()
                , 5000 # take 5s

# Start the app.
app.start process.env.PORT, (err) ->
    throw err if err
    port = app.server.address().port
    console.log "Child listening on port #{port}"
    # Are we forked?
    if process.send
        # Say we are ready to accept connections.
        process.send { 'message': 'online', 'port': port }

# Gracefully die (when I was forked).
process.on 'message', (data) ->
    # Did spawner ask us to wind down?
    if data is 'Die'
        # Do not accept any new connections.
        exiting = true

        # Can we die?
        do die = ->
            if jobs.length is 0
                app.server.close ->
                    console.log 'Child closed remaining connections'
                    process.exit()
             
                # Forcefully die in 30s if we cannot exit normally.
                setTimeout ->
                    console.error 'Child forcefully shutting down'
                    process.exit(1)
                , 30000
            else
                console.log 'Child is busy'

                # Tell spawner we have a job still.
                process.send { 'message': 'busy', 'port': port }

                # Check again in 1s.
                setTimeout die, 1000