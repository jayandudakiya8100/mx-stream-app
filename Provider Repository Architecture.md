# Common Provider Repository Architecture

## 1. Overview

This repository follows a centralized architecture for managing multiple CloudStream providers.

The repository is divided into three main configuration layers:

```text
CS.json
   ↓
plugins.json
   ↓
Provider `.cs3` files
   ↓
Provider website / URL configuration
   ↓
Movies / TV Shows / Anime / Asian Drama
```

The repository also maintains a centralized `urls.json` file that stores the current website URL for each provider.

---

# 2. Repository Structure

```text
Repository
│
├── CS.json
│
├── plugins.json
│
├── urls.json
│
└── Provider Plugins
    ├── Bollyflix.cs3
    ├── CineStream.cs3
    ├── GDIndex.cs3
    ├── MoviesDrive.cs3
    ├── Moviesmod.cs3
    ├── OnlineMoviesHinditProvider.cs3
    └── VegaMovies.cs3
```

---

# 3. Repository Flow

## Step 1 — `CS.json`

`CS.json` is the main repository manifest.

It contains the repository name, description, icon, manifest version, and the location of `plugins.json`.

```text
CS.json
   │
   └── pluginLists
          │
          └── plugins.json
```

### `CS.json`

```json
{
  "name": "Megix Repo(Hindi & English)",
  "description": "Hindi and English",
  "iconUrl": "https://wsrv.nl/?url=https://avatars.githubusercontent.com/u/91174352&mask=circle",
  "manifestVersion": 2,
  "pluginLists": [
    "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/plugins.json"
  ]
}
```

---

# 4. `plugins.json`

`plugins.json` is the central provider registry.

Every provider has its own metadata object.

The `url` field points to the actual `.cs3` plugin.

```text
plugins.json
     │
     ├── Bollyflix.cs3
     ├── CineStream.cs3
     ├── GDIndex.cs3
     ├── MoviesDrive.cs3
     ├── Moviesmod.cs3
     ├── OnlineMoviesHinditProvider.cs3
     └── VegaMovies.cs3
```

## Provider Metadata

Common fields:

```json
{
  "url": "PLUGIN_URL",
  "status": 1,
  "version": 1,
  "name": "Provider Name",
  "internalName": "ProviderName",
  "authors": [],
  "description": "Provider description",
  "fileSize": 0,
  "repositoryUrl": "SOURCE_REPOSITORY",
  "language": "en",
  "tvTypes": [],
  "iconUrl": "ICON_URL",
  "apiVersion": 1,
  "fileHash": "SHA256_HASH",
  "isLiveURL": true
}
```

### `isLiveURL`

`isLiveURL` indicates whether the provider directly provides a live/playable stream URL.

```text
Provider provides live URL
        ↓
"isLiveURL": true
```

```text
Provider does not provide live URL
        ↓
"isLiveURL": false
```

The old field:

```text
isLiveURLProvidred
```

is removed completely.

---

# 5. Current Provider Registry

## Bollyflix

```json
{
  "url": "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/Bollyflix.cs3",
  "status": 1,
  "version": 33,
  "name": "Bollyflix",
  "internalName": "Bollyflix",
  "authors": [
    "megix"
  ],
  "description": "Movies and Series upto 4K",
  "fileSize": 38129,
  "repositoryUrl": "https://github.com/SaurabhKaperwan/CSX",
  "language": "hi",
  "tvTypes": [
    "TvSeries",
    "Movie",
    "AsianDrama",
    "Anime"
  ],
  "iconUrl": "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/refs/heads/master/Bollyflix/icon.png",
  "apiVersion": 1,
  "fileHash": "sha256-507b486b195b98903b0cec0fca811c27fdff6cf200f6f94a662c64dd8abe0e59",
  "isLiveURL": true
}
```

## CineStream

