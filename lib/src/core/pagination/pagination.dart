import 'dart:async';

/// Sayfalama durumu
enum PaginationStatus {
  /// Başlangıç durumu
  initial,

  /// Yükleniyor
  loading,

  /// Daha fazla yükleniyor
  loadingMore,

  /// Yüklendi
  loaded,

  /// Hata
  error,

  /// Veri yok
  empty,
}

/// Sayfalama bilgisi
class PaginationInfo {
  /// Mevcut sayfa
  final int currentPage;

  /// Sayfa başına öğe sayısı
  final int pageSize;

  /// Toplam öğe sayısı
  final int? totalItems;

  /// Toplam sayfa sayısı
  int? get totalPages =>
      totalItems != null ? (totalItems! / pageSize).ceil() : null;

  /// Daha fazla sayfa var mı
  final bool hasMore;

  /// Son yüklenme zamanı
  final DateTime? lastLoadedAt;

  const PaginationInfo({
    this.currentPage = 1,
    this.pageSize = 20,
    this.totalItems,
    this.hasMore = true,
    this.lastLoadedAt,
  });

  /// İlk sayfa mı
  bool get isFirstPage => currentPage == 1;

  /// Son sayfa mı
  bool get isLastPage => !hasMore;

  /// Offset hesapla
  int get offset => (currentPage - 1) * pageSize;

  /// Sonraki sayfa bilgisi
  PaginationInfo nextPage() {
    return PaginationInfo(
      currentPage: currentPage + 1,
      pageSize: pageSize,
      totalItems: totalItems,
      hasMore: hasMore,
      lastLoadedAt: lastLoadedAt,
    );
  }

  /// Önceki sayfa bilgisi
  PaginationInfo previousPage() {
    return PaginationInfo(
      currentPage: currentPage > 1 ? currentPage - 1 : 1,
      pageSize: pageSize,
      totalItems: totalItems,
      hasMore: true,
      lastLoadedAt: lastLoadedAt,
    );
  }

  /// Yeni veriyle güncelle
  PaginationInfo copyWith({
    int? currentPage,
    int? pageSize,
    int? totalItems,
    bool? hasMore,
    DateTime? lastLoadedAt,
  }) {
    return PaginationInfo(
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalItems: totalItems ?? this.totalItems,
      hasMore: hasMore ?? this.hasMore,
      lastLoadedAt: lastLoadedAt ?? this.lastLoadedAt,
    );
  }

  /// Sıfırla
  PaginationInfo reset() {
    return PaginationInfo(
      currentPage: 1,
      pageSize: pageSize,
      totalItems: null,
      hasMore: true,
      lastLoadedAt: null,
    );
  }

  @override
  String toString() =>
      'PaginationInfo(page: $currentPage, size: $pageSize, total: $totalItems, hasMore: $hasMore)';
}

/// Sayfalanmış liste
class PaginatedList<T> {
  /// Öğeler
  final List<T> items;

  /// Sayfalama bilgisi
  final PaginationInfo pagination;

  /// Durum
  final PaginationStatus status;

  /// Hata mesajı
  final String? error;

  const PaginatedList({
    required this.items,
    required this.pagination,
    this.status = PaginationStatus.initial,
    this.error,
  });

  /// Boş liste
  factory PaginatedList.empty({int pageSize = 20}) {
    return PaginatedList(
      items: [],
      pagination: PaginationInfo(pageSize: pageSize, hasMore: false),
      status: PaginationStatus.empty,
    );
  }

  /// Loading durumu
  factory PaginatedList.loading({int pageSize = 20}) {
    return PaginatedList(
      items: [],
      pagination: PaginationInfo(pageSize: pageSize),
      status: PaginationStatus.loading,
    );
  }

  /// Hata durumu
  factory PaginatedList.error(String error, {int pageSize = 20}) {
    return PaginatedList(
      items: [],
      pagination: PaginationInfo(pageSize: pageSize),
      status: PaginationStatus.error,
      error: error,
    );
  }

  /// İlk veri yüklendi
  factory PaginatedList.loaded({
    required List<T> items,
    required int pageSize,
    int? totalItems,
    bool hasMore = true,
  }) {
    return PaginatedList(
      items: items,
      pagination: PaginationInfo(
        currentPage: 1,
        pageSize: pageSize,
        totalItems: totalItems,
        hasMore: hasMore,
        lastLoadedAt: DateTime.now(),
      ),
      status: items.isEmpty ? PaginationStatus.empty : PaginationStatus.loaded,
    );
  }

