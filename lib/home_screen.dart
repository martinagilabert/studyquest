import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'study_screen.dart';
import 'agenda_screen.dart';
import 'settings_screen.dart'; // Importante para la navegación

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  int totalPoints = 0;
  int studyStreak = 0;
  String name = '';
  bool _isLoading = true;

  List<Map<String, dynamic>> dailyChallenges = [];
  
  final List<Map<String, dynamic>> _challengePool = [
    {'id': 'agenda', 'text': 'Registra un evento en la agenda', 'points': 10},
    {'id': 'study_15', 'text': 'Estudia durante 15 minutos', 'points': 15},
    {'id': 'virtual_prof', 'text': 'Habla con tu profesor virtual', 'points': 10},
    {'id': 'mind_map', 'text': 'Crea un nuevo mapa mental', 'points': 20},
    {'id': 'review', 'text': 'Repasa tus notas de ayer', 'points': 5},
    {'id': 'complete_profile', 'text': 'Actualiza tu perfil', 'points': 10},
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;
    try {
      DocumentReference userRef = _firestore.collection('users').doc(_currentUser!.uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        setState(() {
          totalPoints = userData['totalPoints'] ?? 0;
          studyStreak = userData['studyStreak'] ?? 0;
          name = userData['name'] ?? '';
        });

        await _handleDailyChallenges(userRef, userData);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDailyChallenges(DocumentReference userRef, Map<String, dynamic> userData) async {
    DateTime now = DateTime.now();
    String todayKey = "${now.year}-${now.month}-${now.day}";

    if (userData['lastChallengeDate'] == todayKey && userData['dailyChallenges'] != null) {
      dailyChallenges = List<Map<String, dynamic>>.from(userData['dailyChallenges']);
    } else {
      var random = Random();
      List<Map<String, dynamic>> shuffled = List.from(_challengePool)..shuffle(random);
      dailyChallenges = shuffled.take(3).map((c) => {...c, 'completed': false}).toList();

      await userRef.update({
        'lastChallengeDate': todayKey,
        'dailyChallenges': dailyChallenges,
      });
    }
  }

  void _showChallengesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              SizedBox(height: 20),
              Text('Micro-retos de hoy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[900])),
              SizedBox(height: 20),
              ...dailyChallenges.asMap().entries.map((entry) {
                var c = entry.value;
                bool isDone = c['completed'] == true;
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.green[50] : Colors.blue[50], 
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isDone ? Colors.green.shade200 : Colors.blue.shade100),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isDone ? Colors.green : Colors.blue[400],
                    ),
                    title: Text(c['text'], 
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDone ? Colors.green[700] : Colors.blue[900],
                        decoration: isDone ? TextDecoration.lineThrough : null
                      )),
                    trailing: Text('+${c['points']} pts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[900])),
                    onTap: () {
                      if (!isDone) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Te falta completar: ${c['text']}'), 
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.blue[800],
                          )
                        );
                      }
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _completeChallenge(String challengeId) async {
    int index = dailyChallenges.indexWhere((c) => c['id'] == challengeId);
    if (index != -1 && !dailyChallenges[index]['completed']) {
      setState(() {
        dailyChallenges[index]['completed'] = true;
        totalPoints += dailyChallenges[index]['points'] as int;
      });

      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'totalPoints': totalPoints,
        'dailyChallenges': dailyChallenges,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Reto completado! +${dailyChallenges[index]['points']} puntos 🏆'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _openFeature(String feature) async {
    if (feature == 'Estudio') {
      bool? completado = await Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScreen()));
      if (completado == true) {
        await _completeChallenge('study_15');
      }
    } else if (feature == 'Agenda') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AgendaScreen()));
      await _completeChallenge('agenda');
    } else if (feature == 'Profesor Virtual') {
       await _completeChallenge('virtual_prof');
    }
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Flexible(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  Text(value, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('StudyQuest'),
        // He quitado el logout de aquí para que la cabecera quede más limpia
        // ahora que tenemos el botón de ajustes abajo.
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABECERA CON BOTÓN DE AJUSTES EN GRIS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Hola, $name!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.settings, color: Colors.grey),
                        onPressed: () async {
                          // Al volver de ajustes recargamos los datos por si cambió el nombre
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
                          _loadUserData();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      _buildStatCard(Icons.star, 'Puntos', '$totalPoints', Colors.amber),
                      SizedBox(width: 16),
                      _buildStatCard(Icons.whatshot, 'Racha', '$studyStreak días', Colors.redAccent),
                    ],
                  ),
                  SizedBox(height: 35),
                  Text('Funciones rápidas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 15),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      _quickButton(Icons.menu_book, 'Estudio', Colors.blue, () => _openFeature('Estudio')),
                      _quickButton(Icons.school, 'Profesor Virtual', Colors.purple, () => _openFeature('Profesor Virtual')),
                      _quickButton(Icons.event, 'Agenda', Colors.orange, () => _openFeature('Agenda')),
                      _quickButton(Icons.map, 'Mapas Mentales', Colors.green, () => _openFeature('Mapas Mentales')),
                    ],
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add_task),
        onPressed: _showChallengesModal,
        backgroundColor: const Color.fromARGB(255, 217, 222, 255),
        tooltip: 'Ver retos del día',
      ),
    );
  }

  Widget _quickButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}