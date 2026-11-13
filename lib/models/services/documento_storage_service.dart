import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../documento.dart';

// MODEL (service): CRUD de documentos. A lista de objetos Documento é
// serializada para JSON (jsonEncode) e guardada no shared_preferences;
// na leitura, jsonDecode reconstrói os objetos.
class DocumentoStorageService {
  static const String _chave = 'documentos_json';

  static const List<Documento> _iniciais = [
    Documento(
      id: 1,
      titulo: 'Governança de TI.pdf',
      tipo: 'pdf',
      texto:
          'A governança de TI garante que a tecnologia apoie os objetivos do negócio.',
    ),
    Documento(
      id: 2,
      titulo: 'Resumo da aula.txt',
      tipo: 'txt',
      texto: 'Rotas nomeadas permitem navegar entre telas usando um nome único.',
    ),
    Documento(
      id: 3,
      titulo: 'Ideias do projeto',
      tipo: 'nota',
      texto: 'Tela de login, cadastro e editor de documentos.',
    ),
  ];

  /// READ: lista todos. No primeiro uso (nada salvo), grava os exemplos.
  Future<List<Documento>> listar() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_chave);
    if (bruto == null) {
      await _gravar(_iniciais);
      return List.of(_iniciais);
    }
    final lista = jsonDecode(bruto) as List<dynamic>;
    return lista
        .map((e) => Documento.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _gravar(List<Documento> documentos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chave,
      jsonEncode(documentos.map((d) => d.toJson()).toList()),
    );
  }

  /// CREATE
  Future<Documento> criar({
    required String titulo,
    required String tipo,
    required String texto,
  }) async {
    final lista = await listar();
    final proximoId = lista.fold<int>(0, (m, d) => d.id > m ? d.id : m) + 1;
    final novo = Documento(id: proximoId, titulo: titulo, tipo: tipo, texto: texto);
    lista.add(novo);
    await _gravar(lista);
    return novo;
  }

  /// UPDATE
  Future<void> atualizar(Documento documento) async {
    final lista = await listar();
    final indice = lista.indexWhere((d) => d.id == documento.id);
    if (indice == -1) return;
    lista[indice] = documento;
    await _gravar(lista);
  }

  /// DELETE
  Future<void> excluir(int id) async {
    final lista = await listar();
    lista.removeWhere((d) => d.id == id);
    await _gravar(lista);
  }
}
