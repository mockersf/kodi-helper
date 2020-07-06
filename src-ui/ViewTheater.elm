module ViewTheater exposing (viewMovies)

import Browser exposing (UrlRequest(..))
import Html exposing (Html, a, button, div, em, h4, h6, input, span, text)
import Html.Attributes exposing (attribute, class, href, id, style, target, type_, value)
import Html.Events exposing (onClick, onInput)
import Model exposing (CurrentView(..), Msg(..), SortBy(..), Theater, TheaterMsgs(..))
import ViewCommon


maybeIsNothing : Maybe a -> Bool
maybeIsNothing m =
    case m of
        Just _ ->
            False

        Nothing ->
            True


movieCompare : SortBy -> Model.Movie -> Model.Movie -> Order
movieCompare sortBy movieA movieB =
    case sortBy of
        SortByTitle ->
            compare movieA.title movieB.title

        SortByYear ->
            compare movieB.premiered movieA.premiered

        SortByDateAdded ->
            compare movieB.dateadded movieA.dateadded

        SortByRating ->
            compare movieB.rating movieA.rating

        SortByPlaycount ->
            compare movieB.playcount movieA.playcount

        SortBySet ->
            case compare (Maybe.withDefault "" movieA.set) (Maybe.withDefault "" movieB.set) of
                LT ->
                    LT

                GT ->
                    GT

                EQ ->
                    compare movieA.premiered movieB.premiered


sortMovies : SortBy -> List Model.Movie -> List Model.Movie
sortMovies sortBy movie_list =
    List.sortWith
        (movieCompare sortBy)
        movie_list


viewMovies : Theater -> List Model.Movie -> Model.Kodi -> Html Msg
viewMovies theater movie_list kodi =
    let
        filtered_list =
            List.filter
                (\movie ->
                    String.contains theater.filter.title (String.toLower movie.title)
                        || String.contains theater.filter.title (String.toLower (Maybe.withDefault "" movie.set))
                )
                movie_list

        list_for_set =
            case theater.sortBy of
                SortBySet ->
                    Tuple.second
                        (List.foldl
                            (\movie acc ->
                                let
                                    current_set =
                                        Tuple.first acc

                                    movies =
                                        Tuple.second acc
                                in
                                if current_set == movie.set then
                                    ( movie.set, movies ++ [ movie ] )

                                else
                                    ( movie.set
                                    , movies
                                        ++ [ Model.setMovieCard movie.set
                                           , movie
                                           ]
                                    )
                            )
                            ( Nothing, [] )
                            (sortMovies theater.sortBy (List.filter (\movie -> not (maybeIsNothing movie.set)) filtered_list))
                        )

                _ ->
                    []
    in
    viewMovieList
        theater
        (case theater.sortBy of
            SortBySet ->
                list_for_set

            _ ->
                sortMovies
                    theater.sortBy
                    filtered_list
        )
        kodi


viewMovieList : Theater -> List Model.Movie -> Model.Kodi -> Html Msg
viewMovieList theater movie_list kodi =
    div []
        [ div [ class "input-group mb-3 sticky-top", style "margin-top" "0.5rem", style "padding-top" "0.5rem" ]
            [ div [ class "input-group-prepend" ] [ span [ class "input-group-text" ] [ text "Title" ] ]
            , input [ type_ "text", class "form-control", onInput (\i -> TheaterMsg (TitleFilter i)), value theater.filter.title ] []
            , div [ class "input-group-append" ]
                [ button
                    [ class "btn btn-outline-secondary"
                    , attribute "disabled" "true"
                    , style "border-right" "0px"
                    , style "opacity" "100"
                    , style "background-color" "rgb(233, 236, 239)"
                    , style "border-color" "rgb(206, 212, 218)"
                    ]
                    [ text "Sort By:" ]
                , button
                    [ class "btn btn-outline-secondary dropdown-toggle"
                    , type_ "button"
                    , id "dropdownMenuButton"
                    , attribute "data-toggle" "dropdown"
                    , attribute "aria-haspopup" "true"
                    , attribute "aria-expanded" "false"
                    , style "width" "8em"
                    , style "text-align" "right"
                    , style "border-left" "0px"
                    , style "background-color" "rgb(233, 236, 239)"
                    , style "border-color" "rgb(206, 212, 218)"
                    ]
                    [ text (viewSortBy theater.sortBy) ]
                , div [ class "dropdown-menu", attribute "aria-labelledby" "dropdownMenuLink" ]
                    [ a [ class "dropdown-item", onClick (TheaterMsg (SortTable SortByTitle)) ] [ text (viewSortBy SortByTitle) ]
                    , a [ class "dropdown-item", onClick (TheaterMsg (SortTable SortByRating)) ] [ text (viewSortBy SortByRating) ]
                    , a [ class "dropdown-item", onClick (TheaterMsg (SortTable SortByYear)) ] [ text (viewSortBy SortByYear) ]
                    , a [ class "dropdown-item", onClick (TheaterMsg (SortTable SortBySet)) ] [ text (viewSortBy SortBySet) ]
                    , a [ class "dropdown-item", onClick (TheaterMsg (SortTable SortByPlaycount)) ] [ text (viewSortBy SortByPlaycount) ]
                    , a [ class "dropdown-item", onClick (TheaterMsg (SortTable SortByDateAdded)) ] [ text (viewSortBy SortByDateAdded) ]
                    ]
                ]
            ]
        , div [ class "card-deck" ] (List.map (\movie -> viewMovie movie kodi) movie_list)
        ]


