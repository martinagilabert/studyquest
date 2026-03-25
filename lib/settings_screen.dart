import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Estados de configuración
  bool _streakReminders = true;
  bool _agendaAlerts = true;
  int _currentPoints = 0; 
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _currentPoints = data['totalPoints'] ?? 0;
        });
      }
    }
  }

  // --- ACCIONES ---

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'name': _nameController.text.trim(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Perfil actualizado'), backgroundColor: Colors.green)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _resetPassword() async {
    try {
      await _auth.sendPasswordResetEmail(email: _auth.currentUser!.email!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Correo de recuperación enviado a ${_auth.currentUser!.email}'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar el correo')));
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar cuenta?'),
        content: Text('¿Estás realmente seguro? Se perderán todos tus puntos ($_currentPoints pts) y progresos de forma permanente.'),
        actions: [
          TextButton(child: Text('Cancelar'), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text('ELIMINAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () async {
              try {
                String uid = _auth.currentUser!.uid;
                await _firestore.collection('users').doc(uid).delete();
                await _auth.currentUser!.delete();
                Navigator.of(context).popUntil((route) => route.isFirst);
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: Reautenticación requerida'), backgroundColor: Colors.red)
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // --- INTERFAZ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajustes'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Perfil'),
            _buildCard([
              ListTile(
                leading: Icon(Icons.person, color: Colors.blue),
                title: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(hintText: 'Tu nombre', border: InputBorder.none),
                ),
                trailing: _isSaving 
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(icon: Icon(Icons.check, color: Colors.green), onPressed: _updateProfile),
              ),
            ]),

            _sectionTitle('Notificaciones'),
            _buildCard([
              SwitchListTile(
                secondary: Icon(Icons.whatshot, color: Colors.orange),
                title: Text('Recordatorio de Racha'),
                subtitle: Text('Aviso si no has completado tus retos'),
                value: _streakReminders,
                onChanged: (val) => setState(() => _streakReminders = val),
              ),
              SwitchListTile(
                secondary: Icon(Icons.notifications_active, color: Colors.blue),
                title: Text('Alertas de Agenda'),
                subtitle: Text('Notificar eventos próximos'),
                value: _agendaAlerts,
                onChanged: (val) => setState(() => _agendaAlerts = val),
              ),
            ]),

            _sectionTitle('Cuenta y Seguridad'),
            _buildCard([
              ListTile(
                leading: Icon(Icons.lock_reset, color: Colors.blueGrey),
                title: Text('Cambiar Contraseña'),
                onTap: _resetPassword,
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text('Eliminar Cuenta', style: TextStyle(color: Colors.red)),
                onTap: _confirmDeleteAccount,
              ),
            ]),
            
            SizedBox(height: 30),
            Center(
              child: TextButton.icon(
                onPressed: () => _auth.signOut().then((_) => Navigator.pop(context)),
                icon: Icon(Icons.logout, color: Colors.grey),
                label: Text('Cerrar Sesión', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }
}