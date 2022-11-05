extern crate base64;

mod aptos_helper;
mod cache_helper;
mod spotify;

use aptos_helper::{
    get_account_address, get_chain_id, get_current_song_info, get_private_key,
    trigger_vote_resolution, AptosArgs,
};
use cache_helper::{load_cache, write_cache, Cache};
use spotify::{get_spotify_access_token, get_track_length, SpotifyArgs};

use anyhow::{Context, Result};
use clap::Parser;
use log::{debug, info};
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    #[clap(flatten)]
    spotify_args: SpotifyArgs,

    #[clap(flatten)]
    aptos_args: AptosArgs,

    /// Path for where to store the cache.
    #[clap(
        long,
        parse(from_os_str),
        default_value = "/tmp/aptos-infinite-jukebox-driver-cache.json"
    )]
    cache_path: PathBuf,

    /// Amount of time prior to end of the current song that we should
    /// resolve the votes and decide the next song. This essentially
    /// means that if we trigger vote resolution and then someone immediately
    /// tunes in, they'll have to wait this long before they start playing music.
    /// The driver should be configured to run every x seconds where x is half
    /// or less of this value.
    #[clap(long, default_value = "20000")]
    resolve_votes_threshold_ms: u64,

    /// Whether to enable debug logging or not. This is a shortcut for the
    /// standard env logger configuration via env vars
    #[clap(short, long)]
    debug: bool,
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

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    if args.debug {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("debug")).init();
        debug!("Debug logging enabled");
    } else {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    }

    // Make private key from given string.
    let private_key = get_private_key(&args.aptos_args.account_private_key)?;

    // Get account address.
    let account_address = get_account_address(&private_key);

    // Find the song that is playing now and when it started.
    let module_address = match args.aptos_args.module_address {
        Some(a) => a,
        None => account_address.clone(),
    };

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
            info!("Using cached Spotify access token: {}", s);
            // Make sure the token is still good:
            match get_track_length("0H8XeaJunhvpBdBFIYi6Sh", s).await {
                Ok(_) => s.to_owned(),
                Err(e) => {
                    info!("Cached access token didn't work, getting a new one: {}", e);
                    do_access_token_and_cache(
                        &mut cache,
                        &args.cache_path,
                        &args.spotify_args.spotify_client_id,
                        &args.spotify_args.spotify_client_secret,
                    )
                    .await?
                }
            }
        }
        None => {
            do_access_token_and_cache(
                &mut cache,
                &args.cache_path,
                &args.spotify_args.spotify_client_id,
                &args.spotify_args.spotify_client_secret,
            )
            .await?
        }
    };

    let current_song_info = get_current_song_info(
        args.aptos_args.node_url.clone(),
        account_address.clone(),
        &module_address,
        &args.aptos_args.module_name,
        &args.aptos_args.struct_name,
    )
    .await
    .context("Failed to determine current song info")?;
    info!("{:?}", current_song_info);

    let track_length = match cache.track_durations.get(&current_song_info.track_id) {
        Some(l) => {
            info!("Read length of track from cache");
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
            info!("Fetched length of track from Spotify API and cached it");
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
        let chain_id = match args.aptos_args.chain_id {
            Some(ci) => ci,
            None => get_chain_id(args.aptos_args.node_url.clone())
                .await
                .context("Failed to get chain ID")?,
        };
        info!("Using chain ID: {:?}", chain_id);
        trigger_vote_resolution(
            &module_address,
            &args.aptos_args.module_name,
            args.aptos_args.node_url,
            chain_id,
            private_key,
        )
        .await
        .context("Failed to trigger vote resolution")?;
        info!("Successfully triggered vote resolution");
    }

    Ok(())
}

pub fn current_unixtime_milliseconds() -> u64 {
    let start = SystemTime::now();
    start
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_millis() as u64
}
