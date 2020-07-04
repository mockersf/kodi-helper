module Main exposing (main)

import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import MainApi
import MainHospital
import MainTheater
import Model exposing (ApiMsgs(..), CurrentView(..), Hospital, HospitalMsgs(..), Model, Msg(..), SortBy(..), Theater)
import Time
import Url
import Url.Parser as Url exposing ((</>), Parser)
import View exposing (view)


urlToView : Url.Url -> CurrentView
urlToView url =
    url
        |> Url.parse urlParser
        |> Maybe.withDefault TheaterView


urlParser : Parser (CurrentView -> a) a
urlParser =
    Url.oneOf
        [ Url.map TheaterView (Url.s "ui" </> Url.s "theater")
        , Url.map HospitalView (Url.s "ui" </> Url.s "hospital")
        ]


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( Model
        key
        []
        (Theater (Model.Filter "" Nothing) SortByTitle)
        Nothing
        (urlToView url)
        (Hospital False [] True [] True [] True [] True False Nothing Nothing)
        Nothing
        (Model.Config [ Model.defaultKodi ] 0)
    , MainApi.getInit
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SwitchView view ->
            let
                url =
                    case view of
                        TheaterView ->
                            "/ui/theater"

                        HospitalView ->
                            "/ui/hospital"
            in
            ( model, Nav.pushUrl model.navKey url )

        LinkClicked _ ->
            ( model, Cmd.none )

        UrlChange url ->
            ( { model | view = urlToView url }, Cmd.none )

        Tick time ->
            ( { model | currentTime = Just time }, Cmd.none )

        HospitalMsg hospital_msg ->
            MainHospital.update hospital_msg model

        TheaterMsg theater_msg ->
            MainTheater.update theater_msg model

        ApiMsg api_msg ->
            MainApi.update api_msg model


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChange
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    case ( model.hospital.loadingStart, model.hospital.refreshingStart ) of
        ( Just _, _ ) ->
            Time.every 1000 Tick

        ( _, Just _ ) ->
            Time.every 1000 Tick

        ( Nothing, Nothing ) ->
            Sub.none
