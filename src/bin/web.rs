use actix_files::Files;
use actix_web::{middleware, web, App, HttpServer};
use tracing::{event, Level};
use tracing_subscriber;

#[actix_rt::main]
async fn main() -> std::io::Result<()> {
    let _subscriber = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    event!(Level::INFO, "Starting");

    let movie_list: web::Data<std::sync::RwLock<Vec<kodi_helper::Movie>>> =
        web::Data::new(std::sync::RwLock::new(vec![]));

    let init = kodi_helper::api::movies::update_movie_list(movie_list.clone());

    let server = HttpServer::new(move || {
        App::new()
            .app_data(movie_list.clone())
            .wrap(middleware::Logger::default())
            // API
            .service(web::resource("/api/config").to(kodi_helper::api::config::get_config))
            .service(
                web::resource("/api/movies")
                    .route(web::get().to(kodi_helper::api::movies::get_movie_list))
                    .route(web::delete().to(kodi_helper::api::movies::clean_and_scan_kodi_library))
                    .route(web::put().to(kodi_helper::api::movies::update_movie_list)),
            )
            .service(
                web::resource("/api/movies/{movie_id}")
                    .route(web::delete().to(kodi_helper::api::movie::refresh_movie))
                    .route(web::put().to(kodi_helper::api::movie::set_movie_tags)),
            )
            .service(
                web::resource("/api/errors/duplicates")
                    .to(kodi_helper::api::errors::get_duplicate_movies_list),
            )
            .service(
                web::resource("/api/errors/recognition")
                    .to(kodi_helper::api::errors::get_recognition_errors_list),
            )
            .service(
                web::resource("/api/errors/missing")
                    .to(kodi_helper::api::errors::get_unrecognized_movies),
            )
            // UI
            .service(Files::new("/ui/{tail:.*}", "./static/").index_file("index.html"))
            .service(Files::new("/static", "./static/").index_file("index.html"))
    })
    .bind("0.0.0.0:8080")?
    .run();
    futures::future::join(server, init).await.0
}
