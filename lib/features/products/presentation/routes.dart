// OWNER: A2.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import 'pages/product_detail_page.dart';
import 'pages/product_form_page.dart';
import 'pages/product_list_page.dart';

/// Literal paths come before `:id` ones so `/products/new` is never read as an id.
FeatureRoutes get productsRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.products,
          builder: (context, state) => const ProductListPage(),
        ),
        GoRoute(
          path: RoutePaths.productNew,
          // `?barcode=…` prefills the form after an unknown code was scanned.
          builder: (context, state) => ProductFormPage(
            initialBarcode: state.uri.queryParameters['barcode'],
          ),
        ),
        GoRoute(
          path: RoutePaths.productEdit,
          builder: (context, state) =>
              ProductFormPage(productId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: RoutePaths.productDetail,
          builder: (context, state) =>
              ProductDetailPage(productId: state.pathParameters['id']!),
        ),
      ],
    );