```json
{
  "url": "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/CineStream.cs3",
  "status": 1,
  "version": 480,
  "name": "CineStream",
  "internalName": "CineStream",
  "authors": [
    "megix"
  ],
  "description": "One stop solution for Movies, Series, Anime, AsianDrama and Torrents",
  "fileSize": 730499,
  "repositoryUrl": "https://github.com/SaurabhKaperwan/CSX",
  "language": "en",
  "tvTypes": [
    "TvSeries",
    "Movie",
    "AsianDrama",
    "Anime",
    "Torrent"
  ],
  "iconUrl": "https://github.com/SaurabhKaperwan/CSX/raw/refs/heads/master/CineStream/icon.png",
  "apiVersion": 1,
  "fileHash": "sha256-44f60181676e767095bdbb828379f4a7cfdda2c41431806ea9cf6a0d238f7eb6",
  "isLiveURL": false
}
```

## GDIndex

```json
{
  "url": "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/GDIndex.cs3",
  "status": 1,
  "version": 6,
  "name": "GDIndex",
  "internalName": "GDIndex",
  "authors": [
    "Horis"
  ],
  "fileSize": 18257,
  "repositoryUrl": "https://github.com/SaurabhKaperwan/CSX",
  "language": "en",
  "tvTypes": [
    "Movie",
    "TvSeries"
  ],
  "iconUrl": "https://github.com/SaurabhKaperwan/CSX/raw/refs/heads/master/GDIndex/icon.ico",
  "apiVersion": 1,
  "fileHash": "sha256-d6c6b8e49b1f98552fa81615c0a57218e2602eb52c261871e3290bb3d73e1c29",
  "isLiveURL": false
}
```

## MoviesDrive

```json
{
  "url": "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/MoviesDrive.cs3",
  "status": 1,
  "version": 33,
  "name": "MoviesDrive",
  "internalName": "MoviesDrive",
  "authors": [
    "megix"
  ],
  "description": "High Quality Movies and TV Shows",
  "fileSize": 47290,
  "repositoryUrl": "https://github.com/SaurabhKaperwan/CSX",
  "language": "hi",
  "tvTypes": [
    "TvSeries",
    "Movie",
    "AsianDrama",
    "Anime"
  ],
  "iconUrl": "https://github.com/SaurabhKaperwan/CSX/raw/refs/heads/master/MoviesDrive/icon.png",
  "apiVersion": 1,
  "fileHash": "sha256-52758210caa1cf0a6dc929d0f73fec5919e0ab66e5eddf6386ed30f7c771980a",
  "isLiveURL": true
}
```

## Moviesmod

```json
{
  "url": "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/Moviesmod.cs3",
  "status": 1,
  "version": 33,
  "name": "Moviesmod",
  "internalName": "Moviesmod",
  "authors": [
    "megix"
  ],
  "description": "Includes Topmovies",
  "fileSize": 44518,
  "repositoryUrl": "https://github.com/SaurabhKaperwan/CSX",
  "language": "hi",
  "tvTypes": [
    "TvSeries",
    "Movie",
    "AsianDrama",
    "Anime"
  ],
  "iconUrl": "https://github.com/SaurabhKaperwan/CSX/raw/refs/heads/master/Moviesmod/icon.png",
  "apiVersion": 1,
  "fileHash": "sha256-9433fd970480a53f52f3ec4b49d3213c7bda5a26b109dc80ef82cd2ec13a37a7",
  "isLiveURL": true
}
```

## OnlineMoviesHinditProvider

```json
{
  "url": "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/OnlineMoviesHinditProvider.cs3",
  "status": 1,
  "version": 6,
  "name": "OnlineMoviesHinditProvider",
  "internalName": "OnlineMoviesHinditProvider",
  "authors": [
    "megix"
  ],
  "description": "Use VPN",
  "fileSize": 11950,
  "repositoryUrl": "https://github.com/SaurabhKaperwan/CSX",
  "language": "hi",
  "tvTypes": [
    "TvSeries",
    "Movie"
  ],
  "iconUrl": "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/master/OnlineMoviesHinditProvider/icon.png",
  "apiVersion": 1,
  "fileHash": "sha256-577919ca8bbf01ded9e9299851431447c5964e979a9c4eb73ffd82ca8733ae2d",
  "isLiveURL": false
}
```

