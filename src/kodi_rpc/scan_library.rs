use tracing::{event, instrument, Level};

use super::*;

impl KodiRPC {
    #[instrument(err, level = "info")]
    pub async fn scan_video_library(&self) -> Result<(), Box<dyn std::error::Error>> {
        event!(Level::TRACE, "Preparing RPC request to start scan");
        self.send_rpc_request::<(), String>(&JsonRPCRequest {
            jsonrpc: "2.0".to_string(),
            id: 1,
            method: "VideoLibrary.Scan".to_string(),
            params: None,
        })
        .await?;
        Ok(())
    }

    #[instrument(err, level = "info")]
    pub async fn scan_video_library_and_wait_for_done(
        &self,
    ) -> Result<(), Box<dyn std::error::Error>> {
        event!(Level::TRACE, "Preparing RPC request to start scan");
        self.scan_video_library().await?;
        event!(Level::DEBUG, "Scanning Kodi Library");
        loop {
            actix_rt::time::delay_for(std::time::Duration::new(5, 0)).await;
            event!(Level::TRACE, "Preparing RPC request to check scan status");
            if let Some(false) = self
                .get_info_boolean(vec!["Library.IsScanningVideo".to_string()])
                .await?
                .get("Library.IsScanningVideo")
            {
                break;
            }
        }
        event!(Level::INFO, "Scanned Kodi Library");

        Ok(())
    }
}
