#!/usr/bin/env coffee
flatiron  = require 'flatiron'
union     = require 'union'
director  = require 'director'
httpProxy = require 'http-proxy'
winston   = require 'winston'
path      = require 'path'
fs        = require 'fs'

# Nice logging.
winston.cli()

# Load processes.
Processes = require './samfelld/processes.coffee'
module.exports.processes = new Processes()

# Load manifold.
Manifold = require './samfelld/manifold.coffee'
module.exports.manifold = new Manifold()

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
    app.use flatiron.plugins.http, 'before': [ authReq ]

    # Director routes.
    routes = '/api': r = {}
    for path in fs.readdirSync './samfelld/api'
        name = path[0...-7]
        r['/' + name] = require "./samfelld/api/#{path}"

    app.router = new director.http.Router routes

    # Start the service.
    app.start cfg.deploy_port, (err) ->
        if err then throw err
        winston.info "Deploy service listening on port #{(cfg.deploy_port+'').bold}"

        onRoute = (req, res, proxy) ->
            winston.debug 'Routing request'
            # Get the first available route.
            if port = manifold.getPort()
                # Route.
                proxy.proxyRequest req, res, { 'host': '127.0.0.1', 'port': port }
            else
                # No apps are online.
                winston.error 'No apps online'
                res.writeHead 503
                res.end 'No apps online'

        # Start proxy.
        httpProxy.createServer(onRoute).listen cfg.proxy_port
        winston.info "Proxy listening on port #{(cfg.proxy_port+'').bold}"

        if cb and typeof(cb) is 'function' then cb cfg