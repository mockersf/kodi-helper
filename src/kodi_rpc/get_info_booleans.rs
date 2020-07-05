use serde::{Deserialize, Serialize};
use tracing::{event, instrument, Level};

use super::*;

#[derive(Serialize, Clone, Debug)]
struct JsonRPCGetInfoBooleansRequestParams {
    booleans: Vec<String>,
}

#[derive(Deserialize, Clone, Debug)]
struct InfoBooleansResponse {
    #[serde(rename = "Library.IsScanningVideo")]
    library_is_scanning_video: bool,
}

impl KodiRPC {
    #[instrument(err, level = "info")]
    pub async fn get_info_boolean(
        &self,
        info_booleans: Vec<String>,
    ) -> Result<std::collections::HashMap<String, bool>, Box<dyn std::error::Error>> {
        event!(Level::TRACE, "Preparing RPC request to get info boolean");
        let data = self
            .send_rpc_request::<JsonRPCGetInfoBooleansRequestParams, InfoBooleansResponse>(
                &JsonRPCRequest {
                    jsonrpc: "2.0".to_string(),
                    id: 1,
                    method: "XBMC.GetInfoBooleans".to_string(),
                    params: Some(JsonRPCGetInfoBooleansRequestParams {
                        booleans: info_booleans.clone(),
                    }),
                },
            )
            .await?;

        let mut result = std::collections::HashMap::new();
        info_booleans.into_iter().for_each(|b| match b.as_ref() {
            "Library.IsScanningVideo" => {
                result.insert(b, data.library_is_scanning_video);
            }
            _ => (),
        });
        Ok(result)
    }
}
