# edit-doc-flutter

App Flutter com Login, Cadastro e Home (leitor/editor de documentos), organizado em **MVVM**.
Relatório de arquitetura: [ARQUITETURA.md](ARQUITETURA.md)

## Como rodar (GitHub Codespaces)
1. Abra o repositório em um Codespace.
2. No terminal: `flutter pub get`
3. Pressione **F5** (Rodar App Flutter - Web Preview).

## Estrutura
```
lib/
├── main.dart
├── models/ (usuario, documento, services/)
├── viewmodels/ (auth_viewmodel, documentos_viewmodel)
├── views/ (login_view, cadastro_view, home_view)
└── utils/ (validadores, rodape_desenvolvedor)
```

Desenvolvido por Matheus Vinícius Duarte Costa.
