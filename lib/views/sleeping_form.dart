import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:trackingtots/views/widgets/top_navigation_bar.dart';
import 'package:trackingtots/user_state.dart';
import 'package:trackingtots/views/widgets/form_builder.dart';
import 'package:trackingtots/views/widgets/modal_sheet.dart';


class SleepingForm extends StatefulWidget {
  @override
  _SleepingFormState createState() => _SleepingFormState();
}

class _SleepingFormState extends State<SleepingForm> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now();
  String? _notes;
  List<FlSpot> _sleepData = [];
  late TabController _tabController;
  bool _isWeeklyView = true;
  Map<String, List<FlSpot>> _groupedData = {};
  double _dailySleepHours = 0;
  double _averageSleepHours = 0;
  double _longestSleep = 0;
  double _duration = 0.0;

  /// Formats DateTime as `YYYY-MM-DD HH:MM:SS`
  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} "
        "${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}";
  }

  String _twoDigits(int n) => n >= 10 ? "$n" : "0$n";

  /// Fetch sleep data from API and populate chart
  Future<void> _fetchSleepData() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to view your sleep data.'))
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final response = await http.get(Uri.parse('http://127.0.0.1:5001/sleeping/${UserState.userId}'));
    // final response = await http.get(Uri.parse('https://tracking-tots.onrender.com/sleeping/${UserState.userId}'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        _sleepData = data.map((item) {
          final startTime = DateTime.parse(item['start_time']);
          final endTime = DateTime.parse(item['end_time']);
          final duration = endTime.difference(startTime).inMinutes.toDouble();
          return FlSpot(startTime.millisecondsSinceEpoch.toDouble(), duration);
        }).toList();
        _processData();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSleepData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _processData() {
    if (_sleepData.isEmpty) return;

    // Calculate daily sleep (for the current day)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todaySleep = _sleepData.where((spot) {
      final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
      return date.year == today.year && 
             date.month == today.month && 
             date.day == today.day;
    }).fold(0.0, (sum, spot) => sum + spot.y) / 60;

    setState(() {
      _dailySleepHours = todaySleep;
      _averageSleepHours = _sleepData.fold(0.0, (sum, spot) => sum + spot.y) / (60 * _sleepData.length);
      _longestSleep = _sleepData.map((spot) => spot.y).reduce((max, value) => max > value ? max : value) / 60;
    });

    _groupedData = {};
    for (var spot in _sleepData) {
      final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
      final weekKey = DateFormat('yyyy-ww').format(date);
      _groupedData.putIfAbsent(weekKey, () => []).add(spot);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(title: 'Sleep Tracking'),
      backgroundColor: Colors.purple[50],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSleepSummaryCards(),
                  SizedBox(height: 20),
                  CommonFormWidgets.buildDataVisualizationTabs(_tabController),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSleepList(),
                _buildAdvancedChart(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9969C7), Color(0xFF6A359C)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: FloatingActionButton(
                onPressed: () => _showAddSleepDialog(context),
                child: Icon(Icons.add),
                backgroundColor: Colors.transparent,
                elevation: 0,
                hoverElevation: 0,
              ),
            ),
          );
        }

  Widget _buildSleepSummaryCards() {
    return Container(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          CommonFormWidgets.buildSummaryCard(
            'Daily Sleep', 
            '${_dailySleepHours.toStringAsFixed(1)}h',
            Icons.nightlight_round,
            Colors.indigo,
          ),
          CommonFormWidgets.buildSummaryCard(
            'Average Sleep', 
            '${_averageSleepHours.toStringAsFixed(1)}h',
            Icons.trending_up,
            Colors.teal,
          ),
          CommonFormWidgets.buildSummaryCard(
            'Longest Sleep', 
            '${_longestSleep.toStringAsFixed(1)}h',
            Icons.timer,
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedChart() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: _sleepData,
              isCurved: true,
              gradient: LinearGradient(
                colors: [Color(0xFF6A359C), Colors.purple],
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: Colors.white,
                    strokeWidth: 3,
                    strokeColor: Colors.purple,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6A359C).withOpacity(0.3),
                    Colors.purple.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value / 60).toStringAsFixed(1)}h',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  );
                },
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipPadding: EdgeInsets.all(8),
              tooltipRoundedRadius: 8,
              tooltipMargin: 10,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                  return LineTooltipItem(
                    '${DateFormat('MMM dd').format(date)}\n${(spot.y / 60).toStringAsFixed(1)}h',
                    TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSleepList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _sleepData.length,
      itemBuilder: (context, index) {
        final spot = _sleepData[index];
        final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
        final duration = spot.y;

        final startTime = date;
        final endTime = date.add(Duration(minutes: duration.toInt()));

        final isNap = _isNapTime(date);
        
        return Card(
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF6A359C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(isNap ? Icons.wb_sunny : Icons.bedtime, color: Color(0xFF6A359C)),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(_startTime),
                  style: TextStyle(color: Colors.black),
                ),
                Text(
                  '${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: Text(
              duration > 0 && (duration ~/ 60) > 0
              ? '${(duration ~/ 60)} hours ${duration % 60} minutes'
              : '${(duration % 60)} minutes'  
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _showSleepDetails(date, duration),
          ),
        );
      },
    );
  }

  void _showSleepDetails(DateTime date, double duration) {
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    final endTime = date.add(Duration(minutes: duration.toInt()));
    final isNap = _isNapTime(date);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BaseModalSheet(
        title: "Sleep Session Details",
        children: [
          ListTile(
            leading: Icon(isNap ? Icons.wb_sunny : Icons.bedtime, color: Colors.white),
            title: Text(isNap ? 'Nap Start' : 'Sleep Time'),
            subtitle: Text('${DateFormat('EEEE, MMMM d').format(date)} at ${DateFormat('hh:mm a').format(date)}'),
          ),
          ListTile(
            leading: Icon(Icons.wb_sunny, color: Colors.white),
            title: Text('Wake Time'),
            subtitle: Text('${DateFormat('EEEE, MMMM d').format(endTime)} at ${DateFormat('hh:mm a').format(endTime)}'),
          ),
          ListTile(
            leading: Icon(Icons.access_time, color: Colors.white),
            title: Text('Duration'),
            subtitle: Text(
              duration > 0 && hours > 0
              ? '$hours hours ${minutes.toInt()} minutes'
              : '${minutes.toInt()} minutes'
            ),
          ),
          ListTile(
            leading: Icon(Icons.insights, color: Colors.white),
            title: Text(isNap ? 'Nap Quality' : 'Sleep Quality'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getSleepQuality(duration, date)),
                SizedBox(height: 4),
                Text(
                  isNap 
                    ? 'Ideal nap duration is 20-60 minutes'
                    : 'Recommended night sleep is 7-9 hours',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          if (_notes?.isNotEmpty ?? false)
            ListTile(
              leading: Icon(Icons.notes, color: Colors.white),
              title: Text('Notes'),
              subtitle: Text(_notes!),
            ),
        ],
      ),
    );
  }

  String _getSleepQuality(double duration, DateTime date) {
    final hours = duration / 60;
    final isNap = _isNapTime(date);

    if (isNap) {
      if (hours < 0.5) {
        return 'Power Nap 💪';
      } else if (hours <= 1) {
        return 'Ideal Nap Duration 👍';
      } else if (hours <= 1.5) {
        return 'Long Nap 😴';
      } else {
        return 'Very Long Nap ⚠️';
      }
    } else {
      if (hours < 6) {
        return 'Insufficient Sleep 😟';
      } else if (hours < 7) {
        return 'Below Recommended 😐';
      } else if (hours <= 9) {
        return 'Optimal Sleep 👍';
      } else {
        return 'Extended Sleep 😴';
      }
    }
  }

  bool _isNapTime(DateTime startTime) {
    final hour = startTime.hour;
    return hour >= 9 && hour < 20;
  }

  void _showAddSleepDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BaseModalSheet(
        title: 'Add Sleep Session',
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                CommonFormWidgets.buildFormCard(
                  title: 'Start Time',
                  child: CommonFormWidgets.buildDateTimePicker(
                    initialDateTime: _startTime,
                    onDateTimeChanged: (newTime) => setState(() => _startTime = newTime),
                  ),
                ),
                SizedBox(height: 16),
                CommonFormWidgets.buildFormCard(
                  title: 'End Time',
                  child: CommonFormWidgets.buildDateTimePicker(
                    initialDateTime: _endTime,
                    onDateTimeChanged: (newTime) => setState(() => _endTime = newTime),
                  ),
                ),
                SizedBox(height: 16),
                CommonFormWidgets.buildFormCard(
                  title: 'Notes',
                  child: CommonFormWidgets.buildNotesField(
                    (value) => _notes = value,
                  ),
                ),
                SizedBox(height: 24),
                CommonFormWidgets.buildSubmitButton(
                  text: 'Save Sleep Session',
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _submit();
                      Navigator.pop(context);
                    }   
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to add a sleeping session.'))
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Validate that end time is after start time
    if (_endTime.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('End time must be after start time'), backgroundColor: Colors.red, duration: Duration(seconds: 4))
      );
      return;
    }

    final data = {
      'user_id': UserState.userId,
      'start_time': _startTime.toIso8601String(),
      'end_time': _endTime.toIso8601String(),
      'notes': _notes ?? '',
    };

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5001/sleeping/${UserState.userId}'),
        // Uri.parse('https://tracking-tots.onrender.com/sleeping/${UserState.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sleep session added successfully!'))
        );
        _fetchSleepData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding sleep session.'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: Could not add sleep session.'))
      );
    }
  }
}
