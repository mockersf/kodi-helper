module MainApi exposing (cleanAndScan, getInit, refreshMovies, setTags, update)

import Browser exposing (UrlRequest(..))
import Http
import Json.Encode
import List.Extra
import Model exposing (ApiMsgs(..), CurrentView(..), HospitalMsgs(..), Model, Msg(..), SortBy(..))
import Platform.Cmd
import Process
import Task
import Time


setTags : Int -> List String -> Cmd Msg
setTags movie_id tags =
    Cmd.batch
        [ Http.request
            { method = "PUT"
            , headers = []
            , url = "/api/movies/" ++ String.fromInt movie_id
            , body = Http.jsonBody (Json.Encode.list Json.Encode.string tags)
            , expect = Http.expectString (\msg -> ApiMsg (DataStringReceived msg))
            , timeout = Nothing
            , tracker = Nothing
            }
        , Task.succeed (ApiMsg (QuickUpdateTags tags)) |> Task.perform identity
        ]


refreshMovies : List Int -> Cmd Msg
refreshMovies movie_ids =
    Cmd.batch
        (Task.perform (\t -> HospitalMsg (SetStartRefreshingTime t)) Time.now
            :: List.map
                (\id ->
                    Http.request
                        { method = "DELETE"
                        , headers = []
                        , url = "/api/movies/" ++ String.fromInt id
                        , body = Http.emptyBody
                        , expect = Http.expectString (\msg -> ApiMsg (DataStringReceived msg))
                        , timeout = Nothing
                        , tracker = Nothing
                        }
                )
                movie_ids
            ++ [ Task.attempt
                    (\json ->
                        ApiMsg
                            (DataMovieListReceived json)
                    )
                    (Process.sleep (toFloat (max 5 (List.length movie_ids * 4) * 1000))
                        |> Task.andThen (\_ -> updateMovies)
                    )
               ]
        )


updateMovies : Task.Task Http.Error (List Model.Movie)
updateMovies =
    Http.task
        { method = "PUT"
        , headers = []
        , url = "/api/movies"
        , body = Http.emptyBody
        , resolver = Http.stringResolver <| Model.handleJsonResponse <| Model.movieListDecoder
        , timeout = Nothing
        }


cleanAndScan : Cmd Msg
cleanAndScan =
    Cmd.batch
        [ Task.perform (\t -> HospitalMsg (SetStartLoadingTime t)) Time.now
        , Http.request
            { method = "DELETE"
            , headers = []
            , url = "/api/movies"
            , body = Http.emptyBody
            , expect = Http.expectJson (\json -> ApiMsg (DataMovieListReceived json)) Model.movieListDecoder
            , timeout = Nothing
            , tracker = Nothing
            }
        ]


getMovies : Cmd Msg
getMovies =
    Http.get
        { url = "/api/movies"
        , expect = Http.expectJson (\json -> ApiMsg (DataMovieListReceived json)) Model.movieListDecoder
        }


getConfig : Cmd Msg
getConfig =
    Http.get
        { url = "/api/config"
        , expect = Http.expectJson (\json -> ApiMsg (DataConfigReceived json)) Model.configDecoder
        }


getDuplicates : Cmd Msg
getDuplicates =
    Http.get
        { url = "/api/errors/duplicates"
        , expect = Http.expectJson (\json -> ApiMsg (DataDuplicatesReceived json)) Model.movieListDecoder
        }


getRecognitionErrors : Cmd Msg
getRecognitionErrors =
    Http.get
        { url = "/api/errors/recognition"
        , expect = Http.expectJson (\json -> ApiMsg (DataRecognitionErrorsReceived json)) Model.movieListDecoder
        }


getMissingMovies : Cmd Msg
getMissingMovies =
    Http.get
        { url = "/api/errors/missing"
        , expect = Http.expectJson (\json -> ApiMsg (DataMissingMoviesReceived json)) Model.pathListDecoder
        }


getInit : Cmd Msg
getInit =
    Platform.Cmd.batch [ getMovies, getConfig ]


getAllErrors : Cmd Msg
getAllErrors =
    Platform.Cmd.batch [ getDuplicates, getRecognitionErrors, getMissingMovies ]


