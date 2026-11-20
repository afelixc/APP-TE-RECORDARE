import 'dart:convert';

import 'priority_sounds.dart';

/// Lo que hace cada prioridad (Configuración → Notificaciones → Prioridades
/// de notificaciones). Normal avisa una vez con el sonido de la app; media y
/// alta repiten el aviso hasta que se toque "Hecho".
class PriorityConfig {
  const PriorityConfig({
    this.normalTimes = 1,
    this.normalEvery = 0,
    this.normalFor = 60,
    this.normalVibrate = true,
    this.mediaEvery = 5,
    this.mediaFor = 480,
    this.mediaInHours = false,
    this.mediaFrom = 8,
    this.mediaTo = 22,
    this.mediaSound = 'm_campanita_doble',
    this.mediaTimes = 1,
    this.mediaVibrate = true,
    this.mediaPhoneMillis,
    this.altaTimes = 3,
    this.altaEvery = 3,
    this.altaFor = 0,
    this.altaVibrate = true,
    this.altaFullScreen = true,
    this.altaSound = 'a_sirena',
    this.mediaPhoneUri,
    this.mediaPhoneName,
    this.altaPhoneUri,
    this.altaPhoneName,
    this.altaPhoneMillis,
  });

  /// Normal: cuántas veces suena seguido (1 a [maxTimes]; 0 = hasta
  /// "Hecho"), cada cuánto repite (0 = no repite), durante cuánto y si vibra.
  final int normalTimes;
  final int normalEvery;
  final int normalFor;
  final bool normalVibrate;

  /// Media: cada cuántos minutos repite (0 = no repite).
  final int mediaEvery;

  /// Media: durante cuántos minutos (0 = todo el día).
  final int mediaFor;

  /// Media: en vez de "durante", solo entre [mediaFrom] y [mediaTo] (horas).
  final bool mediaInHours;
  final int mediaFrom;
  final int mediaTo;

  /// Media: id de [mediaSounds], o [appSound] para el de la app.
  final String mediaSound;

  /// Media: cuántas veces suena seguido cada aviso (1 a [maxTimes];
  /// 0 = hasta que toque "Hecho").
  final int mediaTimes;

  /// Media: si vibra.
  final bool mediaVibrate;

  /// Lo que dura el sonido del teléfono de la media.
  final int? mediaPhoneMillis;

  /// Alta: cuántas veces suena seguido cada aviso (1 a [maxTimes];
  /// 0 = hasta que toque "Hecho").
  final int altaTimes;
  final int altaEvery;

  /// Alta: durante cuántos minutos (0 = hasta que toque "Hecho").
  final int altaFor;
  final bool altaVibrate;
  final bool altaFullScreen;
  final String altaSound;

  /// Sonido elegido del teléfono (cuando el sonido es [phoneSound]).
  final String? mediaPhoneUri;
  final String? mediaPhoneName;
  final String? altaPhoneUri;
  final String? altaPhoneName;

  /// Lo que dura el sonido del teléfono de la alta (para "cuántas veces").
  final int? altaPhoneMillis;

  static const appSound = 'app';
  static const phoneSound = 'tel';

  bool get mediaFromPhone => mediaSound == phoneSound && mediaPhoneUri != null;
  bool get altaFromPhone => altaSound == phoneSound && altaPhoneUri != null;

  /// Opciones de las listas (0 = "No repetir").
  static const everyOptions = [0, 3, 5, 10, 15, 30];
  static const altaEveryOptions = [0, 1, 2, 3, 5, 10];
  static const normalForOptions = [60, 180, 480, 0];
  static const mediaForOptions = [60, 180, 480, 0];
  static const altaForOptions = [60, 180, 480, 0];
  static const timesOptions = [1, 3, 5];

  /// Lo más que se puede elegir en "cuántas veces suena seguido".
  static const maxTimes = 10;

  static int clampTimes(int v) => v < 0 ? 1 : (v > maxTimes ? maxTimes : v);

  /// "3 veces", "1 vez" o "hasta Hecho".
  static String timesShort(int times) => times == 0
      ? 'hasta Hecho'
      : times == 1
      ? '1 vez'
      : '$times veces';

  /// "Suena 3 veces", "Suena 1 vez" o "Suena hasta que toque Hecho".
  static String timesLabel(int times) =>
      times == 0 ? 'Suena hasta que toque Hecho' : 'Suena ${timesShort(times)}';

  /// Android deja programar pocos avisos por app: cada recordatorio repite
  /// hasta esta cantidad de veces (después sigue el aviso fijo).
  static const maxRepeats = 48;

  /// "No repetir" o "5 min".
  static String everyLabel(int minutes) =>
      minutes == 0 ? 'No repetir' : '$minutes min';

  static String forLabel(int minutes, {bool alta = false}) => switch (minutes) {
    0 => alta ? 'Hasta que toque Hecho' : 'Todo el día',
    60 => '1 hora',
    _ => '${minutes ~/ 60} horas',
  };

  PrioritySound get altaSoundInfo => altaSounds.firstWhere(
    (s) => s.id == altaSound,
    orElse: () => altaSounds.first,
  );

