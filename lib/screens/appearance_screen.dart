import 'package:flutter/material.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _isDarkMode = false;
  Color _selectedAccent = const Color(0xFF7C3AED);

  final List<Color> _accentColors = [
    const Color(0xFF7C3AED), // Purple
    const Color(0xFF10B981), // Emerald
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFEF4444), // Red
    const Color(0xFFF59E0B), // Amber
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aparência'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('TEMA', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Modo Escuro'),
            subtitle: const Text('Reduz o cansaço visual à noite'),
            value: _isDarkMode,
            onChanged: (val) => setState(() => _isDarkMode = val),
            secondary: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode),
          ),
          const SizedBox(height: 24),
          const Text('COR DE DESTAQUE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _accentColors.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final color = _accentColors[index];
                final isSelected = color == _selectedAccent;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAccent = color),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          const Text('PREVIEW', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: _selectedAccent, foregroundColor: Colors.white),
                  child: const Text('Botão Exemplo'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este é um exemplo de como o Arroba ficará com as suas cores.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
