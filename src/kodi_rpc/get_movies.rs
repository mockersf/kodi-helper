use serde::{Deserialize, Serialize};
use tracing::{event, instrument, Level};

use super::*;

#[derive(Serialize, Clone, Debug)]
struct JsonRPCRequestLimits {
    end: u16,
}

#[derive(Serialize, Clone, Debug)]
struct JsonRPCGetMoviesRequestParams {
    properties: Vec<String>,
    limits: Option<JsonRPCRequestLimits>,
}

#[derive(Deserialize, Clone, Debug)]
#[serde(deny_unknown_fields)]
struct MoviesArtResponse {
    icon: Option<String>,
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
    tag: Vec<String>,
    genre: Vec<String>,
    streamdetails: MoviesStreamDetailsResponse,
    cast: Vec<CastMemberResponse>,
}

#[derive(Deserialize, Clone, Debug)]
#[serde(deny_unknown_fields)]
struct CastMemberResponse {
    name: String,
    order: u16,
    role: String,
    thumbnail: Option<String>,
}

#[derive(Deserialize, Clone, Debug)]
struct MoviesResponse {
    movies: Vec<MovieDetailsResponse>,
}

impl KodiRPC {
    #[instrument(err, level = "info")]
    pub async fn get_all_movies(&self) -> Result<Vec<crate::Movie>, Box<dyn std::error::Error>> {
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
                        "tag".to_string(),
                        "genre".to_string(),
                        "cast".to_string(),
                    ],
                    limits: Some(JsonRPCRequestLimits { end: 10000 }),
                }),
            })
            .await?;
        event!(Level::INFO, "found movies: {}", data.movies.len());

        let mut movies: Vec<crate::Movie> = data
            .movies
            .into_iter()
            .map(|movie| {
                let resolution = movie.streamdetails.video.get(0).map(|stream| {
                    if stream.height < 600 {
                        crate::Resolution::Sd
                    } else if stream.height <= 720 {
                        crate::Resolution::Hd720p
                    } else if stream.height <= 1080 {
                        crate::Resolution::Hd1080p
                    } else if stream.height <= 2160 {
                        crate::Resolution::Uhd4k
                    } else {
                        crate::Resolution::Uhd8k
                    }
                });

                crate::Movie {
                    id: movie.movieid,
                    title: movie.title,
                    runtime: movie.runtime,
                    path: movie.file,
                    premiered: movie.premiered,
                    dateadded: movie.dateadded,
                    resolution,
                    poster: movie.art.poster.map(|url| {
                        percent_encoding::percent_encode(
                            url.as_bytes(),
                            percent_encoding::NON_ALPHANUMERIC,
                        )
                        .to_string()
                    }),
                    rating: movie.rating,
                    playcount: movie.playcount,
                    set: match movie.set.as_ref() {
                        "" => None,
                        set => Some(set.to_string()),
                    },
                    tags: movie.tag,
                    genres: movie.genre,
                    cast: movie
                        .cast
                        .into_iter()
                        .map(|cast| crate::Cast {
                            name: cast.name,
                            role: cast.role,
                            thumbnail: cast.thumbnail,
                        })
                        .collect(),
                }
            })
            .collect();

        movies.sort_by(|a, b| a.title.cmp(&b.title));
        Ok(movies)
    }
}
