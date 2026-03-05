# StudyQuest

**StudyQuest** es una aplicación de estudio gamificada que combina gestión de sesiones de estudio, creación de esquemas, exámenes y un profesor IA virtual para ayudar al usuario a aprender de manera más eficiente y motivadora.

---

## 📌 Descripción

StudyQuest permite a los estudiantes organizar sus estudios, hacer resúmenes, realizar pruebas, interactuar con un asistente de IA y llevar un seguimiento de su progreso. Todo esto dentro de una interfaz intuitiva y gamificada que fomenta la constancia y la motivación.

---

## 🎯 Objetivos del Proyecto

1. Crear un **profesor virtual de IA** capaz de responder preguntas y generar exámenes.
2. Permitir al usuario **crear y organizar esquemas de estudio**.
3. Registrar **sesiones de estudio y resultados de exámenes**.
4. Implementar un sistema de **gamificación** con puntos y rachas.
5. Ofrecer una interfaz clara y funcional para **móvil**.
6. Almacenar datos en **Firebase** para persistencia y escalabilidad.

---

## 🛠 Tecnologías Utilizadas

- **Frontend:** Flutter (Dart)  
- **Backend / Base de Datos:** Firebase Firestore  
- **IA Local:** GPT4All (modelo local gratuito)  
- **Reconocimiento de Voz:** Vosk  
- **TTS (Text to Speech):** pyttsx3  
- **Gestión de procesos Python desde Dart:** `process_run`  
- **Control de versiones:** Git / GitHub  
- **Planificación:** Trello

---

## 📁 Estructura del Proyecto
│
├─ lib/
│ ├─ main.dart
│ ├─ screens/
│ │ ├─ login_screen.dart
│ │ ├─ home_screen.dart
│ │ ├─ study_screen.dart
│ │ └─ professor_ai_screen.dart
│ ├─ widgets/
│ └─ utils/
│
├─ python_ai/
│ ├─ professor_local.py
│ ├─ voice_assistant.py
│ ├─ models/
│ │ └─ ggml-gpt4all-small.bin
│ └─ requirements.txt
│
├─ pubspec.yaml
└─ README.md
---
Autor: Martina
Fecha: 2026-02-20
