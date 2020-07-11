use actix_web::{web, HttpResponse};
use tracing::{event, instrument, Level};

use crate::{kodi_rpc, Movie, CONFIG};

pub fn movie_list_cleanup(movie_list: Vec<Movie>) -> Vec<Movie> {
    let set_list = movie_list
        .iter()
        .filter_map(|movie| movie.set.as_ref())
        .cloned()
        .fold(std::collections::HashMap::new(), |mut map, set| {
            let count = map.entry(set).or_insert_with(|| 0);
            *count += 1;
            map
        })
        .iter()
        .filter_map(|(set, count)| if *count > 1 { Some(set.clone()) } else { None })
        .collect::<Vec<_>>();

    //TODO: cleanup path, only keep filename?
    movie_list
        .into_iter()
        .map(|mut movie| {
            if let Some(set) = movie.set.as_ref() {
                if !set_list.contains(&&set) {
                    movie.set = None;
                }
            }
            movie
        })
        .collect::<Vec<_>>()
}

#[instrument(skip(movie_list), level = "info")]
pub async fn update_movie_list(
    movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
) -> HttpResponse {
    if let Ok(new_movie_list) = kodi_rpc::KodiRPC::new(&CONFIG.kodis[0].url)
        .get_all_movies()
        .await
    {
        *movie_list.write().unwrap() = movie_list_cleanup(new_movie_list);
    }

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
