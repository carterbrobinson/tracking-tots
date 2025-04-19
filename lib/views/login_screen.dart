import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trackingtots/user_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  String _password = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9969C7), Color(0xFF6A359C)],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
          child: AppBar(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/tracking-tots-white.png",
                  width: 40,
                  height: 40,
                ),
                const SizedBox(width: 10),
                const Text("Login"),
              ],
            ),
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
          ),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _header(),
            _inputFields(),
            _loginButton(),
            _signupLink(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _header() {
    return const Column(
      children: [
        Text(
          "Welcome Back",
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _inputFields() {
    return Column(
      children: [
        const SizedBox(height: 20.0),
        const Text(
          "Enter your credentials to login",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 55,
            minWidth: 200,
            maxWidth: 400,
          ),
          child: TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              fillColor: Colors.purple.withOpacity(0.1),
              filled: true,
              prefixIcon: const Icon(Icons.email),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 55,
            minWidth: 200,
            maxWidth: 400,
          ),
          child: TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              fillColor: Colors.purple.withOpacity(0.1),
              filled: true,
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF6A359C),
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
            ),
            obscureText: !_passwordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
            onChanged: (value) => _password = value,
            onFieldSubmitted: (_) async {
              if (_formKey.currentState!.validate()) {
                final url = Uri.parse('http://127.0.0.1:5001/login');
                // final url = Uri.parse('https://tracking-tots.onrender.com/login');
                try {
                  final response = await http.post(
                    url,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'email': _emailController.text,
                      'password': _passwordController.text,
                    }),
                  );

                  if (!mounted) return;

                  if (response.statusCode == 200) {
                    final userData = jsonDecode(response.body);
                    UserState.setUserData(userData['user_id'], userData['name'], userData['email']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Login successful!")),
                    );
                    Navigator.pushReplacementNamed(context, '/');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Invalid credentials")),
                    );
                  }
                } catch (e) {
                   if (!mounted) return;
                   ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Login failed: ${e.toString()}")),
                   );
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _loginButton() {
    return ElevatedButton(
      onPressed: () async {
        if (_formKey.currentState!.validate()) {
          final url = Uri.parse('http://127.0.0.1:5001/login');
          // final url = Uri.parse('https://tracking-tots.onrender.com/login');
          try {
            final response = await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': _emailController.text,
                'password': _passwordController.text,
              }),
            );

            if (!mounted) return;

            if (response.statusCode == 200) {
              final userData = jsonDecode(response.body);
              UserState.setUserData(userData['user_id'], userData['name'], userData['email']);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Login successful!")),
              );
              Navigator.pushReplacementNamed(context, '/');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Invalid credentials")),
              );
            }
          } catch (e) {
             if (!mounted) return;
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Login failed: ${e.toString()}")),
             );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
        backgroundColor: const Color(0xFF6A359C),
      ),
      child: const Text("Login", style: TextStyle(fontSize: 20, color: Colors.white)),
    );
  }

  Widget _signupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account?"),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, '/signup');
          },
          child: const Text("Sign Up", style: TextStyle(color: Colors.purple)),
        )
      ],
    );
  }
}
