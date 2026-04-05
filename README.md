# Vida App

Aplicativo mobile em Flutter focado em organização da vida pessoal, visão geral das principais áreas da vida e apoio à rotina do usuário de forma visual, prática e progressiva.

O projeto combina acompanhamento de áreas da vida, check-in diário, organização do dia, finanças, tarefas da casa, voz, notificações e integrações com dados do dispositivo para formar um painel pessoal mais inteligente ao longo do tempo.

---

## Visão geral

O Vida App foi pensado para ajudar o usuário a enxergar como sua vida está em diferentes dimensões, sem depender apenas de listas soltas ou anotações manuais.

Hoje, o app gira em torno de alguns pilares principais:

- **Meu Dia**: visão diária com rotina, timeline e apoio à organização prática
- **Áreas da vida**: painel com avaliação de áreas e subáreas importantes
- **Finanças**: acompanhamento financeiro integrado ao restante do app
- **Perfil**: espaço pessoal do usuário
- **Hub de voz**: interação por comandos e ações rápidas
- **Dados inteligentes**: check-in diário, tarefas reais, finanças e algumas integrações automáticas alimentam o sistema

---

## O que o app já tem hoje

### 1. Autenticação e entrada no app
- Gate de autenticação com Firebase
- Fluxo de entrada dividido entre:
  - login
  - onboarding pessoal
  - onboarding de vida
  - home principal
- Preparação da sessão do usuário com migração de preferências antigas quando necessário

### 2. Navegação principal
Tela principal com navegação inferior para:

- **Meu Dia**
- **Áreas**
- **Finanças**
- **Perfil**

Além disso, existe um **botão central de voz** para abrir o hub de comandos.

### 3. Sistema de áreas da vida
O módulo de áreas é uma das partes centrais do app.

Ele já faz:

- armazenar avaliações por usuário
- calcular avaliações de forma dinâmica
- usar respostas do check-in diário
- integrar dados do módulo de finanças
- integrar sinais das tarefas da casa
- usar algumas informações automáticas do dispositivo e da saúde

Exemplos de sinais usados hoje:

- energia
- sono
- movimento
- alimentação
- hidratação
- humor
- estresse
- foco
- organização
- limpeza
- orçamento
- gastos
- renda
- uso de tela
- uso noturno
- uso de redes sociais

### 4. Check-in diário
O app já possui um serviço próprio de check-in diário, usado para alimentar áreas importantes do sistema.

Objetivo atual do check-in:

- registrar como o usuário está no dia
- gerar sinais reais para as áreas
- reduzir dependência de preenchimento manual isolado
- melhorar o cálculo do painel com base em histórico recente

### 5. Finanças
O projeto já tem um módulo real de finanças com estrutura separada em `data` e `presentation`.

Papel atual no app:

- registrar e ler transações
- alimentar a área de **Finanças & Material**
- servir como base para orçamento, entradas e saídas

### 6. Meu Dia, timeline e organização
O app já possui suporte a:

- timeline
- store de timeline
- repositório em Hive
- lista de compras
- tarefas da casa

Esses módulos ajudam a transformar o app em algo mais prático no dia a dia, e não apenas um painel visual.

### 7. Voz
Existe estrutura para:

- hub de voz
- roteamento de comandos
- integração com `speech_to_text`

A ideia é permitir ações mais rápidas e naturais dentro do app.

### 8. Uso do dispositivo (Android)
O app já possui integração Android para captar sinais de uso do aparelho, com foco em hábitos digitais.

Hoje ele já trabalha com:

- tempo total de tela
- tempo em redes sociais
- uso noturno
- solicitação/acesso de permissão de uso no Android
- persistência local desses sinais para uso no sistema de áreas

### 9. Saúde / Health Connect (Android)
O projeto já possui integração com **Health Connect** no Android.

Atualmente a sincronização cobre:

- última sessão de sono
- minutos de exercício nos últimos 7 dias
- quantidade de treinos nos últimos 7 dias

Esses dados são salvos localmente para serem usados no sistema do app.

### 10. Notificações locais
O app já inicializa um serviço de notificações locais e possui estrutura própria para testes e evolução do sistema.

---

## Tecnologias usadas

### Base do projeto
- Flutter
- Dart

### Estado, dados e persistência
- Hive
- SharedPreferences

### Serviços e integrações
- Firebase Core
- Firebase Auth
- flutter_local_notifications
- speech_to_text
- Health
- MethodChannel para integração Android de uso do dispositivo

### UI e utilidades
- flutter_svg
- package_info_plus
- flutter_localizations

---

## Estrutura atual do projeto

```txt
lib/
├── core/
│   └── onboarding/
├── data/
├── features/
│   ├── alerts/
│   ├── areas/
│   ├── auth/
│   ├── device/
│   ├── finance/
│   ├── goals/
│   ├── health_sync/
│   ├── home/
│   ├── home_tasks/
│   ├── life_journey/
│   ├── notifications/
│   ├── onboarding/
│   ├── shopping/
│   └── timeline/
├── presentation/
│   ├── app/
│   ├── voice/
│   └── widgets/
├── services/
│   ├── notifications/
│   └── voice/
└── main.dart
