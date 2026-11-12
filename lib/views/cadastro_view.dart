import 'package:flutter/material.dart';

import '../utils/rodape_desenvolvedor.dart';
import '../utils/validadores.dart';
import '../viewmodels/auth_viewmodel.dart';

// VIEW: rota "/cadastro".
class CadastroView extends StatefulWidget {
  const CadastroView({super.key, required this.auth});

  final AuthViewModel auth;

  @override
  State<CadastroView> createState() => _CadastroViewState();
}

class _CadastroViewState extends State<CadastroView> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    final inserido = await widget.auth.cadastrar(
      _nomeController.text,
      _emailController.text,
      _senhaController.text,
    );

    if (!mounted) return;
    if (!inserido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este e-mail já está cadastrado')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuário cadastrado com sucesso!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final estiloTitulo = Theme.of(context).textTheme.titleMedium;
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final auth = widget.auth;
        return Scaffold(
          appBar: AppBar(title: const Text('Cadastro de Usuário')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome Completo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: validarNome,
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 20),
                  Text('Tema do app', style: estiloTitulo),
                  RadioListTile<bool>(
                    title: const Text('Tema Claro'),
                    value: false,
                    groupValue: auth.rascunhoTemaEscuro,
                    onChanged: (v) => auth.escolherTema(v!),
                  ),
                  RadioListTile<bool>(
                    title: const Text('Tema Escuro'),
                    value: true,
                    groupValue: auth.rascunhoTemaEscuro,
                    onChanged: (v) => auth.escolherTema(v!),
                  ),
                  const SizedBox(height: 12),
                  Text('Tamanho da fonte: ${(auth.rascunhoFonte * 100).round()}%',
                      style: estiloTitulo),
                  Slider(
                    value: auth.rascunhoFonte,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    label: '${(auth.rascunhoFonte * 100).round()}%',
                    onChanged: auth.escolherFonte,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.carregando ? null : _cadastrar,
                      child: auth.carregando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cadastrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const RodapeDesenvolvedor(),
        );
      },
    );
  }
}
