#!/bin/bash
set -e
echo "== Escrevendo os arquivos da Fase 2 (por cima da Fase 1) =="
rm -rf lib
mkdir -p "$(dirname "ARQUITETURA.md")"
cat > "ARQUITETURA.md" <<'FIM_DO_ARQUIVO'
# Relatório de Migração Arquitetural (Fase 1)

**Aluno:** Matheus Vinícius Duarte Costa
**Projeto:** edit-doc-flutter
**O que foi feito:** o app de 3 telas (Login, Cadastro e Home/Lista) que estava em um único arquivo no DartPad foi migrado para a arquitetura **MVVM** (Model-View-ViewModel). O comportamento é o mesmo de antes: navegação, validações, banco local em memória e preferências no `shared_preferences`.

## 1. Mapeamento de classes e widgets

| Elemento no DartPad (arquivo único) | Novo local | Camada |
|---|---|---|
| `validarNome`, `validarEmail`, `validarSenha` | `lib/utils/validadores.dart` | Utils |
| `RodapeDesenvolvedor` e `nomeDesenvolvedor` | `lib/utils/rodape_desenvolvedor.dart` | Utils |
| `Usuario` | `lib/models/usuario.dart` | Model |
| Documento (era um `Map<String, String>`) | `lib/models/documento.dart` (classe `Documento`) | Model |
| `BancoDadosLocal` | `lib/models/services/banco_local_service.dart` (`BancoLocalService`) | Model (service) |
| `PreferenciasService` | `lib/models/services/preferences_service.dart` (`PreferencesService`) | Model (service) |
| Regras de `_fazerLogin`/`_entrar` e `_cadastrar` | `lib/viewmodels/auth_viewmodel.dart` (`login`, `cadastrar`, `logout`) | ViewModel |
| `temaNotifier` e `fonteNotifier` (globais) | `AuthViewModel` (`temaEscuro`, `fonte`) | ViewModel |
| `_tema` e `_fonte` da tela de cadastro | `AuthViewModel` (`rascunhoTemaEscuro`, `rascunhoFonte`) | ViewModel |
| `_carregando` / `_salvando` | `AuthViewModel.carregando` | ViewModel |
| Lista `_documentos`, `_selecionado`, `_modoLeitura`, `_novoDocumento`, `_abrirDocumento`, `_guardarAtual`, `_alternarModoLeitura` | `lib/viewmodels/documentos_viewmodel.dart` (`DocumentosViewModel`) | ViewModel |
| `TelaLogin` | `lib/views/login_view.dart` (`LoginView`), rota `/` | View |
| `TelaCadastro` | `lib/views/cadastro_view.dart` (`CadastroView`), rota `/cadastro` | View |
| `TelaHome` (cards + editor) | `lib/views/home_view.dart` (`HomeView`), rota `/home` | View |
| `MeuApp`, tema (`ThemeData`) e rotas | `lib/main.dart` | Entrada |

## 2. Alterações de estrutura e imports

- **Um arquivo por classe, com nomes em `snake_case`.** Cada arquivo passou a importar o que usa, com **imports relativos** (por exemplo, `import '../viewmodels/auth_viewmodel.dart';`). A ordem das dependências é View → ViewModel → Model. As views não importam os services, e os models não importam nada de cima.
- **Construtores com injeção de dependência.** As views antes buscavam os dados em variáveis globais. Agora recebem o ViewModel pelo construtor (`LoginView(auth: auth)`, `HomeView(auth: auth, docs: docs)`) e, por isso, perderam o `const` na criação. O `AuthViewModel` recebe os services no construtor: `AuthViewModel(PreferencesService(), BancoLocalService())`.
- **Fim do singleton e das globais.** `BancoDadosLocal.instancia` e os `ValueNotifier` globais foram removidos. As instâncias únicas são criadas em `main()` e entregues a quem precisa, o que mantém uma única "tabela" de usuários para o app inteiro.
- **Visibilidade.** No Dart, o `_` torna o membro privado ao **arquivo**. Ao separar os arquivos, tudo que é usado por outro arquivo teve de perder o `_` (classes como `Usuario` e `Documento`, a constante `nomeDesenvolvedor`, as funções `validar...`). Os detalhes internos continuam privados (`_tabelaUsuarios`, `_proximoId`, `_LoginViewState`, e assim por diante). A tabela de usuários, por exemplo, só pode ser lida pelos métodos `query()` e `autenticar()`.
- **Models com serialização.** `Usuario` e `Documento` ganharam `toJson`/`fromJson` e `copyWith`, e o documento passou de `Map<String, String>` para uma classe tipada (com `totalPalavras`).
- **Rotas nomeadas** ficam todas no `main.dart`, e cada rota usa um `builder` que injeta os ViewModels:
  ```dart
  routes: {
    '/':         (context) => LoginView(auth: auth),
    '/cadastro': (context) => CadastroView(auth: auth),
    '/home':     (context) => HomeView(auth: auth, docs: docs),
  }
  ```
  O nome do usuário continua sendo passado para a Home por `arguments`, como no DartPad.

