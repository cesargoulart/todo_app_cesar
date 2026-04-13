// lib/services/database_sync_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../models/label.dart';
import '../config/sync_config.dart';
import 'supabase_service.dart';
import 'label_service.dart';

/// Serviço para sincronização automática da base de dados
/// Atualiza a base de dados a cada minuto com proteção contra conflitos
class DatabaseSyncService {
  static final DatabaseSyncService _instance = DatabaseSyncService._internal();
  factory DatabaseSyncService() => _instance;
  DatabaseSyncService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final LabelService _labelService = LabelService();
  
  // Timer para atualizações automáticas
  Timer? _syncTimer;
  
  // Controle de concorrência
  bool _isSyncing = false;
  bool _isUserOperating = false;
  final List<Function> _pendingSyncQueue = [];
  final List<Function> _pendingUserOperations = [];
  
  // Callback para notificar a UI sobre atualizações
  Function(List<ToDoItem>)? onDataUpdated;
  Function(String)? onSyncError;
  Function(bool)? onSyncStatusChanged;
  
  // Estatísticas
  final SyncStatistics _statistics = SyncStatistics();
  
  // Estado atual dos dados
  List<ToDoItem> _currentTodos = [];
  DateTime? _lastSyncTime;
  bool _isInitialized = false;

  /// Inicializa o serviço de sincronização
  Future<void> initialize({
    Function(List<ToDoItem>)? onDataUpdated,
    Function(String)? onSyncError,
    Function(bool)? onSyncStatusChanged,
  }) async {
    if (_isInitialized) {
      print('📊 DatabaseSyncService já está inicializado');
      return;
    }

    this.onDataUpdated = onDataUpdated;
    this.onSyncError = onSyncError;
    this.onSyncStatusChanged = onSyncStatusChanged;
    
    _isInitialized = true;
    
    print('🚀 Inicializando DatabaseSyncService...');
    
    // Faz a primeira sincronização imediatamente
    await performSync();
    
    // Inicia o timer para sincronização automática se configurado
    if (SyncConfig.startSyncOnInit) {
      startAutoSync();
    }
  }

  /// Inicia a sincronização automática
  void startAutoSync() {
    if (!SyncConfig.isAutoSyncEnabled) {
      print('⚠️ Sincronização automática desabilitada nas configurações');
      return;
    }
    
    stopAutoSync(); // Para qualquer timer existente
    
    _syncTimer = Timer.periodic(SyncConfig.syncInterval, (_) {
      if (!_isUserOperating) {
        performSync(silent: SyncConfig.silentSync);
      } else {
        if (SyncConfig.shouldLog('sync')) {
          print('⏳ Sincronização adiada - operação do usuário em andamento');
        }
        _pendingSyncQueue.add(() => performSync(silent: SyncConfig.silentSync));
      }
    });
    
    if (SyncConfig.shouldLog('sync')) {
      print('⏰ Sincronização automática iniciada (intervalo: ${SyncConfig.syncIntervalDescription})');
    }
  }

