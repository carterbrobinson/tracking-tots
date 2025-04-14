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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSleepTimingChart(),
          SizedBox(height: 24),
          _buildSleepQualityDistribution(),
          SizedBox(height: 24),
          _buildWeeklySleepTotals(),
        ],
      ),
    );
  }
    
  Widget _buildSleepTimingChart() {
    if (_sleepData.isEmpty) {
      return _buildEmptyAnalyticsCard("Sleep Timing Patterns");
    }
    
    // Process data to show when sleep is occurring
    final Map<int, List<double>> hourlyDistribution = {};
    for (int i = 0; i < 24; i++) {
      hourlyDistribution[i] = [];
    }
    
    try {
      for (var spot in _sleepData) {
        final startTime = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
        final durationMinutes = spot.y.toInt();
        final endTime = startTime.add(Duration(minutes: durationMinutes));
        
        // Track each hour that this sleep session covers
        DateTime currentHour = DateTime(startTime.year, startTime.month, startTime.day, startTime.hour);
        
        while (currentHour.isBefore(endTime)) {
          final hour = currentHour.hour;
          hourlyDistribution[hour]?.add(1.0);
          currentHour = currentHour.add(Duration(hours: 1));
        }
      }
    } catch (e) {
      print('Error processing sleep timing data: $e');
    }
    
    // Calculate sleep frequency for each hour (0-23)
    final List<double> hourlyFrequency = List.generate(24, (hour) {
      return hourlyDistribution[hour]?.length.toDouble() ?? 0;
    });
    
    // Find max for scaling
    final maxFrequency = hourlyFrequency.reduce((max, value) => max > value ? max : value);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep Timing Patterns', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Shows when baby is usually sleeping throughout the day',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 16),
            Container(
              height: 160,
              child: Row(
                children: [
                  // Left axis labels
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('High', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text('Medium', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text('Low', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text('None', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  SizedBox(width: 8),
                  // Main chart
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(24, (hour) {
                        final frequency = hourlyFrequency[hour];
                        final intensity = maxFrequency > 0 ? frequency / maxFrequency : 0;
                        
                        return Tooltip(
                          message: '$hour:00 - ${(hour + 1) % 24}:00: ${frequency.toInt()} sleep sessions',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 10,
                                height: (120 * intensity).toDouble(),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.3 + 0.7 * intensity),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                hour.toString(),
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Hours of the Day (24h format)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepQualityDistribution() {
    if (_sleepData.isEmpty) {
      return _buildEmptyAnalyticsCard("Sleep Quality Distribution");
    }
    
    // Analyze sleep quality
    Map<String, int> qualityDistribution = {
      'Insufficient': 0,
      'Below Recommended': 0, 
      'Optimal': 0,
      'Extended': 0,
      'Power Nap': 0,
      'Ideal Nap': 0,
      'Long Nap': 0,
    };
    
    try {
      for (var spot in _sleepData) {
        final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
        final durationHours = spot.y / 60;
        final isNap = _isNapTime(date);
        
        if (isNap) {
          if (durationHours < 0.5) {
            qualityDistribution['Power Nap'] = (qualityDistribution['Power Nap'] ?? 0) + 1;
          } else if (durationHours <= 1) {
            qualityDistribution['Ideal Nap'] = (qualityDistribution['Ideal Nap'] ?? 0) + 1;
          } else {
            qualityDistribution['Long Nap'] = (qualityDistribution['Long Nap'] ?? 0) + 1;
          }
        } else {
          if (durationHours < 6) {
            qualityDistribution['Insufficient'] = (qualityDistribution['Insufficient'] ?? 0) + 1;
          } else if (durationHours < 7) {
            qualityDistribution['Below Recommended'] = (qualityDistribution['Below Recommended'] ?? 0) + 1;
          } else if (durationHours <= 9) {
            qualityDistribution['Optimal'] = (qualityDistribution['Optimal'] ?? 0) + 1;
          } else {
            qualityDistribution['Extended'] = (qualityDistribution['Extended'] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      print('Error analyzing sleep quality: $e');
    }
    
    // Filter out zeros to avoid empty pie sections
    final Map<String, int> filteredQuality = Map.fromEntries(
      qualityDistribution.entries.where((entry) => entry.value > 0)
    );
    
    // Color mapping for quality categories
    final Map<String, Color> qualityColors = {
      'Insufficient': Colors.red,
      'Below Recommended': Colors.orange, 
      'Optimal': Colors.green,
      'Extended': Colors.blue,
      'Power Nap': Colors.amber,
      'Ideal Nap': Colors.teal,
      'Long Nap': Colors.indigo,
    };
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep Quality Distribution', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Breakdown of sleep quality categories',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: filteredQuality.isNotEmpty
                  ? PieChart(
                      PieChartData(
                        sections: filteredQuality.entries.map((entry) {
                          final percentage = (entry.value / _sleepData.length * 100).toStringAsFixed(0);
                          return PieChartSectionData(
                            value: entry.value.toDouble(),
                            title: '$percentage%',
                            titleStyle: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            color: qualityColors[entry.key] ?? Colors.grey,
                            radius: 70,
                          );
                        }).toList(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    )
                  : Center(child: Text('No quality data available')),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: filteredQuality.keys.map((key) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: qualityColors[key] ?? Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(key, style: TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySleepTotals() {
    if (_sleepData.isEmpty) {
      return _buildEmptyAnalyticsCard("Weekly Sleep Totals");
    }
    
    // Group sleep data by day
    Map<String, double> dailyTotals = {};
    
    try {
      for (var spot in _sleepData) {
        final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
        final dateStr = DateFormat('MM/dd').format(date);
        dailyTotals[dateStr] = (dailyTotals[dateStr] ?? 0) + spot.y;
      }
    } catch (e) {
      print('Error processing daily sleep totals: $e');
    }
    
    // Get the last 7 days (or fewer if we don't have that much data)
    List<String> dates = dailyTotals.keys.toList();
    dates.sort(); // Sort chronologically
    
    // Take only the last 7 days
    if (dates.length > 7) {
      dates = dates.sublist(dates.length - 7);
    }
    
    // Create filtered map with just those days
    Map<String, double> filteredDailyTotals = {};
    for (var date in dates) {
      filteredDailyTotals[date] = dailyTotals[date] ?? 0;
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Sleep Totals', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Total sleep hours per day over the past week',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: dates.isNotEmpty
                  ? BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (filteredDailyTotals.values.reduce(
                                (a, b) => a > b ? a : b) / 60)
                            .ceilToDouble() +
                            1,
                        barGroups: List.generate(dates.length, (index) {
                          final date = dates[index];
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: (filteredDailyTotals[date] ?? 0) / 60,
                                width: 20,
                                color: Color(0xFF6A359C),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                            left: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < dates.length) {
                                  return Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      dates[index],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                }
                                return Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}h',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                );
                              },
                              reservedSize: 30,
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipPadding: EdgeInsets.all(8),
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final date = dates[group.x.toInt()];
                              final hours = (rod.toY).toStringAsFixed(1);
                              return BarTooltipItem(
                                '$date\n$hours hours',
                                TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  : Center(child: Text('No daily sleep data available')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAnalyticsCard(String title) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Container(
              height: 150,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.nights_stay_outlined, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Not enough sleep data to display insights',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add more sleep sessions to see analytics',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
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