## 3. Mudanças no gerenciamento de estado

**`setState()` removidos das views: 12 ocorrências.**

| Tela | `setState` que existia | Para onde foi |
|---|---|---|
| Login | `_carregando = true/false` (2) | `AuthViewModel.carregando`, mudado por `login()` |
| Cadastro | `_salvando = true/false` (3) | `AuthViewModel.carregando`, mudado por `cadastrar()` |
| Cadastro | `_tema = v` nos 2 `RadioListTile` (2) | `AuthViewModel.escolherTema()` |
| Cadastro | `_fonte = v` no `Slider` (1) | `AuthViewModel.escolherFonte()` |
| Home | `_novoDocumento`, `_abrirDocumento`, `_salvar`, `_alternarModoLeitura` (4) | `DocumentosViewModel.novo()`, `abrir()`, `salvarAtual()`, `alternarModoLeitura()` |

Hoje nenhuma view chama `setState`.

**Variáveis de estado que passaram para os ViewModels**
- `AuthViewModel`: `temaEscuro`, `fonte`, `rascunhoTemaEscuro`, `rascunhoFonte`, `carregando`, `usuarioLogado`.
- `DocumentosViewModel`: lista de documentos, `indiceSelecionado` e `modoLeitura`.

Nas views ficaram apenas objetos de interface: `GlobalKey<FormState>` e `TextEditingController`.

**Como as telas reagem às mudanças**
1. Todo método do ViewModel que altera estado termina com `notifyListeners()`.
2. As views envolvem a parte que depende desse estado em um `ListenableBuilder(listenable: viewModel, builder: ...)`, que reconstrói só aquele trecho quando há notificação.
   - `main.dart`: `ListenableBuilder` sobre o `AuthViewModel` reconstrói o `MaterialApp` com o tema (claro ou escuro) e a escala de fonte.
   - Login: o botão "Entrar" escuta `carregando`.
   - Cadastro: radios, slider e botão escutam o `AuthViewModel`.
   - Home: o corpo escuta o `DocumentosViewModel` (lista, item selecionado e modo leitura).
3. A Home também registra `addListener` no `DocumentosViewModel` para preencher os `TextEditingController` quando outro documento é selecionado.
4. Fluxo de um clique: `onPressed` → método do ViewModel → muda o estado → `notifyListeners()` → `ListenableBuilder` reconstrói a interface.

---

# Fase 2: CRUD e persistência local

Com a base MVVM validada, a persistência passou a ser permanente. Como o preview roda na **web** (`web-server`), não foi usado SQLite nativo (`sqflite`). Foi aplicado o padrão **Service/Repository** com `shared_preferences` em duas frentes, ambas dentro de `lib/models/services/`.

| Arquivo | O que persiste | Como |
|---|---|---|
| `preferences_service.dart` | Tema (`bool`), tamanho da fonte (`double`) e dados da sessão (`String` de nome e e-mail) | Chave-valor simples: `setBool`, `setDouble`, `setString` |
| `documento_storage_service.dart` | Lista de documentos (CRUD completo) | A lista de `Documento` é serializada com `jsonEncode` (`toJson`) e gravada em uma única chave; na leitura, `jsonDecode` + `fromJson` reconstroem os objetos |
| `banco_local_service.dart` | Usuários (cadastro/login) e porta de entrada dos documentos | Usuários: mesma técnica de JSON, e eles sobrevivem ao recarregar a página. Documentos: `listarDocumentos`, `inserirDocumento`, `atualizarDocumento` e `excluirDocumento` repassam a chamada ao `DocumentoStorageService` |

