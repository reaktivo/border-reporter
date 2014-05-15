{ pick, map, object } = require 'underscore'

module.exports = (opts) ->

  pg = opts.pg
  table = opts.table
  ttl = opts.ttl

  queries =
    insert:
      sql: "INSERT INTO #{table} (port, type, lane, delay, user_id) VALUES ($1, $2, $3, $4, $5)"
      keys: ['port', 'type', 'lane', 'delay', 'userId']

    findLatest:
      sql: """
        SELECT * FROM #{table}
        WHERE (port = $1 AND type = $2 AND lane = $3 AND user_id = $4)
        ORDER BY id DESC
        LIMIT 1
        """
      keys: ['port', 'type', 'lane', 'userId']

    findRecent:
      sql: """
        SELECT 1 FROM #{table}
        WHERE (user_id = $1 AND EXTRACT (EPOCH FROM (NOW() - created_at)/60) < #{ttl})
        LIMIT 1
        """
      keys: ['userId']

    collect:
      sql: """
        SELECT delay, (#{ttl} - EXTRACT (EPOCH FROM (NOW() - created_at))/60)/#{ttl} as relevancy
        FROM #{table}
        WHERE (port = $1 AND type = $2 AND lane = $3
        AND NOW() - created_at < '#{ttl} minutes'::INTERVAL)
        """
      keys: ['port', 'type', 'lane']

    migrate:
      sql: """
        CREATE TABLE IF NOT EXISTS "#{table}" (
          "id" serial PRIMARY KEY NOT NULL,
          "port" varchar(255) NOT NULL,
          "type" varchar(255) NOT NULL,
          "lane" varchar(255) NOT NULL,
          "delay" smallint NOT NULL,
          "user_id" varchar(255) NOT NULL,
          "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP
        )
        """

  object map queries, (cmd, key) ->
    fn = (params, callback) ->
      if typeof params is 'function'
        callback = params
        params = {}
      params = map cmd.keys, (key) -> params[key]
      pg cmd.sql, params, callback
    [key, fn]