import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationDisclosureDialog extends StatelessWidget {
  const LocationDisclosureDialog({super.key});

  /// Check if the disclosure has already been accepted, and if not, show the dialog.
  /// Returns [true] if the user accepted (or had already accepted), and [false] otherwise.
  static Future<bool> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('has_accepted_location_disclosure') ?? false;
    
    if (accepted) {
      return true;
    }

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must explicitly tap a button
      builder: (context) => const LocationDisclosureDialog(),
    );

    if (result == true) {
      await prefs.setBool('has_accepted_location_disclosure', true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Aesthetic premium styling matching the main app theme (Lime and Blue)
    const primaryColor = Color(0xFF1B5E20); // Deep forest green / dark text
    const limeAccent = Color(0xFFBFFF00);
    final cardBgColor = isDark ? const Color(0xFF1E272C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF263238);
    final textSubColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      backgroundColor: cardBgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header banner with gradient and location icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0288D1), // Light blue
                      Color(0xFF03A9F4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sledování polohy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content body
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hejbej se je aplikace zaměřená na chůzi, plnění outdoorových cílů a objevování tras. Pro správnou funkčnost vyžaduje přístup k poloze vašeho zařízení.',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Účel využití dat o poloze:',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Bullet points
                    _buildFeatureItem(
                      icon: Icons.map_rounded,
                      title: 'Záznam a zobrazení tras',
                      description: 'Kreslení vašich ušlých tras na mapě pro přehled o aktivitě.',
                      textColor: textColor,
                      subColor: textSubColor,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.directions_walk_rounded,
                      title: 'Výpočet vzdálenosti a kroků',
                      description: 'Přesný výpočet denní ušlé vzdálenosti a postupu v herních výzvách.',
                      textColor: textColor,
                      subColor: textSubColor,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.verified_user_rounded,
                      title: 'Ochrana proti podvádění (Anti-Cheat)',
                      description: 'Ověření fyzické aktivity (např. eliminace jízd autem), abychom zajistili férovou hru.',
                      textColor: textColor,
                      subColor: textSubColor,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Background disclosure warning box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade200, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sledování na pozadí',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tato data o poloze jsou sbírána i tehdy, když je aplikace zavřená nebo se nepoužívá (na pozadí). To je nezbytné pro nepřetržité zaznamenávání vaší trasy, i když máte telefon v kapse.',
                                  style: TextStyle(
                                    color: Colors.amber.shade900.withOpacity(0.95),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    Text(
                      'Slibujeme, že vaše data o poloze jsou u nás v bezpečí, nikde je neprodáváme ani nesdílíme s třetími stranami.',
                      style: TextStyle(
                        color: textSubColor,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Divider
              Divider(height: 1, color: Colors.grey.shade200),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Odmítnout',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: limeAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Souhlasím',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color textColor,
    required Color subColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0288D1), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: subColor,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
