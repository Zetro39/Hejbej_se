import 'package:flutter/material.dart';
import '../models/story_quest_model.dart';
import '../services/story_game_service.dart';
import 'logic_puzzles_screen.dart';

class PointAndClickScreen extends StatefulWidget {
  final String nodeId;

  const PointAndClickScreen({super.key, required this.nodeId});

  @override
  State<PointAndClickScreen> createState() => _PointAndClickScreenState();
}

class _PointAndClickScreenState extends State<PointAndClickScreen> {
  final StoryGameService _service = StoryGameService();
  String? _selectedItemId;
  bool _showHints = false;
  String _dialogText = "";
  String _currentSubroom = "exterior"; // Used for sub-rooms (interior vs exterior)

  // NPC Dialogue States
  String? _dialogueCharacterName;
  String? _dialogueCharacterAvatar;
  List<_DialogueOption> _dialogueOptions = [];

  @override
  void initState() {
    super.initState();
    _setInitialDialog();
  }

  void _setInitialDialog() {
    if (widget.nodeId == 'node1') {
      _dialogText = "Stojíš před mohutnou dřevěnou bránou vedoucí do hlubokého lesa. Je zamčená a klika chybí.";
    } else if (widget.nodeId == 'node2') {
      _dialogText = "Dorazil jsi k obrovskému dubu. Podle legendy je zde ukryt amulet strážců.";
    } else if (widget.nodeId == 'node3') {
      _dialogText = "V lese stojí stará chýše hajného. Vchod je zcela zarostlý trnitým křovím.";
    } else if (widget.nodeId == 'node4') {
      _dialogText = "Dorazil jsi k zamlžené tůni a staré studni. Pustevníkova jeskyně je opodál.";
    } else if (widget.nodeId == 'node5') {
      _dialogText = "Stojíš na nádvoří opuštěné kamenné pevnosti. Nahoře se tyčí astronomická věž.";
    } else if (widget.nodeId == 'node6') {
      _dialogText = "Na vrcholku skály stojí pradávný kamenný oltář. Vzduch je nabitý magickou energií.";
    }
  }

  void _showDialog(String text) {
    setState(() {
      _dialogText = text;
    });
  }

  void _showDialogueAnswer(String speakerText, List<_DialogueOption> backOptions) {
    setState(() {
      _dialogText = speakerText;
      _dialogueOptions = backOptions;
    });
  }

  void _endDialogue() {
    setState(() {
      _dialogueCharacterName = null;
      _dialogueCharacterAvatar = null;
      _dialogueOptions = [];
      _setInitialDialog();
    });
  }

  void _startPoustevnikDialogue(QuestState state) {
    final healed = state.roomStates['node4_hermit_healed'] == true;
    setState(() {
      _dialogueCharacterName = "Poustevník";
      _dialogueCharacterAvatar = "🧙‍♂️";
    });
    if (healed) {
      _showHealedPoustevnikDialogue(state);
    } else {
      _showSickPoustevnikDialogue(state);
    }
  }

  void _showHealedPoustevnikDialogue(QuestState state) {
    setState(() {
      _dialogText = "Poustevník: 'Děkuji ti ještě jednou, příteli. Cítím se skvěle. Hledáš něco v těchto končinách?'";
      _dialogueOptions = [
        _DialogueOption(
          text: "Co mám udělat s amuletem?",
          onTap: () {
            _showDialogueAnswer(
              "Poustevník: 'Amulet leží ve starém dubu (K2). Musíš ho odemknout trojúhelníkovým klíčem ze studny. Až ho získáš, přines ho k oltáři věčnosti (K6) a vlož tam i 4 elementy.'",
              [
                _DialogueOption(
                  text: "Díky, chci se zeptat na další věci.",
                  onTap: () => _showHealedPoustevnikDialogue(state),
                ),
                _DialogueOption(
                  text: "Rozumím (Odejít)",
                  onTap: _endDialogue,
                )
              ]
            );
          },
        ),
        _DialogueOption(
          text: "Jaké byly ty úhly pro dalekohled?",
          onTap: () {
            _showDialogueAnswer(
              "Poustevník: 'Pamatuj si dobře úhly souhvězdí: Medvěd má úhel 45°, Vlk má 120° a Jelen 275°. Nastav je na dalekohledu v pevnosti (K5).'",
              [
                _DialogueOption(
                  text: "Díky, chci se zeptat na další věci.",
                  onTap: () => _showHealedPoustevnikDialogue(state),
                ),
                _DialogueOption(
                  text: "Rozumím (Odejít)",
                  onTap: _endDialogue,
                )
              ]
            );
          },
        ),
        _DialogueOption(
          text: "Kde najdu 4 elementy?",
          onTap: () {
            _showDialogueAnswer(
              "Poustevník: 'Popel (Oheň) vezmi z ohniště u chýše lesníka (K3). Destilovanou vodu (Voda) získáš uvařením vody z bažin (K4). Prach (Vzduch) setři z regálu v knihovně pevnosti (K5). A sůl (Země) najdeš přímo ve skále u oltáře (K6).'",
              [
                _DialogueOption(
                  text: "Díky, chci se zeptat na další věci.",
                  onTap: () => _showHealedPoustevnikDialogue(state),
                ),
                _DialogueOption(
                  text: "Rozumím (Odejít)",
                  onTap: _endDialogue,
                )
              ]
            );
          },
        ),
        _DialogueOption(
          text: "Rozumím, jdu na to.",
          onTap: _endDialogue,
        ),
      ];
    });
  }

