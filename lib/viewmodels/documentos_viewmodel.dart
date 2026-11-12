import 'package:flutter/foundation.dart';

import '../models/documento.dart';

// VIEWMODEL: lista de documentos e estado do editor da Home.
class DocumentosViewModel extends ChangeNotifier {
  final List<Documento> _documentos = [
    const Documento(
      id: 1,
      titulo: 'Governança de TI.pdf',
      tipo: 'pdf',
      texto:
          'A governança de TI garante que a tecnologia apoie os objetivos do negócio.',
    ),
    const Documento(
      id: 2,
      titulo: 'Resumo da aula.txt',
      tipo: 'txt',
      texto: 'Rotas nomeadas permitem navegar entre telas usando um nome único.',
    ),
    const Documento(
      id: 3,
      titulo: 'Ideias do projeto',
      tipo: 'nota',
      texto: 'Tela de login, cadastro e editor de documentos.',
    ),
  ];

  int _indiceSelecionado = 0;
  bool _modoLeitura = false;

  List<Documento> get documentos => List.unmodifiable(_documentos);
  int get indiceSelecionado => _indiceSelecionado;
  Documento get selecionado => _documentos[_indiceSelecionado];
  bool get modoLeitura => _modoLeitura;

  void abrir(int indice) {
    _indiceSelecionado = indice;
    notifyListeners();
  }

  void novo() {
    final proximoId = _documentos.fold<int>(0, (m, d) => d.id > m ? d.id : m) + 1;
    _documentos.add(Documento(
      id: proximoId,
      titulo: 'Documento ${_documentos.length + 1}',
      tipo: 'txt',
      texto: '',
    ));
    _indiceSelecionado = _documentos.length - 1;
    _modoLeitura = false;
    notifyListeners();
  }

  /// Guarda na lista o que está no editor.
  void salvarAtual(String titulo, String texto) {
    final t = titulo.trim();
    _documentos[_indiceSelecionado] = selecionado.copyWith(
      titulo: t.isEmpty ? 'Sem título' : t,
      texto: texto,
    );
    notifyListeners();
  }

  void alternarModoLeitura() {
    _modoLeitura = !_modoLeitura;
    notifyListeners();
  }
}
