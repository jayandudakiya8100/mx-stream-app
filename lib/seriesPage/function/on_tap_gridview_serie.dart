import 'package:mxstream/seriesPage/UI/gridview_forlists_series.dart';
import 'package:mxstream/widgets/expressive_page_route.dart';
import 'package:flutter/material.dart';

void onTapGridSerie(List serieList, BuildContext context) {
  Navigator.push(
    context,
    ExpressivePageRoute(
      page: ListGridViewSeries(serieList: serieList),
    ),
  );
}
