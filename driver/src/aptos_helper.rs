use anyhow::{bail, Context, Result};
use aptos_rest_client::{Client as AptosClient, Transaction};
use aptos_sdk::crypto::ValidCryptoMaterialStringExt;
use aptos_sdk::crypto::{ed25519::Ed25519PrivateKey, PrivateKey};
use aptos_sdk::move_types::account_address::AccountAddress;
use aptos_sdk::move_types::identifier::Identifier;
use aptos_sdk::move_types::language_storage::ModuleId;
use aptos_sdk::transaction_builder::TransactionFactory;
use aptos_sdk::types::LocalAccount;
use aptos_sdk::types::{
    chain_id::ChainId,
    transaction::{authenticator::AuthenticationKey, EntryFunction, TransactionPayload},
};
use clap::Parser;
use log::info;
use reqwest::Url;

#[derive(Parser, Debug)]
#[clap()]
pub struct AptosArgs {
    /// The private key for the Aptos account hosting the jukebox.
    #[clap(long)]
    pub account_private_key: String,

    /// What Aptos node to talk to.
    #[clap(long, default_value = "https://fullnode.testnet.aptoslabs.com")]
    pub node_url: Url,

    /// The module name.
    #[clap(long, default_value = "jukebox")]
    pub module_name: String,

    /// The struct name inside the module.
    #[clap(long, default_value = "Jukebox")]
    pub struct_name: String,

    /// Aptos address where the module is published. If not given, we
    /// assume the module is published at the address of the given
    /// private key.
    #[clap(long)]
    pub module_address: Option<AccountAddress>,

    /// Chain ID
    #[clap(long)]
    pub chain_id: Option<ChainId>,
}

#[derive(Debug)]
pub struct CurrentSongInfo {
    /// The Spotify track ID of the song currently playing.
    pub track_id: String,

    /// Time in microseconds representing when the song started
    /// playing. For now we assume this time matches real wall time.
    pub time_to_start_playing: u64,
}

pub async fn get_chain_id(url: Url) -> Result<ChainId> {
    let client = AptosClient::new(url);
    let state = client.get_ledger_information().await?.into_inner();
    Ok(ChainId::new(state.chain_id))
}

pub async fn get_current_song_info(
    node_url: Url,
    account_public_address: AccountAddress,
    module_address: &AccountAddress,
    module_name: &String,
    struct_name: &String,
) -> Result<CurrentSongInfo> {
    let client = AptosClient::new(node_url);
    let resource_type = format!(
        "0x{}::{}::{}",
        module_address.to_hex(),
        module_name,
        struct_name
    );
    let resource = client
        .get_account_resource(account_public_address, &resource_type)
        .await
        .context("Failed to get resource to determine current song info")?
        .into_inner();
    let resource = match resource {
        Some(r) => r,
        None => bail!("Pulling resource succeeded but couldn't find resource"),
    };
    let inner = resource
        .data
        .get("inner")
        .context("No field \"inner\" in response")?;
    // debug!("Raw current song info response: {:#?}", inner);
    let track_id = inner
        .get("song_queue")
        .context("No field \"song_queue\" in data")?[0]
        .get("track_id")
        .context("No field \"track_id\" in current_song")?
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

pub fn get_private_key(private_key: &str) -> Result<Ed25519PrivateKey> {
    // Get sender address
    Ed25519PrivateKey::from_encoded_string(private_key).context("Failed to construct private key")
}

pub fn get_account_address(private_key: &Ed25519PrivateKey) -> AccountAddress {
    // Get sender address
    let sender_address = AuthenticationKey::ed25519(&private_key.public_key()).derived_address();
    AccountAddress::new(*sender_address)
}

pub async fn trigger_vote_resolution(
    module_address: &AccountAddress,
    module_name: &str,
    url: Url,
    chain_id: ChainId,
    private_key: Ed25519PrivateKey,
) -> Result<()> {
    // We assume the module conforms to module name == top level struct name.
    let module_name =
        Identifier::new(module_name).context("Failed to make module name identifier")?;
    let module_id = ModuleId::new(module_address.clone(), module_name);
    let function =
        Identifier::new("resolve_votes").context("Failed to make function identifier")?;
    let entry_function = EntryFunction::new(module_id, function, vec![], vec![]);
    let payload = TransactionPayload::EntryFunction(entry_function);
    let transaction = submit_transaction(url, chain_id, private_key, payload, 500000).await?;
    info!(
        "Submitted transaction: {:?}",
        transaction.transaction_info()
    );
    Ok(())
}

/// Retrieves sequence number from the rest client
async fn get_sequence_number(
    client: &aptos_rest_client::Client,
    address: AccountAddress,
) -> Result<u64> {
    let account_response = client
        .get_account(address)
        .await
        .context("Faled to get sequence number from account")?;
    let account = account_response.inner();
    Ok(account.sequence_number)
}

/// Submits a [`TransactionPayload`] as signed by the `sender_key`
async fn submit_transaction(
    url: Url,
    chain_id: ChainId,
    sender_key: Ed25519PrivateKey,
    payload: TransactionPayload,
    max_gas: u64,
) -> Result<Transaction> {
    let client = AptosClient::new(url);

    let sender_address = get_account_address(&sender_key);

    // Get sequence number for account
    let sequence_number = get_sequence_number(&client, sender_address).await?;

    // Sign and submit transaction
    let transaction_factory = TransactionFactory::new(chain_id)
        .with_gas_unit_price(200)
        .with_max_gas_amount(max_gas);
    let sender_account = &mut LocalAccount::new(sender_address, sender_key, sequence_number);
    let transaction =
        sender_account.sign_with_transaction_builder(transaction_factory.payload(payload));
    let response = client
        .submit_and_wait(&transaction)
        .await
        .context("Error from submitting transaction")?;

    Ok(response.into_inner())
}
