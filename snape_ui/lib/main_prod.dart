import 'flavors.dart';
import 'main.dart';

Future<void> main() async {
  await runSnapeApp(Flavor.prod);
}
