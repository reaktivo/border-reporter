debug = require('debug')('border:calculate')
{ max, min, abs } = Math

calculate = (rows, ttl) =>
  debug "calculate() with rows of length: #{rows.length}"
  if rows.length > 1
    simpleAverage = average rows
    for row in rows
      awayFromAverage = 1 - min(abs(simpleAverage - row.delay), ttl) / ttl
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