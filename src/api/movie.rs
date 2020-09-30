use actix_web::{web, HttpResponse};
use tracing::instrument;

use crate::{kodi_rpc, Movie, CONFIG};

#[instrument(level = "info")]
pub async fn refresh_movie(movie_id: web::Path<u16>) -> HttpResponse {
    let config = CONFIG.read().unwrap();

    let kodi_rpc = kodi_rpc::KodiRPC::new(&config.kodis[0].url);
    if let Err(err) = kodi_rpc.refresh_movie(*movie_id).await {
        HttpResponse::InternalServerError().json(format!("error: {}", err))
    } else {
        HttpResponse::Ok().json("ok")
    }
}

#[instrument(skip(movie_list), level = "info")]
pub async fn set_movie_tags(
    movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
    movie_id: web::Path<u16>,
    tags: web::Json<Vec<String>>,
) -> HttpResponse {
    let mut movie_list = movie_list.write().unwrap();

    *movie_list = movie_list
        .iter()
        .map(|movie| {
            if movie.id == *movie_id {
                let mut movie = movie.clone();
                movie.tags = tags.clone();
                movie
            } else {
                movie.clone()
            }
        })
        .collect();

    let config = CONFIG.read().unwrap();
    let kodi_rpc = kodi_rpc::KodiRPC::new(&config.kodis[0].url);
    if let Err(err) = kodi_rpc.set_movie_details(*movie_id, (*tags).clone()).await {
        HttpResponse::InternalServerError().json(format!("error: {}", err))
    } else {
        HttpResponse::Ok().json("ok")
    }
}
