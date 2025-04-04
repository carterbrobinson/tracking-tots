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

class FeedingForm extends StatefulWidget {
  @override
  _FeedingFormState createState() => _FeedingFormState();
}

class _FeedingFormState extends State<FeedingForm> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _type = 'Breast';
  int? _leftDuration, _rightDuration, _bottleAmount;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now();
  String? _notes;
  List<FlSpot> _feedingData = [];
  late TabController _tabController;
  int _totalFeedings = 0;
  double _averageFeedingsPerDay = 0;
  Map<String, int> _typeDistribution = {
    'Breast': 0,
    'Bottle': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFeedingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeedingData() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view your feeding data.'))
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final response = await http.get(
      // Uri.parse('http://127.0.0.1:5000/feeding/${UserState.userId}')
      Uri.parse('https://tracking-tots.onrender.com/feeding/${UserState.userId}')
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      _processData(data);
    }
  }

  void _processData(List<dynamic> data) {
    setState(() {
      _typeDistribution = {
        'Breast': 0,
        'Bottle': 0,
      };

      _feedingData = data.map((item) {
        final time = DateTime.parse(item['start_time']);
        _typeDistribution[item['type']] = (_typeDistribution[item['type']] ?? 0) + 1;
        return FlSpot(time.millisecondsSinceEpoch.toDouble(), 
          item['bottle_amount']?.toDouble() ?? 
          (item['left_breast_duration'] ?? 0 + item['right_breast_duration'] ?? 0).toDouble()
        );
      }).toList();

      _totalFeedings = data.length;
      final firstFeeding = data.isNotEmpty ? DateTime.parse(data.first['start_time']) : DateTime.now();
      final daysDifference = DateTime.now().difference(firstFeeding).inDays + 1;
      _averageFeedingsPerDay = _totalFeedings / daysDifference;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(title: 'Feeding Tracking'),
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
                          'Total Feedings',
                          '$_totalFeedings',
                          Icons.restaurant,
                          Colors.blue,
                        ),
                        CommonFormWidgets.buildSummaryCard(
                          'Daily Average',
                          '${_averageFeedingsPerDay.toStringAsFixed(1)}',
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
                _buildFeedingList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFeedingDialog(context),
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
              spots: _feedingData,
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

  Widget _buildFeedingList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _feedingData.length,
      itemBuilder: (context, index) {
        final spot = _feedingData[index];
        final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
        
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.restaurant, color: Colors.deepPurple),
            title: Text(DateFormat('MMMM d, y').format(date)),
            subtitle: Text(_type),
            trailing: Text(_type == 'Bottle' 
              ? '${_bottleAmount}ml' 
              : '${_leftDuration}m L, ${_rightDuration}m R'),
          ),
        );
      },
    );
  }

  void _showAddFeedingDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BaseModalSheet(
        title: 'Add Feeding',
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
            title: 'Type',
            child: DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: ['Breast', 'Bottle'].map((type) {
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
          if (_type == 'Breast') ...[
            CommonFormWidgets.buildFormCard(
              title: 'Left Breast Duration (minutes)',
              child: TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _leftDuration = int.tryParse(value),
              ),
            ),
            SizedBox(height: 16),
            CommonFormWidgets.buildFormCard(
              title: 'Right Breast Duration (minutes)',
              child: TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _rightDuration = int.tryParse(value),
              ),
            ),
          ] else
            CommonFormWidgets.buildFormCard(
              title: 'Bottle Amount (ml)',
              child: TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _bottleAmount = int.tryParse(value),
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
            text: 'Save Feeding',
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
        SnackBar(content: Text('Please log in to add a feeding.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    
    final data = {
      'user_id': UserState.userId,
      'type': _type,
      'left_breast_duration': _leftDuration,
      'right_breast_duration': _rightDuration,
      'bottle_amount': _bottleAmount,
      'start_time': _startTime.toIso8601String(),
      'end_time': _endTime.toIso8601String(),
      'notes': _notes,
    };
    
    final response = await http.post(
      // Uri.parse('http://127.0.0.1:5000/feeding/${UserState.userId}'),
      Uri.parse('https://tracking-tots.onrender.com/feeding/${UserState.userId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Feeding added successfully!')),
      );
      _fetchFeedingData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding Feeding.')),
      );
    }
  }
}

