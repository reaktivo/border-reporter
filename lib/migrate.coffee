module.exports = (pg, table) ->

  sql = """
    CREATE TABLE IF NOT EXISTS "#{table}" (
      "id" serial PRIMARY KEY NOT NULL,
      "port" varchar(255) NOT NULL,
      "type" varchar(255) NOT NULL,
      "lane" varchar(255) NOT NULL,
      "delay" smallint NOT NULL,
      "user_id" varchar(255) NOT NULL,
      "created_at" timestamp NOT NULL DEFAULT now()
    )
    """

  pg sql, (err, rows, res) ->
    if err
      errMessage = "Could not initialize table '#{table}'"
      throw Error(errMessage)
      console.log(errMessage)