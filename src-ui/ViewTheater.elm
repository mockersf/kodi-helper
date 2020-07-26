module ViewTheater exposing (viewMovies)

import Browser exposing (UrlRequest(..))
import Html exposing (Html, a, button, div, em, h4, h5, h6, input, span, table, tbody, td, text, tr)
import Html.Attributes exposing (attribute, class, colspan, href, id, spellcheck, style, target, type_, value)
import Html.Events exposing (custom, keyCode, on, onClick, onInput, targetValue)
import InfiniteScroll
import Json.Decode as JD
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
                    ((List.member Model.SearchInTitle theater.filter.searchIn
                        && String.contains theater.filter.title (String.toLower movie.title)
                     )
                        || (List.member Model.SearchInSet theater.filter.searchIn
                                && String.contains theater.filter.title (String.toLower (Maybe.withDefault "" movie.set))
                           )
                        || (List.member Model.SearchInTag theater.filter.searchIn
                                && not (List.isEmpty (List.filter (\tag -> String.contains theater.filter.title (String.toLower tag)) movie.tags))
                           )
                        || (List.member Model.SearchInActor theater.filter.searchIn
                                && not (List.isEmpty (List.filter (\actor -> String.contains theater.filter.title (String.toLower actor.name)) movie.cast))
                           )
                    )
                        && List.member movie.resolution theater.filter.resolution
                        && (List.isEmpty theater.filter.tags || (not (List.isEmpty movie.tags) && List.all (\tag -> List.member tag movie.tags) theater.filter.tags))
                        && (List.isEmpty theater.filter.genres || (not (List.isEmpty movie.genres) && List.all (\genre -> List.member genre movie.genres) theater.filter.genres))
                        && ((theater.filter.seen == Model.SeenFilterAll)
                                || ((theater.filter.seen == Model.SeenFilterSeen) && (movie.playcount > 0))
                                || ((theater.filter.seen == Model.SeenFilterNotSeen) && (movie.playcount == 0))
                           )
                        && (movie.rating >= theater.filter.rating)
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

        movie_details =
            Maybe.andThen List.head (Maybe.map (\id -> List.filter (\movie -> movie.id == id) movie_list) theater.displayTagForMovie)
    in
    div []
        [ viewMovieDetails movie_details
        , viewMovieList
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
        ]


whenEnterPressed_ReceiveInputValue : (String -> msg) -> Html.Attribute msg
whenEnterPressed_ReceiveInputValue tagger =
    let
        isEnter code =
            if code == 13 then
                JD.succeed "Enter pressed"

            else
                JD.fail "is not enter - is this error shown anywhere?!"

        decode_Enter =
            JD.andThen isEnter keyCode
    in
    on "keydown" (JD.map2 (\_ value -> tagger value) decode_Enter targetValue)


onClickNoBubble : msg -> Html.Attribute msg
onClickNoBubble message =
    Html.Events.custom "click" (JD.succeed { message = message, stopPropagation = True, preventDefault = True })


viewMovieDetails : Maybe Model.Movie -> Html Msg
viewMovieDetails movie_details =
    case movie_details of
        Just movie ->
            div [ class "modal", style "display" "block", onClick (TheaterMsg StopDisplayTags) ]
                [ div [ class "bg-info", style "opacity" "67%", style "height" "100%", style "width" "100%", style "position" "absolute" ] []
                , div
                    [ class "modal-dialog", onClickNoBubble Noops ]
                    [ div [ class "modal-content" ]
                        [ div [ class "modal-header" ]
                            [ h5 [ class "modal-title" ] [ text movie.title ]
                            , button
                                [ type_ "button"
                                , class "close"
                                , onClick (TheaterMsg StopDisplayTags)
                                ]
                                [ span [] [ text "×" ] ]
                            ]
                        , div
                            [ class "modal-body" ]
                            [ table [ class "table table-sm" ]
                                [ tbody []
                                    (List.map
                                        (\tag ->
                                            tr []
                                                [ td [] [ text tag ]
                                                , td [ style "text-align" "right" ]
                                                    [ button
                                                        [ type_ "button"
                                                        , class "btn btn-warning btn-sm"
                                                        , onClick (TheaterMsg (RemoveTag movie.id tag))
                                                        ]
                                                        [ text "🗑" ]
                                                    ]
                                                ]
                                        )
                                        movie.tags
                                        ++ [ tr []
                                                [ td
                                                    [ colspan 2
                                                    , whenEnterPressed_ReceiveInputValue (\value -> TheaterMsg (AddTag movie.id value))
                                                    ]
                                                    [ input [ type_ "text", class "form-control" ] [] ]
                                                ]
                                           ]
                                    )
                                ]
                            ]
                        ]
                    ]
                ]

        _ ->
            div [] []


