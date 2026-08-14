import 'package:Mirarr/moviesPage/movieDetailPage.dart';
import 'package:Mirarr/widgets/expressive_page_route.dart';
import 'package:flutter/material.dart';

Future<void> onTapMovie(String movieTitle, int movieId, BuildContext context) async {
  await Navigator.push(
    context,
    ExpressivePageRoute(
      page: MovieDetailPage(movieTitle: movieTitle, movieId: movieId),
    ),
  );
}
