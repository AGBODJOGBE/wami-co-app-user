import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../auth/current_session.dart';
import '../config/app_config.dart';

/// Signaux temps réel du back (Socket.io).
///
/// Un signal ne décrit pas l'état : il dit « relisez maintenant ». La source de données relit
/// alors la route HTTP, qui reste la seule à décrire la course. Si le WebSocket tombe,
/// l'interrogation régulière continue : l'écran ne dépend jamais de lui.
abstract interface class RealtimeSignals {
  /// `true` tant que la connexion est ouverte : l'interrogation régulière peut ralentir.
  bool get isConnected;

  /// Un signal à chaque changement de statut de la course [rideId].
  Stream<void> ride(String rideId);
}

/// Faux backend et tests : aucun signal, l'interrogation régulière fait tout.
class NoRealtimeSignals implements RealtimeSignals {
  const NoRealtimeSignals();

  @override
  bool get isConnected => false;

  @override
  Stream<void> ride(String rideId) => const Stream.empty();
}

/// Connexion Socket.io au back wami-co, ouverte tant qu'une course est suivie.
///
/// Le passager rejoint la salle `ride:{id}` (`ride:join`) ; le back y envoie les changements
/// de statut. La salle est rejointe à nouveau après chaque reconnexion.
class SocketIoRealtimeSignals implements RealtimeSignals {
  SocketIoRealtimeSignals(this._config, this._session);

  final AppConfig _config;
  final CurrentSession _session;

  /// Événements envoyés par le back dans la salle `ride:{id}`.
  static const rideEvents = [
    'ride:driver_assigned',
    'ride:driver_en_route',
    'ride:driver_arrived',
    'ride:started',
    'ride:paused',
    'ride:resumed',
    'ride:completed',
    'ride:cancelled',
    'ride:no_driver_found',
  ];

  final _rides = <String, StreamController<void>>{};
  io.Socket? _socket;
  String? _token;

  @override
  bool get isConnected => _socket?.connected ?? false;

  @override
  Stream<void> ride(String rideId) {
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        _rides[rideId] = controller;
        final socket = _open();
        if (socket.connected) socket.emit('ride:join', rideId);
      },
      onCancel: () {
        _rides.remove(rideId);
        if (_rides.isEmpty) _close();
      },
    );
    return controller.stream;
  }

  io.Socket _open() {
    final token = _session.token;
    final current = _socket;
    if (current != null && token == _token) return current;
    _close();
    _token = token;
    final socket = io.io(
      _config.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          // Une connexion neuve par jeton : le client réutiliserait sinon l'ancienne authentification.
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );
    socket.onConnect((_) {
      for (final id in _rides.keys) {
        socket.emit('ride:join', id);
      }
    });
    for (final event in rideEvents) {
      socket.on(event, (data) {
        final id = data is Map ? data['rideId'] : null;
        for (final entry in _rides.entries) {
          if (id == null || id == entry.key) entry.value.add(null);
        }
      });
    }
    _socket = socket..connect();
    return socket;
  }

  void _close() {
    _socket?.dispose();
    _socket = null;
    _token = null;
  }
}
