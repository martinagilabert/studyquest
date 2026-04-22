// lib/study_screen.dart
// StudyScreen mejorado visualmente + Música integrada

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

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isInBreak = false;

  int _studyMinutes = 30;
  int _breakMinutes = 2;
  int _intervalBetweenBreaksMinutes = 0;
  int _totalSeconds = 0;
  int _secondsElapsed = 0;

  List<Map<String, dynamic>> _plans = [];
  String? _selectedPlanId;
  final _planNameController = TextEditingController();

  bool _fullscreenLocked = false;

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
    _planNameController.dispose();
    super.dispose();
  }

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isRunning) {
        _showPersistentNotification(
          'StudyQuest — sesión en curso',
          _statusText(),
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      _cancelNotifications();
    }
    super.didChangeAppLifecycleState(state);
  }

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
                'pause': d['pause'],
              })
          .toList();
    });
  }

  Future<void> _savePlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final name = _planNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pon un nombre para el plan')),
      );
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
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _plans.add({
        'id': doc.id,
        'name': name,
        'study': _studyMinutes,
        'pause': _breakMinutes,
      });
      _planNameController.clear();
    });
  }

  Future<void> _enterFullscreenLock() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() => _fullscreenLocked = true);
  }

  Future<void> _restoreSystemUI() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) {
      setState(() => _fullscreenLocked = false);
    }
  }

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

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isPaused) return;

      setState(() => _secondsElapsed++);

      if (!kIsWeb) {
        final remaining = _totalSeconds - _secondsElapsed;
        if (remaining > 0) {
          _showPersistentNotification(
            'Estudiando',
            '${_formatTime(remaining)} restantes',
          );
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
          DateTime.now().subtract(Duration(seconds: _totalSeconds)),
        ),
        'endedAt': Timestamp.fromDate(DateTime.now()),
        'minutes': minutosEstudio,
        'points': puntosGanados,
      });
    });
  }
  Future<void> _deleteSession({
  required String sessionId,
  required int sessionPoints,
}) async {
  final user = _auth.currentUser;
  if (user == null) return;

  final userRef = _firestore.collection('users').doc(user.uid);
  final sessionRef = userRef.collection('sessions').doc(sessionId);

  await _firestore.runTransaction((tx) async {
    final userSnap = await tx.get(userRef);
    final sessionSnap = await tx.get(sessionRef);

    if (!sessionSnap.exists) return;

    final currentPoints = ((userSnap.data()?['totalPoints'] ?? 0) as num).toInt();
    final newPoints = currentPoints - sessionPoints;

    tx.delete(sessionRef);
    tx.update(userRef, {
      'totalPoints': newPoints < 0 ? 0 : newPoints,
    });
  });

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesión eliminada correctamente')),
    );
  }
}

String _formatSessionDate(Timestamp? timestamp) {
  if (timestamp == null) return 'Sin fecha';

  final date = timestamp.toDate();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');

  return '${date.day}/${date.month}/${date.year} · $hour:$minute';
}

Future<void> _confirmDeleteSession({
  required String sessionId,
  required int sessionPoints,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Eliminar sesión'),
        content: const Text(
          '¿Seguro que quieres eliminar esta sesión? También se restarán sus puntos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      );
    },
  );

  if (confirm == true) {
    await _deleteSession(
      sessionId: sessionId,
      sessionPoints: sessionPoints,
    );
  }
}

