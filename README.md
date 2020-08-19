# Kodi Helper

![demo gif](https://raw.githubusercontent.com/mockersf/kodi-helper/master/demo.gif "demo")

## Library Exploration

Explore your library
* Sort movies by Title, Rating, Year, Set, Play Count, Date Added
* Add /remove tags
* Filter by title, tag, genre, cast, resolution


## Hospital

Identify common issues in your library:

* Duplicate movies
* Movies missing poster
* Movie badly recognized (when the name is too different from the filename)
* Missing files from your library
* Movies without resolution
* SD movies



## Configuration
```
kodis = []
kodis = ${kodis} [{
    name: "my kodi instance"
    url: "http://192.168.0.123:8080/"
}]

filepatterns_to_ignore = [
    ".*\.srt$",
    ".*\.sub$",
    ".*\.ssa$",
    "\.DS_Store$",
    "/$",
]

movies_directory = "/volume/movies/"

name_differences_threshold = 3
```