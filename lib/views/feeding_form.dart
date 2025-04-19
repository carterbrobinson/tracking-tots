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
import 'dart:math' show max;

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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFeedingTypeDistribution(),
          SizedBox(height: 24),
          _buildFeedingTrends(),
          SizedBox(height: 24),
          _buildFeedingAmountChart(),
        ],
      ),
    );
  }

  Widget _buildFeedingTypeDistribution() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feeding Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: _typeDistribution['Breast']?.toDouble() ?? 0,
                      title: '${((_typeDistribution['Breast'] ?? 0) / _totalFeedings * 100).toStringAsFixed(0)}%',
                      color: Colors.purple,
                      radius: 60,
                    ),
                    PieChartSectionData(
                      value: _typeDistribution['Bottle']?.toDouble() ?? 0,
                      title: '${((_typeDistribution['Bottle'] ?? 0) / _totalFeedings * 100).toStringAsFixed(0)}%',
                      color: Colors.blue,
                      radius: 60,
                    ),
                  ],
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Breast', Colors.purple),
                SizedBox(width: 16),
                _buildLegendItem('Bottle', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(text),
      ],
    );
  }

  Widget _buildFeedingTrends() {
    // Group by day
    Map<String, int> dailyCounts = {};
    
    for (var item in _feedingDetails) {
      final date = DateTime.parse(item['start_time']);
      final dateStr = DateFormat('MM/dd').format(date);
      dailyCounts[dateStr] = (dailyCounts[dateStr] ?? 0) + 1;
    }
    
    // Sort dates chronologically
    List<String> dates = dailyCounts.keys.toList();
    dates.sort();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Feeding Frequency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: List.generate(
                    dates.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: dailyCounts[dates[index]]!.toDouble(),
                          gradient: LinearGradient(
                            colors: [Color(0xFF9969C7), Color(0xFF6A359C)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 20,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                  alignment: BarChartAlignment.spaceAround,
                  maxY: dailyCounts.values.isEmpty ? 10 : dailyCounts.values.reduce(max).toDouble() + 2,
                  gridData: FlGridData(show: true, horizontalInterval: 1),
                  titlesData: FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < dates.length) {
                            // Show all dates when there are few entries, otherwise show every other one
                            if (dates.length <= 7 || index % 2 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(dates[index], style: TextStyle(fontSize: 10)),
                              );
                            }
                          }
                          return const Text('');
                        },
                        reservedSize: 24, // Give more space for the labels
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedingAmountChart() {
    // Group by day and feeding type
    Map<String, Map<String, dynamic>> feedingStats = {};
    
    for (var item in _feedingDetails) {
      final date = DateTime.parse(item['start_time']);
      final dateStr = DateFormat('MM/dd').format(date);
      
      if (!feedingStats.containsKey(dateStr)) {
        feedingStats[dateStr] = {
          'breast_duration': 0,
          'bottle_amount': 0,
        };
      }
      
      if (item['type'] == 'Breast') {
        feedingStats[dateStr]!['breast_duration'] += 
          ((item['left_breast_duration'] ?? 0) + (item['right_breast_duration'] ?? 0));
      } else if (item['type'] == 'Bottle') {
        feedingStats[dateStr]!['bottle_amount'] += (item['bottle_amount'] ?? 0);
      }
    }
    
    // Convert to sorted list of dates
    List<String> dates = feedingStats.keys.toList();
    dates.sort();
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Feeding Amounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 250,
              child: BarChart(
                BarChartData(
                  barGroups: List.generate(
                    dates.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        // Breast feeding (minutes)
                        BarChartRodData(
                          toY: feedingStats[dates[index]]!['breast_duration'].toDouble(),
                          gradient: LinearGradient(
                            colors: [Colors.purple.shade300, Colors.purple.shade700],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 12,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        // Bottle feeding (ml)
                        BarChartRodData(
                          toY: feedingStats[dates[index]]!['bottle_amount'].toDouble() / 10, // Scale down to fit
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade300, Colors.blue.shade700],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 12,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text('${(value * 10).toInt()} ml', style: TextStyle(fontSize: 10, color: Colors.blue)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text('${value.toInt()} min', style: TextStyle(fontSize: 10, color: Colors.purple)),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < dates.length) {
                            // Show all dates when there are few entries, otherwise show every other one
                            if (dates.length <= 7 || index % 2 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(dates[index], style: TextStyle(fontSize: 10)),
                              );
                            }
                          }
                          return const Text('');
                        },
                        reservedSize: 24, // Give more space for the labels
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Breast (minutes)', Colors.purple),
                SizedBox(width: 16),
                _buildLegendItem('Bottle (ml)', Colors.blue),
              ],
            ),
          ],
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
        try {
          // Get the feeding details with null safety
          final item = _feedingDetails[index];
          if (item == null) {
            return _buildErrorCard('Missing data entry');
          }
          
          final timeStr = item['start_time'] as String?;
          final feedingType = item['type'] as String? ?? 'Unknown';
          
          // Safely parse date or use current time as fallback
          DateTime time;
          try {
            time = timeStr != null ? DateTime.parse(timeStr) : DateTime.now();
          } catch (e) {
            time = DateTime.now();
            print('Error parsing date: $e');
          }
          
          // Calculate durations safely
          final leftDuration = item['left_breast_duration'] is int ? item['left_breast_duration'] as int : 0;
          final rightDuration = item['right_breast_duration'] is int ? item['right_breast_duration'] as int : 0;
          final bottleAmount = item['bottle_amount'] is int ? item['bottle_amount'] as int : 0;
          
          // Build the trailing text based on the actual feeding data
          String trailingText;
          if (feedingType == 'Bottle') {
            trailingText = '${bottleAmount}ml';
          } else {
            trailingText = '${leftDuration}m L, ${rightDuration}m R';
          }
          
          // Calculate end time safely
          final totalDuration = leftDuration + rightDuration;
          final endTime = time.add(Duration(minutes: totalDuration));
          
          return InkWell(
            onTap: () => _showUpdateFeedingDialog(item['id']),
            child: Card(
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                feedingType == 'Bottle' ? Icons.baby_changing_station : Icons.child_care,
                color: Color(0xFF6A359C)
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMMM d, y').format(time)),
                  Text('${DateFormat('hh:mm a').format(time)} - ${DateFormat('hh:mm a').format(endTime)}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '$feedingType - $trailingText',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteFeedings(item['id']),
                  ),
                ],
              ),
            ),)
          );
        } catch (e) {
          // Return a fallback card for invalid data
          print('Error rendering feeding item: $e');
          return _buildErrorCard('Could not display this feeding entry');
        }
      },
    );
  }

  // Helper method for consistent error cards
  Widget _buildErrorCard(String message) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      color: Colors.red.shade50,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: Colors.red),
        title: Text('Invalid data'),
        subtitle: Text(message),
      ),
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

  void _showUpdateFeedingDialog(int id) {
    // Find the existing feeding data
    final feedingData = _feedingDetails.firstWhere((item) => item['id'] == id);
    
    // Create local variables for the form
    String localType = feedingData['type'] ?? 'Breast';
    DateTime localStartTime = DateTime.parse(feedingData['start_time']);
    DateTime localEndTime = DateTime.parse(feedingData['end_time']);
    int? localLeftDuration = feedingData['left_breast_duration'];
    int? localRightDuration = feedingData['right_breast_duration'];
    int? localBottleAmount = feedingData['bottle_amount'];
    String? localNotes = feedingData['notes'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => BaseModalSheet(
          title: 'Update Feeding',
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CommonFormWidgets.buildFormCard(
                    title: 'Start Time',
                    child: CommonFormWidgets.buildDateTimePicker(
                      initialDateTime: localStartTime,
                      onDateTimeChanged: (newTime) => setModalState(() => localStartTime = newTime),
                      isUpdate: true,
                    ),
                  ),
                  SizedBox(height: 16),
                  CommonFormWidgets.buildFormCard(
                    title: 'End Time',
                    child: CommonFormWidgets.buildDateTimePicker(
                      initialDateTime: localEndTime,
                      onDateTimeChanged: (newTime) => setModalState(() => localEndTime = newTime),
                      isUpdate: true,
                    ),
                  ),
                  SizedBox(height: 16),
                  CommonFormWidgets.buildFormCard(
                    title: 'Type',
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setModalState(() => localType = 'Breast'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: localType == 'Breast' ? Color(0xFF6A359C) : Colors.grey[200],
                              foregroundColor: localType == 'Breast' ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text('Breast'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setModalState(() => localType = 'Bottle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: localType == 'Bottle' ? Color(0xFF6A359C) : Colors.grey[200],
                              foregroundColor: localType == 'Bottle' ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text('Bottle'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (localType == 'Breast') ...[
                    SizedBox(height: 16),
                    CommonFormWidgets.buildFormCard(
                      title: 'Left Breast Duration (minutes)',
                      child: TextFormField(
                        initialValue: localLeftDuration?.toString() ?? '',
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => localLeftDuration = int.tryParse(value),
                        validator: (value) => value?.isEmpty ?? true ? 'Please enter a duration' : null,
                      ),
                    ),
                    SizedBox(height: 16),
                    CommonFormWidgets.buildFormCard(
                      title: 'Right Breast Duration (minutes)',
                      child: TextFormField(
                        initialValue: localRightDuration?.toString() ?? '',
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => localRightDuration = int.tryParse(value),
                        validator: (value) => value?.isEmpty ?? true ? 'Please enter a duration' : null,
                      ),
                    ),
                  ] else
                    CommonFormWidgets.buildFormCard(
                      title: 'Bottle Amount (ml)',
                      child: TextFormField(
                        initialValue: localBottleAmount?.toString() ?? '',
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => localBottleAmount = int.tryParse(value),
                        validator: (value) => value?.isEmpty ?? true ? 'Please enter an amount' : null,
                      ),
                    ),
                  SizedBox(height: 16),
                  CommonFormWidgets.buildFormCard(
                    title: 'Notes',
                    child: CommonFormWidgets.buildNotesField(
                      (value) => localNotes = value,
                      initialValue: localNotes,
                    ),
                  ),
                  SizedBox(height: 24),
                  CommonFormWidgets.buildSubmitButton(
                    text: 'Update Feeding',
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _updateFeeding(
                          id.toString(),
                          localType,
                          localStartTime,
                          localEndTime,
                          localLeftDuration,
                          localRightDuration,
                          localBottleAmount,
                          localNotes ?? '',
                        );
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

  Future<void> _deleteFeedings(int id) async {
    try {
      final response = await http.delete(Uri.parse('http://127.0.0.1:5001/feeding/$id'));
      // final response = await http.delete(Uri.parse('https://tracking-tots.onrender.com/todo/$id'));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feeding deleted')),
        );
        await _fetchFeedingData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: Could not delete feeding')),
      );
    }
  }

  Future<void> _updateFeeding(
    String id,
    String type,
    DateTime startTime,
    DateTime endTime,
    int? leftDuration,
    int? rightDuration,
    int? bottleAmount,
    String notes,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('http://127.0.0.1:5001/feeding/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': UserState.userId,
          'type': type,
          'left_breast_duration': leftDuration,
          'right_breast_duration': rightDuration,
          'bottle_amount': bottleAmount,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feeding updated successfully!')),
        );
        await _fetchFeedingData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating feeding')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: Could not update feeding')),
      );
    }
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

