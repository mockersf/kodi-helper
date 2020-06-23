module ViewCommon exposing (resolutionToColor, resolutionToQuality, viewDuration, viewMoviePoster)

import Browser exposing (UrlRequest(..))
import Html exposing (Html, div, img, text)
import Html.Attributes exposing (class, src, style)
import Html.Events exposing (on)
import Json.Decode
import Model exposing (CurrentView(..), HospitalMsgs(..), Msg(..))


viewMoviePoster : Int -> Maybe String -> String -> String -> Html Msg
viewMoviePoster movie_id mposter width kodiHost =
    case mposter of
        Just poster ->
            img
                [ class "poster"
                , style "width" width
                , style "height" "auto"
                , src (kodiHost ++ "image/" ++ poster)
                , on "error" (Json.Decode.succeed (HospitalMsg (SickPoster movie_id)))
                ]
                []

        Nothing ->
            div [] []


viewDuration : Int -> Html Msg
viewDuration duration =
    div [ class "text-muted small" ]
        [ text
            (String.concat
                ((if duration > 3600 then
                    [ String.fromInt (duration // 3600)
                    , ":"
                    , String.padLeft 2 '0' (String.fromInt (modBy 60 (duration // 60)))
                    ]

                  else
                    [ String.fromInt (duration // 60) ]
                 )
                    ++ [ ":"
                       , String.padLeft 2 '0' (String.fromInt (modBy 60 duration))
                       ]
                )
            )
        ]


resolutionToQuality : Maybe Model.Resolution -> String
resolutionToQuality resolution =
    case resolution of
        Just Model.SD ->
            "SD"

        Just Model.HD_720p ->
            "720p"

        Just Model.HD_1080p ->
            "1080p"

        Just Model.UHD_4k ->
            "4k"

        Just Model.UHD_8k ->
            "8k"

        Nothing ->
            "N/A"


resolutionToColor : Maybe Model.Resolution -> String
resolutionToColor resolution =
    case resolution of
        Just Model.SD ->
            "badge-danger"

        Just Model.HD_720p ->
            "badge-warning"

        Just Model.HD_1080p ->
            "badge-primary"

        Just Model.UHD_4k ->
            "badge-success"

        Just Model.UHD_8k ->
            "badge-info"

        Nothing ->
            "badge-secondary"
