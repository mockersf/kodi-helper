use actix_web::{web, HttpResponse};
use tracing::{event, instrument, Level};

use crate::{kodi_rpc, Movie, CONFIG};

#[instrument(skip(movie_list), level = "info")]
pub async fn update_movie_list(
    movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
) -> HttpResponse {
    let movie_list = crate::update_movie_list(movie_list).await;

    get_movie_list(movie_list)
}

#[instrument(skip(movie_list), level = "info")]
pub fn get_movie_list(movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>) -> HttpResponse {
    let readable_movie_list = movie_list.read().unwrap();
    HttpResponse::Ok().json(readable_movie_list.clone())
}

#[instrument(skip(movie_list), level = "info")]
pub async fn clean_and_scan_kodi_library(
    movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
) -> HttpResponse {
    event!(Level::INFO, "starting");
    let kodi_rpc = kodi_rpc::KodiRPC::new(&CONFIG.kodis[0].url);
    if let Err(_) = kodi_rpc.clean_video_library().await {
        HttpResponse::InternalServerError().json("err")
    } else if let Err(_) = kodi_rpc.scan_video_library_and_wait_for_done().await {
        HttpResponse::InternalServerError().json("err")
    } else {
        update_movie_list(movie_list).await
    }
}
