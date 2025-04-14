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
  List<dynamic> _feedingDetails = [];

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
      Uri.parse('http://127.0.0.1:5001/feeding/${UserState.userId}')
      // Uri.parse('https://tracking-tots.onrender.com/feeding/${UserState.userId}')
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
        double duration = 0;
        if (item['type'] == 'Breast') {
          duration = ((item['left_breast_duration'] ?? 0) + (item['right_breast_duration'] ?? 0)).toDouble();
        } else if (item['type'] == 'Bottle') {
          duration = item['bottle_amount']?.toDouble() ?? 0;
        }
        return FlSpot(time.millisecondsSinceEpoch.toDouble(), duration);
      }).toList();

      _totalFeedings = data.length;
      final firstFeeding = data.isNotEmpty ? DateTime.parse(data.first['start_time']) : DateTime.now();
      final daysDifference = DateTime.now().difference(firstFeeding).inDays + 1;
      _averageFeedingsPerDay = _totalFeedings / daysDifference;

      _feedingDetails = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(title: 'Feeding Tracker'),
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
                _buildFeedingList(),
                _buildAnalytics(),
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
          onPressed: () => _showAddFeedingDialog(context),
          child: Icon(Icons.add),
          backgroundColor: Colors.transparent,
          elevation: 0,
          hoverElevation: 0,
        ),
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
                colors: [Color(0xFF6A359C), Colors.purple],
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
    if (_feedingDetails.isEmpty) {
      return Center(
        child: Text(
          'No feeding data recorded yet',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _feedingDetails.length,
      itemBuilder: (context, index) {
        // Get the feeding details directly
        final item = _feedingDetails[index];
        final time = DateTime.parse(item['start_time']);
        final feedingType = item['type'] ?? 'Unknown';
        
        // Build the trailing text based on the actual feeding data
        String trailingText;
        if (feedingType == 'Bottle') {
          trailingText = '${item['bottle_amount'] ?? 0}ml';
        } else {
          trailingText = '${item['left_breast_duration'] ?? 0}m L, ${item['right_breast_duration'] ?? 0}m R';
        }
        
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              feedingType == 'Bottle' ? Icons.baby_changing_station : Icons.child_care,
              color: Color(0xFF6A359C)
            ),
            title: Text(DateFormat('MMMM d, y').format(time)),
            subtitle: Text(feedingType),
            trailing: Text(trailingText),
          ),
        );
      },
    );
  }

  void _showAddFeedingDialog(BuildContext context) {
    // Create a local variable to track the type inside the modal
    String localType = _type;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => BaseModalSheet(
          title: 'Add Feeding',
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CommonFormWidgets.buildFormCard(
                    title: 'Start Time',
                    child: CommonFormWidgets.buildDateTimePicker(
                      initialDateTime: _startTime,
                      onDateTimeChanged: (newTime) => setModalState(() => _startTime = newTime),
                    ),
                  ),
                  SizedBox(height: 16),
                  CommonFormWidgets.buildFormCard(
                    title: 'End Time',
                    child: CommonFormWidgets.buildDateTimePicker(
                      initialDateTime: _endTime,
                      onDateTimeChanged: (newTime) => setModalState(() => _endTime = newTime),
                    ),
                  ),
                  SizedBox(height: 16),
                  CommonFormWidgets.buildFormCard(
                    title: 'Type',
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                localType = 'Breast';
                                _type = 'Breast';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: localType == 'Breast' 
                                  ? Color(0xFF6A359C) 
                                  : Colors.grey[200],
                              foregroundColor: localType == 'Breast' 
                                  ? Colors.white 
                                  : Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(8),
                                ),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text('Breast'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                localType = 'Bottle';
                                _type = 'Bottle';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: localType == 'Bottle' 
                                  ? Color(0xFF6A359C) 
                                  : Colors.grey[200],
                              foregroundColor: localType == 'Bottle' 
                                  ? Colors.white 
                                  : Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(8),
                                ),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text('Bottle'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  if (localType == 'Breast') ...[
                    CommonFormWidgets.buildFormCard(
                      title: 'Left Breast Duration (minutes)',
                      child: TextFormField(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _leftDuration = int.tryParse(value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a valid duration';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    CommonFormWidgets.buildFormCard(
                      title: 'Right Breast Duration (minutes)',
                      child: TextFormField(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _rightDuration = int.tryParse(value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a valid duration';
                          }
                          return null;
                        },
                      ),
                    ),
                  ] else
                  CommonFormWidgets.buildFormCard(
                    title: 'Bottle Amount (ml)',
                    child: TextFormField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8) ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _bottleAmount = int.tryParse(value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a valid amount';
                        }
                        return null;
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
                    text: 'Save Feeding',
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _submit();
                        Navigator.pop(context);
                      }
                    },
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
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
      Uri.parse('http://127.0.0.1:5001/feeding/${UserState.userId}'),
      // Uri.parse('https://tracking-tots.onrender.com/feeding/${UserState.userId}'),
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

