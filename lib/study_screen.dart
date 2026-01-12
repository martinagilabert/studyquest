// lib/study_screen.dart
// StudyScreen avanzado + Música integrada (just_audio + file_picker)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

class StudyScreen extends StatefulWidget {
  @override
  _StudyScreenState createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Notificaciones
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Temporizador
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isInBreak = false;

  int _studyMinutes = 30;
  int _breakMinutes = 2;
  int _intervalBetweenBreaksMinutes = 0;
  int _totalSeconds = 0;
  int _secondsElapsed = 0;

  // Planes
  List<Map<String, dynamic>> _plans = [];
  String? _selectedPlanId;
  final _planNameController = TextEditingController();

  // UI
  bool _fullscreenLocked = false;

  // ------------------------ MÚSICA ------------------------
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentAudio;
  double _volume = 0.5;

  final List<Map<String, String>> _builtInTracks = [
    {"name": "Lofi suave", "path": "assets/audio/lofi1.mp3"},
    {"name": "Lluvia relajante", "path": "assets/audio/rain.mp3"},
    {"name": "Lofi profundo", "path": "assets/audio/lofi2.mp3"},
  ];

  Future<void> _playInternal(String assetPath) async {
    try {
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
      setState(() => _currentAudio = assetPath);
    } catch (e) {
      print("Error playing internal audio: $e");
    }
  }

