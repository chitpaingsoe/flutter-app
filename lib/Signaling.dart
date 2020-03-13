import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter_webrtc/webrtc.dart';
import 'random_string.dart';
import 'package:http/http.dart' as http;

enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

/*
 * callbacks for Signaling API.
 */
typedef void SignalingStateCallback(SignalingState state);
typedef void StreamStateCallback(MediaStream stream);
typedef void OtherEventCallback(dynamic event);
typedef void DataChannelMessageCallback(
    RTCDataChannel dc, RTCDataChannelMessage data);
typedef void DataChannelCallback(RTCDataChannel dc);

class Signaling {
  var _host;
  var _media;
  var _dataChannels = new Map<String, RTCDataChannel>();

  MediaStream _localStream;
  List<MediaStream> _remoteStreams;
  RTCPeerConnection _pc = null;
  String _id = randomNumeric(6);
  bool _isCurrentRD=false;
  List _earlyCandidates = [];
  SignalingStateCallback onStateChange;
  StreamStateCallback onLocalStream;
  StreamStateCallback onAddRemoteStream;
  StreamStateCallback onRemoveRemoteStream;
  OtherEventCallback onPeersUpdate;
  DataChannelMessageCallback onDataChannelMessage;
  DataChannelCallback onDataChannel;

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
       */
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  final Map<String, dynamic> _dc_constraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  Signaling(this._host,this._media);

  close() async {
    if (_localStream != null) {
      _localStream.dispose();
      _localStream = null;
    }
  }

  Future<dynamic> getMediaList(String url) async{
    var res = await http.get(url+'/api/getMediaList');
    return res.body;
  }


  void disconnect() async {
    if (this._pc != null) {
          await http.get(this._host + '/api/hangup?peerid=' + this._id);
      try {
        this._pc.dispose();

        this._pc.close();
      } on Exception {
        print('Fail to close peer Connection : ' + this._id);
      }
      this._pc = null;
    }
  }

  void connect() async {
    this.disconnect();
    await this.onReceiveGetIceServers();
  }

  void onReceiveGetIceServers() async {
    var options = 'rtptransport=tcp&timeout=60';

    try {
      var media = 'video';

      if (this.onStateChange != null) {
        this.onStateChange(SignalingState.CallStateNew);
      }

      await _createPeerConnection(this._id, media, false);

      var callurl =
          this._host + "/api/call?peerid=" + this._id + "&url="+ Uri.encodeComponent(this._media);
      callurl += "&options=" + Uri.encodeComponent(options);

      // clear early candidates
      //this._earlyCandidates.len = 0;

      // create Offer
      await this._createOffer(this._id, this._pc, 'video', callurl);
    } catch (e) {
      this.disconnect();
      print("connect error: " + e);
    }
  }

  Future<MediaStream> createStream(media, user_screen) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth':
              '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    MediaStream stream = user_screen
        ? await navigator.getDisplayMedia(mediaConstraints)
        : await navigator.getUserMedia(mediaConstraints);
    if (this.onLocalStream != null) {
      this.onLocalStream(stream);
    }
    return stream;
  }

  _createPeerConnection(id, media, user_screen) async {
    //get IceServers
    var iceServersRepsonse = await http.get(this._host + '/api/getIceServers');
    RTCPeerConnection pc = await createPeerConnection(json.decode(iceServersRepsonse.body), _config);

    pc.onIceCandidate = (candidate) async{
      await this._onIceCandidate(candidate);
    };

    pc.onIceConnectionState = (state) {
      if (this._pc.iceConnectionState ==
          RTCIceConnectionState.RTCIceConnectionStateNew) {
        this._getIceCandidate();
      }
    };

    pc.onAddStream = (stream) {
      print("Remot stream: ok");
      if (this.onAddRemoteStream != null) this.onAddRemoteStream(stream);
      //_remoteStreams.add(stream);
    };

    pc.onRemoveStream = (stream) {
      if (this.onRemoveRemoteStream != null) this.onRemoveRemoteStream(stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(id, channel);
    };
    this._pc = pc;
    return pc;
  }

  _addDataChannel(id, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      if (this.onDataChannelMessage != null)
        this.onDataChannelMessage(channel, data);
    };
    _dataChannels[id] = channel;

    if (this.onDataChannel != null) this.onDataChannel(channel);
  }

  _createDataChannel(id, RTCPeerConnection pc, {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = new RTCDataChannelInit();
    RTCDataChannel channel = await pc.createDataChannel(label, dataChannelDict);
    _addDataChannel(id, channel);
  }

  _createOffer(
      String id, RTCPeerConnection pc, String media, String url) async {
    try {
      RTCSessionDescription s = await pc
          .createOffer(media == 'data' ? _dc_constraints : _constraints);
      await pc.setLocalDescription(s);

      //  var res = await http.post(url,body: json.encode(s));
      var res = await _send2(s, url);
      if (res.statusCode == 200) {
        await this._onReceiveCall(res.body);
      }
    } catch (e) {
      print(e.toString());
    }
  }

  _onReceiveCall(dynamic dataJson) async {
    try {
      var data = json.decode(dataJson);
      var sdp = data['sdp'];
      var type = data['type'];
      var descr = new RTCSessionDescription(sdp, type);
      if (this._pc != null) {
        await this._pc.setRemoteDescription(descr);

      }

      print('setRemote Deescrption Ok.');
      for (var i = 0; i < this._earlyCandidates.length; i++) {
        var candidate = this._earlyCandidates[i];
        await this._addIceCandidate(candidate);
        await this._pc.addCandidate(candidate);
      }
      this._earlyCandidates.clear();

      await this._getIceCandidate();
    } catch (e) {
      print("Error on receive call in set remote desr:");
    }
  }

  _addIceCandidate(dynamic candidate) async {
    var _candidate = candidate as RTCIceCandidate;
    var payload = json.encode(_candidate.toMap());
    var res = await http.post(
        this._host + "/api/addIceCandidate?peerid=" + this._id,
        body: payload);
    if (res.statusCode == 200) {
      print('addIceCandidate Ok:' + res.body.toString());
    } else {
      print('addIceCandidate Error:' + res.body);
    }
  }

  _onIceCandidate(dynamic event) async {
    if (event.candidate != null) {
      if(this._isCurrentRD != false){
        await this._addIceCandidate(event);


      }else{
          this._earlyCandidates.add(event);
          this._isCurrentRD = true;
      }

    } else {
      print("End of candidates.");
    }
  }

  _getIceCandidate() async {
    var res =
        await http.get(this._host + "/api/getIceCandidate?peerid=" + this._id);
    if (res.statusCode == 200) {
      await this._onReceiveCandidate(res.body);
    }
  }

  _onReceiveCandidate(dynamic dataJson) async {
    var data = json.decode(dataJson) as List;
    if (data.length != 0) {
      for (var i = 0; i < data.length; i++) {
        var d = data[i];
        var cp = d['sdpMid'];
        var candidate = new RTCIceCandidate(
            d['candidate'], d['sdpMid'], d['sdpMLineIndex']);
        print("Adding ICE candidate :" + candidate.candidate );
        await this._pc.addCandidate(candidate);
      }
    }
  }

  _send2(data, url) async {
    var parsed= data as RTCSessionDescription;
    var payload = json.encode(parsed.toMap());
    var res = await http.post(url, body: payload);
    return res;
  }
}
