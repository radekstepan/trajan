#!/usr/bin/env coffee
flatiron  = require 'flatiron'
director  = require 'director'
httpProxy = require 'http-proxy'
winston   = require 'winston'
path      = require 'path'
fs        = require 'fs'

# Create a logger.
module.exports.log = log = do ->
    if process.env.NODE_ENV isnt 'test'
        winston.cli()
        winston
    else
        winston.loggers.add 'dummy', 'console': 'silent': true
        winston.loggers.get 'dummy'

# Read config.
module.exports.cfg = cfg = do ->
    obj = require path.resolve __dirname, './config.json'
    # Fix the auth token and dyno cound in test mode.
    if process.env.NODE_ENV is 'test'
        obj.auth_token = 'abc'
        obj.dyno_count = 2
    obj

# Load processes.
Processes = require './trajan/processes.coffee'
module.exports.processes = new Processes()

# Load manifold.
Manifold = require './trajan/manifold.coffee'
module.exports.manifold = manifold = new Manifold()

# What to do on Ctrl-C?
process.on 'SIGINT', -> manifold.offline

# Start the shebang.
module.exports.start = (cb) ->
    authReq = (req, res, next) ->
        # Does API token match?
        if req.headers['x-auth-token'] is cfg.auth_token then next()
        else
            res.writeHead 403, 'content-type': 'application/json'
            res.write JSON.stringify 'message': 'Wrong auth token'
            res.end()

    app = flatiron.app
    app.use flatiron.plugins.http, 'before': [ authReq ]

    # Director routes.
    routes = '/api': r = {}
    for file in fs.readdirSync path.resolve(__dirname, './trajan/api')
        name = file[0...-7]
        r['/' + name] = require path.resolve(__dirname, "./trajan/api/#{file}")

    app.router = new director.http.Router routes

    # Start the service.
    app.start cfg.deploy_port, (err) ->
        if err then throw err
        log.info "Deploy service listening on port #{(cfg.deploy_port+'').bold}"

        onRoute = (req, res, proxy) ->
            # Get the first available route.
            if port = manifold.getPort()
                log.info "Routing request to port #{(port+'').bold}"
                # Route.
                proxy.proxyRequest req, res, { 'host': '127.0.0.1', 'port': port }
            else
                # No apps are online.
                log.error 'No apps online'
                res.writeHead 503
                res.end 'No apps online'

        # Start proxy.
        httpProxy.createServer(onRoute).listen cfg.proxy_port, ->
            log.info "Proxy listening on port #{(cfg.proxy_port+'').bold}"

            if cb and typeof(cb) is 'function' then cb cfg