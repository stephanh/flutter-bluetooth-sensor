import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class SensorPage extends StatefulWidget {
  final BluetoothDevice server;

  const SensorPage({this.server});

  @override
  _SensorPage createState() => new _SensorPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _SensorPage extends State<SensorPage> {
  BluetoothConnection connection;

  String _messageBuffer = '';
  
  String _temperature = '';

  bool isConnecting = true;
  bool get isConnected => connection != null && connection.isConnected;

  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
        }
        else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: (
          isConnecting ? Text('Getting sensor reading from ' + widget.server.name + '...') :
          isConnected ? Text('Sensor readings from ' + widget.server.name) :
          Text('Disconnected from ' + widget.server.name)
        )
      ),
      body: Container(
        child: ListView(
          children: <Widget>[
            Divider(),
            ListTile(
              title: const Text(
                'Temperature:',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 60),
              )
            ),
            ListTile(
              title: Text(
                _temperature,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 60),
              )
            ),
            ListTile(
              title: RaisedButton(
                child: const Text('Update'),
                onPressed: () => _getUpdate()
              )
            )
          ]
        )
      )
    );
  }

  void _onDataReceived(Uint8List data) {
    String dataString = String.fromCharCodes(data);
    print('Received ' + dataString);

    _messageBuffer = _messageBuffer + dataString;
    print('Updating message buffer ' + _messageBuffer);
    int index = data.indexOf(13);
    if (index != -1) {
      print('Got last message');
      if (_messageBuffer.startsWith('T')) {
        print('Setting temp');
        setState(() {
            _temperature = _messageBuffer.substring(1, _messageBuffer.length).trim();
        });
      }
      _messageBuffer = '';
    }
  }

  void _getUpdate() async {
    try {
      connection.output.add(utf8.encode('T'));
      await connection.output.allSent;
    } catch (e) {
      print('Got error');
      print(e);
    }
  }
}
