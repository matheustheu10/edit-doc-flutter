import 'package:flutter/material.dart';

import 'models/services/banco_local_service.dart';
import 'models/services/documento_storage_service.dart';
import 'models/services/preferences_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/documentos_viewmodel.dart';
import 'views/cadastro_view.dart';
import 'views/editor_view.dart';
import 'views/home_view.dart';
import 'views/login_view.dart';

Future<void> main() async {
  // Necessário porque o shared_preferences é usado antes do runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Os serviços e ViewModels são criados uma única vez e entregues às views.
  final banco = BancoLocalService(DocumentoStorageService());
  final auth = AuthViewModel(PreferencesService(), banco);
  final docs = DocumentosViewModel(banco);

  // Restaura o que foi salvo: tema/fonte, sessão do usuário e documentos.
  await auth.aplicarPreferenciasSalvas();
  await auth.restaurarSessao();
  await docs.carregar();

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
          initialRoute: auth.usuarioLogado != null ? '/home' : '/',
          routes: {
            '/': (context) => LoginView(auth: auth),
            '/cadastro': (context) => CadastroView(auth: auth),
            '/home': (context) => HomeView(auth: auth, docs: docs),
            '/editor': (context) => EditorView(docs: docs),
          },
        );
      },
    );
  }
}