viewSortBy : SortBy -> String
viewSortBy sortBy =
    case sortBy of
        SortByTitle ->
            "Title"

        SortByRating ->
            "Rating"

        SortByYear ->
            "Year"

        SortBySet ->
            "Set"

        SortByPlaycount ->
            "Play Count"

        SortByDateAdded ->
            "Date Added"


viewMovie : Model.Movie -> Model.Kodi -> Html Msg
viewMovie movie kodi =
    div [ class "card", style "width" "10rem", style "min-width" "10rem", style "max-width" "10rem", style "margin" "0.5rem" ]
        [ ViewCommon.viewMoviePoster movie.id movie.poster "10rem" kodi.url
        , if movie.id == -1 then
            div [ class "card-body", style "padding" "0.7rem", style "display" "flex", style "align-items" "center" ]
                [ h4 [ class "card-title", style "text-align" "center" ]
                    [ text movie.title ]
                ]

          else
            div [ class "card-body", style "padding" "0.7rem" ]
                [ h6
                    [ class "card-title" ]
                    [ a
                        [ href (kodi.url ++ "#movie/" ++ String.fromInt movie.id)
                        , target "_blank"
                        ]
                        [ text movie.title ]
                    ]
                , div [] [ em [ class "text-muted small" ] [ text movie.premiered ] ]
                , ViewCommon.viewDuration movie.runtime
                , viewResolution movie.resolution
                , viewMovieMeta movie.rating movie.tags
                , viewPlaycount movie.playcount
                ]
        ]


viewResolution : Maybe Model.Resolution -> Html Msg
viewResolution resolution =
    if not (maybeIsNothing resolution) then
        span [ class (String.concat [ "badge ", ViewCommon.resolutionToColor resolution ]), style "position" "absolute", style "top" "0", style "right" "-0.15em" ]
            [ text
                (ViewCommon.resolutionToQuality resolution)
            ]

    else
        div [] []


viewMovieMeta : Float -> List String -> Html Msg
viewMovieMeta rating tags =
    div
        [ style "position" "absolute"
        , style "bottom" "0"
        , style "right" "-0.1em"
        , style "display" "flex"
        , style "flex-direction" "column"
        ]
        [ span [ class "badge badge-info" ]
            [ text
                (String.concat
                    [ String.fromInt
                        (List.length tags)
                    , "🏷"
                    ]
                )
            ]
        , if rating > 0 then
            span [ class "badge badge-warning" ]
                [ text
                    (String.concat
                        [ String.fromFloat
                            rating
                        , "⭐️"
                        ]
                    )
                ]

          else
            div [] []
        ]


viewPlaycount : Int -> Html Msg
viewPlaycount playcount =
    if playcount > 0 then
        span [ class "badge badge-primary", style "position" "absolute", style "bottom" "0", style "left" "-0.1em" ]
            [ text
                (String.concat
                    [ "👁"
                    , String.fromInt
                        playcount
                    ]
                )
            ]

    else
        div [] []
