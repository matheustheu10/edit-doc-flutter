// MODEL: entidade Documento (antes era um Map<String, String> no DartPad).
class Documento {
  final int id;
  final String titulo;
  final String tipo; // 'pdf', 'txt' ou 'nota'
  final String texto;

  const Documento({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.texto,
  });

  int get totalPalavras {
    final t = texto.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  Documento copyWith({String? titulo, String? tipo, String? texto}) {
    return Documento(
      id: id,
      titulo: titulo ?? this.titulo,
      tipo: tipo ?? this.tipo,
      texto: texto ?? this.texto,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'tipo': tipo,
        'texto': texto,
      };

  factory Documento.fromJson(Map<String, dynamic> json) => Documento(
        id: json['id'] as int,
        titulo: json['titulo'] as String,
        tipo: json['tipo'] as String,
        texto: json['texto'] as String,
      );
}