  void _showSickPoustevnikDialogue(QuestState state) {
    setState(() {
      _dialogText = "Poustevník silně blouzní na lůžku. Jeho kůže pálí a tichým hlasem šeptá nesrozumitelná slova.";
      _dialogueOptions = [];

      if (state.inventory.contains('potion')) {
        _dialogueOptions.add(_DialogueOption(
          text: "Podat léčivý elixír 🍵",
          onTap: () {
            _service.removeItem('potion');
            _service.updateRoomState('node4_hermit_healed', true);
            _service.collectItem('well_handle');
            setState(() {
              _selectedItemId = null;
            });
            final updatedState = _service.stateNotifier.value;
            _showDialogueAnswer(
              "Poustevník: 'Ahhh... ten chladivý elixír! Moje horečka ustupuje... zachránil jsi mě, poutníku! Vezmi si tuto kliku k navijáku studny venku, pomůže ti vytáhnout starý klíč ze dna. A pamatuj si úhly dalekohledu: Medvěd 45°, Vlk 120°, Jelen 275°.'",
              [
                _DialogueOption(
                  text: "Děkuji. Chci se zeptat na další věci.",
                  onTap: () => _showHealedPoustevnikDialogue(updatedState),
                ),
                _DialogueOption(
                  text: "Díky, jdu dál.",
                  onTap: _endDialogue,
                )
              ]
            );
          },
        ));
      }

      _dialogueOptions.add(_DialogueOption(
        text: "Jak tě mohu vyléčit?",
        onTap: () {
          _showDialogueAnswer(
            "Poustevník: 'Potřebuji léčivý elixír... Modré bažinné houby... a čistou destilovanou vodu. Bez nich ta horečka neustoupí...'",
            [
              _DialogueOption(
                text: "Kde najdu ingredience?",
                onTap: () {
                  _showDialogueAnswer(
                    "Poustevník: 'Houby rostou ve svatyni v bažinách (tam vpravo). Svatyně je chráněna posvátnými vahami. Čistou vodu získáš destilací otrávené vody z bažin nad ohništěm u chýše lesníka. Kotlík a trubku najdeš tady u mě v jeskyni.'",
                    [
                      _DialogueOption(
                        text: "Rozumím (Zpět)",
                        onTap: () => _showSickPoustevnikDialogue(state),
                      )
                    ]
                  );
                }
              ),
              _DialogueOption(
                text: "Pokusím se (Zpět)",
                onTap: () => _showSickPoustevnikDialogue(state),
              )
            ]
          );
        },
      ));

      _dialogueOptions.add(_DialogueOption(
        text: "Odejít",
        onTap: _endDialogue,
      ));
    });
  }

  void _startHvezdopravecDialogue(QuestState state) {
    setState(() {
      _dialogueCharacterName = "Hvězdopravec";
      _dialogueCharacterAvatar = "👴";
    });

    final solved = state.roomStates['node5_puzzle_solved'] == true;
    if (solved) {
      _showSolvedHvezdopravecDialogue(state);
    } else {
      _showUnsolvedHvezdopravecDialogue(state);
    }
  }

  void _showSolvedHvezdopravecDialogue(QuestState state) {
    setState(() {
      _dialogText = "Hvězdopravec: 'Díky tvému seřízení dalekohledu se cesta otevřela! Hvězdné světlo ukázalo na horský průsmyk.'";
      _dialogueOptions = [
        _DialogueOption(
          text: "Jak najdu ty elementy pro oltář?",
          onTap: () {
            _showDialogueAnswer(
              "Hvězdopravec: 'Musíš shromáždit čtyři elementy: Popel (Oheň) z ohniště v lese, vodu (Voda) z bažin, prach (Vzduch) z knihovny za mnou a sůl (Země) přímo ve skalách u oltáře. Vlož je do amuletu a pak na oltář.'",
              [
                _DialogueOption(
                  text: "Díky (Zpět)",
                  onTap: () => _showSolvedHvezdopravecDialogue(state),
                )
              ]
            );
          },
        ),
        _DialogueOption(
          text: "Hodně štěstí při pozorování.",
          onTap: _endDialogue,
        ),
      ];
    });
  }

