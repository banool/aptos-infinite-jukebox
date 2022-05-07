module AptosInfiniteJukebox::Jukebox {
    use Std::ASCII;
    use Std::Errors;
    use Std::Signer;
    use Std::Table;

    /// There is no jukebox present yet.
    const ENO_JUKEBOX: u64 = 0;

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
    struct Jukebox has key {
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
        let jukebox = Jukebox {
            // TODO: Figure out how to get string "0H8XeaJunhvpBdBFIYi6Sh"
            current_song: Song { song: ASCII::string(b"0H8XeaJunhvpBdBFIYi6Sh") },
            next_song_votes: Table::new<address, Vote>(),
        };
        move_to(account, jukebox);
    }

    public fun get_current_song(addr: address): ASCII::String acquires Jukebox {
        assert!(exists<Jukebox>(addr), Errors::not_published(ENO_JUKEBOX));
        *&borrow_global<Jukebox>(addr).current_song.song
    }

    /*
    public(script) fun submit_vote(account: signer, message_bytes: vector<u8>)
    acquires MessageHolder {
        let message = ASCII::string(message_bytes);
        let account_addr = Signer::address_of(&account);
        if (!exists<MessageHolder>(account_addr)) {
            move_to(&account, MessageHolder {
                message,
                message_change_events: Event::new_event_handle<MessageChangeEvent>(&account),
            })
        } else {
            let old_message_holder = borrow_global_mut<MessageHolder>(account_addr);
            let from_message = *&old_message_holder.message;
            Event::emit_event(&mut old_message_holder.message_change_events, MessageChangeEvent {
                from_message,
                to_message: copy message,
            });
            old_message_holder.message = message;
        }
    }

    #[test(account = @0x1)]
    public(script) fun sender_can_set_message(account: signer) acquires MessageHolder {
        let addr = Signer::address_of(&account);
        set_message(account,  b"Hello, Blockchain");

        assert!(
          get_message(addr) == ASCII::string(b"Hello, Blockchain"),
          ENO_MESSAGE
        );
    }
    */
}
