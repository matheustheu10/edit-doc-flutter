import 'package:flutter/material.dart';

import 'models/services/banco_local_service.dart';
import 'models/services/preferences_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/documentos_viewmodel.dart';
import 'views/cadastro_view.dart';
import 'views/home_view.dart';
import 'views/login_view.dart';

void main() {
  // Os serviços e ViewModels são criados uma única vez e entregues às views.
  final auth = AuthViewModel(PreferencesService(), BancoLocalService());
  final docs = DocumentosViewModel();
  runApp(MeuApp(auth: auth, docs: docs));
}

ThemeData _montarTema(Brightness brilho) {
  final claro = brilho == Brightness.light;
  return ThemeData(
    colorSchemeSeed: Colors.indigo,
    brightness: brilho,
    useMaterial3: true,
    scaffoldBackgroundColor: claro ? const Color(0xFFF5F6FA) : null,
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    ),
  );
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key, required this.auth, required this.docs});

  final AuthViewModel auth;
  final DocumentosViewModel docs;

  @override
  Widget build(BuildContext context) {
    // O app escuta o AuthViewModel: tema e fonte mudam quando ele notifica.
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Aula de Roteamento e Form',
          themeMode: auth.temaEscuro ? ThemeMode.dark : ThemeMode.light,
          theme: _montarTema(Brightness.light),
          darkTheme: _montarTema(Brightness.dark),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(auth.fonte)),
              child: child!,
            );
          },
          initialRoute: '/',
          routes: {
            '/': (context) => LoginView(auth: auth),
            '/cadastro': (context) => CadastroView(auth: auth),
            '/home': (context) => HomeView(auth: auth, docs: docs),
          },
        );
      },
    );
  }
}
