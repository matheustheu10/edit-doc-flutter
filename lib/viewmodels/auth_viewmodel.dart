import 'package:flutter/foundation.dart';

import '../models/services/banco_local_service.dart';
import '../models/services/preferences_service.dart';
import '../models/usuario.dart';

// VIEWMODEL: autenticação, cadastro e preferências (tema e fonte).
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._prefs, this._banco);

  final PreferencesService _prefs;
  final BancoLocalService _banco;

  // Preferências aplicadas ao app (antes: ValueNotifier globais)
  bool _temaEscuro = false;
  double _fonte = 1.0;

  // Escolhas feitas na tela de cadastro, ainda não gravadas
  // (antes: variáveis _tema e _fonte com setState)
  bool _rascunhoTemaEscuro = false;
  double _rascunhoFonte = 1.0;

  // Antes: _carregando (login) e _salvando (cadastro) com setState
  bool _carregando = false;

  Usuario? _usuarioLogado;

  bool get temaEscuro => _temaEscuro;
  double get fonte => _fonte;
  bool get rascunhoTemaEscuro => _rascunhoTemaEscuro;
  double get rascunhoFonte => _rascunhoFonte;
  bool get carregando => _carregando;
  Usuario? get usuarioLogado => _usuarioLogado;

  void escolherTema(bool escuro) {
    _rascunhoTemaEscuro = escuro;
    notifyListeners();
  }

  void escolherFonte(double fonte) {
    _rascunhoFonte = fonte;
    notifyListeners();
  }

  /// Ao abrir o app: se houver sessão salva e o usuário ainda existir, entra direto.
  Future<void> restaurarSessao() async {
    final sessao = await _prefs.carregarSessao();
    if (sessao == null) return;
    final usuario = await _banco.buscarPorEmail(sessao.email);
    if (usuario == null) {
      await _prefs.limparSessao();
      return;
    }
    _usuarioLogado = usuario;
    notifyListeners();
  }

  /// Lê o que está salvo e aplica no app inteiro.
  Future<void> aplicarPreferenciasSalvas() async {
    final p = await _prefs.carregarPreferencias();
    _temaEscuro = p.temaEscuro;
    _fonte = p.fonte;
    notifyListeners();
  }

  /// Usado pelo Card "Preferências do Usuário" da Home.
  Future<Preferencias> lerPreferenciasSalvas() => _prefs.carregarPreferencias();

  /// Usado pelo Card "Usuários no Banco Local" da Home.
  Future<List<Usuario>> listarUsuarios() => _banco.query();

  Future<Usuario?> login(String email, String senha) async {
    _carregando = true;
    notifyListeners();

    final usuario = await _banco.autenticar(email, senha);
    if (usuario != null) {
      _usuarioLogado = usuario;
      await _prefs.salvarSessao(usuario.nome, usuario.email);
      await aplicarPreferenciasSalvas();
    }

    _carregando = false;
    notifyListeners();
    return usuario;
  }

  /// Devolve false se o e-mail já estiver cadastrado.
  Future<bool> cadastrar(String nome, String email, String senha) async {
    _carregando = true;
    notifyListeners();

    final inserido = await _banco.insert(nome, email, senha);
    if (inserido) {
      await _prefs.salvarPreferencias(
        temaEscuro: _rascunhoTemaEscuro,
        fonte: _rascunhoFonte,
      );
      _rascunhoTemaEscuro = false;
      _rascunhoFonte = 1.0;
    }

    _carregando = false;
    notifyListeners();
    return inserido;
  }

  Future<void> logout() async {
    _usuarioLogado = null;
    await _prefs.limparSessao();
    notifyListeners();
  }
}
