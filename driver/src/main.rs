extern crate base64;

use anyhow::{Context, Result};
use clap::Parser;
use log::debug;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::path::PathBuf;
use std::time::Duration;

#[derive(Debug, Default, Deserialize, Serialize)]
struct Cache {
    /// A spotify access token.
    pub spotify_access_token: Option<String>,
    /// Map of Spotify track ID to Duration.
    pub track_durations: HashMap<String, u64>,
}

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    /// The private key for the Aptos account hosting the jukebox.
    #[clap(long)]
    account_private_key: String,

    /// The client ID for the Spotify developer account.
    #[clap(long)]
    spotify_client_id: String,

    /// The client secret for the Spotify developer account.
    #[clap(long)]
    spotify_client_secret: String,

    /// Path for where to store the cache.
    #[clap(
        long,
        parse(from_os_str),
        default_value = "/tmp/aptos-infinite-jukebox-driver-cache.json"
    )]
    cache_path: PathBuf,

    /// Whether to enable debug logging or not. This is a shortcut for the
    /// standard env logger configuration via env vars
    #[clap(short, long)]
    debug: bool,
}

async fn get_spotify_access_token(
    spotify_client_id: &String,
    spotify_client_secret: &String,
) -> Result<String> {
    let params = [("grant_type", "client_credentials")];
    let uri = "https://accounts.spotify.com/api/token";
    let client_string = format!("{}:{}", spotify_client_id, spotify_client_secret);
    let authorization_string = format!("Basic {}", base64::encode(client_string));
    let client = Client::new();
    let res = client
        .post(uri)
        .header("Authorization", authorization_string)
        .header("Content-Type", "application/x-www-form-urlencoded")
        .form(&params)
        .send()
        .await?;
    let res_json: serde_json::Value = serde_json::from_str(&res.text().await?)?;
    Ok(res_json
        .get("access_token")
        .context("No access_token in response")?
        .as_str()
        .context("access_token wasn't a string")?
        .to_owned())
}

/// Returns track length.
async fn get_track_length(track_id: &str, spotify_access_token: &str) -> Result<Duration> {
    let uri = format!("https://api.spotify.com/v1/tracks/{}", track_id);
    let authorization_string = format!("Bearer {}", spotify_access_token);
    let client = Client::new();
    let res = client
        .get(uri)
        .header("Authorization", authorization_string)
        .send()
        .await
        .context("Failed to make GET request to Sptoify API for track information")?;
    let res_json: serde_json::Value = serde_json::from_str(&res.text().await?)?;
    let duration_ms = res_json
        .get("duration_ms")
        .context("No duration_ms in response")?
        .as_u64()
        .context("duration_ms wasn't a u64")?
        .to_owned();
    Ok(Duration::from_millis(duration_ms))
}

fn load_cache(cache_path: &PathBuf) -> Result<Option<Cache>> {
    let file = match File::open(cache_path) {
        Ok(f) => f,
        Err(_e) => {
            debug!("No cache file found");
            return Ok(None);
        }
    };
    let reader = BufReader::new(file);
    let j = serde_json::from_reader(reader).context("Cache data was invalid")?;

    Ok(j)
}

fn write_cache(cache_path: &PathBuf, cache: &Cache) -> Result<()> {
    let file = File::create(cache_path).context("Failed to create cache file")?;
    serde_json::to_writer(&file, cache).context("Failed to write cache as json")?;
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    if args.debug {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("debug")).init();
        debug!("Debug logging enabled");
    } else {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("warn")).init();
    }

    let cache_option = load_cache(&args.cache_path).context("Failed to load cache")?;
    let mut cache = match cache_option {
        Some(c) => c,
        None => {
            let newc = Cache::default();
            write_cache(&args.cache_path, &newc).context("Failed to write cache")?;
            newc
        }
    };

    let spotify_access_token = match cache.spotify_access_token {
        Some(s) => {
            debug!("Using cached Spotify access token: {}", s);
            s
        }
        None => {
            let access_token =
                get_spotify_access_token(&args.spotify_client_id, &args.spotify_client_secret)
                    .await
                    .context("Failed to get Spotify access token")?;
            debug!("Got new Spotify access token: {}", access_token);
            cache.spotify_access_token = Some(access_token.to_owned());
            write_cache(&args.cache_path, &cache)
                .context("Failed to write cache after getting new access token")?;
            access_token
        }
    };

    let eh = get_track_length("0H8XeaJunhvpBdBFIYi6Sh", &spotify_access_token).await?;
    println!("test: {:?}", eh);

    Ok(())
}
