import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'search_screen.dart';

class ContactsScreen extends StatefulWidget {
  final String currentUserId;

  const ContactsScreen({super.key, required this.currentUserId});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<User> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    final contacts = await ApiService.getContacts(widget.currentUserId);
    
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Meus Contatos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Você ainda não tem contatos salvos', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SearchScreen(currentUserId: widget.currentUserId)),
                          );
                          _loadContacts(); // Recarrega a lista ao voltar
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar Contatos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF7C3AED),
                  onRefresh: _loadContacts,
                  child: ListView.separated(
                    itemCount: _contacts.length,
                    separatorBuilder: (context, index) => const Divider(indent: 72, height: 1),
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFFEDE9FE),
                          backgroundImage: contact.avatar != null ? NetworkImage(contact.avatar!) : null,
                          child: contact.avatar == null
                              ? Text(
                                  contact.username[0].toUpperCase(),
                                  style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 18),
                                )
                              : null,
                        ),
                        title: Text(
                          '@${contact.username}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          contact.bio ?? 'Disponível no Arroba',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF7C3AED)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(contact: contact, currentUserId: widget.currentUserId),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SearchScreen(currentUserId: widget.currentUserId)),
          );
          _loadContacts();
        },
        backgroundColor: const Color(0xFF7C3AED),
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      ),
    );
  }
}
