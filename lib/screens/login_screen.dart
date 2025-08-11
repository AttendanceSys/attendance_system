import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF9D83D7), // Top (Purple)
              Color(0xFF4D91D6), // Bottom (Blue)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: isMobile
              ? _buildMobileForm(context)
              : _buildWebForm(context),
        ),
      ),
    );
  }

  Widget _buildMobileForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "LOGIN",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 32),
          _buildInputField(
            icon: Icons.person,
            hint: "Username",
            obscure: false,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            icon: Icons.lock,
            hint: "Password",
            obscure: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D91D6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {},
              child: const Text(
                "Login",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebForm(BuildContext context) {
    return Center(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "LOGIN",
              style: TextStyle(
                color: Color(0xFF4D91D6),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            _buildInputField(
              icon: Icons.person,
              hint: "Username",
              obscure: false,
              fillColor: Colors.grey[100],
              textColor: Colors.black87,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              icon: Icons.lock,
              hint: "Password",
              obscure: true,
              fillColor: Colors.grey[100],
              textColor: Colors.black87,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4D91D6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {},
                child: const Text(
                  "Login",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required String hint,
    required bool obscure,
    Color? fillColor,
    Color? textColor,
  }) {
    return TextField(
      obscureText: obscure,
      style: TextStyle(color: textColor ?? Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor ?? Colors.white.withOpacity(0.2),
        prefixIcon: Icon(icon, color: textColor ?? Colors.white),
        hintText: hint,
        hintStyle: TextStyle(color: textColor ?? Colors.white70),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}