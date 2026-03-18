import 'package:get_it/get_it.dart';
import 'package:fala_file/core/database/database_helper.dart';
import 'package:fala_file/core/services/tts_service.dart';
import 'package:fala_file/data/datasources/file_local_datasource.dart';
import 'package:fala_file/data/datasources/pdf_datasource.dart';
import 'package:fala_file/data/repositories/file_repository_impl.dart';
import 'package:fala_file/domain/repositories/file_repository.dart';
import 'package:fala_file/domain/usecases/get_files_use_case.dart';
import 'package:fala_file/domain/usecases/upload_file_use_case.dart';
import 'package:fala_file/presentation/viewmodels/file_viewmodel.dart';

final sl = GetIt.instance;

Future<void> init() async {
  await TtsService.initTts();

  // Core
  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());
  sl.registerLazySingleton<TtsService>(() => TtsService());

  // Data Sources
  sl.registerLazySingleton<FileLocalDataSource>(
    () => FileLocalDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<PDFDataSource>(() => PDFDataSourceImpl());

  // Repositories
  sl.registerLazySingleton<FileRepository>(
    () => FileRepositoryImpl(localDataSource: sl(), pdfDataSource: sl()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetFilesUseCase(sl()));
  sl.registerLazySingleton(() => UploadFileUseCase(sl()));

  // ViewModel
  sl.registerFactory(
    () => FileViewModel(
      getFilesUseCase: sl(),
      uploadFileUseCase: sl(),
      ttsService: sl(),
    ),
  );
}