  Future<void> _pickAndPlayExternal() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      setState(() => _currentAudio = filePath);
    }
  }

  Future<void> _toggleMusic() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    setState(() {});
  }

  // ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _loadPlans();
    _audioPlayer.setVolume(_volume);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _restoreSystemUI();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ---------------- Notificaciones ----------------
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: null,
      macOS: null,
      linux: null,
    );

    await _localNotifications.initialize(initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'study_timer_channel',
      'Study Timer',
      description: 'Notificaciones del temporizador de StudyQuest',
      importance: Importance.defaultImportance,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showPersistentNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'study_timer_channel',
      'Study Timer',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
    );

    await _localNotifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _cancelNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ---------------- Ciclo vida ----------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isRunning) {
        _showPersistentNotification(
            'StudyQuest — sesión en curso', _statusText());
      }
    } else if (state == AppLifecycleState.resumed) {
      _cancelNotifications();
    }
    super.didChangeAppLifecycleState(state);
  }

  // ---------------- Firestore ----------------
  Future<void> _loadPlans() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final qp = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('planners')
        .get();

    setState(() {
      _plans = qp.docs
          .map((d) => {
                'id': d.id,
                'name': d['name'],
                'study': d['study'],
                'pause': d['pause']
              })
          .toList();
    });
  }

  Future<void> _savePlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final name = _planNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Pon un nombre para el plan')));
      return;
    }

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('planners')
        .add({
      'name': name,
      'study': _studyMinutes,
      'pause': _breakMinutes,
      'createdAt': FieldValue.serverTimestamp()
    });

    setState(() {
      _plans.add({
        'id': doc.id,
        'name': name,
        'study': _studyMinutes,
        'pause': _breakMinutes
      });
      _planNameController.clear();
    });
  }

  // ---------------- UI Lock ----------------
  Future<void> _enterFullscreenLock() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() => _fullscreenLocked = true);
  }

  Future<void> _restoreSystemUI() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setState(() => _fullscreenLocked = false);
  }

  // ---------------- Temporizador ----------------
  void _configureTotalSeconds() {
    _totalSeconds = _studyMinutes * 60;
    _secondsElapsed = 0;
    _isInBreak = false;
  }

  void _startTimer() {
    if (_isRunning) return;

    _configureTotalSeconds();
    _enterFullscreenLock();

    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (_isPaused) return;

      setState(() => _secondsElapsed++);

      if (!kIsWeb) {
        final remaining = _totalSeconds - _secondsElapsed;
        if (remaining > 0) {
          _showPersistentNotification(
              'Estudiando', _formatTime(remaining) + ' restantes');
        }
      }

      if (_secondsElapsed >= _totalSeconds) {
        await _stopTimer(finished: true);
      }
    });
  }

  Future<void> _pauseTimer() async {
    if (!_isRunning) return;

    setState(() => _isPaused = true);
    await _showPersistentNotification('StudyQuest', 'Temporizador pausado');
  }

  Future<void> _resumeTimer() async {
    if (!_isRunning) return;

    setState(() => _isPaused = false);
    await _cancelNotifications();
  }

  Future<void> _stopTimer({bool finished = false}) async {
    _timer?.cancel();

    setState(() {
      _isRunning = false;
      _isPaused = false;
    });

    await _restoreSystemUI();
    await _cancelNotifications();

    if (finished) {
      await _registerSessionAndPoints();
      if (Navigator.canPop(context)) Navigator.pop(context, true);
    }
  }

  // ---------------- Sesión/Puntos ----------------
  Future<void> _registerSessionAndPoints() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);

    final minutosEstudio = (_totalSeconds / 60).round();
    final puntosGanados = minutosEstudio;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final currentPoints = (snap.data()?['totalPoints'] ?? 0) as int;

      tx.update(userRef, {
        'totalPoints': currentPoints + puntosGanados,
        'lastStudy': Timestamp.fromDate(DateTime.now()),
      });

      tx.set(userRef.collection('sessions').doc(), {
        'startedAt': Timestamp.fromDate(
            DateTime.now().subtract(Duration(seconds: _totalSeconds))),
        'endedAt': Timestamp.fromDate(DateTime.now()),
        'minutes': minutosEstudio,
        'points': puntosGanados
      });
    });
  }

  // ---------------- Helpers ----------------
  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _statusText() {
    if (!_isRunning) return 'Sin sesión';
    if (_isPaused) return 'Pausado';
    final remaining = (_totalSeconds - _secondsElapsed).clamp(0, _totalSeconds);
    return 'Restan ${_formatTime(remaining)}';
  }

  double _progressValue() {
    if (_totalSeconds == 0) return 0;
    return (_secondsElapsed / _totalSeconds).clamp(0.0, 1.0);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final remaining =
        (_totalSeconds - _secondsElapsed).clamp(0, _totalSeconds);

    return WillPopScope(
      onWillPop: () async {
        if (_fullscreenLocked && _isRunning) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Termina la sesión o pausa primero')),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Sesión de estudio"),
          actions: [
            IconButton(
              icon: Icon(_audioPlayer.playing
                  ? Icons.music_note
                  : Icons.music_off),
              tooltip: "Música",
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => _buildMusicSheet(),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.lock),
              onPressed: () {
                if (_fullscreenLocked)
                  _restoreSystemUI();
                else
                  _enterFullscreenLock();
              },
            ),
          ],
        ),

        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              //------------------------------------------
              // CONFIGURACIÓN
              //------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Estudio
                      Row(
                        children: [
                          Expanded(child: Text("Tiempo de estudio (min):")),
                          DropdownButton<int>(
                            value: _studyMinutes,
                            items: [15,20,25,30,40,50,60]
                                .map((m) => DropdownMenuItem(
                                    value: m, child: Text("$m")))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _studyMinutes = v!),
                          ),
                        ],
                      ),
                      // Pausa
                      Row(
                        children: [
                          Expanded(child: Text("Duración de pausa (min):")),
                          DropdownButton<int>(
                            value: _breakMinutes,
                            items: [1,2,3,5,10]
                                .map((m) => DropdownMenuItem(
                                    value: m, child: Text("$m")))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _breakMinutes = v!),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Guardar plan
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _planNameController,
                              decoration: InputDecoration(
                                  hintText: "Nombre del plan"),
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                              onPressed: _savePlan,
                              child: Text("Guardar")),
                        ],
                      ),

                      if (_plans.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Planes guardados:",
                              style:
                                  TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Wrap(
                          spacing: 8,
                          children: _plans.map((p) {
                            return ActionChip(
                              label: Text(
                                  "${p['name']} (${p['study']}m/${p['pause']}m)"),
                              onPressed: () {
                                setState(() {
                                  _studyMinutes = p['study'];
                                  _breakMinutes = p['pause'];
                                  _selectedPlanId = p['id'];
                                });
                              },
                            );
                          }).toList(),
                        )
                      ]
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              //------------------------------------------
              // TEMPORIZADOR
              //------------------------------------------
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: _progressValue(),
                            strokeWidth: 12,
                          ),
                        ),
                        Column(
                          children: [
                            Text(_statusText()),
                            SizedBox(height: 8),
                            Text(
                              _formatTime(remaining),
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(_isInBreak ? "En descanso" : "En estudio"),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    //------------------------------------------
                    // BOTONES
                    //------------------------------------------
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(_isRunning
                                ? (_isPaused
                                    ? Icons.play_arrow
                                    : Icons.pause)
                                : Icons.play_arrow),
                            label: Text(_isRunning
                                ? (_isPaused ? "Reanudar" : "Pausar")
                                : "Iniciar"),
                            onPressed: () {
                              if (!_isRunning)
                                _startTimer();
                              else if (_isPaused)
                                _resumeTimer();
                              else
                                _pauseTimer();
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: Icon(Icons.stop),
                          label: Text("Detener"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          onPressed: () {
                            if (_isRunning)
                              _stopTimer();
                            else
                              Navigator.pop(context, false);
                          },
                        )
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  //---------------------------------------------------
  //  PANEL DE MÚSICA (BOTTOM SHEET)
  //---------------------------------------------------
Widget _buildMusicSheet() {
  return SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Música", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),

          // Música interna
          Text("Pistas internas", style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: _builtInTracks.map((t) {
              return ElevatedButton(
                onPressed: () => _playInternal(t["path"]!),0
                child: Text(t["name"]!),
              );
            }).toList(),
          ),
          SizedBox(height: 16),

          // Música del dispositivo
          ElevatedButton.icon(10
            onPressed: _pickAndPlayExternal,
            icon: Icon(Icons.folder_open),
            label: Text("Elegir audio del dispositivo"),
          ),

          SizedBox(height: 16),

          // Volumen
          Text("Volumen"),
          Slider(
            value: _volume,
            min: 0,
            max: 1,
            onChanged: (v) {
              setState(() => _volume = v);
              _audioPlayer.setVolume(v);
            },
          ),

          // Play/Pause
          Center(
            child: IconButton(
              icon: Icon(
                _audioPlayer.playing ? Icons.pause_circle : Icons.play_circle,
                size: 48,
              ),
              onPressed: _toggleMusic,
            ),
          ),
          SizedBox(height: 16), // padding extra para que no se corte
        ],
      ),
    )
    );
  }
}
