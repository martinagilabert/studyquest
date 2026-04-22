# StudyQuest 1.1

**StudyQuest 1.1** es una aplicación de estudio gamificada que ayuda al usuario a organizar su aprendizaje, realizar sesiones de estudio, interactuar con un profesor virtual con IA y generar exámenes tipo test a partir de sus conversaciones.

---

## 📌 Descripción

StudyQuest combina herramientas de productividad y aprendizaje en una sola app. El usuario puede estudiar con temporizador, guardar planes de estudio, escuchar música durante la sesión, hablar con un profesor virtual, guardar conversaciones, generar exámenes tipo test desde esos chats y revisar su progreso con puntos y retos.

La app está pensada para ofrecer una experiencia visual, intuitiva y motivadora en móvil.

---

## 🎯 Funcionalidades actuales

- **Profesor Virtual con IA local**
  - Crear chats nuevos
  - Guardar historial de chats
  - Reabrir conversaciones anteriores
  - Continuar un chat ya existente

- **Exámenes tipo test**
  - Generar exámenes desde un chat guardado
  - Añadir un prompt opcional para ajustar dificultad o enfoque
  - Corregir el examen en la app
  - Guardar examen, nota y respuestas en Firebase
  - Revisar exámenes desde el historial

- **Sesión de estudio**
  - Temporizador de estudio
  - Pausas configurables
  - Guardado de planes de estudio
  - Música integrada
  - Notificaciones locales durante la sesión

- **Gamificación**
  - Sistema de puntos
  - Retos diarios
  - Seguimiento del progreso del usuario

- **Otras secciones**
  - Agenda
  - Ajustes de usuario

---

## 🛠 Tecnologías utilizadas

- **Frontend:** Flutter (Dart)
- **Autenticación y base de datos:** Firebase Auth + Cloud Firestore
- **Backend IA local:** Python + FastAPI
- **Modelo local:** Ollama
- **Audio:** just_audio
- **Selector de archivos:** file_picker
- **Notificaciones locales:** flutter_local_notifications
- **Control de versiones:** Git / GitHub

---

## 📁 Estructura general del proyecto

lib/
  main.dart
  home_screen.dart
  study_screen.dart
  agenda_screen.dart
  settings_screen.dart
  ai_chat_screen.dart
  ai_chat_list_screen.dart
  professor_virtual_home_screen.dart
  professor_virtual_chats_screen.dart
  professor_virtual_exams_screen.dart
  professor_virtual_exam_take_screen.dart
  professor_virtual_exam_history_screen.dart
  professor_virtual_exam_review_screen.dart
  ai_service.dart
  services/
    chat_firestore_service.dart
    exam_firestore_service.dart

python_ai/
  server.py

---

## 🚀 Objetivo del proyecto

El objetivo de StudyQuest es ofrecer una experiencia de estudio más completa, motivadora y personalizada, integrando productividad, seguimiento del progreso y asistencia con IA dentro de una sola aplicación.

---

Autor: Martina
Versión: StudyQuest 1.1
Fecha: 2026-04-22
