import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../config/constants.dart';

class ApiService {
  static const String _baseUrl = Constants.apiUrl;

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
        // The API returns a list of contacts, where the nested 'contact' object is the User
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
    try {
      final response = await http.get(Uri.parse('$_baseUrl/messages/$userId1/$userId2'));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getRecentChats(String userId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/chats/$userId'));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching recent chats: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getMomentsFeed(String userId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/moments/feed/$userId'));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching moments feed: $e');
      return [];
    }
  }
}
