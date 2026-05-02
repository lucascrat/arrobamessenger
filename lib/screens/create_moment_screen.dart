import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/media_service.dart';

class CreateMomentScreen extends StatefulWidget {
  final String currentUserId; // Should come from auth state

  const CreateMomentScreen({super.key, required this.currentUserId});

  @override
  State<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends State<CreateMomentScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedMedia;
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;

  Future<void> _pickMedia() async {
    // Show a dialog to choose between camera or gallery
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar Mídia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedMedia = File(pickedFile.path);
        });
      }
    }
  }

  Future<void> _uploadMoment() async {
    if (_selectedMedia == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // 1. Upload the media to Cloudflare R2 via our MediaService
      final publicUrl = await MediaService.uploadMediaDirectlyToR2(_selectedMedia!);

      if (publicUrl != null) {
        // 2. If upload was successful, save the moment in the backend DB
        final success = await MediaService.createMoment(
          widget.currentUserId,
          publicUrl,
          _captionController.text.isNotEmpty ? _captionController.text : null,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Moment publicado com sucesso!')),
          );
          Navigator.pop(context); // Go back to the feed
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao salvar Moment no banco de dados.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao fazer upload da mídia.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Novo Moment', style: TextStyle(color: Colors.white)),
        actions: [
          if (_selectedMedia != null && !_isUploading)
            TextButton(
              onPressed: _uploadMoment,
              child: const Text('Publicar', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: _selectedMedia != null
                      ? Image.file(_selectedMedia!, fit: BoxFit.contain)
                      : GestureDetector(
                          onTap: _pickMedia,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo, size: 80, color: Colors.white54),
                              SizedBox(height: 16),
                              Text('Toque para adicionar foto ou vídeo', style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                ),
              ),
              if (_selectedMedia != null)
                Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Adicionar legenda...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
              ),
            ),
        ],
      ),
    );
  }
}
