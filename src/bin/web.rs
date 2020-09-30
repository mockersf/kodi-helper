#![type_length_limit = "2275484"]

use actix_files::Files;
use actix_web::{middleware, web, App, HttpServer};
use clap::Clap;
use tracing::instrument;
use tracing::{event, Level};
use tracing_subscriber;

#[derive(Clap)]
#[clap(version = "1.0", author = "François")]
struct CliOpts {
    /// conf path
    #[clap(short = 'c', long = "config", default_value = "config.conf")]
    config: String,
}

#[actix_rt::main]
async fn main() -> std::io::Result<()> {
    let _subscriber = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    load_config();
    event!(Level::INFO, "Starting");

    let movie_list: web::Data<std::sync::RwLock<Vec<kodi_helper::Movie>>> =
        web::Data::new(std::sync::RwLock::new(vec![]));

    let mut refresh_interval = actix_rt::time::interval(std::time::Duration::from_secs(60 * 30));

    let server = setup_server(movie_list.clone())?;
    futures::pin_mut!(server);

    loop {
        let next_tick = futures::future::join(
            refresh_movie_list(movie_list.clone()),
            refresh_interval.tick(),
        );
        futures::pin_mut!(next_tick);
        let running = futures::future::select(server, next_tick);
        match running.await {
            futures::future::Either::Left(_) => break,
            futures::future::Either::Right((_, server_fut)) => {
                server = server_fut;
            }
        }
    }
    Ok(())
}

fn load_config() {
    let cli_opts: CliOpts = CliOpts::parse();
    let loaded_config: kodi_helper::Config = hocon::HoconLoader::new()
        .load_file(&cli_opts.config)
        .and_then(|hc| hc.resolve())
        .unwrap();
    let mut config = kodi_helper::CONFIG.write().unwrap();
    *config = loaded_config;
}

#[instrument(skip(movie_list), level = "info")]
async fn refresh_movie_list(movie_list: web::Data<std::sync::RwLock<Vec<kodi_helper::Movie>>>) {
    kodi_helper::update_movie_list(movie_list.clone()).await;
}

fn setup_server(
    movie_list: web::Data<std::sync::RwLock<Vec<kodi_helper::Movie>>>,
) -> std::io::Result<actix_web::dev::Server> {
    Ok(HttpServer::new(move || {
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
            .service(Files::new("/static", "./static/").index_file("index.html"))
            .service(Files::new("/{tail:.*}", "./static/").index_file("index.html"))
    })
    .bind("0.0.0.0:8080")?
    .run())
}
