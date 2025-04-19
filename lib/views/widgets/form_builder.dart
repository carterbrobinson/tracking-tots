import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class CommonFormWidgets {
  static Widget buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.all(8),
      child: Container(
        width: 150,
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
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
        color: Color(0xFF6A359C).withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: tabController,
        // indicator: BoxDecoration(
        //   borderRadius: BorderRadius.circular(5),
        //   borderWidth: fit,
        //   color: Color(0xFF6A359C),
        // ),
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xFF6A359C),
        tabs: [
          Tab(text: 'History'),
          Tab(text: 'Analytics'),       
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

  static Widget buildNotesField(Function(String) onChanged, {String? initialValue}) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        hintText: 'Add notes...',
        hintStyle: TextStyle(
          color: Colors.grey[700],
        ),
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
    VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        // padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            Color(0xFF9969C7),
            Color(0xFF6A359C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  static Widget buildDateTimePicker({
    required DateTime initialDateTime,
    required Function(DateTime) onDateTimeChanged,
    bool isUpdate = false,
  }) {
    return Container(
      height: 180,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.dateAndTime,
        initialDateTime: initialDateTime,
        maximumDate: DateTime.now().add(Duration(days: 1)),
        minimumDate: isUpdate ? null : DateTime.now().subtract(Duration(days: 7)),
        onDateTimeChanged: onDateTimeChanged,
        use24hFormat: false,
      ),
    );
  }

  static Widget buildDateTimePickerForward({
    required DateTime initialDateTime,
    required Function(DateTime) onDateTimeChanged,
    DateTime? minimumDate,
    bool isUpdate = false,
  }) {
    DateTime effectiveInitialDate = initialDateTime;
    if (minimumDate != null && initialDateTime.isBefore(minimumDate)) {
      effectiveInitialDate = minimumDate;
    }
    
    return Container(
      height: 180,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.dateAndTime,
        initialDateTime: effectiveInitialDate,
        maximumDate: effectiveInitialDate.add(Duration(days: 30)),
        minimumDate: isUpdate ? null : (minimumDate ?? effectiveInitialDate),
        onDateTimeChanged: onDateTimeChanged,
        use24hFormat: false,
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
            color: Colors.white,
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