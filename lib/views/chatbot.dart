import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:trackingtots/constants/colors.dart';
import 'package:trackingtots/models/conversation.dart';
import 'package:trackingtots/views/widgets/example_widget.dart';
import 'package:http/http.dart';
import 'package:trackingtots/views/widgets/top_navigation_bar.dart';


import 'widgets/chat_list_view.dart';
import 'widgets/chat_text_field.dart';

class Chatbot extends StatefulWidget {

  @override
  State<Chatbot> createState() => _ChatbotState();
}

class _ChatbotState extends State<Chatbot> {
  final TextEditingController controller = TextEditingController();
  List<Conversation> conversations = [];

  bool get isConversationStarted => conversations.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: TopNavigationBar(title: "Chatbot Page"),
      backgroundColor: Colors.purple[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), // Increased padding
          child: Column(
            children: [
              const SizedBox(height: 24), // Reduced top spacing
              if (!isConversationStarted) ...[
                Image.asset(
                  "assets/rattle.png",
                  height: 120, // Control image size
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Parenting Queries",
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Ask anything, get your answer",
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.purple[900],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wb_sunny_outlined,
                            color: Colors.purple[700],
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Examples",
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.purple[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const ExampleWidget(text: "What is your baby doing now?"),
                          const SizedBox(height: 12),
                          const ExampleWidget(text: "When should I sleep?"),
                          const SizedBox(height: 12),
                          const ExampleWidget(text: "Is it normal that my baby does this?"),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(child: ChatListView(conversations: conversations)),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ChatTextField(
                  controller: controller,
                  onSubmitted: (question) {
                    if (question?.trim().isEmpty ?? true) return;
                    
                    controller.clear();
                    FocusScope.of(context).unfocus();
                    setState(() {
                      conversations.add(Conversation(question!, "Thinking..."));
                    });
                    
                    post(
                      Uri.parse('http://127.0.0.1:5001/get-response'),
                      body: jsonEncode({"text": question}),
                      headers: {'Content-Type': "application/json"},
                    ).then((response) {
                      var jsonResponse = jsonDecode(response.body);
                      String result = jsonResponse.containsKey('response')
                          ? jsonResponse['response']
                          : "Error: No response received";
                      
                      setState(() {
                        conversations.last = Conversation(
                          conversations.last.question, 
                          result
                        );
                      });
                    }).catchError((error) {
                      setState(() {
                        conversations.last = Conversation(
                          conversations.last.question,
                          "Error: Failed to get response. Please try again."
                        );
                      });
                      print("Error: $error");
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}