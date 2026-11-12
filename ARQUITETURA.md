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
