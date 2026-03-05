import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class AgendaScreen extends StatefulWidget {
  @override
  _AgendaScreenState createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    initializeDateFormatting('es_ES', null);
    _loadEvents();
  }

  // Convierte Timestamp o DateTime a DateTime
  DateTime getDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw Exception('Tipo de fecha desconocido');
  }

  Future<void> _loadEvents() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .get();

    Map<DateTime, List<Map<String, dynamic>>> eventsMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      DateTime date = getDateTime(data['start']);
      final day = DateTime(date.year, date.month, date.day);

      if (!eventsMap.containsKey(day)) eventsMap[day] = [];
      eventsMap[day]!.add({
        'id': doc.id,
        'title': data['title'],
        'start': data['start'],
        'end': data['end'],
        'allDay': data['allDay'] ?? false,
      });
    }

    setState(() {
      _events = eventsMap;
    });
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _events[d] ?? [];
  }

  // Agregar evento
  Future<void> _addEvent() async {
    final titleController = TextEditingController();
    DateTime start = _selectedDay ?? DateTime.now();
    DateTime end = start.add(Duration(hours: 1));
    bool allDay = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Crear Evento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'Nombre del evento'),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: allDay,
                      onChanged: (v) =>
                          setStateDialog(() => allDay = v ?? false),
                    ),
                    Text('Todo el día')
                  ],
                ),
                if (!allDay) ...[
                  Row(
                    children: [
                      Text('Inicio: '),
                      TextButton(
                        child: Text(DateFormat('HH:mm').format(start)),
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(start));
                          if (t != null)
                            setStateDialog(() => start = DateTime(
                                start.year,
                                start.month,
                                start.day,
                                t.hour,
                                t.minute));
                        },
                      )
                    ],
                  ),
                  Row(
                    children: [
                      Text('Fin: '),
                      TextButton(
                        child: Text(DateFormat('HH:mm').format(end)),
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(end));
                          if (t != null)
                            setStateDialog(() => end = DateTime(
                                end.year,
                                end.month,
                                end.day,
                                t.hour,
                                t.minute));
                        },
                      )
                    ],
                  ),
                ]
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;

                  final user = _auth.currentUser;
                  if (user == null) return;

                  DateTime saveStart = allDay
                      ? DateTime(start.year, start.month, start.day)
                      : start;
                  DateTime saveEnd = allDay
                      ? DateTime(start.year, start.month, start.day, 23, 59)
                      : end;

                  final docRef = await _firestore
                      .collection('users')
                      .doc(user.uid)
                      .collection('events')
                      .add({
                    'title': title,
                    'start': Timestamp.fromDate(saveStart),
                    'end': Timestamp.fromDate(saveEnd),
                    'allDay': allDay,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  setState(() {
                    final dayKey =
                        DateTime(saveStart.year, saveStart.month, saveStart.day);
                    _events.putIfAbsent(dayKey, () => []);
                    _events[dayKey]!.add({
                      'id': docRef.id,
                      'title': title,
                      'start': saveStart,
                      'end': saveEnd,
                      'allDay': allDay,
                    });
                  });

                  Navigator.pop(context);
                },
                child: Text('Guardar'),
              )
            ],
          );
        },
      ),
    );
  }

  // Eliminar evento seguro
  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .doc(event['id'])
        .delete();

    setState(() {
      final dayKey = _selectedDay != null
          ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
          : null;

      if (dayKey != null && _events[dayKey] != null) {
        _events[dayKey]!.removeWhere((e) => e['id'] == event['id']);
        if (_events[dayKey]!.isEmpty) {
          _events.remove(dayKey);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agenda')),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: _addEvent,
      ),
      body: Column(
        children: [
          // Botones de vista Día / Semana / Mes
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () =>
                      setState(() => _calendarFormat = CalendarFormat.week),
                  child: Text('Semana'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      setState(() => _calendarFormat = CalendarFormat.month),
                  child: Text('Mes'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      setState(() => _calendarFormat = CalendarFormat.twoWeeks),
                  child: Text('Día extendido'),
                ),
              ],
            ),
          ),
          TableCalendar(
            locale: 'es_ES',
            startingDayOfWeek: StartingDayOfWeek.monday,
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getEventsForDay,
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) => setState(() => _calendarFormat = format),
            calendarStyle: CalendarStyle(
              todayDecoration:
                  BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
              selectedDecoration:
                  BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: _getEventsForDay(_selectedDay!).map((event) {
                final startTime =
                    DateFormat('HH:mm').format(getDateTime(event['start']));
                final endTime =
                    DateFormat('HH:mm').format(getDateTime(event['end']));
                return Card(
                  child: ListTile(
                    title: Text(event['title']),
                    subtitle: Text(event['allDay']
                        ? 'Todo el día'
                        : '$startTime - $endTime'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEvent(event),
                    ),
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}