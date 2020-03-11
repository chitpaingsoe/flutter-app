import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/rtc_video_view.dart';

import 'Signaling.dart';

class PlayStream extends StatefulWidget {
  PlayStream({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _PlayStreamState createState() => _PlayStreamState();
}

class _PlayStreamState extends State<PlayStream> {
  Signaling _signaling;
  String _serverUrl='http://192.168.0.68:8000';
  String video='rtsp://192.168.0.203/user=admin_password=tlJwpbo6_channel=1_stream=0.sdp?real_stream';
  List<dynamic> mediaList= [];

  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();
  }


  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _connect() async {
    if (_signaling == null) {
      _signaling = new Signaling(_serverUrl,video)..connect();

      _signaling.onStateChange = (SignalingState state) {
        switch (state) {
          case SignalingState.CallStateNew:
            this.setState(() {
             // _inCalling = true;
            });
            break;
          case SignalingState.CallStateBye:
            this.setState(() {
              _localRenderer.srcObject = null;
              _remoteRenderer.srcObject = null;
              //_inCalling = false;
            });
            break;
          case SignalingState.CallStateInvite:
          case SignalingState.CallStateConnected:
          case SignalingState.CallStateRinging:
          case SignalingState.ConnectionClosed:
          case SignalingState.ConnectionError:
          case SignalingState.ConnectionOpen:
            break;
        }
      };

      _signaling.onPeersUpdate = ((event) {
//        this.setState(() {
//          _selfId = event['self'];
//          _peers = event['peers'];
//        });
      });

      _signaling.onLocalStream = ((stream) {
        _localRenderer.srcObject = stream;
      });

      _signaling.onAddRemoteStream = ((stream) {
        _remoteRenderer.srcObject = stream;
      });

      _signaling.onRemoveRemoteStream = ((stream) {
        _remoteRenderer.srcObject = null;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body:
      OrientationBuilder(builder: (context, orientation) {
        return new Container(
          child: Column(
            children: <Widget>[
              Text(""),
              Padding(
                padding: EdgeInsets.all(20),
                child: TextField(
                  onChanged: (value){
                    this.setState(() {
                      _serverUrl = value;
                    });
                  },
                  decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: _serverUrl
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: Text("Video List:",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 16),),
                  ),
                  Container(
                    child: new DropdownButton<String>(
                      hint:  Text("Select item"),
                      value: video,

                      items: mediaList.map((dynamic media) {
                        var value= media['video'];
                        return new DropdownMenuItem<String>(
                          value: value,
                          child: new Text(value),
                        );
                      }).toList(),
                      onChanged: (_value) {
                        this.setState(() {
                          video = _value;
                        });
                      },
                    ),
                  )
                ],
              ),
              Row(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                      child: RaisedButton(
                          onPressed: () async {
                            var res = await _signaling.getMediaList(_serverUrl);
                            this.setState(() {
                              mediaList= json.decode(res);
                            });
                          },
                          child: Text(
                              'Get Video List',
                              style: TextStyle(fontSize: 20)
                          ))
                  ),
                  Padding(
                      padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                      child: RaisedButton(
                          onPressed: () async {
                            if(_signaling != null){
                              _signaling.disconnect();
                              _signaling = null;
                              _connect();
                            }
                          },
                          child: Text(
                              'Connect',
                              style: TextStyle(fontSize: 20)
                          ))
                  )
                ],
              ),

            Text(""),
              Text("Remote Video"),
              new Container(
                margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                width: MediaQuery. of(context). size. width,
                height:
                 300 ,
                child: new RTCVideoView(_remoteRenderer                                                                                                                                                                                                                              ),
                decoration: new BoxDecoration(color: Colors.black54),
              ),

            ],
          ),
        );
      })

    );
  }
}
