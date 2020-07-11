module ViewHospital exposing (viewSickMovies)

import Browser exposing (UrlRequest(..))
import Html exposing (Html, a, button, div, em, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, href, scope, style, target, type_)
import Html.Events exposing (onClick)
import Model exposing (CurrentView(..), HospitalMsgs(..), Msg(..))
import Time
import ViewCommon


maybeIsNothing : Maybe a -> Bool
maybeIsNothing m =
    case m of
        Just _ ->
            False

        Nothing ->
            True


viewSickMovies : Model.Hospital -> Maybe Time.Posix -> List Model.Movie -> Model.Kodi -> Html Msg
viewSickMovies hospital mtime movie_list kodi =
    div []
        [ div [ style "margin" "1rem" ]
            [ div [ class "btn-group" ]
                [ button
                    [ type_ "button"
                    , class
                        (String.concat
                            [ "btn btn"
                            , if hospital.showDuplicate then
                                "-primary"

                              else
                                "-secondary"
                            ]
                        )
                    , onClick (HospitalMsg (ToggleHospitalShow Model.SickTypeDuplicate))
                    ]
                    [ text "Duplicates" ]
                , button
                    [ type_ "button"
                    , class
                        (String.concat
                            [ "btn btn"
                            , if hospital.showPoster then
                                "-primary"

                              else
                                "-secondary"
                            ]
                        )
                    , onClick (HospitalMsg (ToggleHospitalShow Model.SickTypePoster))
                    ]
                    [ text "Posters" ]
                , button
                    [ type_ "button"
                    , class
                        (String.concat
                            [ "btn btn"
                            , if hospital.showRecognition then
                                "-primary"

                              else
                                "-secondary"
                            ]
                        )
                    , onClick (HospitalMsg (ToggleHospitalShow Model.SickTypeRecognition))
                    ]
                    [ text "Recognition" ]
                , button
                    [ type_ "button"
                    , class
                        (String.concat
                            [ "btn btn"
                            , if hospital.showMissing then
                                "-primary"

                              else
                                "-secondary"
                            ]
                        )
                    , onClick (HospitalMsg (ToggleHospitalShow Model.SickTypeMissing))
                    ]
                    [ text "Missing" ]
                , button
                    [ type_ "button"
                    , class
                        (String.concat
                            [ "btn btn"
                            , if hospital.showResolutionMissing then
                                "-primary"

                              else
                                "-secondary"
                            ]
                        )
                    , onClick (HospitalMsg (ToggleHospitalShow Model.SickTypeResolutionMissing))
                    ]
                    [ text "Resolution Missing" ]
                , button
                    [ type_ "button"
                    , class
                        (String.concat
                            [ "btn btn"
                            , if hospital.showSD then
                                "-primary"

                              else
                                "-secondary"
                            ]
                        )
                    , onClick (HospitalMsg (ToggleHospitalShow Model.SickTypeSD))
                    ]
                    [ text "SD" ]
                ]
            , div [ class "float-right", style "display" "flex" ]
                [ div [ style "margin-top" "0.5rem" ]
                    [ let
                        actionStarted =
                            case ( hospital.loadingStart, hospital.refreshingStart ) of
                                ( Just start, _ ) ->
                                    Just start

                                ( _, Just start ) ->
                                    Just start

                                ( Nothing, Nothing ) ->
                                    Nothing
                      in
                      case ( mtime, actionStarted ) of
                        ( Just currentTime, Just startTime ) ->
                            ViewCommon.viewDuration ((Time.posixToMillis currentTime - Time.posixToMillis startTime) // 1000)

                        _ ->
                            div [] []
                    ]
                , button
                    [ type_ "button"
                    , class "btn btn-warning"
                    , style "margin-right" "1rem"
                    , style "margin-left" "1rem"
                    , onClick
                        (HospitalMsg
                            (RefreshMovies
                                (List.take 20
                                    (List.sort
                                        (List.map
                                            .id
                                            (List.filter
                                                (\movie ->
                                                    List.member movie.id hospital.sickPoster
                                                        || maybeIsNothing movie.poster
                                                )
                                                movie_list
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    ]
                    [ div
                        (if not (maybeIsNothing hospital.refreshingStart) then
                            [ style "animation" "spinner 2s linear infinite" ]

                         else
                            []
                        )
                        [ text "👀" ]
                    ]
                , button
                    [ type_ "button"
                    , class "btn btn-warning"
                    , onClick (HospitalMsg RefreshKodi)
                    ]
                    [ div
                        (if not (maybeIsNothing hospital.loadingStart) then
                            [ style "animation" "spinner 2s linear infinite" ]

                         else
                            []
                        )
                        [ text "♻️" ]
                    ]
                ]
            ]
        , viewSickMovieList
            (List.filter
                (\movie ->
                    (hospital.showDuplicate && List.member movie.id hospital.sickDuplicate)
                        || (hospital.showPoster
                                && (List.member movie.id hospital.sickPoster
                                        || maybeIsNothing movie.poster
                                   )
                           )
                        || (hospital.showRecognition && List.member movie.id hospital.sickRecognition)
                        || (hospital.showSD && (movie.resolution == Just Model.SD))
                        || (hospital.showResolutionMissing && (movie.resolution == Nothing))
                )
                movie_list
                ++ (if hospital.showMissing then
                        List.map Model.placeholderMovie hospital.sickMissing

                    else
                        []
                   )
            )
            kodi
        ]


viewSickMovieList : List Model.Movie -> Model.Kodi -> Html Msg
viewSickMovieList movie_list kodi =
    div []
        [ em []
            [ text (String.fromInt (List.length movie_list) ++ " movies to fix") ]
        , table
            [ class "table table-sm table-striped" ]
            [ thead []
                [ th [ scope "col" ] [ text "Poster" ]
                , th [ scope "col" ] [ text "Title" ]
                , th [ scope "col" ] [ text "Path" ]
                , th [ scope "col" ] [ text "Runtime" ]
                , th [ scope "col" ] [ text "Resolution" ]
                , th [ scope "col" ] [ text "Refresh" ]
                ]
            , tbody [] (List.map (\movie -> viewSickMovie movie kodi) movie_list)
            ]
        ]


viewSickMovie : Model.Movie -> Model.Kodi -> Html Msg
viewSickMovie movie kodi =
    tr
        []
        [ ViewCommon.viewMoviePoster movie.id movie.poster "1.6rem" kodi.url
        , td []
            [ a
                [ href (kodi.url ++ "#movie/" ++ String.fromInt movie.id)
                , target "_blank"
                ]
                [ text movie.title ]
            , em [ class "text-muted small" ] [ text (" - " ++ movie.premiered) ]
            ]
        , td
            (if movie.id == -1 then
                []

             else
                [ class "text-muted" ]
            )
            [ text movie.path ]
        , td []
            [ if movie.runtime > 0 then
                ViewCommon.viewDuration movie.runtime

              else
                div [] []
            ]
        , td [ class "text-muted" ] [ text (ViewCommon.resolutionToQuality movie.resolution) ]
        , td []
            [ if movie.id > 0 then
                button
                    [ type_ "button"
                    , class "btn btn-info btn-sm"
                    , onClick (HospitalMsg (RefreshMovies [ movie.id ]))
                    ]
                    [ text "👀" ]

              else
                div [] []
            ]
        ]
