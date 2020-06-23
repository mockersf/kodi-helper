module MainHospital exposing (update)

import Browser exposing (UrlRequest(..))
import List.Extra
import MainApi
import Model exposing (ApiMsgs(..), CurrentView(..), HospitalMsgs(..), Model, Msg(..), SortBy(..))


update : HospitalMsgs -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SickPoster id ->
            let
                hospital =
                    model.hospital

                old_sick_list =
                    hospital.sickPoster

                updated_hospital =
                    { hospital
                        | sickPoster = List.Extra.unique (old_sick_list ++ [ id ])
                    }
            in
            ( { model
                | hospital = updated_hospital
              }
            , Cmd.none
            )

        ToggleHospitalShow type_to_toggle ->
            let
                hospital =
                    model.hospital

                updated_hospital =
                    case type_to_toggle of
                        Model.SickTypeSD ->
                            { hospital
                                | showSD = not hospital.showSD
                            }

                        Model.SickTypeResolutionMissing ->
                            { hospital
                                | showResolutionMissing = not hospital.showResolutionMissing
                            }

                        Model.SickTypeDuplicate ->
                            { hospital
                                | showDuplicate = not hospital.showDuplicate
                            }

                        Model.SickTypePoster ->
                            { hospital
                                | showPoster = not hospital.showPoster
                            }

                        Model.SickTypeRecognition ->
                            { hospital
                                | showRecognition = not hospital.showRecognition
                            }

                        Model.SickTypeMissing ->
                            { hospital
                                | showMissing = not hospital.showMissing
                            }
            in
            ( { model
                | hospital = updated_hospital
              }
            , Cmd.none
            )

        RefreshKodi ->
            ( model
            , case model.hospital.loadingStart of
                Nothing ->
                    MainApi.cleanAndScan

                Just _ ->
                    Cmd.none
            )

        RefreshMovies movie_ids ->
            let
                hospital =
                    model.hospital

                updated_hospital =
                    { hospital
                        | sickPoster = List.filter (\id -> not (List.member id movie_ids)) hospital.sickPoster
                    }
            in
            ( { model
                | hospital = updated_hospital
                , movieList =
                    List.map
                        (\movie ->
                            if List.member movie.id movie_ids then
                                { movie | poster = Just "image%3A%2F%2Fhttps%253A%252F%252Fkodi.tv%252Fsites%252Fdefault%252Ffiles%252Fuploads%252Fthumbnail-light.png" }

                            else
                                movie
                        )
                        model.movieList
              }
            , MainApi.refreshMovies movie_ids
            )

        SetStartLoadingTime time ->
            let
                hospital =
                    model.hospital

                updated_hospital =
                    { hospital | loadingStart = Just time }
            in
            ( { model | hospital = updated_hospital }
            , Cmd.none
            )

        SetStartRefreshingTime time ->
            let
                hospital =
                    model.hospital

                updated_hospital =
                    { hospital | refreshingStart = Just time }
            in
            ( { model | hospital = updated_hospital }
            , Cmd.none
            )
