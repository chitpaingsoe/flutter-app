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
  int _counter = 0;
  Signaling _signaling;
  List<dynamic> _peers;
  var _selfId;
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
      _signaling = new Signaling('http://192.168.0.69:8000')..connect();

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
        this.setState(() {
          _selfId = event['self'];
          _peers = event['peers'];
        });
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

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
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
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body:
      OrientationBuilder(builder: (context, orientation) {
        return new Container(
          child: new Stack(children: <Widget>[
            new Positioned(
                left: 0.0,
                right: 0.0,
                top: 0.0,
                bottom: 0.0,
                child: new Container(
                  margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  width: 200,
                  height: 200,
                  child: new RTCVideoView(_remoteRenderer                                                                                                                                                                                                                              ),
                  decoration: new BoxDecoration(color: Colors.black54),
                )),
//            new Positioned(
//              left: 20.0,
//              top: 20.0,
//              child: new Container(
//                width: orientation == Orientation.portrait ? 90.0 : 120.0,
//                height:
//                orientation == Orientation.portrait ? 120.0 : 90.0,
//                child: new RTCVideoView(_localRenderer),
//                decoration: new BoxDecoration(color: Colors.black54),
//              ),
//            ),
          ]),
        );
      })
//      Column(
//        children: <Widget>[
//          Column(
//            children: <Widget>[
//              Text('Remote Video'),
//              new Positioned(
//                  left: 0.0,
//                  right: 0.0,
//                  top: 0.0,
//                  bottom: 0.0,
//                  child: new Container(
//                    margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
//                    width: 100,
//                    height: 100,
//                    child: new RTCVideoView(_localRenderer),
//                    decoration: new BoxDecoration(color: Colors.amberAccent),
//                  )),
//
//            ],
//          ),
//
//
//        ],
//      )// This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
