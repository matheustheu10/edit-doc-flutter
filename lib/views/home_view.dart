import 'package:flutter/material.dart';

import '../models/documento.dart';
import '../utils/rodape_desenvolvedor.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/documentos_viewmodel.dart';

// VIEW: rota "/home" (cards de dados + leitor/editor de documentos).
class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.auth, required this.docs});

  final AuthViewModel auth;
  final DocumentosViewModel docs;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // Controllers são objetos de interface (guardam o texto digitado).
  final _tituloController = TextEditingController();
  final _textoController = TextEditingController();
  int? _idCarregado;

  @override
  void initState() {
    super.initState();
    widget.docs.addListener(_sincronizarEditor);
    _sincronizarEditor();
  }

  @override
  void dispose() {
    widget.docs.removeListener(_sincronizarEditor);
    _tituloController.dispose();
    _textoController.dispose();
    super.dispose();
  }

  /// Quando o ViewModel troca o documento selecionado, o editor é preenchido.
  void _sincronizarEditor() {
    final doc = widget.docs.selecionado;
    if (_idCarregado != doc.id) {
      _idCarregado = doc.id;
      _tituloController.text = doc.titulo;
      _textoController.text = doc.texto;
    }
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  void _guardarEditor() {
    widget.docs.salvarAtual(_tituloController.text, _textoController.text);
  }

  void _novoDocumento() {
    _guardarEditor();
    widget.docs.novo();
    _mostrarMensagem('Novo documento criado!');
  }

  void _abrirDocumento(int indice) {
    _guardarEditor();
    widget.docs.abrir(indice);
  }

  void _salvar() {
    if (widget.docs.modoLeitura) {
      _mostrarMensagem('Saia do modo leitura para salvar');
      return;
    }
    _guardarEditor();
    _mostrarMensagem('Documento salvo!');
  }

  void _exportarPdf() {
    _mostrarMensagem('"${_tituloController.text}" exportado em PDF!');
  }

  // ---------- Card 1: lê do shared_preferences ----------
  Future<void> _mostrarPreferencias() async {
    final p = await widget.auth.lerPreferenciasSalvas();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preferências do Usuário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tema escolhido: ${p.temaEscuro ? 'Escuro' : 'Claro'}'),
            const SizedBox(height: 8),
            Text('Tamanho da fonte: ${(p.fonte * 100).round()}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // ---------- Card 2: consulta o banco local ----------
  Future<void> _mostrarUsuarios() async {
    final lista = await widget.auth.listarUsuarios();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Usuários no Banco Local (${lista.length})',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum usuário cadastrado.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lista.length,
                    itemBuilder: (_, i) {
                      final u = lista[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${u.id}')),
                        title: Text(u.nome),
                        subtitle: Text(u.email),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icone(String tipo) {
    if (tipo == 'pdf') return Icons.picture_as_pdf;
    if (tipo == 'nota') return Icons.sticky_note_2;
    return Icons.description;
  }

  Color _cor(String tipo) {
    if (tipo == 'pdf') return Colors.red;
    if (tipo == 'nota') return Colors.orange;
    return Colors.blue;
  }

  Widget _itemDocumento(int indice, Documento doc) {
    final selecionado = indice == widget.docs.indiceSelecionado;
    return Card(
      child: ListTile(
        selected: selecionado,
        leading: Icon(_icone(doc.tipo), color: _cor(doc.tipo)),
        title: Text(doc.titulo),
        subtitle: Text('${doc.totalPalavras} palavras'),
        trailing: Icon(selecionado ? Icons.edit : Icons.chevron_right),
        onTap: () => _abrirDocumento(indice),
      ),
    );
  }

  Widget _cardInterativo({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Icon(icone, size: 36, color: Colors.indigo),
          title: Text(titulo),
          subtitle: Text(subtitulo),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = ModalRoute.of(context)?.settings.arguments as String? ??
        widget.auth.usuarioLogado?.nome ??
        'Usuário';
    final cor = Theme.of(context).colorScheme.primary;
    final estiloSecao =
        TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor e Editor de Documentos'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () {
              widget.auth.logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          )
        ],
      ),
      // A tela reconstrói sempre que o DocumentosViewModel chama notifyListeners
      body: ListenableBuilder(
        listenable: widget.docs,
        builder: (context, _) {
          final docs = widget.docs;
          final lista = docs.documentos;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text('Bem-vindo(a), $nome!',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              _cardInterativo(
                icone: Icons.settings,
                titulo: 'Preferências do Usuário',
                subtitulo: 'Toque para ver o que está no shared_preferences',
                onTap: _mostrarPreferencias,
              ),
              _cardInterativo(
                icone: Icons.storage,
                titulo: 'Usuários no Banco Local',
                subtitulo: 'Toque para listar os usuários cadastrados',
                onTap: _mostrarUsuarios,
              ),
              const SizedBox(height: 16),
              Text('Meus documentos (${lista.length})', style: estiloSecao),
              const SizedBox(height: 8),
              for (int i = 0; i < lista.length; i++) _itemDocumento(i, lista[i]),
              const SizedBox(height: 16),
              Text('Editor de texto', style: estiloSecao),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tituloController,
                readOnly: docs.modoLeitura,
                decoration:
                    const InputDecoration(labelText: 'Título do documento'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _textoController,
                readOnly: docs.modoLeitura,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Digite ou edite seu documento aqui...',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _novoDocumento,
                    icon: const Icon(Icons.add),
                    label: const Text('Novo Documento'),
                  ),
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
                    onPressed: docs.alternarModoLeitura,
                    icon: Icon(docs.modoLeitura ? Icons.edit : Icons.menu_book),
                    label: Text(docs.modoLeitura ? 'Modo Edição' : 'Modo Leitura'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const RodapeDesenvolvedor(),
    );
  }
}
