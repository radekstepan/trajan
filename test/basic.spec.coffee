#!/usr/bin/env coffee
{ assert }    = require 'chai'
async         = require 'async'
request       = require 'request'
child_process = require 'child_process'
{ _ }         = require 'underscore'

{ start, manifold }     = require '../trajan.coffee'

CFG = null

# ----------------------------------------------------------------------------------------------------

describe 'Basic test', ->

    before (done) ->
        start (cfg) ->
            CFG = cfg
            done()

    after (done) -> manifold.offline()

    describe 'deploy app', ->
        it 'spawns two dynos', (done) ->
            # Package up our app and stream it to the service.
            async.waterfall [ (cb) ->
                child_process.exec './bin/trajan-cli deploy 127.0.0.1 test/example-app/', (err, stdout, stderr) ->
                    if err then cb err
                    if stderr then cb stderr
                    cb null

            # Keep checking for up status from both dynos.
            , (cb) ->
                do check = ->
                    child_process.exec './bin/trajan-cli dynos 127.0.0.1', (err, stdout, stderr) ->
                        if err then cb err
                        if stderr then cb stderr

                        dynos = JSON.parse(stdout).dynos

                        # Do we still have 2 dynos?
                        assert.lengthOf dynos, 2

                        # Check all dynos now.
                        up = true
                        for dyno in dynos
                            if dyno.status isnt 'up' then up = false

                        unless up then setTimeout check, 500
                        else cb null

            # Make requests to all dynos.
            , (cb) ->
                fns = ( for i in [0...2]
                    (_cb) ->
                        request.get
                            'url': "http://127.0.0.1:8000/api"
                        , (err, res, body) ->
                            if err then return _cb err # request
                            if res.statusCode isnt 200 then return _cb body # response

                            # Get the response.
                            _cb null, body
                )
                async.parallel fns, (err, results) ->
                    if err and err.length isnt 0 then cb err
                    else cb null, results

            # We done.
            ], (err, results) ->
                assert.equal err, null
                assert.lengthOf _.unique(results), 2
                
                done()