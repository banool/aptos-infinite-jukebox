extern crate base64;

use anyhow::{bail, Context, Result};
// use aptos_types::transaction::{ModuleBundle, ScriptFunction, TransactionPayload};
use clap::Parser;
use log::{debug, info};
/*
use move_core_types::{
    account_address::AccountAddress,
    identifier::Identifier,
    language_storage::{ModuleId, TypeTag},
};
*/
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::path::PathBuf;
use std::process::Command;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub fn current_unixtime_milliseconds() -> u64 {
    let start = SystemTime::now();
    start
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_millis() as u64
}

#[derive(Debug, Default, Deserialize, Serialize)]
struct Cache {
    /// A spotify access token.
    pub spotify_access_token: Option<String>,
    /// Map of Spotify track ID to Duration.
    pub track_durations: HashMap<String, u64>,
}

#[derive(Debug)]
struct CurrentSongInfo {
    /// The Spotify track ID of the song currently playing.
    pub track_id: String,

    /// Time in microseconds representing when the song started
    /// playing. For now we assume this time matches real wall time.
    pub time_to_start_playing: u64,
}

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    /// The public address for the Aptos account hosting the jukebox.
    #[clap(long)]
    account_public_address: String,

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

    /// What Aptos node to talk to.
    #[clap(long, default_value = "https://fullnode.devnet.aptoslabs.com")]
    node_url: String,

    /// The module name. We assume the module name and top level struct
    /// name are identical, as is the convention.
    #[clap(long, default_value = "JukeboxV7")]
    module_name: String,

    /// Aptos address where the module is published. If not given, we
    /// assume the module is published at the given public address.
    #[clap(long)]
    module_address: Option<String>,

    /// Amount of time prior to end of the current song that we should
    /// resolve the votes and decide the next song. This essentially
    /// means that if we trigger vote resolution and then someone immediately
    /// tunes in, they'll have to wait this long before they start playing music.
    /// The driver should be configured to run every x seconds where x is half
    /// or less of this value.
    #[clap(long, default_value = "20000")]
    resolve_votes_threshold_ms: u64,

    /// Path to the directory that contains the .aptos config directory.
    /// Temporary while we use the CLI (as opposed to using the libraries
    /// natively).
    #[clap(long, parse(from_os_str), default_value = "/Users/dport")]
    aptos_cli_config_parent_directory: PathBuf,

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
    // debug!("Raw access token response: {:#?}", res_json);
    Ok(res_json
        .get("access_token")
        .context("No field \"access_token\" in response")?
        .as_str()
        .context("access_token wasn't a string")?
        .to_owned())
}

async fn do_access_token_and_cache(
    cache: &mut Cache,
    cache_path: &PathBuf,
    spotify_client_id: &String,
    spotify_client_secret: &String,
) -> Result<String> {
    let access_token = get_spotify_access_token(&spotify_client_id, &spotify_client_secret)
        .await
        .context("Failed to get Spotify access token")?;
    debug!("Got new Spotify access token: {}", access_token);
    cache.spotify_access_token = Some(access_token.to_owned());
    write_cache(&cache_path, &cache)
        .context("Failed to write cache after getting new access token")?;
    Ok(access_token)
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
    // debug!("Raw track length response: {:#?}", res_json);
    let duration_ms = res_json
        .get("duration_ms")
        .context("No field \"duration_ms\" in response")?
        .as_u64()
        .context("duration_ms wasn't a u64")?
        .to_owned();
    Ok(Duration::from_millis(duration_ms))
}

async fn get_current_song_info(
    node_url: &str,
    account_public_address: &str,
    module_address: &str,
    module_name: &str,
) -> Result<CurrentSongInfo> {
    let resource_type = format!("0x{}::{}::{}", module_address, module_name, module_name);
    let uri = format!(
        "{}/accounts/{}/resource/{}",
        node_url, account_public_address, resource_type
    );
    let client = Client::new();
    let res = client.get(uri).send().await?;
    let res_json: serde_json::Value = serde_json::from_str(&res.text().await?)?;
    // debug!("Raw current song info response: {:#?}", res_json);
    let inner = res_json
        .get("data")
        .context("No field \"data\" in response")?
        .get("inner")
        .context("No field \"inner\" in response")?;
    let track_id = inner
        .get("song_queue")
        .context("No field \"song_queue\" in data")?[0]
        .get("song")
        .context("No field \"song\" in current_song")?
        .as_str()
        .context("song wasn't a string")?
        .to_owned();
    let time_to_start_playing = inner
        .get("time_to_start_playing")
        .context("No field \"time_to_start_playing\" in data")?
        .as_str()
        .context("time_to_start_playing wasn't a string (which we later convert into u64)")?
        .to_owned()
        .parse::<u64>()?;
    let out = CurrentSongInfo {
        track_id,
        time_to_start_playing,
    };
    Ok(out)
}

