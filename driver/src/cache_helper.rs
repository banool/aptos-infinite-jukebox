use anyhow::{Context, Result};
use log::debug;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::path::PathBuf;

#[derive(Debug, Default, Deserialize, Serialize)]
pub struct Cache {
    /// A spotify access token.
    pub spotify_access_token: Option<String>,
    /// Map of Spotify track ID to Duration.
    pub track_durations: HashMap<String, u64>,
}

pub fn load_cache(cache_path: &PathBuf) -> Result<Option<Cache>> {
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

pub fn write_cache(cache_path: &PathBuf, cache: &Cache) -> Result<()> {
    let file = File::create(cache_path).context("Failed to create cache file")?;
    serde_json::to_writer(&file, cache).context("Failed to write cache as json")?;
    Ok(())
}
