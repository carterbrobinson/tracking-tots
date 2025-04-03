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
      appBar: TopNavigationBar(title: "Parenting Assistant"),
      backgroundColor: Colors.purple[50],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 38),
                      if (!isConversationStarted) ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            "assets/rattle.png",
                            height: 80,
                            width: 80,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Parenting Queries",
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Ask anything, get your answer",
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Icon(Icons.lightbulb_outline, 
                          color: Colors.deepPurple,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Try asking about:",
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ExampleWidget(text: "What is normal sleep for my baby?"),
                        const SizedBox(height: 12),
                        ExampleWidget(text: "When should I start solid foods?"),
                        const SizedBox(height: 12),
                        ExampleWidget(text: "How often should my baby have wet diapers?"),
                      ] else ...[
                        ChatListView(conversations: conversations),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
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
                    // Uri.parse('http://127.0.0.1:5000/get-response'),
                    Uri.parse('https://tracking-tots.onrender.com/get-response/${UserState.userId}'),
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
                        "Error: Failed to get response"
                      );
                    });
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
