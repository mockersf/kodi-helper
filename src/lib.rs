use hocon;
use lazy_static::lazy_static;
use serde::{Deserialize, Serialize};
use tracing::instrument;

pub mod api;
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
    pub tags: Vec<String>,
    pub genres: Vec<String>,
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
    movie_list: actix_web::web::Data<std::sync::RwLock<Vec<Movie>>>,
) -> actix_web::web::Data<std::sync::RwLock<Vec<Movie>>> {
    if let Ok(new_movie_list) = kodi_rpc::KodiRPC::new(&CONFIG.kodis[0].url)
        .get_all_movies()
        .await
    {
        *movie_list.write().unwrap() = movie_list_cleanup(new_movie_list);
    }

    movie_list
}
