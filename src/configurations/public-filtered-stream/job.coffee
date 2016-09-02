http    = require 'http'
_       = require 'lodash'
Salesforce = require 'jsforce'
MeshbluHttp = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'

class PublicFilteredStream
  constructor: ({@encrypted, @auth, @userDeviceUuid}) ->
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @salesforce = new Salesforce.Connection({
        accessToken: @encrypted.secrets.credentials.secret
        instanceUrl: "https://na17.salesforce.com"
      })
    @_throttledMessage = _.throttle meshbluHttp.message, 500, leading: true, trailing: false

  do: ({slurry}, callback) =>
    @salesforce.streaming.topic('LeadAddress').subscribe (event) =>
      console.log 'Event Type : ' + event.event.type
      console.log 'Event Created : ' + event.event.createdDate
      console.log 'Object Id : ' + event.sobject.Id

      message =
        devices: ['*']
        data: event

      @_throttledMessage message, as: @userDeviceUuid, (error) =>
        console.error error if error?

      return callback null, event

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = PublicFilteredStream
