import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wheel_of_fortune_model.dart';

class WheelOfFortuneService {
  static final WheelOfFortuneService _instance = WheelOfFortuneService._internal();
  factory WheelOfFortuneService() => _instance;
  WheelOfFortuneService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _localPrefsKey = 'local_custom_wheels';

  /// Returns official default HEJBEJ wheels
  List<WheelOfFortune> getOfficialWheels() {
    return [
      WheelOfFortune(
        id: 'hejbej_indiv_preset',
        name: 'Od HEJBEJ: Zábavná výzva (Jednotlivci) 🏃',
        creatorName: 'HEJBEJ',
        isCustom: false,
        tasks: _getDefaultIndividualTasks(),
      ),
      WheelOfFortune(
        id: 'hejbej_group_preset',
        name: 'Od HEJBEJ: Týmová výprava (Skupiny) 👥',
        creatorName: 'HEJBEJ',
        isCustom: false,
        tasks: _getDefaultGroupTasks(),
      ),
    ];
  }

  /// Get local custom/downloaded wheels
  Future<List<WheelOfFortune>> getCustomWheels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localPrefsKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => WheelOfFortune.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save a custom wheel locally
  Future<void> saveCustomWheel(WheelOfFortune wheel) async {
    final list = await getCustomWheels();
    final index = list.indexWhere((w) => w.id == wheel.id);
    if (index >= 0) {
      list[index] = wheel;
    } else {
      list.add(wheel);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localPrefsKey, jsonEncode(list.map((w) => w.toJson()).toList()));
  }

  /// Delete a custom wheel locally
  Future<void> deleteCustomWheel(String id) async {
    final list = await getCustomWheels();
    list.removeWhere((w) => w.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localPrefsKey, jsonEncode(list.map((w) => w.toJson()).toList()));
  }

  /// Share wheel to Firestore, generating a unique code like K15746
  Future<String> shareWheelToCommunity(WheelOfFortune wheel, String creatorUid, String creatorName) async {
    // Generate unique code KXXXXX
    String code = '';
    bool isUnique = false;
    final random = Random();
    
    while (!isUnique) {
      final num = random.nextInt(90000) + 10000; // 5-digit number
      code = 'K$num';
      final query = await _firestore
          .collection('custom_wheels')
          .where('code', isEqualTo: code)
          .get();
      if (query.docs.isEmpty) {
        isUnique = true;
      }
    }

    final newWheel = WheelOfFortune(
      id: wheel.id,
      code: code,
      name: wheel.name,
      tasks: wheel.tasks,
      creatorName: creatorName.isNotEmpty ? creatorName : 'Hráč',
      creatorUid: creatorUid,
      likes: wheel.likes,
      isCustom: true,
    );

    // Save to Firestore
    await _firestore.collection('custom_wheels').doc(wheel.id).set(newWheel.toJson());

    // Update local wheel representation with the generated code
    await saveCustomWheel(newWheel);

    return code;
  }

  /// Search wheel by code (e.g. K15746 or #K15746) in Firestore and save it locally if found
  Future<WheelOfFortune?> searchWheelByCode(String code) async {
    String cleanCode = code.trim().replaceAll('#', '').toUpperCase();
    if (cleanCode.isEmpty) return null;

    try {
      final query = await _firestore
          .collection('custom_wheels')
          .where('code', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final wheel = WheelOfFortune.fromJson(query.docs.first.data());
      await saveCustomWheel(wheel);
      return wheel;
    } catch (_) {
      return null;
    }
  }

  /// Like/Unlike a community wheel
  Future<void> likeCommunityWheel(String wheelId, String userUid) async {
    try {
      final docRef = _firestore.collection('custom_wheels').doc(wheelId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final likedBy = List<String>.from(data['likedBy'] as List<dynamic>? ?? []);
        int likes = data['likes'] as int? ?? 0;

        if (likedBy.contains(userUid)) {
          likedBy.remove(userUid);
          likes = max(0, likes - 1);
        } else {
          likedBy.add(userUid);
          likes += 1;
        }

        transaction.update(docRef, {
          'likes': likes,
          'likedBy': likedBy,
        });
      });
    } catch (_) {}
  }

