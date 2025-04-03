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

class DiaperForm extends StatefulWidget {
  @override
  _DiaperFormState createState() => _DiaperFormState();
}

class _DiaperFormState extends State<DiaperForm> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _type = 'Wet';
  DateTime _time = DateTime.now();
  String _notes = '';
  List<FlSpot> _diaperData = [];
  late TabController _tabController;
  Map<String, int> _typeDistribution = {
    'Wet': 0,
    'Dirty': 0,
    'Mixed': 0,
  };
  int _totalChanges = 0;
  double _averageChangesPerDay = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDiaperData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDiaperData() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view your diaper data.'))
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final response = await http.get(
      // Uri.parse('http://127.0.0.1:5000/diaper-change/${UserState.userId}')
      Uri.parse('https://tracking-tots.onrender.com/diaper-change/${UserState.userId}')
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      _processData(data);
    }
  }

  void _processData(List<dynamic> data) {
    setState(() {
      _typeDistribution = {
        'Wet': 0,
        'Dirty': 0,
        'Mixed': 0,
      };

      _diaperData = data.map((item) {
        final time = DateTime.parse(item['time']);
        _typeDistribution[item['type']] = (_typeDistribution[item['type']] ?? 0) + 1;
        return FlSpot(time.millisecondsSinceEpoch.toDouble(), 1);
      }).toList();

      _totalChanges = data.length;
      final firstChange = data.isNotEmpty ? DateTime.parse(data.first['time']) : DateTime.now();
      final daysDifference = DateTime.now().difference(firstChange).inDays + 1;
      _averageChangesPerDay = _totalChanges / daysDifference;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(title: 'Diaper Tracking'),
      backgroundColor: Colors.purple[50],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 160,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        CommonFormWidgets.buildSummaryCard(
                          'Total Changes',
                          '$_totalChanges',
                          Icons.change_circle,
                          Colors.blue,
                        ),
                        CommonFormWidgets.buildSummaryCard(
                          'Daily Average',
                          '${_averageChangesPerDay.toStringAsFixed(1)}',
                          Icons.trending_up,
                          Colors.green,
                        ),
                        CommonFormWidgets.buildSummaryCard(
                          'Most Common',
                          _typeDistribution.entries.reduce((a, b) => 
                            a.value > b.value ? a : b).key,
                          Icons.star,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
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
                _buildAnalytics(),
                _buildDiaperList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDiaperDialog(context),
        child: Icon(Icons.add),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildAnalytics() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: _diaperData,
              isCurved: true,
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
              ),
              barWidth: 4,
              dotData: FlDotData(show: true),
            ),
          ],
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Text(DateFormat('MM/dd').format(date));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiaperList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _diaperData.length,
      itemBuilder: (context, index) {
        final spot = _diaperData[index];
        final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
        
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.baby_changing_station, color: Colors.deepPurple),
            title: Text(DateFormat('MMMM d, y').format(date)),
            subtitle: Text(_type),
            trailing: Text(_notes ?? ''),
          ),
        );
      },
    );
  }

  void _showAddDiaperDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BaseModalSheet(
        title: 'Add Diaper Change',
        children: [
          CommonFormWidgets.buildFormCard(
            title: 'Time',
            child: CommonFormWidgets.buildDateTimePicker(
              initialDateTime: _time,
              onDateTimeChanged: (newTime) => setState(() => _time = newTime),
            ),
          ),
          SizedBox(height: 16),
          CommonFormWidgets.buildFormCard(
            title: 'Type',
            child: DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: ['Wet', 'Dirty', 'Mixed'].map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _type = value!);
              },
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
            text: 'Save Diaper Change',
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _submit();
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to add a diaper change.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    
    final data = {
      'user_id': UserState.userId,
      'type': _type,
      'time': _time.toIso8601String(),
      'notes': _notes,
    };
    
    final response = await http.post(
      // Uri.parse('http://127.0.0.1:5000/diaper-change/${UserState.userId}'),
      Uri.parse('https://tracking-tots.onrender.com/diaper-change/${UserState.userId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Diaper added successfully!')),
      );
      _fetchDiaperData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding Diaper.')),
      );
    }
  }
}
