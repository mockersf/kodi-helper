use serde::{Deserialize, Serialize};
use tracing::{event, instrument, Level};

pub struct KodiRPC {
    client: reqwest::Client,
    host: String,
}

impl std::fmt::Debug for KodiRPC {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("KodiRPC").field("host", &self.host).finish()
    }
}

#[derive(Serialize, Clone, Debug)]
struct JsonRPCRequestLimits {
    end: u16,
}

#[derive(Serialize, Clone, Debug)]
struct JsonRPCGetDirectoryRequestParams {
    directory: String,
}

#[derive(Serialize, Clone, Debug)]
struct JsonRPCGetMoviesRequestParams {
    properties: Vec<String>,
    limits: Option<JsonRPCRequestLimits>,
}

#[derive(Serialize, Clone, Debug)]
struct JsonRPCGetInfoBooleansRequestParams {
    booleans: Vec<String>,
}

#[derive(Serialize, Clone, Debug)]
struct JsonRPCRefreshMovieRequestParams {
    movieid: u16,
}

#[derive(Serialize, Clone, Debug)]
struct JsonRPCRequest<T> {
    jsonrpc: String,
    id: u16,
    method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    params: Option<T>,
}

#[derive(Deserialize, Clone, Debug)]
#[serde(deny_unknown_fields)]
struct MoviesArtResponse {
    thumb: Option<String>,
    fanart: Option<String>,
    poster: Option<String>,
    #[serde(rename = "set.fanart")]
    set_fanart: Option<String>,
    #[serde(rename = "set.poster")]
    set_poster: Option<String>,
    #[serde(rename = "set.thumb")]
    set_thumb: Option<String>,
}

#[derive(Deserialize, Clone, Debug)]
#[serde(deny_unknown_fields)]
struct MoviesAudioStreamDetailsResponse {
    channels: u8,
    codec: String,
    language: String,
}
#[derive(Deserialize, Clone, Debug)]
#[serde(deny_unknown_fields)]
struct MoviesSubtitleStreamDetailsResponse {
    language: String,
}
#[derive(Deserialize, Clone, Debug)]
#[serde(deny_unknown_fields)]
struct MoviesVideoStreamDetailsResponse {
    aspect: f32,
    codec: String,
    duration: u16,
    height: u16,
    width: u16,
    language: String,
    stereomode: String,
}

#[derive(Deserialize, Clone, Debug)]
#[serde(deny_unknown_fields)]
struct MoviesStreamDetailsResponse {
    audio: Vec<MoviesAudioStreamDetailsResponse>,
    video: Vec<MoviesVideoStreamDetailsResponse>,
    subtitle: Vec<MoviesSubtitleStreamDetailsResponse>,
}

#[derive(Deserialize, Clone, Debug)]
#[serde(deny_unknown_fields)]
struct MovieDetailsResponse {
    art: MoviesArtResponse,
    label: String,
    movieid: u16,
    runtime: u16,
    title: String,
    file: String,
    premiered: String,
    rating: f32,
    playcount: u8,
    set: String,
    dateadded: String,
    streamdetails: MoviesStreamDetailsResponse,
}

#[derive(Deserialize, Clone, Debug)]
struct MoviesResponse {
    movies: Vec<MovieDetailsResponse>,
}

#[derive(Deserialize, Clone, Debug)]
struct File {
    file: String,
    filetype: String,
    label: String,
    #[serde(rename = "type")]
    ty: String,
}

#[derive(Deserialize, Clone, Debug)]
struct DirectoryResponse {
    files: Vec<File>,
}

#[derive(Deserialize, Clone, Debug)]
struct InfoBooleansResponse {
    #[serde(rename = "Library.IsScanningVideo")]
    library_is_scanning_video: bool,
}

#[derive(Deserialize, Clone, Debug)]
#[serde(untagged)]
enum JsonRPCResponse<T> {
    Success { result: T },
    Error { error: JsonRPCError },
}

