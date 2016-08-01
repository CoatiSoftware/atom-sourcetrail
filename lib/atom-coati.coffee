AtomCoatiView = require './atom-coati-view'
{CompositeDisposable} = require 'atom'

net = require 'net'
fs = require 'fs'
path = require 'path'

module.exports = AtomCoati =
  atomCoatiView: null
  modalPanel: null
  subscriptions: null

  server: null

  config:
    host:
      title: 'Host Ip'
      description: 'Ip to communicate with Coati'
      type: 'string'
      default: 'localhost'
    port_coati:
      title: 'Port Coati'
      description: 'Port Atom sends messages to Coati'
      type: 'integer'
      default: 6667
    port_atom:
      title: 'Port Atom'
      description: 'Port Atom listens to messages from Coati'
      type: 'integer'
      default: 6666

  activate: (state) ->
    @atomCoatiView = new AtomCoatiView(state.atomCoatiViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @atomCoatiView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that send location this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-coati:sendLocation': => @sendLocation()

    # Register command that send location this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-coati:startServer': => @startServer()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-coati:restartServer': => @restartServer()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-coati:stopServer': => @stopServer()

  deactivate: ->
    this.stopServer()
    @modalPanel.destroy()
    @subscriptions.dispose()
    @atomCoatiView.destroy()

  serialize: ->
    atomCoatiViewState: @atomCoatiView.serialize()

  sendLocation: ->
    console.log 'Send Location to Coati'
    ip = atom.config.get('atom-coati.host')
    port = atom.config.get('atom-coati.port_coati')
    connection = net.createConnection port, ip
    connection.on 'connect', () ->
      editor = atom.workspace.getActiveTextEditor()
      file = editor.getPath()
      cursor = editor.getCursorBufferPosition()

      connection.write("setActiveToken>>#{file}>>#{cursor.row}>>#{cursor.column}<EOM>")
      atom.notifications.addInfo('Location sent to Coati')
      connection.end()


  startServer: ->
    console.log 'Starting Coati Tcp Server'
    @server = net.createServer (socket) ->
      socket.on 'data', (data) ->
        console.log "#{socket.remoteAddress} sent: #{data}"
        message = data.toString()
        sp = message.split ">>"
        if sp[0] == "moveCursor"
          fs.exists sp[1], (exists) ->
            if exists
              atom.workspace.open fs.resolve sp[1],
                initialLine: sp[2] - 1
          	    initialColumn: sp[3]
            else
              atom.notifications.addError("Cant find #{sp[1]}")

    ip = atom.config.get('atom-coati.host')
    port = atom.config.get('atom-coati.port_atom')
    try
      @server.listen port, ip
    catch
      atom.notifications.addError "Cant listen to #{ip}:#{port}"

  restartServer: ->
    console.log 'Restart Coati Tcp Server'
    this.stopServer()
    this.startServer()

  stopServer: ->
    console.log 'Stop Coati Tcp Server'
    @server.close()
