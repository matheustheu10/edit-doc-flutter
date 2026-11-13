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
