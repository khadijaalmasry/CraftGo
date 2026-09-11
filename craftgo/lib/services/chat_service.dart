import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';
import 'session_service.dart';

class ChatService {
  static io.Socket? _socket;

  static String get _wsUrl {
    final base = ApiService.baseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  static Future<void> connectSocket({
    required String chatId,
    required void Function(Map<String, dynamic>) onMessage,
    void Function(Map<String, dynamic>)? onReadAck,
  }) async {
    await disconnectSocket();
    final token = await SessionService.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[ChatService] No token — socket not connected.');
      return;
    }

    _socket = io.io(
      _wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[ChatService] Socket connected: ${_socket!.id}');
      _socket!.emit('joinChat', chatId);
    });

    _socket!.on('newMessage', (data) {
      if (data is Map) onMessage(Map<String, dynamic>.from(data));
    });

    _socket!.on('messagesRead', (data) {
      if (data is Map && onReadAck != null) {
        onReadAck(Map<String, dynamic>.from(data));
      }
    });

    _socket!
        .on('error', (err) => debugPrint('[ChatService] Socket error: $err'));
    _socket!
        .onDisconnect((_) => debugPrint('[ChatService] Socket disconnected.'));

    _socket!.connect();
  }

  static Future<void> disconnectSocket() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // ── REST ───────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getMyChats() async {
    try {
      final response = await ApiService.get('/chats');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      debugPrint(
          '[ChatService] getMyChats error ${response.statusCode}: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('[ChatService] getMyChats exception: $e');
      return [];
    }
  }

  /// Create or get a chat with any user (not just craftsman).
  static Future<Map<String, dynamic>?> createOrGetChat({
    required String otherUserId,
    required String otherUserRole,
    String? orderId,
  }) async {
    try {
      final body = <String, dynamic>{
        'otherUserId': otherUserId,
        'otherUserRole': otherUserRole,
      };
      if (orderId != null && orderId.isNotEmpty) body['orderId'] = orderId;

      final response = await ApiService.post('/chats', body: body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint(
          '[ChatService] createOrGetChat error ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[ChatService] createOrGetChat exception: $e');
      return null;
    }
  }

  static Future<List<dynamic>> getMessages(String chatId) async {
    try {
      final response = await ApiService.get('/chats/$chatId/messages');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      debugPrint(
          '[ChatService] getMessages error ${response.statusCode}: ${response.body}');
      throw Exception('Failed to load messages (${response.statusCode})');
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> sendMessage({
    required String chatId,
    required String content,
  }) async {
    try {
      final response = await ApiService.post(
        '/chats/$chatId/messages',
        body: {'content': content},
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint(
          '[ChatService] sendMessage error ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[ChatService] sendMessage exception: $e');
      return null;
    }
  }

  static Future<bool> markChatAsRead(String chatId) async {
    try {
      final response = await ApiService.patch('/chats/$chatId/read');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ChatService] markChatAsRead exception: $e');
      return false;
    }
  }
}