/// All times in milliseconds.
/// TODO: Use proper time types instead of random numbers.
/// This function determines whether we should trigger vote resolution,
/// as in, is it time to progress to the next round and play a new song.
fn should_we_trigger_vote_resolution(
    song_start_time: u64,
    song_duration: u64,
    resolve_votes_threshold_ms: u64,
) -> bool {
    current_unixtime_milliseconds() > (song_start_time + song_duration - resolve_votes_threshold_ms)
}

/// For now we just shell out to the CLI
async fn trigger_vote_resolution(
    module_address: &str,
    module_name: &str,
    aptos_cli_config_parent_directory: &PathBuf,
) -> Result<()> {
    let function_id = format!("{}::{}::resolve_votes", module_address, module_name);
    let status = Command::new("aptos")
        .current_dir(aptos_cli_config_parent_directory)
        .args(["move", "run", "--max-gas", "10000", "--function-id", &function_id])
        .status()?;
    if !status.success() {
        bail!("Command failed with code {:?}", status.code(),);
    }
    Ok(())
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

    // Find the song that is playing now and when it started.
    let module_address = match args.module_address {
        Some(a) => a,
        None => args.account_public_address.to_string(),
    };

    // TODO: Use the proper types for these.
    if args.account_public_address.starts_with("0x") || module_address.starts_with("0x") {
        bail!("Do not prefix addresses with 0x");
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

    // Get spotify access token.
    let spotify_access_token = match cache.spotify_access_token {
        Some(ref s) => {
            debug!("Using cached Spotify access token: {}", s);
            // Make sure the token is still good:
            match get_track_length("0H8XeaJunhvpBdBFIYi6Sh", s).await {
                Ok(_) => s.to_owned(),
                Err(e) => {
                    debug!("Cached access token didn't work, getting a new one: {}", e);
                    do_access_token_and_cache(
                        &mut cache,
                        &args.cache_path,
                        &args.spotify_client_id,
                        &args.spotify_client_secret,
                    )
                    .await?
                }
            }
        }
        None => {
            do_access_token_and_cache(
                &mut cache,
                &args.cache_path,
                &args.spotify_client_id,
                &args.spotify_client_secret,
            )
            .await?
        }
    };

    let current_song_info = get_current_song_info(
        &args.node_url,
        &args.account_public_address,
        &module_address,
        &args.module_name,
    )
    .await
    .context("Failed to determine current song info")?;
    info!("{:?}", current_song_info);

    let track_length = match cache.track_durations.get(&current_song_info.track_id) {
        Some(l) => {
            debug!("Read length of track from cache");
            *l
        }
        None => {
            let l = get_track_length(&current_song_info.track_id, &spotify_access_token)
                .await
                .context("Failed to get track length")?;
            let out = l.as_millis() as u64;
            cache
                .track_durations
                .insert(current_song_info.track_id.to_string(), out);
            write_cache(&args.cache_path, &cache)
                .context("Failed to write cache after discovering track length")?;
            debug!("Fetched length of track from Spotify API and cached it");
            out
        }
    };

    info!(
        "Length of track {} is {:?}",
        current_song_info.track_id, track_length
    );

    let we_should_trigger_vote_resolution = should_we_trigger_vote_resolution(
        current_song_info.time_to_start_playing / 1000,
        track_length,
        args.resolve_votes_threshold_ms,
    );
    info!(
        "We should trigger vote resolution: {}",
        we_should_trigger_vote_resolution
    );

    if we_should_trigger_vote_resolution {
        trigger_vote_resolution(
            &module_address,
            &args.module_name,
            &args.aptos_cli_config_parent_directory,
        )
        .await
        .context("Failed to trigger vote resolution")?;
        info!("Successfully triggered vote resolution");
    }

    Ok(())
}
