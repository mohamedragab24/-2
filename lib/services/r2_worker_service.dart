class R2WorkerService {
  static const String _defaultWorkerUrl = 'https://fahmny-r2.mohamedragabewiess.workers.dev';

  static String get workerUrl {
    const configured = String.fromEnvironment('R2_WORKER_URL');
    return configured.trim().isEmpty ? _defaultWorkerUrl : configured.trim();
  }

  static String keyToUrl(String key) {
    final clean = key.replaceFirst(RegExp(r'^/+'), '');
    final encoded = clean.split('/').map(Uri.encodeComponent).join('/');
    return '${workerUrl.replaceFirst(RegExp(r'/+$'), '')}/$encoded';
  }

  static String? tokenToUrl(String token) {
    final value = token.trim();
    if (value.startsWith('r2:')) {
      final parts = value.split(':');
      if (parts.length >= 4) return keyToUrl(parts.sublist(3).join(':'));
    }
    if (value.startsWith('r2cover:')) {
      final parts = value.split(':');
      if (parts.length >= 3) return keyToUrl(parts.sublist(2).join(':'));
    }
    return null;
  }
}