  /// Öğe sayısı
  int get length => items.length;

  /// Boş mu
  bool get isEmpty => items.isEmpty;

  /// Dolu mu
  bool get isNotEmpty => items.isNotEmpty;

  /// Yükleniyor mu
  bool get isLoading =>
      status == PaginationStatus.loading || status == PaginationStatus.loadingMore;

  /// Daha fazla yükleniyor mu
  bool get isLoadingMore => status == PaginationStatus.loadingMore;

  /// Hata var mı
  bool get hasError => status == PaginationStatus.error;

  /// Daha fazla yüklenebilir mi
  bool get canLoadMore => pagination.hasMore && !isLoading;

  /// Yenileniyor mu (ilk sayfa yükleniyor ve mevcut veri var)
  bool get isRefreshing => status == PaginationStatus.loading && isNotEmpty;

  /// Daha fazla veri ekle
  PaginatedList<T> addItems(
    List<T> newItems, {
    bool hasMore = true,
    int? totalItems,
  }) {
    return PaginatedList(
      items: [...items, ...newItems],
      pagination: pagination.copyWith(
        currentPage: pagination.currentPage + 1,
        hasMore: hasMore,
        totalItems: totalItems,
        lastLoadedAt: DateTime.now(),
      ),
      status: PaginationStatus.loaded,
    );
  }

  /// Listeyi yenile
  PaginatedList<T> refresh(
    List<T> newItems, {
    bool hasMore = true,
    int? totalItems,
  }) {
    return PaginatedList(
      items: newItems,
      pagination: PaginationInfo(
        currentPage: 1,
        pageSize: pagination.pageSize,
        totalItems: totalItems,
        hasMore: hasMore,
        lastLoadedAt: DateTime.now(),
      ),
      status: newItems.isEmpty ? PaginationStatus.empty : PaginationStatus.loaded,
    );
  }

  /// Yükleme durumuna geç
  PaginatedList<T> toLoading() {
    return PaginatedList(
      items: items,
      pagination: pagination,
      status: items.isEmpty ? PaginationStatus.loading : PaginationStatus.loadingMore,
    );
  }

  /// Hata durumuna geç
  PaginatedList<T> toError(String error) {
    return PaginatedList(
      items: items,
      pagination: pagination,
      status: PaginationStatus.error,
      error: error,
    );
  }

  /// Öğe güncelle
  PaginatedList<T> updateItem(int index, T item) {
    if (index < 0 || index >= items.length) return this;

    final newItems = List<T>.from(items);
    newItems[index] = item;

    return PaginatedList(
      items: newItems,
      pagination: pagination,
      status: status,
    );
  }

  /// Öğe sil
  PaginatedList<T> removeItem(int index) {
    if (index < 0 || index >= items.length) return this;

    final newItems = List<T>.from(items);
    newItems.removeAt(index);

    return PaginatedList(
      items: newItems,
      pagination: pagination.copyWith(
        totalItems: pagination.totalItems != null ? pagination.totalItems! - 1 : null,
      ),
      status: newItems.isEmpty ? PaginationStatus.empty : status,
    );
  }

  /// Öğe ekle (başa)
  PaginatedList<T> prependItem(T item) {
    return PaginatedList(
      items: [item, ...items],
      pagination: pagination.copyWith(
        totalItems: pagination.totalItems != null ? pagination.totalItems! + 1 : null,
      ),
      status: PaginationStatus.loaded,
    );
  }

  /// Öğe ekle (sona)
  PaginatedList<T> appendItem(T item) {
    return PaginatedList(
      items: [...items, item],
      pagination: pagination.copyWith(
        totalItems: pagination.totalItems != null ? pagination.totalItems! + 1 : null,
      ),
      status: PaginationStatus.loaded,
    );
  }

  /// Where ile filtrele
  PaginatedList<T> where(bool Function(T) test) {
    return PaginatedList(
      items: items.where(test).toList(),
      pagination: pagination,
      status: status,
    );
  }

  /// Map ile dönüştür
  PaginatedList<R> map<R>(R Function(T) convert) {
    return PaginatedList<R>(
      items: items.map(convert).toList(),
      pagination: pagination,
      status: status,
      error: error,
    );
  }

  @override
  String toString() =>
      'PaginatedList(items: ${items.length}, status: $status, pagination: $pagination)';
}

/// Sayfalama yöneticisi
class PaginationController<T> {
  /// Sayfalama bilgisi
  PaginationInfo _pagination;

