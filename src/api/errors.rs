use actix_web::{web, HttpResponse};
use tracing::{event, instrument, Level};

use crate::{kodi_rpc, Movie, CONFIG};

#[instrument(skip(movie_list), level = "info")]
pub async fn get_unrecognized_movies(
    movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
) -> HttpResponse {
    let config = CONFIG.read().unwrap();
    let ignored_patterns = config
        .filepatterns_to_ignore
        .iter()
        .map(|pattern| regex::Regex::new(pattern).unwrap())
        .collect::<Vec<_>>();
    if let Ok(files) = kodi_rpc::KodiRPC::new(&config.kodis[0].url)
        .get_directory(&config.movies_directory)
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
pub fn get_duplicate_movies_list(
    movie_list: web::Data<std::sync::RwLock<Vec<Movie>>>,
) -> HttpResponse {
    let readable_movie_list = movie_list.read().unwrap().clone();
    let config = CONFIG.read().unwrap();
    let movie_pattern = regex::Regex::new(&format!(
        "^{}{}",
        config.movies_directory, config.movie_pattern
    ))
    .unwrap();

    let dups: Vec<Movie> = readable_movie_list
        .into_iter()
        .map(|movie| {
            (
                movie.clone(),
                movie_pattern
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
    let config = CONFIG.read().unwrap();
    let movie_pattern = regex::Regex::new(&format!(
        "^{}{}",
        config.movies_directory, config.movie_pattern
    ))
    .unwrap();

    let diffs: Vec<Movie> = readable_movie_list
        .into_iter()
        .map(|movie| {
            (
                movie.clone(),
                movie_pattern
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
                > config.name_differences_threshold.unwrap_or(3)
                || !movie.premiered.starts_with(year)
        })
        .map(|(movie, _)| movie)
        .collect();

    event!(Level::INFO, "found recognition errors: {}", diffs.len());
    HttpResponse::Ok().json(diffs)
}
