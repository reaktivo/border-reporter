debug = require('debug')('border:calculate')
{ max, pluck } = require 'underscore'

calculate = (rows) =>
  debug "calculate() with rows of length: #{rows.length}"
  if rows.length > 1
    maxCreatedAgo = max(pluck rows, 'created_ago') + 1
    for row in rows
      row.relevancy = 1 - (row.created_ago / maxCreatedAgo)
    simpleAverage = average rows
    for row in rows
      awayFromAverage = 1 - Math.abs(simpleAverage - row.delay) / maxCreatedAgo
      row.relevancy *= awayFromAverage
    average rows
  else
    rows[0].delay

average = (rows) =>
  # Calculate delay average
  # considering report relevancy
  delay = 0
  relevancy = 0
  for row in rows
    relevancy += row.relevancy
    delay += row.delay * row.relevancy
  # Return calculated delay
  delay / relevancy

module.exports = calculate