import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../config/constants.dart';

class ApiService {
  static const String _baseUrl = Constants.apiUrl;

  // Caching Keys
  static const String _chatsCacheKey = 'cached_chats_';
  static const String _messagesCacheKey = 'cached_messages_';
  static const String _momentsCacheKey = 'cached_moments_';

  static Future<void> _saveToCache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  static Future<dynamic> _loadFromCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached != null) {
      return jsonDecode(cached);
    }
    return null;
  }

  static Future<List<User>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await http.get(Uri.parse('$_baseUrl/users/search?q=$query'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User(
          id: json['id'],
          username: json['username'],
          avatar: json['avatar'],
          bio: json['bio'],
        )).toList();
      }
      return [];
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  static Future<List<User>> getContacts(String userId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/contacts/$userId'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User(
          id: json['contact']['id'],
          username: json['contact']['username'],
          avatar: json['contact']['avatar'],
          bio: json['contact']['bio'],
        )).toList();
      }
      return [];
    } catch (e) {
      print('Error getting contacts: $e');
      return [];
    }
  }

  static Future<bool> addContact(String userId, String contactId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'contactId': contactId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error adding contact: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getMessages(String userId1, String userId2) async {
    final cacheKey = '$_messagesCacheKey${userId1}_$userId2';
    try {
      final response = await http.get(Uri.parse('$_baseUrl/messages/$userId1/$userId2'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToCache(cacheKey, data);
        return data;
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
    
    // Return cache if fetch fails
    return await _loadFromCache(cacheKey) ?? [];
  }

  static Future<List<dynamic>> getRecentChats(String userId) async {
    final cacheKey = '$_chatsCacheKey$userId';
    try {
      final response = await http.get(Uri.parse('$_baseUrl/chats/$userId'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToCache(cacheKey, data);
        return data;
      }
    } catch (e) {
      print('Error fetching recent chats: $e');
    }

    // Return cache if fetch fails
    return await _loadFromCache(cacheKey) ?? [];
  }

  static Future<List<dynamic>> getMomentsFeed(String userId) async {
    final cacheKey = '$_momentsCacheKey$userId';
    try {
      final response = await http.get(Uri.parse('$_baseUrl/moments/feed/$userId'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToCache(cacheKey, data);
        return data;
      }
    } catch (e) {
      print('Error fetching moments feed: $e');
    }

    // Return cache if fetch fails
    return await _loadFromCache(cacheKey) ?? [];
  }

  static Future<User?> getUserProfile(String username) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/users/$username'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User(
          id: data['id'],
          username: data['username'],
          avatar: data['avatar'],
          bio: data['bio'],
        );
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  static Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }
}
