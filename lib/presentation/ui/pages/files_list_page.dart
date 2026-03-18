import 'package:flutter/material.dart';
import 'package:fala_file/presentation/viewmodels/file_viewmodel.dart';
import 'package:provider/provider.dart';

class FilesListPage extends StatefulWidget {
  const FilesListPage({super.key});

  @override
  State<FilesListPage> createState() => _FilesListPageState();
}

class _FilesListPageState extends State<FilesListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FileViewModel>().loadFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus PDFs'),
      ),
      body: Consumer<FileViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.files.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.files.isEmpty) {
            return const Center(
              child: Text('Nenhum arquivo enviado ainda.'),
            );
          }

          return ListView.builder(
            itemCount: viewModel.files.length,
            itemBuilder: (context, index) {
              final file = viewModel.files[index];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(file.title),
                subtitle: Text(
                  'Enviado em: ${file.uploadDate.day}/${file.uploadDate.month}/${file.uploadDate.year}',
                ),
                onTap: () {
                  // TODO: Mostrar conteúdo do PDF extraído
                  _showContentDialog(context, file.title, file.content);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<FileViewModel>().pickAndUploadFile(),
        tooltip: 'Adicionar PDF',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showContentDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}
