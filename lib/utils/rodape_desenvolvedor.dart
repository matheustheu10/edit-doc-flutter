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
