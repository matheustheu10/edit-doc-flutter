import 'package:flutter/material.dart';

import '../models/documento.dart';
import '../utils/rodape_desenvolvedor.dart';
import '../utils/validadores.dart';
import '../viewmodels/documentos_viewmodel.dart';

// VIEW: rota "/editor". Sem argumento = criar documento novo;
// com um Documento como argumento = editar (e poder excluir).
class EditorView extends StatefulWidget {
  const EditorView({super.key, required this.docs});

  final DocumentosViewModel docs;

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _textoController = TextEditingController();

  // Estados só de interface (escolha local, não são dados do app).
  final ValueNotifier<String> _tipo = ValueNotifier<String>('txt');
  final ValueNotifier<bool> _modoLeitura = ValueNotifier<bool>(false);

  Documento? _documento; // null = novo
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    _documento = ModalRoute.of(context)?.settings.arguments as Documento?;
    _tituloController.text = _documento?.titulo ?? '';
    _textoController.text = _documento?.texto ?? '';
    _tipo.value = _documento?.tipo ?? 'txt';
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _textoController.dispose();
    _tipo.dispose();
    _modoLeitura.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_modoLeitura.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saia do modo leitura para salvar')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final titulo = _tituloController.text.trim();
    final texto = _textoController.text;

    if (_documento == null) {
      await widget.docs.criar(titulo: titulo, tipo: _tipo.value, texto: texto);
    } else {
      await widget.docs.atualizar(
        _documento!.copyWith(titulo: titulo, tipo: _tipo.value, texto: texto),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _documento == null ? 'Documento criado!' : 'Documento atualizado!'),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _excluir() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir documento'),
        content: Text('Deseja excluir "${_documento!.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    await widget.docs.excluir(_documento!.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Documento excluído')));
    Navigator.pop(context);
  }

  void _exportarPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${_tituloController.text}" exportado em PDF!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final novo = _documento == null;
    return Scaffold(
      appBar: AppBar(title: Text(novo ? 'Novo documento' : 'Editar documento')),
      body: ValueListenableBuilder<bool>(
        valueListenable: _modoLeitura,
        builder: (context, leitura, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _tituloController,
                  readOnly: leitura,
                  decoration: const InputDecoration(
                    labelText: 'Título do documento',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: validarTitulo,
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: _tipo,
                  builder: (context, tipo, _) {
                    return SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'txt',
                            label: Text('Texto'),
                            icon: Icon(Icons.description)),
                        ButtonSegment(
                            value: 'pdf',
                            label: Text('PDF'),
                            icon: Icon(Icons.picture_as_pdf)),
                        ButtonSegment(
                            value: 'nota',
                            label: Text('Nota'),
                            icon: Icon(Icons.sticky_note_2)),
                      ],
                      selected: {tipo},
                      onSelectionChanged: leitura
                          ? null
                          : (selecao) => _tipo.value = selecao.first,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _textoController,
                  readOnly: leitura,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    hintText: 'Digite ou edite seu documento aqui...',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _salvar,
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _exportarPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Exportar PDF'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _modoLeitura.value = !leitura,
                      icon: Icon(leitura ? Icons.edit : Icons.menu_book),
                      label: Text(leitura ? 'Modo Edição' : 'Modo Leitura'),
                    ),
                    if (!novo)
                      OutlinedButton.icon(
                        onPressed: _excluir,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Excluir'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const RodapeDesenvolvedor(),
    );
  }
}
