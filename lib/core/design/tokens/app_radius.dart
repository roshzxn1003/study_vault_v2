import 'package:flutter/material.dart';

/// Centralized corner radius system for Study Vault.
/// Defines a restrained geometric hierarchy without excessive roundness.
class AppRadius {
  AppRadius._();

  // Raw Radius Values
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 9999;

  // Radius Tokens
  static const Radius rNone = Radius.zero;
  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);

  // BorderRadius Tokens
  static const BorderRadius brNone = BorderRadius.zero;
  static const BorderRadius brXs = BorderRadius.all(rXs);
  static const BorderRadius brSm = BorderRadius.all(rSm);
  static const BorderRadius brMd = BorderRadius.all(rMd);
  static const BorderRadius brLg = BorderRadius.all(rLg);
  static const BorderRadius brXl = BorderRadius.all(rXl);
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(full));

  // Semantic Component BorderRadius
  static const BorderRadius button = brMd;
  static const BorderRadius field = brMd;
  static const BorderRadius card = brLg;
  static const BorderRadius chip = brSm;
  static const BorderRadius modal = brLg;
  static const BorderRadius bottomSheet = BorderRadius.vertical(top: rXl);
}