update : ApiMsgs -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateTags movie_list ->
            let
                old_theater =
                    model.theater

                tags =
                    List.sort (List.Extra.unique (List.concat (List.map .tags movie_list)))

                genres =
                    List.sort (List.Extra.unique (List.concat (List.map .genres movie_list)))

                updated_theater =
                    { old_theater | tags = tags, genres = genres }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        QuickUpdateTags new_tags ->
            let
                old_theater =
                    model.theater

                tags =
                    List.sort (List.Extra.unique (List.concat [ model.theater.tags, new_tags ]))

                updated_theater =
                    { old_theater | tags = tags }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        DataConfigReceived (Ok config) ->
            ( { model
                | config = config
              }
            , getAllErrors
            )

        DataConfigReceived (Err httpError) ->
            ( { model
                | errorMessage =
                    case model.errorMessage of
                        Just previousError ->
                            Just (String.concat [ previousError, Model.buildErrorMessage httpError ])

                        Nothing ->
                            Just (Model.buildErrorMessage httpError)
              }
            , Cmd.none
            )

        DataMovieListReceived (Ok movies) ->
            ( { model
                | movieList = movies
              }
            , Cmd.batch
                [ getAllErrors
                , Task.succeed (ApiMsg (UpdateTags movies)) |> Task.perform identity
                ]
            )

        DataMovieListReceived (Err httpError) ->
            ( { model
                | errorMessage =
                    case model.errorMessage of
                        Just previousError ->
                            Just (String.concat [ previousError, Model.buildErrorMessage httpError ])

                        Nothing ->
                            Just (Model.buildErrorMessage httpError)
              }
            , Cmd.none
            )

        DataStringReceived (Ok _) ->
            ( model, Cmd.none )

        DataStringReceived (Err httpError) ->
            ( { model
                | errorMessage =
                    case model.errorMessage of
                        Just previousError ->
                            Just (String.concat [ previousError, Model.buildErrorMessage httpError ])

                        Nothing ->
                            Just (Model.buildErrorMessage httpError)
              }
            , Cmd.none
            )

        DataDuplicatesReceived (Ok movies) ->
            let
                hospital =
                    model.hospital

                updated_hospital =
                    { hospital
                        | sickDuplicate = List.map .id movies
                        , loadingStart = Nothing
                        , refreshingStart = Nothing
                    }
            in
            ( { model
                | hospital = updated_hospital
                , currentTime = Nothing
              }
            , Cmd.none
            )

        DataRecognitionErrorsReceived (Ok movies) ->
            let
                hospital =
                    model.hospital

                updated_hospital =
                    { hospital
                        | sickRecognition = List.map .id movies
                    }
            in
            ( { model
                | hospital = updated_hospital
              }
            , Cmd.none
            )

        DataMissingMoviesReceived (Ok missing_movies) ->
            let
                hospital =
                    model.hospital

                updated_hospital =
                    { hospital
                        | sickMissing = List.map .path missing_movies
                    }
            in
            ( { model
                | hospital = updated_hospital
              }
            , Cmd.none
            )

        DataDuplicatesReceived (Err httpError) ->
            ( { model
                | errorMessage =
                    case model.errorMessage of
                        Just previousError ->
                            Just (String.concat [ previousError, Model.buildErrorMessage httpError ])

                        Nothing ->
                            Just (Model.buildErrorMessage httpError)
              }
            , Cmd.none
            )

        DataRecognitionErrorsReceived (Err httpError) ->
            ( { model
                | errorMessage =
                    case model.errorMessage of
                        Just previousError ->
                            Just (String.concat [ previousError, Model.buildErrorMessage httpError ])

                        Nothing ->
                            Just (Model.buildErrorMessage httpError)
              }
            , Cmd.none
            )

        DataMissingMoviesReceived (Err httpError) ->
            ( { model
                | errorMessage =
                    case model.errorMessage of
                        Just previousError ->
                            Just (String.concat [ previousError, Model.buildErrorMessage httpError ])

                        Nothing ->
                            Just (Model.buildErrorMessage httpError)
              }
            , Cmd.none
            )