#[derive(Deserialize, Clone, Debug)]
struct JsonRPCErrorData {
    message: String,
    method: String,
}
#[derive(Deserialize, Clone, Debug)]
struct JsonRPCError {
    message: String,
    data: Option<JsonRPCErrorData>,
}
impl std::fmt::Display for JsonRPCError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if let Some(ref data) = self.data {
            write!(
                f,
                "{} when calling {}: {}",
                self.message, data.method, data.message
            )
        } else {
            write!(f, "{} ", self.message)
        }
    }
}
impl std::error::Error for JsonRPCError {}

impl KodiRPC {
    /// Create a new Kodi RPC client
    pub fn new(host: &str) -> KodiRPC {
        KodiRPC {
            client: reqwest::Client::new(),
            host: host.to_string(),
        }
    }

    /// Send RPC request
    #[instrument(err, level = "info")]
    async fn send_rpc_request<Params, Resp>(
        &self,
        request: &JsonRPCRequest<Params>,
    ) -> Result<Resp, Box<dyn std::error::Error>>
    where
        Params: Serialize + std::fmt::Debug,
        for<'de> Resp: Deserialize<'de>,
    {
        event!(Level::TRACE, "Preparing RPC request");

        // event!(
        //     Level::INFO,
        //     "request to send: {:?}",
        //     serde_json::to_string(request)
        // );
        let mut request = self
            .client
            .post(&format!("{}jsonrpc", self.host))
            .json(request)
            .build()?;
        let headers = request.headers_mut();

        headers.insert(
            "Content-Type",
            reqwest::header::HeaderValue::from_static("application/json"),
        );
        event!(Level::TRACE, "Sending RPC Request");
        let data = self
            .client
            .execute(request)
            .await?
            .json::<JsonRPCResponse<Resp>>()
            // .text()
            .await?;
        event!(Level::TRACE, "done");

        // event!(Level::INFO, "response received: {:?}", data);
        // let data: JsonRPCResponse<Resp> = serde_json::from_str(&data)?;
        match data {
            JsonRPCResponse::Success { result } => Ok(result),
            JsonRPCResponse::Error { error } => {
                event!(Level::ERROR, "Error sending JsonRPC Request: {}", error,);
                Err(error)?
            }
        }
    }

    #[instrument(err, level = "info")]
    pub async fn get_all_movies(&self) -> Result<Vec<super::Movie>, Box<dyn std::error::Error>> {
        event!(Level::TRACE, "Preparing RPC request");
        let data = self
            .send_rpc_request::<JsonRPCGetMoviesRequestParams, MoviesResponse>(&JsonRPCRequest {
                jsonrpc: "2.0".to_string(),
                id: 1,
                method: "VideoLibrary.GetMovies".to_string(),
                params: Some(JsonRPCGetMoviesRequestParams {
                    properties: vec![
                        "art".to_string(),
                        "title".to_string(),
                        "runtime".to_string(),
                        "streamdetails".to_string(),
                        "file".to_string(),
                        "premiered".to_string(),
                        "rating".to_string(),
                        "playcount".to_string(),
                        "set".to_string(),
                        "dateadded".to_string(),
                    ],
                    limits: Some(JsonRPCRequestLimits { end: 10000 }),
                }),
            })
            .await?;
        event!(Level::INFO, "found movies: {}", data.movies.len());

        let mut movies: Vec<super::Movie> = data
            .movies
            .iter()
            .map(|movie| {
                let resolution = movie.streamdetails.video.get(0).map(|stream| {
                    if stream.height < 600 {
                        super::Resolution::Sd
                    } else if stream.height <= 720 {
                        super::Resolution::Hd720p
                    } else if stream.height <= 1080 {
                        super::Resolution::Hd1080p
                    } else if stream.height <= 2160 {
                        super::Resolution::Uhd4k
                    } else {
                        super::Resolution::Uhd8k
                    }
                });

                super::Movie {
                    id: movie.movieid,
                    title: movie.title.clone(),
                    runtime: movie.runtime,
                    path: movie.file.clone(),
                    premiered: movie.premiered.clone(),
                    dateadded: movie.dateadded.clone(),
                    resolution,
                    poster: movie
                        .art
                        .poster
                        .as_ref()
                        .map(|url| {
                            percent_encoding::percent_encode(
                                url.as_bytes(),
                                percent_encoding::NON_ALPHANUMERIC,
                            )
                            .to_string()
                        })
                        .clone(),
                    rating: movie.rating,
                    playcount: movie.playcount,
                    set: match movie.set.as_ref() {
                        "" => None,
                        set => Some(set.to_string()),
                    },
                }
            })
            .collect();

        movies.sort_by(|a, b| a.title.cmp(&b.title));
        Ok(movies)
    }

