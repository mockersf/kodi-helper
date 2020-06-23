module ViewTheater exposing (viewMovies)

import Browser exposing (UrlRequest(..))
import Html exposing (Html, a, button, div, em, h6, input, span, text)
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


sortMovies : SortBy -> Model.MovieList -> Model.MovieList
sortMovies sortBy movie_list =
    List.sortWith
        (movieCompare sortBy)
        movie_list


viewMovies : Theater -> Model.MovieList -> Model.Kodi -> Html Msg
viewMovies theater movie_list kodi =
    let
        filtered_list =
            List.filter
                (\movie ->
                    String.contains theater.filter.title (String.toLower movie.title)
                        || String.contains theater.filter.title (String.toLower (Maybe.withDefault "" movie.set))
                )
                movie_list

        filtered_filtered_list =
            case theater.sortBy of
                SortBySet ->
                    List.filter (\movie -> not (maybeIsNothing movie.set)) filtered_list

                _ ->
                    filtered_list
    in
    viewMovieList
        theater
        (sortMovies
            theater.sortBy
            filtered_filtered_list
        )
        kodi


viewMovieList : Theater -> Model.MovieList -> Model.Kodi -> Html Msg
viewMovieList theater movie_list kodi =
    div []
        [ div [ class "input-group mb-3 sticky-top", style "margin-top" "1rem" ]
            [ div [ class "input-group-prepend" ] [ span [ class "input-group-text" ] [ text "Title" ] ]
            , input [ type_ "text", class "form-control", onInput (\i -> TheaterMsg (TitleFilter i)), value theater.filter.title ] []
            , div [ class "input-group-append" ]
                [ button
                    [ class "btn btn-outline-secondary", attribute "disabled" "true", style "border-right" "0px", style "opacity" "100" ]
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
        , div [ class "card-body", style "padding" "0.7rem" ]
            [ h6 [ class "card-title" ]
                [ a
                    [ href (kodi.url ++ "#movie/" ++ String.fromInt movie.id)
                    , target "_blank"
                    ]
                    [ text movie.title ]
                ]
            , div [] [ em [ class "text-muted small" ] [ text movie.premiered ] ]
            , ViewCommon.viewDuration movie.runtime
            , viewResolution movie.resolution
            , viewRating movie.rating
            , viewPlaycount movie.playcount
            ]
        ]


viewResolution : Maybe Model.Resolution -> Html Msg
viewResolution resolution =
    span [ class (String.concat [ "badge ", ViewCommon.resolutionToColor resolution ]), style "position" "absolute", style "top" "0", style "right" "-0.15em" ]
        [ text
            (ViewCommon.resolutionToQuality resolution)
        ]


viewRating : Float -> Html Msg
viewRating rating =
    span [ class "badge badge-light", style "position" "absolute", style "bottom" "0", style "right" "-0.1em" ]
        [ text
            (String.concat
                [ String.fromFloat
                    rating
                , "⭐️"
                ]
            )
        ]


viewPlaycount : Int -> Html Msg
viewPlaycount playcount =
    if playcount > 0 then
        span [ class "badge badge-light", style "position" "absolute", style "bottom" "0", style "left" "-0.1em" ]
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
