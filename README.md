# Todo App César

Um aplicativo Flutter de lista de tarefas com sincronização automática e proteção contra conflitos.

## 🚀 Funcionalidades

### 📊 Sincronização Automática da Base de Dados
- **Atualização automática a cada minuto** - A base de dados é sincronizada automaticamente em intervalos regulares
- **Proteção contra conflitos** - Sistema inteligente que evita conflitos quando o usuário está inserindo ou editando dados
- **Fila de operações** - Operações pendentes são gerenciadas em filas para garantir execução ordenada
- **Indicadores visuais** - Mostra quando a sincronização está em andamento
- **Controle manual** - Opção de pausar/retomar a sincronização automática

### 🎯 Recursos Principais
- Criar, editar e deletar tarefas
- Tarefas recorrentes com múltiplas opções de intervalo
- Sistema de labels/etiquetas para organização
- Notificações para lembretes de tarefas
- Subtarefas aninhadas
- Filtros avançados (por data, labels, status)
- Tema claro/escuro
- Sincronização com Supabase

## 🛡️ Sistema de Proteção contra Conflitos

O `DatabaseSyncService` implementa um sistema robusto para evitar conflitos:

### Como funciona:
1. **Mutex de Operações**: Bloqueia sincronizações durante operações do usuário
2. **Filas Inteligentes**: Gerencia operações pendentes em filas separadas
3. **Wrapper de Proteção**: Todas as operações de escrita são protegidas automaticamente
4. **Retry Automático**: Tentativas automáticas em caso de falha (até 3x)

### Exemplo de uso:
```dart
// Operação protegida de salvamento
final savedTodo = await _syncService.saveTodoSafely(todo);

// Operação protegida de deleção
await _syncService.deleteTodoSafely(todoId);

// Forçar sincronização manual
await _syncService.forceSync();
```

## 📱 Interface de Usuário

### Indicadores de Status:
- **Ícone de sincronização no título**: Verde (sincronizado) ou Laranja (precisa sincronizar)
- **Barra de progresso**: Aparece durante a sincronização
- **Pull-to-refresh**: Arraste para baixo para sincronizar manualmente
- **Botão de refresh**: Na barra de ações para sincronização manual

### Menu Debug:
- Visualizar status completo da sincronização
- Pausar/retomar sincronização automática
- Ver filas pendentes
- Testar notificações
- Monitorar última sincronização

## 🔧 Configuração

### Intervalo de Sincronização
Por padrão, a sincronização ocorre a cada **1 minuto**. Para alterar:

```dart
// Em database_sync_service.dart
static const Duration _syncInterval = Duration(minutes: 1); // Altere aqui
```

### Número de Tentativas
Por padrão, tenta **3 vezes** antes de desistir:

```dart
static const int _maxRetries = 3; // Altere aqui
```

## 🏗️ Arquitetura

```
lib/
├── services/
│   ├── database_sync_service.dart  # Novo serviço de sincronização
│   ├── supabase_service.dart       # Acesso à base de dados
│   ├── notification_service.dart   # Gerenciamento de notificações
│   └── label_service.dart          # Gerenciamento de labels
├── screens/
│   └── todo_list_screen.dart       # Tela principal integrada
└── models/
    ├── todo_item.dart               # Modelo de tarefa
    └── label.dart                   # Modelo de label
```

## 🚦 Estados de Sincronização

### Estados possíveis:
1. **Idle** - Aguardando próxima sincronização
2. **Syncing** - Sincronização em andamento
3. **User Operating** - Operação do usuário em andamento (sincronização pausada)
4. **Error** - Erro na sincronização (com retry automático)

## 📋 Comandos Úteis

```bash
# Instalar dependências
flutter pub get

# Executar o app
flutter run

# Build para Android
flutter build apk --release

# Build para iOS
flutter build ios --release
```

## 🔍 Monitoramento

Para monitorar o status da sincronização:
1. Abra o menu debug (ícone de ciência na barra)
2. Veja o "Status de Sincronização"
3. Monitore filas pendentes e última sincronização

## ⚠️ Tratamento de Erros

O sistema trata automaticamente:
- Falhas de rede
- Timeouts
- Conflitos de concorrência
- Operações simultâneas
- Falhas de sincronização (com retry)

## 📱 Screenshots

### Status de Sincronização
- Indicador visual quando está sincronizando
- Ícone colorido mostrando estado da sincronização
- Tempo desde última sincronização

## 🤝 Contribuindo

1. Faça fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob licença MIT.

## 👤 Autor

César

## 🙏 Agradecimentos

- Flutter Team
- Supabase Team
- Comunidade Flutter
