import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story_quest_model.dart';
import '../services/story_game_service.dart';
import 'catching_game_screen.dart';
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
          _service.collectItem('well_handle');
          setState(() {
            _selectedItemId = null;
          });
          final updatedState = _service.stateNotifier.value;

          final healScript = [
            _DialogueLine(speaker: 'player', text: "Tady, vypijte tohle! Svařil jsem modré houby v destilované vodě."),
            _DialogueLine(speaker: 'npc', text: "🍵 (Lok... lok...) Oh! Ta léčivá síla... chlad stoupá do mých spánků..."),
            _DialogueLine(speaker: 'npc', text: "Horečka ustupuje! Zachránil jsi mi život, poutníku."),
            _DialogueLine(speaker: 'npc', text: "Vezmi si tuto kliku k navijáku studny venku. Pomůže ti vytáhnout staré tajemství ze dna."),
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
          _DialogueLine(speaker: 'npc', text: "Musíš ji destilovat. V rohu mé jeskyně najdeš prázdný kotlík a měděnou trubku."),
          _DialogueLine(speaker: 'npc', text: "Naber špinavou vodu z bažiny do kotlíku a odveď páru trubkou nad ohněm u chýše lesníka (K3)."),
          _DialogueLine(speaker: 'player', text: "Ah, destilační přístroj! V lese u chýše je staré ohniště, tam to půjde."),
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
          x: 0.4, y: 0.4, w: 0.24, h: 0.38,
          onTap: () {
            if (triangularKeyTaken) {
              _showDialog("Studna je prázdná, klíč jsi již vytáhl.");
              return;
            }

            if (wellHandlePlaced) {
              final wellBalanced = state.roomStates['node4_well_balanced'] == true;
              if (wellBalanced) {
                _service.updateRoomState('node4_triangular_key_taken', true);
                _service.collectItem('triangular_key');
                _showDialog("⚙️ Otočil jsi klikou a bez námahy vytáhl kbelík nahoru. Na jeho dně leží těžký trojúhelníkový klíč!");
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LogicPuzzlesScreen(
                      puzzleType: "scales",
                      onSolved: () {
                        _service.updateRoomState('node4_well_balanced', true);
                        _service.updateRoomState('node4_triangular_key_taken', true);
                        _service.collectItem('triangular_key');
                        _showDialog("⚙️ Vyvážil jsi protizávaží studny! Lano jde otočit lehoučce a vytáhl jsi kbelík nahoru, na jehož dně leží trojúhelníkový klíč!");
                      },
                    ),
                  ),
                );
              }
            } else if (_selectedItemId == 'well_handle') {
              _service.updateRoomState('node4_well_handle', true);
              _service.removeItem('well_handle');
              setState(() => _selectedItemId = null);
              _showDialog("Nasadil jsi kliku navijáku na osu studny. Zkus ji otočit.");
            } else {
              _showDialog("Stará studna je hluboká a navijáku chybí otočná rukojeť, lano nejde navinout. Zdvihací mechanismus je navíc zablokován těžkým kbelíkem (protizávažím).");
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
      final isGateOpen = state.roomStates['node1_gate_open'] == true;
      return isGateOpen
          ? 'assets/images/story_room_gate_open.png'
          : 'assets/images/story_room_gate_closed.png';
    } else if (widget.nodeId == 'node2') {
      return 'assets/images/story_room_oak.png';
    } else if (widget.nodeId == 'node3') {
      if (_currentSubroom == "interior") {
        return 'assets/images/story_room_cabin_interior.png';
      }
      return 'assets/images/story_room_cabin_exterior.png';
    } else if (widget.nodeId == 'node4') {
      if (_currentSubroom == "cave") {
        return 'assets/images/story_room_cave.png';
      } else if (_currentSubroom == "shrine") {
        return 'assets/images/story_room_shrine.png';
      }
      return 'assets/images/story_room_swamp.png';
    } else if (widget.nodeId == 'node5') {
      if (_currentSubroom == "library") {
        return 'assets/images/story_room_observatory.png';
      }
      return 'assets/images/story_room_fortress_exterior.png';
    } else if (widget.nodeId == 'node6') {
      return 'assets/images/story_room_altar.png';
    }
    return 'assets/images/story_room_gate_closed.png';
  }

  Color _getRoomColorFilter() {
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

                          // Visual Novel Dialogue Overlay
                          if (_dialogueCharacterName != null)
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: _onDialogueAreaTap,
                                child: Container(
                                  color: Colors.black.withOpacity(0.55),
                                  child: Stack(
                                    children: [
                                      // 1. Left Character (NPC)
                                      if (_dialogueCharacterAsset != null)
                                        Positioned(
                                          left: 16,
                                          bottom: 0,
                                          width: width * 0.45,
                                          height: height * 0.7,
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
                                                transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0), // horizontal flip so NPC faces player on right
                                                child: ColorFiltered(
                                                  colorFilter: const ColorFilter.matrix(<double>[
                                                    1, 0, 0, 0, 0,
                                                    0, 1, 0, 0, 0,
                                                    0, 0, 1, 0, 0,
                                                    -1, -1, -1, 3, 0, // chromakey out pure white background
                                                  ]),
                                                  child: Image.asset(
                                                    _dialogueCharacterAsset!,
                                                    fit: BoxFit.contain,
                                                    alignment: Alignment.bottomLeft,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      // 2. Right Character (Player)
                                      if (_playerCharacterAsset != null)
                                        Positioned(
                                          right: 16,
                                          bottom: 0,
                                          width: width * 0.45,
                                          height: height * 0.7,
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
                                                  -1, -1, -1, 3, 0, // chromakey out white background
                                                ]),
                                                child: Image.asset(
                                                  _playerCharacterAsset!,
                                                  fit: BoxFit.contain,
                                                  alignment: Alignment.bottomRight,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      // 3. Speech Bubble (Upper area)
                                      if (_dialogueScript.isNotEmpty && _dialogueScriptIndex < _dialogueScript.length)
                                        Positioned(
                                          top: height * 0.08,
                                          left: 16,
                                          right: 16,
                                          child: _isNpcActive
                                              ? Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Container(
                                                    constraints: BoxConstraints(maxWidth: width * 0.75),
                                                    padding: const EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF0A0A0A).withOpacity(0.95),
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(16),
                                                        topRight: Radius.circular(16),
                                                        bottomRight: Radius.circular(16),
                                                      ),
                                                      border: Border.all(color: Colors.lime.shade600, width: 2),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          _dialogueCharacterName ?? "NPC",
                                                          style: TextStyle(
                                                            color: Colors.lime.shade400,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          _dialogText,
                                                          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              : Align(
                                                  alignment: Alignment.centerRight,
                                                  child: Container(
                                                    constraints: BoxConstraints(maxWidth: width * 0.75),
                                                    padding: const EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF0A0A0A).withOpacity(0.95),
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(16),
                                                        topRight: Radius.circular(16),
                                                        bottomLeft: Radius.circular(16),
                                                      ),
                                                      border: Border.all(color: Colors.cyan.shade400, width: 2),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Text(
                                                          "Ty",
                                                          style: TextStyle(
                                                            color: Colors.cyanAccent,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          _dialogText,
                                                          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                        ),

                                      // 4. Floating Choices (Center)
                                      if (_dialogueScriptIndex == _dialogueScript.length - 1 && _dialogueChoices.isNotEmpty)
                                        Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 24),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: _dialogueChoices.map((opt) {
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
                                                      elevation: 4,
                                                    ),
                                                    onPressed: opt.onTap,
                                                    child: Text(
                                                      opt.text,
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
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

class _DialogueLine {
  final String speaker; // 'npc' or 'player'
  final String text;

  _DialogueLine({
    required this.speaker,
    required this.text,
  });
}
