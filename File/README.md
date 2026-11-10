Future<List<KittingCard>> createKittingCard({
    PrinterDevice? printer,
    bool isPreview = true,
    required List<KittingDetail> kittingModels,
  }) async {
    return launch(() async {
      // Kiểm tra user có phải PMD không
      final userId = getIt<StorageManager>().get<String>(StorageKeys.id) ?? '';
      final isPMD = userId.toUpperCase().endsWith('PMD');
      
      if (!isPreview && !isPMD) {   // ← thêm !isPMD
        if (printer == null) {
          throw ValidationError(type: ValidationErrorType.connectPrinterError);
        }
        await checkConnectPrint(printerDevice: printer);
      }
      
      // ... (giữ nguyên phần còn lại)
      
      if (!isPreview) {
        if (!isPMD) {               // ← thêm !isPMD
          if (printer == null) {
            throw ValidationError(type: ValidationErrorType.connectPrinterError);
          }
          await printKittingCard(kittingCards: response, printerDevice: printer);
        }
        commands.clear();
        emit(state.copyWith(
          receivingCards: [],
          receivingCardItems: [],
          totalQuantityBarcode: 0,
          material: '',
        ));
      }
