import '../usuario.dart';

// MODEL (service): simulação de banco relacional em memória (tabela "usuarios").
class BancoLocalService {
  final List<Usuario> _tabelaUsuarios = [];
  int _proximoId = 1; // simula AUTOINCREMENT

  /// INSERT: devolve false se o e-mail já existe (restrição UNIQUE).
  Future<bool> insert(String nome, String email, String senha) async {
    await Future.delayed(const Duration(milliseconds: 600)); // latência de I/O
    final emailNormalizado = email.trim().toLowerCase();
    final existe = _tabelaUsuarios.any((u) => u.email == emailNormalizado);
    if (existe) return false;
    _tabelaUsuarios.add(Usuario(
      id: _proximoId++,
      nome: nome.trim(),
      email: emailNormalizado,
      senha: senha,
    ));
    return true;
  }

  /// SELECT * FROM usuarios
  Future<List<Usuario>> query() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(_tabelaUsuarios);
  }

  /// SELECT * FROM usuarios WHERE email = ? AND senha = ?
  Future<Usuario?> autenticar(String email, String senha) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final emailNormalizado = email.trim().toLowerCase();
    for (final u in _tabelaUsuarios) {
      if (u.email == emailNormalizado && u.senha == senha) return u;
    }
    return null;
  }
}
