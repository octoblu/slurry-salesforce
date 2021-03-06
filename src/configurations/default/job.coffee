http          = require 'http'
_             = require 'lodash'
Salesforce    = require 'jsforce'
MeshbluHttp   = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
SlurryStream  = require 'slurry-core/slurry-stream'

debug = require('debug')('slurry-salesforce')

class PublicFilteredStream
  constructor: ({@encrypted, @auth, @userDeviceUuid}) ->
    debug 'New Stream', @userDeviceUuid
    meshbluConfig = new MeshbluConfig({@auth}).toJSON()
    meshbluHttp = new MeshbluHttp meshbluConfig
    @salesforce = new Salesforce.Connection({
      instanceUrl: @encrypted.secrets.instanceUrl
      accessToken: @encrypted.secrets.credentials.secret
    })
    @_throttledMessage = _.throttle meshbluHttp.message, 500, leading: true, trailing: false

  do: ({slurry}, callback) =>
    { topic, disabled } = slurry ? {}
    return @_userError 422, "Requires Topic to subscribe" unless topic?
    return @_userError 422, "Missing instance URL in credentials device" if _.isEmpty @encrypted.secrets.instanceUrl

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
