debug = require('debug')('border:reporter')
pg = require 'pg-query'
calculate = require './calculate'
cbpListener = require './cbp-listener'
Queries = require './queries'
{ waterfall } = require 'async'
{ max, min, abs } = Math

class Reporter

  constructor: (@opts = {}) ->
    if @opts.connection
      pg.connectionParameters = @opts.connection
    @opts.pg = pg
    @opts.table or= "reports"
    @opts.ttl or= 120
    @opts.privileged or= []
    @query = Queries(@opts)
    @cbp = cbpListener @add
    @migrate()

  add: (report, done) =>
    waterfall [
      (done) -> done null, report
      @checkRepeat
      @checkPrivileges
      @insertReport
    ], (err) ->
      debug err if err
      done(err)

  insertReport: (report, done) =>
    @query.insert report, (err, rows, res) =>
      if err
        done err.toString()
      else
        done null, report
        @collect report

  checkRepeat: (report, done) =>
    @query.findLatest report, (err, rows) ->
      if err
        done err.toString()
      else if rows?.length and rows[0].delay is report.delay
        done 'Found duplicate report, ignore'
      else
        debug 'No repeat'
        debug JSON.stringify(report)
        done null, report

  checkTroll: (report, done) =>
    @query.findRecent report, (err, rows) =>
      if err
        err = err.toString()
      else if rows.length
        err = "Cannot allow more than one report per #{@ttl} minutes"
      done err, report

  checkPrivileges: (report, done) =>
    if @opts.privileged.indexOf(report.userId) is -1
      @checkTroll report, done
    else
      debug "Report comes from privileged user: #{report.userId}"
      done null, report

  collect: (query) =>
    @query.collect query, (err, rows) =>
      if err or rows.length is 0
        debug 'No results found for query:'
        debug query
      else
        @collected
          port: query.port
          type: query.type
          lane: query.lane
          delay: calculate(rows, @opts.ttl)

  collected: (report) ->
    # do something with actual report
    debug 'Collected report'
    debug JSON.stringify(report, null, 2)

  migrate: ->
    @query.migrate (err) ->
      debug "Could not initialize table border reports table" if err


module.exports = (connection) -> new Reporter(connection)
