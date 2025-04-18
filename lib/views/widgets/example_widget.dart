import 'package:flutter/material.dart';
import 'package:trackingtots/constants/colors.dart';

class ExampleWidget extends StatelessWidget {
  final String text;

  const ExampleWidget({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CustomColors.darkGrey,
        borderRadius: BorderRadius.circular(8)
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 36),
      child: Text(text, style: textTheme.bodyLarge, textAlign: TextAlign.center),
    );
  }
}