  /// Para a sincronização automática
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('⏹️ Sincronização automática parada');
  }

  /// Realiza uma sincronização com a base de dados
  Future<void> performSync({bool silent = false}) async {
    // Evita sincronizações simultâneas
    if (_isSyncing) {
      print('🔄 Sincronização já em andamento, pulando...');
      return;
    }

    // Se o usuário estiver operando, adia a sincronização
    if (_isUserOperating) {
      print('👤 Usuário está operando, adiando sincronização...');
      _pendingSyncQueue.add(() => performSync(silent: silent));
      return;
    }

    _isSyncing = true;
    onSyncStatusChanged?.call(true);
    
    final startTime = DateTime.now();
    
    if (!silent && SyncConfig.shouldLog('sync')) {
      print('🔄 Iniciando sincronização da base de dados...');
    }

    int retryCount = 0;
    bool success = false;

    while (retryCount < SyncConfig.maxRetries && !success) {
      try {
        // Busca os dados atualizados
        final todos = await _supabaseService.loadTodos();
        
        // Carrega labels para cada todo
        for (ToDoItem todo in todos) {
          if (todo.id != null) {
            todo.labels = await _labelService.getLabelsForTask(todo.id!);
          }
        }
        
        _currentTodos = todos;
        _lastSyncTime = DateTime.now();
        
        // Atualiza estatísticas
        _statistics.successfulSyncs++;
        _statistics.totalOperations++;
        _statistics.lastSuccessfulSync = _lastSyncTime;
        _statistics.totalSyncTime += DateTime.now().difference(startTime);
        
        // Notifica a UI sobre os novos dados
        onDataUpdated?.call(todos);
        
        success = true;
        
        if (!silent && SyncConfig.shouldLog('sync')) {
          print('✅ Sincronização concluída com sucesso! ${todos.length} tarefas carregadas');
          print('📅 Última sincronização: ${_lastSyncTime?.toLocal()}');
        }
        
      } catch (e) {
        retryCount++;
        _statistics.failedSyncs++;
        _statistics.totalOperations++;
        _statistics.lastFailedSync = DateTime.now();
        
        if (SyncConfig.shouldLog('sync')) {
          print('❌ Erro na sincronização (tentativa $retryCount/${SyncConfig.maxRetries}): $e');
        }
        
        if (retryCount < SyncConfig.maxRetries && SyncConfig.enableAutoRetry) {
          // Espera progressivamente mais tempo antes de tentar novamente
          await Future.delayed(SyncConfig.getRetryDelay(retryCount));
        } else {
          if (SyncConfig.shouldLog('sync')) {
            print('❌ Falha na sincronização após ${SyncConfig.maxRetries} tentativas');
          }
          if (SyncConfig.showSyncErrorNotification) {
            onSyncError?.call('Erro ao sincronizar: $e');
          }
        }
      }
    }

    _isSyncing = false;
    onSyncStatusChanged?.call(false);
    
    // Processa operações pendentes do usuário
    _processPendingUserOperations();
  }

  /// Marca o início de uma operação do usuário
  void beginUserOperation() {
    _isUserOperating = true;
    if (SyncConfig.debugMode) {
      print('👤 Operação do usuário iniciada - sincronização pausada');
    }
  }

  /// Marca o fim de uma operação do usuário
  void endUserOperation() {
    _isUserOperating = false;
    if (SyncConfig.debugMode) {
      print('👤 Operação do usuário finalizada');
    }
    
    // Sincroniza após operação se configurado
    if (SyncConfig.syncAfterUserOperation) {
      performSync(silent: true);
    }
    
    // Processa sincronizações pendentes
    _processPendingSyncQueue();
  }

  /// Wrapper para operações do usuário com proteção
  Future<T> wrapUserOperation<T>(Future<T> Function() operation) async {
    beginUserOperation();
    try {
      final result = await operation();
      return result;
    } finally {
      endUserOperation();
    }
  }

  /// Salva um todo com proteção contra conflitos
  Future<ToDoItem> saveTodoSafely(ToDoItem todo) async {
    return await wrapUserOperation(() async {
      final savedTodo = await _supabaseService.saveTodo(todo);

      if (savedTodo.parentId != null) {
        // It's a subtask — add it to its parent in the cache, not as top-level
        final parentIndex =
            _currentTodos.indexWhere((t) => t.id == savedTodo.parentId);
        if (parentIndex != -1) {
          final parent = _currentTodos[parentIndex];
          final subtaskIndex =
              parent.subtasks.indexWhere((s) => s.id == savedTodo.id);
          if (subtaskIndex != -1) {
            parent.subtasks[subtaskIndex] = savedTodo;
          } else {
            parent.subtasks.add(savedTodo);
          }
        }
      } else {
        // It's a top-level task — update or add in the cache
        final index = _currentTodos.indexWhere((t) => t.id == savedTodo.id);
        if (index != -1) {
          // Preserve in-memory subtasks that may not have synced yet
          savedTodo.subtasks = _currentTodos[index].subtasks;
          _currentTodos[index] = savedTodo;
        } else {
          _currentTodos.add(savedTodo);
        }
      }

      // Notifica a UI
      onDataUpdated?.call(_currentTodos);

      return savedTodo;
    });
  }

  /// Salva múltiplos todos com proteção
  Future<List<ToDoItem>> saveTodosSafely(List<ToDoItem> todos) async {
    return await wrapUserOperation(() async {
      final savedTodos = await _supabaseService.saveTodos(todos);
      
      // Atualiza o cache local
      for (final savedTodo in savedTodos) {
        final index = _currentTodos.indexWhere((t) => t.id == savedTodo.id);
        if (index != -1) {
          _currentTodos[index] = savedTodo;
        } else {
          _currentTodos.add(savedTodo);
        }
      }
      
      // Notifica a UI
      onDataUpdated?.call(_currentTodos);
      
      return savedTodos;
    });
  }

  /// Deleta um todo com proteção
  Future<void> deleteTodoSafely(String id) async {
    await wrapUserOperation(() async {
      await _supabaseService.deleteTodo(id);
      
      // Remove do cache local
      _currentTodos.removeWhere((t) => t.id == id);
      
      // Notifica a UI
      onDataUpdated?.call(_currentTodos);
    });
  }

  /// Atualiza o status de um todo com proteção
  Future<void> updateTodoStatusSafely(String id, bool isDone) async {
    await wrapUserOperation(() async {
      await _supabaseService.updateTodoStatus(id, isDone);
      
      // Atualiza o cache local
      final index = _currentTodos.indexWhere((t) => t.id == id);
      if (index != -1) {
        _currentTodos[index].isDone = isDone;
      }
      
      // Notifica a UI
      onDataUpdated?.call(_currentTodos);
    });
  }

  /// Força uma sincronização manual
  Future<void> forceSync() async {
    if (SyncConfig.shouldLog('sync')) {
      print('🔄 Sincronização manual solicitada');
    }
    await performSync(silent: false);
  }

  /// Processa a fila de sincronizações pendentes
  void _processPendingSyncQueue() {
    if (_pendingSyncQueue.isNotEmpty && !_isUserOperating) {
      // Limita o tamanho da fila
      if (_pendingSyncQueue.length > SyncConfig.maxPendingOperations) {
        _pendingSyncQueue.removeRange(0, _pendingSyncQueue.length - SyncConfig.maxPendingOperations);
      }
      
      if (SyncConfig.debugMode) {
        print('📋 Processando ${_pendingSyncQueue.length} sincronizações pendentes');
      }
      final operation = _pendingSyncQueue.removeAt(0);
      operation();
    }
  }

  /// Processa operações pendentes do usuário
  void _processPendingUserOperations() {
    if (_pendingUserOperations.isNotEmpty && !_isSyncing) {
      // Limita o tamanho da fila
      if (_pendingUserOperations.length > SyncConfig.maxPendingOperations) {
        _pendingUserOperations.removeRange(0, _pendingUserOperations.length - SyncConfig.maxPendingOperations);
      }
      
      if (SyncConfig.debugMode) {
        print('📋 Processando ${_pendingUserOperations.length} operações do usuário pendentes');
      }
      final operation = _pendingUserOperations.removeAt(0);
      operation();
    }
  }

  /// Obtém o status atual do serviço
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isSyncing': _isSyncing,
      'isUserOperating': _isUserOperating,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'currentTodosCount': _currentTodos.length,
      'pendingSyncQueue': _pendingSyncQueue.length,
      'pendingUserOperations': _pendingUserOperations.length,
      'autoSyncActive': _syncTimer != null,
      'statistics': _statistics.toJson(),
      'config': SyncConfig.getConfigSummary(),
    };
  }

  /// Obtém os todos atualmente em cache
  List<ToDoItem> getCachedTodos() => List.from(_currentTodos);

  /// Limpa o cache e para a sincronização
  void dispose() {
    stopAutoSync();
    _currentTodos.clear();
    _pendingSyncQueue.clear();
    _pendingUserOperations.clear();
    _isInitialized = false;
    onDataUpdated = null;
    onSyncError = null;
    onSyncStatusChanged = null;
  }

  /// Verifica se o serviço está pronto
  bool get isReady => _isInitialized && !_isSyncing;

  /// Obtém o tempo desde a última sincronização
  Duration? get timeSinceLastSync {
    if (_lastSyncTime == null) return null;
    return DateTime.now().difference(_lastSyncTime!);
  }

  /// Verifica se precisa sincronizar (útil para decidir se deve fazer sync manual)
  bool get needsSync {
    if (_lastSyncTime == null) return true;
    return timeSinceLastSync!.inMinutes >= SyncConfig.syncInterval.inMinutes;
  }
  
  /// Obtém as estatísticas de sincronização
  SyncStatistics get statistics => _statistics;
}
