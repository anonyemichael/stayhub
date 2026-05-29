// Stub for dart:html to allow compilation on mobile
class Window {
  void postMessage(dynamic message, String targetOrigin) {}
  Window? get parent => this;
  Stream<MessageEvent> get onMessage => const Stream.empty();
  Storage get localStorage => Storage();
  Location get location => Location();
}

class Storage {
  void clear() {}
}

class Location {
  void reload() {}
}

class MessageEvent {
  dynamic data;
}

final Window window = Window();