## Novidades da fase 2
- **`views/editor_view.dart` (rota `/editor`)**: quarta tela, usada para criar e editar. Sem argumento, cria um documento; com um `Documento` como argumento, edita e permite excluir. Tem título (validado), tipo (texto, PDF ou nota), corpo, modo leitura e exportar PDF (simulado).
- **`DocumentosViewModel`**: deixou de guardar a lista em memória e passou a expor o CRUD por meio do `BancoLocalService`, que delega ao `DocumentoStorageService`: `carregar()` (Read), `criar()` (Create), `atualizar()` (Update) e `excluir()` (Delete). Cada operação grava e depois chama `notifyListeners()`, e a `HomeView` se atualiza sozinha por meio de `ListenableBuilder`.
- **`HomeView`**: virou `StatelessWidget`. Lista os documentos (toque abre o editor, ícone da lixeira exclui com confirmação) e tem o botão "Novo documento".
- **Sessão persistente**: `AuthViewModel.login()` grava a sessão, `restaurarSessao()` a lê ao abrir o app (o app já abre na Home) e `logout()` a apaga.
- **Tema persistente**: o `main()` agora é `async`, chama `WidgetsFlutterBinding.ensureInitialized()` e aplica as preferências salvas antes do `runApp`.

## Teste de persistência (F5 no preview)
1. Cadastre um usuário escolhendo o **Tema Escuro** e faça login.
2. Crie, edite e exclua documentos pelo botão "Novo documento" e pela lista.
3. Recarregue a página do preview (F5): o tema escuro, a sessão (o app abre direto na Home), os usuários e os documentos criados ou editados continuam lá.
FIM_DO_ARQUIVO
mkdir -p "$(dirname "README.md")"
cat > "README.md" <<'FIM_DO_ARQUIVO'
# edit-doc-flutter

App Flutter com Login, Cadastro, Home e Editor de documentos (CRUD), organizado em **MVVM** e com persistência local (`shared_preferences`).
Relatório de arquitetura: [ARQUITETURA.md](ARQUITETURA.md)

## Como rodar (GitHub Codespaces)
1. Abra o repositório em um Codespace.
2. No terminal: `flutter pub get`
3. Pressione **F5** (Rodar App Flutter - Web Preview).

## Estrutura
```
lib/
├── main.dart                         # ponto de entrada, tema reativo e rotas
├── models/
│   ├── usuario.dart
│   ├── documento.dart
│   └── services/
│       ├── preferences_service.dart        # tema e sessão (chave-valor)
│       ├── banco_local_service.dart        # usuários
│       └── documento_storage_service.dart  # CRUD de documentos (JSON)
├── viewmodels/
│   ├── auth_viewmodel.dart
│   └── documentos_viewmodel.dart
├── views/
│   ├── login_view.dart      # /
│   ├── cadastro_view.dart   # /cadastro
│   ├── home_view.dart       # /home
│   └── editor_view.dart     # /editor
└── utils/
    ├── validadores.dart
    └── rodape_desenvolvedor.dart
```

Desenvolvido por Matheus Vinícius Duarte Costa.
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/main.dart")"
cat > "lib/main.dart" <<'FIM_DO_ARQUIVO'
import 'package:flutter/material.dart';

import 'models/services/banco_local_service.dart';
import 'models/services/documento_storage_service.dart';
import 'models/services/preferences_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/documentos_viewmodel.dart';
import 'views/cadastro_view.dart';
import 'views/editor_view.dart';
import 'views/home_view.dart';
import 'views/login_view.dart';

Future<void> main() async {
  // Necessário porque o shared_preferences é usado antes do runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Os serviços e ViewModels são criados uma única vez e entregues às views.
  final banco = BancoLocalService(DocumentoStorageService());
  final auth = AuthViewModel(PreferencesService(), banco);
  final docs = DocumentosViewModel(banco);

  // Restaura o que foi salvo: tema/fonte, sessão do usuário e documentos.
  await auth.aplicarPreferenciasSalvas();
  await auth.restaurarSessao();
  await docs.carregar();

  runApp(MeuApp(auth: auth, docs: docs));
}

ThemeData _montarTema(Brightness brilho) {
  final claro = brilho == Brightness.light;
  return ThemeData(
    colorSchemeSeed: Colors.indigo,
    brightness: brilho,
    useMaterial3: true,
    scaffoldBackgroundColor: claro ? const Color(0xFFF5F6FA) : null,
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    ),
  );
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key, required this.auth, required this.docs});

  final AuthViewModel auth;
  final DocumentosViewModel docs;

  @override
  Widget build(BuildContext context) {
    // O app escuta o AuthViewModel: tema e fonte mudam quando ele notifica.
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Aula de Roteamento e Form',
          themeMode: auth.temaEscuro ? ThemeMode.dark : ThemeMode.light,
          theme: _montarTema(Brightness.light),
          darkTheme: _montarTema(Brightness.dark),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(auth.fonte)),
              child: child!,
            );
          },
          initialRoute: auth.usuarioLogado != null ? '/home' : '/',
          routes: {
            '/': (context) => LoginView(auth: auth),
            '/cadastro': (context) => CadastroView(auth: auth),
            '/home': (context) => HomeView(auth: auth, docs: docs),
            '/editor': (context) => EditorView(docs: docs),
          },
        );
      },
    );
  }
}
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/views/cadastro_view.dart")"
cat > "lib/views/cadastro_view.dart" <<'FIM_DO_ARQUIVO'
import 'package:flutter/material.dart';