  /// Fetch top rated wheels from Firestore
  Future<List<WheelOfFortune>> fetchTopRatedCommunityWheels() async {
    try {
      final query = await _firestore
          .collection('custom_wheels')
          .orderBy('likes', descending: true)
          .limit(15)
          .get();

      return query.docs.map((doc) => WheelOfFortune.fromJson(doc.data())).toList();
    } catch (_) {
      return [];
    }
  }

  List<WheelTask> _getDefaultIndividualTasks() {
    return [
      WheelTask(id: 'indiv_1', title: 'Ruce v kapsách', icon: 'pocket', description: 'Jdi po celý tento úsek s rukama v kapsách.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_2', title: 'Poskoky po jedné', icon: 'hop', description: 'Skákej po jedné noze každých 10 kroků po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_3', title: 'Chůze pozpátku', icon: 'backward', description: 'Jdi po celý tento úsek pozpátku.', exceptions: 'Buď opatrný při chůzi, při nerovném terénu úkol přeruš.'),
      WheelTask(id: 'indiv_4', title: 'Nosič batohů', icon: 'backpack', description: 'Neseš batoh jinému hráči ({hráč}) po celý tento úsek.', exceptions: 'Pokud jdeš sám, úkol se ignoruje a válec vybere jiný.'),
      WheelTask(id: 'indiv_5', title: 'Tichý bobřík', icon: 'silent', description: 'Nemluv po celý tento úsek.', exceptions: 'Krizové situace (např. varování před nebezpečím).'),
      WheelTask(id: 'indiv_6', title: 'Ozvěna', icon: 'echo', description: 'Opakuj každé slovo, které řekne hráč {hráč} po celý tento úsek.', exceptions: 'Pokud jdeš sám, úkol se ignoruje.'),
      WheelTask(id: 'indiv_7', title: 'Král rytířů', icon: 'knight', description: 'Mluv jako středověký rytíř (používej nýbrž, poněvadž, panovníku) po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_8', title: 'Dřepovací úsek', icon: 'squat', description: 'Každých 20 kroků udělej jeden dřep po celý tento úsek.', exceptions: 'Bolesti kloubů nebo extrémní únava.'),
      WheelTask(id: 'indiv_9', title: 'Zvukař', icon: 'sound', description: 'Dělej doprovodné zvuky (např. vítr, kroky, motor) při chůzi po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_10', title: 'Kulhavý chodec', icon: 'limp', description: 'Jdi s předstíraným kulháním na levou nohu po celý tento úsek.', exceptions: 'Bolesti nohou.'),
      WheelTask(id: 'indiv_11', title: 'Pravidelný dřep', icon: 'squat', description: 'Každých 50 kroků udělej jeden dřep po celý tento úsek.', exceptions: 'Bolesti kloubů.'),
      WheelTask(id: 'indiv_12', title: 'Zakázaná slova', icon: 'forbidden', description: 'Nesmíš použít slovo "ano" ani "ne" po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_13', title: 'Šeptání', icon: 'whisper', description: 'Mluv pouze šeptem po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_14', title: 'Letadlo', icon: 'airplane', description: 'Jdi s rozpaženýma rukama jako letadlo po celý tento úsek.', exceptions: 'Úzké stezky s větvemi.'),
      WheelTask(id: 'indiv_15', title: 'Průvodce', icon: 'guide', description: 'Předstírej, že jsi průvodce, a komentuj přírodu jako v dokumentu po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_16', title: 'Pospolu', icon: 'friends', description: 'Musíš jít v těsné blízkosti hráče {hráč} (jít pospolu) po celý tento úsek.', exceptions: 'Pokud jdeš sám, úkol se ignoruje.'),
      WheelTask(id: 'indiv_17', title: 'Komentátor', icon: 'mic', description: 'Předstírej, že jsi sportovní komentátor, a komentuj chůzi skupiny po celý tento úsek.', exceptions: 'Žádné (komentuješ sebe).'),
      WheelTask(id: 'indiv_18', title: 'Básník', icon: 'poem', description: 'Každému, kdo na tebe promluví, musíš po celý tento úsek odpovídat rýmem.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_19', title: 'Cizinec', icon: 'globe', description: 'Mluv s cizím přízvukem (slovenským, anglickým apod.) po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_20', title: 'Žezlo', icon: 'stick', description: 'Hledej na cestě zajímavý klacek nebo jiný předmět a nes ho po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_21', title: 'Zoolog', icon: 'animal', description: 'Každou minutu vyjmenuj jedno náhodné zvíře po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_22', title: 'Ruce za zády', icon: 'lock', description: 'Jdi s rukama sepjatýma za zády po celý tento úsek.', exceptions: 'Náročný terén vyžadující stabilitu.'),
      WheelTask(id: 'indiv_23', title: 'Divadelník', icon: 'theater', description: 'Dělej velké divadelní kroky (vysoká kolena) po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_24', title: 'Poslední stráž', icon: 'shield', description: 'Musíš jít jako poslední člen skupiny po celý tento úsek.', exceptions: 'Pokud jdeš sám, úkol se ignoruje.'),
      WheelTask(id: 'indiv_25', title: 'Vůdce smečky', icon: 'crown', description: 'Musíš jít jako první člen skupiny a udávat tempo po celý tento úsek.', exceptions: 'Pokud jdeš sám, úkol se ignoruje.'),
      WheelTask(id: 'indiv_26', title: 'Stín', icon: 'shadow', description: 'Drž se po celý tento úsek vždy přesně dva kroky za hráčem {hráč}.', exceptions: 'Pokud jdeš sám, úkol se ignoruje.'),
      WheelTask(id: 'indiv_27', title: 'Zdvořilost', icon: 'heart', description: 'Pokaždé, když promluvíš, musíš začít slovy \'Milý příteli\' po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_28', title: 'Zákaz ukazování', icon: 'pointer', description: 'Nesmíš ukázat prstem na nic po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_29', title: 'Zvědavec', icon: 'question', description: 'Mluv pouze v otázkách po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_30', title: 'Tajný agent', icon: 'spy', description: 'Předstírej tajného agenta a kryj se za stromy, budovy či překážky při každém zastavení.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_31', title: 'Popisovatel', icon: 'book', description: 'Pokaždé, když promluvíš, musíš popsat básnicky nejbližší věc v dohledu po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_32', title: 'Strážce kamene', icon: 'stone', description: 'Musíš nést v ruce malý kamínek a nepustit ho po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_33', title: 'Rýmař', icon: 'poem', description: 'Mluv pouze v rýmech po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_34', title: 'Poklad', icon: 'leaf', description: 'Nos v ruce stéblo trávy nebo list a chraň ho jako poklad po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_35', title: 'Robot', icon: 'robot', description: 'Mluv jako robot po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_36', title: 'Písničkář', icon: 'music', description: 'Zpívej si potichu svou oblíbenou písničku po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_37', title: 'Tajný rozhovor', icon: 'whisper', description: 'Mluv šeptem pouze s jedním vybraným hráčem ({hráč}) po celý tento úsek.', exceptions: 'Pokud jdeš sám, úkol se ignoruje.'),
      WheelTask(id: 'indiv_38', title: 'Socha', icon: 'statue', description: 'Kdykoliv se někdo zastaví, musíš se zastavit také a ztuhnout jako socha po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_39', title: 'Potlesk', icon: 'clap', description: 'Každých 50 kroků tleskni nad hlavou po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_40', title: 'Služebník', icon: 'service', description: 'Musíš odpovědět pouze slovem \'Rozumím\' na jakoukoliv otázku od hráče {hráč} po celý tento úsek.', exceptions: 'Pokud jdeš sám, úkol se ignoruje.'),
      WheelTask(id: 'indiv_41', title: 'Modlitba', icon: 'pray', description: 'Jdi s rukama spojenýma před sebou jako při modlitbě po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_42', title: 'Křížení', icon: 'cross', description: 'Jdi s levou rukou na pravém rameni a pravou na levém rameni po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_43', title: 'Detox od mobilu', icon: 'phone', description: 'Nesmíš se podívat na mobil po celý tento úsek.', exceptions: 'Kontrola mapy pro navigaci.'),
      WheelTask(id: 'indiv_44', title: 'Zpomalený hlas', icon: 'slow', description: 'Mluv extrémně pomalu po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_45', title: 'Rychlodabér', icon: 'fast', description: 'Mluv extrémně rychle po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_46', title: 'Strážce oblohy', icon: 'cloud', description: 'Kdykoliv uvidíš letadlo nebo ptáka, musíš ukázat a zakřičet "Pozor!" po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_47', title: 'Máš štěstí!', icon: 'luck', description: 'Tento úsek jdeš bez jakéhokoliv úkolu a odpočíváš. (Free Pass)', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_48', title: 'Máš štěstí!', icon: 'luck', description: 'Tento úsek jdeš bez jakéhokoliv úkolu a odpočíváš. (Free Pass)', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_49', title: 'Máš štěstí!', icon: 'luck', description: 'Tento úsek jdeš bez jakéhokoliv úkolu a odpočíváš. (Free Pass)', exceptions: 'Žádné'),
      WheelTask(id: 'indiv_50', title: 'Máš štěstí!', icon: 'luck', description: 'Tento úsek jdeš bez jakéhokoliv úkolu a odpočíváš. (Free Pass)', exceptions: 'Žádné'),
    ];
  }

