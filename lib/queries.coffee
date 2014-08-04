{ pick, map, object } = require 'underscore'
pg = require 'pg-query'
debug = require('debug')('border:queries')

module.exports = (opts) ->

  pg.connectionParamaters = opts.connectionParameters or opts.connection
  reportsTable = opts.reportsTable or "reports"
  portsTable = opts.portsTable or "ports"
  ttl = opts.ttl or 120

  queries =

    report:
      sql: "INSERT INTO #{reportsTable} (port_id, type, lane, delay, user_id) VALUES ($1::integer, $2, $3, $4, $5)"
      keys: ['port_id', 'type', 'lane', 'delay', 'user_id']

    port:
      sql: "INSERT INTO #{portsTable} (port_id, port, crossing) VALUES ($1::integer, $2, $3)"
      keys: ['port_id', 'port', 'crossing']

    findPort:
      sql: "SELECT * FROM #{portsTable} WHERE port_id = $1::integer"
      keys: ['port_id']

    findLatest:
      sql: """
        SELECT * FROM #{reportsTable}
        WHERE (port_id = $1::integer AND type = $2 AND lane = $3 AND user_id = $4)
        ORDER BY id DESC
        LIMIT 1
        """
      keys: ['port_id', 'type', 'lane', 'userId']

    findRepeat:
      sql: """
        SELECT id FROM (
          SELECT id, delay FROM #{reportsTable}
          WHERE (port_id = $1 AND type = $2 AND lane = $3)
          ORDER BY id DESC LIMIT 1) as #{reportsTable}
        WHERE delay = $4
        """
      keys: ['port_id', 'type', 'lane', 'delay']

    findRecent:
      sql: """
        SELECT 1 FROM #{reportsTable}
        WHERE (user_id = $1 AND EXTRACT (EPOCH FROM (NOW() - created_at)/60) < #{ttl})
        LIMIT 1
        """
      keys: ['userId']

    # collect:
    #   sql: """
    #     SELECT DISTINCT ON (user_id) user_id, id, delay, (#{ttl} - EXTRACT (EPOCH FROM (NOW() - created_at))/60)/#{ttl} as relevancy
    #     FROM #{reportsTable}
    #     WHERE (
    #       port_id = $1::integer AND type = $2 AND lane = $3
    #       AND NOW() - created_at < '#{ttl} minutes'::INTERVAL)
    #     ORDER BY user_id, id DESC
    #     """
    #   keys: ['port_id', 'type', 'lane']

    collect:
      sql: """
        SELECT DISTINCT ON (user_id) user_id, id, delay, EXTRACT (EPOCH FROM (NOW() - created_at)) as created_ago
        FROM #{reportsTable}
        WHERE (port_id = $1::integer AND type = $2 AND lane = $3)
        ORDER BY user_id, id DESC
        LIMIT 10
        """
      keys: ['port_id', 'type', 'lane']

    createPortsTable:
      sql: """
        CREATE TABLE IF NOT EXISTS "#{portsTable}" (
          "port_id" integer PRIMARY KEY,
          "port" varchar(255) NOT NULL,
          "crossing" varchar(255) NOT NULL
        );"""

    createReportsTable:
      sql: """
        CREATE TABLE IF NOT EXISTS "#{reportsTable}" (
          "id" serial PRIMARY KEY,
          "port_id" integer REFERENCES "#{portsTable}" (port_id),
          "type" varchar(255) NOT NULL,
          "lane" varchar(255) NOT NULL,
          "delay" smallint NOT NULL,
          "user_id" varchar(255) NOT NULL,
          "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP
        );
        """

  object map queries, (cmd, key) ->
    fn = (params, callback) ->
      if typeof params is 'function'
        callback = params
        params = {}
      params = map cmd.keys, (key) -> params[key]
      debug "Running sql query: #{cmd.sql} with params: #{params}"
      pg cmd.sql, params, callback
    [key, fn]