  void _showUnsolvedHvezdopravecDialogue(QuestState state) {
    setState(() {
      _dialogText = "Hvězdopravec: 'Ach, mé staré oči už neslouží a navíc mi chybí čočka dalekohledu! Dával jsem ji někam k rytířské soše venku na nádvoří, ale ta se otočila a schovala ji. Pomůžeš mi ji najít a dalekohled seřídit?'";
      _dialogueOptions = [];

      final lensPlaced = state.roomStates['node5_lens_placed'] == true;
      if (!lensPlaced && state.inventory.contains('clean_lens')) {
        _dialogueOptions.add(_DialogueOption(
          text: "Předat vyčištěnou čočku 🔍",
          onTap: () {
            _service.removeItem('clean_lens');
            _service.updateRoomState('node5_lens_placed', true);
            setState(() {
              _selectedItemId = null;
            });
            final updatedState = _service.stateNotifier.value;
            _showDialogueAnswer(
              "Hvězdopravec: 'Úžasné! Čočka pasuje dokonale. Nyní musíme dalekohled otočit na souhvězdí Medvěda, Vlka a Jelena. Znáš jejich úhly? Poustevník z bažin by ti je mohl prozradit.'",
              [
                _DialogueOption(
                  text: "Jaké úhly mám nastavit?",
                  onTap: () {
                    _showDialogueAnswer(
                      "Hvězdopravec: 'Pokud ti je poustevník neřekl, budeš se muset vrátit do jeho jeskyně v bažinách (K4). Jakmile je budeš vědět, klikni na dalekohled a zadej je.'",
                      [
                        _DialogueOption(
                          text: "Rozumím (Zpět)",
                          onTap: () => _showUnsolvedHvezdopravecDialogue(updatedState),
                        )
                      ]
                    );
                  },
                ),
                _DialogueOption(
                  text: "Půjdu se podívat (Ukončit)",
                  onTap: _endDialogue,
                )
              ]
            );
          },
        ));
      }

      if (!lensPlaced) {
        _dialogueOptions.add(_DialogueOption(
          text: "Jak otočím tu rytířskou sochu?",
          onTap: () {
            _showDialogueAnswer(
              "Hvězdopravec: 'Socha rytíře na nádvoří reaguje na vložení kamenného meče. Ten je zamčený ve staré zbrojnici venku na nádvoří.'",
              [
                _DialogueOption(
                  text: "Kde je klíč od zbrojnice?",
                  onTap: () {
                    _showDialogueAnswer(
                      "Hvězdopravec: 'Klíč od zbrojnice jsem schoval v této knihovně za knihy na polici. Abys ho získal, musíš ty knihy na polici seřadit abecedně od A do Z.'",
                      [
                        _DialogueOption(
                          text: "Rozumím (Zpět)",
                          onTap: () => _showUnsolvedHvezdopravecDialogue(state),
                        )
                      ]
                    );
                  },
                ),
                _DialogueOption(
                  text: "A co kyselina na pryskyřici?",
                  onTap: () {
                    _showDialogueAnswer(
                      "Hvězdopravec: 'Až otevřeš zbrojnici, najdeš tam kamenný meč i lahvičku s kyselinou. Ta kyselina rozpustí pryskyřici, ve které je čočka uvízlá.'",
                      [
                        _DialogueOption(
                          text: "Rozumím (Zpět)",
                          onTap: () => _showUnsolvedHvezdopravecDialogue(state),
                        )
                      ]
                    );
                  },
                ),
                _DialogueOption(
                  text: "Děkuji (Zpět)",
                  onTap: () => _showUnsolvedHvezdopravecDialogue(state),
                ),
              ]
            );
          },
        ));
      } else {
        _dialogueOptions.add(_DialogueOption(
          text: "Jaké úhly mám nastavit?",
          onTap: () {
            _showDialogueAnswer(
              "Hvězdopravec: 'Musíme dalekohled natočit na tři souhvězdí: Medvěda, Vlka a Jelena. Pokud neznáš úhly, zajdi za poustevníkem v jeskyni (K4).'",
              [
                _DialogueOption(
                  text: "Rozumím (Zpět)",
                  onTap: () => _showUnsolvedHvezdopravecDialogue(state),
                )
              ]
            );
          },
        ));
      }

      _dialogueOptions.add(_DialogueOption(
        text: "Odejít",
        onTap: _endDialogue,
      ));
    });
  }

