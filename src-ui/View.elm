module View exposing (view)

import Browser exposing (UrlRequest(..))
import Html exposing (Html, a, div, em, li, p, text, ul)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Model exposing (CurrentView(..), Model, Msg(..))
import ViewHospital
import ViewTheater


view : Model -> Browser.Document Msg
view model =
    Browser.Document
        "Kodi Movie Library Manager"
        [ viewContent model ]


viewContent : Model -> Html Msg
viewContent model =
    let
        kodi =
            Maybe.withDefault Model.defaultKodi (List.head (List.drop model.config.kodiOfInterest model.config.kodis))
    in
    div [ class "container-fluid" ]
        [ div []
            (case model.errorMessage of
                Just error ->
                    [ text error ]

                Nothing ->
                    []
            )
        , div [ class "container-fluid" ]
            [ div
                [ class "row" ]
                [ p
                    [ class "col-2", style "border-bottom" "1px solid #dee2e6", style "margin-bottom" "0", style "margin-top" "1rem" ]
                    [ em [] [ text (kodi.name ++ " - " ++ String.fromInt (List.length model.movieList) ++ " movies") ] ]
                , ul [ class "nav nav-tabs justify-content-end col-10" ]
                    [ li [ class "nav-item" ]
                        [ a
                            [ class
                                ("nav-link "
                                    ++ (if model.view == TheaterView then
                                            "active"

                                        else
                                            ""
                                       )
                                )
                            , onClick (SwitchView TheaterView)
                            ]
                            [ text "🎬" ]
                        ]
                    , li [ class "nav-item" ]
                        [ a
                            [ class
                                ("nav-link "
                                    ++ (if model.view == HospitalView then
                                            "active"

                                        else
                                            ""
                                       )
                                )
                            , onClick (SwitchView HospitalView)
                            ]
                            [ text "🏥" ]
                        ]
                    ]
                ]
            ]
        , div [ class "container-fluid" ]
            [ case model.view of
                TheaterView ->
                    ViewTheater.viewMovies model.theater model.movieList kodi

                HospitalView ->
                    ViewHospital.viewSickMovies model.hospital model.currentTime model.movieList kodi
            ]
        ]
