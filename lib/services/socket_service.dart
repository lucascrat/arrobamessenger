import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/constants.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  IO.Socket? _socket;

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  void connectAndJoin(String userId1, String userId2, Function(dynamic) onMessageReceived) {
    if (_socket != null && _socket!.connected) {
      _socket!.disconnect();
    }

    _socket = IO.io(Constants.apiUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Connected to Socket.IO Server');
      // Join room
      _socket!.emit('join_room', {
        'userId1': userId1,
        'userId2': userId2,
      });
    });

    _socket!.on('receive_message', (data) {
      onMessageReceived(data);
    });

    _socket!.onDisconnect((_) => print('Disconnected from Socket.IO Server'));
  }

  void sendMessage(String senderId, String receiverId, String content) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('send_message', {
        'senderId': senderId,
        'receiverId': receiverId,
        'content': content,
      });
    }
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
  }
}
