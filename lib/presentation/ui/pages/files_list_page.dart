import 'package:flutter/material.dart';
import 'package:fala_file/presentation/viewmodels/file_viewmodel.dart';
import 'package:fala_file/core/services/tts_service.dart';
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
        title: const Text('Fala File - Leitor de PDF'),
        actions: [
          Consumer<FileViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.ttsState == TtsState.playing || 
                  viewModel.ttsState == TtsState.continued ||
                  viewModel.ttsState == TtsState.paused) {
                return IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () => viewModel.stop(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<FileViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.files.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.files.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Nenhum arquivo enviado ainda.\nToque no + para adicionar um PDF.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: viewModel.files.length,
            itemBuilder: (context, index) {
              final file = viewModel.files[index];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(file.title),
                subtitle: Text(
                  'Enviado em: ${file.uploadDate.day}/${file.uploadDate.month}/${file.uploadDate.year}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.play_circle_fill, size: 36, color: Colors.blue),
                  onPressed: () => _showPlayerModal(context, file.title, file.content),
                ),
                onTap: () {
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

  void _showPlayerModal(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Consumer<FileViewModel>(
                builder: (context, viewModel, child) {
                  final isPlaying = viewModel.ttsState == TtsState.playing || 
                                  viewModel.ttsState == TtsState.continued;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.stop, size: 48),
                        onPressed: () {
                          viewModel.stop();
                        },
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          size: 64,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            viewModel.pause();
                          } else {
                            viewModel.speak(content);
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                "Lendo em Português (Brasil)",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