import '../utils/rodape_desenvolvedor.dart';
import '../utils/validadores.dart';
import '../viewmodels/auth_viewmodel.dart';

// VIEW: rota "/cadastro".
class CadastroView extends StatefulWidget {
  const CadastroView({super.key, required this.auth});

  final AuthViewModel auth;

  @override
  State<CadastroView> createState() => _CadastroViewState();
}

class _CadastroViewState extends State<CadastroView> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    final inserido = await widget.auth.cadastrar(
      _nomeController.text,
      _emailController.text,
      _senhaController.text,
    );

    if (!mounted) return;
    if (!inserido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este e-mail já está cadastrado')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuário cadastrado com sucesso!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final estiloTitulo = Theme.of(context).textTheme.titleMedium;
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final auth = widget.auth;
        return Scaffold(
          appBar: AppBar(title: const Text('Cadastro de Usuário')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome Completo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: validarNome,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: validarEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senhaController,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: validarSenha,
                  ),
                  const SizedBox(height: 20),
                  Text('Tema do app', style: estiloTitulo),
                  RadioListTile<bool>(
                    title: const Text('Tema Claro'),
                    value: false,
                    groupValue: auth.rascunhoTemaEscuro,
                    onChanged: (v) => auth.escolherTema(v!),
                  ),
                  RadioListTile<bool>(
                    title: const Text('Tema Escuro'),
                    value: true,
                    groupValue: auth.rascunhoTemaEscuro,
                    onChanged: (v) => auth.escolherTema(v!),
                  ),
                  const SizedBox(height: 12),
                  Text('Tamanho da fonte: ${(auth.rascunhoFonte * 100).round()}%',
                      style: estiloTitulo),
                  Slider(
                    value: auth.rascunhoFonte,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    label: '${(auth.rascunhoFonte * 100).round()}%',
                    onChanged: auth.escolherFonte,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.carregando ? null : _cadastrar,
                      child: auth.carregando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cadastrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const RodapeDesenvolvedor(),
        );
      },
    );
  }
}
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/views/editor_view.dart")"
cat > "lib/views/editor_view.dart" <<'FIM_DO_ARQUIVO'
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
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/views/home_view.dart")"
cat > "lib/views/home_view.dart" <<'FIM_DO_ARQUIVO'
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
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/views/login_view.dart")"
cat > "lib/views/login_view.dart" <<'FIM_DO_ARQUIVO'
import 'package:flutter/material.dart';

import '../utils/rodape_desenvolvedor.dart';
import '../utils/validadores.dart';
import '../viewmodels/auth_viewmodel.dart';

// VIEW: rota "/" (apenas interface; a regra de negócio está no AuthViewModel).
class LoginView extends StatefulWidget {
  const LoginView({super.key, required this.auth});

  final AuthViewModel auth;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final usuario =
        await widget.auth.login(_emailController.text, _senhaController.text);

    if (!mounted) return;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail ou senha incorretos')),
      );
      return;
    }
    Navigator.pushReplacementNamed(context, '/home', arguments: usuario.nome);
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cor.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Icon(Icons.auto_stories, size: 52, color: cor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                  const Text('Leia e edite seus documentos'),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: validarEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senhaController,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: validarSenha,
                  ),
                  const SizedBox(height: 24),
                  // A view "escuta" o ViewModel: o botão reage a "carregando".
                  ListenableBuilder(
                    listenable: widget.auth,
                    builder: (context, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed:
                              widget.auth.carregando ? null : _fazerLogin,
                          child: widget.auth.carregando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Entrar'),
                        ),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/cadastro'),
                    child: const Text('Não tem uma conta? Cadastre-se'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const RodapeDesenvolvedor(),
    );
  }
}
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/viewmodels/auth_viewmodel.dart")"
cat > "lib/viewmodels/auth_viewmodel.dart" <<'FIM_DO_ARQUIVO'
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
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/viewmodels/documentos_viewmodel.dart")"
cat > "lib/viewmodels/documentos_viewmodel.dart" <<'FIM_DO_ARQUIVO'
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
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/models/documento.dart")"
cat > "lib/models/documento.dart" <<'FIM_DO_ARQUIVO'
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
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/models/usuario.dart")"
cat > "lib/models/usuario.dart" <<'FIM_DO_ARQUIVO'
// MODEL: entidade Usuário (linha da "tabela" usuarios).
class Usuario {
  final int id;
  final String nome;
  final String email;
  final String senha;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.senha,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'senha': senha,
      };

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nome: json['nome'] as String,
        email: json['email'] as String,
        senha: json['senha'] as String,
      );
}
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/models/services/banco_local_service.dart")"
cat > "lib/models/services/banco_local_service.dart" <<'FIM_DO_ARQUIVO'
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
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/models/services/documento_storage_service.dart")"
cat > "lib/models/services/documento_storage_service.dart" <<'FIM_DO_ARQUIVO'
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
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/models/services/preferences_service.dart")"
cat > "lib/models/services/preferences_service.dart" <<'FIM_DO_ARQUIVO'
import 'package:shared_preferences/shared_preferences.dart';

