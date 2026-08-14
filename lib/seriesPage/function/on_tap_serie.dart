import 'package:Mirarr/seriesPage/serieDetailPage.dart';
import 'package:Mirarr/widgets/expressive_page_route.dart';
import 'package:flutter/material.dart';

void onTapSerie(String serieName, int serieId, BuildContext context) {
  Navigator.push(
    context,
    ExpressivePageRoute(
      page: SerieDetailPage(serieName: serieName, serieId: serieId),
    ),
  );
}