viewMovieList : Theater -> List Model.Movie -> Model.Kodi -> Html Msg
viewMovieList theater movie_list kodi =
    div []
        [ div [ style "margin-top" "0.5rem", style "padding-top" "0.5rem" ]
            [ div
                [ class "input-group mb-3 bg-secondary", style "border-radius" ".25rem" ]
                [ div [ class "input-group-prepend" ]
                    [ button
                        [ class "btn btn-outline-secondary text-light"
                        , type_ "button"
                        , attribute "data-toggle" "collapse"
                        , attribute "data-target" "#collapsableExtraFilters"
                        ]
                        [ text "Filters" ]
                    ]
                , input [ type_ "text", class "form-control", onInput (\i -> TheaterMsg (TitleFilter i)), value theater.filter.title, spellcheck False ] []
                , div [ class "input-group-append" ]
                    [ button
                        [ class "btn btn-outline-secondary text-light"
                        , attribute "disabled" "true"
                        , style "border-right" "0px"
                        ]
                        [ text "Sort By:" ]
                    , button
                        [ class "btn btn-outline-secondary dropdown-toggle text-light"
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
                        (List.map
                            (\sort -> a [ class "dropdown-item", onClick (TheaterMsg (SortTable sort)) ] [ text (viewSortBy sort) ])
                            [ SortByTitle, SortByRating, SortByYear, SortBySet, SortByPlaycount, SortByDateAdded ]
                        )
                    ]
                ]
            ]
        , div []
            [ div [ class "row" ]
                [ div [ class "collapse col-3", id "collapsableExtraFilters" ]
                    [ div [ class "card card-body" ]
                        [ table [ class "table table-sm table-borderless" ]
                            [ tr []
                                [ td []
                                    [ text "Search In" ]
                                , td
                                    []
                                    (List.map
                                        (\search_in -> viewSearchInFilter theater search_in)
                                        [ Model.SearchInTitle
                                        , Model.SearchInSet
                                        , Model.SearchInTag
                                        , Model.SearchInActor
                                        ]
                                    )
                                ]
                            , tr []
                                [ td []
                                    [ text "Resolution" ]
                                , td
                                    []
                                    (List.map
                                        (\resolution -> viewResolutionFilter theater resolution)
                                        [ Just Model.UHD_8k
                                        , Just Model.UHD_4k
                                        , Just Model.HD_1080p
                                        , Just Model.HD_720p
                                        , Just Model.SD
                                        , Nothing
                                        ]
                                    )
                                ]
                            , tr []
                                [ td []
                                    [ text "Tags" ]
                                , td
                                    []
                                    (List.map
                                        (\tag -> viewTagFilter theater tag)
                                        theater.tags
                                        ++ [ span
                                                [ class
                                                    (if List.isEmpty theater.filter.tags then
                                                        "badge badge-dark"

                                                     else
                                                        "badge badge-warning"
                                                    )
                                                , onClick (TheaterMsg ClearTagFilter)
                                                , style "margin" "0.25rem"
                                                ]
                                                [ text "clear" ]
                                           ]
                                    )
                                ]
                            , tr []
                                [ td []
                                    [ text "Genres" ]
                                , td
                                    []
                                    (List.map
                                        (\genre -> viewGenreFilter theater genre)
                                        theater.genres
                                        ++ [ span
                                                [ class
                                                    (if List.isEmpty theater.filter.genres then
                                                        "badge badge-dark"

                                                     else
                                                        "badge badge-warning"
                                                    )
                                                , onClick (TheaterMsg ClearGenreFilter)
                                                , style "margin" "0.25rem"
                                                ]
                                                [ text "clear" ]
                                           ]
                                    )
                                ]
                            , tr []
                                [ td [] [ text "Seen" ]
                                , td []
                                    [ div [ class "btn-group" ]
                                        [ button
                                            [ type_ "button"
                                            , class
                                                ("btn btn-sm btn-"
                                                    ++ (if theater.filter.seen == Model.SeenFilterAll then
                                                            "light"

                                                        else
                                                            "dark"
                                                       )
                                                )
                                            , onClick (TheaterMsg (ChangeSeenFilter Model.SeenFilterAll))
                                            ]
                                            [ text "All" ]
                                        , button
                                            [ type_ "button"
                                            , class
                                                ("btn btn-sm btn-"
                                                    ++ (if theater.filter.seen == Model.SeenFilterSeen then
                                                            "light"

                                                        else
                                                            "dark"
                                                       )
                                                )
                                            , onClick (TheaterMsg (ChangeSeenFilter Model.SeenFilterSeen))
                                            ]
                                            [ text "Seen" ]
                                        , button
                                            [ type_ "button"
                                            , class
                                                ("btn btn-sm btn-"
                                                    ++ (if theater.filter.seen == Model.SeenFilterNotSeen then
                                                            "light"

                                                        else
                                                            "dark"
                                                       )
                                                )
                                            , onClick (TheaterMsg (ChangeSeenFilter Model.SeenFilterNotSeen))
                                            ]
                                            [ text "Not seen" ]
                                        ]
                                    ]
                                ]
                            , tr []
                                [ td [] [ text "Rating" ]
                                , td []
                                    [ div [ class "dropdown" ]
                                        [ button
                                            [ class "btn btn-sm btn-secondary dropdown-toggle"
                                            , type_ "button"
                                            , id "dropdownRatingButton"
                                            , attribute "data-toggle" "dropdown"
                                            ]
                                            [ text (String.fromFloat theater.filter.rating) ]
                                        , div [ class "dropdown-menu", attribute "aria-labelledby" "dropdownRatingButton" ]
                                            (List.map
                                                (\rating ->
                                                    a
                                                        [ class "dropdown-item"
                                                        , href "#"
                                                        , onClick (TheaterMsg (RatingFilter rating))
                                                        ]
                                                        [ text (String.fromFloat rating) ]
                                                )
                                                [ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 ]
                                            )
                                        ]
                                    ]
                                , td [] []
                                ]
                            , tr []
                                [ td [ colspan 4 ]
                                    [ em [ class "text-muted" ]
                                        [ text (String.fromInt (List.length movie_list) ++ " movies matching")
                                        , ViewCommon.viewDuration (List.sum (List.map (\movie -> movie.runtime) movie_list))
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                , div
                    [ class "card-deck col"
                    , style "height" "87vh"
                    , style "overflow" "scroll"
                    , style "align-content" "flex-start"
                    , InfiniteScroll.infiniteScroll (\msg -> TheaterMsg (InfiniteScrollMsg msg))
                    ]
                    (List.map (\movie -> viewMovie movie kodi) (List.take theater.nb_displayed movie_list))
                ]
            ]
        ]


viewSearchInFilter : Theater -> Model.FilterSearchIn -> Html Msg
viewSearchInFilter theater search_in =
    span
        [ class
            (if List.member search_in theater.filter.searchIn then
                "badge badge-light"

             else
                "badge badge-dark"
            )
        , onClick (TheaterMsg (ToggleSearchInFilter search_in))
        , style "margin" "0.25rem"
        ]
        [ text (searchInToString search_in) ]


searchInToString : Model.FilterSearchIn -> String
searchInToString search_in =
    case search_in of
        Model.SearchInTitle ->
            "Title"

        Model.SearchInSet ->
            "Set"

        Model.SearchInTag ->
            "Tag"

        Model.SearchInActor ->
            "Actor"


viewResolutionFilter : Theater -> Maybe Model.Resolution -> Html Msg
viewResolutionFilter theater resolution =
    span
        [ class
            (if List.member resolution theater.filter.resolution then
                String.concat
                    [ "badge "
                    , ViewCommon.resolutionToColor resolution
                    ]

             else
                "badge badge-dark"
            )
        , onClick (TheaterMsg (ToggleResolutionFilter resolution))
        , style "margin" "0.25rem"
        , style "width" "3rem"
        ]
        [ text (ViewCommon.resolutionToQuality resolution) ]


viewTagFilter : Theater -> String -> Html Msg
viewTagFilter theater tag =
    span
        [ class
            (if List.member tag theater.filter.tags then
                "badge badge-light"

             else
                "badge badge-dark"
            )
        , onClick (TheaterMsg (ToggleTagFilter tag))
        , style "margin" "0.25rem"
        ]
        [ text tag ]


viewGenreFilter : Theater -> String -> Html Msg
viewGenreFilter theater genre =
    span
        [ class
            (if List.member genre theater.filter.genres then
                "badge badge-light"

             else
                "badge badge-dark"
            )
        , onClick (TheaterMsg (ToggleGenreFilter genre))
        , style "margin" "0.25rem"
        ]
        [ text genre ]


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
    div
        [ class "card"
        , style "width" "10rem"
        , style "min-width" "10rem"
        , style "max-width" "10rem"
        , style "margin" "0.5rem"
        , style "max-height" "24rem"
        ]
        [ ViewCommon.viewMoviePoster movie.id movie.poster "100%" kodi.url
        , if movie.id == -1 then
            div [ class "card-body", style "padding" "0.7rem", style "display" "flex", style "align-items" "center" ]
                [ h4 [ class "card-title", style "text-align" "center" ]
                    [ text movie.title ]
                ]

          else
            div [ class "card-body", style "padding" "0.7rem" ]
                (h6
                    [ class "card-title" ]
                    [ a
                        [ href (kodi.url ++ "#movie/" ++ String.fromInt movie.id)
                        , target "_blank"
                        ]
                        [ text movie.title ]
                    ]
                    :: div [] [ em [ class "text-muted small" ] [ text movie.premiered ] ]
                    :: ViewCommon.viewDuration movie.runtime
                    :: viewMovieMeta movie
                )
        ]


viewResolution : Maybe Model.Resolution -> Html Msg
viewResolution resolution =
    if not (maybeIsNothing resolution) then
        span
            [ class (String.concat [ "badge ", ViewCommon.resolutionToColor resolution ])
            , style "position" "absolute"
            , style "top" "0"
            , style "right" "-0.1px"
            , style "width" "3rem"
            ]
            [ text
                (ViewCommon.resolutionToQuality resolution)
            ]

    else
        div [] []


viewMovieMeta : Model.Movie -> List (Html Msg)
viewMovieMeta movie =
    [ div
        [ style "position" "absolute"
        , style "bottom" "0"
        , style "right" "-0.1px"
        , style "display" "flex"
        , style "flex-direction" "column"
        ]
        [ span [ class "badge badge-info", onClick (Model.TheaterMsg (Model.DisplayTagsFor movie.id)) ]
            [ text
                (String.concat
                    [ String.fromInt
                        (List.length movie.tags)
                    , "🏷"
                    ]
                )
            ]
        , if movie.rating > 0 then
            span [ class "badge badge-warning" ]
                [ text
                    (String.concat
                        [ String.fromFloat
                            movie.rating
                        , "⭐️"
                        ]
                    )
                ]

          else
            div [] []
        ]
    , viewResolution movie.resolution
    , viewPlaycount movie.playcount
    ]


viewPlaycount : Int -> Html Msg
viewPlaycount playcount =
    if playcount > 0 then
        span [ class "badge badge-primary", style "position" "absolute", style "bottom" "0", style "left" "-0.1px" ]
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
