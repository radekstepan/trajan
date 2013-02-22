child_process = require 'child_process'
httpProxy     = require 'http-proxy'
{ _ }         = require 'underscore'
winston       = require 'winston'

# Nice logging.
winston.cli()

# Store children here.
children = 'up': [], 'down': []

# Start proxy.
httpProxy.createServer((req, res, proxy) ->
    winston.debug 'Routing request'
    # Get the first available route.
    if target = children.up.shift()
        # Route.
        proxy.proxyRequest req, res, { 'host': '127.0.0.1', 'port': target.port }
        # Add back to the stack.
        children.up.push target
    else
        # No apps are online.
        winston.error 'No apps online'
        res.writeHead 503
        res.end 'No apps online'
).listen 8000

winston.info 'Proxy listening on port 8000'

# Deploy a child.
exports.deploy = (cb) ->
    winston.debug (children.up.length + '').bold + ' apps online ' + (children.down.length + '').bold + ' apps going down '

    # Example app to launch.
    child = child_process.fork './example-app/start.js',
        # 'env': _.extend { 'PORT': 7000 }, process.env
        'silent': true

    winston.info "Spawning process pid #{child.pid}"

    # Say when child is dead.
    child.on 'exit', (code) ->
        winston.warn "Child process #{child.pid} exited"
        # Remove it from the going down stack.
        for i, ch of children.down
            if ch.pid is child.pid
                return children.down.splice 0, i

    # Messaging from the child.
    child.on 'message', (data) ->
        switch data.message
            when 'online'
                winston.info "Child says it is online on port #{data.port}"
                
                # Offline existing app(s).
                while children.up.length isnt 0
                    ch = children.up.pop()
                    # Send message.
                    ch.ref.send 'Die'
                    # To down stack.
                    children.down.push ch

                # Save us as a new online app.
                obj =
                    'ref': child
                    'pid': child.pid
                    'port': data.port

                children.up.push obj

                if cb and typeof(cb) is 'function' then cb obj