  // Get active hotspots for current room
  List<_Hotspot> _getHotspots(QuestState state) {
    final list = <_Hotspot>[];

    if (widget.nodeId == 'node1') {
      // Lesní brána
      // Gate hotspot
      list.add(_Hotspot(
        name: "Lesní brána",
        x: 0.35, y: 0.25, w: 0.3, h: 0.45,
        onTap: () {
          final isGateOpen = state.roomStates['node1_gate_open'] == true;
          if (isGateOpen) {
            _showDialog("Brána je dokořán. Cesta do nitra lesa je volná!");
            return;
          }

          if (_selectedItemId == 'fixed_key') {
            _service.updateRoomState('node1_gate_open', true);
            _service.removeItem('fixed_key');
            _service.completeNode('node1');
            setState(() => _selectedItemId = null);
            _showDialog("💥 Použil jsi upravený klíč! Zámek s hlasitým cvaknutím povolil a brána se pomalu otevírá.");
          } else if (_selectedItemId == 'dirty_key') {
            _showDialog("Klíč pasuje do dírky, ale je příliš rezavý a drhne. Nemůžeš s ním otočit, hrozí, že ho zlomíš.");
          } else if (_selectedItemId != null) {
            _showDialog("Tento předmět na bránu nepasuje.");
          } else {
            _showDialog("Masivní brána z dubového dřeva. Zámek je zrezivělý a chybí klika.");
          }
        },
      ));

      // Handle in grass
      final hasHandle = state.roomStates['node1_has_handle'] == true;
      if (!hasHandle) {
        list.add(_Hotspot(
          name: "Klika v trávě",
          x: 0.15, y: 0.75, w: 0.15, h: 0.12,
          onTap: () {
            _service.updateRoomState('node1_has_handle', true);
            _service.collectItem('iron_handle');
            _showDialog("V trávě pod kamenným pilířem jsi našel těžkou kovanou kliku. Beru ji.");
          },
        ));
      }
    } else if (widget.nodeId == 'node2') {
      // Starý dub
      // Hollow/Chest
      final chestOpen = state.roomStates['node2_chest_open'] == true;
      list.add(_Hotspot(
        name: "Dutina u kořenů",
        x: 0.42, y: 0.68, w: 0.18, h: 0.15,
        onTap: () {
          if (chestOpen) {
            final hasAmulet = state.roomStates['node2_has_amulet'] == true;
            if (!hasAmulet) {
              _service.updateRoomState('node2_has_amulet', true);
              _service.collectItem('amulet');
              _showDialog("Vzal jsi ze schránky vyhaslý kovový amulet.");
            } else {
              _showDialog("Schránka je prázdná.");
            }
            return;
          }

          if (_selectedItemId == 'triangular_key') {
            _service.updateRoomState('node2_chest_open', true);
            _service.removeItem('triangular_key');
            setState(() => _selectedItemId = null);
            _showDialog("🔑 Odemkl jsi schránku starým trojúhelníkovým klíčem! Uvnitř leží vyhaslý kovový amulet.");
          } else if (_selectedItemId != null) {
            _showDialog("Tímto schránku neotevřeš.");
          } else {
            _showDialog("V dutině dubu je ukrytá dřevěná schránka chráněná trojúhelníkovým zámkem.");
          }
        },
      ));
    } else if (widget.nodeId == 'node3') {
      // Zřícenina chýše
      if (_currentSubroom == "exterior") {
        final vinesBurned = state.roomStates['node3_vines_burned'] == true;

        // Vines / Door
        list.add(_Hotspot(
          name: vinesBurned ? "Vchod do chýše" : "Trnité křoví",
          x: 0.38, y: 0.32, w: 0.22, h: 0.42,
          onTap: () {
            if (vinesBurned) {
              setState(() {
                _currentSubroom = "interior";
                _dialogText = "Vstoupil jsi do chýše hajného. Vzduch je zatuchlý a na zemi se povalují staré věci.";
              });
              return;
            }

            if (_selectedItemId == 'smoldering_tinder') {
              _service.updateRoomState('node3_vines_burned', true);
              _service.removeItem('smoldering_tinder');
              setState(() => _selectedItemId = null);
              _showDialog("🔥 Přiložil jsi doutnající troud k suchému listí u paty křoví. Oheň se bleskově rozběhl po větvích a spálil trny na uhel! Vchod je volný.");
            } else if (_selectedItemId != null) {
              _showDialog("Tento předmět ti s odklizením křoví nepomůže.");
            } else {
              _showDialog("Dveře chýše jsou kompletně zarostlé tlustými ostnatými šlahouny. Holýma rukama neprojdou.");
            }
          },
        ));

        // Stone table
        final hasLens = state.roomStates['node3_has_lens'] == true;
        if (!hasLens) {
          list.add(_Hotspot(
            name: "Kamenný stůl",
            x: 0.72, y: 0.65, w: 0.18, h: 0.18,
            onTap: () {
              _service.updateRoomState('node3_has_lens', true);
              _service.collectItem('lens');
              _showDialog("Na rozpadlém stole leží poškrábaná prasklá lupa. Mohla by se hodit k zažehnutí slunce.");
            },
          ));
        }

        // Tree Stump
        final hasMoss = state.roomStates['node3_has_moss'] == true;
        if (!hasMoss) {
          list.add(_Hotspot(
            name: "Pařez",
            x: 0.08, y: 0.72, w: 0.18, h: 0.18,
            onTap: () {
              _service.updateRoomState('node3_has_moss', true);
              _service.collectItem('tinder');
              _showDialog("Na pařezu roste hustý mech. Je úplně vysušený od slunce, ideální jako troud.");
            },
          ));
        }

        // Crafting fire using Lens and Moss
        if (_selectedItemId == 'lens' && !state.inventory.contains('smoldering_tinder') && state.inventory.contains('tinder')) {
          list.add(_Hotspot(
            name: "Sluneční svit",
            x: 0.4, y: 0.05, w: 0.2, h: 0.2,
            onTap: () {
              _service.removeItem('lens');
              _service.removeItem('tinder');
              _service.collectItem('smoldering_tinder');
              setState(() => _selectedItemId = null);
              _showDialog("☀️ Soustředil jsi paprsky přes čočku lupy na suchý mech. Po chvíli se z něj začal linout dým a mech začal doutnat. Máš žhavý troud!");
            },
          ));
        }
      } else {
        // Interior of Forester's Cabin
        // Shelf / Jar
        final hasKey = state.roomStates['node3_has_key'] == true;
        list.add(_Hotspot(
          name: "Police se džbánem",
          x: 0.12, y: 0.35, w: 0.15, h: 0.2,
          onTap: () {
            if (!hasKey) {
              _service.updateRoomState('node3_has_key', true);
              _service.collectItem('dirty_key');
              _showDialog("Pod převráceným hliněným džbánem na polici ležel zrezivělý klíč.");
            } else {
              _showDialog("Police je prázdná.");
            }
          },
        ));

        // Diary
        list.add(_Hotspot(
          name: "Starý sešit",
          x: 0.42, y: 0.58, w: 0.15, h: 0.12,
          onTap: () {
            _showDialog("Čteš z Deníku hajného:\n'Zámek lesní brány je hrozně rezavý a drhne. Bez promazání olejem se zlomí klíč. Truhlu s olejem jsem schoval v chýši a zašifroval kódem, který se rovná počtu větví na kresbě dubu (kód je 472).'");
          },
        ));

        // Iron Chest
        final chestOpened = state.roomStates['node3_chest_opened'] == true;
        list.add(_Hotspot(
          name: "Železná truhla",
          x: 0.72, y: 0.62, w: 0.18, h: 0.18,
          onTap: () {
            if (chestOpened) {
              _showDialog("Truhla je prázdná, olej jsi již vzal.");
              return;
            }

            // Open lock screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LogicPuzzlesScreen(
                  puzzleType: "combination_lock",
                  correctCode: "472",
                  onSolved: () {
                    _service.updateRoomState('node3_chest_opened', true);
                    _service.collectItem('oil');
                    _showDialog("🎉 Truhla cvakla a otevřela se! Uvnitř leží lahvička s olejem na rez.");
                  },
                ),
              ),
            );
          },
        ));

        // Grinding and oiling key on workbench
        if (state.inventory.contains('dirty_key') && state.inventory.contains('oil')) {
          list.add(_Hotspot(
            name: "Pracovní stůl (Pilník)",
            x: 0.28, y: 0.6, w: 0.22, h: 0.22,
            onTap: () {
              _service.removeItem('dirty_key');
              _service.removeItem('oil');
              _service.collectItem('fixed_key');
              _showDialog("🔧 Nanesl jsi olej na rezavý klíč a pomocí starého pilníku na stole jsi ho pečlivě obrousil. Získal jsi čistý, funkční klíč od brány!");
            },
          ));
        }

