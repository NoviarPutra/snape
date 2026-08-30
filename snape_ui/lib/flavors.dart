enum Flavor {
  dev,
  prod,
}

class F {
  static Flavor appFlavor = Flavor.dev;

  static String get name => appFlavor.name;

  static bool get isDev => appFlavor == Flavor.dev;
  static bool get isProd => appFlavor == Flavor.prod;

  static String get envFileName {
    switch (appFlavor) {
      case Flavor.dev:
        return '.env.dev';
      case Flavor.prod:
        return '.env.prod';
    }
  }

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'Snape Dev';
      case Flavor.prod:
        return 'Snape';
    }
  }
}
