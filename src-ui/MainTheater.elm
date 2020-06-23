module MainTheater exposing (update)

import Browser exposing (UrlRequest(..))
import Model exposing (CurrentView(..), HospitalMsgs(..), Model, Msg(..), SortBy(..), TheaterMsgs(..))


update : TheaterMsgs -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SortTable sortBy ->
            let
                old_theater =
                    model.theater

                updated_theater =
                    { old_theater
                        | sortBy = sortBy
                    }
            in
            ( { model | theater = updated_theater }, Cmd.none )

        TitleFilter filter ->
            let
                old_filter =
                    model.theater.filter

                new_filter =
                    { old_filter | title = String.toLower filter }

                old_theater =
                    model.theater

                updated_theater =
                    { old_theater
                        | filter = new_filter
                    }
            in
            ( { model | theater = updated_theater }, Cmd.none )
