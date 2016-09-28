http          = require 'http'
_             = require 'lodash'
Salesforce    = require 'jsforce'
MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
SlurryStream  = require 'slurry-core/slurry-stream'

class PublicFilteredStream
  constructor: ({@encrypted, @auth, @userDeviceUuid}) ->
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @salesforce = new Salesforce.Connection({
        instanceUrl: @salesforce.toolilng.instanceUrl
        accessToken: @encrypted.secrets.credentials.secret
      })
    @_throttledMessage = _.throttle meshbluHttp.message, 500, leading: true, trailing: false

  do: ({slurry}, callback) =>
    { topic, disabled } = slurry
    return @_userError 422, "Requires Topic to subscribe" if !topic?

    slurryStream = new SlurryStream
    slurryStream.destroy = =>
      @salesforce.logout()

    @salesforce.streaming.topic(topic).subscribe (event) =>
      message =
        devices: ['*']
        data: event

      @_throttledMessage message, as: @userDeviceUuid, (error) =>
        slurryStream.emit 'error', error if error?

    return callback null, slurryStream

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = PublicFilteredStream
