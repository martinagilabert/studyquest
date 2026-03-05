import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'study_screen.dart';
import 'agenda_screen.dart'; // <-- importamos tu agenda

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

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      try {
        DocumentReference userRef =
            _firestore.collection('users').doc(_currentUser!.uid);
        DocumentSnapshot userDoc = await userRef.get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          int puntos = userData['totalPoints'] ?? 0;
          int racha = userData['studyStreak'] ?? 0;
          String nombre = userData['name'] ?? '';

          Timestamp nowTimestamp = Timestamp.now();
          if (!userData.containsKey('lastStudy')) {
            await userRef.update({'lastStudy': nowTimestamp});
            userData['lastStudy'] = nowTimestamp;
          }

          Timestamp? lastStudyTimestamp = userData['lastStudy'];
          if (lastStudyTimestamp != null) {
            DateTime lastStudy = lastStudyTimestamp.toDate();
            Duration diff = DateTime.now().difference(lastStudy);
            if (diff.inHours >= 24) racha = 0;
          }

          setState(() {
            totalPoints = puntos;
            studyStreak = racha;
            name = nombre;
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos: ${e.toString()}')),
        );
      }
    }
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pop(context);
  }

  Future<void> _openFeature(String feature) async {
    if (feature == 'Estudio') {
      bool estudioCompletado = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StudyScreen()),
      );
      if (estudioCompletado == true && _currentUser != null) {
        await _updateStreakAndPoints();
      }
    } else if (feature == 'Agenda') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AgendaScreen()), // <-- Agenda
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$feature pendiente de implementar 🚀')),
      );
    }
  }

  Future<void> _updateStreakAndPoints() async {
    if (_currentUser == null) return;

    DocumentReference userRef =
        _firestore.collection('users').doc(_currentUser!.uid);
    DocumentSnapshot userDoc = await userRef.get();

    int racha = userDoc['studyStreak'] ?? 0;
    int puntos = userDoc['totalPoints'] ?? 0;
    Timestamp? lastStudyTimestamp = userDoc['lastStudy'];

    DateTime now = DateTime.now();

    if (lastStudyTimestamp != null) {
      DateTime lastStudy = lastStudyTimestamp.toDate();
      Duration diff = now.difference(lastStudy);
      if (diff.inHours >= 24) {
        racha = 1;
      } else {
        racha += 1;
      }
    } else {
      racha = 1;
    }

    int puntosGanados = 10;
    puntos += puntosGanados;

    await userRef.update({
      'studyStreak': racha,
      'totalPoints': puntos,
      'lastStudy': Timestamp.fromDate(now),
    });

    setState(() {
      studyStreak = racha;
      totalPoints = puntos;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Has ganado $puntosGanados puntos! Racha: $racha días 🚀'),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Flexible(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            )
          ],
        ),
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Text(value,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
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
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: _logout)],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, $name!',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildStatCard(Icons.star, 'Puntos totales', '$totalPoints', Colors.amber),
                      _buildStatCard(Icons.whatshot, 'Racha de estudio', '$studyStreak días', Colors.redAccent),
                    ],
                  ),
                  SizedBox(height: 30),
                  Text('Funciones rápidas',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.menu_book),
                        label: Text('Estudio'),
                        onPressed: () => _openFeature('Estudio'),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.school),
                        label: Text('Profesor Virtual'),
                        onPressed: () => _openFeature('Profesor Virtual'),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.event),
                        label: Text('Agenda'),
                        onPressed: () => _openFeature('Agenda'),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.map),
                        label: Text('Mapas Mentales'),
                        onPressed: () => _openFeature('Mapas Mentales'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add_task),
        onPressed: () => _openFeature('Micro-reto'),
        tooltip: 'Micro-reto diario',
      ),
    );
  }
}