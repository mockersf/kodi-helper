use lazy_static::lazy_static;
use serde::{Deserialize, Serialize};
use tracing::instrument;

pub mod api;
pub mod kodi_rpc;

lazy_static! {
    pub static ref CONFIG: std::sync::Arc<std::sync::RwLock<Config>> =
        std::sync::Arc::new(std::sync::RwLock::new(Config::default()));
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct Config {
    pub kodis: Vec<Kodi>,
    pub filepatterns_to_ignore: Vec<String>,
    pub movies_directory: String,
    pub name_differences_threshold: Option<usize>,
    #[serde(default = "get_default_movie_pattern")]
    pub movie_pattern: String,
}

fn get_default_movie_pattern() -> String {
    "(?P<title>.+?)( (?P<year>[0-9]{4})\\.[a-z0-9]{3,4}$|\\.[a-z0-9]{3,4}$)".to_string()
}

impl Default for Config {
    fn default() -> Self {
        Config {
            kodis: vec![Kodi {
                name: "localhost".to_string(),
                url: "http://localhost:8080".to_string(),
            }],
            filepatterns_to_ignore: vec![],
            movies_directory: "/movies/".to_string(),
            name_differences_threshold: None,
            movie_pattern: get_default_movie_pattern(),
        }
    }
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct Kodi {
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
    pub cast: Vec<Cast>,
}

#[derive(Serialize, Clone, Debug)]
pub struct Cast {
    name: String,
    role: String,
    thumbnail: Option<String>,
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
    let config = CONFIG.read().unwrap();

    if let Ok(new_movie_list) = kodi_rpc::KodiRPC::new(&config.kodis[0].url)
        .get_all_movies()
        .await
    {
        *movie_list.write().unwrap() = movie_list_cleanup(new_movie_list);
    }

    movie_list
}
