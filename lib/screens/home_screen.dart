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
import 'edit_profile_screen.dart';
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
  User? _currentUserProfile;
  bool _isLoading = true;
  bool _isLoadingChats = true;
  bool _isLoadingMoments = true;
  User? _selectedContact;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUserProfile(),
      _loadChats(),
      _loadMoments(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username != null) {
      final user = await ApiService.getUserProfile(username);
      if (mounted) {
        setState(() {
          _currentUserProfile = user;
        });
      }
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth > 900;

        if (isWideScreen) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Row(
              children: [
                // Desktop Navigation Rail (The far left strip)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: Color(0xFF7C3AED)),
                  selectedLabelTextStyle: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                  unselectedIconTheme: const IconThemeData(color: Colors.grey),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: Text('Conversas')),
                    NavigationRailDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt), label: Text('Moments')),
                    NavigationRailDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: Text('Shop')),
                    NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Ajustes')),
                  ],
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
                      child: const Center(child: Text('@', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                    ),
                  ),
                ),
                // Sidebar List Area (The middle strip)
                Container(
                  width: 350,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade200),
                      right: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(
                        _selectedIndex == 0 ? 'Conversas' : 
                        _selectedIndex == 1 ? 'Moments' : 
                        _selectedIndex == 2 ? 'Shop' : 'Ajustes',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)
                      ),
                      actions: [
                        if (_selectedIndex == 0)
                          IconButton(
                            icon: const Icon(Icons.add_comment_outlined), 
                            onPressed: () => _handleFABAction()
                          ),
                        IconButton(
                          icon: const Icon(Icons.search), 
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SearchScreen(currentUserId: widget.currentUserId)),
                            );
                          }
                        ),
                      ],
                      elevation: 0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    body: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _buildChatList(true),
                        _buildMomentsFeed(),
                        _buildShoppingPlaceholder(),
                        _buildSettingsList(),
                      ],
                    ),
                  ),
                ),
                // Chat Detail Area (The large right side)
                Expanded(
                  child: _selectedContact != null
                      ? ChatScreen(
                          contact: _selectedContact!, 
                          currentUserId: widget.currentUserId,
                          isEmbedded: true,
                          onBack: () => setState(() => _selectedContact = null),
                        )
                      : Container(
                          color: const Color(0xFFF8F9FA),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _currentUserProfile?.avatar != null ? NetworkImage(_currentUserProfile!.avatar!) : null,
                                    child: _currentUserProfile?.avatar == null 
                                      ? const Text('@', style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))
                                      : null,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                const Text('Arroba Messenger para Web', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87)),
                                const SizedBox(height: 8),
                                const Text('Envie e receba mensagens com segurança e rapidez.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        }

        // Mobile View (Default)
        return Scaffold(
          backgroundColor: Colors.white,
          drawer: _buildDrawer(),
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
              _buildChatList(false),
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
            onPressed: () => _handleFABAction(),
            backgroundColor: const Color(0xFF7C3AED),
            child: Icon(
              _selectedIndex == 1 ? Icons.camera_alt : Icons.add_comment,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  void _handleFABAction() {
    if (_selectedIndex == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CreateMomentScreen(currentUserId: widget.currentUserId)),
      );
    } else if (_selectedIndex == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ContactsScreen(currentUserId: widget.currentUserId)),
      ).then((_) => _loadChats());
    }
  }

  Widget _buildChatList(bool isEmbedded) {
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
          
          final bool isSelected = _selectedContact?.id == contactUser.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: const Color(0xFFF3F0FF),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFEDE9FE),
              child: Text(
                contactUser.username[0].toUpperCase(),
                style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF7C3AED), fontWeight: FontWeight.bold),
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
              if (isEmbedded) {
                setState(() => _selectedContact = contactUser);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(contact: contactUser, currentUserId: widget.currentUserId),
                  ),
                ).then((_) => _loadChats());
              }
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
        ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFF7C3AED), child: Icon(Icons.person, color: Colors.white)),
          title: const Text('Meu Perfil'),
          subtitle: const Text('Editar nome, bio e foto'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EditProfileScreen(currentUserId: widget.currentUserId)),
            ).then((value) {
              if (value == true) _loadData(); // Refresh if profile changed
            });
          },
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
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF7C3AED)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: _currentUserProfile?.avatar != null ? NetworkImage(_currentUserProfile!.avatar!) : null,
              child: _currentUserProfile?.avatar == null 
                  ? const Text('@', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)))
                  : null,
            ),
            accountName: Text(
              '@${_currentUserProfile?.username ?? "usuário"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(_currentUserProfile?.bio ?? "Sem bio definida"),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Meu Perfil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfileScreen(currentUserId: widget.currentUserId)),
              ).then((value) {
                if (value == true) _loadData();
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Ajustes'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 3);
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
            onTap: () => _logout(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
