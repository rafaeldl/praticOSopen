import 'package:praticos/mobx/auth_store.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  AuthStore _auth = AuthStore();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xff3b97d3),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image(image: AssetImage("assets/images/icon.png"), height: 200.0),
              SizedBox(height: 60),
              _buildSocialButton(
                onPressed: () {
                  _auth.signInWithGoogle();
                },
                text: 'Entrar com Google',
                color: Colors.white,
                textColor: Colors.black87,
                icon: Image(
                  image: AssetImage("assets/images/google_logo.png"),
                  height: 24.0,
                ),
              ),
              SizedBox(height: 16),
              _buildSocialButton(
                onPressed: () async {
                  try {
                    await _auth.signInWithApple();
                  } catch (e) {
                    print(e);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao entrar com Apple: $e'),
                      ),
                    );
                  }
                },
                text: 'Entrar com Apple',
                color: Colors.black,
                textColor: Colors.white,
                icon: Icon(FontAwesomeIcons.apple, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onPressed,
    required String text,
    required Color color,
    required Color textColor,
    required Widget icon,
  }) {
    return SizedBox(
      width: 280,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
