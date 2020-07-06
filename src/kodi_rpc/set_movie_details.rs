use serde::Serialize;
use tracing::{event, instrument, Level};

use super::*;

#[derive(Serialize, Clone, Debug)]
struct JsonRPCSetMovieDetailRequestParams {
    movieid: u16,
    tag: Vec<String>,
}

impl KodiRPC {
    #[instrument(err, level = "info")]
    pub async fn set_movie_details(
        &self,
        movie_id: u16,
        tags: Vec<String>,
    ) -> Result<String, Box<dyn std::error::Error>> {
        event!(Level::TRACE, "Preparing RPC request");
        let data = self
            .send_rpc_request::<JsonRPCSetMovieDetailRequestParams, String>(&JsonRPCRequest {
                jsonrpc: "2.0".to_string(),
                id: 1,
                method: "VideoLibrary.SetMovieDetails".to_string(),
                params: Some(JsonRPCSetMovieDetailRequestParams {
                    movieid: movie_id,
                    tag: tags,
                }),
            })
            .await?;
        event!(Level::INFO, "set movie details: {}", data);

        Ok(data)
    }
}
