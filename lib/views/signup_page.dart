import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _confirmPasswordVisible = false;
  bool _passwordVisible = false;
  String _password = '';
  String _confirmPassword = '';

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
            title: const Text("Sign up"),
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          height: MediaQuery.of(context).size.height - 50,
          width: double.infinity,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _header(),
                Column(
                  children: <Widget>[
                    const SizedBox(height: 20.0),
                    const Text(
                      "Create your account",
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
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: "First Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.purple.withOpacity(0.1),
                          filled: true,
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
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
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: "Last Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.purple.withOpacity(0.1),
                          filled: true,
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
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
                              color: Color(0xFF6A359C),
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
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.purple.withOpacity(0.1),
                          filled: true,
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Color(0xFF6A359C),
                            ),
                            onPressed: () {
                              setState(() {
                                _confirmPasswordVisible = !_confirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        onFieldSubmitted: (_) async {
                          if (_formKey.currentState!.validate()) {
                            final url = Uri.parse('http://127.0.0.1:5001/register');
                            final response = await http.post(
                              url,
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'name': '${_firstNameController.text} ${_lastNameController.text}',
                                'email': _emailController.text,
                                'password': _passwordController.text,
                              }),
                            );

                            if (response.statusCode == 201) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Sign up successful! Please login.")),
                              );
                              Navigator.pushNamed(context, '/login');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Sign up failed. Please try again.")),
                              );
                            }
                          }
                        },
                        obscureText: !_confirmPasswordVisible,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        onChanged: (value) => _confirmPassword = value,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final url = Uri.parse('http://127.0.0.1:5001/register');
                      // final url = Uri.parse('https://tracking-tots.onrender.com/register');
                      final response = await http.post(
                        url,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'name': '${_firstNameController.text} ${_lastNameController.text}',
                          'email': _emailController.text,
                          'password': _passwordController.text,
                        }),
                      );

                      if (response.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Sign up successful! Please login.")),
                        );
                        Navigator.pushNamed(context, '/login');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Sign up failed. Please try again.")),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
                    backgroundColor: Color(0xFF6A359C),
                  ),
                  child: const Text("Sign Up", style: TextStyle(fontSize: 20, color: Colors.white)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text("Already have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: const Text("Login", style: TextStyle(color: Colors.purple)),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
    Widget _header() {
    return const Column(
      children: [
        Text(
          "Tracking Tots Signup",
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
