# Instruções de Contexto - Projeto fala_file

## Perfil do Desenvolvedor
- Senior Flutter Developer com foco em Clean Architecture e SOLID.
- Preferência por código performático, tipado e testável.

## Domínio do Projeto
- Aplicativo Android em Flutter para conversão de Documentos em Voz (Text-to-Speech).
- Fluxo: Seleção de arquivo -> Extração de texto -> Persistência em SQLite -> Reprodução de áudio.

## Stack Técnica & Padrões
- **Linguagem:** Dart / Flutter.
- **Persistência:** SQLite (sqflite) - salvar texto e progresso de leitura (index/offset).
- **Voz:** flutter_tts (Configurado estritamente para pt-BR) e ElevenLabs.
- **Arquitetura:** Clean Architecture (Domain, Data, Presentation).
- **Padrões:** Repository Pattern, Factory, e Dependency Injection (get_it), adapter pattern, strategy pattern.

## Regras de Implementação para o Copilot
1. **Controle de Estado:** Implementar lógica de Iniciar, Pausar e Retomar mantendo o estado sincronizado com o banco de dados.
2. **Concorrência:** Sempre sugerir o uso de Isolates ou computação assíncrona para extração de textos pesados, evitando travamentos na UI.
3. **Idiomas:** Todas as saídas de voz e logs de erro devem considerar o idioma Português (pt-BR).
4. **Segurança:** Seguir práticas OWASP MASVS (ofuscação e proteção de dados locais no SQLite).