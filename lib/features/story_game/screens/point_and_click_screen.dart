import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story_quest_model.dart';
import '../services/story_game_service.dart';
import 'catching_game_screen.dart';
import 'logic_puzzles_screen.dart';
import 'story_animations.dart';
import 'package:flutter_tts/flutter_tts.dart';

class PointAndClickScreen extends StatefulWidget {
  final String nodeId;

  const PointAndClickScreen({super.key, required this.nodeId});

  @override
  State<PointAndClickScreen> createState() => _PointAndClickScreenState();
}

class _PointAndClickScreenState extends State<PointAndClickScreen> {
  final StoryGameService _service = StoryGameService();
  String? _selectedItemId;
  final FlutterTts _tts = FlutterTts();

  void _speakHeroLine(String line) async {
    try {
      await _tts.setLanguage("cs-CZ");
      await _tts.setPitch(0.85); // Deeper pitch to sound like a man
      await _tts.setSpeechRate(0.4); // Slower, natural reading speed
      await _tts.speak(line);
    } catch (_) {}
  }

  void _collectItem(String itemId, String pickupMessage) {
    _service.collectItem(itemId);
    _speakHeroLine("To se bude hodit.");
    _showDialog(pickupMessage);
  }

  void _checkNode3Completion(QuestState state) {
    final hasPot = _service.stateNotifier.value.roomStates['node3_has_pot'] == true;
    final hasWellHandle = _service.stateNotifier.value.roomStates['node3_has_well_handle'] == true;
    if (hasPot && hasWellHandle) {
      _service.completeNode('node3');
      _showDialog("🎉 Našel jsi kotlík i kliku studny! Pokoj byl plně prozkoumán.");
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    }
  }

