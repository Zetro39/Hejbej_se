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

class _PointAndClickScreenState extends State<PointAndClickScreen> with SingleTickerProviderStateMixin {
  final StoryGameService _service = StoryGameService();
  String? _selectedItemId;
  final FlutterTts _tts = FlutterTts();
  late AnimationController _pulseController;
  bool _highlightCombineTutorial = false;

  void _speakHeroLine(String line) {
    // voiceover disabled due to robot-like TTS quality
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
  Offset? _debugTapOffset;
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _setInitialDialog();
    _loadPlayerAvatar();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
    // 4. blue_mushrooms + item_water -> potion (only consumes blue_mushrooms)
    if (id1 == 'blue_mushrooms' && id2 == 'item_water') {
      _service.removeItem('blue_mushrooms');
      _service.collectItem('potion'); _speakHeroLine("Podařilo se!");
      _showDialog("🍵 Svařil jsi modré houby s čistou vodou a vyrobil zářící Léčivý elixír!");
      return true;
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
          _service.completeNode('node4');
          setState(() {
            _selectedItemId = null;
          });
          final updatedState = _service.stateNotifier.value;

          final healScript = [
            _DialogueLine(speaker: 'player', text: "Tady, vypijte tohle! Svařil jsem modré houby v destilované vodě."),
            _DialogueLine(speaker: 'npc', text: "🍵 (Lok... lok...) Oh! Ta léčivá síla... chlad stoupá do mých spánků..."),
            _DialogueLine(speaker: 'npc', text: "Horečka ustupuje! Zachránil jsi mi život, poutníku."),
            _DialogueLine(speaker: 'npc', text: "Děkuji ti. Pokud chceš vědět něco o tomto místě nebo o oltáři, klidně se zeptej."),
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

    final hasMushrooms = state.inventory.contains('blue_mushrooms') || state.roomStates['node2_mushrooms_taken'] == true;
    if (!hasMushrooms) {
      choices.add(_DialogueOption(
        text: "Kde najdu ty modré houby?",
        onTap: () {
          final mushroomScript = [
            _DialogueLine(speaker: 'player', text: "Kde přesně rostou ty modré houby? Prohledal jsem okolí a nic jsem neviděl."),
            _DialogueLine(speaker: 'npc', text: "Rostou v hlubokém lese u kořenů prastarých stromů, například pod kořeny velkého starého dubu."),
            _DialogueLine(speaker: 'npc', text: "Svítí výrazným modrým světlem, takže je snadno uvidíš."),
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
    }

    final hasWater = state.inventory.contains('item_water') || state.roomStates['node4_water_taken'] == true;
    if (!hasWater) {
      choices.add(_DialogueOption(
        text: "Kde získám čistou vodu?",
        onTap: () {
          final waterScript = [
            _DialogueLine(speaker: 'player', text: "Voda v bažině je otrávená a špinavá. Jak mám získat čistou vodu pro lektvar?"),
            _DialogueLine(speaker: 'npc', text: "Venku v bažinách je stará kamenná studna. Voda v ní je čistá, ale naviják studny je zablokovaný těžkým kbelíkem."),
            _DialogueLine(speaker: 'npc', text: "Musíš jít do stodoly a vyvážit protizávaží studny na váze."),
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
    }

    choices.add(_DialogueOption(
      text: "Pokusím se ten elixír uvařit.",
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
            _DialogueLine(speaker: 'npc', text: "Musíš ho získat z truhly ukryté v dutině starého dubu."),
            _DialogueLine(speaker: 'npc', text: "Jakmile ho budeš mít, odnes ho k oltáři věčnosti na vrcholku skály."),
            _DialogueLine(speaker: 'npc', text: "K provedení rituálu budeš muset shromáždit 4 elementy a umístit je do příslušných slotů na oltáři."),
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
        text: "Kde najdu ty 4 elementy?",
        onTap: () {
          final elementScript = [
            _DialogueLine(speaker: 'player', text: "Kde najdu ty 4 elementy, které oltář vyžaduje?"),
            _DialogueLine(speaker: 'npc', text: "Všechny leží na místech, která jsi navštívil nebo brzy navštívíš:"),
            _DialogueLine(speaker: 'npc', text: "Popel (Oheň) vezmi z ohniště u chýše lesníka."),
            _DialogueLine(speaker: 'npc', text: "Destilovanou vodu (Voda) získáš ze studny zde v bažinách."),
            _DialogueLine(speaker: 'npc', text: "Prach (Vzduch) setři ze starého regálu v knihovně pevnosti."),
            _DialogueLine(speaker: 'npc', text: "A posvátný kámen (Země) najdeš přímo v kamenné mohyle u oltáře."),
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
        text: "Zajímavosti o bažinách 💬",
        onTap: () {
          final swampScript = [
            _DialogueLine(speaker: 'player', text: "Můžete mi říct něco zajímavého o těchto bažinách?"),
            _DialogueLine(speaker: 'npc', text: "Tyto bažiny jsou plné magického oparu. Lidé říkají, že v noci světélkují."),
            _DialogueLine(speaker: 'npc', text: "Není to ale kouzlo, nýbrž zvláštní světélkující houby a hmyz, který se živí jejich mízou."),
            _DialogueLine(speaker: 'npc', text: "Pokud se tu ztratíš, jdi vždy za světlem, ale dávej pozor na hluboká rašeliniště."),
          ];
          _startDialogueScript(
            "Poustevník",
            "assets/images/story_npc_hermit.png",
            swampScript,
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
        text: "Děkuji, jdu dál.",
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
    if (state.roomStates['node5_astronomer_asked_help'] != true) {
      _service.updateRoomState('node5_astronomer_asked_help', true);
    }
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
            _DialogueLine(speaker: 'npc', text: "Hledej popel v ohništi u chýše lesníka, vodu z bažiny, prach ze starého regálu za mnou a posvátný kámen v kamenné mohyle u oltáře."),
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
            _DialogueLine(speaker: 'npc', text: "Nyní musíme dalekohled zaměřit na souhvězdí Medvěda, Vlka a Jelena. Podívej se do objektivu a zkus je najít na obloze!"),
          ];

          _startDialogueScript(
            "Hvězdopravec",
            "assets/images/story_npc_astronomer.png",
            placeScript,
            [
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
        x: 0.35, y: 0.2, w: 0.3, h: 0.55,
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
            _showDialog("Masivní brána z dubového dřeva. Zámek je zrezivélý a chybí klika.");
          }
        },
      ));

      // Starý pařez (Sparkling!)
      final hasStumpItems = state.roomStates['node1_stump_checked'] == true;
      if (!hasStumpItems) {
        list.add(_Hotspot(
          name: "Starý pařez",
          x: 0.1, y: 0.7, w: 0.25, h: 0.2,
          showSparkle: true,
          onTap: () {
            _service.updateRoomState('node1_stump_checked', true);
            _service.collectItem('dirty_key');
            _service.collectItem('oil');
            _speakHeroLine("To se bude hodit.");
            setState(() {
              _highlightCombineTutorial = true;
            });
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text(
                  '💡 Výuka kombinování',
                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                content: const Text(
                  "Některé předměty v inventáři můžeš kombinovat!\n\nZkus vybrat jeden předmět (např. Olej na rez) a potom klepnout na druhý předmět (Zanesený klíč) v inventáři na dolním panelu.",
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Rozumím', style: TextStyle(color: Colors.cyanAccent)),
                  ),
                ],
              ),
            );
            _showDialog("Našel jsi Zanesený klíč a Olej na rez! Zkus je v inventáři spojit.");
          },
        ));
      }
    } else if (widget.nodeId == 'node2') {
      // Starý dub
      // Hollow/Chest (Rune dial lock 674)
      final chestOpen = state.roomStates['node2_chest_open'] == true;
      list.add(_Hotspot(
        name: "Dutina u kořenů",
        x: 0.42, y: 0.68, w: 0.18, h: 0.15,
        onTap: () {
          if (chestOpen) {
            final chestTaken = state.roomStates['node2_chest_taken'] == true;
            if (!chestTaken) {
              _service.batchUpdate(
                roomStatesToUpdate: {'node2_chest_taken': true},
              );
              _collectItem('lens', "🔎 Uvnitř truhly jsi našel lupu (zvětšovací sklo)! To by se mohlo hodit na soustředění slunečních paprsků.");
            } else {
              _completeNodeAndPop('node2', "🔮 Otevřel jsi tajnou schránku! Dozvěděl ses o oltáři věčnosti. Cesta lesem pokračuje dál!");
            }
            return;
          }

          // Open runic combination lock puzzle
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogicPuzzlesScreen(
                puzzleType: "combination_lock",
                correctCode: "674",
                onSolved: () {
                  _service.updateRoomState('node2_chest_open', true);
                  _speakHeroLine("Mám to! Otevřelo se to.");
                  _showDialog("🎉 Truhla v dutině cvakla a otevřela se!");
                },
              ),
            ),
          );
        },
      ));

      // Dry stick on the ground (Broken signpost)
      final hasStick = state.roomStates['node2_has_stick'] == true;
      final hasTorchInInventory = state.inventory.contains('torch') || state.inventory.contains('burning_torch');
      final caveLit = state.roomStates['node4_cave_lit'] == true;
      final canGatherStick = !hasStick || (!state.inventory.contains('stick') && !hasTorchInInventory && !caveLit);
      if (canGatherStick) {
        list.add(_Hotspot(
          name: "Rozpadlá značka",
          x: 0.15, y: 0.8, w: 0.2, h: 0.12,
          onTap: () {
            _service.updateRoomState('node2_has_stick', true);
            _collectItem('stick', "Hele, rozpadlá značka. Ten sloupek si vezmu, mohl by posloužit jako základ pochodně.");
          },
        ));
      }

      // Kresba na kmeni (clue for 674) - enlarged
      list.add(_Hotspot(
        name: "Kresba na kmeni",
        x: 0.40, y: 0.38, w: 0.20, h: 0.25,
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
                    "Na kůře stromu je vyrytá kresba dubu. Všimni si rozdělení a počtu hlavní větví směřujících k nebi zleva doprava. Tento počet větví (3 číslice) ti napoví kód k schránce.",
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

      // Forest right side (blue mushrooms)
      final hasMushrooms = state.inventory.contains('blue_mushrooms') || state.roomStates['node2_mushrooms_taken'] == true;
      if (!hasMushrooms) {
        list.add(_Hotspot(
          name: "Les vpravo (Houby)",
          x: 0.75, y: 0.55, w: 0.18, h: 0.25,
          onTap: () {
            _service.updateRoomState('node2_mushrooms_taken', true);
            _collectItem('blue_mushrooms', "Prohledal jsi les za starým dubem a pod jedním z kořenů jsi našel svítící modré houby!");
          },
        ));
      }
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
              _service.batchUpdate(
                roomStatesToUpdate: {'node3_vines_burned': true},
              );
              _service.collectItem('item_ash');
              _speakHeroLine("Mám to! Trní hoří.");
              setState(() => _selectedItemId = null);
              _showDialog("🔥 Přiložil jsi zapálenou pochodeň k ostnatému křoví. Suché větve okamžitě vzplály a spálily se na uhel! Vchod do chýše je volný. Z popela jsi rovnou sesbíral jemný popel a prach jako Element Vzduchu.");
            } else if (_selectedItemId == 'smoldering_tinder') {
              _speakHeroLine("Tohle zelené trní nezapálí.");
              _showDialog("Doutnající troud sám o sobě nestačí na zapálení zeleného ostnatého křoví. Potřebuješ pořádný otevřený plamen, např. hořící pochodeň.");
            } else if (_selectedItemId != null) {
              _speakHeroLine("Tohle sem nepatří.");
              _showDialog("Tento předmět ti s odklizením křoví nepomůže.");
            } else {
              _showDialog("Dveře chýše jsou kompletně zarostlé tlustými ostnatými šlahouny. Holýma rukama neprojdeš.");
            }
          },
        ));

        // Hadr na plotě
        final hasCloth = state.roomStates['node3_has_cloth'] == true;
        final hasTorchInInventory = state.inventory.contains('torch') || state.inventory.contains('burning_torch');
        final caveLit = state.roomStates['node4_cave_lit'] == true;
        final canGatherCloth = !hasCloth || (!state.inventory.contains('cloth') && !hasTorchInInventory && !caveLit);
        if (canGatherCloth) {
          list.add(_Hotspot(
            name: "Hadr na plotě",
            x: 0.10, y: 0.62, w: 0.12, h: 0.12,
            onTap: () {
              _service.updateRoomState('node3_has_cloth', true);
              _collectItem('cloth', "Z dřevěného plotu jsi sundal starý, olejem nasáklý hadr. Bude skvěle hořet, pokud ho připevníš na větev.");
            },
          ));
        }

        // Mech u plotu
        final hasTinder = state.roomStates['node3_has_tinder'] == true;
        final hasTinderProductInInventory = state.inventory.contains('smoldering_tinder') || state.inventory.contains('burning_torch');
        final canGatherTinder = !hasTinder || (!state.inventory.contains('tinder') && !hasTinderProductInInventory && !caveLit);
        if (canGatherTinder) {
          list.add(_Hotspot(
            name: "Suchý mech",
            x: 0.82, y: 0.84, w: 0.1, h: 0.1,
            showSparkle: true,
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
        final chestTaken = state.roomStates['node3_chest_taken'] == true;
        final diaryRead = state.roomStates['node3_diary_read'] == true;

        // Diary
        list.add(_Hotspot(
          name: "Starý sešit",
          x: 0.42, y: 0.58, w: 0.15, h: 0.12,
          onTap: () {
            _service.updateRoomState('node3_diary_read', true);
            if (chestTaken) {
              _completeNodeAndPop('node3', "📖 Přečetl jsi deník lesníka a dozvěděl ses o studni v bažinách a o tom, jak ji vyvážit. Jelikož máš i kotlík a kliku z truhly, tvá cesta chýší je dokončena!");
            } else {
              _showDialog("📖 Přečetl jsi deník lesníka! Dozvěděl ses o studni v bažinách a o tom, jak ji vyvážit. Stále bys ale měl prohledat chýši, zda tu nezůstaly nějaké užitečné věci v truhle.");
            }
          },
        ));

        // Chest
        list.add(_Hotspot(
          name: "Železná truhla",
          x: 0.72, y: 0.62, w: 0.18, h: 0.18,
          onTap: () {
            if (!chestTaken) {
              _service.batchUpdate(
                roomStatesToUpdate: {'node3_chest_taken': true},
              );
              _service.collectItem('pot');
              _service.collectItem('well_handle');
              if (diaryRead) {
                _completeNodeAndPop('node3', "🔓 Otevřel jsi starou železnou truhlu, ze které jsi vzal měděný kotlík a kliku od studny. Tím jsi prozkoumal celou chýši a můžeš jít dál!");
              } else {
                _showDialog("🔓 Otevřel jsi starou železnou truhlu. Na dně ležel měděný kotlík a klika od studny! Měl bys ale ještě najít a přečíst deník lesníka.");
              }
            } else {
              _showDialog("Stará železná truhla je otevřená a prázdná.");
            }
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
          x: 0.20, y: 0.42, w: 0.25, h: 0.35,
          onTap: () {
            setState(() {
              _currentSubroom = "cave";
              _dialogText = state.roomStates['node4_hermit_healed'] == true
                  ? "Poustevník sedí v jeskyni u malého ohýnku a usmívá se."
                  : "Uvnitř temné jeskyně leží na slaměném lůžku poustevník. Silně blouzní v horečkách.";
            });
          },
        ));

        // Old Well (no handle required)
        final waterTaken = state.roomStates['node4_water_taken'] == true &&
            (state.inventory.contains('item_water') || state.roomStates['node6_water_placed'] == true);

        list.add(_Hotspot(
          name: "Kamenná studna",
          x: 0.4, y: 0.4, w: 0.24, h: 0.38,
          onTap: () {
            final hasWaterOrPlaced = state.inventory.contains('item_water') || state.roomStates['node6_water_placed'] == true;
            if (waterTaken && hasWaterOrPlaced) {
              _showDialog("Kbelík s čistou pramenitou vodou jsi již nabral. Pokud jej ztratíš nebo spotřebuješ, můžeš nabrat další.");
              return;
            }

            final wellBalanced = state.roomStates['node4_well_balanced'] == true;
            if (wellBalanced) {
              _service.updateRoomState('node4_water_taken', true);
              _collectItem('item_water', "💧 Vytáhl jsi kbelík s čistou pramenitou vodou ze studny!");
            } else {
              _showDialog("Zdvihací mechanismus studny je zablokován těžkým kbelíkem. Kbelík nelze vytáhnout, dokud nevyvážíš protizávaží na váze ve stodole.");
            }
          },
        ));

        // Barn hotspot (Stodola)
        list.add(_Hotspot(
          name: "Stodola",
          x: 0.78, y: 0.38, w: 0.18, h: 0.35,
          onTap: () {
            setState(() {
              _currentSubroom = "barn";
              _dialogText = "Vstoupil jsi do staré zaprášené stodoly. V rohu stojí mechanismus váhy spojený se studnou.";
            });
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
        final caveLit = state.roomStates['node4_cave_lit'] == true;

        if (!caveLit) {
          list.add(_Hotspot(
            name: "Černočerná tma",
            x: 0.2, y: 0.2, w: 0.6, h: 0.6,
            onTap: () {
              if (_selectedItemId == 'burning_torch') {
                _service.updateRoomState('node4_cave_lit', true);
                setState(() => _selectedItemId = null);
                _showDialog("🔥 Pomocí zapálené pochodně jsi rozkřesal staré ohniště uprostřed jeskyně! Plameny ozářily kamenné stěny a v rohu jsi spatřil ležet nemocného poustevníka.");
              } else {
                _showDialog("V jeskyni je naprostá tma a chlad. Bez zdroje světla, jako je zapálená pochodeň (vyrobíš spojením větve a hadru a zapálením u troudu), se neodvážíš jít dál.");
              }
            },
          ));
        } else {
          list.add(_Hotspot(
            name: "Poustevník",
            x: 0.38, y: 0.42, w: 0.25, h: 0.35,
            onTap: () => _startPoustevnikDialogue(state),
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

      } else if (_currentSubroom == "barn") {
        // Váha (Detail) click
        list.add(_Hotspot(
          name: "Váha (Detail)",
          x: 0.55, y: 0.3, w: 0.3, h: 0.5,
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
        final waterTaken = state.roomStates['node4_water_taken'] == true;
        final barnCleaned = state.roomStates['node4_barn_cleaned'] == true;

        if (!barnCleaned) {
          // Clean the scale hotspot
          list.add(_Hotspot(
            name: "Očistit váhu",
            x: 0.2, y: 0.2, w: 0.6, h: 0.6,
            onTap: () {
              _service.updateRoomState('node4_barn_cleaned', true);
              _showDialog("Setřel jsi nánosy prachu a pavučin z kovového štítku. Piktogramy kbelíku, vah a přetrženého lana jsou nyní krásně vidět!");
            },
          ));
        } else {
          // Cleaned scale interaction
          list.add(_Hotspot(
            name: "Mechanismus váhy",
            x: 0.25, y: 0.25, w: 0.5, h: 0.5,
            onTap: () {
              if (waterTaken) {
                _showDialog("Voda je již úspěšně vytažena, váhu už není potřeba používat.");
                return;
              }

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
                        _showDialog("⚙ Vyvážil jsi protizávaží studny! Otočil jsi klikou a kbelík s čistou pramenitou vodou se s tichým zavrzáním vytáhl nahoru.");
                      },
                    ),
                  ),
                );
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
      } else if (_currentSubroom == "shrine") {
        final hasHerbs = state.roomStates['node4_has_herbs'] == true;

        list.add(_Hotspot(
          name: "Kamenný oltář (Modré houby)",
          x: 0.38, y: 0.35, w: 0.25, h: 0.35,
          onTap: () {
            if (hasHerbs) {
              _showDialog("Svatyně je tichá, modré houby jsi již nasbíral.");
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CatchingGameScreen(
                  onSolved: () {
                    _service.updateRoomState('node4_has_herbs', true);
                    _service.collectItem('blue_mushrooms');
                    _showDialog("🦟 Pochytal jsi dotěrné světlušky, které chránily oltář, a bezpečně jsi nasbíral léčivé modré houby!");
                  },
                ),
              ),
            );
          },
        ));

        // Return button
        list.add(_Hotspot(
          name: "Vchod ven",
          x: 0.45, y: 0.85, w: 0.15, h: 0.1,
          onTap: () {
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

        final lensTaken = state.roomStates['node5_lens_taken'] == true;

        list.add(_Hotspot(
          name: "Socha rytíře",
          x: 0.10, y: 0.42, w: 0.2, h: 0.45,
          onTap: () {
            if (swordPlaced) {
              _showDialog("Socha rytíře se otočila a drží kamenný meč. Ukazuje směrem k bráně.");
            } else if (_selectedItemId == 'stone_sword') {
              _service.updateRoomState('node5_has_sword', true);
              _service.removeItem('stone_sword');
              setState(() => _selectedItemId = null);
              _showDialog("🗡️ Vložil jsi kamenný meč do rukou sochy rytíře. Mechanismus za zdí zabzučel, socha se otočila a ukázala k bráně. Na jejích zádech se objevila čočka!");
            } else {
              _showDialog("Obří kamenná socha rytíře chránící pevnost. V rukou jí chybí rituální meč.");
            }
          },
        ));

        if (swordPlaced && !lensTaken) {
          list.add(_Hotspot(
            name: "Čočka na zádech",
            x: 0.12, y: 0.28, w: 0.08, h: 0.08,
            showSparkle: true,
            onTap: () {
              _service.collectItem('clean_lens');
              _service.updateRoomState('node5_lens_taken', true);
              _showDialog("🔍 Sebral jsi čistou čočku ze zad otočené sochy rytíře!");
            },
          ));
        }

        // Armory Gate
        final armoryOpen = state.roomStates['node5_armory_open'] == true;
        list.add(_Hotspot(
          name: "Mříž zbrojnice",
          x: 0.78, y: 0.48, w: 0.18, h: 0.32,
          onTap: () {
            if (armoryOpen) {
              final taken = state.roomStates['node5_items_taken'] == true;
              if (!taken) {
                _service.updateRoomState('node5_items_taken', true);
                _service.collectItem('stone_sword');
                _showDialog("Vstoupil jsi do zbrojnice. Ze stojanu jsi vzal Kamenný meč.");
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
        final askedForHelp = state.roomStates['node5_astronomer_asked_help'] == true;

        // Bookshelf puzzle
        list.add(_Hotspot(
          name: "Police s knihami",
          x: 0.15, y: 0.15, w: 0.20, h: 0.30,
          onTap: () {
            if (!askedForHelp) {
              _showDialog("Police plná starých knih. Nevypadá to, že bys s nimi měl teď hýbat bez svolení hvězdopravce.");
              return;
            }
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

        // Starý regál
        list.add(_Hotspot(
          name: "Starý regál",
          x: 0.72, y: 0.25, w: 0.18, h: 0.32,
          onTap: () {
            if (!askedForHelp) {
              _showDialog("Tento starý dřevěný regál na té knihovně je plný rozpadajících se knih a tlusté vrstvy stoletého prachu.");
            } else if (keyTaken) {
              _showDialog("Regál je nyní uklizený a čistý.");
            } else {
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
            }
          },
        ));

        // Hvězdopravec NPC (dialogue trigger moved to the left of telescope)
        list.add(_Hotspot(
          name: "Hvězdopravec",
          x: 0.28, y: 0.55, w: 0.15, h: 0.30,
          onTap: () => _startHvezdopravecDialogue(state),
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
            _showDialog("Rituál byl ůspěšně dokončen. Amulet září věčným světlem!");
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
                _showDialog("🏆 Úspěšně jsi dokončil celou výpravu! Získal jsi 50 Limetek a tvůj zvířecí maskot slaví vítězství!");
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

          // Try placing Fire (burning_torch)
          if (!ashPlaced && state.inventory.contains('burning_torch')) {
            roomStatesToUpdate['node6_ash_placed'] = true;
            ashPlaced = true;
            placedNow.add("Zapálenou pochodneň (Oheň) 🔥");
          }

          // Try placing Water (item_water)
          if (!waterPlaced && state.inventory.contains('item_water')) {
            itemsToRemove.add('item_water');
            roomStatesToUpdate['node6_water_placed'] = true;
            waterPlaced = true;
            placedNow.add("Kbelík vody (Voda) 💧");
          }

          // Try placing Air (item_ash)
          if (!dustPlaced && state.inventory.contains('item_ash')) {
            itemsToRemove.add('item_ash');
            roomStatesToUpdate['node6_dust_placed'] = true;
            dustPlaced = true;
            placedNow.add("Popel a prach (Vzduch) 💨");
          }

          // Try placing Earth (item_salt)
          if (!saltPlaced && state.inventory.contains('item_salt')) {
            itemsToRemove.add('item_salt');
            roomStatesToUpdate['node6_salt_placed'] = true;
            saltPlaced = true;
            placedNow.add("Posvátný kámen (Země) 🌱");
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
                "${ashPlaced ? '✅ Zapálená pochodeň (Oheň)' : '❌ Chybí Zapálená pochodeň (Oheň)'}\n"
                "${waterPlaced ? '✅ Kbelík vody (Voda)' : '❌ Chybí Kbelík vody (Voda)'}\n"
                "${dustPlaced ? '✅ Popel a prach (Vzduch)' : '❌ Chybí Popel a prach (Vzduch)'}\n"
                "${saltPlaced ? '✅ Posvátný kámen (Země)' : '❌ Chybí Posvátný kámen (Země)'}");
          } else {
            _showDialog("K oltáři jsi neměl co nového přiložit.\n\nStav oltáře:\n"
                "${ashPlaced ? '✅ Zapálená pochodeň (Oheň)' : '❌ Chybí Zapálená pochodeň (Oheň)'}\n"
                "${waterPlaced ? '✅ Kbelík vody (Voda)' : '❌ Chybí Kbelík vody (Voda)'}\n"
                "${dustPlaced ? '✅ Popel a prach (Vzduch)' : '❌ Chybí Popel a prach (Vzduch)'}\n"
                "${saltPlaced ? '✅ Posvátný kámen (Země)' : '❌ Chybí Posvátný kámen (Země)'}");
          }
        },
      ));

      // Salt hotspot (Posvátný kámen v mohyle)
      final saltPlaced = state.roomStates['node6_salt_placed'] == true;
      final hasSalt = state.inventory.contains('item_salt');
      final canCollectSalt = !saltPlaced && !hasSalt;
      if (canCollectSalt) {
        list.add(_Hotspot(
          name: "Kamenná mohyla",
          x: 0.08, y: 0.65, w: 0.18, h: 0.18,
          showSparkle: true,
          onTap: () {
            _service.collectItem('item_salt');
            _showDialog("Z kamenné mohyly jsi vzal jeden posvátný kámen! Sebral jsi ho jako Element Země.");
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
    } else if (name == "Kamenná mohyla") {
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
      final mushroomsTaken = state.roomStates['node2_mushrooms_taken'] == true;
      final stickTaken = state.roomStates['node2_has_stick'] == true;
      if (!mushroomsTaken && !stickTaken) {
        return 'assets/images/story_room_oak.png';
      } else if (mushroomsTaken && !stickTaken) {
        return 'assets/images/story_room_oak_no_mushrooms.png';
      } else if (!mushroomsTaken && stickTaken) {
        return 'assets/images/story_room_oak_no_stick.png';
      } else {
        return 'assets/images/story_room_oak_clean.png';
      }
    } else if (widget.nodeId == 'node3') {
      if (_currentSubroom == "interior") {
        final chestOpen = state.roomStates['node3_chest_open'] == true;
        return chestOpen
            ? 'assets/images/story_room_cabin_interior_open_chest.png'
            : 'assets/images/story_room_cabin_interior.png';
      }

      final hasCloth = state.roomStates['node3_has_cloth'] == true;
      final hasTinder = state.roomStates['node3_has_tinder'] == true;
      final vinesBurned = state.roomStates['node3_vines_burned'] == true;
      if (vinesBurned) {
        return 'assets/images/story_room_cabin_exterior_burned.png';
      } else if (!hasCloth && !hasTinder) {
        return 'assets/images/story_room_cabin_exterior_both.png';
      } else if (hasCloth && !hasTinder) {
        return 'assets/images/story_room_cabin_exterior_no_cloth.png';
      } else if (!hasCloth && hasTinder) {
        return 'assets/images/story_room_cabin_exterior_no_moss.png';
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
      final waterTaken = state.roomStates['node4_water_taken'] == true &&
          (state.inventory.contains('item_water') || state.roomStates['node6_water_placed'] == true);
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
      final lensTaken = state.roomStates['node5_lens_taken'] == true;
      if (hasSword) {
        return lensTaken
            ? 'assets/images/story_room_fortress_exterior_turned_no_lens.png'
            : 'assets/images/story_room_fortress_exterior_turned.png';
      } else {
        return 'assets/images/story_room_fortress_exterior.png';
      }
    } else if (widget.nodeId == 'node6') {
      final saltPlaced = state.roomStates['node6_salt_placed'] == true;
      final hasSalt = state.inventory.contains('item_salt');
      final elementsPlaced = state.roomStates['node6_elements_placed'] == true;
      final threeElementsPlaced = state.roomStates['node6_ash_placed'] == true &&
          state.roomStates['node6_water_placed'] == true &&
          state.roomStates['node6_dust_placed'] == true;

      if (elementsPlaced) {
        return 'assets/images/story_room_altar_lit.png';
      } else if (threeElementsPlaced) {
        if (!saltPlaced && !hasSalt) {
          return 'assets/images/story_room_altar_partial.png';
        } else {
          return 'assets/images/story_room_altar_partial_taken.png';
        }
      } else if (!saltPlaced && !hasSalt) {
        return 'assets/images/story_room_altar_with_salt.png';
      } else {
        return 'assets/images/story_room_altar.png';
      }
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
                        onPressed: () {
                          if (widget.nodeId == 'node3' && _currentSubroom == 'interior') {
                            setState(() {
                              _currentSubroom = 'exterior';
                              _dialogText = "Stojíš venku před chýší.";
                            });
                          } else if (widget.nodeId == 'node4' && _currentSubroom == 'scale_zoom') {
                            setState(() {
                              _currentSubroom = 'barn';
                              _dialogText = "Uvnitř stodoly.";
                            });
                          } else if (widget.nodeId == 'node4' && (_currentSubroom == 'cave' || _currentSubroom == 'barn')) {
                            setState(() {
                              _currentSubroom = 'exterior';
                              _dialogText = "Stojíš u bažiny.";
                            });
                          } else if (widget.nodeId == 'node5' && (_currentSubroom == 'library' || _currentSubroom == 'armory')) {
                            setState(() {
                              _currentSubroom = 'exterior';
                              _dialogText = "Nádvoří pevnosti.";
                            });
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.nodeId == 'node3' && _currentSubroom == 'interior'
                              ? 'Uvnitř chýše'
                              : widget.nodeId == 'node4' && _currentSubroom == 'cave'
                                  ? 'Poustevníkova jeskyně'
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

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) {
                          if (_showHints) {
                            setState(() {
                              _debugTapOffset = Offset(
                                details.localPosition.dx / width,
                                details.localPosition.dy / height,
                              );
                            });
                          }
                        },
                        child: Stack(
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
                            const Positioned.fill(
                              child: ImmersiveWeatherParticles(
                                particleType: 'fog',
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
                          if (_showHints && _debugTapOffset != null) ...[
                            Positioned(
                              left: _debugTapOffset!.dx * width - 6,
                              top: _debugTapOffset!.dy * height - 6,
                              width: 12,
                              height: 12,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.cyanAccent, width: 1.5),
                                ),
                                child: Text(
                                  "SOUŘADNICE: x: ${_debugTapOffset!.dx.toStringAsFixed(3)}, y: ${_debugTapOffset!.dy.toStringAsFixed(3)}",
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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
                                child: AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final shouldGlow = _highlightCombineTutorial && (itemId == 'dirty_key' || itemId == 'oil');
                                    return Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      width: 60,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.lime.shade700 : Colors.grey.shade800,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected
                                            ? Border.all(color: Colors.lime, width: 2)
                                            : (shouldGlow
                                                ? Border.all(color: Colors.cyanAccent.withOpacity(0.3 + _pulseController.value * 0.7), width: 2)
                                                : null),
                                        boxShadow: shouldGlow
                                            ? [
                                                BoxShadow(
                                                  color: Colors.cyanAccent.withOpacity(0.1 + _pulseController.value * 0.4),
                                                  blurRadius: 4.0 + _pulseController.value * 6.0,
                                                  spreadRadius: _pulseController.value * 2.0,
                                                )
                                              ]
                                            : null,
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
                                    );
                                  },
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
  final bool showSparkle;

  _Hotspot({
    required this.name,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.onTap,
    this.showSparkle = false,
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


