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
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      
      // Sort data by time AND id (newest first)
      data.sort((a, b) {
        final timeA = DateTime.parse(a['time']);
        final timeB = DateTime.parse(b['time']);
        final timeCompare = timeB.compareTo(timeA); // Primary sort by time (newest first)
        if (timeCompare != 0) {
          return timeCompare;
        }
        // If times are equal, sort by ID (higher/newer ID first)
        final idA = int.parse(a['id'].toString());
        final idB = int.parse(b['id'].toString());
        return idB.compareTo(idA);
      });
      
      _processData(data);
    }
  }

  void _processData(List<dynamic> data) {
    setState(() {
      _typeDistribution = {'Wet': 0, 'Dirty': 0, 'Mixed': 0};
      _diaperData = [];
      _spotDataMap = {};
      _spotKeys = [];
      
      // Process each item from the server (data is already sorted newest first)
      for (var item in data) {
        final time = DateTime.parse(item['time']);
        final timestamp = time.millisecondsSinceEpoch;
        final type = item['type'];
        final uniqueKey = item['id']?.toString() ?? '${timestamp}_${DateTime.now().millisecondsSinceEpoch}';
        
        // Update all data structures at once
        _typeDistribution[type] = (_typeDistribution[type] ?? 0) + 1;
        // Add to end since data is already sorted newest first
        _diaperData.add(FlSpot(timestamp.toDouble(), 1));
        _spotKeys.add(uniqueKey);
        _spotDataMap[uniqueKey] = {
          'type': type,
          'notes': item['notes'] ?? '',
          'timestamp': timestamp,
        };
      }
      
      _totalChanges = data.length;
      if (_totalChanges > 0) {
        // Use the last item since it's the oldest
        final firstChange = DateTime.parse(data.last['time']);
        _averageChangesPerDay = _totalChanges / (DateTime.now().difference(firstChange).inDays + 1);
      } else {
        _averageChangesPerDay = 0;
      }
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
      itemCount: _spotKeys.length,
      itemBuilder: (context, index) {
        final uniqueKey = _spotKeys[index];
        final itemData = _spotDataMap[uniqueKey]!;
        final date = DateTime.fromMillisecondsSinceEpoch(itemData['timestamp']);
        
        return InkWell(
          onTap: () => _showUpdateDiaperDialog(uniqueKey),
          child: Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
              Icons.baby_changing_station, 
              color: itemData['type'] == 'Wet' ? Colors.blue : 
                     itemData['type'] == 'Dirty' ? Colors.brown : Colors.purple,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('MMMM d, y – h:mm a').format(date)),
                if (itemData['notes']?.isNotEmpty ?? false) 
                  Text(
                    itemData['notes'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            subtitle: Text(itemData['type']),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteDiaperChanges(uniqueKey),
            ),
          ),
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

  void _showUpdateDiaperDialog(String uniqueKey) {
    final itemData = _spotDataMap[uniqueKey]!;
    String updatedType = itemData['type'];
    String updatedNotes = itemData['notes'] ?? '';
    DateTime updatedTime = DateTime.fromMillisecondsSinceEpoch(itemData['timestamp']);

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
              title: 'Update Diaper Change',
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CommonFormWidgets.buildFormCard(
                        title: 'Time',
                        child: CommonFormWidgets.buildDateTimePicker(
                          initialDateTime: updatedTime,
                          onDateTimeChanged: (newTime) {
                            updatedTime = newTime;
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      CommonFormWidgets.buildFormCard(
                        title: 'Type',
                        child: DropdownButtonFormField<String>(
                          value: updatedType,
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
                            if (value != null) {
                              updatedType = value;
                            }
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      CommonFormWidgets.buildFormCard(
                        title: 'Notes',
                        child: CommonFormWidgets.buildNotesField(
                          (value) => updatedNotes = value ?? '',
                          initialValue: updatedNotes,
                        ),
                      ),
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: CommonFormWidgets.buildSubmitButton(
                              text: 'Update',
                              onPressed: () async {
                                await _updateDiaperChange(
                                  uniqueKey,
                                  updatedType,
                                  updatedTime,
                                  updatedNotes,
                                );
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
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

  Future<void> _deleteDiaperChanges(String uniqueKey) async {
    try {
      final response = await http.delete(Uri.parse('http://127.0.0.1:5001/diaper-change/$uniqueKey'));
      
      if (response.statusCode == 200) {
        setState(() {
          // Get the index and data of the item being deleted
          final index = _spotKeys.indexOf(uniqueKey);
          final itemData = _spotDataMap[uniqueKey]!;
          final type = itemData['type'];
          
          // Update type distribution
          _typeDistribution[type] = (_typeDistribution[type]! - 1);
          
          // Remove from all data structures
          _spotKeys.removeAt(index);
          _diaperData.removeAt(index);
          _spotDataMap.remove(uniqueKey);
          
          // Update totals
          _totalChanges--;
          
          // Recalculate average if there are still entries
          if (_totalChanges > 0) {
            final oldestTimestamp = _diaperData.last.x.toInt();
            final firstChange = DateTime.fromMillisecondsSinceEpoch(oldestTimestamp);
            _averageChangesPerDay = _totalChanges / (DateTime.now().difference(firstChange).inDays + 1);
          } else {
            _averageChangesPerDay = 0;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diaper change deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: Could not delete diaper change')),
      );
    }
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

        // Fetch fresh data from server
        await _fetchDiaperData();
        
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding diaper.')),
        );
      }
    } catch (e) {
      print('Submission error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Could not add diaper change')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _updateDiaperChange(String id, String type, DateTime time, String notes) async {
    try {
      final response = await http.put(
        Uri.parse('http://127.0.0.1:5001/diaper-change/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'time': time.toIso8601String(),
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diaper change updated successfully!')),
        );
        await _fetchDiaperData(); // Refresh the data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating diaper change')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: Could not update diaper change')),
      );
    }
  }
}
