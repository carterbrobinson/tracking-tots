import 'package:flutter/material.dart';
import 'package:trackingtots/constants/colors.dart';

class ChatTextField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String?) onSubmitted;
  final FocusNode focusNode;

  const ChatTextField(
    {super.key, required this.controller, required this.onSubmitted, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: .8)),
      child: Row(
        children: [
          const SizedBox(height: 8), 
          Flexible(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: onSubmitted,
              cursorColor: Color(0xFF6A359C),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
            ),
            Padding(padding: const EdgeInsets.all(4.0),
            child: IconButton(
              onPressed: () => onSubmitted(controller.text),
              style: IconButton.styleFrom(
              backgroundColor: Color(0xFF6A359C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4))),
            icon: const Icon(Icons.send),
            ),
          )
        ],
      ),
    );
  }
}