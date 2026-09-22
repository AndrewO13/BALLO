import 'dart:io';

bool isSocketConnectionError(Object error) => error is SocketException;