    #[instrument(err, level = "info")]
    pub async fn clean_library(&self) -> Result<(), Box<dyn std::error::Error>> {
        event!(Level::TRACE, "Preparing RPC request");
        self.send_rpc_request::<(), String>(&JsonRPCRequest {
            jsonrpc: "2.0".to_string(),
            id: 1,
            method: "VideoLibrary.Clean".to_string(),
            params: None,
        })
        .await?;
        event!(Level::INFO, "Cleaned Kodi Library");

        Ok(())
    }

    #[instrument(err, level = "info")]
    pub async fn scan_library(&self) -> Result<(), Box<dyn std::error::Error>> {
        event!(Level::TRACE, "Preparing RPC request to start scan");
        self.send_rpc_request::<(), String>(&JsonRPCRequest {
            jsonrpc: "2.0".to_string(),
            id: 1,
            method: "VideoLibrary.Scan".to_string(),
            params: None,
        })
        .await?;
        event!(Level::DEBUG, "Scanning Kodi Library");
        loop {
            event!(Level::TRACE, "Preparing RPC request to check scan status");
            let data = self
                .send_rpc_request::<JsonRPCGetInfoBooleansRequestParams, InfoBooleansResponse>(
                    &JsonRPCRequest {
                        jsonrpc: "2.0".to_string(),
                        id: 1,
                        method: "XBMC.GetInfoBooleans".to_string(),
                        params: Some(JsonRPCGetInfoBooleansRequestParams {
                            booleans: vec!["Library.IsScanningVideo".to_string()],
                        }),
                    },
                )
                .await?;
            if !data.library_is_scanning_video {
                break;
            }
            actix_rt::time::delay_for(std::time::Duration::new(5, 0)).await;
        }
        event!(Level::INFO, "Scanned Kodi Library");

        Ok(())
    }

    #[instrument(err, level = "info")]
    pub async fn refresh_movie(&self, movie_id: u16) -> Result<(), Box<dyn std::error::Error>> {
        event!(Level::TRACE, "Preparing RPC request");
        self.send_rpc_request::<JsonRPCRefreshMovieRequestParams, String>(&JsonRPCRequest {
            jsonrpc: "2.0".to_string(),
            id: 1,
            method: "VideoLibrary.RefreshMovie".to_string(),
            params: Some(JsonRPCRefreshMovieRequestParams { movieid: movie_id }),
        })
        .await?;
        event!(Level::INFO, "Refreshed movie {}", movie_id);

        Ok(())
    }

    #[instrument(err, level = "info")]
    pub async fn get_all_files(
        &self,
        path: &str,
    ) -> Result<Vec<super::File>, Box<dyn std::error::Error>> {
        event!(Level::TRACE, "Preparing RPC request");
        let data = self
            .send_rpc_request::<JsonRPCGetDirectoryRequestParams, DirectoryResponse>(
                &JsonRPCRequest {
                    jsonrpc: "2.0".to_string(),
                    id: 1,
                    method: "Files.GetDirectory".to_string(),
                    params: Some(JsonRPCGetDirectoryRequestParams {
                        directory: path.to_string(),
                    }),
                },
            )
            .await?;
        event!(Level::INFO, "found files: {}", data.files.len());

        let files = data
            .files
            .into_iter()
            .map(|f| super::File {
                path: f.file,
                label: f.label,
            })
            .collect::<Vec<_>>();

        Ok(files)
    }
}
