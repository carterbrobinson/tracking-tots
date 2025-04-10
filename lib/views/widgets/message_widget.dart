import 'package:flutter/material.dart';
import 'package:trackingtots/constants/colors.dart';

class MessageWidget extends StatelessWidget {
  final String text;
  final bool fromAi;

  const MessageWidget({super.key, required this.text, this.fromAi = false});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: fromAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * .8
            ),
            decoration: BoxDecoration(
                color: fromAi ? Colors.white : Color(0xFF6A359C),
                borderRadius: BorderRadius.circular(8).copyWith(
                    bottomLeft: fromAi ? const Radius.circular(0) : null,
                    bottomRight: !fromAi ? const Radius.circular(0) : null)),
            padding: const EdgeInsets.all(12),
            child: Text(text, style: TextStyle(
              color: fromAi ? Colors.black : Colors.white,
            )),
          ),
        ],
      ),
    );
  }
}