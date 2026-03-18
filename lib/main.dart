import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fala_file/core/di/injection.dart' as di;
import 'package:fala_file/presentation/ui/pages/files_list_page.dart';
import 'package:fala_file/presentation/viewmodels/file_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<FileViewModel>()),
      ],
      child: MaterialApp(
        title: 'Fala File',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const FilesListPage(),
      ),
    );
  }
}
