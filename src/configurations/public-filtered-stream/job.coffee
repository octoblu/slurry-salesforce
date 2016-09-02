http    = require 'http'
_       = require 'lodash'
Salesforce = require 'node-salesforce'
MeshbluHttp = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'

class PublicFilteredStream
  constructor: ({@encrypted, @auth, @userDeviceUuid}) ->
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @salesforce = new Salesforce({
      consumer_id:        process.env.SLURRY_SALESFORCE_SALESFORCE_CLIENT_ID
      consumer_secret:     process.env.SLURRY_SALESFORCE_SALESFORCE_CLIENT_SECRET
    })
    @_throttledMessage = _.throttle meshbluHttp.message, 500, leading: true, trailing: false

  do: ({slurry}, callback) =>
    metadata =
      track: _.join(slurry.track, ',')
      follow: _.join(slurry.follow, ',')

    @salesforce.streaming.topic('InvoiceStatementUpdates').subscribe (message) ->
      console.log 'Event Type : ' + message.event.type
      console.log 'Event Created : ' + message.event.createdDate
      console.log 'Object Id : ' + message.sobject.Id

    @salesforce.stream 'statuses/filter', metadata, (stream) =>
      stream.on 'data', (event) =>
        message =
          devices: ['*']
          metadata: metadata
          data: event

        @_throttledMessage message, as: @userDeviceUuid, (error) =>
          console.error error if error?

      stream.on 'error', (error) =>
        console.error error.stack

      return callback null, stream

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = PublicFilteredStream
