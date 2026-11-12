import 'package:flutter/material.dart';

import '../utils/rodape_desenvolvedor.dart';
import '../utils/validadores.dart';
import '../viewmodels/auth_viewmodel.dart';

// VIEW: rota "/" (apenas interface; a regra de negócio está no AuthViewModel).
class LoginView extends StatefulWidget {
  const LoginView({super.key, required this.auth});

  final AuthViewModel auth;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final usuario =
        await widget.auth.login(_emailController.text, _senhaController.text);

    if (!mounted) return;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail ou senha incorretos')),
      );
      return;
    }
    Navigator.pushReplacementNamed(context, '/home', arguments: usuario.nome);
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cor.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Icon(Icons.auto_stories, size: 52, color: cor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                  const Text('Leia e edite seus documentos'),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: validarEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senhaController,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: validarSenha,
                  ),
                  const SizedBox(height: 24),
                  // A view "escuta" o ViewModel: o botão reage a "carregando".
                  ListenableBuilder(
                    listenable: widget.auth,
                    builder: (context, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed:
                              widget.auth.carregando ? null : _fazerLogin,
                          child: widget.auth.carregando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Entrar'),
                        ),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/cadastro'),
                    child: const Text('Não tem uma conta? Cadastre-se'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const RodapeDesenvolvedor(),
    );
  }
}
