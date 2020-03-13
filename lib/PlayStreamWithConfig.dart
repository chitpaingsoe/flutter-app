import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/rtc_video_view.dart';

import 'Signaling.dart';

class PlayStreamWithConfig extends StatefulWidget {
  PlayStreamWithConfig({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _PlayStreamWithConfigState createState() => _PlayStreamWithConfigState();
}

class _PlayStreamWithConfigState extends State<PlayStreamWithConfig> {
  Signaling _signaling;
  String _serverUrl = 'http://192.168.0.68:8000';
  String video = 'StreamHLocal';
  List<dynamic> mediaList = [];
  String _signalState = "none";
  bool _viewFullVideo = false;

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
      this.setState(() {
        _signalState = "connecting";
      });
      _signaling = new Signaling(_serverUrl, video)..connect();

      await getMediaLists();

//      _signaling.onStateChange = (SignalingState state) {
//        switch (state) {
//          case SignalingState.CallStateNew:
//            this.setState(() {
//              // _inCalling = true;
//            });
//            break;
//          case SignalingState.CallStateBye:
//            this.setState(() {
//              _localRenderer.srcObject = null;
//              _remoteRenderer.srcObject = null;
//              //_inCalling = false;
//            });
//            break;
//          case SignalingState.CallStateInvite:
//          case SignalingState.CallStateConnected:
//          case SignalingState.CallStateRinging:
//          case SignalingState.ConnectionClosed:
//          case SignalingState.ConnectionError:
//          case SignalingState.ConnectionOpen:
//            break;
//        }
//      };

      _signaling.onLocalStream = ((stream) {
        _localRenderer.srcObject = stream;
      });

      _signaling.onAddRemoteStream = ((stream) {
        _remoteRenderer.srcObject = stream;
        this.setState(() {
          _signalState = "connected";
        });
      });

      _signaling.onRemoveRemoteStream = ((stream) {
        _remoteRenderer.srcObject = null;
      });
    }
  }

  Future<void> getMediaLists() async {
    this.setState(() {
      mediaList = [];
    });
    var res = await _signaling.getMediaList(_serverUrl);
    this.setState(() {
      mediaList = json.decode(res);
    });
  }

  Widget getandRenderSignalState() {
    if (this._signalState == "connecting") {
      return Text(
        "Connecting.....",
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color.fromRGBO(230, 184, 0, 1.0)),
      );
    } else if (this._signalState == "connected") {
      return Text(
        "Connected",
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color.fromRGBO(0, 179, 0, 1.0)),
      );
    } else if (this._signalState == "stopped") {
      return Text(
        "Stopped",
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color.fromRGBO(0, 77, 153, 1.0)),
      );
    } else {
      return Text(
        "None",
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color.fromRGBO(0, 0, 0, 1.0)),
      );
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
        appBar:
        this._viewFullVideo ? null :
        AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: this._viewFullVideo
            ? new Container(
                margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child:
                  GestureDetector(
                    onDoubleTap: (){
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                      this.setState(() {
                        _viewFullVideo = false;
                      });
                    },
                    child: new RTCVideoView(_remoteRenderer),
                  ),
                decoration: new BoxDecoration(color: Colors.black54),
              )
            : new Container(
                child: Column(
                  children: <Widget>[
                    Text(""),
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: TextField(
                        onChanged: (value) {
                          this.setState(() {
                            _serverUrl = value;
                          });
                        },
                        decoration: InputDecoration(
                            border: OutlineInputBorder(), hintText: _serverUrl),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            "Select Video:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Container(
                          child: new DropdownButton<String>(
                            hint: Text("Select item"),
                            value: video.isNotEmpty ? video : null,
                            items: mediaList.map((dynamic media) {
                              var value = media['video'];
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
                                  await getMediaLists();
                                },
                                child: Text('Get Video List',
                                    style: TextStyle(fontSize: 20)))),
                        Padding(
                            padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                            child: RaisedButton(
                                onPressed: () async {
                                  if (_signaling != null && video.isNotEmpty) {
                                    _signaling.disconnect();
                                    _signaling = null;
                                    _connect();
                                  }
                                },
                                child: Text('Connect',
                                    style: TextStyle(fontSize: 20)))),
                        Padding(
                            padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                            child: RaisedButton(
                                onPressed: () async {
                                  if (_signaling != null) {
                                    _signaling.disconnect();
                                    this.setState(() {
                                      video = "";
                                      _signalState = "stopped";
                                    });
                                  }
                                },
                                child: Text('Stop',
                                    style: TextStyle(fontSize: 20))))
                      ],
                    ),
                    Text(""),
                    Row(
                      children: <Widget>[
                        Padding(
                            padding: EdgeInsets.all(10),
                            child: Text("Status:")),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: getandRenderSignalState(),
                        )
                      ],
                    ),

                    new Container(
                      margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                      width: MediaQuery.of(context).size.width,
                      height: 300,
                      child: GestureDetector(
                        onDoubleTap: (){
                          SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
                          this.setState(() {
                            _viewFullVideo = true;
                          });
                        },
                        child: new RTCVideoView(_remoteRenderer),
                      ),
                      decoration: new BoxDecoration(color: Colors.black54),
                    ),
//                    Padding(
//                        padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
//                        child: RaisedButton(
//                            onPressed: () async {
//                              if (_signaling != null) {
//                                this.setState(() {
//                                  _viewFullVideo = true;
//                                });
//                              }
//                            },
//                            child: Text('View Full Video',
//                                style: TextStyle(fontSize: 20)))),


                  ],
                ),
              ));
  }
}
