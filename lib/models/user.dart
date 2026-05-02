class User {
  final String id;
  final String username;
  final String? avatar;
  final String? bio;

  User({required this.id, required this.username, this.avatar, this.bio});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      avatar: json['avatar'],
      bio: json['bio'],
    );
  }
}

class ChatPreview {
  final User contact;
  final String lastMessage;
  final String time;
  final int unreadCount;

  ChatPreview({
    required this.contact,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
  });
}
