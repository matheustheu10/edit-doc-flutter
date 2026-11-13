import 'package:flutter/foundation.dart';

import '../models/documento.dart';
import '../models/services/banco_local_service.dart';

// VIEWMODEL: listagem e operações CRUD dos documentos.
// Toda operação passa pelo BancoLocalService (persistência) e depois notifica as views.
class DocumentosViewModel extends ChangeNotifier {
  DocumentosViewModel(this._banco);

  final BancoLocalService _banco;

  List<Documento> _documentos = [];

  List<Documento> get documentos => List.unmodifiable(_documentos);

  /// READ
  Future<void> carregar() async {
    _documentos = await _banco.listarDocumentos();
    notifyListeners();
  }

  /// CREATE
  Future<void> criar({
    required String titulo,
    required String tipo,
    required String texto,
  }) async {
    await _banco.inserirDocumento(titulo: titulo.trim(), tipo: tipo, texto: texto);
    await carregar();
  }

  /// UPDATE
  Future<void> atualizar(Documento documento) async {
    await _banco.atualizarDocumento(documento);
    await carregar();
  }

  /// DELETE
  Future<void> excluir(int id) async {
    await _banco.excluirDocumento(id);
    await carregar();
  }
}
