module AptosInfiniteJukebox::JukeboxV1 {
    use Std::ASCII;
    use Std::Errors;
    use Std::Signer;
    use Std::Vector;

    struct CurrentSong has key {
        current_song: ASCII::String,
    }

    // We represent a vote as a struct in case we want to add further
    // fields down the line, e.g. a weight for the vote based on some
    // (governance) token spend.
    struct Vote has store {
        song: ASCII::String;
    }

    // I wonder if instead each vote should be stored on that account,
    // I believe maintaining a map of address to struct is an antipatttern
    // in Aptos. If so, we would need this module to be granted permission
    // to read and wipe the Vote from an account. We would also need to be
    // able to list all addresses that have this struct (Vote). Potentially
    // instead we could have some kind of incrementing counter for each song
    // player and each vote contains a value indicating which round it is for.
    // This leads into greater questions around history. You could design a
    // module where the votes from all accounts are maintained in their storage,
    // and this module could record the vote history, but that seems unnecessary
    // given the blockchain is a historical ledger. As in, we should only store
    // the current state (or info necessary to build the next state, which is
    // the purpose of this struct).
    struct NextSongVotes has key {
        next_song_votes: table<address, Vote>,
    }

    /// There is no message present
    const ENO_MESSAGE: u64 = 0;

    public fun get_message(addr: address): ASCII::String acquires MessageHolder {
        assert!(exists<MessageHolder>(addr), Errors::not_published(ENO_MESSAGE));
        *&borrow_global<MessageHolder>(addr).message
    }

    public(script) fun set_message(account: signer, message_bytes: vector<u8>)
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
}
