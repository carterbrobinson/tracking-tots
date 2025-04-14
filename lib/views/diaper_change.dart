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
  Map<String, dynamic> _spotDataMap = {};
  bool _isSubmitting = false;
  List<String> _spotKeys = []; // List to track keys in same order as _diaperData

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
      Uri.parse('http://127.0.0.1:5001/diaper-change/${UserState.userId}')
      // Uri.parse('https://tracking-tots.onrender.com/diaper-change/${UserState.userId}')
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      
      // Sort data by time (newest first)
      data.sort((a, b) {
        final timeA = DateTime.parse(a['time']);
        final timeB = DateTime.parse(b['time']);
        return timeB.compareTo(timeA); // Reverse order - newest first
      });
      
      _processData(data);
    }
  }

  void _processData(List<dynamic> data) {
    // Create a fresh list of entries
    List<Map<String, dynamic>> allEntries = [];
    
    // Process each item from the server
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final time = DateTime.parse(item['time']);
      final timestamp = time.millisecondsSinceEpoch;
      final type = item['type'];
      final notes = item['notes'] ?? '';
      
      // Unique position-based identifier that won't change
      final uniqueKey = item['id']?.toString() ?? '${timestamp}_${i}';
      
      allEntries.add({
        'uniqueKey': uniqueKey,
        'timestamp': timestamp,
        'type': type,
        'notes': notes,
        'time': time,
      });
    }
    
    // Sort the entries by timestamp (newest first)
    allEntries.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    
    setState(() {
      // Reset everything
      _typeDistribution = {'Wet': 0, 'Dirty': 0, 'Mixed': 0};
      _diaperData = [];
      _spotDataMap = {};
      _spotKeys = [];
      
      // Process in sorted order
      for (var entry in allEntries) {
        final type = entry['type'];
        final uniqueKey = entry['uniqueKey'];
        final timestamp = entry['timestamp'];
        
        // Update type distribution
        _typeDistribution[type] = (_typeDistribution[type] ?? 0) + 1;
        
        // Store in spotDataMap
        _spotDataMap[uniqueKey] = {
          'type': type,
          'notes': entry['notes'],
          'timestamp': timestamp,
        };
        
        // Add to chart data using the sorted order
        _diaperData.add(FlSpot(timestamp.toDouble(), 1));
        _spotKeys.add(uniqueKey);
      }
      
      _totalChanges = allEntries.length;
      
      // Use the oldest entry for average calculation
      final firstChange = allEntries.isNotEmpty 
          ? allEntries.reduce((a, b) => a['timestamp'] < b['timestamp'] ? a : b)['time'] 
          : DateTime.now();
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
                _buildDiaperList(),
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
          onPressed: () => _showAddDiaperDialog(context),
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
          _buildDiaperTypeDistribution(),
          SizedBox(height: 24),
          _buildDailyFrequencyChart(),
        ],
      ),
    );
  }

  Widget _buildDiaperTypeDistribution() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diaper Type Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: _typeDistribution['Wet']?.toDouble() ?? 0,
                      title: '${((_typeDistribution['Wet'] ?? 0) / _totalChanges * 100).toStringAsFixed(0)}%',
                      color: Colors.blue,
                      radius: 60,
                    ),
                    PieChartSectionData(
                      value: _typeDistribution['Dirty']?.toDouble() ?? 0,
                      title: '${((_typeDistribution['Dirty'] ?? 0) / _totalChanges * 100).toStringAsFixed(0)}%',
                      color: Colors.brown,
                      radius: 60,
                    ),
                    PieChartSectionData(
                      value: _typeDistribution['Mixed']?.toDouble() ?? 0,
                      title: '${((_typeDistribution['Mixed'] ?? 0) / _totalChanges * 100).toStringAsFixed(0)}%',
                      color: Colors.purple,
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
                _buildLegendItem('Wet', Colors.blue),
                SizedBox(width: 16),
                _buildLegendItem('Dirty', Colors.brown),
                SizedBox(width: 16),
                _buildLegendItem('Mixed', Colors.purple),
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

  Widget _buildDailyFrequencyChart() {
    // Group data by day
    Map<String, int> dailyCounts = {};
    
    for (var spot in _diaperData) {
      final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
      final dateStr = DateFormat('MM/dd').format(date);
      dailyCounts[dateStr] = (dailyCounts[dateStr] ?? 0) + 1;
    }
    
    // Convert data to BarChartGroupData objects
    List<BarChartGroupData> barGroups = [];
    List<String> dates = dailyCounts.keys.toList();
    
    for (int i = 0; i < dates.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: dailyCounts[dates[i]]!.toDouble(),
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
      );
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Diaper Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  alignment: BarChartAlignment.spaceAround,
                  maxY: dailyCounts.values.isEmpty ? 10 : dailyCounts.values.reduce(max).toDouble().ceilToDouble() + 2,
                  gridData: FlGridData(show: true, horizontalInterval: 1,),
                  titlesData: FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < dates.length && index % 2 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(dates[index], style: TextStyle(fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
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

  Widget _buildDiaperList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _diaperData.length,
      itemBuilder: (context, index) {
        final spot = _diaperData[index];
        
        // Get the corresponding key using the index
        final uniqueKey = index < _spotKeys.length 
            ? _spotKeys[index]
            : '${spot.x.toInt()}_$index'; // Fallback
        
        final itemData = _spotDataMap[uniqueKey];
        
        // Fallback in case the key is not found
        if (itemData == null) {
          return SizedBox.shrink(); // Skip this item
        }
        
        final type = itemData['type'] ?? 'Unknown';
        final notes = itemData['notes'] ?? '';
        final timestamp = itemData['timestamp'] ?? spot.x.toInt();
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.baby_changing_station, 
              color: type == 'Wet' ? Colors.blue : 
                    type == 'Dirty' ? Colors.brown : Colors.purple,
            ),
            title: Text(DateFormat('MMMM d, y – h:mm a').format(date)),
            subtitle: Text(type),
            trailing: notes.isNotEmpty ? Text(notes) : null,
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
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom
          ),
          child: SingleChildScrollView(
            child: BaseModalSheet(
              title: 'Add Diaper Change',
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CommonFormWidgets.buildFormCard(
                        title: 'Time',
                        child: CommonFormWidgets.buildDateTimePicker(
                          initialDateTime: _time,
                          onDateTimeChanged: (newTime) {
                            if (mounted) {
                              setState(() => _time = newTime);
                            }
                          },
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
                            if (value != null && mounted) {
                              setState(() => _type = value);
                            }
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      CommonFormWidgets.buildFormCard(
                        title: 'Notes',
                        child: CommonFormWidgets.buildNotesField(
                          (value) => _notes = value ?? '',
                        ),
                      ),
                      SizedBox(height: 24),
                      CommonFormWidgets.buildSubmitButton(
                        text: _isSubmitting ? 'Saving...' : 'Save Diaper Change',
                        onPressed: _isSubmitting ? null : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            _submit();
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
      },
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (UserState.userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to add a diaper change.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userId = UserState.userId.toString();

      final data = {
        'user_id': userId,
        'type': _type,
        'time': _time.toIso8601String(),
        'notes': _notes,
      };

      final response = await http.post(
        Uri.parse('http://127.0.0.1:5001/diaper-change/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diaper added successfully!')),
        );

        // CHANGE: Instead of fetching from server, add the new entry locally
        _addNewDiaperToList(data);

        // Now dismiss modal
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding diaper.')),
        );
      }
    } catch (e) {
      print('Submission error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Add this new method to manually add a diaper change to the list
  void _addNewDiaperToList(Map<String, dynamic> data) {
    setState(() {
      // Create timestamp and unique key
      final time = DateTime.parse(data['time']);
      final timestamp = time.millisecondsSinceEpoch;
      final uniqueKey = 'new_${timestamp}_${DateTime.now().millisecondsSinceEpoch}';
      final type = data['type'];
      final notes = data['notes'] ?? '';
      
      // Update type distribution
      _typeDistribution[type] = (_typeDistribution[type] ?? 0) + 1;
      
      // Store details in spotDataMap
      _spotDataMap[uniqueKey] = {
        'type': type,
        'notes': notes,
        'timestamp': timestamp,
      };
      
      // Insert at the beginning of lists (newest first)
      _diaperData.insert(0, FlSpot(timestamp.toDouble(), 1));
      _spotKeys.insert(0, uniqueKey);
      
      // Update counters
      _totalChanges += 1;
      
      // Recalculate average
      final oldestTimestamp = _diaperData.isEmpty ? 
          timestamp : 
          _diaperData.map((spot) => spot.x.toInt()).reduce((a, b) => a < b ? a : b);
      final firstChange = DateTime.fromMillisecondsSinceEpoch(oldestTimestamp);
      final daysDifference = DateTime.now().difference(firstChange).inDays + 1;
      _averageChangesPerDay = _totalChanges / daysDifference;
    });
  }
}
