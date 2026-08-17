import 'dart:ui';
import 'package:Mirarr/moviesPage/UI/customMovieWidget.dart';
import 'package:Mirarr/moviesPage/functions/on_tap_movie.dart';
import 'package:Mirarr/widgets/tv_focus_wrapper.dart';
import 'package:flutter/material.dart';

class ListGridViewMovies extends StatefulWidget {
  final List movieList;
  final String title;

  const ListGridViewMovies({
    Key? key,
    required this.movieList,
    this.title = 'Movie List',
  }) : super(key: key);

  @override
  _ListGridViewMoviesState createState() => _ListGridViewMoviesState();
}

class _ListGridViewMoviesState extends State<ListGridViewMovies> {
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
          itemCount: widget.movieList.length,
          itemBuilder: (context, index) {
            final movie = widget.movieList[index];
            return TvFocusWrapper(
              onTap: () => onTapMovie(movie.title, movie.id, context),
              child: CustomMovieWidget(
                movie: movie,
                showAvailability: false,
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
