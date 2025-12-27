enum StockResultStatus {
  success,
  productNotFound,
  noBatchesFound,
  marketMismatch, // Batches exist but for different markets (or null)
  insufficientStock, // Batches match market but stock is 0
  error,
}

class StockDeductionResult {
  final StockResultStatus status;
  final String message;

  StockDeductionResult({required this.status, required this.message});

  bool get isSuccess => status == StockResultStatus.success;
}