        // Return to exterior button
        list.add(_Hotspot(
          name: "Vchod ven",
          x: 0.45, y: 0.82, w: 0.15, h: 0.12,
          onTap: () {
            setState(() {
              _currentSubroom = "exterior";
              _dialogText = "Stojíš venku před chýší.";
            });
          },
        ));
      }
    } else if (widget.nodeId == 'node4') {
      // Bažina & Studna
      if (_currentSubroom == "exterior") {
        // Hermit cave entrance
        list.add(_Hotspot(
          name: "Poustevníkova jeskyně",
          x: 0.12, y: 0.32, w: 0.22, h: 0.42,
          onTap: () {
            setState(() {
              _currentSubroom = "cave";
              _dialogText = state.roomStates['node4_hermit_healed'] == true
                  ? "Poustevník sedí v jeskyni u malého ohýnku a usmívá se."
                  : "Uvnitř temné jeskyně leží na slaměném lůžku poustevník. Silně blouzní v horečkách.";
            });
          },
        ));

        // Distillation setup at fireplace (requires pot + water + copper pipe + jar)
        final distilled = state.roomStates['node4_water_distilled'] == true;
        if (!distilled && state.inventory.contains('pot') && state.inventory.contains('copper_pipe') && state.inventory.contains('pure_water') == false) {
          list.add(_Hotspot(
            name: "Ohniště (Destilace)",
            x: 0.72, y: 0.72, w: 0.2, h: 0.2,
            onTap: () {
              _service.removeItem('pot');
              _service.removeItem('copper_pipe');
              _service.collectItem('pure_water');
              _showDialog("🧪 Sestavil jsi destilační přístroj: Do kotlíku jsi nalil špinavou vodu z bažiny, napojil měděnou trubku a páru odvedl do prázdné lahve nad ohněm. Získal jsi čistou destilovanou vodu!");
            },
          ));
        }

        // Swamp Water hotspot (requires pot)
        list.add(_Hotspot(
          name: "Bažina (Voda)",
          x: 0.42, y: 0.78, w: 0.25, h: 0.18,
          onTap: () {
            if (_selectedItemId == 'pot') {
              _showDialog("Nabral jsi špinavou a otrávenou vodu z bažiny do kotlíku.");
            } else {
              _showDialog("Voda v bažině je znečištěná, pít se nedá.");
            }
          },
        ));

        // Old Well (requires well handle)
        final wellHandlePlaced = state.roomStates['node4_well_handle'] == true;
        final triangularKeyTaken = state.roomStates['node4_triangular_key_taken'] == true;

        list.add(_Hotspot(
          name: "Kamenná studna",
          x: 0.45, y: 0.48, w: 0.16, h: 0.25,
          onTap: () {
            if (triangularKeyTaken) {
              _showDialog("Studna je prázdná, klíč jsi již vytáhl.");
              return;
            }

            if (wellHandlePlaced) {
              _service.updateRoomState('node4_triangular_key_taken', true);
              _service.collectItem('triangular_key');
              _showDialog("⚙️ Otočil jsi klikou a vytáhl kbelík nahoru. Na jeho dně leží těžký trojúhelníkový klíč!");
            } else if (_selectedItemId == 'well_handle') {
              _service.updateRoomState('node4_well_handle', true);
              _service.removeItem('well_handle');
              setState(() => _selectedItemId = null);
              _showDialog("Nasadil jsi kliku navijáku na osu studny.");
            } else {
              _showDialog("Stará studna je hluboká a navijáku chybí otočná rukojeť, lano nejde navinout.");
            }
          },
        ));

        // Shrine transition
        list.add(_Hotspot(
          name: "Svatyně v bažinách",
          x: 0.72, y: 0.22, w: 0.22, h: 0.32,
          onTap: () {
            setState(() {
              _currentSubroom = "shrine";
              _dialogText = "Stojíš u svatyně obklopené kamennými sochami lesní zvěře.";
            });
          },
        ));
      } else if (_currentSubroom == "cave") {
        // Uvnitř jeskyně
        final healed = state.roomStates['node4_hermit_healed'] == true;

        list.add(_Hotspot(
          name: "Poustevník",
          x: 0.38, y: 0.42, w: 0.25, h: 0.35,
          onTap: () => _startPoustevnikDialogue(state),
        ));

        // Pot on ground
        final hasPot = state.roomStates['node4_has_pot'] == true;
        if (!hasPot) {
          list.add(_Hotspot(
            name: "Měděný kotlík",
            x: 0.72, y: 0.72, w: 0.15, h: 0.12,
            onTap: () {
              _service.updateRoomState('node4_has_pot', true);
              _service.collectItem('pot');
              _showDialog("Sebral jsi ze země prázdný měděný kotlík.");
            },
          ));
        }

        // Copper pipe
        final hasPipe = state.roomStates['node4_has_pipe'] == true;
        if (!hasPipe) {
          list.add(_Hotspot(
            name: "Měděná trubka",
            x: 0.15, y: 0.65, w: 0.15, h: 0.15,
            onTap: () {
              _service.updateRoomState('node4_has_pipe', true);
              _service.collectItem('copper_pipe');
              _showDialog("V rohu jeskyně leží stará měděná trubka. Mohla by se hodit na destilaci.");
            },
          ));
        }

        // Return button
        list.add(_Hotspot(
          name: "Vchod ven",
          x: 0.45, y: 0.85, w: 0.15, h: 0.1,
          onTap: () {
            _endDialogue();
            setState(() {
              _currentSubroom = "exterior";
              _dialogText = "Stojíš venku v bažině.";
            });
          },
        ));
      } else if (_currentSubroom == "shrine") {
        // Svatyně bažin
        final hasHerbs = state.roomStates['node4_has_herbs'] == true;

        list.add(_Hotspot(
          name: "Kamenný oltář svatyně",
          x: 0.38, y: 0.35, w: 0.25, h: 0.32,
          onTap: () {
            if (hasHerbs) {
              _showDialog("Svatyně je tichá, modré houby jsi již nasbíral.");
              return;
            }

            // Balance scale puzzle
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LogicPuzzlesScreen(
                  puzzleType: "scales",
                  onSolved: () {
                    _service.updateRoomState('node4_has_herbs', true);
                    _service.collectItem('blue_mushrooms');
                    _showDialog("🎉 Váhy se vyrovnaly! Socha jelena ustoupila a pod ní jsi našel čerstvé modré bažinné houby.");
                  },
                ),
              ),
            );
          },
        ));

        // Brew potion (requires pure water + blue mushrooms + pot)
        if (state.inventory.contains('pure_water') && state.inventory.contains('blue_mushrooms')) {
          list.add(_Hotspot(
            name: "Ohniště (Vaření)",
            x: 0.12, y: 0.72, w: 0.22, h: 0.22,
            onTap: () {
              _service.removeItem('pure_water');
              _service.removeItem('blue_mushrooms');
              _service.collectItem('potion');
              _showDialog("🍯 Svařil jsi modré houby v čisté destilované vodě v kotlíku. Získal jsi zářící modrý léčivý elixír!");
            },
          ));
        }

        // Return button
        list.add(_Hotspot(
          name: "Vchod ven",
          x: 0.45, y: 0.85, w: 0.15, h: 0.1,
          onTap: () {
            _endDialogue();
            setState(() {
              _currentSubroom = "exterior";
              _dialogText = "Stojíš venku v bažině.";
            });
          },
        ));
      }
    } else if (widget.nodeId == 'node5') {
      // Zapomenutá pevnost
      if (_currentSubroom == "exterior") {
        // Knight Statue
        final swordPlaced = state.roomStates['node5_has_sword'] == true;
        final lensCleaned = state.roomStates['node5_lens_cleaned'] == true;

        list.add(_Hotspot(
          name: "Socha rytíře",
          x: 0.15, y: 0.42, w: 0.2, h: 0.45,
          onTap: () {
            if (lensCleaned) {
              _showDialog("Socha drží kamenný meč a čočka je již vyleštěná.");
              return;
            }

            if (swordPlaced) {
              if (_selectedItemId == 'acid') {
                _service.removeItem('acid');
                _service.updateRoomState('node5_lens_cleaned', true);
                _service.collectItem('clean_lens');
                setState(() => _selectedItemId = null);
                _showDialog("🧪 Nanesl jsi kyselinu na čočku sochy. Tvrdá pryskyřice se okamžitě rozpustila a odhalila čisté leštěné sklo. Sebral jsi čistou čočku!");
              } else {
                _showDialog("Socha rytíře se otočila. V jejím hrudním plátu se odhalila čočka, ale je zalitá tvrdou stromovou pryskyřicí, která nejde seškrábat.");
              }
            } else if (_selectedItemId == 'stone_sword') {
              _service.updateRoomState('node5_has_sword', true);
              _service.removeItem('stone_sword');
              setState(() => _selectedItemId = null);
              _showDialog("🗡️ Vložil jsi kamenný meč do rukou sochy rytíře. Mechanismus za zdí zabzučel a socha se otočila čelem ke zdi!");
            } else {
              _showDialog("Obří kamenná socha rytíře chránící pevnost. V rukou jí chybí rituální meč.");
            }
          },
        ));

        // Armory Gate
        final armoryOpen = state.roomStates['node5_armory_open'] == true;
        list.add(_Hotspot(
          name: "Mříž zbrojnice",
          x: 0.72, y: 0.48, w: 0.18, h: 0.32,
          onTap: () {
            if (armoryOpen) {
              final taken = state.roomStates['node5_items_taken'] == true;
              if (!taken) {
                _service.updateRoomState('node5_items_taken', true);
                _service.collectItem('stone_sword');
                _service.collectItem('acid');
                _showDialog("Vstoupil jsi do zbrojnice. Na stojanu leží Kamenný meč a na polici lahvička s kyselinou.");
              } else {
                _showDialog("Zbrojnice je prázdná.");
              }
              return;
            }

            if (_selectedItemId == 'key_armory') {
              _service.updateRoomState('node5_armory_open', true);
              _service.removeItem('key_armory');
              setState(() => _selectedItemId = null);
              _showDialog("🔑 Odemkl jsi mříž zbrojnice těžkým klíčem!");
            } else if (_selectedItemId != null) {
              _showDialog("Tento klíč na mříž nepasuje.");
            } else {
              _showDialog("Vchod do zbrojnice je zajištěn bytelnou železnou mříží.");
            }
          },
        ));

        // Library transition
        list.add(_Hotspot(
          name: "Vchod do knihovny",
          x: 0.45, y: 0.42, w: 0.15, h: 0.3,
          onTap: () {
            setState(() {
              _currentSubroom = "library";
              _dialogText = "Knihovna pevnosti. Police jsou plné tlustých svazků a na stole leží astronomický dalekohled.";
            });
          },
        ));
      } else if (_currentSubroom == "library") {
        // Uvnitř knihovny
        final keyTaken = state.roomStates['node5_key_armory_taken'] == true;

        // Bookshelf puzzle
        list.add(_Hotspot(
          name: "Police s knihami",
          x: 0.15, y: 0.22, w: 0.22, h: 0.45,
          onTap: () {
            if (keyTaken) {
              _showDialog("Knihy jsou seřazené, klíč jsi již vybral.");
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LogicPuzzlesScreen(
                  puzzleType: "bookshelf",
                  onSolved: () {
                    _service.updateRoomState('node5_key_armory_taken', true);
                    _service.collectItem('key_armory');
                    _showDialog("🎉 Knihy zapadly na své místo. Zpoza jedné z nich vypadl těžký železný klíč od zbrojnice!");
                  },
                ),
              ),
            );
          },
        ));

        // Telescope puzzle (requires clean_lens)
        final telescopeSolved = state.roomStates['node5_puzzle_solved'] == true;
        list.add(_Hotspot(
          name: "Astronomický dalekohled",
          x: 0.42, y: 0.45, w: 0.25, h: 0.35,
          onTap: () {
            if (telescopeSolved) {
              _showDialog("Dalekohled je správně seřízen. Paprsek světla ukazuje na průsmyk.");
              return;
            }

            final lensPlaced = state.roomStates['node5_lens_placed'] == true;
            if (!lensPlaced) {
              if (_selectedItemId == 'clean_lens') {
                _service.updateRoomState('node5_lens_placed', true);
                _service.removeItem('clean_lens');
                setState(() => _selectedItemId = null);
                _showDialog("Vložil jsi čistou čočku do objektivu dalekohledu.");
              } else {
                _showDialog("Obří kovový dalekohled. Chybí mu skleněná čočka, takže skrz něj není nic vidět.");
              }
            } else {
              // Open telescope puzzle
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LogicPuzzlesScreen(
                    puzzleType: "telescope",
                    onSolved: () {
                      _service.updateRoomState('node5_puzzle_solved', true);
                      _service.completeNode('node5');
                      _showDialog("🎉 Správně jsi zaměřil souhvězdí! Dalekohled se uzamkl a paprsek světla skrze něj ukázal přesnou lokaci kamenného oltáře.");
                    },
                  ),
                ),
              );
            }
          },
        ));

        // Gather dust element (requires amulet)
        final dustCollected = state.roomStates['node6_dust_collected'] == true;
        if (!dustCollected && state.inventory.contains('amulet')) {
          list.add(_Hotspot(
            name: "Starý regál",
            x: 0.72, y: 0.25, w: 0.18, h: 0.32,
            onTap: () {
              _service.updateRoomState('node6_dust_collected', true);
              _service.collectItem('item_dust');
              _showDialog("Prach na knihách je starý stovky let. Nabral jsi ho do amuletu jako Element Vzduchu.");
            },
          ));
        }

        // Hvězdopravec NPC
        list.add(_Hotspot(
          name: "Hvězdopravec",
          x: 0.75, y: 0.52, w: 0.18, h: 0.32,
          onTap: () => _startHvezdopravecDialogue(state),
        ));

        // Return button
        list.add(_Hotspot(
          name: "Vchod ven",
          x: 0.45, y: 0.85, w: 0.15, h: 0.1,
          onTap: () {
            _endDialogue();
            setState(() {
              _currentSubroom = "exterior";
              _dialogText = "Stojíš na nádvoří pevnosti.";
            });
          },
        ));
      }
    } else if (widget.nodeId == 'node6') {
      // Kamenný oltář
      final completed = state.completedNodes.contains('node6');

      // Elements slot
      final elementsPlaced = state.roomStates['node6_elements_placed'] == true;
      list.add(_Hotspot(
        name: "Oltář (Sloty)",
        x: 0.35, y: 0.42, w: 0.3, h: 0.3,
        onTap: () {
          if (completed) {
            _showDialog("Rituál byl úspěšně dokončen. Amulet září věčným světlem!");
            return;
          }

          if (elementsPlaced) {
            // Start final action game!
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CatchingGameScreen(
                  onSolved: () async {
                    _service.updateRoomState('node6_amulet_active', true);
                    _service.completeNode('node6');
                    await _service.claimFinalReward();
                    _showDialog("🏆 Úspěšně jsi dokončil celou výpravu! Získal jsi 50 Limenek a tvůj zvířecí maskot slaví vítězství!");
                  },
                ),
              ),
            );
            return;
          }

          // Check if user has all 4 elements
          final hasAsh = state.inventory.contains('item_ash');
          final hasWater = state.inventory.contains('item_water') || state.inventory.contains('pure_water');
          final hasDust = state.inventory.contains('item_dust');
          final hasSalt = state.roomStates['node6_salt_collected'] == true || state.inventory.contains('item_salt');

          if (hasAsh && hasWater && hasDust && hasSalt && state.inventory.contains('amulet')) {
            _service.removeItem('item_ash');
            _service.removeItem('item_dust');
            if (state.inventory.contains('item_water')) _service.removeItem('item_water');
            if (state.inventory.contains('pure_water')) _service.removeItem('pure_water');
            if (state.inventory.contains('item_salt')) _service.removeItem('item_salt');
            _service.removeItem('amulet');
            _service.updateRoomState('node6_elements_placed', true);
            _showDialog("🔮 Vložil jsi amulet do středu oltáře a rozmístil 4 elementy: Popel (Oheň), Vodu (Voda), Prach (Vzduch) a Horskou sůl (Země). Oltář se rozsvítil! Klikni na něj znovu a zahaj aktivaci.");
          } else {
            _showDialog("Oltář vyžaduje vložení vyhaslého amuletu a 4 elementů: Oheň (Popel K1), Vodu (Čistou vodu K2), Vzduch (Prach K3) a Zemi (Horskou sůl). Vrať se na mapě a najdi je!");
          }
        },
      ));

      // Salt hotspot (requires amulet)
      final saltCollected = state.roomStates['node6_salt_collected'] == true;
      if (!saltCollected && state.inventory.contains('amulet')) {
        list.add(_Hotspot(
          name: "Skalní trhlina (Sůl)",
          x: 0.08, y: 0.65, w: 0.18, h: 0.18,
          onTap: () {
            _service.updateRoomState('node6_salt_collected', true);
            _service.collectItem('item_salt');
            _showDialog("V trhlině skály se vysrážela čistá horská sůl. Nabral jsi ji do amuletu jako Element Země.");
          },
        ));
      }
    }

    return list;
  }

  String _getRoomBackground(QuestState state) {
    if (widget.nodeId == 'node1') {
      return 'assets/images/story_room_gate.png';
    } else if (widget.nodeId == 'node2') {
      return 'assets/images/story_room_oak.png';
    } else if (widget.nodeId == 'node3') {
      if (_currentSubroom == "interior") {
        return 'assets/images/story_room_cabin.png';
      }
      return 'assets/images/story_room_gate.png'; // Reuses gate background with green overlay
    } else if (widget.nodeId == 'node4') {
      if (_currentSubroom == "cave") {
        return 'assets/images/story_room_cabin.png'; // Reuses cabin interior (cave fallback)
      }
      return 'assets/images/story_room_swamp.png';
    } else if (widget.nodeId == 'node5') {
      if (_currentSubroom == "library") {
        return 'assets/images/story_room_observatory.png';
      }
      return 'assets/images/story_room_gate.png'; // Reuses gate with gray fortress wall tint
    } else if (widget.nodeId == 'node6') {
      return 'assets/images/story_room_altar.png';
    }
    return 'assets/images/story_room_gate.png';
  }

  Color _getRoomColorFilter() {
    // Add custom tint to reuse backgrounds effectively
    if (widget.nodeId == 'node3' && _currentSubroom == "exterior") {
      return Colors.brown.withOpacity(0.18); // brown forest clearing tint
    }
    if (widget.nodeId == 'node4' && _currentSubroom == "cave") {
      return Colors.purple.withOpacity(0.35); // dark magic cave tint
    }
    if (widget.nodeId == 'node5' && _currentSubroom == "exterior") {
      return Colors.blueGrey.withOpacity(0.3); // stone fortress tint
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ValueListenableBuilder<QuestState>(
          valueListenable: _service.stateNotifier,
          builder: (context, state, _) {
            final hotspots = _getHotspots(state);
            final bgAsset = _getRoomBackground(state);
            final colorFilter = _getRoomColorFilter();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Navigation / HUD bar
                Container(
                  color: Colors.grey.shade900,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.nodeId == 'node3' && _currentSubroom == 'interior'
                              ? 'Uvnitř chýše'
                              : widget.nodeId == 'node4' && _currentSubroom == 'cave'
                                  ? 'Poustevníkova jeskyně'
                                  : widget.nodeId == 'node4' && _currentSubroom == 'shrine'
                                      ? 'Svatyně'
                                      : widget.nodeId == 'node5' && _currentSubroom == 'library'
                                          ? 'Knihovna'
                                          : _service.nodes.firstWhere((n) => n.id == widget.nodeId).name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _showHints ? Icons.lightbulb : Icons.lightbulb_outline,
                          color: _showHints ? Colors.yellow : Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _showHints = !_showHints;
                          });
                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) {
                              setState(() {
                                _showHints = false;
                              });
                            }
                          });
                        },
                        tooltip: 'Ukázat nápovědu',
                      ),
                    ],
                  ),
                ),

                // 2. Point-and-Click Viewport
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;

                      return Stack(
                        children: [
                          // Background Image
                          Positioned.fill(
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(colorFilter, BlendMode.darken),
                              child: Image.asset(
                                bgAsset,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          // Render Interactive Hotspots
                          ...hotspots.map((hs) {
                            return Positioned(
                              left: hs.x * width,
                              top: hs.y * height,
                              width: hs.w * width,
                              height: hs.h * height,
                              child: GestureDetector(
                                onTap: hs.onTap,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: _showHints
                                        ? Border.all(color: Colors.yellowAccent, width: 2)
                                        : null,
                                    color: _showHints
                                        ? Colors.yellowAccent.withOpacity(0.15)
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),

                // 3. Dialog Box / Dialogue UI
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade900,
                  constraints: const BoxConstraints(minHeight: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_dialogueCharacterName != null) ...[
                        Row(
                          children: [
                            Text(
                              _dialogueCharacterAvatar ?? '💬',
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _dialogueCharacterName!,
                              style: TextStyle(
                                color: Colors.lime.shade400,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                              onPressed: _endDialogue,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        _dialogText,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                      ),
                      if (_dialogueOptions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _dialogueOptions.map((opt) {
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lime.shade800,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: opt.onTap,
                              child: Text(opt.text),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                // 4. Inventory Bar
                Container(
                  color: Colors.black,
                  height: 75,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: state.inventory.isEmpty
                      ? const Center(
                          child: Text(
                            'Tvůj inventář je prázdný.',
                            style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.inventory.length,
                          itemBuilder: (context, index) {
                            final itemId = state.inventory[index];
                            final item = _service.allItems[itemId];
                            if (item == null) return const SizedBox.shrink();

                            final isSelected = _selectedItemId == itemId;

                            // Emojis for item fallback representation
                            final emojis = {
                              'iron_handle': '🔧',
                              'lens': '🔍',
                              'tinder': '🌿',
                              'smoldering_tinder': '🔥',
                              'oil': '🧪',
                              'dirty_key': '🗝️',
                              'fixed_key': '🔑',
                              'blue_mushrooms': '🍄',
                              'copper_pipe': '⚙️',
                              'pot': '🥣',
                              'pure_water': '💧',
                              'potion': '🍵',
                              'well_handle': '🪓',
                              'triangular_key': '📐',
                              'amulet': '💎',
                              'key_armory': '🗝️',
                              'stone_sword': '🗡️',
                              'acid': '🧪',
                              'clean_lens': '🔍',
                              'item_ash': '🌋',
                              'item_salt': '🧂',
                              'item_dust': '🌪️',
                              'item_water': '💧',
                            };

                            final emoji = emojis[itemId] ?? '🎒';

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedItemId = null;
                                  } else {
                                    _selectedItemId = itemId;
                                    _dialogText = "${item.name}: ${item.description}";
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 60,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.lime.shade700 : Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected ? Border.all(color: Colors.lime, width: 2) : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Hotspot {
  final String name;
  final double x; // x percentage (0-1)
  final double y; // y percentage (0-1)
  final double w; // width percentage (0-1)
  final double h; // height percentage (0-1)
  final VoidCallback onTap;

  _Hotspot({
    required this.name,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.onTap,
  });
}

class _DialogueOption {
  final String text;
  final VoidCallback onTap;

  _DialogueOption({
    required this.text,
    required this.onTap,
  });
}
