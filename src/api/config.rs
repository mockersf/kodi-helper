use actix_web::HttpResponse;
use tracing::instrument;

use crate::CONFIG;

#[instrument(level = "info")]
pub fn get_config() -> HttpResponse {
    HttpResponse::Ok().json(CONFIG.read().unwrap().clone())
}
