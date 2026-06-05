import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isDecoding = false;
  bool _isConnecting = false;
  String _myFriendCode = '';
  String _myUsername = '';

  @override
  void initState() {
    super.initState();
    _loadMyDetails();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMyDetails() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _myFriendCode = data['friend_code'] as String? ?? '';
          _myUsername = data['username'] as String? ?? 'Uživatel';
        });
      }
    } catch (_) {}
  }

  Future<void> _shareQrCode() async {
    if (_myFriendCode.isEmpty) return;
    try {
      final qrPainter = QrPainter(
        data: _myFriendCode,
        version: QrVersions.auto,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: false,
        errorCorrectionLevel: QrErrorCorrectLevel.Q,
      );

      // Create a canvas to draw the QR code with a solid white background and padding (quiet zone)
      const double qrSize = 512.0;
      const double padding = 64.0;
      const double canvasSize = qrSize + (padding * 2);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasSize, canvasSize));
      
      // 1. Draw solid white background
      final paint = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawRect(const Rect.fromLTWH(0, 0, canvasSize, canvasSize), paint);
      
      // 2. Draw the QR code centered
      canvas.save();
      canvas.translate(padding, padding);
      qrPainter.paint(canvas, const Size(qrSize, qrSize));
      canvas.restore();

      final picture = recorder.endRecording();
      final img = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_friend_code.png').create();
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Přidej si mě v aplikaci Hejbej se! Můj kód přítele je $_myFriendCode',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při sdílení QR: $e')),
        );
      }
    }
  }

  Future<void> _pickAndDecodeQr() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image == null) return;

    setState(() {
      _isDecoding = true;
    });

    try {
      final controller = MobileScannerController();
      final barcodeCapture = await controller.analyzeImage(image.path);

      if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
        final code = barcodeCapture.barcodes.first.rawValue?.trim() ?? '';
        if (code.isNotEmpty) {
          _codeController.text = code;
          _connectFriend(code);
        } else {
          throw Exception('QR kód v obrázku je prázdný.');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('V obrázku nebyl nalezen žádný QR kód')),
          );
        }
      }
      await controller.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při načítání QR z galerie: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDecoding = false;
        });
      }
    }
  }

  String _cleanStringForSearch(String input) {
    var str = input.toLowerCase().trim();
    const diacritics = {
      'á': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e', 'í': 'i', 'ň': 'n', 
      'ó': 'o', 'ř': 'r', 'š': 's', 'ť': 't', 'ú': 'u', 'ů': 'u', 'ý': 'y', 'ž': 'z'
    };
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      buffer.write(diacritics[char] ?? char);
    }
    return buffer.toString().replaceAll('#', '');
  }

  Future<void> _connectFriend(String code) async {
    String searchCode = code.trim();
    if (searchCode.isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      // 1. Get current user's profile
      final myDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final myData = myDoc.data() ?? {};
      final currentFriendCode = myData['friend_code'] as String?;
      final currentUsername = myData['username'] as String?;

      String targetCode = searchCode.toUpperCase();
      if (!targetCode.startsWith('#')) {
        targetCode = '#$targetCode';
      }

      if (currentFriendCode == targetCode || currentUsername?.toLowerCase() == searchCode.toLowerCase()) {
        throw Exception('Nemůžeš přidat sám sebe.');
      }

      // 2. Query target user document by clean fields
      final cleanInput = _cleanStringForSearch(searchCode);
      QuerySnapshot query = await _firestore
          .collection('users')
          .where('friend_code_clean', isEqualTo: cleanInput)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await _firestore
            .collection('users')
            .where('username_clean', isEqualTo: cleanInput)
            .limit(1)
            .get();
      }

      // Backward compatibility fallbacks if clean fields are not populated
      if (query.docs.isEmpty) {
        query = await _firestore
            .collection('users')
            .where('friend_code', isEqualTo: targetCode)
            .limit(1)
            .get();
      }

      // If not found, try querying by exact username
      if (query.docs.isEmpty) {
        query = await _firestore
            .collection('users')
            .where('username', isEqualTo: searchCode)
            .limit(1)
            .get();
      }

      // If not found, try querying by lowercase username
      if (query.docs.isEmpty) {
        query = await _firestore
            .collection('users')
            .where('username', isEqualTo: searchCode.toLowerCase())
            .limit(1)
            .get();
      }

      // If not found, try querying by uppercase username
      if (query.docs.isEmpty) {
        query = await _firestore
            .collection('users')
            .where('username', isEqualTo: searchCode.toUpperCase())
            .limit(1)
            .get();
      }

      // If not found, try querying by capitalized username (e.g. Pepa)
      if (query.docs.isEmpty && searchCode.isNotEmpty) {
        final capitalized = searchCode[0].toUpperCase() + searchCode.substring(1).toLowerCase();
        query = await _firestore
            .collection('users')
            .where('username', isEqualTo: capitalized)
            .limit(1)
            .get();
      }

      if (query.docs.isEmpty) {
        throw Exception('Uživatel s tímto kódem nebo přezdívkou nebyl nalezen.');
      }

      final targetDoc = query.docs.first;
      final targetUid = targetDoc.id;
      final targetData = targetDoc.data() as Map<String, dynamic>;
      final targetUsername = targetData['username'] ?? 'Uživatel';
      final resolvedTargetCode = targetData['friend_code'] as String? ?? targetCode;

      // 3. Create bidirectional 'friends' relationship instantly
      final batch = _firestore.batch();

      final myFriendRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(targetUid);

      batch.set(myFriendRef, {
        'uid': targetUid,
        'username': targetUsername,
        'friend_code': resolvedTargetCode,
        'status': 'friends',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final targetFriendRef = _firestore
          .collection('users')
          .doc(targetUid)
          .collection('friends')
          .doc(currentUser.uid);

      batch.set(targetFriendRef, {
        'uid': currentUser.uid,
        'username': myData['username'] ?? 'Uživatel',
        'friend_code': currentFriendCode ?? '',
        'status': 'friends',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Log friend connection to activity feed
      try {
        await _firestore.collection('activities').add({
          'uid': currentUser.uid,
          'username': myData['username'] ?? 'Uživatel',
          'type': 'friend_added',
          'timestamp': FieldValue.serverTimestamp(),
          'details': {
            'friendName': targetUsername,
            'friendUid': targetUid,
          },
        });
      } catch (_) {}

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🎉 Přítel přidán!'),
          content: Text('Nyní jste propojeni s uživatelem $targetUsername.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // pop dialog
                Navigator.pop(context); // pop screen
              },
              child: const Text('Super!'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nepodařilo se připojit přítele: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PŘIDAT PŘÁTELE'),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // QR Code Section
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
                shadowColor: Colors.lightBlue.shade100,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text(
                        'Můj QR kód',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      if (_myFriendCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.lightBlue.shade50, width: 2),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                          ),
                          child: QrImageView(
                            data: _myFriendCode,
                            version: QrVersions.auto,
                            size: 180.0,
                            gapless: true,
                          ),
                        )
                      else
                        const SizedBox(
                          height: 180,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Přezdívka: $_myUsername',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _myFriendCode,
                        style: TextStyle(color: Colors.lightBlue.shade700, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _myFriendCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Kód zkopírován do schránky')),
                                );
                              },
                              icon: const Icon(Icons.copy),
                              label: const Text('Kopírovat kód'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.lightBlue),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _shareQrCode,
                              icon: const Icon(Icons.share),
                              label: const Text('Sdílet QR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lime,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Connect Friends Section
              const Text(
                'Propojit se s kamarádem',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: _isDecoding ? null : _pickAndDecodeQr,
                icon: _isDecoding
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.photo_library),
                label: Text(_isDecoding ? 'Načítání QR kódu...' : 'Nahrát QR kód z galerie'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue.shade50,
                  foregroundColor: Colors.lightBlue.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),

              const SizedBox(height: 16),
              const Center(child: Text('nebo zadej kód ručně', style: TextStyle(color: Colors.black54, fontSize: 13))),
              const SizedBox(height: 16),

              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Kód kamaráda (např. #PEPA456)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _codeController.text = data!.text!.trim();
                      }
                    },
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isConnecting ? null : () => _connectFriend(_codeController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lime,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isConnecting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Propojit se', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
