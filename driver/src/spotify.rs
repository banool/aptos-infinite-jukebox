use anyhow::{Context, Result};
use clap::Parser;
use reqwest::Client;
use std::time::Duration;

#[derive(Parser, Debug)]
#[clap()]
pub struct SpotifyArgs {
    /// The client ID for the Spotify developer account.
    #[clap(long)]
    pub spotify_client_id: String,

    /// The client secret for the Spotify developer account.
    #[clap(long)]
    pub spotify_client_secret: String,
}

pub async fn get_spotify_access_token(
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

/// Returns track length.
pub async fn get_track_length(track_id: &str, spotify_access_token: &str) -> Result<Duration> {
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
