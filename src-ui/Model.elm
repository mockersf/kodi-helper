module Model exposing
    ( ApiMsgs(..)
    , Config
    , CurrentView(..)
    , Filter
    , Hospital
    , HospitalMsgs(..)
    , Kodi
    , Model
    , Movie
    , Msg(..)
    , Resolution(..)
    , SeenFilter(..)
    , SickType(..)
    , SortBy(..)
    , Theater
    , TheaterMsgs(..)
    , buildErrorMessage
    , configDecoder
    , defaultKodi
    , handleJsonResponse
    , movieListDecoder
    , pathListDecoder
    , placeholderMovie
    , setMovieCard
    )

import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import Http
import Json.Decode as Decode exposing (float, int, string)
import Json.Decode.Pipeline exposing (hardcoded, required)
import Time
import Url


type alias Model =
    { navKey : Nav.Key
    , movieList : List Movie
    , theater : Theater
    , errorMessage : Maybe String
    , view : CurrentView
    , hospital : Hospital
    , currentTime : Maybe Time.Posix
    , config : Config
    }


type alias Theater =
    { filter : Filter
    , sortBy : SortBy
    , displayTagForMovie : Maybe Int
    , tags : List String
    , genres : List String
    }


type alias Hospital =
    { showSD : Bool
    , sickPoster : List Int
    , showPoster : Bool
    , sickMissing : List String
    , showMissing : Bool
    , sickDuplicate : List Int
    , showDuplicate : Bool
    , sickRecognition : List Int
    , showRecognition : Bool
    , showResolutionMissing : Bool
    , loadingStart : Maybe Time.Posix
    , refreshingStart : Maybe Time.Posix
    }


type SickType
    = SickTypeDuplicate
    | SickTypePoster
    | SickTypeRecognition
    | SickTypeMissing
    | SickTypeSD
    | SickTypeResolutionMissing


type alias Filter =
    { title : String
    , resolution : List (Maybe Resolution)
    , tags : List String
    , genres : List String
    , seen : SeenFilter
    }


type SeenFilter
    = SeenFilterAll
    | SeenFilterSeen
    | SeenFilterNotSeen


type CurrentView
    = TheaterView
    | HospitalView


type Msg
    = LinkClicked UrlRequest
    | UrlChange Url.Url
    | SwitchView CurrentView
    | Tick Time.Posix
    | ApiMsg ApiMsgs
    | TheaterMsg TheaterMsgs
    | HospitalMsg HospitalMsgs
    | Noops


type ApiMsgs
    = DataStringReceived (Result Http.Error String)
    | DataMovieListReceived (Result Http.Error (List Movie))
    | DataConfigReceived (Result Http.Error Config)
    | DataDuplicatesReceived (Result Http.Error (List Movie))
    | DataRecognitionErrorsReceived (Result Http.Error (List Movie))
    | DataMissingMoviesReceived (Result Http.Error (List File))
    | UpdateTags (List Movie)
    | QuickUpdateTags (List String)


type TheaterMsgs
    = SortTable SortBy
    | TitleFilter String
    | ToggleTagFilter String
    | ClearTagFilter
    | ToggleGenreFilter String
    | ClearGenreFilter
    | ToggleResolutionFilter (Maybe Resolution)
    | ChangeSeenFilter SeenFilter
    | DisplayTagsFor Int
    | StopDisplayTags
    | RemoveTag Int String
    | AddTag Int String


type HospitalMsgs
    = SickPoster Int
    | ToggleHospitalShow SickType
    | RefreshKodi
    | RefreshMovies (List Int)
    | SetStartLoadingTime Time.Posix
    | SetStartRefreshingTime Time.Posix


type SortBy
    = SortByTitle
    | SortByRating
    | SortByYear
    | SortBySet
    | SortByPlaycount
    | SortByDateAdded


type alias Config =
    { kodis : List Kodi
    , kodiOfInterest : Int
    }


type alias Kodi =
    { name : String
    , url : String
    }


