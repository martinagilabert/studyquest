import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class AgendaScreen extends StatefulWidget {
  @override
  _AgendaScreenState createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  CalendarController _calendarController = CalendarController();
  DateTime _selectedDate = DateTime.now();
  
  late MeetingDataSource _eventsSource;
  List<Appointment> _appointments = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null);
    _initNotifications();
    _calendarController.view = CalendarView.week;
    _eventsSource = MeetingDataSource(_appointments);
    _loadEvents();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await notificationsPlugin.initialize(
      InitializationSettings(android: androidSettings),
    );
  }

  Future<void> _scheduleNotification(String title, DateTime date) async {
    await notificationsPlugin.zonedSchedule(
      date.millisecondsSinceEpoch ~/ 1000,
      'Recordatorio',
      title,
      tz.TZDateTime.from(date, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'events',
          'Eventos',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  DateTime getDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return value;
  }

  Color getColorFromString(String color) {
    switch (color) {
      case 'rojo': return Colors.red;
      case 'verde': return Colors.green;
      case 'azul': return Colors.blue;
      case 'amarillo': return Colors.orange;
      case 'morado': return Colors.purple;
      case 'rosa': return Colors.pink;
      case 'turquesa': return Colors.teal;
      case 'gris': return Colors.grey;
      case 'naranja': return Colors.deepOrange;
      default: return Colors.indigo;
    }
  }

  String _colorToString(Color color) {
    if (color == Colors.red) return 'rojo';
    if (color == Colors.green) return 'verde';
    if (color == Colors.blue) return 'azul';
    if (color == Colors.orange) return 'amarillo';
    if (color == Colors.purple) return 'morado';
    if (color == Colors.pink) return 'rosa';
    if (color == Colors.teal) return 'turquesa';
    if (color == Colors.grey) return 'gris';
    if (color == Colors.deepOrange) return 'naranja';
    return 'azul';
  }

  Future<void> _loadEvents() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .get();

    List<Appointment> loaded = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      loaded.add(Appointment(
        id: doc.id,
        startTime: getDateTime(data['start']),
        endTime: getDateTime(data['end']),
        subject: data['title'],
        color: getColorFromString(data['color'] ?? 'azul'),
        isAllDay: data['allDay'] ?? false,
      ));
    }

    setState(() {
      _appointments = loaded;
      _eventsSource = MeetingDataSource(_appointments);
    });
  }

  Future<void> _openEventDialog({Appointment? existing}) async {
    final controller = TextEditingController(text: existing?.subject ?? '');
    DateTime start = existing?.startTime ?? _selectedDate;
    DateTime end = existing?.endTime ?? start.add(Duration(hours: 1));
    String color = existing?.color != null ? _colorToString(existing!.color) : 'azul';
    bool allDay = existing?.isAllDay ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) { // Añadido context explícito aquí
        return StatefulBuilder(builder: (context, setStateDialog) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              top: 20, left: 20, right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null ? "Nuevo evento" : "Editar evento",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                TextField(
                    controller: controller,
                    decoration: InputDecoration(labelText: 'Título')),
                SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: allDay,
                      onChanged: (v) => setStateDialog(() => allDay = v!),
                    ),
                    Text('Todo el día')
                  ],
                ),
                if (!allDay)
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text("Inicio"),
                          subtitle: Text(DateFormat.Hm('es_ES').format(start)),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(start),
                            );
                            if (t != null) {
                              setStateDialog(() {
                                start = DateTime(start.year, start.month,
                                    start.day, t.hour, t.minute);
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: Text("Fin"),
                          subtitle: Text(DateFormat.Hm('es_ES').format(end)),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(end),
                            );
                            if (t != null) {
                              setStateDialog(() {
                                end = DateTime(end.year, end.month, end.day,
                                    t.hour, t.minute);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 10),
                DropdownButton<String>(
                  value: color,
                  isExpanded: true,
                  items: ['azul', 'rojo', 'verde', 'amarillo', 'morado', 'rosa', 'turquesa', 'gris', 'naranja']
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                CircleAvatar(backgroundColor: getColorFromString(c), radius: 8),
                                SizedBox(width: 10),
                                Text(c),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => color = v!),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 45)),
                  child: Text("Guardar"),
                  onPressed: () async {
                    final title = controller.text.trim();
                    if (title.isEmpty) return;

                    final user = _auth.currentUser;
                    if (user == null) return;

                    // Cerramos el modal inmediatamente para evitar doble click y mejorar la UX
                    Navigator.pop(context);

                    if (existing == null) {
                      final doc = await _firestore
                          .collection('users')
                          .doc(user.uid)
                          .collection('events')
                          .add({
                        'title': title,
                        'start': Timestamp.fromDate(start),
                        'end': Timestamp.fromDate(end),
                        'allDay': allDay,
                        'color': color,
                      });

                      final newApp = Appointment(
                        id: doc.id,
                        startTime: start,
                        endTime: end,
                        subject: title,
                        color: getColorFromString(color),
                        isAllDay: allDay,
                      );

                      _eventsSource.appointments!.add(newApp);
                      _eventsSource.notifyListeners(CalendarDataSourceAction.add, [newApp]);

                      if (!allDay) {
                        await _scheduleNotification(title, start.subtract(Duration(minutes: 10)));
                      }
                    } else {
                      await _firestore
                          .collection('users')
                          .doc(user.uid)
                          .collection('events')
                          .doc(existing.id.toString())
                          .update({
                        'title': title,
                        'start': Timestamp.fromDate(start),
                        'end': Timestamp.fromDate(end),
                        'allDay': allDay,
                        'color': color,
                      });

                      existing.subject = title;
                      existing.startTime = start;
                      existing.endTime = end;
                      existing.color = getColorFromString(color);
                      existing.isAllDay = allDay;

                      _eventsSource.notifyListeners(CalendarDataSourceAction.reset, _eventsSource.appointments!);
                    }
                    setState(() {});
                  },
                ),
                if (existing != null) ...[
                  SizedBox(height: 10),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text("Eliminar Evento"),
                    onPressed: () async {
                      final user = _auth.currentUser;
                      if (user == null) return;
                      
                      Navigator.pop(context);

                      await _firestore
                          .collection('users')
                          .doc(user.uid)
                          .collection('events')
                          .doc(existing.id.toString())
                          .delete();

                      _eventsSource.appointments!.remove(existing);
                      _eventsSource.notifyListeners(CalendarDataSourceAction.remove, [existing]);
                      setState(() {});
                    },
                  ),
                ]
              ],
            ),
          );
        });
      },
    );
  }

  void _changeView(CalendarView view) {
    setState(() => _calendarController.view = view);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMM('es_ES').format(_selectedDate)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _openEventDialog(),
      ),
      body: Column(
        children: [
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _viewButton("Día", CalendarView.day),
              _viewButton("Semana", CalendarView.week),
              _viewButton("Mes", CalendarView.month),
            ],
          ),
          SizedBox(height: 10),
          Expanded(
            child: SfCalendar(
              controller: _calendarController,
              dataSource: _eventsSource,
              firstDayOfWeek: 1,
              showNavigationArrow: true,
              todayHighlightColor: Colors.blue,
              headerStyle: CalendarHeaderStyle(
                textAlign: TextAlign.center,
                backgroundColor: Colors.white,
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onTap: (details) {
                if (details.appointments != null && details.appointments!.isNotEmpty) {
                  _openEventDialog(existing: details.appointments!.first);
                } else if (details.date != null) {
                  setState(() => _selectedDate = details.date!);
                }
              },
              monthViewSettings: MonthViewSettings(showAgenda: true),
              timeSlotViewSettings: TimeSlotViewSettings(
                timeFormat: 'HH:mm',
                timeIntervalHeight: 60,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewButton(String text, CalendarView view) {
    final isSelected = _calendarController.view == view;
    return GestureDetector(
      onTap: () => _changeView(view),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(horizontal: 6),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}