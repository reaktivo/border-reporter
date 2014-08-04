fs = require 'fs'
assert = require 'assert'
difflet = require('difflet')({indent: 2})
{ join } = require 'path'
{ all } = require 'underscore'

BorderWait = require '../lib/border-wait'
ReporterEmitter = require '../lib/emitter'

patchLoad = (xml) ->
  BorderWait.prototype._load = (done) ->
    stubPath = join __dirname, 'stubs', xml or "bwt.xml"
    fs.readFile stubPath, (err, data) -> done(err, data.toString())

describe 'Border Wait Emitter', ->

  it 'should find changed reports only, using ignoreFirst: true', (done) ->
    patchLoad 'bwt2.xml'
    count = 0
    times = 5
    reporter = new ReporterEmitter
      interval: 200
      ignoreFirst: yes
    reporter.many 'report', times, (report) ->
      assert report.port is 'San Ysidro', 'All new reports should have San Ysidro as it\'s port'
      done() if ++count is times
    patchLoad 'bwt.xml'

  it 'should find all the reports, since we are setting ignoreFirst: false', (done) ->
    patchLoad 'bwt.xml'
    count = 0
    times = 130
    reporter = new ReporterEmitter
      interval: 200
      ignoreFirst: no
    reporter.many 'report', times, (report) ->
      done() if ++count is times

