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
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .95,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 38),
                    if (!isConversationStarted) ...[
                      Image.asset("assets/rattle.png"),
                      const SizedBox(height: 16),
                      Text(
                        "Parenting Queries",
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Ask anything, get your answer",
                        style: textTheme.bodyMedium,
                      ),
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wb_sunny_outlined),
                              const SizedBox(height: 6),
                              Text(
                                "Examples",
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: 40),
                              const ExampleWidget(text: "What is your baby doing now?"),
                              const ExampleWidget(text: "When should I sleep?"),
                              const ExampleWidget(text: "Is it normal that my baby does this?"),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(child: ChatListView(conversations: conversations)),
                    ],
                    ChatTextField(
                      controller: controller,
                      onSubmitted: (question) {
                        controller.clear();
                        FocusScope.of(context).unfocus();
                        conversations.add(Conversation(question!, ""));
                        setState(() {});
                        post(
                          Uri.parse('http://127.0.0.1:5000/get-response'),
                          body: jsonEncode({"text": question}),
                          headers: {'Content-Type': "application/json"},
                        ).then((response) {
                          var jsonResponse = jsonDecode(response.body);
                          String result = jsonResponse.containsKey('response')
                              ? jsonResponse['response']
                              : "Error: No response received";
                          
                          conversations.last = Conversation(conversations.last.question, result);
                          setState(() {});
                        }).catchError((error) {
                          conversations.last = Conversation(conversations.last.question, "Error: Failed to get response");
                          setState(() {});
                        });

                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
