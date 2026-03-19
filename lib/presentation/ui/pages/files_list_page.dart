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
                  icon: const Icon(
                    Icons.play_circle_fill,
                    size: 36,
                    color: Colors.blue,
                  ),
                  onPressed: () =>
                      _showPlayerModal(context, file.title, file.content),
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
          content: SingleChildScrollView(child: Text(content)),
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: _PlayerModalContent(title: title, content: content),
        );
      },
    );
  }
}

class _PlayerModalContent extends StatefulWidget {
  final String title;
  final String content;

  const _PlayerModalContent({required this.title, required this.content});

  @override
  State<_PlayerModalContent> createState() => _PlayerModalContentState();
}

class _PlayerModalContentState extends State<_PlayerModalContent> {
  double? _draggingValue;
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -1;
  final Map<int, GlobalKey> _itemKeys = {};
  late FileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<FileViewModel>();
    _viewModel.addListener(_onViewModelUpdate);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    final isPlaying =
        _viewModel.ttsState == TtsState.playing ||
        _viewModel.ttsState == TtsState.continued;

    if (isPlaying || _viewModel.ttsState == TtsState.paused) {
      _scrollToCurrent(_viewModel.currentChunkIndex);
    }
  }

  void _scrollToCurrent(int index) {
    if (index != _lastIndex && _scrollController.hasClients) {
      _lastIndex = index;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _itemKeys[index];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutQuad,
            alignment: 0.2, // Focus on the upper part
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FileViewModel>(
      builder: (context, viewModel, child) {
        final isPlaying =
            viewModel.ttsState == TtsState.playing ||
            viewModel.ttsState == TtsState.continued;
        final chunks = viewModel.chunks;

        return Column(
          children: [
            // Handle for the modal
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title and Progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbColor: Colors.blue,
                      activeTrackColor: Colors.blue,
                      inactiveTrackColor: Colors.blue.withOpacity(0.1),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value: (_draggingValue ?? viewModel.ttsProgress).clamp(
                        0.0,
                        1.0,
                      ),
                      onChanged: (value) =>
                          setState(() => _draggingValue = value),
                      onChangeEnd: (value) {
                        viewModel.seekTo(value, widget.content);
                        setState(() => _draggingValue = null);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Text Reader Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: chunks.isEmpty
                    ? const Center(
                        child: Text(
                          "Toque no play para começar",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    : _buildTextFlow(viewModel),
              ),
            ),

            // Controls
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: Icons.stop_rounded,
                    label: "Parar",
                    color: Colors.redAccent,
                    onTap: () => viewModel.stop(),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (isPlaying) {
                        viewModel.pause();
                      } else {
                        viewModel.speak(widget.content);
                      }
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _ControlButton(
                    icon: Icons.refresh_rounded,
                    label: "Reiniciar",
                    color: Colors.orange,
                    onTap: () => viewModel.seekTo(0, widget.content),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextFlow(FileViewModel viewModel) {
    final chunks = viewModel.chunks;
    final currentIndex = viewModel.currentChunkIndex;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        vertical: 100,
      ), // Padding to allow centering first/last items
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(chunks.length, (index) {
          final isPast = index < currentIndex;
          final isCurrent = index == currentIndex;

          // Ensure each index has a key for scroll tracking
          final key = _itemKeys.putIfAbsent(index, () => GlobalKey());

          return Padding(
            key: key,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isCurrent ? 1.0 : (isPast ? 0.3 : 0.6),
              child: isCurrent
                  ? _CurrentChunkHighlight(
                      text: chunks[index],
                      wordStart: viewModel.currentWordStart,
                      wordEnd: viewModel.currentWordEnd,
                    )
                  : Text(
                      chunks[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: isPast ? Colors.grey[600] : Colors.black87,
                        height: 1.4,
                        fontWeight: isPast
                            ? FontWeight.normal
                            : FontWeight.w400,
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }
}

class _CurrentChunkHighlight extends StatelessWidget {
  final String text;
  final int wordStart;
  final int wordEnd;

  const _CurrentChunkHighlight({
    required this.text,
    required this.wordStart,
    required this.wordEnd,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle = const TextStyle(
      fontSize: 14,
      height: 1.4,
      color: Colors.black,
      fontWeight: FontWeight.w600,
    );

    if (wordStart < 0 || wordEnd > text.length || wordStart >= wordEnd) {
      return Text(text, style: baseStyle);
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          // Cumulative highlight: everything read so far in this chunk
          TextSpan(
            text: text.substring(0, wordEnd),
            style: baseStyle.copyWith(
              backgroundColor: Colors.blue.withOpacity(0.12),
              color: Colors.blue[900],
              fontWeight: FontWeight.bold,
            ),
          ),
          // Remaining text in the chunk
          TextSpan(text: text.substring(wordEnd)),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
