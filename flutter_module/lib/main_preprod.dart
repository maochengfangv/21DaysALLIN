import 'env/app_env.dart';
import 'main.dart' as app;

void main() {
  AppEnv.overrideFlavor = AppFlavor.preprod;
  app.main();
}

