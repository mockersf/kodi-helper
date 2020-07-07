module MainTheater exposing (update)

import Browser exposing (UrlRequest(..))
import MainApi
import Model exposing (CurrentView(..), HospitalMsgs(..), Model, Msg(..), SortBy(..), TheaterMsgs(..))


update : TheaterMsgs -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SortTable sortBy ->
            let
                old_theater =
                    model.theater

                updated_theater =
                    { old_theater
                        | sortBy = sortBy
                    }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        TitleFilter filter ->
            let
                old_filter =
                    model.theater.filter

                new_filter =
                    { old_filter | title = String.toLower filter }

                old_theater =
                    model.theater

                updated_theater =
                    { old_theater
                        | filter = new_filter
                    }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        ToggleTagFilter tag ->
            let
                old_filter =
                    model.theater.filter

                new_filter =
                    if List.member tag old_filter.tags then
                        { old_filter | tags = List.filter (\t -> t /= tag) old_filter.tags }

                    else
                        { old_filter | tags = tag :: old_filter.tags }

                old_theater =
                    model.theater

                updated_theater =
                    { old_theater
                        | filter = new_filter
                    }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        ClearTagFilter ->
            let
                old_filter =
                    model.theater.filter

                new_filter =
                    { old_filter | tags = [] }

                old_theater =
                    model.theater

                updated_theater =
                    { old_theater
                        | filter = new_filter
                    }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        ToggleResolutionFilter resolution ->
            let
                old_filter =
                    model.theater.filter

                new_filter =
                    if List.member resolution old_filter.resolution then
                        { old_filter | resolution = List.filter (\res -> res /= resolution) old_filter.resolution }

                    else
                        { old_filter | resolution = resolution :: old_filter.resolution }

                old_theater =
                    model.theater

                updated_theater =
                    { old_theater
                        | filter = new_filter
                    }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        DisplayTagsFor movie_id ->
            let
                old_theater =
                    model.theater

                updated_theater =
                    { old_theater
                        | displayTagForMovie = Just movie_id
                    }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        StopDisplayTags ->
            let
                old_theater =
                    model.theater

                updated_theater =
                    { old_theater
                        | displayTagForMovie = Nothing
                    }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        AddTag movie_id new_tag ->
            let
                updated_movie_list =
                    List.map
                        (\movie ->
                            if movie.id == movie_id then
                                { movie | tags = movie.tags ++ [ new_tag ] }

                            else
                                movie
                        )
                        model.movieList
            in
            ( { model
                | movieList = updated_movie_list
              }
            , MainApi.setTags movie_id (Maybe.withDefault [] (Maybe.map .tags (List.head (List.filter (\movie -> movie.id == movie_id) updated_movie_list))))
            )

        RemoveTag movie_id tag_to_remove ->
            let
                updated_movie_list =
                    List.map
                        (\movie ->
                            if movie.id == movie_id then
                                { movie | tags = List.filter (\tag -> tag /= tag_to_remove) movie.tags }

                            else
                                movie
                        )
                        model.movieList
            in
            ( { model
                | movieList = updated_movie_list
              }
            , MainApi.setTags movie_id (Maybe.withDefault [] (Maybe.map .tags (List.head (List.filter (\movie -> movie.id == movie_id) updated_movie_list))))
            )