// MODEL (service): persistência chave-valor com shared_preferences.

typedef Preferencias = ({bool temaEscuro, double fonte});
typedef Sessao = ({String nome, String email});

class PreferencesService {
  static const String _chaveTemaEscuro = 'tema_escuro'; // bool
  static const String _chaveFonte = 'tamanho_fonte'; // double 0.8 a 1.4
  static const String _chaveSessaoNome = 'sessao_nome'; // String
  static const String _chaveSessaoEmail = 'sessao_email'; // String

  Future<void> salvarPreferencias({
    required bool temaEscuro,
    required double fonte,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveTemaEscuro, temaEscuro);
    await prefs.setDouble(_chaveFonte, fonte);
  }

  Future<Preferencias> carregarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      temaEscuro: prefs.getBool(_chaveTemaEscuro) ?? false,
      fonte: prefs.getDouble(_chaveFonte) ?? 1.0,
    );
  }

  Future<void> salvarSessao(String nome, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveSessaoNome, nome);
    await prefs.setString(_chaveSessaoEmail, email);
  }

  Future<Sessao?> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final nome = prefs.getString(_chaveSessaoNome);
    final email = prefs.getString(_chaveSessaoEmail);
    if (nome == null || email == null) return null;
    return (nome: nome, email: email);
  }

  Future<void> limparSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveSessaoNome);
    await prefs.remove(_chaveSessaoEmail);
  }
}
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/utils/rodape_desenvolvedor.dart")"
cat > "lib/utils/rodape_desenvolvedor.dart" <<'FIM_DO_ARQUIVO'
import 'package:flutter/material.dart';

// UTILS: widget auxiliar reutilizado no rodapé das telas.
const String nomeDesenvolvedor = 'Matheus Vinícius Duarte Costa';

class RodapeDesenvolvedor extends StatelessWidget {
  const RodapeDesenvolvedor({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.indigo,
      padding: const EdgeInsets.all(14),
      child: const Text(
        'Desenvolvido por $nomeDesenvolvedor',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
FIM_DO_ARQUIVO
mkdir -p "$(dirname "lib/utils/validadores.dart")"
cat > "lib/utils/validadores.dart" <<'FIM_DO_ARQUIVO'
// UTILS: validações de formulário reutilizadas pelas views.

String? validarNome(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Informe seu nome completo';
  }
  return null;
}

/// Validação estrita: precisa ter @ e o domínio deve terminar em .com ou .com.br
String? validarEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Informe o e-mail';
  }
  final email = value.trim().toLowerCase();

  if (!email.contains('@')) {
    return 'O e-mail deve conter o caractere @';
  }

  final partes = email.split('@');
  if (partes.length != 2 || partes[0].isEmpty || partes[1].isEmpty) {
    return 'Formato de e-mail inválido';
  }

  final dominio = partes[1];
  String base;
  if (dominio.endsWith('.com.br')) {
    base = dominio.substring(0, dominio.length - '.com.br'.length);
  } else if (dominio.endsWith('.com')) {
    base = dominio.substring(0, dominio.length - '.com'.length);
  } else {
    return 'O domínio deve terminar em .com ou .com.br';
  }
  if (base.isEmpty) {
    return 'Informe um domínio válido (ex.: gmail.com)';
  }
  return null;
}

String? validarSenha(String? value) {
  if (value == null || value.length < 6) {
    return 'A senha deve ter pelo menos 6 caracteres';
  }
  return null;
}

String? validarTitulo(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Informe o título do documento';
  }
  return null;
}
FIM_DO_ARQUIVO
echo ""; echo "PRONTO!"
