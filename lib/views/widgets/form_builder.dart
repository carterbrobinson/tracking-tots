import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class CommonFormWidgets {
  static Widget buildSummaryCard(String title, String value, IconData icon, Color color) {
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

  static Widget buildDataVisualizationTabs(TabController tabController) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: tabController,
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
    );
  }

  static Widget buildFormCard({
    required String title,
    required Widget child,
    double elevation = 2,
  }) {
    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  static Widget buildNotesField(Function(String) onChanged) {
    return TextFormField(
      decoration: InputDecoration(
        hintText: 'Add any additional notes...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.all(16),
      ),
      maxLines: 3,
      onChanged: onChanged,
    );
  }

  static Widget buildSubmitButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Widget buildDateTimePicker({
    required DateTime initialDateTime,
    required Function(DateTime) onDateTimeChanged,
  }) {
    return Container(
      height: 180,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.dateAndTime,
        initialDateTime: initialDateTime,
        maximumDate: DateTime.now(),
        minimumDate: DateTime.now().subtract(Duration(days: 7)),
        onDateTimeChanged: onDateTimeChanged,
      ),
    );
  }
  static Widget buildDateTimePickerForward({
    required DateTime initialDateTime,
    required Function(DateTime) onDateTimeChanged,
    DateTime? minimumDate,
  }) {

    DateTime effectiveInitialDate = initialDateTime;
    if (minimumDate != null && initialDateTime.isBefore(minimumDate)) {
      effectiveInitialDate = minimumDate;
    }
    return Container(
      height: 180,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.dateAndTime ,
        initialDateTime: effectiveInitialDate,
        maximumDate: effectiveInitialDate.add(Duration(days: 30)),
        minimumDate: minimumDate,
        onDateTimeChanged: onDateTimeChanged,
      ),
    );
  }

  static Widget buildModalHeader({
    required String title,
    required VoidCallback onClose,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: onClose,
        ),
      ],
    );
  }
}