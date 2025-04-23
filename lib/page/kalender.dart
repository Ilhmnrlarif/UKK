import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:to_do_list/page/add_task.dart';
import 'package:to_do_list/page/task_detail.dart';

class KalenderPage extends StatefulWidget {
  const KalenderPage({Key? key}) : super(key: key);

  @override
  State<KalenderPage> createState() => _KalenderPageState();
}

class _KalenderPageState extends State<KalenderPage> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  List<dynamic> _selectedEvents = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      debugPrint('Loading tasks...');
      
      // Ambil data kategori warna terlebih dahulu
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('category_colors')
          .eq('id', Supabase.instance.client.auth.currentUser!.id)
          .single();
      
      debugPrint('Profile response: $profileResponse');
      Map<String, int> categoryColors = {};
      
      if (profileResponse != null && profileResponse['category_colors'] != null) {
        categoryColors = Map<String, int>.from(
          Map<String, dynamic>.from(profileResponse['category_colors'])
        );
        debugPrint('Category colors loaded: $categoryColors');
      }

      // Ambil semua tugas
      final tasksResponse = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);

      debugPrint('Tasks response: $tasksResponse');
      Map<DateTime, List<dynamic>> events = {};
      
      for (final task in tasksResponse) {
        debugPrint('Processing task: ${task['title']} with category: ${task['category']}');
        if (task['due_date'] != null) {
          final date = DateTime.parse(task['due_date']).toLocal();
          final key = DateTime(date.year, date.month, date.day);
          debugPrint('Task date: $date, key: $key');
          
          // Ambil warna dari categoryColors
          Color taskColor = Colors.blue.shade300;
          if (task['category'] != null && categoryColors.containsKey(task['category'])) {
            taskColor = Color(categoryColors[task['category']]!);
            debugPrint('Found color for category ${task['category']}: $taskColor');
          }
          
          final taskWithColor = Map<String, dynamic>.from(task)
            ..['displayColor'] = taskColor;
          
          debugPrint('Adding task to events with color: $taskColor');
          if (events[key] != null) {
            events[key]!.add(taskWithColor);
          } else {
            events[key] = [taskWithColor];
          }
        }
      }

      debugPrint('Final events map: $events');
      if (mounted) {
      setState(() {
        _events = events;
          if (_selectedDay != null) {
            _selectedEvents = _getEventsForDay(_selectedDay!);
            debugPrint('Selected events: $_selectedEvents');
          }
      });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading tasks: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final events = _events[normalizedDay] ?? [];
    debugPrint('Getting events for $normalizedDay: ${events.length} events found');
    return events;
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.yellow[700]!;
      case 'Easy':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _onTaskUpdated(Map<String, dynamic> updatedTask) {
    setState(() {
      // Update events map
      if (updatedTask['due_date'] != null) {
        final date = DateTime.parse(updatedTask['due_date']).toLocal();
        final key = DateTime(date.year, date.month, date.day);
        
        // Update the task in events
        if (_events.containsKey(key)) {
          final index = _events[key]!.indexWhere((task) => task['id'] == updatedTask['id']);
          if (index != -1) {
            _events[key]![index] = updatedTask;
          }
        }
        
        // Update selected events if the updated task is for the selected day
        if (_selectedDay != null && isSameDay(key, _selectedDay!)) {
          _selectedEvents = _getEventsForDay(_selectedDay!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          padding: const EdgeInsets.only(left: 8),
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 30),
          onPressed: () {
            setState(() {
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
            });
          },
        ),
        actions: [
          IconButton(
            padding: const EdgeInsets.only(right: 8),
            icon: const Icon(Icons.chevron_right, color: Colors.black, size: 30),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              });
            },
            ),
            IconButton(
            padding: const EdgeInsets.only(right: 8),
            icon: Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.black
            ),
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
                _calendarFormat = _isExpanded ? CalendarFormat.month : CalendarFormat.week;
              });
            },
            ),
          ],
        title: Text(
          DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay).toUpperCase(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'id_ID',
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Bulan',
              CalendarFormat.week: 'Minggu',
            },
            eventLoader: _getEventsForDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedEvents = _getEventsForDay(selectedDay);
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
                _isExpanded = format == CalendarFormat.month;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
              _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: const TextStyle(color: Colors.black),
              holidayTextStyle: const TextStyle(color: Colors.black),
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue.shade400,
                shape: BoxShape.circle,
              ),
              markersAlignment: Alignment.bottomCenter,
              markerSize: 5,
              markerDecoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.black),
              weekendStyle: TextStyle(color: Colors.black),
            ),
            headerVisible: false,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final normalizedDate = DateTime(date.year, date.month, date.day);
                debugPrint('Building markers for $normalizedDate with ${events.length} events');
                if (events.isEmpty) return const SizedBox();

                return Positioned(
                  bottom: 5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: events.map((event) {
                      final Map<String, dynamic> eventMap = event as Map<String, dynamic>;
                      final Color displayColor = eventMap['displayColor'] as Color? ?? Colors.blue.shade300;
                      debugPrint('Marker for ${eventMap['title']}: $displayColor');
                      return Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: displayColor,
                        ),
                      );
                    }).take(3).toList(),
                  ),
                );
              },
              selectedBuilder: (context, date, _) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
              todayBuilder: (context, date, _) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: const TextStyle(color: Colors.black),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _selectedEvents.length,
              itemBuilder: (context, index) {
                final event = _selectedEvents[index] as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: event['displayColor'] as Color? ?? Colors.blue.shade300,
                      ),
                    ),
                  title: Text(event['title'] ?? ''),
                  subtitle: Text(event['category'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Indikator subtask
                        if (event['subtasks'] != null && 
                            (event['subtasks'] as List).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.assignment,
                              size: 20,
                              color: Colors.blue[300],
                            ),
                          ),
                        // Indikator priority
                        if (event['priority'] != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.flag,
                              size: 20,
                              color: _getPriorityColor(event['priority']),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskDetailPage(
                            task: event,
                            onTaskUpdated: _onTaskUpdated,
                          ),
                        ),
                      ).then((_) {
                        // Reload tasks setelah kembali dari detail
                        _loadTasks();
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: const AddTaskPage(),
              ),
            );
            
            // Reload tasks jika ada task baru ditambahkan
            if (result == true) {
              _loadTasks();
            }
          },
          backgroundColor: const Color(0xFF69D1F7),
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
          shape: const CircleBorder(),
          elevation: 2,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
