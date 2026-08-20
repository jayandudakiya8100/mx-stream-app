import 'package:mxstream/moviesPage/UI/gridview_forlists_movies.dart';
import 'package:mxstream/widgets/expressive_page_route.dart';
import 'package:flutter/material.dart';

void onTapGridMovie(List movieList, BuildContext context) {
  Navigator.push(
    context,
    ExpressivePageRoute(
      page: ListGridViewMovies(movieList: movieList),
    ),
  );
}
