#!/usr/bin/env coffee
flatiron      = require 'flatiron'
director      = require 'director'
httpProxy     = require 'http-proxy'
winston       = require 'winston'
path          = require 'path'
fs            = require 'fs'

# Nice logging.
winston.cli()

# Store children here.
module.exports.apps = 'up': [], 'down': []

# Start the shebang.
module.exports.start = (cb) ->
    # Read config.
    cfg = JSON.parse fs.readFileSync('./config.json').toString('utf-8')

    authReq = (req, res, next) ->
        # Does API token match?
        if req.headers['x-auth-token'] is cfg.auth_token then next()
        else
            res.writeHead 403, 'content-type': 'application/json'
            res.write JSON.stringify 'message': 'Wrong auth token'
            res.end()

    app = flatiron.app
    app.use flatiron.plugins.http,
        'before': [ authReq ]

    # Director routes.
    app.router = new director.http.Router
        '/api':
            '/deploy':
                post: require './samfelld/deploy.coffee'

    # Start the service.
    app.start cfg.deploy_port, (err) ->
        if err then throw err
        winston.info "Deploy service listening on port #{(cfg.deploy_port+'').bold}"

        onRoute = (req, res, proxy) ->
            winston.debug 'Routing request'
            # Get the first available route.
            if target = apps.up.shift()
                # Route.
                proxy.proxyRequest req, res, { 'host': '127.0.0.1', 'port': target.port }
                # Add back to the stack.
                apps.up.push target
            else
                # No apps are online.
                winston.error 'No apps online'
                res.writeHead 503
                res.end 'No apps online'

        # Start proxy.
        httpProxy.createServer(onRoute).listen cfg.proxy_port
        winston.info "Proxy listening on port #{(cfg.proxy_port+'').bold}"

        if cb and typeof(cb) is 'function' then cb cfg