import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:trackingtots/views/widgets/top_navigation_bar.dart';
import 'package:trackingtots/user_state.dart';


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
  double _totalSleepHours = 0;
  double _averageSleepHours = 0;
  double _longestSleep = 0;

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

    final response = await http.get(Uri.parse('http://127.0.0.1:5000/sleeping/${UserState.userId}'));

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

    _totalSleepHours = _sleepData.fold(0.0, (sum, spot) => sum + spot.y) / 60;
    _averageSleepHours = _totalSleepHours / _sleepData.length;
    _longestSleep = _sleepData.map((spot) => spot.y).reduce((max, value) => max > value ? max : value) / 60;

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
                  _buildDataVisualizationTabs(),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAdvancedChart(),
                _buildSleepList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSleepDialog(context),
        child: Icon(Icons.add),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildSleepSummaryCards() {
    return Container(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildSummaryCard('Total Sleep', '${_totalSleepHours.toStringAsFixed(1)}h',
          Icons.nightlight_round,
          Colors.indigo,
          ),
          _buildSummaryCard('Average Sleep', '${_averageSleepHours.toStringAsFixed(1)}h',
          Icons.trending_up,
          Colors.teal,
          ),
          _buildSummaryCard('Longest Sleep', '${_longestSleep.toStringAsFixed(1)}h',
          Icons.timer,
          Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.all(8),
      child: Container(
        width: 160,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataVisualizationTabs() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.deepPurple,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.deepPurple,
            tabs: [
              Tab(text: 'Analytics'),
              Tab(text: 'History'),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoSegmentedControl(
              children: {
                true: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Weekly'),
                ),
                false: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Monthly'),
                ),
              },
              groupValue: _isWeeklyView,
              onValueChanged: (bool value) {
                setState(() => _isWeeklyView = value);
              },
            ),
          ],
        ),
      ],
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
                colors: [Colors.deepPurple, Colors.purple],
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
                    Colors.deepPurple.withOpacity(0.3),
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
        
        return Card(
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.nightlight_round, color: Colors.deepPurple),
            ),
            title: Text(
              DateFormat('EEEE, MMMM d').format(date),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${(duration / 60).toStringAsFixed(1)} hours'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _showSleepDetails(date, duration),
          ),
        );
      },
    );
  }

  void _showSleepDetails(DateTime date, double duration) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sleep Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.deepPurple),
              title: Text('Date'),
              subtitle: Text(DateFormat('EEEE, MMMM d, y').format(date)),
            ),
            ListTile(
              leading: Icon(Icons.access_time, color: Colors.deepPurple),
              title: Text('Duration'),
              subtitle: Text('${(duration / 60).toStringAsFixed(1)} hours'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, DateTime dateTime, Function(DateTime) onTimeSelected) {
    return ListTile(
      title: Text('$label: ${_formatDateTime(dateTime)}'),
      trailing: Icon(Icons.keyboard_arrow_down),
      onTap: () async {
        TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(dateTime),
        );

        if (picked != null) {
          onTimeSelected(DateTime(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            picked.hour,
            picked.minute,
            0,
          ));
        }
      },
    );
  }

  Future<void> _submit() async {
    if (UserState.userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please log in to add a sleeping.'))
        );
        Navigator.pushReplacementNamed(context, '/login');
        return;
    }
    final data = {
      'user_id': UserState.userId,
      'start_time': _startTime.toIso8601String(),
      'end_time': _endTime.toIso8601String(),
      'notes': _notes,
    };
    final response = await http.post(
      Uri.parse('http://127.0.0.1:5000/sleeping/${UserState.userId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sleeping added successfully!')),
      );
      _fetchSleepData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding Sleeping.')),
      );
    }
  }

  void _showAddSleepDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.all(20).copyWith(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Sleep Session',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 20),
              Container(
                height: 180,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _startTime,
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime.now().subtract(Duration(days: 7)),
                  onDateTimeChanged: (DateTime newDateTime) {
                    setModalState(() => _startTime = newDateTime);
                  },
                ),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Sleep Duration',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          for (int hours in [6, 7, 8, 9, 10])
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text('$hours hours'),
                                selected: _endTime.difference(_startTime).inHours == hours,
                                onSelected: (bool selected) {
                                  if (selected) {
                                    setModalState(() {
                                      _endTime = _startTime.add(Duration(hours: hours));
                                    });
                                  }
                                },
                                selectedColor: Colors.deepPurple,
                                labelStyle: TextStyle(
                                  color: _endTime.difference(_startTime).inHours == hours
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                            IconButton(
                            icon: Icon(Icons.more_horiz),
                            onPressed: () async {
                              // Show a number picker or custom input for different durations
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: 8, minute: 0),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  _endTime = _startTime.add(
                                    Duration(hours: picked.hour, minutes: picked.minute),
                                  );
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                  ),
                  prefixIcon: Icon(Icons.note, color: Colors.deepPurple),
                ),
                onChanged: (value) => _notes = value,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _submit();
                  Navigator.pop(context);
                },
                child: Text('Save Sleep Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