type alias Movie =
    { id : Int
    , title : String
    , runtime : Int
    , premiered : String
    , dateadded : String
    , resolution : Maybe Resolution
    , poster : Maybe String
    , path : String
    , rating : Float
    , playcount : Int
    , set : Maybe String
    , tags : List String
    , genres : List String
    }


placeholderMovie : String -> Movie
placeholderMovie path =
    Movie
        -1
        ""
        0
        ""
        ""
        Nothing
        Nothing
        path
        0
        0
        Nothing
        []
        []


setMovieCard : Maybe String -> Movie
setMovieCard set_name =
    Movie
        -1
        (Maybe.withDefault "" set_name)
        0
        ""
        ""
        Nothing
        Nothing
        ""
        0
        0
        set_name
        []
        []


type Resolution
    = UHD_8k
    | UHD_4k
    | HD_1080p
    | HD_720p
    | SD


pathListDecoder : Decode.Decoder (List File)
pathListDecoder =
    Decode.list pathDecoder


type alias File =
    { path : String
    , label : String
    }


pathDecoder : Decode.Decoder File
pathDecoder =
    Decode.map2 File
        (Decode.field "path" Decode.string)
        (Decode.field "label" Decode.string)


configDecoder : Decode.Decoder Config
configDecoder =
    Decode.succeed Config
        |> required "kodis" (Decode.list kodiDecoder)
        |> hardcoded 0


kodiDecoder : Decode.Decoder Kodi
kodiDecoder =
    Decode.map2 Kodi
        (Decode.field "name" Decode.string)
        (Decode.field "url" Decode.string)


defaultKodi : Kodi
defaultKodi =
    Kodi "local" "localhost:8080"


movieListDecoder : Decode.Decoder (List Movie)
movieListDecoder =
    Decode.list movieDecoder


movieDecoder : Decode.Decoder Movie
movieDecoder =
    Decode.succeed Movie
        |> required "id" Decode.int
        |> required "title" Decode.string
        |> required "runtime" Decode.int
        |> required "premiered" Decode.string
        |> required "dateadded" Decode.string
        |> required "resolution" (Decode.nullable resolutionDecoder)
        |> required "poster" (Decode.nullable Decode.string)
        |> required "path" Decode.string
        |> required "rating" Decode.float
        |> required "playcount" Decode.int
        |> required "set" (Decode.nullable Decode.string)
        |> required "tags" (Decode.list Decode.string)
        |> required "genres" (Decode.list Decode.string)


resolutionDecoder : Decode.Decoder Resolution
resolutionDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "Sd" ->
                        Decode.succeed SD

                    "Hd720p" ->
                        Decode.succeed HD_720p

                    "Hd1080p" ->
                        Decode.succeed HD_1080p

                    "Uhd4k" ->
                        Decode.succeed UHD_4k

                    "Uhd8k" ->
                        Decode.succeed UHD_8k

                    somethingElse ->
                        Decode.fail <| "Unknown resolution: " ++ somethingElse
            )


handleJsonResponse : Decode.Decoder a -> Http.Response String -> Result Http.Error a
handleJsonResponse decoder response =
    case response of
        Http.BadUrl_ url ->
            Err (Http.BadUrl url)

        Http.Timeout_ ->
            Err Http.Timeout

        Http.BadStatus_ { statusCode } _ ->
            Err (Http.BadStatus statusCode)

        Http.NetworkError_ ->
            Err Http.NetworkError

        Http.GoodStatus_ _ body ->
            case Decode.decodeString decoder body of
                Err _ ->
                    Err (Http.BadBody body)

                Ok result ->
                    Ok result


buildErrorMessage : Http.Error -> String
buildErrorMessage httpError =
    case httpError of
        Http.BadUrl message ->
            message

        Http.Timeout ->
            "Server is taking too long to respond. Please try again later."

        Http.NetworkError ->
            "Unable to reach server."

        Http.BadStatus statusCode ->
            "Request failed with status code: " ++ String.fromInt statusCode

        Http.BadBody message ->
            "Error: " ++ message