## VegaMovies

```json
{
  "url": "https://raw.githubusercontent.com/SaurabhKaperwan/CSX/builds/VegaMovies.cs3",
  "status": 1,
  "version": 82,
  "name": "VegaMovies",
  "internalName": "VegaMovies",
  "authors": [
    "megix"
  ],
  "description": "Includes LuxMovies, Rogmovies",
  "fileSize": 41565,
  "repositoryUrl": "https://github.com/SaurabhKaperwan/CSX",
  "language": "hi",
  "tvTypes": [
    "TvSeries",
    "Movie",
    "AsianDrama",
    "Anime"
  ],
  "iconUrl": "https://github.com/SaurabhKaperwan/CSX/raw/refs/heads/master/VegaMovies/icon.jpg",
  "apiVersion": 1,
  "fileHash": "sha256-b78635ef4f2f66c134184552fe5e4956cc02ec1c5ce6d6811cccfd3747367883",
  "isLiveURL": true
}
```

---

# 6. Centralized `urls.json`

`urls.json` contains the current URL/domain for each provider.

```json
{
  "4khdhub": "https://4khdhub.one",
  "bollyflix": "https://bollyflix.free",
  "hdmovie2": "https://hdmovie2a.bar",
  "rtally": "https://rtally.link",
  "hindmoviez": "https://hindmovie.icu",
  "moviesdrive": "https://new2.moviesdrive.christmas",
  "movies4u": "https://www.google.com",
  "multimovies": "https://multimovies.makeup",
  "nfmirror": "https://tv.imgcdn.kim/newtv",
  "skymovies": "https://skymovieshd.forex",
  "uhdmovies": "https://uhdmovies.autos",
  "moviesmod": "https://moviesmod.zone",
  "topmovies": "https://moviesleech.rest",
  "vegamovies": "https://new2.vegamovies.futbol",
  "rogmovies": "https://new2.rogmovies.click",
  "gdflix": "https://new3.gdflix.io",
  "hubcloud": "https://hubcloud.cx",
  "toonstream": "https://toon-stream.site",
  "zinkmovies": "https://zinkmovies.org",
  "vcloud": "https://vcloud.fit",
  "dudefilms": "https://dudefilms.garden",
  "m4ufree": "https://ww4.m4ufree.lat",
  "animedao": "https://anidao.to",
  "mlsbd": "https://mlsbd.co",
  "fibwatch": "https://fibwatch.art",
  "fmovies": "https://www.f-movies.org"
}
```

---

# 7. URL Resolution Flow

Providers should not depend on a permanently hardcoded domain when the provider supports centralized URL configuration.

Example:

```text
VegaMovies Provider
       │
       ↓
Lookup "vegamovies"
       │
       ↓
urls.json
       │
       ↓
https://new2.vegamovies.futbol
       │
       ↓
Provider requests
       │
       ├── Search
       ├── Load Movie
       ├── Load Series
       └── Extract Links
```

If the domain changes:

```text
Old Domain
    ↓
new2.vegamovies.futbol

New Domain
    ↓
new-domain.example
```

Only `urls.json` needs to be updated if the provider implementation is otherwise unchanged.

---

# 8. Complete Runtime Flow

The complete repository flow is:

```text
                    ┌──────────────┐
                    │    CS.json   │
                    └──────┬───────┘
                           │
                           ↓
                    ┌──────────────┐
                    │ plugins.json │
                    └──────┬───────┘
                           │
                ┌──────────┼──────────┐
                ↓          ↓          ↓
             Provider   Provider   Provider
               .cs3       .cs3       .cs3
                │          │          │
                └──────────┼──────────┘
                           │
                           ↓
                      urls.json
                           │
                           ↓
                    Current Domain
                           │
                           ↓
                       Provider
                           │
              ┌────────────┼────────────┐
              ↓            ↓            ↓
           Search        Load        Load Links
              │            │            │
              └────────────┼────────────┘
                           ↓
                     Media Results
                           │
                           ↓
                    Playback / URL
```