  void _completeNodeAndPop(String nodeId, String successMessage) {
    _service.completeNode(nodeId);
    _showDialog(successMessage);
    _speakHeroLine("Dokončeno!");
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.pop(context, true);
      }
    });
  }
  bool _showHints = false;
  String _dialogText = "";
  String _currentSubroom = "exterior"; // Used for sub-rooms (interior vs exterior)

  // NPC Dialogue States
  String? _dialogueCharacterName;
  String? _dialogueCharacterAsset; // Left character image (NPC)
  String? _playerCharacterAsset;   // Right character image (Player)
  List<_DialogueLine> _dialogueScript = [];
  int _dialogueScriptIndex = 0;
  List<_DialogueOption> _dialogueChoices = [];
  String _activeCompanion = 'boy';

  @override
  void initState() {
    super.initState();
    _setInitialDialog();
    _loadPlayerAvatar();
  }

  Future<void> _loadPlayerAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companion = prefs.getString('selected_companion') ?? 'boy';
      if (mounted) {
        setState(() {
          _activeCompanion = companion;
        });
      }
    } catch (_) {}
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
      _dialogueChoices = backOptions;
    });
  }

  void _startDialogueScript(String charName, String charAsset, List<_DialogueLine> script, List<_DialogueOption> choices) {
    setState(() {
      _dialogueCharacterName = charName;
      _dialogueCharacterAsset = charAsset;
      _playerCharacterAsset = 'assets/images/story_player_adventurer.png';
      _dialogueScript = script;
      _dialogueScriptIndex = 0;
      _dialogueChoices = choices;
      if (script.isNotEmpty) {
        _dialogText = script[0].text;
      } else {
        _dialogText = "";
      }
    });
  }

  void _onDialogueAreaTap() {
    if (_dialogueScriptIndex < _dialogueScript.length - 1) {
      setState(() {
        _dialogueScriptIndex++;
        _dialogText = _dialogueScript[_dialogueScriptIndex].text;
      });
    } else if (_dialogueChoices.isEmpty) {
      _endDialogue();
    }
  }

  bool get _isNpcActive {
    if (_dialogueScript.isEmpty || _dialogueScriptIndex >= _dialogueScript.length) return false;
    return _dialogueScript[_dialogueScriptIndex].speaker == 'npc';
  }

  bool get _isPlayerActive {
    if (_dialogueScript.isEmpty || _dialogueScriptIndex >= _dialogueScript.length) return false;
    return _dialogueScript[_dialogueScriptIndex].speaker == 'player';
  }

  void _endDialogue() {
    setState(() {
      _dialogueCharacterName = null;
      _dialogueCharacterAsset = null;
      _playerCharacterAsset = null;
      _dialogueScript = [];
      _dialogueScriptIndex = 0;
      _dialogueChoices = [];
      _setInitialDialog();
    });
  }

  bool _tryCombineItems(String item1, String item2) {
    final state = _service.stateNotifier.value;
    final id1 = item1.compareTo(item2) < 0 ? item1 : item2;
    final id2 = item1.compareTo(item2) < 0 ? item2 : item1;

    // Recipes:
    // 1. stick + cloth -> torch
    if (id1 == 'cloth' && id2 == 'stick') {
      _service.removeItem('cloth');
      _service.removeItem('stick');
      _service.collectItem('torch'); _speakHeroLine("Mám to!");
      _showDialog("🔧 Spojil jsi suchou větev s mastným hadrem a vyrobil jsi Nezapálenou pochodeň! 🔦");
      return true;
    }
    // 2. torch + smoldering_tinder -> burning_torch
    if (id1 == 'smoldering_tinder' && id2 == 'torch') {
      _service.removeItem('smoldering_tinder');
      _service.removeItem('torch');
      _service.collectItem('burning_torch'); _speakHeroLine("Podařilo se!");
      _showDialog("🔥 Pomocí doutnajícího troudu jsi úspěšně zapálil pochodeň! Nyní jasně plane. Můžeš s ní osvětlit temná místa.");
      return true;
    }
    // 3. dirty_key + oil -> fixed_key
    if (id1 == 'dirty_key' && id2 == 'oil') {
      _service.removeItem('dirty_key');
      _service.removeItem('oil');
      _service.collectItem('fixed_key'); _speakHeroLine("Mám to!");
      _showDialog("🔧 Nanesl jsi olej na rezavý klíč a očistil ho. Získal jsi funkční Klíč od brány! 🔑");
      return true;
    }
    // 4. blue_mushrooms + pure_water -> potion (requires pot in inventory)
    if (id1 == 'blue_mushrooms' && id2 == 'pure_water') {
      if (state.inventory.contains('pot')) {
        _service.removeItem('blue_mushrooms');
        _service.removeItem('pure_water');
        _service.collectItem('potion'); _speakHeroLine("Podařilo se!");
        _showDialog("🍵 Svařil jsi modré houby s čistou vodou v měděném kotlíku a vyrobil zářící Léčivý elixír!");
        return true;
      } else {
        _showDialog("Máš sice houby i čistou vodu, ale nemáš v čem elixír svařit. Chce to nějakou nádobu/kotlík.");
        return false;
      }
    }
    // 5. lens + tinder -> smoldering_tinder
    if (id1 == 'lens' && id2 == 'tinder') {
      _service.removeItem('lens');
      _service.removeItem('tinder');
      _service.collectItem('smoldering_tinder'); _speakHeroLine("Podařilo se!");
      _showDialog("☀️ Soustředil jsi paprsky přes čočku lupy na suchý mech. Po chvíli se z něj začal linout dým a mech začal doutnat. Máš doutnající troud!");
      return true;
    }

    _speakHeroLine("Tohle nefunguje.");
    return false;
  }

  void _startPoustevnikDialogue(QuestState state) {
    final healed = state.roomStates['node4_hermit_healed'] == true;
    if (healed) {
      _showHealedPoustevnikDialogue(state);
    } else {
      _showSickPoustevnikDialogue(state);
    }
  }

  void _showSickPoustevnikDialogue(QuestState state) {
    final script = [
      _DialogueLine(speaker: 'npc', text: "Uch... ten oheň v mých žilách... pálí mě celá hruď..."),
      _DialogueLine(speaker: 'player', text: "Haló? Slyšíte mě? Jste v pořádku? Co vás trápí?"),
      _DialogueLine(speaker: 'npc', text: "Och... poutník... Jsem poustevník z této mlžné bažiny. Horečka mě trápí... pálí mě tělo..."),
      _DialogueLine(speaker: 'player', text: "Jak vám mohu pomoci? Existuje nějaký lék?"),
      _DialogueLine(speaker: 'npc', text: "Lektvar... modré bažinné houby... a čistá destilovaná voda. Bez nich horečka neustoupí..."),
    ];

    final choices = <_DialogueOption>[];

    if (state.inventory.contains('potion')) {
      choices.add(_DialogueOption(
        text: "Podat léčivý elixír 🍵",
        onTap: () {
          _service.removeItem('potion');
          _service.updateRoomState('node4_hermit_healed', true);
          _service.collectItem('triangular_key');
          _service.completeNode('node4');
          setState(() {
            _selectedItemId = null;
          });
          final updatedState = _service.stateNotifier.value;

          final healScript = [
            _DialogueLine(speaker: 'player', text: "Tady, vypijte tohle! Svařil jsem modré houby v destilované vodě."),
            _DialogueLine(speaker: 'npc', text: "🍵 (Lok... lok...) Oh! Ta léčivá síla... chlad stoupá do mých spánků..."),
            _DialogueLine(speaker: 'npc', text: "Horečka ustupuje! Zachránil jsi mi život, poutníku."),
            _DialogueLine(speaker: 'npc', text: "Vezmi si tento Trojúhelníkový klíč, který chrání rituální oltář na konci cesty (K6)."),
            _DialogueLine(speaker: 'npc', text: "A pamatuj si úhly pro dalekohled v pevnosti (K5): Medvěd 45°, Vlk 120° a Jelen 275°. Nastav je tam."),
          ];

          _startDialogueScript(
            "Poustevník",
            "assets/images/story_npc_hermit.png",
            healScript,
            [
              _DialogueOption(
                text: "Chci se zeptat na další věci.",
                onTap: () => _showHealedPoustevnikDialogue(updatedState),
              ),
              _DialogueOption(
                text: "Děkuji, jdu dál.",
                onTap: _endDialogue,
              )
            ]
          );
        },
      ));
    }

    choices.add(_DialogueOption(
      text: "Kde najdu ty modré houby?",
      onTap: () {
        final mushroomScript = [
          _DialogueLine(speaker: 'player', text: "Kde přesně rostou ty modré houby? Prohledal jsem okolí a nic jsem neviděl."),
          _DialogueLine(speaker: 'npc', text: "Rostou ve svatyni v bažinách (cesta vpravo). Ale svatyně je chráněna starobylými vahami."),
          _DialogueLine(speaker: 'npc', text: "Musíš na váhách vyrovnat váhu soch lesních zvířat. Teprve pak se ti houby odhalí."),
        ];
        _startDialogueScript(
          "Poustevník",
          "assets/images/story_npc_hermit.png",
          mushroomScript,
          [
            _DialogueOption(
              text: "Rozumím (Zpět)",
              onTap: () => _showSickPoustevnikDialogue(state),
            )
          ]
        );
      },
    ));

    choices.add(_DialogueOption(
      text: "Kde získám čistou vodu?",
      onTap: () {
        final waterScript = [
          _DialogueLine(speaker: 'player', text: "Voda v bažině je otrávená a špinavá. Jak mám získat čistou vodu pro lektvar?"),
          _DialogueLine(speaker: 'npc', text: "Venku v bažinách je stará kamenná studna. Voda v ní je čistá, ale naviják studny je zablokovaný těžkým kbelíkem a chybí mu klika."),
          _DialogueLine(speaker: 'player', text: "Aha! Kliku ze staré chýše (K3) už mám u sebe. Použiji ji na studnu a zkusím ji vyvážit."),
        ];
        _startDialogueScript(
          "Poustevník",
          "assets/images/story_npc_hermit.png",
          waterScript,
          [
            _DialogueOption(
              text: "Rozumím (Zpět)",
              onTap: () => _showSickPoustevnikDialogue(state),
            )
          ]
        );
      },
    ));

    choices.add(_DialogueOption(
      text: "Proč žijete v této bažině? (Flavor 💬)",
      onTap: () {
        final flavorScript = [
          _DialogueLine(speaker: 'player', text: "Proč vlastně žijete sám v této nehostinné bažině? Není to tu nebezpečné?"),
          _DialogueLine(speaker: 'npc', text: "Nehostinné? Možná. Ale má to své výhody. Žádní lidé, žádný hluk... a hlavně žádné daně!"),
          _DialogueLine(speaker: 'npc', text: "Svatyně v bažinách ukrývá prastaré síly. Jsem jejím strážcem, i když teď spíše pacientem..."),
          _DialogueLine(speaker: 'npc', text: "A navíc, komáři jsou tu sice velcí jako vrabci, ale když se s nimi spřátelíš, dají ti pokoj."),
          _DialogueLine(speaker: 'player', text: "Spřátelit se s komáry? To zní docela šíleně."),
          _DialogueLine(speaker: 'npc', text: "Věř mi, stačí jim obětovat trochu cukru a budou tě doprovázet jako malá bzučící armáda!"),
        ];
        _startDialogueScript(
          "Poustevník",
          "assets/images/story_npc_hermit.png",
          flavorScript,
          [
            _DialogueOption(
              text: "Zajímavé (Zpět)",
              onTap: () => _showSickPoustevnikDialogue(state),
            )
          ]
        );
      },
    ));

    choices.add(_DialogueOption(
      text: "Pokusím se ty věci sehnat.",
      onTap: _endDialogue,
    ));

    _startDialogueScript(
      "Poustevník",
      "assets/images/story_npc_hermit.png",
      script,
      choices,
    );
  }

  void _showHealedPoustevnikDialogue(QuestState state) {
    final script = [
      _DialogueLine(speaker: 'npc', text: "Děkuji ti ještě jednou, příteli. Cítím se skvěle. Jak ti mohu na tvé cestě pomoci?"),
      _DialogueLine(speaker: 'player', text: "Rád vás vidím na nohou. Potřeboval bych nějaké rady ohledně své výpravy."),
    ];

    final choices = [
      _DialogueOption(
        text: "Co mám udělat s amuletem?",
        onTap: () {
          final amuletScript = [
            _DialogueLine(speaker: 'player', text: "Co mám udělat s amuletem strážců? Mám ho, ale je úplně vyhaslý."),
            _DialogueLine(speaker: 'npc', text: "Amulet leží zamčený v dutině starého dubu (K2). Musíš ho odemknout trojúhelníkovým klíčem ze studny."),
            _DialogueLine(speaker: 'npc', text: "Jakmile ho budeš mít, přines ho k oltáři věčnosti na vrcholku skály (K6)."),
            _DialogueLine(speaker: 'npc', text: "Budeš k tomu potřebovat shromáždit 4 elementy a umístit je do slotů oltáře pro rituál."),
          ];
          _startDialogueScript(
            "Poustevník",
            "assets/images/story_npc_hermit.png",
            amuletScript,
            [
              _DialogueOption(
                text: "Rozumím (Zpět)",
                onTap: () => _showHealedPoustevnikDialogue(state),
              )
            ]
          );
        },
      ),
      _DialogueOption(
        text: "Jaké byly ty úhly pro dalekohled?",
        onTap: () {
          final angleScript = [
            _DialogueLine(speaker: 'player', text: "Mohl byste mi zopakovat úhly souhvězdí pro dalekohled v pevnosti?"),
            _DialogueLine(speaker: 'npc', text: "Jistě. Musíš dalekohled otočit na tři souhvězdí v tomto přesném pořadí:"),
            _DialogueLine(speaker: 'npc', text: "První je Medvěd (úhel 45°), druhý je Vlk (úhel 120°) a třetí Jelen (úhel 275°)."),
            _DialogueLine(speaker: 'player', text: "Medvěd 45, Vlk 120, Jelen 275. Pamatuji si."),
            _DialogueLine(speaker: 'npc', text: "Správně. Jakmile tyto úhly nastavíš, paprsek světla odemkne průsmyk k oltáři."),
          ];
          _startDialogueScript(
            "Poustevník",
            "assets/images/story_npc_hermit.png",
            angleScript,
            [
              _DialogueOption(
                text: "Rozumím (Zpět)",
                onTap: () => _showHealedPoustevnikDialogue(state),
              )
            ]
          );
        },
      ),
      _DialogueOption(
        text: "Kde najdu ty 4 elementy?",
        onTap: () {
          final elementScript = [
            _DialogueLine(speaker: 'player', text: "Kde najdu ty 4 elementy, které oltář vyžaduje?"),
            _DialogueLine(speaker: 'npc', text: "Všechny leží na místech, která jsi již navštívil nebo navštívíš:"),
            _DialogueLine(speaker: 'npc', text: "Popel (Oheň) vezmi z ohniště u chýše lesníka (K3)."),
            _DialogueLine(speaker: 'npc', text: "Destilovanou vodu (Voda) získáš uvařením vody z bažin (K4)."),
            _DialogueLine(speaker: 'npc', text: "Prach (Vzduch) setři ze starého regálu v knihovně pevnosti (K5)."),
            _DialogueLine(speaker: 'npc', text: "A horskou sůl (Země) najdeš přímo ve skalní trhlině u oltáře (K6)."),
            _DialogueLine(speaker: 'player', text: "Takže se musím vracet a posbírat je do amuletu. Dobře."),
          ];
          _startDialogueScript(
            "Poustevník",
            "assets/images/story_npc_hermit.png",
            elementScript,
            [
              _DialogueOption(
                text: "Rozumím (Zpět)",
                onTap: () => _showHealedPoustevnikDialogue(state),
              )
            ]
          );
        },
      ),
      _DialogueOption(
        text: "Máte nějakou historku o tomto lese? (Flavor 💬)",
        onTap: () {
          final storyScript = [
            _DialogueLine(speaker: 'player', text: "Žijete tu dlouho. Máte nějakou zajímavou historku o tomto lese?"),
            _DialogueLine(speaker: 'npc', text: "Kdysi tu prý žil lesník, který se pokusil ochočit divočáka. Dal mu jméno 'Kvík' a krmil ho jen borůvkami."),
            _DialogueLine(speaker: 'npc', text: "Kvík nakonec vyrostl do velikosti medvěda a začal se chovat jako přerostlé štěně."),
            _DialogueLine(speaker: 'npc', text: "Chudák lesník musel z chýše utéct, protože ho Kvík neustále olizoval a shazoval na zem radostí, kdykoliv se vrátil z lesa."),
            _DialogueLine(speaker: 'player', text: "To zní docela legračně."),
            _DialogueLine(speaker: 'npc', text: "Možná ano, ale když tě olízne 300kilový kanec s borůvkovým dechem, smích tě rychle přejde!"),
          ];
          _startDialogueScript(
            "Poustevník",
            "assets/images/story_npc_hermit.png",
            storyScript,
            [
              _DialogueOption(
                text: "Pobavilo mě to (Zpět)",
                onTap: () => _showHealedPoustevnikDialogue(state),
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

    _startDialogueScript(
      "Poustevník",
      "assets/images/story_npc_hermit.png",
      script,
      choices,
    );
  }

  void _startHvezdopravecDialogue(QuestState state) {
    setState(() {
      _dialogueCharacterName = "Hvězdopravec";
      _dialogueCharacterAsset = "assets/images/story_npc_astronomer.png";
    });

    final solved = state.roomStates['node5_puzzle_solved'] == true;
    if (solved) {
      _showSolvedHvezdopravecDialogue(state);
    } else {
      _showUnsolvedHvezdopravecDialogue(state);
    }
  }

  void _showSolvedHvezdopravecDialogue(QuestState state) {
    final script = [
      _DialogueLine(speaker: 'npc', text: "Úžasné! Dalekohled je seřízen a hvězdný paprsek ukazuje na horský průsmyk."),
      _DialogueLine(speaker: 'player', text: "Díky tomu se cesta k oltáři otevřela. Jdu tam dokončit rituál."),
    ];

    final choices = [
      _DialogueOption(
        text: "Jak najdu ty elementy pro oltář?",
        onTap: () {
          final elementsScript = [
            _DialogueLine(speaker: 'player', text: "Kde najdu ty elementy, které musím umístit na oltář?"),
            _DialogueLine(speaker: 'npc', text: "Hledej popel v ohništi u chýše lesníka (K3), vodu z bažiny (K4), prach ze starého regálu za mnou (K5) a sůl přímo ve skalách u oltáře (K6)."),
          ];
          _startDialogueScript(
            "Hvězdopravec",
            "assets/images/story_npc_astronomer.png",
            elementsScript,
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
      )
    ];

    _startDialogueScript(
      "Hvězdopravec",
      "assets/images/story_npc_astronomer.png",
      script,
      choices,
    );
  }

  void _showUnsolvedHvezdopravecDialogue(QuestState state) {
    final script = [
      _DialogueLine(speaker: 'npc', text: "Hvězdy se pohybují... ale já nevidím vůbec nic! Moje staré oči už neslouží..."),
      _DialogueLine(speaker: 'player', text: "Dobrý den. Co se stalo? Mohu vám nějak pomoci?"),
      _DialogueLine(speaker: 'npc', text: "Ztratil jsem čočku ze svého astronomického dalekohledu! Dával jsem ji ven na nádvoří k soše rytíře..."),
      _DialogueLine(speaker: 'npc', text: "Ale rytíř se otočil a schovala ji pod tvrdou pryskyřici. Bez ní dalekohled neseřídím."),
    ];

    final choices = <_DialogueOption>[];

    final lensPlaced = state.roomStates['node5_lens_placed'] == true;
    if (!lensPlaced && state.inventory.contains('clean_lens')) {
      choices.add(_DialogueOption(
        text: "Předat vyčištěnou čočku 🔍",
        onTap: () {
          _service.removeItem('clean_lens');
          _service.updateRoomState('node5_lens_placed', true);
          setState(() {
            _selectedItemId = null;
          });
          final updatedState = _service.stateNotifier.value;

          final placeScript = [
            _DialogueLine(speaker: 'player', text: "Tady je ta čočka, vyčistil jsem ji kyselinou od té pryskyřice."),
            _DialogueLine(speaker: 'npc', text: "Úžasné! Pasuje dokonale. Moje staré oči opět uvidí hvězdy."),
            _DialogueLine(speaker: 'npc', text: "Nyní musíme dalekohled otočit na souhvězdí: Medvěda, Vlka a Jelena. Znáš jejich úhly?"),
            _DialogueLine(speaker: 'npc', text: "Poustevník z bažin by ti je mohl prozradit, pokud jsi ho zachránil."),
          ];

          _startDialogueScript(
            "Hvězdopravec",
            "assets/images/story_npc_astronomer.png",
            placeScript,
            [
              _DialogueOption(
                text: "Jaké úhly mám nastavit?",
                onTap: () {
                  final anglesScript = [
                    _DialogueLine(speaker: 'player', text: "Jaké úhly dalekohledu se mají nastavit? Poustevník mi je řekl."),
                    _DialogueLine(speaker: 'npc', text: "Pokud je víš, klikni na dalekohled a zadej je. Měly by to být úhly pro Medvěda, Vlka a Jelena."),
                    _DialogueLine(speaker: 'npc', text: "Pokud ne, budeš se muset vrátit do jeskyně v bažinách (K4) a zeptat se ho."),
                  ];
                  _startDialogueScript(
                    "Hvězdopravec",
                    "assets/images/story_npc_astronomer.png",
                    anglesScript,
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
                text: "Rozumím, jdu na to.",
                onTap: _endDialogue,
              )
            ]
          );
        },
      ));
    }

    if (!lensPlaced) {
      choices.add(_DialogueOption(
        text: "Jak otočím tu rytířskou sochu?",
        onTap: () {
          final statueScript = [
            _DialogueLine(speaker: 'player', text: "Jak mohu otočit tu sochu rytíře na nádvoří, aby odhalila čočku?"),
            _DialogueLine(speaker: 'npc', text: "Socha rytíře chránící pevnost reaguje na vložení Kamenného meče do rukou."),
            _DialogueLine(speaker: 'npc', text: "Ten je zamčený ve zbrojnici venku na nádvoří. Ale klíč od zbrojnice jsem někam schoval..."),
          ];
          _startDialogueScript(
            "Hvězdopravec",
            "assets/images/story_npc_astronomer.png",
            statueScript,
            [
              _DialogueOption(
                text: "Kde je klíč od zbrojnice?",
                onTap: () {
                  final keyScript = [
                    _DialogueLine(speaker: 'player', text: "Kam jste ten klíč od zbrojnice schoval? Bez něj se dovnitř nedostanu."),
                    _DialogueLine(speaker: 'npc', text: "Schoval jsem ho tady v knihovně za knihy na polici. Je tam šifra."),
                    _DialogueLine(speaker: 'npc', text: "Musíš seřadit knihy na polici abecedně od A do Z, teprve pak klíč vypadne."),
                  ];
                  _startDialogueScript(
                    "Hvězdopravec",
                    "assets/images/story_npc_astronomer.png",
                    keyScript,
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
                text: "Jak vyčistím tu čočku?",
                onTap: () {
                  final cleanScript = [
                    _DialogueLine(speaker: 'player', text: "Čočka na soše je zalitá tvrdou stromovou pryskyřicí. Jak ji dostanu dolů?"),
                    _DialogueLine(speaker: 'npc', text: "Pryskyřice je strašně tvrdá, ale rozpustí ji silná kyselina."),
                    _DialogueLine(speaker: 'npc', text: "Lahvička s kyselinou leží ve zbrojnici, hned vedle kamenného meče. Až ji odemkneš, vezmi obojí."),
                  ];
                  _startDialogueScript(
                    "Hvězdopravec",
                    "assets/images/story_npc_astronomer.png",
                    cleanScript,
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
                text: "Zpět",
                onTap: () => _showUnsolvedHvezdopravecDialogue(state),
              )
            ]
          );
        },
      ));
    } else {
      choices.add(_DialogueOption(
        text: "Jaké úhly mám nastavit?",
        onTap: () {
          final anglesScript = [
            _DialogueLine(speaker: 'player', text: "Jaké úhly dalekohledu se mají nastavit? Zapomněl jsem je."),
            _DialogueLine(speaker: 'npc', text: "Musíme dalekohled natočit na tři souhvězdí: Medvěda, Vlka a Jelena. Pokud neznáš úhly, zajdi za poustevníkem (K4)."),
          ];
          _startDialogueScript(
            "Hvězdopravec",
            "assets/images/story_npc_astronomer.png",
            anglesScript,
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

    choices.add(_DialogueOption(
      text: "Proč studujete hvězdy v pevnosti? (Flavor 💬)",
      onTap: () {
        final flavorScript = [
          _DialogueLine(speaker: 'player', text: "Proč vlastně studujete hvězdy v této staré opuštěné pevnosti? Není to nepohodlné?"),
          _DialogueLine(speaker: 'npc', text: "Nepohodlné? Trochu. Pevnost byla postavena přímo na silném magickém uzlu."),
          _DialogueLine(speaker: 'npc', text: "Hvězdná obloha je odtud nejjasnější. Hvězdy mi včera v noci pošeptaly úžasné tajemství."),
          _DialogueLine(speaker: 'player', text: "Opravdu? Jaké tajemství? Souvisí to s amuletem?"),
          _DialogueLine(speaker: 'npc', text: "Ne, pošeptaly mi, že zítra bude pršet. Jen mi zapomněly říct na kterém místě na zemi."),
          _DialogueLine(speaker: 'player', text: "Takže ta předpověď je vlastně úplně k ničemu."),
          _DialogueLine(speaker: 'npc', text: "Kdepak! Aspoň vím, že někdo na tomto světě by si měl vzít deštník!"),
        ];
        _startDialogueScript(
          "Hvězdopravec",
          "assets/images/story_npc_astronomer.png",
          flavorScript,
          [
            _DialogueOption(
              text: "Dobrá úvaha (Zpět)",
              onTap: () => _showUnsolvedHvezdopravecDialogue(state),
            )
          ]
        );
      },
    ));

    choices.add(_DialogueOption(
      text: "Pokusím se to vyřešit.",
      onTap: _endDialogue,
    ));

    _startDialogueScript(
      "Hvězdopravec",
      "assets/images/story_npc_astronomer.png",
      script,
      choices,
    );
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
            setState(() => _selectedItemId = null);
            _completeNodeAndPop('node1', "💥 Použil jsi klíč! Zámek s hlasitým cvaknutím povolil, brána se otevřela a cesta dál je volná.");
          } else if (_selectedItemId == 'dirty_key') {
            _speakHeroLine("Tenhle klíč je moc rezavý.");
            _showDialog("Klíč pasuje do dírky, ale je příliš rezavý a drhne. Nemůžeš s ním otočit, chtělo by to nějak promazat olejem.");
          } else if (_selectedItemId != null) {
            _speakHeroLine("Tohle sem nepatří.");
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
            _collectItem('iron_handle', "V trávě pod kamenným pilířem jsi našel těžkou kovanou kliku. Beru ji.");
          },
        ));
      }

      // Key under stone (New)
      final hasKey = state.roomStates['node1_has_key'] == true;
      if (!hasKey) {
        list.add(_Hotspot(
          name: "Uvolněný kámen",
          x: 0.76, y: 0.62, w: 0.1, h: 0.08,
          onTap: () {
            _service.updateRoomState('node1_has_key', true);
            _collectItem('fixed_key', "Odhrnul jsi uvolněný kámen v pilíři brány a našel klíč od brány!");
          },
        ));
      }

      // Bedna u cesty (Flavor)
      list.add(_Hotspot(
        name: "Bedna u cesty",
        x: 0.16, y: 0.72, w: 0.12, h: 0.1,
        onTap: () {
          _showDialog("Stará dřevěná bedna lesníků u cesty. Je prázdná, zbyla v ní jen trocha shnilého listí.");
        },
      ));

      // Signpost (New - Flavor)
      list.add(_Hotspot(
        name: "Rozcestník",
        x: 0.02, y: 0.35, w: 0.1, h: 0.25,
        onTap: () {
          _showDialog("Starý zvětralý ukazatel hlásá:\n'Vstup na vlastní nebezpečí! Stezka střežená čtyřmi elementy.'");
        },
      ));

      // Divoké křoví (Flavor)
      list.add(_Hotspot(
        name: "Divoké křoví",
        x: 0.85, y: 0.35, w: 0.12, h: 0.25,
        onTap: () {
          _showDialog("Husté trnité křoví podél kamenné zdi. Bez mačety nebo ohně skrz něj neprojdeš.");
        },
      ));
    } else if (widget.nodeId == 'node2') {
      // Starý dub
      // Hollow/Chest (Rune dial lock 472)
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
              _completeNodeAndPop('node2', "🔮 Vzal jsi ze schránky vyhaslý kovový amulet. Cesta lesem pokračuje dál!");
            } else {
              _showDialog("Schránka je prázdná.");
            }
            return;
          }

          // Open runic combination lock puzzle
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogicPuzzlesScreen(
                puzzleType: "combination_lock",
                correctCode: "574",
                onSolved: () {
                  _service.updateRoomState('node2_chest_open', true);
                  _speakHeroLine("Mám to! Otevřelo se to.");
                  _showDialog("🎉 Truhla v dutině cvakla a otevřela se! Uvnitř leží vyhaslý kovový amulet.");
                },
              ),
            ),
          );
        },
      ));

      // Dry stick on the ground
      final hasStick = state.roomStates['node2_has_stick'] == true;
      final hasTorchInInventory = state.inventory.contains('torch') || state.inventory.contains('burning_torch');
      final caveLit = state.roomStates['node4_cave_lit'] == true;
      final canGatherStick = !hasStick || (!state.inventory.contains('stick') && !hasTorchInInventory && !caveLit);
      if (canGatherStick) {
        list.add(_Hotspot(
          name: "Suchá větev",
          x: 0.15, y: 0.8, w: 0.2, h: 0.12,
          onTap: () {
            _service.updateRoomState('node2_has_stick', true);
            _collectItem('stick', "Sebral jsi ze země dlouhou suchou větev. Vypadá pevně, mohla by posloužit jako základ pochodně.");
          },
        ));
      }

      // Kresba na kmeni (New - clue for 472)
      list.add(_Hotspot(
        name: "Kresba na kmeni",
        x: 0.42, y: 0.42, w: 0.15, h: 0.18,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                '🔍 Vyryté znamení',
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/clue_oak_tree.png',
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Na kůře stromu je vyrytá kresba dubu. Všimni si rozdělení a počtu hlavních větví směřujících k nebi zleva doprava. Tento počet větví (3 číslice) ti napoví kód k schránce.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zavřít', style: TextStyle(color: Colors.cyanAccent)),
                ),
              ],
            ),
          );
        },
      ));

      // Squirrel on branch (New - Flavor)
      list.add(_Hotspot(
        name: "Veverka",
        x: 0.72, y: 0.32, w: 0.08, h: 0.08,
        onTap: () {
          _speakHeroLine("Jé, ahoj veverko.");
          _showDialog("Na větvi sedí rezavá veverka, zvědavě se na tebe podívá, zacvrliká a schová se do listí.");
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

            if (_selectedItemId == 'burning_torch') {
              _service.updateRoomState('node3_vines_burned', true);
              // Torch is not removed when burning vines so the player doesn't lose it
              _speakHeroLine("Mám to! Trní hoří.");
              setState(() => _selectedItemId = null);
              _showDialog("🔥 Přiložil jsi zapálenou pochodeň k ostnatému křoví. Suché větve okamžitě vzplály a spálily se na uhel! Vchod do chýše je volný.");
            } else if (_selectedItemId == 'smoldering_tinder') {
              _speakHeroLine("Tohle zelené trní nezapálí.");
              _showDialog("Doutnající troud sám o sobě nestačí na zapálení zeleného ostnatého křoví. Potřebuješ pořádný otevřený plamen, např. hořící pochodeň.");
            } else if (_selectedItemId != null) {
              _speakHeroLine("Tohle sem nepatří.");
              _showDialog("Tento předmět ti s odklizením křoví nepomůže.");
            } else {
              _showDialog("Dveře chýše jsou kompletně zarostlé tlustými ostnatými šlahouny. Holýma rukama neprojdou.");
            }
          },
        ));

        // Hromada popela (New - Element Ohně)
        final ashPlaced = state.roomStates['node6_ash_placed'] == true;
        final hasAsh = state.inventory.contains('item_ash');
        final canCollectAsh = !ashPlaced && !hasAsh;
        final hasAmuletOrPlaced = state.inventory.contains('amulet');
        if (vinesBurned && canCollectAsh && hasAmuletOrPlaced) {
          list.add(_Hotspot(
            name: "Hromada popela",
            x: 0.45, y: 0.65, w: 0.1, h: 0.1,
            onTap: () {
              _service.collectItem('item_ash');
              _showDialog("Z ohniště po spáleném křoví jsi nabral popel do amuletu jako Element Ohně.");
            },
          ));
        }

        // Hadr na plotě (New)
        final hasCloth = state.roomStates['node3_has_cloth'] == true;
        final hasTorchInInventory = state.inventory.contains('torch') || state.inventory.contains('burning_torch');
        final caveLit = state.roomStates['node4_cave_lit'] == true;
        final canGatherCloth = !hasCloth || (!state.inventory.contains('cloth') && !hasTorchInInventory && !caveLit);
        if (canGatherCloth) {
          list.add(_Hotspot(
            name: "Hadr na plotě",
            x: 0.15, y: 0.65, w: 0.1, h: 0.1,
            onTap: () {
              _service.updateRoomState('node3_has_cloth', true);
              _collectItem('cloth', "Z dřevěného plotu jsi sundal starý, olejem nasáklý hadr. Bude skvěle hořet, pokud ho připevníš na větev.");
            },
          ));
        }

        // Lupa na okně (New)
        final hasLens = state.roomStates['node3_has_lens'] == true;
        final hasTinderProductInInventory = state.inventory.contains('smoldering_tinder') || state.inventory.contains('burning_torch');
        final canGatherLens = !hasLens || (!state.inventory.contains('lens') && !hasTinderProductInInventory && !caveLit);
        if (canGatherLens) {
          list.add(_Hotspot(
            name: "Lupa na okně",
            x: 0.68, y: 0.48, w: 0.08, h: 0.08,
            onTap: () {
              _service.updateRoomState('node3_has_lens', true);
              _collectItem('lens', "Na parapetu zarostlého okna leží stará prasklá lupa. Lze ji použít jako čočku ke koncentraci slunečních paprsků.");
            },
          ));
        }

        // Mech u plotu (New)
        final hasTinder = state.roomStates['node3_has_tinder'] == true;
        final canGatherTinder = !hasTinder || (!state.inventory.contains('tinder') && !hasTinderProductInInventory && !caveLit);
        if (canGatherTinder) {
          list.add(_Hotspot(
            name: "Suchý mech",
            x: 0.82, y: 0.78, w: 0.1, h: 0.1,
            onTap: () {
              _service.updateRoomState('node3_has_tinder', true);
              _collectItem('tinder', "U paty plotového sloupku jsi nasbíral chuchvalec suchého troudu (mechu). Výborný na rozdělání ohně.");
            },
          ));
        }

        // Dřevěný plot (Flavor)
        list.add(_Hotspot(
          name: "Dřevěný plot",
          x: 0.7, y: 0.65, w: 0.2, h: 0.2,
          onTap: () {
            _showDialog("Starý chatrný dřevěný plot. Některé latě jsou shnilé a rozpadají se.");
          },
        ));
      } else {
        // Interior of Forester's Cabin
        // Grinding pot (shelf)
        final hasPot = state.roomStates['node3_has_pot'] == true;
        list.add(_Hotspot(
          name: "Police se džbánem (Kotlík)",
          x: 0.12, y: 0.35, w: 0.15, h: 0.2,
          onTap: () {
            if (!hasPot) {
              _service.updateRoomState('node3_has_pot', true);
              _collectItem('pot', "Pod převráceným hliněným džbánem na polici ležel starý měděný kotlík. Hodí se na vaření lektvarů.");
              _checkNode3Completion(state);
            } else {
              _showDialog("Police je prázdná.");
            }
          },
        ));

        // Well handle in drawer (New)
        final hasWellHandle = state.roomStates['node3_has_well_handle'] == true;
        list.add(_Hotspot(
          name: "Zásuvka stolu",
          x: 0.28, y: 0.6, w: 0.22, h: 0.22,
          onTap: () {
            if (!hasWellHandle) {
              _service.updateRoomState('node3_has_well_handle', true);
              _collectItem('well_handle', "Otevřel jsi zásuvku dílenského stolu a našel v ní masivní železnou kliku od studničního navijáku!");
              _checkNode3Completion(state);
            } else {
              _showDialog("Zásuvka je prázdná.");
            }
          },
        ));

        // Diary
        list.add(_Hotspot(
          name: "Starý sešit",
          x: 0.42, y: 0.58, w: 0.15, h: 0.12,
          onTap: () {
            _showDialog("Čteš z Deníku hajného:\n'Našel jsem v bažinách studnu a vedle ní svatyni. Kliku od navijáku studny si schovávám k sobě do chýše do zásuvky, aby z ní nikdo cizí nepil. Studna je těžká a k vytažení vědra vyžaduje přesné vyvážení (25 kg)...'");
          },
        ));

        // Chest
        list.add(_Hotspot(
          name: "Železná truhla",
          x: 0.72, y: 0.62, w: 0.18, h: 0.18,
          onTap: () {
            _showDialog("Stará železná truhla. Zámek je rozbitý a je zcela prázdná.");
          },
        ));

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
        final waterTaken = state.roomStates['node4_water_taken'] == true;

        list.add(_Hotspot(
          name: "Kamenná studna",
          x: 0.4, y: 0.4, w: 0.24, h: 0.38,
          onTap: () {
            final hasWaterOrPlaced = state.inventory.contains('pure_water') || state.roomStates['node6_water_placed'] == true;
            if (waterTaken && hasWaterOrPlaced) {
              _showDialog("Ve studni zbývá už jen zablácené dno, kbelík s čistou pramenitou vodou jsi již vzal.");
              return;
            }

            if (wellHandlePlaced) {
              final wellBalanced = state.roomStates['node4_well_balanced'] == true;
              if (wellBalanced) {
                _service.updateRoomState('node4_water_taken', true);
                _collectItem('pure_water', "💧 Vzal jsi kbelík s čistou pramenitou vodou ze studny!");
              } else {
                _showDialog("Zdvihací mechanismus studny je zablokován těžkým kbelíkem. Kbelík nelze vytáhnout, dokud nevyvážíš protizávaží na váze ve stodole.");
              }
            } else if (_selectedItemId == 'well_handle') {
              _service.updateRoomState('node4_well_handle', true);
              _service.removeItem('well_handle');
              setState(() => _selectedItemId = null);
              _showDialog("Nasadil jsi kliku navijáku na osu studny. Zkus ji otočit.");
            } else {
              _showDialog("Stará studna je hluboká a navijáku chybí otočná rukojeť, lano nejde navinout. Hned vedle studny se nachází váha ve stodole.");
            }
          },
        ));

        // Barn hotspot (Stodola) instead of Váha
        list.add(_Hotspot(
          name: "Stodola",
          x: 0.65, y: 0.38, w: 0.2, h: 0.35,
          onTap: () {
            setState(() {
              _currentSubroom = "barn";
              _dialogText = "Vstoupil jsi do staré zaprášené stodoly. V rohu stojí masivní mechanismus váhy spojený se studnou.";
            });
          },
        ));

      } else if (_currentSubroom == "cave") {
        // Uvnitř jeskyně
        final caveLit = state.roomStates['node4_cave_lit'] == true;

        if (!caveLit) {
          list.add(_Hotspot(
            name: "Černočerná tma",
            x: 0.2, y: 0.2, w: 0.6, h: 0.6,
            onTap: () {
              if (_selectedItemId == 'burning_torch') {
                _service.updateRoomState('node4_cave_lit', true);
                _service.removeItem('burning_torch');
                setState(() => _selectedItemId = null);
                _showDialog("🔥 Pomocí zapálené pochodně jsi rozkřesal staré ohniště uprostřed jeskyně! Plameny ozářily kamenné stěny a v rohu jsi spatřil ležet nemocného poustevníka.");
              } else {
                _showDialog("V jeskyni je naprostá tma a chlad. Bez zdroje světla, jako je zapálená pochodeň (vyrobíš spojením větve a hadru a zapálením u troudu), se neodvážíš jít dál.");
              }
            },
          ));
        } else {
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

          // Ohniště (Vaření) - Brew potion inside lit cave (requires pure water + blue mushrooms + pot)
          if (state.inventory.contains('pure_water') && state.inventory.contains('blue_mushrooms')) {
            list.add(_Hotspot(
              name: "Ohniště (Vaření)",
              x: 0.62, y: 0.72, w: 0.15, h: 0.15,
              onTap: () {
                _service.removeItem('pure_water');
                _service.removeItem('blue_mushrooms');
                _service.collectItem('potion');
                _speakHeroLine("Podařilo se!");
                _showDialog("🍯 Svařil jsi modré houby v čisté destilované vodě v kotlíku. Získal jsi zářící modrý léčivý elixír!");
              },
            ));
          }
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

      } else if (_currentSubroom == "barn") {
        // Váha (Detail) click
        list.add(_Hotspot(
          name: "Váha (Detail)",
          x: 0.35, y: 0.3, w: 0.3, h: 0.5,
          onTap: () {
            setState(() {
              _currentSubroom = "scale_zoom";
              _dialogText = state.roomStates['node4_barn_cleaned'] == true
                  ? "Detailní pohled na očištěnou váhu. Všechny piktogramy jsou jasně čitelné."
                  : "Pohled na starou váhu. Je zcela pokrytá prachem a pavučinami. Štítek s piktogramy není čitelný.";
            });
          },
        ));

        // Return button
        list.add(_Hotspot(
          name: "Odejít ven",
          x: 0.42, y: 0.82, w: 0.16, h: 0.12,
          onTap: () {
            setState(() {
              _currentSubroom = "exterior";
              _dialogText = "Stojíš venku v bažině.";
            });
          },
        ));

      } else if (_currentSubroom == "scale_zoom") {
        final wellHandlePlaced = state.roomStates['node4_well_handle'] == true;
        final waterTaken = state.roomStates['node4_water_taken'] == true;
        final barnCleaned = state.roomStates['node4_barn_cleaned'] == true;

        if (!barnCleaned) {
          // Clean the scale hotspot (click anywhere on the scale to clean)
          list.add(_Hotspot(
            name: "Očistit váhu",
            x: 0.2, y: 0.2, w: 0.6, h: 0.6,
            onTap: () {
              _service.updateRoomState('node4_barn_cleaned', true);
              _showDialog("Setřel jsi nánosy prachu a pavučin z kovového štítku. Piktogramy kbelíku, vah a přetrženého lana jsou nyní krásně vidět!");
            },
          ));
        } else {
          // Cleaned scale interaction (run the puzzle)
          list.add(_Hotspot(
            name: "Mechanismus váhy",
            x: 0.25, y: 0.25, w: 0.5, h: 0.5,
            onTap: () {
              if (waterTaken) {
                _showDialog("Voda je již úspěšně vytažena, váhu už není potřeba používat.");
                return;
              }

              if (wellHandlePlaced) {
                final wellBalanced = state.roomStates['node4_well_balanced'] == true;
                if (wellBalanced) {
                  _showDialog("Váha je již úspěšně vyvážena.");
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LogicPuzzlesScreen(
                        puzzleType: "scales",
                        onSolved: () {
                          _service.updateRoomState('node4_well_balanced', true);
                          _showDialog("⚙️ Vyvážil jsi protizávaží studny! Otočil jsi klikou a kbelík s čistou pramenitou vodou se s tichým zavrzáním vytáhl nahoru.");
                        },
                      ),
                    ),
                  );
                }
              } else {
                _showDialog("Mechanismus váhy je propojen s navijákem studny. Nejdříve musíš nasadit kliku studny na osu navijáku.");
              }
            },
          ));
        }

        // Return button
        list.add(_Hotspot(
          name: "Zpět do stodoly",
          x: 0.42, y: 0.82, w: 0.16, h: 0.12,
          onTap: () {
            setState(() {
              _currentSubroom = "barn";
              _dialogText = "Stojíš uvnitř stodoly.";
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
                    },
                  ),
                ),
              ).then((_) {
                final solved = _service.stateNotifier.value.roomStates['node5_puzzle_solved'] == true;
                if (solved) {
                  _showDialog("🎉 Správně jsi zaměřil všechna 3 souhvězdí! Dalekohled se uzamkl a paprsek světla ukázal přesnou lokaci kamenného oltáře.");
                  Future.delayed(const Duration(milliseconds: 3000), () {
                    if (mounted) {
                      Navigator.pop(context, true);
                    }
                  });
                }
              });
            }
          },
        ));

        // Gather dust element (requires amulet or placed)
        final dustPlaced = state.roomStates['node6_dust_placed'] == true;
        final hasDust = state.inventory.contains('item_dust');
        final canCollectDust = !dustPlaced && !hasDust;
        final hasAmuletOrPlaced = state.inventory.contains('amulet');
        if (canCollectDust && hasAmuletOrPlaced) {
          list.add(_Hotspot(
            name: "Starý regál",
            x: 0.72, y: 0.25, w: 0.18, h: 0.32,
            onTap: () {
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
            // Start final Concentric Rune Board puzzle!
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LogicPuzzlesScreen(
                  puzzleType: "rune_ritual",
                  onSolved: () async {
                    _service.updateRoomState('node6_amulet_active', true);
                    _service.completeNode('node6');
                    await _service.claimFinalReward();
                  },
                ),
              ),
            ).then((_) {
              final active = _service.stateNotifier.value.roomStates['node6_amulet_active'] == true;
              if (active) {
                _showDialog("🏆 Úspěšně jsi dokončil celou výpravu! Získal jsi 50 Limenek a tvůj zvířecí maskot slaví vítězství!");
                Future.delayed(const Duration(milliseconds: 3500), () {
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                });
              }
            });
            return;
          }

          // Get current placement status from roomStates (4 elements only)
          bool ashPlaced = state.roomStates['node6_ash_placed'] == true;
          bool waterPlaced = state.roomStates['node6_water_placed'] == true;
          bool dustPlaced = state.roomStates['node6_dust_placed'] == true;
          bool saltPlaced = state.roomStates['node6_salt_placed'] == true;

          final List<String> itemsToRemove = [];
          final Map<String, dynamic> roomStatesToUpdate = {};
          final List<String> placedNow = [];

          // Try placing ash
          if (!ashPlaced && state.inventory.contains('item_ash')) {
            itemsToRemove.add('item_ash');
            roomStatesToUpdate['node6_ash_placed'] = true;
            ashPlaced = true;
            placedNow.add("Popel (Oheň) 🔥");
          }

          // Try placing water
          final hasWater = state.inventory.contains('item_water') || state.inventory.contains('pure_water');
          if (!waterPlaced && hasWater) {
            if (state.inventory.contains('item_water')) {
              itemsToRemove.add('item_water');
            } else if (state.inventory.contains('pure_water')) {
              itemsToRemove.add('pure_water');
            }
            roomStatesToUpdate['node6_water_placed'] = true;
            waterPlaced = true;
            placedNow.add("Čistou vodu (Voda) 💦");
          }

          // Try placing dust
          if (!dustPlaced && state.inventory.contains('item_dust')) {
            itemsToRemove.add('item_dust');
            roomStatesToUpdate['node6_dust_placed'] = true;
            dustPlaced = true;
            placedNow.add("Prach (Vzduch) 💨");
          }

          // Try placing salt
          if (!saltPlaced && state.inventory.contains('item_salt')) {
            itemsToRemove.add('item_salt');
            roomStatesToUpdate['node6_salt_placed'] = true;
            saltPlaced = true;
            placedNow.add("Horskou sůl (Země) 🌱");
          }

          // Check if all are now placed
          final allPlaced = ashPlaced && waterPlaced && dustPlaced && saltPlaced;
          if (allPlaced) {
            roomStatesToUpdate['node6_elements_placed'] = true;
          }

          // Execute single batch update if any changes made
          if (itemsToRemove.isNotEmpty || roomStatesToUpdate.isNotEmpty) {
            _service.batchUpdate(
              itemsToRemove: itemsToRemove,
              roomStatesToUpdate: roomStatesToUpdate,
            );
          }

          if (allPlaced) {
            _showDialog("🔮 Všechny 4 elementy byly úspěšně rozmístěny na oltář! Oltář se rozsvítil zářivým tyrkysovým světlem. Klikni na něj znovu a zahaj aktivaci.");
            return;
          }

          if (placedNow.isNotEmpty) {
            _showDialog("Vložil jsi do oltáře: ${placedNow.join(', ')}.\n\nStav oltáře:\n"
                "${ashPlaced ? '✅ Popel (Oheň)' : '❌ Chybí Popel (Oheň)'}\n"
                "${waterPlaced ? '✅ Čistá voda (Voda)' : '❌ Chybí Čistá voda (Voda)'}\n"
                "${dustPlaced ? '✅ Prach (Vzduch)' : '❌ Chybí Prach (Vzduch)'}\n"
                "${saltPlaced ? '✅ Horská sůl (Země)' : '❌ Chybí Horská sůl (Země)'}");
          } else {
            _showDialog("K oltáři jsi neměl co nového přiložit.\n\nStav oltáře:\n"
                "${ashPlaced ? '✅ Popel (Oheň)' : '❌ Chybí Popel (Oheň)'}\n"
                "${waterPlaced ? '✅ Čistá voda (Voda)' : '❌ Chybí Čistá voda (Voda)'}\n"
                "${dustPlaced ? '✅ Prach (Vzduch)' : '❌ Chybí Prach (Vzduch)'}\n"
                "${saltPlaced ? '✅ Horská sůl (Země)' : '❌ Chybí Horská sůl (Země)'}");
          }
        },
      ));

      // Salt hotspot (requires amulet or placed)
      final saltPlaced = state.roomStates['node6_salt_placed'] == true;
      final hasSalt = state.inventory.contains('item_salt');
      final canCollectSalt = !saltPlaced && !hasSalt;
      final hasAmuletOrPlaced = state.inventory.contains('amulet');
      if (canCollectSalt && hasAmuletOrPlaced) {
        list.add(_Hotspot(
          name: "Skalní trhlina (Sůl)",
          x: 0.08, y: 0.65, w: 0.18, h: 0.18,
          onTap: () {
            _service.collectItem('item_salt');
            _showDialog("V trhlině skály se vysrážela čistá horská sůl. Nabral jsi ji do amuletu jako Element Země.");
          },
        ));
      }
    }

    return list;
  }

  Widget? _buildItemOverlay(String name) {
    String? itemId;
    double scale = 0.55;
    Alignment alignment = Alignment.center;

    if (name == "Klika v trávě") {
      itemId = 'iron_handle';
      scale = 0.45;
      alignment = Alignment.bottomCenter;
    } else if (name == "Uvolněný kámen") {
      itemId = 'dirty_key';
      scale = 0.35;
      alignment = const Alignment(0.3, 0.4);
    } else if (name == "Bedna u cesty") {
      itemId = 'oil';
      scale = 0.35;
      alignment = const Alignment(-0.2, 0.3);
    } else if (name == "Suchá větev") {
      itemId = 'stick';
      scale = 0.65;
      alignment = Alignment.center;
    } else if (name == "Hadr na plotě") {
      itemId = 'cloth';
      scale = 0.55;
      alignment = Alignment.center;
    } else if (name == "Lupa na okně") {
      itemId = 'lens';
      scale = 0.4;
      alignment = Alignment.center;
    } else if (name == "Suchý mech") {
      itemId = 'tinder';
      scale = 0.5;
      alignment = Alignment.bottomCenter;
    } else if (name == "Police se džbánem (Kotlík)") {
      itemId = 'pot';
      scale = 0.6;
      alignment = Alignment.bottomCenter;
    } else if (name == "Modré houby") {
      itemId = 'blue_mushrooms';
      scale = 0.55;
      alignment = Alignment.center;
    } else if (name == "Měděný kotlík") {
      itemId = 'pot';
      scale = 0.55;
      alignment = Alignment.center;
    } else if (name == "Měděná trubka") {
      itemId = 'copper_pipe';
      scale = 0.55;
      alignment = Alignment.center;
    } else if (name == "Hromada popela") {
      itemId = 'item_ash';
      scale = 0.55;
      alignment = Alignment.center;
    } else if (name == "Starý regál") {
      itemId = 'item_dust';
      scale = 0.55;
      alignment = Alignment.center;
    } else if (name == "Skalní trhlina (Sůl)") {
      itemId = 'item_salt';
      scale = 0.55;
      alignment = Alignment.center;
    }


    if (itemId == null) return null;

    return Align(
      alignment: alignment,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: 0.85,
          child: InventoryItemIcon(itemId: itemId, size: 48),
        ),
      ),
    );
  }

  String _getRoomBackground(QuestState state) {
    if (widget.nodeId == 'node1') {
      final isGateOpen = state.roomStates['node1_gate_open'] == true;
      return isGateOpen
          ? 'assets/images/story_room_gate_open.png'
          : 'assets/images/story_room_gate_closed.png';
    } else if (widget.nodeId == 'node2') {
      return 'assets/images/story_room_oak.png';
    } else if (widget.nodeId == 'node3') {
      if (_currentSubroom == "interior") {
        final chestOpen = state.roomStates['node3_chest_open'] == true;
        return chestOpen
            ? 'assets/images/story_room_cabin_interior_open_chest.png'
            : 'assets/images/story_room_cabin_interior.png';
      }

      final hasCloth = state.roomStates['node3_has_cloth'] == true;
      final vinesBurned = state.roomStates['node3_vines_burned'] == true;
      if (vinesBurned) {
        return 'assets/images/story_room_cabin_exterior_burned.png';
      } else if (!hasCloth) {
        return 'assets/images/story_room_cabin_exterior_with_cloth.png';
      } else {
        return 'assets/images/story_room_cabin_exterior.png';
      }
    } else if (widget.nodeId == 'node4') {
      if (_currentSubroom == "cave") {
        final caveLit = state.roomStates['node4_cave_lit'] == true;
        return caveLit
            ? 'assets/images/story_room_cave_lit.png'
            : 'assets/images/story_room_cave.png';
      } else if (_currentSubroom == "barn") {
        final barnCleaned = state.roomStates['node4_barn_cleaned'] == true;
        return barnCleaned
            ? 'assets/images/story_room_barn_interior_clean.png'
            : 'assets/images/story_room_barn_interior.png';
      } else if (_currentSubroom == "scale_zoom") {
        final barnCleaned = state.roomStates['node4_barn_cleaned'] == true;
        return barnCleaned
            ? 'assets/images/story_room_barn_scale_clean.png'
            : 'assets/images/story_room_barn_scale_dusty.png';
      }
      final caveLit = state.roomStates['node4_cave_lit'] == true;
      final wellBalanced = state.roomStates['node4_well_balanced'] == true;
      final waterTaken = state.roomStates['node4_water_taken'] == true;
      if (caveLit) {
        if (waterTaken) {
          return 'assets/images/story_room_swamp_cave_lit_hook_only.png';
        } else if (wellBalanced) {
          return 'assets/images/story_room_swamp_cave_lit_bucket_up.png';
        } else {
          return 'assets/images/story_room_swamp_cave_lit.png';
        }
      } else {
        if (waterTaken) {
          return 'assets/images/story_room_swamp_hook_only.png';
        } else if (wellBalanced) {
          return 'assets/images/story_room_swamp_bucket_up.png';
        } else {
          return 'assets/images/story_room_swamp.png';
        }
      }
    } else if (widget.nodeId == 'node5') {
      if (_currentSubroom == "library") {
        final solved = state.roomStates['node5_puzzle_solved'] == true;
        return solved
            ? 'assets/images/story_room_observatory_solved.png'
            : 'assets/images/story_room_observatory.png';
      }
      final hasSword = state.roomStates['node5_has_sword'] == true;
      return hasSword
          ? 'assets/images/story_room_fortress_exterior_turned.png'
          : 'assets/images/story_room_fortress_exterior.png';
    } else if (widget.nodeId == 'node6') {
      return 'assets/images/story_room_altar.png';
    }
    return 'assets/images/story_room_gate_closed.png';
  }

  Color _getRoomColorFilter(QuestState state) {
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
            final colorFilter = _getRoomColorFilter(state);

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
                                  : widget.nodeId == 'node4' && _currentSubroom == 'barn'
                                      ? 'Stodola'
                                  : widget.nodeId == 'node4' && _currentSubroom == 'scale_zoom'
                                      ? 'Detail váhy'
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

                          // Částicové počasí a animace na scénách
                          if (widget.nodeId == 'node2')
                            const Positioned.fill(
                              child: ImmersiveWeatherParticles(particleType: 'leaves'),
                            ),
                          if (widget.nodeId == 'node3')
                            const Positioned.fill(
                              child: ImmersiveWeatherParticles(particleType: 'leaves'),
                            ),
                          if (widget.nodeId == 'node4')
                            Positioned.fill(
                              child: ImmersiveWeatherParticles(
                                particleType: _currentSubroom == 'shrine' ? 'fireflies' : 'fog',
                              ),
                            ),
                          if (widget.nodeId == 'node6')
                            const Positioned.fill(
                              child: ImmersiveWeatherParticles(particleType: 'magic'),
                            ),

                          // Render Interactive Hotspots
                          ...hotspots.map((hs) {
                            final overlay = _buildItemOverlay(hs.name);
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
                                  child: overlay,
                                ),
                              ),
                            );
                          }),

                          // Visual Novel Dialogue Overlay
                          if (_dialogueCharacterName != null)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.6),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _onDialogueAreaTap,
                                        child: const SizedBox.expand(),
                                      ),
                                    ),

                                    // 1. Left Character (NPC) - Simple Bust in Corner
                                    if (_dialogueCharacterAsset != null)
                                      Positioned(
                                        left: 8,
                                        bottom: 40,
                                        width: 160,
                                        height: 320,
                                        child: IgnorePointer(
                                          child: AnimatedOpacity(
                                            duration: const Duration(milliseconds: 200),
                                            opacity: _isNpcActive ? 1.0 : 0.45,
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              transform: Matrix4.identity()
                                                ..scale(_isNpcActive ? 1.05 : 0.95),
                                              transformAlignment: Alignment.bottomCenter,
                                              child: Transform(
                                                alignment: Alignment.center,
                                                transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                                                child: ColorFiltered(
                                                  colorFilter: const ColorFilter.matrix(<double>[
                                                    1, 0, 0, 0, 0,
                                                    0, 1, 0, 0, 0,
                                                    0, 0, 1, 0, 0,
                                                    -1, -1, -1, 3, 0,
                                                  ]),
                                                  child: Image.asset(
                                                    _dialogueCharacterAsset!,
                                                    fit: BoxFit.contain,
                                                    alignment: Alignment.bottomCenter,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // 2. Right Character (Player) - Simple Bust in Corner
                                    if (_playerCharacterAsset != null)
                                      Positioned(
                                        right: 8,
                                        bottom: 40,
                                        width: 160,
                                        height: 320,
                                        child: IgnorePointer(
                                          child: AnimatedOpacity(
                                            duration: const Duration(milliseconds: 200),
                                            opacity: _isPlayerActive ? 1.0 : 0.45,
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              transform: Matrix4.identity()
                                                ..scale(_isPlayerActive ? 1.05 : 0.95),
                                              transformAlignment: Alignment.bottomCenter,
                                              child: ColorFiltered(
                                                colorFilter: const ColorFilter.matrix(<double>[
                                                  1, 0, 0, 0, 0,
                                                  0, 1, 0, 0, 0,
                                                  0, 0, 1, 0, 0,
                                                  -1, -1, -1, 3, 0,
                                                ]),
                                                child: Image.asset(
                                                  _playerCharacterAsset!,
                                                  fit: BoxFit.contain,
                                                  alignment: Alignment.bottomCenter,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    
                                    // 3. Dialogue Panel at the bottom
                                    Positioned(
                                      left: 16,
                                      right: 16,
                                      bottom: 16,
                                      height: 150,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xF20F0F0F),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.grey.shade800, width: 1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.6),
                                              blurRadius: 16,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _isNpcActive
                                                  ? (_dialogueCharacterName ?? "NPC")
                                                  : "Ty",
                                              style: TextStyle(
                                                color: _isNpcActive ? Colors.limeAccent : Colors.cyanAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: SingleChildScrollView(
                                                child: Text(
                                                  _dialogText,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    height: 1.45,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_dialogueScriptIndex < _dialogueScript.length - 1 || _dialogueChoices.isEmpty)
                                              const Align(
                                                alignment: Alignment.bottomRight,
                                                child: Text(
                                                  'Klepnutím pokračuj ▷',
                                                  style: TextStyle(color: Colors.white38, fontSize: 9, fontStyle: FontStyle.italic),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 4. Floating Choices Overlay
                                    if (_dialogueScriptIndex == _dialogueScript.length - 1 && _dialogueChoices.isNotEmpty)
                                      Center(
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 32),
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.lime.shade700, width: 1.5),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Vyber odpověď:',
                                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 16),
                                              ..._dialogueChoices.map((opt) {
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 12),
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.lime.shade800,
                                                      foregroundColor: Colors.black,
                                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        side: const BorderSide(color: Colors.lime, width: 1.5),
                                                      ),
                                                    ),
                                                    onPressed: opt.onTap,
                                                    child: Text(opt.text),
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                // 3. Dialog Box
                if (_dialogueCharacterName == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade900,
                    height: 110,
                    child: SingleChildScrollView(
                      child: Text(
                        _dialogText,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45),
                      ),
                    ),
                  ),

                // 4. Inventory Bar
                if (_dialogueCharacterName == null)
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

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedItemId = null;
                                    } else if (_selectedItemId != null) {
                                      final success = _tryCombineItems(_selectedItemId!, itemId);
                                      if (success) {
                                        _selectedItemId = null;
                                      } else {
                                        _selectedItemId = itemId;
                                        _dialogText = "${item.name}: ${item.description}";
                                      }
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
                                      InventoryItemIcon(
                                        itemId: itemId,
                                        size: 32,
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

class _DialogueLine {
  final String speaker; // 'npc' or 'player'
  final String text;

  _DialogueLine({
    required this.speaker,
    required this.text,
  });
}

class InventoryItemIcon extends StatelessWidget {
  final String itemId;
  final double size;

  const InventoryItemIcon({required this.itemId, this.size = 32, super.key});

  @override
  Widget build(BuildContext context) {
    // Grid 1: 4x4
    final Map<String, List<int>> grid1 = {
      'stick': [0, 0],
      'cloth': [1, 0],
      'torch': [2, 0],
      'burning_torch': [3, 0],
      
      'tinder': [0, 1],
      'lens': [1, 1],
      'smoldering_tinder': [2, 1],
      'oil': [3, 1],
      
      'dirty_key': [0, 2],
      'fixed_key': [1, 2],
      'pot': [2, 2],
      'pure_water': [3, 2],
      
      'blue_mushrooms': [0, 3],
      'potion': [1, 3],
      'well_handle': [2, 3],
      'triangular_key': [3, 3],
    };

    // Grid 2: 3x4
    final Map<String, List<int>> grid2 = {
      'amulet': [0, 0],
      'key_armory': [1, 0],
      'stone_sword': [2, 0],
      
      'acid': [0, 1],
      'clean_lens': [1, 1],
      'item_ash': [2, 1],
      
      'item_salt': [0, 2],
      'item_dust': [1, 2],
      'item_water': [2, 2],
      
      'copper_pipe': [0, 3],
      'iron_handle': [1, 3],
    };

    String assetPath;
    int cols, rows;
    int col, row;

    if (grid1.containsKey(itemId)) {
      assetPath = 'assets/images/items_grid_one.png';
      cols = 4;
      rows = 4;
      col = grid1[itemId]![0];
      row = grid1[itemId]![1];
    } else if (grid2.containsKey(itemId)) {
      assetPath = 'assets/images/items_grid_two.png';
      cols = 3;
      rows = 4;
      col = grid2[itemId]![0];
      row = grid2[itemId]![1];
    } else {
      // Fallback
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
        'stick': '🪵',
        'cloth': '🧹',
        'torch': '🔦',
        'burning_torch': '🔥',
      };
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Text(
          emojis[itemId] ?? '🎒',
          style: TextStyle(fontSize: size * 0.7),
        ),
      );
    }

    final alignX = cols > 1 ? -1.0 + 2.0 * col / (cols - 1) : 0.0;
    final alignY = rows > 1 ? -1.0 + 2.0 * row / (rows - 1) : 0.0;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FractionallySizedBox(
          widthFactor: cols.toDouble(),
          heightFactor: rows.toDouble(),
          alignment: Alignment(alignX, alignY),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              1, 0, 0, 0, 0,
              0, 1, 0, 0, 0,
              0, 0, 1, 0, 0,
              -1, -1, -1, 3, 0,
            ]),
            child: Image.asset(
              assetPath,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}