  String get altaSoundName =>
      altaFromPhone ? altaPhoneName ?? 'Del teléfono' : altaSoundInfo.name;

  /// Lo que dura una vez el sonido de la alta. Los del teléfono pueden ser
  /// largos: se toman hasta 20 segundos.
  int get altaMillis => altaFromPhone
      ? (altaPhoneMillis ?? 3000).clamp(1000, 20000)
      : altaSoundInfo.millis;

  /// Lo que dura una vez el sonido de la media (el de la app: se calcula).
  int get mediaMillis => mediaFromPhone
      ? (mediaPhoneMillis ?? 3000).clamp(1000, 20000)
      : mediaSound == appSound
      ? 2000
      : mediaSounds
            .firstWhere(
              (s) => s.id == mediaSound,
              orElse: () => mediaSounds.first,
            )
            .millis;

  /// Sonido propio de la media (si el elegido no existe, el primero).
  String get mediaSoundId => mediaSounds.any((s) => s.id == mediaSound)
      ? mediaSound
      : mediaSounds.first.id;

  String get mediaSoundName => mediaSound == appSound
      ? 'El de la app'
      : mediaFromPhone
      ? mediaPhoneName ?? 'Del teléfono'
      : mediaSounds
            .firstWhere(
              (s) => s.id == mediaSound,
              orElse: () => mediaSounds.first,
            )
            .name;

  PriorityConfig copyWith({
    int? normalTimes,
    int? normalEvery,
    int? normalFor,
    bool? normalVibrate,
    int? mediaEvery,
    int? mediaFor,
    bool? mediaInHours,
    int? mediaFrom,
    int? mediaTo,
    String? mediaSound,
    int? mediaTimes,
    bool? mediaVibrate,
    int? mediaPhoneMillis,
    int? altaTimes,
    int? altaEvery,
    int? altaFor,
    bool? altaVibrate,
    bool? altaFullScreen,
    String? altaSound,
    String? mediaPhoneUri,
    String? mediaPhoneName,
    String? altaPhoneUri,
    String? altaPhoneName,
    int? altaPhoneMillis,
  }) => PriorityConfig(
    normalTimes: normalTimes ?? this.normalTimes,
    normalEvery: normalEvery ?? this.normalEvery,
    normalFor: normalFor ?? this.normalFor,
    normalVibrate: normalVibrate ?? this.normalVibrate,
    mediaEvery: mediaEvery ?? this.mediaEvery,
    mediaFor: mediaFor ?? this.mediaFor,
    mediaInHours: mediaInHours ?? this.mediaInHours,
    mediaFrom: mediaFrom ?? this.mediaFrom,
    mediaTo: mediaTo ?? this.mediaTo,
    mediaSound: mediaSound ?? this.mediaSound,
    mediaTimes: mediaTimes ?? this.mediaTimes,
    mediaVibrate: mediaVibrate ?? this.mediaVibrate,
    mediaPhoneMillis: mediaPhoneMillis ?? this.mediaPhoneMillis,
    altaTimes: altaTimes ?? this.altaTimes,
    altaEvery: altaEvery ?? this.altaEvery,
    altaFor: altaFor ?? this.altaFor,
    altaVibrate: altaVibrate ?? this.altaVibrate,
    altaFullScreen: altaFullScreen ?? this.altaFullScreen,
    altaSound: altaSound ?? this.altaSound,
    mediaPhoneUri: mediaPhoneUri ?? this.mediaPhoneUri,
    mediaPhoneName: mediaPhoneName ?? this.mediaPhoneName,
    altaPhoneUri: altaPhoneUri ?? this.altaPhoneUri,
    altaPhoneName: altaPhoneName ?? this.altaPhoneName,
    altaPhoneMillis: altaPhoneMillis ?? this.altaPhoneMillis,
  );

  Map<String, dynamic> toJson() => {
    'nVeces': normalTimes,
    'nCada': normalEvery,
    'nDurante': normalFor,
    'nVibrar': normalVibrate,
    'mCada': mediaEvery,
    'mDurante': mediaFor,
    'mHorario': mediaInHours,
    'mDesde': mediaFrom,
    'mHasta': mediaTo,
    'mSonido': mediaSound,
    'mVeces': mediaTimes,
    'mVibrar': mediaVibrate,
    'mTelMs': ?mediaPhoneMillis,
    'aVeces': altaTimes,
    'aCada': altaEvery,
    'aDurante': altaFor,
    'aVibrar': altaVibrate,
    'aPantalla': altaFullScreen,
    'aSonido': altaSound,
    'mTelUri': ?mediaPhoneUri,
    'mTelNombre': ?mediaPhoneName,
    'aTelUri': ?altaPhoneUri,
    'aTelNombre': ?altaPhoneName,
    'aTelMs': ?altaPhoneMillis,
  };

  String encode() => jsonEncode(toJson());

