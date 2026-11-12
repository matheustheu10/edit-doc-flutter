import 'package:shared_preferences/shared_preferences.dart';

// MODEL (service): persistência chave-valor com shared_preferences.

typedef Preferencias = ({bool temaEscuro, double fonte});
typedef Sessao = ({String nome, String email});

class PreferencesService {
  static const String _chaveTemaEscuro = 'tema_escuro'; // bool
  static const String _chaveFonte = 'tamanho_fonte'; // double 0.8 a 1.4
  static const String _chaveSessaoNome = 'sessao_nome'; // String
  static const String _chaveSessaoEmail = 'sessao_email'; // String

  Future<void> salvarPreferencias({
    required bool temaEscuro,
    required double fonte,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveTemaEscuro, temaEscuro);
    await prefs.setDouble(_chaveFonte, fonte);
  }

  Future<Preferencias> carregarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      temaEscuro: prefs.getBool(_chaveTemaEscuro) ?? false,
      fonte: prefs.getDouble(_chaveFonte) ?? 1.0,
    );
  }

  Future<void> salvarSessao(String nome, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveSessaoNome, nome);
    await prefs.setString(_chaveSessaoEmail, email);
  }

  Future<Sessao?> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final nome = prefs.getString(_chaveSessaoNome);
    final email = prefs.getString(_chaveSessaoEmail);
    if (nome == null || email == null) return null;
    return (nome: nome, email: email);
  }

  Future<void> limparSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveSessaoNome);
    await prefs.remove(_chaveSessaoEmail);
  }
}
