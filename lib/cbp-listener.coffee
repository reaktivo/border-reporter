debug = require('debug')('border:cbplistener')
CBPReporter = require 'border-wait/reporter'

class CBPListener

  constructor: (@handler) ->
    @reporter = new CBPReporter
      interval: 2 * 60 * 1000
      ignoreFirst: no
    debug "Starting with interval of #{@reporter.interval}"
    do @setup

  setup: =>
    @reporter.on 'report', (report) =>
      debug "New CBP Report for #{report.port} - #{report.type} - #{report.lane}: #{report.delay}"
      report.userId = 'cbp'
      report.createdAt = new Date(report.updated_at * 1000)
      @handler report, (err) -> # ignore error

module.exports = (handler) -> new CBPListener(handler)