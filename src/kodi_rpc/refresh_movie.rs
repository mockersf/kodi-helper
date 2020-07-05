use serde::Serialize;
use tracing::{event, instrument, Level};

use super::*;

#[derive(Serialize, Clone, Debug)]
struct JsonRPCRefreshMovieRequestParams {
    movieid: u16,
}

impl KodiRPC {
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
}
