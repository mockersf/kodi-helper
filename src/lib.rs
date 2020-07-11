use hocon;
use lazy_static::lazy_static;
use serde::{Deserialize, Serialize};

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