  List<WheelTask> _getDefaultGroupTasks() {
    return [
      WheelTask(id: 'group_1', title: 'Husí pochod', icon: 'group_walk', description: 'Celá parta musí jít v řadě za sebou (jako husy) po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_2', title: 'Ticho v lese', icon: 'group_silent', description: 'Celá skupina nesmí promluvit ani slovo po celý tento úsek.', exceptions: 'Krizová varování.'),
      WheelTask(id: 'group_3', title: 'Vláček', icon: 'group_train', description: 'Všichni musí kráčet pouze při držení se za rameno člověka před sebou po celý tento úsek.', exceptions: 'Úzké nebo nebezpečné úseky cesty.'),
      WheelTask(id: 'group_4', title: 'Společný zpěv', icon: 'group_music', description: 'Zazpívejte společně refrén známé písničky při každém zastavení po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_5', title: 'Skupinový fitness', icon: 'group_squat', description: 'Všichni se musí zastavit a udělat 10 dřepů každých 300 metrů po celý tento úsek.', exceptions: 'Zdravotní potíže členů.'),
      WheelTask(id: 'group_6', title: 'Zpomalený čas', icon: 'group_slow', description: 'Celá parta musí jít extrémně pomalu (jako ve zpomaleném filmu) po celý tento úsek.', exceptions: 'Spěch nebo špatné počasí.'),
      WheelTask(id: 'group_7', title: 'Ruce vzhůru', icon: 'group_hands', description: 'Všichni musí jít s rukama nad hlavou po celý tento úsek.', exceptions: 'Únava paží.'),
      WheelTask(id: 'group_8', title: 'Společné břemeno', icon: 'group_stick', description: 'Celá parta musí nést jeden společný velký klacek nebo jiný nalezený předmět po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_9', title: 'Pochodový krok', icon: 'group_sync', description: 'Všichni must kráčet synchronně (levá, pravá ve stejný čas) po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_10', title: 'Přepadovka', icon: 'group_stealth', description: 'Celá parta se musí schovávat za překážky podél cesty po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_11', title: 'Cestovatelé', icon: 'group_chat', description: 'Každý musí během tohoto úseku vyprávět jednu příhodu ze své oblíbené dovolené.', exceptions: 'Žádné'),
      WheelTask(id: 'group_12', title: 'Společný šepot', icon: 'group_whisper', description: 'Všichni mluví pouze šeptem po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_13', title: 'Zpětný chod party', icon: 'group_backward', description: 'Celá skupina musí jít pozpátku po celý tento úsek.', exceptions: 'Zvýšená opatrnost, zastavit při překážkách.'),
      WheelTask(id: 'group_14', title: 'Balanc na dlani', icon: 'group_balance', description: 'Každý musí nést po celý tento úsek kamínek položený na hřbetu ruky.', exceptions: 'Žádné'),
      WheelTask(id: 'group_15', title: 'Společné selfie', icon: 'group_camera', description: 'Celá parta musí udělat vtipné selfie – nahraná fotka se nastaví jako pozadí v záznamu trasy!', exceptions: 'Chybějící fotoaparát nebo nefunkční úložiště.'),
      WheelTask(id: 'group_16', title: 'Slušná parta', icon: 'group_heart', description: 'Všichni musí jít po celý tento úsek bez použití jakýchkoliv sprostých slov.', exceptions: 'Žádné'),
      WheelTask(id: 'group_17', title: 'Zvířecí doprovod', icon: 'group_animal', description: 'Všichni must napodobovat chůzi zvířete vybraného nejmladším členem party po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_18', title: 'Týmový plank', icon: 'group_plank', description: 'Celá skupina se musí zastavit a držet plank (vzpor) po dobu 20 sekund při každém zastavení.', exceptions: 'Zdravotní potíže.'),
      WheelTask(id: 'group_19', title: 'Řetěz rukou', icon: 'group_link', description: 'Všichni se musí držet za ruce při chůzi po celý tento úsek.', exceptions: 'Úzká stezka vyžadující volné ruce.'),
      WheelTask(id: 'group_20', title: 'Ticho a příroda', icon: 'group_ear', description: 'Celá parta musí jít v naprostém tichu a naslouchat zvukům okolí po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_21', title: 'Vtipálci', icon: 'group_laugh', description: 'Každý člen party musí říct jeden vtip po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_22', title: 'Pirátská posádka', icon: 'group_pirate', description: 'Všichni musí mluvit jako piráti po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_23', title: 'Letka letadel', icon: 'group_fly', description: 'Všichni must jít s rozpaženýma rukama jako letadla po celý tento úsek.', exceptions: 'Stísněné prostory.'),
      WheelTask(id: 'group_24', title: 'Rozcvička', icon: 'group_stretch', description: 'Celá parta se musí zastavit a udělat společný strečink při každém zastavení.', exceptions: 'Žádné'),
      WheelTask(id: 'group_25', title: 'Společný tlesk', icon: 'group_clap', description: 'Všichni musí tlesknout ve stejný moment pokaždé, když někdo promluví po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_26', title: 'Smíšek', icon: 'group_smile', description: 'Celá parta musí jít s úsměvem na tváři (nesmí se mračit) po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_27', title: 'Ochrana nejpomalejšího', icon: 'group_slow', description: 'Všichni musí jít v tempu nejpomalejšího člena party bez předbíhání po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_28', title: 'Eko-hlídka', icon: 'group_trash', description: 'Každý musí najít a odnést jeden odhozený odpad podél cesty po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_29', title: 'Básníci v řadě', icon: 'group_poem', description: 'Všichni must mluvit pouze ve verších po celý tento úsek.', exceptions: 'Žádné'),
      WheelTask(id: 'group_30', title: 'Skupinové štěstí', icon: 'group_luck', description: 'Všichni máte štěstí! Tento úsek jde celá parta bez úkolů a užívá si cestu. (Free Pass)', exceptions: 'Žádné'),
    ];
  }
}
