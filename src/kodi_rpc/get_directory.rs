use serde::{Deserialize, Serialize};
use tracing::{event, instrument, Level};

use super::*;

#[derive(Serialize, Clone, Debug)]
struct JsonRPCGetDirectoryRequestParams {
    directory: String,
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

impl KodiRPC {
    #[instrument(err, level = "info")]
    pub async fn get_directory(
        &self,
        path: &str,
    ) -> Result<Vec<crate::File>, Box<dyn std::error::Error>> {
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
            .map(|f| crate::File {
                path: f.file,
                label: f.label,
            })
            .collect::<Vec<_>>();

        Ok(files)
    }
}
