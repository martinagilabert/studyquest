import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'study_screen.dart'; // Importamos la pantalla de estudio

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

        // Inicializar lastStudy si no existe con la fecha actual
        Timestamp nowTimestamp = Timestamp.now();
        if (!userData.containsKey('lastStudy')) {
          await userRef.update({'lastStudy': nowTimestamp});
          userData['lastStudy'] = nowTimestamp;
        }

        // Lógica de racha de 24h
        Timestamp? lastStudyTimestamp = userData['lastStudy'];
        if (lastStudyTimestamp != null) {
          DateTime lastStudy = lastStudyTimestamp.toDate();
          Duration diff = DateTime.now().difference(lastStudy);
          if (diff.inHours >= 24) {
            racha = 0; // reiniciamos racha si han pasado más de 24h
          }
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
    Navigator.pop(context); // vuelve al login
  }

  Widget _buildCard(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _openFeature(String feature) async {
    if (feature == 'Estudio') {
      // Abrimos StudyScreen y esperamos a que termine la sesión
      bool estudioCompletado = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StudyScreen()),
      );

      // Si la sesión se completó, actualizamos puntos y racha
      if (estudioCompletado == true && _currentUser != null) {
        await _updateStreakAndPoints();
      }
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

    // Revisamos la racha de 24h
    if (lastStudyTimestamp != null) {
      DateTime lastStudy = lastStudyTimestamp.toDate();
      Duration diff = now.difference(lastStudy);
      if (diff.inHours >= 24) {
        racha = 1; // reiniciamos racha
      } else {
        racha += 1; // incrementamos racha
      }
    } else {
      racha = 1; // primera sesión
    }

    int puntosGanados = 10; // ejemplo: 10 puntos por sesión
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
          content: Text(
              '¡Has ganado $puntosGanados puntos! Racha: $racha días 🚀')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('StudyQuest'),
        actions: [
          IconButton(icon: Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, $name!',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  _buildCard(Icons.star, 'Puntos totales', '$totalPoints',
                      Colors.amber),
                  _buildCard(Icons.whatshot, 'Racha de estudio',
                      '$studyStreak días', Colors.redAccent),
                  SizedBox(height: 20),
                  Text('Funciones rápidas',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.menu_book),
                        label: Text('Estudio'),
                        onPressed: () => _openFeature('Estudio'),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.auto_graph),
                        label: Text('Gamificación'),
                        onPressed: () => _openFeature('Gamificación'),
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
