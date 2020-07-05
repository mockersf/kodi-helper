use tracing::{event, instrument, Level};

use super::*;

impl KodiRPC {
    #[instrument(err, level = "info")]
    pub async fn clean_video_library(&self) -> Result<(), Box<dyn std::error::Error>> {
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
}
