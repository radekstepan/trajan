#!/usr/bin/env coffee
request = require 'request'
async   = require 'async'
tar     = require 'tar'
zlib    = require 'zlib'
fstream = require 'fstream'
fs      = require 'fs'
path    = require 'path'
{ _ }   = require 'underscore'

exports.exit = exit = (message) -> console.log(message) ; process.exit(1)

# Get arguments, no checking.
[ task, args... ] = process.argv[2...]

# Check task.
if task not in [ 'deploy', 'dynos' ] then exit "Unknown task #{task}"

# Fire the task.
require(path.resolve __dirname, "./task/#{task}.coffee") args