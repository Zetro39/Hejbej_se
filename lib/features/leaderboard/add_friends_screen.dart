import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_dart_decoder/qr_code_dart_decoder.dart';
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
        emptyColor: const ui.Color(0xFFFFFFFF),
        gapless: true,
      );

      final image = await qrPainter.toImage(300);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _isDecoding = true;
    });

    try {
      final bytes = await image.readAsBytes();
      final decoder = QrCodeDartDecoder(formats: [BarcodeFormat.qrCode]);
      final result = await decoder.decodeFile(bytes);

      if (result != null && result.text.isNotEmpty) {
        final code = result.text.trim();
        _codeController.text = code;
        _connectFriend(code);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('V obrázku nebyl nalezen žádný QR kód')),
          );
        }
      }
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

  Future<void> _connectFriend(String code) async {
    final targetCode = code.trim().toUpperCase();
    if (targetCode.isEmpty) return;

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

      if (currentFriendCode == targetCode) {
        throw Exception('Nemůžeš přidat sám sebe.');
      }

      // 2. Query target user document by friend_code
      final query = await _firestore
          .collection('users')
          .where('friend_code', isEqualTo: targetCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Uživatel s tímto kódem nebyl nalezen.');
      }

      final targetDoc = query.docs.first;
      final targetUid = targetDoc.id;
      final targetData = targetDoc.data();
      final targetUsername = targetData['username'] ?? 'Uživatel';

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
        'friend_code': targetCode,
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
