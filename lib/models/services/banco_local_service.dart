import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../documento.dart';
import '../usuario.dart';
import 'documento_storage_service.dart';

// MODEL (service): "banco local" do app. Cuida do CRUD de usuários e também é a
// porta de entrada para os documentos: as operações de documento são entregues
// ao DocumentoStorageService, que faz a gravação em JSON.
// A lista de objetos é serializada para JSON e guardada no shared_preferences.
class BancoLocalService {
  BancoLocalService(this._documentos);

  final DocumentoStorageService _documentos;

  static const String _chave = 'usuarios_json';

  /// SELECT * FROM usuarios
  Future<List<Usuario>> query() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_chave);
    if (bruto == null) return [];
    final lista = jsonDecode(bruto) as List<dynamic>;
    return lista
        .map((e) => Usuario.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _gravar(List<Usuario> usuarios) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chave,
      jsonEncode(usuarios.map((u) => u.toJson()).toList()),
    );
  }

  /// INSERT: devolve false se o e-mail já existe (restrição UNIQUE).
  Future<bool> insert(String nome, String email, String senha) async {
    final usuarios = await query();
    final emailNormalizado = email.trim().toLowerCase();
    if (usuarios.any((u) => u.email == emailNormalizado)) return false;

    final proximoId = usuarios.fold<int>(0, (m, u) => u.id > m ? u.id : m) + 1;
    usuarios.add(Usuario(
      id: proximoId,
      nome: nome.trim(),
      email: emailNormalizado,
      senha: senha,
    ));
    await _gravar(usuarios);
    return true;
  }

  /// SELECT * FROM usuarios WHERE email = ? AND senha = ?
  Future<Usuario?> autenticar(String email, String senha) async {
    final emailNormalizado = email.trim().toLowerCase();
    for (final u in await query()) {
      if (u.email == emailNormalizado && u.senha == senha) return u;
    }
    return null;
  }

  /// SELECT * FROM usuarios WHERE email = ?
  Future<Usuario?> buscarPorEmail(String email) async {
    final emailNormalizado = email.trim().toLowerCase();
    for (final u in await query()) {
      if (u.email == emailNormalizado) return u;
    }
    return null;
  }

  // ---------------- Documentos (delegam ao DocumentoStorageService) ----------------

  /// READ
  Future<List<Documento>> listarDocumentos() => _documentos.listar();

  /// CREATE
  Future<Documento> inserirDocumento({
    required String titulo,
    required String tipo,
    required String texto,
  }) =>
      _documentos.criar(titulo: titulo, tipo: tipo, texto: texto);

  /// UPDATE
  Future<void> atualizarDocumento(Documento documento) =>
      _documentos.atualizar(documento);

  /// DELETE
  Future<void> excluirDocumento(int id) => _documentos.excluir(id);
}
