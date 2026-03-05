import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;

Future<void> _register() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);
  FocusScope.of(context).unfocus();

  try {
    // 1️⃣ Crear usuario en Firebase Auth
    UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    String uid = userCredential.user!.uid;
    print("Usuario creado en Auth con UID: $uid");

    try {
      // 2️⃣ Crear documento en Firestore
      await _firestore.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'totalPoints': 0,
        'studyStreak': 0,
        'level': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print("Documento de Firestore creado para UID: $uid");
    } catch (e) {
      // 🔥 Si Firestore falla, eliminamos usuario Auth para rollback
      await userCredential.user!.delete();
      print("Firestore falló. Usuario Auth eliminado: $uid");
      throw Exception("No se pudo crear el perfil.");
    }

    // 3️⃣ Diálogo visual bonito
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('¡Bienvenido a StudyQuest!'),
          ],
        ),
        content: Text(
          'Tu aventura de estudio comienza ahora ! 🚀\n',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomeScreen()),
              );
            },
            child: Text(
              'Comenzar',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  } on FirebaseAuthException catch (e) {
    String message = "Error al registrarse";

    if (e.code == 'email-already-in-use') {
      message = "Ese email ya está registrado";
    } else if (e.code == 'invalid-email') {
      message = "Email inválido";
    } else if (e.code == 'weak-password') {
      message = "La contraseña es demasiado débil";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade400,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add,
                          size: 60, color: Colors.deepPurple),
                      SizedBox(height: 10),
                      Text(
                        "Crear Cuenta",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 30),

                      /// NAME
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: "Nombre",
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Introduce tu nombre";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 20),

                      /// EMAIL
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Introduce tu email";
                          }
                          if (!value.contains('@')) {
                            return "Email no válido";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 20),

                      /// PASSWORD
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Contraseña",
                          prefixIcon: Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Introduce una contraseña";
                          }
                          if (value.length < 6) {
                            return "Mínimo 6 caracteres";
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 30),

                      /// REGISTER BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  "Crear Cuenta",
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),

                      SizedBox(height: 15),

                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text("¿Ya tienes cuenta? Inicia sesión"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
