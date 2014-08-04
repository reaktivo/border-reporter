debug = require('debug')('border:reporter')
{ pick, pluck } = require 'underscore'
{ waterfall } = require 'async'
{ max, min, abs } = Math
calculate = require './calculate'
Queries = require './queries'
ReportEmitter = require './emitter'

class Reporter

  constructor: (opts = {}) ->
    @privileged = opts.privileged
    @ttl = opts.ttl
    @query = Queries(opts)
    @setupEmitter()
    @setupTables()

  add: (report, done) =>
    waterfall [
      (done) =>
        done null, report
      (report, done) =>
        @checkIfPortExists report, done
      (report, done) =>
        @checkRepeat report, done
      (report, done) =>
        @checkPrivileges report, done
      (report, done) =>
        @insertReport report, done
    ], (err) =>
      @collect report
      debug err if err
      done err

  insertReport: (report, done) =>
    @query.report report, (err, rows, res) =>
      err = err.toString() if err
      done err, report
      debug 'insert report'

  checkIfPortExists: (report, done) =>
    @query.findPort report, (err, rows) =>
      if rows?.length
        debug 'Port already exists: ' + report.port_id
        done null, report
      else if @privileged.indexOf(report.user_id) >= 0
        @query.port report, (err) =>
          debug err if err
          done null, report
      else
        done 'Port does not exist ' + report.port_id

  checkRepeat: (report, done) =>
    @query.findRepeat report, (err, rows) ->
      if err
        done err.toString()
      else if rows?.length
        done 'Found duplicate report, ignore'
      else
        debug 'No repeat'
        debug JSON.stringify(report)
        done null, report

  checkTroll: (report, done) =>
    @query.findRecent report, (err, rows) =>
      if err
        err = err.toString()
      else if rows?.length
        err = "Cannot allow more than one report per #{@ttl} minutes"
      done err, report

  checkPrivileges: (report, done) =>
    if @privileged.indexOf(report.user_id) is -1
      @checkTroll report, done
    else
      debug "Report comes from privileged user: #{report.user_id}"
      done null, report

  collect: (query) =>
    @query.collect query, (err, rows) =>
      if err or rows.length is 0
        debug 'No results found for query:'
        debug JSON.stringify(query, null, 2)
      else
        @collected
          port_id: query.port_id
          type: query.type
          lane: query.lane
          delay: calculate(rows, @ttl)
          reports_by: pluck rows, 'user_id'

  collected: (report) ->
    # do something with actual report
    debug 'Collected report'
    debug JSON.stringify(report, null, 2)

  setupTables: ->
    @query.createPortsTable (err) ->
      debug "Could not initialize Ports table" if err
    @query.createReportsTable (err) ->
      debug "Could not initialize Reports table" if err

  setupEmitter: ->
    @emitter = new ReportEmitter
      interval: 2 * 60 * 1000
      ignoreFirst: no
    @emitter.on 'report', (report) =>
      debug "New CBP Report for #{report.port} - #{report.type} - #{report.lane}: #{report.delay}"
      report.user_id = 'cbp'
      @add report, (err) -> # ignore error

  reports: -> @emitter.reports


module.exports = (connection) -> new Reporter(connection)