---

# 9. Provider Responsibilities

Every provider should expose a common set of operations.

Conceptually:

```text
Provider
│
├── search(query)
│
├── load(url)
│
├── loadLinks(data)
│
└── getBaseUrl()
```

### Search

```text
search("Avengers")
        ↓
Provider Website
        ↓
Search Results
        ↓
Normalized Movie/Series Results
```

### Load

```text
Movie ID / URL
      ↓
Provider
      ↓
Movie Details
      ↓
Poster
Title
Description
Year
Rating
Genres
Episodes
```

### Load Links

```text
Movie / Episode
       ↓
Provider
       ↓
Source Extraction
       ↓
Video Sources
       ↓
Quality
       ↓
Stream URL
```

---

# 10. Common Provider Data Model

All providers should normalize their output into a common structure.

### Search Result

```json
{
  "id": "provider-specific-id",
  "title": "Movie Title",
  "url": "PROVIDER_URL",
  "poster": "POSTER_URL",
  "type": "Movie",
  "year": 2026
}
```

### Movie / Series Details

```json
{
  "id": "provider-specific-id",
  "title": "Movie Title",
  "description": "Description",
  "poster": "POSTER_URL",
  "backdrop": "BACKDROP_URL",
  "year": 2026,
  "genres": [],
  "type": "Movie",
  "episodes": []
}
```

### Stream Source

```json
{
  "url": "STREAM_URL",
  "quality": "1080p",
  "type": "HLS",
  "headers": {},
  "referer": "PROVIDER_URL"
}
```

---

# 11. `isLiveURL` Usage

The provider metadata contains:

```json
"isLiveURL": true
```

or:

```json
"isLiveURL": false
```

### `true`

The provider directly returns a usable/live playback URL.

```text
Provider
   ↓
Extract
   ↓
Live Stream URL
   ↓
Player
```

### `false`

The provider does not directly provide the final playable URL and another extraction/resolution step may be required.

```text
Provider
   ↓
Extract intermediary URL
   ↓
Resolver / Extractor
   ↓
Final Stream URL
   ↓
Player
```

---

# 12. Common Architecture Principle

The main objective is to keep provider-specific implementation separate from the common application layer.

```text
                 Application
                     │
                     ↓
            Common Provider API
                     │
        ┌────────────┼────────────┐
        ↓            ↓            ↓
    VegaMovies   Bollyflix   MoviesDrive
        │            │            │
        └────────────┼────────────┘
                     ↓
              Normalized Data
                     │
                     ↓
               Application UI
```

The UI should not need to know how VegaMovies or Bollyflix works internally.

It only consumes the normalized provider interface.

---

# 13. Final Architecture

```text
Repository
│
├── CS.json
│      │
│      └── Repository metadata
│
├── plugins.json
│      │
│      └── Provider registry
│
├── urls.json
│      │
│      └── Centralized provider domains
│
└── Providers
       │
       ├── Bollyflix
       ├── CineStream
       ├── GDIndex
       ├── MoviesDrive
       ├── Moviesmod
       ├── OnlineMoviesHinditProvider
       └── VegaMovies
              │
              ↓
        Common Provider Interface
              │
              ├── Search
              ├── Load
              └── Load Links
                      │
                      ↓
               Normalized Results
                      │
                      ↓
                   Player
```

## Summary

The architecture has three major responsibilities:

1. **`CS.json`** — Repository entry point.
2. **`plugins.json`** — Provider/plugin registry and metadata.
3. **`urls.json`** — Centralized provider domain configuration.

The actual provider implementation remains inside each `.cs3` plugin, while the application consumes providers through a common normalized interface.

`isLiveURLProvidred` is removed entirely and replaced with the standardized:

```json
"isLiveURL": true
```

or:

```json
"isLiveURL": false
```