  static PriorityConfig decode(String? raw) {
    const d = PriorityConfig();
    if (raw == null) return d;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      int i(String k, int def) => j[k] is int ? j[k] as int : def;
      bool b(String k, bool def) => j[k] is bool ? j[k] as bool : def;
      String s(String k, String def) => j[k] is String ? j[k] as String : def;
      String? o(String k) => j[k] is String ? j[k] as String : null;
      return PriorityConfig(
        normalTimes: clampTimes(i('nVeces', d.normalTimes)),
        normalEvery: i('nCada', d.normalEvery),
        normalFor: i('nDurante', d.normalFor),
        normalVibrate: b('nVibrar', d.normalVibrate),
        mediaEvery: i('mCada', d.mediaEvery),
        mediaFor: i('mDurante', d.mediaFor),
        mediaInHours: b('mHorario', d.mediaInHours),
        mediaFrom: i('mDesde', d.mediaFrom),
        mediaTo: i('mHasta', d.mediaTo),
        mediaSound: s('mSonido', d.mediaSound),
        mediaTimes: clampTimes(i('mVeces', d.mediaTimes)),
        mediaVibrate: b('mVibrar', d.mediaVibrate),
        mediaPhoneMillis: j['mTelMs'] is int ? j['mTelMs'] as int : null,
        altaTimes: clampTimes(i('aVeces', d.altaTimes)),
        altaEvery: i('aCada', d.altaEvery),
        altaFor: i('aDurante', d.altaFor),
        altaVibrate: b('aVibrar', d.altaVibrate),
        altaFullScreen: b('aPantalla', d.altaFullScreen),
        altaSound: s('aSonido', d.altaSound),
        mediaPhoneUri: o('mTelUri'),
        mediaPhoneName: o('mTelNombre'),
        altaPhoneUri: o('aTelUri'),
        altaPhoneName: o('aTelNombre'),
        altaPhoneMillis: j['aTelMs'] is int ? j['aTelMs'] as int : null,
      );
    } catch (_) {
      return d;
    }
  }

  /// Horas en las que repite un aviso de prioridad media que tocó a las
  /// [first] (sin contar ese primer aviso).
  List<DateTime> mediaRepeats(DateTime first) {
    // Suena sin parar hasta "Hecho": no hace falta repetir.
    if (mediaTimes == 0 || mediaEvery <= 0) return const [];
    final every = Duration(minutes: mediaEvery);
    final DateTime end;
    var start = first.add(every);
    if (mediaInHours) {
      final day = DateTime(first.year, first.month, first.day);
      final from = day.add(Duration(hours: mediaFrom));
      end = day.add(Duration(hours: mediaTo <= mediaFrom ? 24 : mediaTo));
      while (start.isBefore(from)) {
        start = start.add(every);
      }
    } else {
      end = mediaFor == 0
          ? DateTime(first.year, first.month, first.day, 23, 59)
          : first.add(Duration(minutes: mediaFor));
    }
    return _steps(start, end, every);
  }

  /// Horas en las que vuelve a sonar un aviso de prioridad alta.
  List<DateTime> altaRepeats(DateTime first) {
    if (altaTimes == 0 || altaEvery <= 0) return const [];
    final every = Duration(minutes: altaEvery);
    final end = altaFor == 0
        ? first.add(every * maxRepeats)
        : first.add(Duration(minutes: altaFor));
    return _steps(first.add(every), end, every);
  }

  /// Horas en las que vuelve a sonar un aviso de prioridad normal.
  List<DateTime> normalRepeats(DateTime first) {
    if (normalTimes == 0 || normalEvery <= 0) return const [];
    final every = Duration(minutes: normalEvery);
    final end = normalFor == 0
        ? DateTime(first.year, first.month, first.day, 23, 59)
        : first.add(Duration(minutes: normalFor));
    return _steps(first.add(every), end, every);
  }

  /// Cuántas veces suena seguido y cada cuánto repite cada prioridad.
  (int times, int every) of(int priorityIndex) => switch (priorityIndex) {
    0 => (normalTimes, normalEvery),
    1 => (mediaTimes, mediaEvery),
    _ => (altaTimes, altaEvery),
  };

  /// Resumen de una prioridad: "1 vez, no repite", "3 veces, cada 3 min".
  String summary(int priorityIndex) {
    final (times, every) = of(priorityIndex);
    if (times == 0) return 'Hasta Hecho';
    final t = times == 1 ? '1 vez' : '$times veces';
    return every == 0 ? '$t, no repite' : '$t, cada $every min';
  }

  /// Lo que hace, en una frase: "Suena 1 vez, a la hora."
  String sentence(int priorityIndex) {
    final (times, every) = of(priorityIndex);
    if (times == 0) return 'Suena hasta que lo apagues.';
    final t = times == 1 ? 'Suena 1 vez' : 'Suena $times veces';
    return every == 0 ? '$t, a la hora.' : '$t, cada $every minutos.';
  }

  static List<DateTime> _steps(DateTime start, DateTime end, Duration every) {
    final out = <DateTime>[];
    for (
      var t = start;
      !t.isAfter(end) && out.length < maxRepeats;
      t = t.add(every)
    ) {
      out.add(t);
    }
    return out;
  }
}
