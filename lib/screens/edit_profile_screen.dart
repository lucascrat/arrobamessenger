import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/media_service.dart';
import '../models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentUserId;

  const EditProfileScreen({super.key, required this.currentUserId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;
  
  File? _imageFile;
  String? _currentAvatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _emailController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? '';
    
    // We fetch fresh data from API
    final user = await ApiService.getUserProfile(username);
    
    if (user != null && mounted) {
      setState(() {
        _usernameController.text = user.username;
        _bioController.text = user.bio ?? '';
        _emailController.text = ''; // API currently doesn't return email in getUserProfile, might need update
        _currentAvatarUrl = user.avatar;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? avatarUrl = _currentAvatarUrl;

      // 1. Upload image if changed
      if (_imageFile != null) {
        final uploadedUrl = await MediaService.uploadMediaDirectlyToR2(_imageFile!);
        if (uploadedUrl != null) {
          avatarUrl = uploadedUrl;
        }
      }

      // 2. Update profile in backend
      final success = await ApiService.updateUser(widget.currentUserId, {
        'username': _usernameController.text.trim().toLowerCase(),
        'bio': _bioController.text.trim(),
        'avatar': avatarUrl,
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      });

      if (success && mounted) {
        // Update local cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', _usernameController.text.trim().toLowerCase());
        if (avatarUrl != null) {
          await prefs.setString('avatar', avatarUrl);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
        Navigator.pop(context, true); // Return true to indicate change
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar perfil. O @username pode já estar em uso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Salvar', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Profile Photo
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color(0xFFEDE9FE),
                          backgroundImage: _imageFile != null 
                              ? FileImage(_imageFile!) as ImageProvider
                              : (_currentAvatarUrl != null ? NetworkImage(_currentAvatarUrl!) : null),
                          child: (_imageFile == null && _currentAvatarUrl == null)
                              ? const Icon(Icons.person, size: 60, color: Color(0xFF7C3AED))
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Seu @username',
                      prefixText: '@ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'O username é obrigatório';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Bio Field
                  TextFormField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Sua Bio',
                      hintText: 'Fale um pouco sobre você...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Email Field (Opcional)
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'E-mail (opcional)',
                      hintText: 'seu@email.com',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 40),
                  
                  const Text(
                    'Informações públicas serão visíveis para todos no Arroba.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
              ),
            ),
        ],
      ),
    );
  }
}
