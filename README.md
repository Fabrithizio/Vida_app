🌱 Vida App

Aplicativo mobile desenvolvido em Flutter com foco em gestão de vida pessoal, ajudando o usuário a acompanhar diferentes áreas da sua vida através de um sistema visual, interativo e gamificado.

📱 Sobre o projeto

O Vida App tem como objetivo ajudar o usuário a manter equilíbrio entre diferentes aspectos da vida, como saúde, mentalidade, rotina e desenvolvimento pessoal.

A interface gira em torno de um avatar central (representando o usuário) e áreas da vida ao redor, que mudam de estado conforme o tempo e as ações do usuário.

✨ Funcionalidades atuais
👤 Avatar do usuário
Representação visual central
Base para futura personalização (roupas, cores, etc.)
🧠 Áreas da vida
Sistema dividido em múltiplos aspectos (ex: saúde, mental, etc.)
Cada área possui subáreas (ex: check-ups, hábitos)
📊 Sistema de status por tempo
🟢 Verde → em dia
🟡 Amarelo → atenção
🔴 Vermelho → atrasado
📅 Controle manual de eventos
Usuário pode registrar quando realizou uma ação (ex: consulta médica)
Status é atualizado automaticamente com base no tempo
💡 Feedback inteligente
Cada status possui mensagens personalizadas:
Verde → "Continue assim"
Amarelo → "Fique atento"
Vermelho → "Já faz X dias desde..."
🎮 Sistema gamificado (em evolução)
Score geral
Barra de progresso (XP)
Evolução futura planejada
🛠️ Tecnologias utilizadas
Flutter
Dart
Firebase (Auth / Core)
Hive (armazenamento local)
Shared Preferences
Flutter SVG
Speech to Text
Local Notifications
📂 Estrutura do projeto
lib/
├── core/           # Configurações e utilidades globais
├── data/           # Modelos e fontes de dados
├── presentation/   # UI (telas, widgets, páginas)
├── services/       # Serviços (notificações, voz, etc.)
├── features/       # Funcionalidades organizadas por domínio
🚀 Como rodar o projeto
# Clonar o repositório
git clone https://github.com/Fabrithizio/Vida_app.git

# Entrar na pasta
cd Vida_app

# Instalar dependências
flutter pub get

# Rodar o app
flutter run
🎯 Objetivo do projeto

Criar um aplicativo que:

Ajude o usuário a cuidar de si mesmo
Traga clareza sobre sua vida atual
Use visual, feedback e gamificação para engajamento
🔮 Próximos passos
Customização completa do avatar
Sistema automático de datas (integrações futuras)
Melhorias visuais na UI
Sistema de níveis e progressão
Análises e insights do usuário
👨‍💻 Autor

Desenvolvido por Fabricio 🚀
