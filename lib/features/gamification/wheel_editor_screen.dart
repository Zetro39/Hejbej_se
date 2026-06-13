import 'dart:math';
import 'package:flutter/material.dart';
import 'models/wheel_of_fortune_model.dart';
import 'services/wheel_of_fortune_service.dart';
import '../../main_shell.dart';

class WheelEditorScreen extends StatefulWidget {
  final WheelOfFortune? wheelToEdit;

  const WheelEditorScreen({super.key, this.wheelToEdit});

  @override
  State<WheelEditorScreen> createState() => _WheelEditorScreenState();
}

class _WheelEditorScreenState extends State<WheelEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<WheelTask> _tasks = [];

  // Available icon categories for dropdown
  final List<Map<String, String>> _availableIcons = [
    {'code': 'luck', 'label': '🍀 Šťastná karta (Free Pass)'},
    {'code': 'backpack', 'label': '🎒 Nosič batohů'},
    {'code': 'silent', 'label': '🤫 Tichý bobřík'},
    {'code': 'backward', 'label': '🔙 Chůze pozpátku'},
    {'code': 'hop', 'label': '🦘 Skákání po jedné'},
    {'code': 'knight', 'label': '⚔️ Král rytířů (Středověká řeč)'},
    {'code': 'squat', 'label': '🏋️ Dřepování'},
    {'code': 'whisper', 'label': '👂 Šeptání'},
    {'code': 'airplane', 'label': '✈️ Letadlo (Rozpažené paže)'},
    {'code': 'friends', 'label': '👥 Pospolu (Chůze u sebe)'},
    {'code': 'mic', 'label': '🎙️ Sportovní komentátor'},
    {'code': 'poem', 'label': '✍️ Básník / Mluva v rýmech'},
    {'code': 'stick', 'label': '🥖 Posvátné žezlo (Nést klacek)'},
    {'code': 'animal', 'label': '🐾 Zoolog (Hádání zvířat)'},
    {'code': 'lock', 'label': '🔒 Ruce za zády'},
    {'code': 'spy', 'label': '🕵️ Tajný agent (Krytí)'},
    {'code': 'stone', 'label': '🪨 Strážce kamene'},
    {'code': 'leaf', 'label': '🌿 Listový poklad'},
    {'code': 'robot', 'label': '🤖 Mluva jako robot'},
    {'code': 'music', 'label': '🎵 Písničkář (Zpěv)'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.wheelToEdit != null) {
      _nameController.text = widget.wheelToEdit!.name;
      _tasks.addAll(widget.wheelToEdit!.tasks);
    } else {
      // Add 3 default empty tasks to start with
      _addTask();
      _addTask();
      _addTask();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addTask() {
    setState(() {
      _tasks.add(WheelTask(
        id: 'task_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}',
        title: '',
        icon: 'backpack',
        description: '',
        exceptions: 'Žádné',
      ));
    });
  }

  void _removeTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  Future<void> _saveWheel() async {
    if (!_formKey.currentState!.validate()) return;

    if (_tasks.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kolo štěstí musí obsahovat alespoň 3 úkoly.')),
      );
      return;
    }

    final newWheel = WheelOfFortune(
      id: widget.wheelToEdit?.id ?? 'wheel_${DateTime.now().millisecondsSinceEpoch}',
      code: widget.wheelToEdit?.code ?? '',
      name: _nameController.text.trim(),
      tasks: _tasks,
      isCustom: true,
      creatorName: widget.wheelToEdit?.creatorName ?? 'Hráč',
      creatorUid: widget.wheelToEdit?.creatorUid ?? '',
      likes: widget.wheelToEdit?.likes ?? 0,
    );

    try {
      await WheelOfFortuneService().saveCustomWheel(newWheel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kolo štěstí bylo úspěšně uloženo!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uložení selhalo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: MainShell.themeNotifier,
      builder: (context, theme, child) {
        final isWhite = theme == 'white';
        final bgColor = isWhite ? const Color(0xFFF9FBFC) : const Color(0xFF263238);
        final cardColor = isWhite ? Colors.white : const Color(0xFF1E272C);
        final textColor = isWhite ? const Color(0xFF263238) : Colors.white;
        final textSecondary = isWhite ? Colors.black54 : Colors.white70;
        final borderColor = isWhite ? Colors.grey.shade300 : Colors.white12;
        final appBarBg = isWhite ? Colors.white : const Color(0xFF1E272C);
        final appBarFg = isWhite ? const Color(0xFF263238) : Colors.white;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              widget.wheelToEdit == null ? 'Vytvořit Kolo štěstí' : 'Upravit Kolo štěstí',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: appBarFg),
            ),
            backgroundColor: appBarBg,
            foregroundColor: appBarFg,
            actions: [
              IconButton(
                onPressed: _saveWheel,
                icon: const Icon(Icons.check_rounded, size: 28, color: Color(0xFFBFFF00)),
                tooltip: 'Uložit',
              ),
            ],
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Wheel Name Field
                  Container(
                    color: cardColor,
                    padding: const EdgeInsets.all(16.0),
                    child: TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Název Kola štěstí',
                        labelStyle: TextStyle(color: textSecondary),
                        hintText: 'Např. Bláznivá výprava',
                        hintStyle: TextStyle(color: textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF5C9E00), width: 2),
                        ),
                        prefixIcon: Icon(Icons.casino_outlined, color: textSecondary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Zadejte název Kola štěstí.';
                        }
                        return null;
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'SEZNAM ÚKOLŮ KOLA',
                      style: TextStyle(fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 0.8, fontSize: 11),
                    ),
                  ),

                  // Tasks Editor List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Card(
                          color: cardColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: borderColor, width: 1.5),
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Úkol #${index + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF5C9E00), fontSize: 15),
                                    ),
                                    if (_tasks.length > 3)
                                      IconButton(
                                        onPressed: () => _removeTask(index),
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Task Title
                                TextFormField(
                                  initialValue: task.title,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Název úkolu',
                                    labelStyle: TextStyle(color: textSecondary),
                                    hintText: 'Např. Nosič batohů',
                                    hintStyle: TextStyle(color: textSecondary),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF5C9E00), width: 2),
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    _tasks[index] = WheelTask(
                                      id: task.id,
                                      title: val,
                                      icon: task.icon,
                                      description: task.description,
                                      exceptions: task.exceptions,
                                    );
                                  },
                                  validator: (val) => val == null || val.trim().isEmpty ? 'Vyplňte název úkolu.' : null,
                                ),
                                const SizedBox(height: 12),

                                // Icon Category Dropdown
                                DropdownButtonFormField<String>(
                                  value: task.icon,
                                  dropdownColor: cardColor,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Symbol / Ikona',
                                    labelStyle: TextStyle(color: textSecondary),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF5C9E00), width: 2),
                                    ),
                                    isDense: true,
                                  ),
                                  items: _availableIcons.map((i) {
                                    return DropdownMenuItem<String>(
                                      value: i['code'],
                                      child: Text(i['label']!, style: TextStyle(color: textColor)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _tasks[index] = WheelTask(
                                          id: task.id,
                                          title: task.title,
                                          icon: val,
                                          description: task.description,
                                          exceptions: task.exceptions,
                                        );
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Task Description
                                TextFormField(
                                  initialValue: task.description,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Popis úkolu / Pravidla',
                                    labelStyle: TextStyle(color: textSecondary),
                                    hintText: 'Popište co přesně musí hráč dělat',
                                    hintStyle: TextStyle(color: textSecondary),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF5C9E00), width: 2),
                                    ),
                                    isDense: true,
                                  ),
                                  maxLines: 2,
                                  onChanged: (val) {
                                    _tasks[index] = WheelTask(
                                      id: task.id,
                                      title: task.title,
                                      icon: task.icon,
                                      description: val,
                                      exceptions: task.exceptions,
                                    );
                                  },
                                  validator: (val) => val == null || val.trim().isEmpty ? 'Vyplňte popis úkolu.' : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Control Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addTask,
                            icon: Icon(Icons.add_rounded, color: textColor),
                            label: Text('PŘIDAT ÚKOL', style: TextStyle(color: textColor)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(color: textColor, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveWheel,
                            icon: const Icon(Icons.save_rounded, color: Colors.black),
                            label: const Text('ULOŽIT KOLO', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBFFF00),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      },
    );
  }
}
