import 'package:flutter/material.dart';

import '../models/documento.dart';
import '../utils/rodape_desenvolvedor.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/documentos_viewmodel.dart';

// VIEW: rota "/home" (cards de dados + lista de documentos do CRUD).
class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.auth, required this.docs});

  final AuthViewModel auth;
  final DocumentosViewModel docs;

  // ---------- Card 1: lê do shared_preferences ----------
  Future<void> _mostrarPreferencias(BuildContext context) async {
    final p = await auth.lerPreferenciasSalvas();
    if (!context.mounted) return;
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
  Future<void> _mostrarUsuarios(BuildContext context) async {
    final lista = await auth.listarUsuarios();
    if (!context.mounted) return;
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

  // ---------- DELETE com confirmação ----------
  Future<void> _confirmarExclusao(BuildContext context, Documento doc) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir documento'),
        content: Text('Deseja excluir "${doc.titulo}"?'),
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
    await docs.excluir(doc.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Documento excluído')));
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
        auth.usuarioLogado?.nome ??
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
            onPressed: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/');
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/editor'),
        icon: const Icon(Icons.add),
        label: const Text('Novo documento'),
      ),
      body: ListenableBuilder(
        listenable: docs,
        builder: (context, _) {
          final lista = docs.documentos;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              Text('Bem-vindo(a), $nome!',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              _cardInterativo(
                icone: Icons.settings,
                titulo: 'Preferências do Usuário',
                subtitulo: 'Toque para ver o que está no shared_preferences',
                onTap: () => _mostrarPreferencias(context),
              ),
              _cardInterativo(
                icone: Icons.storage,
                titulo: 'Usuários no Banco Local',
                subtitulo: 'Toque para listar os usuários cadastrados',
                onTap: () => _mostrarUsuarios(context),
              ),
              const SizedBox(height: 16),
              Text('Meus documentos (${lista.length})', style: estiloSecao),
              const SizedBox(height: 8),
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum documento. Toque em "Novo documento".'),
                ),
              for (final doc in lista)
                Card(
                  child: ListTile(
                    leading: Icon(_icone(doc.tipo), color: _cor(doc.tipo)),
                    title: Text(doc.titulo),
                    subtitle: Text('${doc.totalPalavras} palavras'),
                    trailing: IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmarExclusao(context, doc),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, '/editor', arguments: doc),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: const RodapeDesenvolvedor(),
    );
  }
}
