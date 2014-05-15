pg = require 'pg-query'
migrate = require './migrate'
calculate = require './calculate'

{ max, min, abs } = Math

class Reporter

  constructor: (@connection, @table = "reports", @ttl = 120) ->
    @ttl = parseInt @ttl
    pg.connectionParameters = @connection
    migrate pg

  add: (report, done) =>
    sql = "INSERT INTO #{@table} (port, type, lane, delay, user_id) VALUES ($1, $2, $3, $4, $5)"
    params = [report.port, report.type, report.lane, report.delay, report.userId]
    pg sql, params, (err, rows, res) =>
      return done(err.toString()) if err
      @collect report, (err, delay) ->
        return done(err) if err
        console.log 'COLLECTED DELAY ' + delay
        done null, delay

  collect: (query, done) =>
    relevancy_expr = ""
    where_expr = ""
    sql = """
      SELECT *, (#{@ttl} - EXTRACT (EPOCH FROM (NOW() - created_at))/60)/#{@ttl} as relevancy
      FROM #{@table}
      WHERE (
        port = $1 AND type = $2 AND lane = $3
      AND
        NOW() - created_at < '#{@ttl} minutes'::INTERVAL
      )
      """
    pg sql, [query.port, query.type, query.lane], (err, rows) =>
      return done(err) if err
      done null, calculate(rows, @ttl)

module.exports = (connection) -> new Reporter(connection)
