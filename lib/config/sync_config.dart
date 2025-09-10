// lib/config/sync_config.dart

/// Configurações para o serviço de sincronização da base de dados
class SyncConfig {
  // ==========================================
  // CONFIGURAÇÕES DE TEMPO
  // ==========================================
  
  /// Intervalo entre sincronizações automáticas
  /// Padrão: 1 minuto
  /// Recomendado: Entre 30 segundos e 5 minutos
  static const Duration syncInterval = Duration(minutes: 1);
  
  /// Tempo de delay entre tentativas de sincronização após falha
  /// O delay aumenta progressivamente: tentativa * baseRetryDelay
  static const Duration baseRetryDelay = Duration(seconds: 2);
  
  /// Tempo máximo de espera para uma operação de sincronização
  static const Duration syncTimeout = Duration(seconds: 30);
  
  // ==========================================
  // CONFIGURAÇÕES DE RETRY
  // ==========================================
  
  /// Número máximo de tentativas em caso de falha
  /// Padrão: 3 tentativas
  static const int maxRetries = 3;
  
  /// Habilitar retry automático em caso de falha
  static const bool enableAutoRetry = true;
  
  // ==========================================
  // CONFIGURAÇÕES DE COMPORTAMENTO
  // ==========================================
  
  /// Iniciar sincronização automática ao abrir o app
  static const bool startSyncOnInit = true;
  
  /// Fazer sincronização silenciosa (sem logs)
  static const bool silentSync = false;
  
  /// Sincronizar automaticamente após operações do usuário
  /// Se true, sincroniza após cada operação de escrita
  /// Se false, aguarda o próximo ciclo automático
  static const bool syncAfterUserOperation = false;
  
  /// Mostrar notificação quando sincronização falhar
  static const bool showSyncErrorNotification = true;
  
  // ==========================================
  // CONFIGURAÇÕES DE UI
  // ==========================================
  
  /// Mostrar indicador de sincronização na UI
  static const bool showSyncIndicator = true;
  
  /// Mostrar tempo desde última sincronização
  static const bool showLastSyncTime = true;
  
  /// Habilitar pull-to-refresh para sincronização manual
  static const bool enablePullToRefresh = true;
  
  /// Mostrar botão de sincronização manual na AppBar
  static const bool showManualSyncButton = true;
  
  // ==========================================
  // CONFIGURAÇÕES DE CACHE
  // ==========================================
  
  /// Manter cache local dos dados
  static const bool enableLocalCache = true;
  
  /// Tamanho máximo do cache de operações pendentes
  static const int maxPendingOperations = 100;
  
  // ==========================================
  // CONFIGURAÇÕES DE DEBUG
  // ==========================================
  
  /// Habilitar modo debug com logs detalhados
  static const bool debugMode = true;
  
  /// Mostrar menu de debug na UI
  static const bool showDebugMenu = true;
  
  /// Logar todas as operações de sincronização
  static const bool logSyncOperations = true;
  
  // ==========================================
  // CONFIGURAÇÕES DE PERFORMANCE
  // ==========================================
  
  /// Número máximo de tarefas para processar por vez
  static const int batchSize = 50;
  
  /// Habilitar otimização de batching para múltiplas operações
  static const bool enableBatching = true;
  
  // ==========================================
  // MÉTODOS AUXILIARES
  // ==========================================
  
  /// Verifica se deve fazer log baseado nas configurações
  static bool shouldLog(String message) {
    if (silentSync && !debugMode) return false;
    if (!logSyncOperations && message.contains('sync')) return false;
    return true;
  }
  
  /// Calcula o delay para retry baseado no número da tentativa
  static Duration getRetryDelay(int attemptNumber) {
    return Duration(
      seconds: baseRetryDelay.inSeconds * attemptNumber
    );
  }
  
  /// Verifica se a sincronização automática está habilitada
  static bool get isAutoSyncEnabled => 
    startSyncOnInit && syncInterval.inSeconds > 0;
  
  /// Obtém a descrição do intervalo de sincronização
  static String get syncIntervalDescription {
    if (syncInterval.inDays > 0) {
      return '${syncInterval.inDays} dia(s)';
    } else if (syncInterval.inHours > 0) {
      return '${syncInterval.inHours} hora(s)';
    } else if (syncInterval.inMinutes > 0) {
      return '${syncInterval.inMinutes} minuto(s)';
    } else {
      return '${syncInterval.inSeconds} segundo(s)';
    }
  }
  
  /// Valida as configurações
  static bool validateConfig() {
    if (syncInterval.inSeconds < 10) {
      print('⚠️ Aviso: Intervalo de sincronização muito curto (< 10s)');
      return false;
    }
    
    if (maxRetries > 10) {
      print('⚠️ Aviso: Número de tentativas muito alto (> 10)');
      return false;
    }
    
    if (batchSize < 1) {
      print('❌ Erro: Tamanho do batch inválido (< 1)');
      return false;
    }
    
    return true;
  }
  
  /// Obtém um resumo das configurações atuais
  static Map<String, dynamic> getConfigSummary() {
    return {
      'syncInterval': syncIntervalDescription,
      'maxRetries': maxRetries,
      'autoRetry': enableAutoRetry,
      'startOnInit': startSyncOnInit,
      'silentMode': silentSync,
      'debugMode': debugMode,
      'batchSize': batchSize,
      'cacheEnabled': enableLocalCache,
      'uiIndicators': {
        'showSyncIndicator': showSyncIndicator,
        'showLastSyncTime': showLastSyncTime,
        'pullToRefresh': enablePullToRefresh,
        'manualSyncButton': showManualSyncButton,
      }
    };
  }
}

/// Classe para armazenar estatísticas de sincronização
class SyncStatistics {
  int successfulSyncs = 0;
  int failedSyncs = 0;
  int totalOperations = 0;
  DateTime? lastSuccessfulSync;
  DateTime? lastFailedSync;
  Duration totalSyncTime = Duration.zero;
  
  double get successRate => 
    totalOperations > 0 ? successfulSyncs / totalOperations : 0.0;
  
  Duration get averageSyncTime => 
    successfulSyncs > 0 
      ? Duration(milliseconds: totalSyncTime.inMilliseconds ~/ successfulSyncs)
      : Duration.zero;
  
  Map<String, dynamic> toJson() {
    return {
      'successful': successfulSyncs,
      'failed': failedSyncs,
      'total': totalOperations,
      'successRate': '${(successRate * 100).toStringAsFixed(1)}%',
      'lastSuccess': lastSuccessfulSync?.toIso8601String(),
      'lastFailure': lastFailedSync?.toIso8601String(),
      'averageSyncTime': '${averageSyncTime.inSeconds}s',
    };
  }
}
