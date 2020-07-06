use actix_web::{web, HttpResponse};
use hocon;
use lazy_static::lazy_static;
use serde::{Deserialize, Serialize};
use tracing::{event, instrument, Level};

pub mod kodi_rpc;

lazy_static! {
    static ref CONFIG: Config = {
        let config: Config = hocon::HoconLoader::default()
            .load_file("config.conf")
            .and_then(hocon::HoconLoader::resolve)
            .unwrap();
        // check that patterns are OK at loadtime
        for regex in config.filepatterns_to_ignore
            .iter()
            .map(|pattern| regex::Regex::new(pattern)) {
            regex.unwrap();
        }

        config
    };
    static ref MOVIE_FILE: regex::Regex = regex::Regex::new(
        &format!("^{}(?P<title>.+?)( (?P<year>[0-9]{{4}})\\.[a-z0-9]{{3,4}}$|\\.[a-z0-9]{{3,4}}$)", CONFIG.movies_directory)
    )
    .unwrap();
}

#[derive(Deserialize, Serialize, Clone, Debug)]
struct Config {
    pub kodis: Vec<Kodi>,
    pub filepatterns_to_ignore: Vec<String>,
    pub movies_directory: String,
    pub name_differences_threshold: Option<usize>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
struct Kodi {
    pub name: String,
    pub url: String,
}

#[derive(Serialize, Clone, Debug)]
pub enum Resolution {
    Sd,
    Hd720p,
    Hd1080p,
    Uhd4k,
    Uhd8k,
}

#[derive(Serialize, Clone, Debug)]
pub struct Movie {
    pub id: u16,
    pub title: String,
    pub runtime: u16,
    pub path: String,
    pub premiered: String,
    pub resolution: Option<Resolution>,
    pub poster: Option<String>,
    pub rating: f32,
    pub playcount: u8,
    pub set: Option<String>,
    pub dateadded: String,
}

#[derive(Serialize, Clone, Debug)]
pub struct File {
    pub path: String,
    pub label: String,
}

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
pub async fn get_unrecognized_movies(
    movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
) -> HttpResponse {
    let ignored_patterns = CONFIG
        .filepatterns_to_ignore
        .iter()
        .map(|pattern| regex::Regex::new(pattern).unwrap())
        .collect::<Vec<_>>();
    if let Ok(files) = kodi_rpc::KodiRPC::new(&CONFIG.kodis[0].url)
        .get_all_files(&CONFIG.movies_directory)
        .await
    {
        let known_files: Vec<_> = movie_list
            .read()
            .unwrap()
            .iter()
            .map(|m| m.path.clone())
            .collect();

        let missing = files
            .into_iter()
            .filter(|f| {
                for pattern in ignored_patterns.iter() {
                    if pattern.is_match(&f.path) {
                        return false;
                    }
                }
                return true;
            })
            .filter(|f| !known_files.contains(&f.path))
            .collect::<Vec<_>>();

        event!(Level::INFO, "found missing movies: {}", missing.len());

        HttpResponse::Ok().json(missing)
    } else {
        HttpResponse::InternalServerError().json("err")
    }
}

#[instrument(skip(movie_list), level = "info")]
pub fn get_movie_list(movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>) -> HttpResponse {
    let readable_movie_list = movie_list.read().unwrap();
    HttpResponse::Ok().json(readable_movie_list.clone())
}

#[instrument(skip(movie_list), level = "info")]
pub fn get_duplicate_movies_list(
    movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
) -> HttpResponse {
    let readable_movie_list = movie_list.read().unwrap().clone();

    let dups: Vec<Movie> = readable_movie_list
        .into_iter()
        .map(|movie| {
            (
                movie.clone(),
                MOVIE_FILE
                    .captures(&movie.path)
                    .and_then(|c| c.name("year"))
                    .map(|m| m.as_str().to_string()),
            )
        })
        .fold(
            std::collections::HashMap::new(),
            |mut map, (movie, year)| {
                map.entry(movie.title.clone())
                    .or_insert_with(|| Vec::new())
                    .push((movie, year));
                map
            },
        )
        .iter()
        .filter(|(_, m_y)| {
            let years: Vec<Option<String>> = m_y.iter().map(|(_, y)| y.clone()).collect();
            years.len() != 1
                && years.len()
                    != years
                        .iter()
                        .filter_map(|y| y.clone())
                        .fold(std::collections::HashSet::new(), |mut set, year| {
                            set.insert(year);
                            set
                        })
                        .len()
        })
        .map(|(_, m_y)| m_y.iter().map(|(m, _)| m.clone()).collect::<Vec<_>>())
        .flatten()
        .collect();

    event!(Level::INFO, "found duplicates: {}", dups.len());
    HttpResponse::Ok().json(dups)
}

#[instrument(skip(movie_list), level = "info")]
pub fn get_recognition_errors_list(
    movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
) -> HttpResponse {
    let readable_movie_list = movie_list.read().unwrap().clone();

    let diffs: Vec<Movie> = readable_movie_list
        .into_iter()
        .map(|movie| {
            (
                movie.clone(),
                MOVIE_FILE
                    .captures(&movie.path)
                    .map(|c| {
                        (
                            c.name("title")
                                .map(|mt| mt.as_str().to_string())
                                .unwrap_or_else(|| String::from("")),
                            c.name("year")
                                .map(|my| my.as_str().to_string())
                                .unwrap_or_else(|| String::from("")),
                        )
                    })
                    .unwrap_or_else(|| (String::from(""), String::from(""))),
            )
        })
        .filter(|(movie, (title, year))| {
            strsim::levenshtein(&movie.title, title)
                > CONFIG.name_differences_threshold.unwrap_or(3)
                || !movie.premiered.starts_with(year)
        })
        .map(|(movie, _)| movie)
        .collect();

    event!(Level::INFO, "found recognition errors: {}", diffs.len());
    HttpResponse::Ok().json(diffs)
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

#[instrument(skip(_movie_list), level = "info")]
pub async fn refresh_movie(
    _movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
    movie_id: web::Path<u16>,
) -> HttpResponse {
    let kodi_rpc = kodi_rpc::KodiRPC::new(&CONFIG.kodis[0].url);
    if let Err(err) = kodi_rpc.refresh_movie(*movie_id).await {
        HttpResponse::InternalServerError().json(format!("error: {}", err))
    } else {
        HttpResponse::Ok().json("ok")
    }
}

#[instrument(level = "info")]
pub fn get_config() -> HttpResponse {
    HttpResponse::Ok().json(CONFIG.clone())
}
