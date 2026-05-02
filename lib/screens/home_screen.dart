import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'moments_viewer.dart';
import 'appearance_screen.dart';
import 'create_moment_screen.dart';
import 'contacts_screen.dart';
import 'search_screen.dart';
import '../main.dart'; // Para navegar de volta pro SplashScreen caso faça logout

class HomeScreen extends StatefulWidget {
  final String currentUserId;

  const HomeScreen({super.key, required this.currentUserId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  List<dynamic> _chats = [];
  List<dynamic> _moments = [];
  bool _isLoadingChats = true;
  bool _isLoadingMoments = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadChats(),
      _loadMoments(),
    ]);
  }

  Future<void> _loadChats() async {
    setState(() => _isLoadingChats = true);
    final chats = await ApiService.getRecentChats(widget.currentUserId);
    if (mounted) {
      setState(() {
        _chats = chats;
        _isLoadingChats = false;
      });
    }
  }

  Future<void> _loadMoments() async {
    setState(() => _isLoadingMoments = true);
    final moments = await ApiService.getMomentsFeed(widget.currentUserId);
    if (mounted) {
      setState(() {
        _moments = moments;
        _isLoadingMoments = false;
      });
    }
  }
  
  String _formatTime(String isoTime) {
    final dt = DateTime.parse(isoTime);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Arroba', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search), 
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen(currentUserId: widget.currentUserId)),
              );
            }
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') _logout();
              if (value == 'refresh') _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'refresh', child: Text('Atualizar')),
              const PopupMenuItem(value: 'logout', child: Text('Sair da Conta', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildChatList(),
          _buildMomentsFeed(),
          _buildShoppingPlaceholder(),
          _buildSettingsList(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF7C3AED),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Conversas'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), activeIcon: Icon(Icons.camera_alt), label: 'Moments'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), activeIcon: Icon(Icons.shopping_bag), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedIndex == 1) {
            // Moments tab
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateMomentScreen(currentUserId: widget.currentUserId),
              ),
            );
          } else if (_selectedIndex == 0) {
            // Chats tab -> Go to contacts
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContactsScreen(currentUserId: widget.currentUserId),
              ),
            ).then((_) => _loadChats()); // Atualiza ao voltar
          }
        },
        backgroundColor: const Color(0xFF7C3AED),
        child: Icon(
          _selectedIndex == 1 ? Icons.camera_alt : Icons.add_comment,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildChatList() {
    if (_isLoadingChats) return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    if (_chats.isEmpty) return const Center(child: Text('Nenhuma conversa ainda.', style: TextStyle(color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _loadChats,
      color: const Color(0xFF7C3AED),
      child: ListView.separated(
        itemCount: _chats.length,
        separatorBuilder: (context, index) => const Divider(indent: 80, height: 1),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final contactUser = User(
            id: chat['contact']['id'],
            username: chat['contact']['username'],
            avatar: chat['contact']['avatar'],
            bio: null,
          );
          
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFEDE9FE),
              child: Text(
                contactUser.username[0].toUpperCase(),
                style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              '@${contactUser.username}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              chat['lastMessage'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: chat['unreadCount'] > 0 ? Colors.black87 : Colors.grey),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatTime(chat['timestamp']), style: TextStyle(color: chat['unreadCount'] > 0 ? const Color(0xFF7C3AED) : Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                if (chat['unreadCount'] > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
                    child: Text(
                      chat['unreadCount'].toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(contact: contactUser, currentUserId: widget.currentUserId),
                ),
              ).then((_) => _loadChats());
            },
          );
        },
      ),
    );
  }

  Widget _buildMomentsFeed() {
    if (_isLoadingMoments) return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Moments da sua Rede', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        if (_moments.isEmpty)
          const Expanded(child: Center(child: Text('Nenhum moment publicado nas últimas 24h.', style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMoments,
              color: const Color(0xFF7C3AED),
              child: ListView.builder(
                itemCount: _moments.length,
                itemBuilder: (context, index) {
                  final feedItem = _moments[index];
                  final user = feedItem['user'];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF7C3AED), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 24, 
                        backgroundColor: const Color(0xFFEDE9FE),
                        child: Text(user['username'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF7C3AED))),
                      ),
                    ),
                    title: Text('@${user['username']}'),
                    subtitle: Text('Atualizado às ${_formatTime(feedItem['latestTimestamp'])}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // Nota: MomentsViewer precisará ser atualizado para receber o ID e buscar pela API futuramente.
                          builder: (context) => MomentsViewer(username: user['username']),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShoppingPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Arroba Shopping vindo aí!', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return ListView(
      children: [
        const ListTile(
          leading: CircleAvatar(backgroundColor: Color(0xFF7C3AED)),
          title: Text('Meu Perfil'),
          subtitle: Text('Editar nome, bio e foto'),
          trailing: Icon(Icons.chevron_right),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Aparência'),
          subtitle: const Text('Temas e Cores'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AppearanceScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.security_outlined),
          title: const Text('Segurança'),
          subtitle: const Text('Privacidade e Arroba Pay'),
          onTap: () {},
        ),
      ],
    );
  }
}
