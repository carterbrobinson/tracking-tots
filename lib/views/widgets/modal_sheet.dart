import 'package:flutter/material.dart';
import 'package:trackingtots/views/widgets/form_builder.dart';


class BaseModalSheet extends StatelessWidget {
  final List<Widget> children;
  final String title;

  const BaseModalSheet({
    Key? key,
    required this.children,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9969C7), Color(0xFF6A359C)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommonFormWidgets.buildModalHeader(
              title: title,
              onClose: () => Navigator.pop(context),
            ),
            SizedBox(height: 20),
            ...children,
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}