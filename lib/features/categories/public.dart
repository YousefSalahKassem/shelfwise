// OWNER: A2. Public surface of the categories feature — the only thing other
// features may import besides `domain/`.
export 'domain/entities/category.dart';
export 'presentation/providers/category_providers.dart'
    show CategoryOption, categoryOptionsProvider, categoryTreeProvider;
export 'presentation/widgets/category_field.dart' show CategoryField;
