import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

// Set by main.dart — called when all sessions expire and the user must re-login.
VoidCallback? onSessionExpired;
