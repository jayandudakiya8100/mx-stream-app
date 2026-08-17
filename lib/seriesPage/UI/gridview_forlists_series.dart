import 'dart:ui';
import 'package:Mirarr/seriesPage/UI/customSeriesWidget.dart';
import 'package:Mirarr/seriesPage/function/on_tap_serie.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:flutter/material.dart';

class ListGridViewSeries extends StatefulWidget {
  final List serieList;
  final String title;

  const ListGridViewSeries({
    Key? key,
    required this.serieList,
    this.title = 'TV List',
  }) : super(key: key);

  @override
  _ListGridViewSeriesState createState() => _ListGridViewSeriesState();
}

class _ListGridViewSeriesState extends State<ListGridViewSeries> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double width = MediaQuery.sizeOf(context).width;
    int crossAxisCount = (width / 160).floor();
    if (crossAxisCount < 2) crossAxisCount = 2;

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          widget.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.58,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
          ),
          itemCount: widget.serieList.length,
          itemBuilder: (context, index) {
            final serie = widget.serieList[index];
            return TvFocusWrapper(
              onTap: () => onTapSerie(serie.name, serie.id, context),
              child: CustomSeriesWidget(
                serie: serie,
                width: double.infinity,
                height: (width / crossAxisCount) * 1.45,
              ),
            );
          },
        ),
      ),
    );
  }
}
