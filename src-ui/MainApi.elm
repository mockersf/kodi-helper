module MainApi exposing (cleanAndScan, getInit, refreshMovies, update)

import Browser exposing (UrlRequest(..))
import Http
import Model exposing (ApiMsgs(..), CurrentView(..), HospitalMsgs(..), Model, Msg(..), SortBy(..))
import Platform.Cmd
import Process
import Task
import Time


refreshMovies : List Int -> Cmd Msg
refreshMovies movie_ids =
    Cmd.batch
        (Task.perform (\t -> HospitalMsg (SetStartRefreshingTime t)) Time.now
            :: List.map
                (\id ->
                    Http.get
                        { url = "/api/refresh_movie/" ++ String.fromInt id
                        , expect = Http.expectString (\msg -> ApiMsg (DataStringReceived msg))
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
        { method = "GET"
        , headers = []
        , url = "/api/update_movie_list"
        , body = Http.emptyBody
        , resolver = Http.stringResolver <| Model.handleJsonResponse <| Model.movieListDecoder
        , timeout = Nothing
        }


cleanAndScan : Cmd Msg
cleanAndScan =
    Cmd.batch
        [ Task.perform (\t -> HospitalMsg (SetStartLoadingTime t)) Time.now
        , Http.get
            { url = "/api/clean_and_scan"
            , expect = Http.expectJson (\json -> ApiMsg (DataMovieListReceived json)) Model.movieListDecoder
            }
        ]


getMovies : Cmd Msg
getMovies =
    Http.get
        { url = "/api/movie_list"
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
        { url = "/api/duplicates_list"
        , expect = Http.expectJson (\json -> ApiMsg (DataDuplicatesReceived json)) Model.movieListDecoder
        }


getRecognitionErrors : Cmd Msg
getRecognitionErrors =
    Http.get
        { url = "/api/recognition_errors_list"
        , expect = Http.expectJson (\json -> ApiMsg (DataRecognitionErrorsReceived json)) Model.movieListDecoder
        }


getMissingMovies : Cmd Msg
getMissingMovies =
    Http.get
        { url = "/api/missing_movies_list"
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
            , getAllErrors
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
            ( model, getAllErrors )

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
