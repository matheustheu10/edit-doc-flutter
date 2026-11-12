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
