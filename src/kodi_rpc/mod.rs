use serde::{Deserialize, Serialize};
use tracing::{event, instrument, Level};

mod clean_video_library;
mod get_directory;
mod get_info_booleans;
mod get_movies;
mod refresh_movie;
mod scan_library;
mod set_movie_details;

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
struct JsonRPCRequest<T> {
    jsonrpc: String,
    id: u16,
    method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    params: Option<T>,
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
}
