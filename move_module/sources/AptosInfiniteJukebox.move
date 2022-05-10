module AptosInfiniteJukebox::JukeboxV5 {
    use Std::ASCII;
    use Std::Errors;
    use Std::Table;

    //use Std::Signer;

    /// There is no jukebox present yet.
    const E_NO_JUKEBOX: u64 = 0;

    /// I wonder if instead each vote should be stored on that account,
    /// I believe maintaining a map of address to struct is an antipatttern
    /// in Aptos. If so, we would need this module to be granted permission
    /// to read and wipe the Vote from an account. We would also need to be
    /// able to list all addresses that have this struct (Vote). Potentially
    /// instead we could have some kind of incrementing counter for each song
    /// player and each vote contains a value indicating which round it is for.
    /// This leads into greater questions around history. You could design a
    /// module where the votes from all accounts are maintained in their storage,
    /// and this module could record the vote history, but that seems unnecessary
    /// given the blockchain is a historical ledger. As in, we should only store
    /// the current state (or info necessary to build the next state, which is
    /// the purpose of this struct).
    /// 
    /// The current song clients should be playing. The current plan is users
    /// can derive when they should be up to in the song by looking at when
    /// the transaction was executed to set current_song. I could also have
    /// the server pass it in.
    struct JukeboxV5 has key {
        current_song: Song,
        next_song_votes: Table::Table<address, Vote>,
    }

    /// Pretty much a newtype (using Rust terminology).
    struct Song has store {
        /// This must be the Spotify ID of the track, e.g.
        /// 0H8XeaJunhvpBdBFIYi6Sh
        /// See https://developer.spotify.com/documentation/web-api/
        song: ASCII::String,
    }

    /// We represent a vote as a struct in case we want to add further
    /// fields down the line, e.g. a weight for the vote based on some
    /// (governance) token spend.
    struct Vote has store {
        song: Song,
    }

    /// Initialize infinite jukebox.
    public(script) fun initialize_infinite_jukebox(account: &signer) {
        let jukebox = JukeboxV5 {
            current_song: Song { song: ASCII::string(b"0H8XeaJunhvpBdBFIYi6Sh") },
            next_song_votes: Table::new<address, Vote>(),
        };
        move_to(account, jukebox);
    }

    // For now calling this externally doesn't work. Instead I'm going to use the REST API
    // and just get the account resources.
    public(script) fun get_current_song(addr: address): ASCII::String acquires JukeboxV5 {
        // TODO: Use a different variant of Errors
        assert!(exists<JukeboxV5>(addr), Errors::not_published(E_NO_JUKEBOX));
        *&borrow_global<JukeboxV5>(addr).current_song.song
    }

    /* TODO: Figure out a way to assert that this throws an error (which we expect it to).
    #[test(account = @0x1)]
    public(script) fun test_get_current_song_fails_without_initializing_first(account: signer) acquires JukeboxV5 {
        let addr = Signer::address_of(&account);
        assert!(
          get_current_song(addr) == ASCII::string(b"0H8XeaJunhvpBdBFIYi6Sh"),
          E_NO_JUKEBOX
        );
    }
    */

    #[test(account = @0x1)]
    public(script) fun initialize_get_current_song_works(account: signer) acquires JukeboxV5 {
        let addr = Signer::address_of(&account);

        initialize_infinite_jukebox(&account);

        assert!(
          get_current_song(addr) == ASCII::string(b"0H8XeaJunhvpBdBFIYi6Sh"),
          E_NO_JUKEBOX
        );
    }
}