void _showSessionsHistorySheet() {
  final user = _auth.currentUser;
  if (user == null) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sesiones guardadas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Aquí puedes revisar y eliminar sesiones anteriores.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(user.uid)
                        .collection('sessions')
                        .orderBy('endedAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      final sessions = snapshot.data?.docs ?? [];

                      if (sessions.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_toggle_off,
                                size: 54,
                                color: Colors.indigo.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Todavía no tienes sesiones guardadas.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final data = session.data() as Map<String, dynamic>;

                          final minutes = ((data['minutes'] ?? 0) as num).toInt();
                          final points = ((data['points'] ?? 0) as num).toInt();
                          final endedAt = data['endedAt'] as Timestamp?;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.withOpacity(0.12),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: Colors.indigo,
                                ),
                              ),
                              title: Text(
                                '$minutes min de estudio',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Puntos ganados: +$points'),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatSessionDate(endedAt),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Eliminar sesión',
                                onPressed: () {
                                  _confirmDeleteSession(
                                    sessionId: session.id,
                                    sessionPoints: points,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _statusText() {
    if (!_isRunning) return 'Preparada para empezar';
    if (_isPaused) return 'Sesión en pausa';
    final remaining = (_totalSeconds - _secondsElapsed).clamp(0, _totalSeconds);
    return 'Restan ${_formatTime(remaining)}';
  }

  double _progressValue() {
    if (_totalSeconds == 0) return 0;
    return (_secondsElapsed / _totalSeconds).clamp(0.0, 1.0);
  }

  Color _statusColor() {
    if (!_isRunning) return Colors.indigo;
    if (_isPaused) return Colors.orange;
    if (_isInBreak) return Colors.teal;
    return Colors.green;
  }

  Widget _buildHeaderCard() {
    final hasMusic = _currentAudio != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B5FEF), Color(0xFF7B7FF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B5FEF).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sesión de estudio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Configura tu concentración, guarda planes y estudia con música si te ayuda.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoChip(Icons.timer_outlined, '$_studyMinutes min estudio'),
              _buildInfoChip(Icons.free_breakfast_outlined, '$_breakMinutes min pausa'),
              _buildInfoChip(
                hasMusic ? Icons.music_note : Icons.music_off,
                hasMusic ? 'Música lista' : 'Sin música',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildConfigRow({
    required String label,
    required IconData icon,
    required int value,
    required List<int> options,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.indigo.withOpacity(0.10),
            child: Icon(icon, color: Colors.indigo, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<int>(
              value: value,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(16),
              items: options
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text('$m'),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ajusta tu tiempo de estudio y guarda combinaciones que uses mucho.',
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _buildConfigRow(
            label: 'Tiempo de estudio (min)',
            icon: Icons.school_outlined,
            value: _studyMinutes,
            options: [15, 20, 25, 30, 40, 50, 60],
            onChanged: (v) => setState(() => _studyMinutes = v!),
          ),
          _buildConfigRow(
            label: 'Duración de pausa (min)',
            icon: Icons.coffee_outlined,
            value: _breakMinutes,
            options: [1, 2, 3, 5, 10],
            onChanged: (v) => setState(() => _breakMinutes = v!),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _planNameController,
                  decoration: InputDecoration(
                    hintText: 'Nombre del plan',
                    filled: true,
                    fillColor: const Color(0xFFF7F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _savePlan,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          if (_plans.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Planes guardados',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _plans.map((p) {
                final isSelected = _selectedPlanId == p['id'];
                return ChoiceChip(
                  selected: isSelected,
                  label: Text('${p['name']} (${p['study']}m/${p['pause']}m)'),
                  selectedColor: Colors.indigo.withOpacity(0.14),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.indigo : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.indigo.withOpacity(0.35)
                        : Colors.grey.shade300,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _studyMinutes = p['study'];
                      _breakMinutes = p['pause'];
                      _selectedPlanId = p['id'];
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerSection(int remainingDisplay) {
    final progress = _progressValue();
    final statusColor = _statusColor();

    return _buildSectionCard(
      child: Column(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 12, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      _statusText(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (_isInBreak ? Colors.teal : Colors.indigo)
                      .withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isInBreak ? 'Descanso' : 'Estudio',
                  style: TextStyle(
                    color: _isInBreak ? Colors.teal : Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 14,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF9FAFF),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRunning
                              ? (_isPaused ? 'Pausado' : 'En curso')
                              : 'Listo',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _formatTime(remainingDisplay),
                            key: ValueKey(remainingDisplay),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(value * 100).round()}%',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMiniStat(
                'Estudio',
                '$_studyMinutes min',
                Icons.menu_book_rounded,
                Colors.indigo,
              ),
              const SizedBox(width: 12),
              _buildMiniStat(
                'Pausa',
                '$_breakMinutes min',
                Icons.coffee_rounded,
                Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(
                    !_isRunning
                        ? Icons.play_arrow_rounded
                        : _isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                  ),
                  label: Text(
                    !_isRunning
                        ? 'Iniciar'
                        : _isPaused
                            ? 'Reanudar'
                            : 'Pausar',
                  ),
                  onPressed: () {
                    if (!_isRunning) {
                      _startTimer();
                    } else if (_isPaused) {
                      _resumeTimer();
                    } else {
                      _pauseTimer();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(_isRunning ? 'Detener' : 'Salir'),
                  onPressed: () {
                    if (_isRunning) {
                      _stopTimer();
                    } else {
                      Navigator.pop(context, false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMusicSheet() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Música",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentAudio == null
                        ? 'Elige una pista para acompañar la sesión.'
                        : 'Tienes una pista seleccionada.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.indigo.withOpacity(0.14),
                          child: Icon(
                            _audioPlayer.playing
                                ? Icons.music_note
                                : Icons.music_off,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _currentAudio == null
                                ? 'No hay audio cargado'
                                : _currentAudio!.split('/').last,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Pistas internas",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _builtInTracks.map((t) {
                      final isCurrent = _currentAudio == t["path"];
                      return ChoiceChip(
                        selected: isCurrent,
                        label: Text(t["name"]!),
                        selectedColor: Colors.indigo.withOpacity(0.14),
                        onSelected: (_) async {
                          await _playInternal(t["path"]!);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _pickAndPlayExternal();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text("Elegir audio del dispositivo"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Volumen",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _volume,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      setModalState(() {});
                      _audioPlayer.setVolume(v);
                    },
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: IconButton(
                      iconSize: 54,
                      icon: Icon(
                        _audioPlayer.playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.indigo,
                      ),
                      onPressed: () async {
                        await _toggleMusic();
                        setModalState(() {});
                      },
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

  @override
  Widget build(BuildContext context) {
    final remaining =
        (_totalSeconds - _secondsElapsed).clamp(0, _totalSeconds);
    final remainingDisplay = _isRunning ? remaining : _studyMinutes * 60;

    return WillPopScope(
      onWillPop: () async {
        if (_fullscreenLocked && _isRunning) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Termina la sesión o pausa primero'),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        appBar: AppBar(
          title: const Text("Sesión de estudio"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
  IconButton(
    icon: Icon(
      _audioPlayer.playing ? Icons.music_note : Icons.music_off,
    ),
    tooltip: "Música",
    onPressed: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        builder: (_) => _buildMusicSheet(),
      );
    },
  ),
  IconButton(
    icon: Icon(
      _fullscreenLocked ? Icons.lock : Icons.lock_open,
    ),
    tooltip: 'Bloqueo de pantalla',
    onPressed: () {
      if (_fullscreenLocked) {
        _restoreSystemUI();
      } else {
        _enterFullscreenLock();
      }
    },
  ),
],
        ),
   body: SafeArea(
  child: LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 24,
          ),
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildSettingsCard(),
              const SizedBox(height: 16),
              _buildTimerSection(remainingDisplay),
            ],
          ),
        ),
      );
    },
  ),
),
      ),
    );
  }
}