  /// Veri çekme fonksiyonu
  final Future<List<T>> Function(int page, int pageSize) fetchPage;

  /// Toplam sayısı çekme fonksiyonu (opsiyonel)
  final Future<int?> Function()? fetchTotalCount;

  /// Stream controller
  final _controller = StreamController<PaginatedList<T>>.broadcast();

  /// Mevcut liste
  PaginatedList<T> _currentList;

  PaginationController({
    required this.fetchPage,
    this.fetchTotalCount,
    int pageSize = 20,
  })  : _pagination = PaginationInfo(pageSize: pageSize),
        _currentList = PaginatedList.loading(pageSize: pageSize);

  /// Liste stream'i
  Stream<PaginatedList<T>> get stream => _controller.stream;

  /// Mevcut liste
  PaginatedList<T> get currentList => _currentList;

  /// Yükleniyor mu
  bool get isLoading => _currentList.isLoading;

  /// Daha fazla yüklenebilir mi
  bool get canLoadMore => _currentList.canLoadMore;

  /// İlk sayfa yükle
  Future<void> loadInitial() async {
    _currentList = PaginatedList.loading(pageSize: _pagination.pageSize);
    _controller.add(_currentList);

    try {
      final items = await fetchPage(1, _pagination.pageSize);
      final totalCount = await fetchTotalCount?.call();

      _pagination = PaginationInfo(
        currentPage: 1,
        pageSize: _pagination.pageSize,
        totalItems: totalCount,
        hasMore: items.length >= _pagination.pageSize,
        lastLoadedAt: DateTime.now(),
      );

      _currentList = PaginatedList.loaded(
        items: items,
        pageSize: _pagination.pageSize,
        totalItems: totalCount,
        hasMore: items.length >= _pagination.pageSize,
      );
      _controller.add(_currentList);
    } catch (e) {
      _currentList = PaginatedList.error(e.toString(), pageSize: _pagination.pageSize);
      _controller.add(_currentList);
    }
  }

  /// Sonraki sayfayı yükle
  Future<void> loadMore() async {
    if (!canLoadMore) return;

    _currentList = _currentList.toLoading();
    _controller.add(_currentList);

    try {
      final nextPage = _pagination.currentPage + 1;
      final items = await fetchPage(nextPage, _pagination.pageSize);

      _pagination = _pagination.copyWith(
        currentPage: nextPage,
        hasMore: items.length >= _pagination.pageSize,
        lastLoadedAt: DateTime.now(),
      );

      _currentList = _currentList.addItems(
        items,
        hasMore: items.length >= _pagination.pageSize,
      );
      _controller.add(_currentList);
    } catch (e) {
      _currentList = _currentList.toError(e.toString());
      _controller.add(_currentList);
    }
  }

  /// Yenile
  Future<void> refresh() async {
    _pagination = _pagination.reset();
    await loadInitial();
  }

  /// Listeyi güncelle
  void updateList(PaginatedList<T> list) {
    _currentList = list;
    _controller.add(_currentList);
  }

  /// Kapat
  void dispose() {
    _controller.close();
  }
}

/// Cursor tabanlı sayfalama
class CursorPagination<T, C> {
  /// Öğeler
  final List<T> items;

  /// Sonraki cursor
  final C? nextCursor;

  /// Önceki cursor
  final C? previousCursor;

  /// Daha fazla var mı
  final bool hasMore;

  const CursorPagination({
    required this.items,
    this.nextCursor,
    this.previousCursor,
    this.hasMore = true,
  });

  /// Boş
  factory CursorPagination.empty() {
    return CursorPagination(
      items: [],
      hasMore: false,
    );
  }

  /// Daha fazla yüklenebilir mi
  bool get canLoadMore => hasMore && nextCursor != null;

  /// Öğe sayısı
  int get length => items.length;

  /// Boş mu
  bool get isEmpty => items.isEmpty;
}

/// Supabase için sayfalama yardımcısı
class SupabasePaginationHelper {
  /// Range başlangıcı hesapla
  static int getRangeStart(int page, int pageSize) {
    return (page - 1) * pageSize;
  }

  /// Range bitişi hesapla
  static int getRangeEnd(int page, int pageSize) {
    return page * pageSize - 1;
  }

  /// Sayfalama parametreleri
  static Map<String, int> getParams(int page, int pageSize) {
    return {
      'offset': (page - 1) * pageSize,
      'limit': pageSize,
    };
  }
}
