import 'package:flutter/material.dart';
import 'package:gms_project/screens/home.dart';
import 'package:gms_project/states/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  return runApp(MultiProvider(providers: [
    ChangeNotifierProvider.value(value: AppState(),)
  ],
    child: MyApp(),));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'uber clone',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Gms project'),
    );
  }
}

