// If ever updating this version, also update:
// - driver/src/main.rs
// - aptos_infinite_jukebox/lib/constants.dart
module AptosInfiniteJukebox::JukeboxV8 {
    use Std::ASCII;
    use Std::Errors;
    use Std::Signer;
    use Std::Table;
    use Std::Timestamp;
    use Std::Vector;

    /// How long to delay "playing" the first song when a jukebox is initialized. 
    const DELAY_BETWEEN_SONGS: u64 = 5000000;  // 5 seconds.

    /// This is how long prior to the end of a song that the driver kicks in and
    /// triggers vote resolution. Realistically it's impossible to time this perfectly,
    /// so this sets a lower bound on when the next song will start, mostly guaranteeing
    /// that the next song will start some time after the end of the previou song.
    /// The frontend can adapt to this and pause playback when one song ends until it
    /// is the right time to start the next song. This value should match the
    /// resolve_votes_threshold_ms value for the driver (except this is in microseconds,
    /// not milliseconds).
    const TIME_BEFORE_END_OF_SONG_VOTE_RESOLUTION_TRIGGERED: u64 = 20000000;  // 20 seconds.

    /// How many songs should be in the queue at all times.
    const NUM_SONGS_IN_QUEUE: u64 = 5;

    /// There is no jukebox present yet (meaning initialize_jukebox hasn't
    /// been called yet).
    const E_NO_JUKEBOX: u64 = 0;

    /// Indicates that one of the assertions that the internal state
    /// is as expected following a particular function call didn't pass.
    const E_BROKEN_INTERNAL_INVARIANT: u64 = 1;

    #[test_only]
    /// Used for assertions in tests.
    const E_TEST_FAILURE: u64 = 100;

    /// Top level module. This just contains the Inner struct, which actually
    /// holds all the interesting stuff. We do it this way so it's easy to
    /// grab a mutable reference to everything at once without running into
    /// issues from holding multiple references. This is acceptable for now.
    struct JukeboxV8 has key {
        inner: Inner,
    }

    /// All the interesting stuff.
    struct Inner has store {
        /// The queue of songs. The client should be playing the song at
        /// the head of the queue, offset based on how long it has been
        /// since time_to_start_playing.
        song_queue: vector<Song>,
        /// Time in microseconds when the current song should start
        /// playing / has started playing.
        time_to_start_playing: u64,
        /// Votes for which song to next put at the end of the queue.
        /// Currently votes are not weighted or ACL'd, any account
        /// can submit one vote.
        next_song_votes: Table::Table<address, Vote>,
        // We need this since you can't enumerate all keys in a table / iterate
        // through all the KV pairs in a table. This will contain duplicates,
        // what I really need is a set.
        voters: vector<address>,
    }

    /// Pretty much a newtype (using Rust terminology).
    struct Song has copy, drop, store {
        /// This must be the Spotify ID of the track, e.g. 0H8XeaJunhvpBdBFIYi6Sh
        /// See https://developer.spotify.com/documentation/web-api/
        /// Currently we don't deal with what happens if an invalidstring (i.e. not
        /// a Spotify track ID) wins the election.
        song: ASCII::String,
    }

    /// We represent a vote as a struct in case we want to add further
    /// fields down the line, e.g. a weight for the vote based on some
    /// (governance) token spend.
    struct Vote has copy, drop, store {
        song: Song,
    }

    /// Initialize the infinite jukebox. For now we seed it with songs right here.
    public(script) fun initialize_jukebox(account: &signer) {
        let q = Vector::empty<Song>();
        // Bootstrap the queue with NUM_SONGS_IN_QUEUE songs.
        // If we change this number, change the tests too.

        // White Winter Hymnal
        Vector::push_back(&mut q, Song { song: ASCII::string(b"3QVtICc8ViNOy4I5K14d8Z") });
        // Mamadou Kanda Keita
        Vector::push_back(&mut q, Song { song: ASCII::string(b"6jgeug0bubcri5YcS23WeQ") });
        // Anaguragurashi
        Vector::push_back(&mut q, Song { song: ASCII::string(b"3FvzeaesPY35bhhj55u4zJ") });
        // Uncover
        Vector::push_back(&mut q, Song { song: ASCII::string(b"2oFbMd0TcgUm7Df4Sx16h9") });
        // Igor's Theme
        Vector::push_back(&mut q, Song { song: ASCII::string(b"51RN0kzWd7xeR4th5HsEtW") });

        assert!(Vector::length(&q) == NUM_SONGS_IN_QUEUE, Errors::internal(E_BROKEN_INTERNAL_INVARIANT));
        let inner = Inner {
            song_queue: q,
            time_to_start_playing: Timestamp::now_microseconds() + DELAY_BETWEEN_SONGS,
            next_song_votes: Table::new<address, Vote>(),
            voters: Vector::empty<address>(),
        };
        move_to(account, JukeboxV8 { inner });
    }

    /// Public wrapper around vote, since you can't use structs nor ascii in external calls.
    public(script) fun vote(voter: &signer, jukebox_address: address, vote: vector<u8>) acquires JukeboxV8 {
        let v = Vote { song: Song { song: ASCII::string(vote) } };
        vote_internal(voter, jukebox_address, v);
    }

    /// Vote for what song to play in the next round. The user is able to
    /// change their vote if they want.
    fun vote_internal(voter: &signer, jukebox_address: address, vote: Vote) acquires JukeboxV8 {
        assert!(exists<JukeboxV8>(jukebox_address), Errors::not_published(E_NO_JUKEBOX));

        let voter_addr = Signer::address_of(voter);
        let inner = &mut borrow_global_mut<JukeboxV8>(jukebox_address).inner;
        *Table::borrow_mut_with_default(&mut inner.next_song_votes, &voter_addr, copy vote) = vote;
        Vector::push_back(&mut inner.voters, voter_addr);
    }

    /// Resolve the votes into a final selection of which song to put on the
    /// queue next. Currently there is no protection ensuring that the song IDs
    /// given to us are valid in any way. If there are no votes, we just move the
    /// song at the head of the queue to the tail. This function uses a very
    /// roundabout way of figuring this all out, given there is no native Counter
    /// right now (though see https://github.com/aptos-labs/aptos-core/pull/907).
    /// If the "driver" of this module (a cron that calls resolve_votes every
    /// time a song ends) stops calling this function, we expect clients will
    /// just not play anything.
    public(script) fun resolve_votes(account: &signer) acquires JukeboxV8 {
        let addr = Signer::address_of(account);

        assert!(exists<JukeboxV8>(addr), Errors::not_published(E_NO_JUKEBOX));

        let inner = &mut borrow_global_mut<JukeboxV8>(addr).inner;

        // Build up a counter of Vote to how many people made that vote.
        let vote_counter = Table::new<Vote, u64>();
        let vote_keys = Vector::empty<Vote>();
        while (Vector::length(&inner.voters) > 0) {
            let voter_addr = Vector::pop_back(&mut inner.voters);
            if (Table::contains(&mut inner.next_song_votes, &voter_addr)) {
                let vote = Table::remove(&mut inner.next_song_votes, &voter_addr);
                let value = Table::borrow_mut_with_default(&mut vote_counter, &vote, 0);
                Vector::push_back(&mut vote_keys, vote);
                *value = *value + 1;
            };
        };

        // Run through that counter to figure out which song won the election. If there
        // is a tie, currently whichever tied song was voted for first will win.
        // Here we pop the head off the queue and then push a new song onto the end.
        // If there were no votes, we just use the head and put that on the tail.
        let current_winner = Vector::remove(&mut inner.song_queue, 0);
        if (Table::length(&mut vote_counter) > 0) {
            let current_winner_num_votes = 0;
            while (Vector::length(&vote_keys) > 0) {
               let vote = Vector::pop_back(&mut vote_keys);
               let vote_count = Table::remove(&mut vote_counter, &vote);
               if (vote_count > current_winner_num_votes) {
                   let song = vote.song;
                   current_winner = copy song;
                   current_winner_num_votes = vote_count;
               };
            };
        };
        Vector::push_back(&mut inner.song_queue, current_winner);

        // Update time_to_start_playing regardless of whether a new song was elected.
        *&mut inner.time_to_start_playing = Timestamp::now_microseconds() + TIME_BEFORE_END_OF_SONG_VOTE_RESOLUTION_TRIGGERED;

        // Make sure everything ends / is reset as expected.
        Table::destroy_empty(vote_counter);
        assert!(Vector::length(&vote_keys) == 0, Errors::internal(E_BROKEN_INTERNAL_INVARIANT));
        assert!(Table::length(&inner.next_song_votes) == 0, Errors::internal(E_BROKEN_INTERNAL_INVARIANT));
        assert!(Vector::length(&inner.voters) == 0, Errors::internal(E_BROKEN_INTERNAL_INVARIANT));

        // Make sure we still have the expected number of songs in the queue.
        assert!(Vector::length(&inner.song_queue) == NUM_SONGS_IN_QUEUE, Errors::internal(E_BROKEN_INTERNAL_INVARIANT));
    }

    #[test(core_resources = @CoreResources, account1 = @0x123, account2 = @0x456)]
    public(script) fun test_initialize(core_resources: signer, account1: signer, account2: signer) acquires JukeboxV8 {
        Timestamp::set_time_has_started_for_testing(&core_resources);

        // Account 1 is where we initialize the jukebox.
        // Account 2 is a participating voter.
        let addr1 = Signer::address_of(&account1);
        let _addr2 = Signer::address_of(&account2);

        // Initialize a jukebox on account1.
        initialize_jukebox(&account1);
        assert!(exists<JukeboxV8>(addr1), Errors::internal(E_TEST_FAILURE));

        // Assert that we can see the initial song.
        let front_of_queue = Vector::borrow(&borrow_global<JukeboxV8>(addr1).inner.song_queue, 0).song;
        assert!(
          front_of_queue == ASCII::string(b"3QVtICc8ViNOy4I5K14d8Z"),
          E_TEST_FAILURE
        );
    }

    #[test(core_resources = @CoreResources, account1 = @0x123, account2 = @0x456)]
    public(script) fun test_vote(core_resources: signer, account1: signer, account2: signer) acquires JukeboxV8 {
        Timestamp::set_time_has_started_for_testing(&core_resources);

        // Account 1 is where we initialize the jukebox.
        // Account 2 is a participating voter.
        let addr1 = Signer::address_of(&account1);
        let addr2 = Signer::address_of(&account2);

        // Initialize a jukebox on account1.
        initialize_jukebox(&account1);
        assert!(exists<JukeboxV8>(addr1), Errors::internal(E_TEST_FAILURE));

        // Submit a vote.
        let vote = Vote { song: Song { song: ASCII::string(b"abc1234") }};
        vote_internal(&account2, addr1, vote);

        // Assert that we can see that vote.
        let votes = &borrow_global<JukeboxV8>(addr1).inner.next_song_votes;
        assert!(Table::borrow(votes, &addr2) == &vote, Errors::internal(E_TEST_FAILURE));

        // Assert that a voter can change their vote.
        let vote2 = Vote { song: Song { song: ASCII::string(b"xyz6789") }};
        vote_internal(&account2, addr1, vote2);
        let votes = &borrow_global<JukeboxV8>(addr1).inner.next_song_votes;
        assert!(Table::borrow(votes, &addr2) == &vote2, Errors::internal(E_TEST_FAILURE));
    }

    #[test(core_resources = @CoreResources, account1 = @0x123, account2 = @0x456)]
    public(script) fun test_resolve_votes(core_resources: signer, account1: signer, account2: signer) acquires JukeboxV8 {
        Timestamp::set_time_has_started_for_testing(&core_resources);

        // Account 1 is where we initialize the jukebox.
        // Account 2 is a participating voter.
        let addr1 = Signer::address_of(&account1);
        let _addr2 = Signer::address_of(&account2);

        // Initialize a jukebox on account1.
        initialize_jukebox(&account1);
        assert!(exists<JukeboxV8>(addr1), Errors::internal(E_TEST_FAILURE));

        // Get current time_to_start_playing.
        let front_of_queue_1 = Vector::borrow(&borrow_global<JukeboxV8>(addr1).inner.song_queue, 0).song;
        let time_to_start_playing_1 = borrow_global<JukeboxV8>(addr1).inner.time_to_start_playing;

        // Advance the clock to 1 second since epoch.
        Timestamp::update_global_time_for_test(10000000000000000);

        // Resolve votes.
        resolve_votes(&account1);

        // Assert that the next song at the front of the queue is what was previously
        // second in the queue, and that the previous song is now at the end of the
        // queue (since there weren't any votes). Also assert that time_to_start_playing
        // has been updated.
        let front_of_queue_2 = Vector::borrow(&borrow_global<JukeboxV8>(addr1).inner.song_queue, 0).song;
        let end_of_queue_2 = Vector::borrow(&borrow_global<JukeboxV8>(addr1).inner.song_queue, NUM_SONGS_IN_QUEUE - 1).song;
        let time_to_start_playing_2 = borrow_global<JukeboxV8>(addr1).inner.time_to_start_playing;

        assert!(front_of_queue_2 == ASCII::string(b"6jgeug0bubcri5YcS23WeQ"), Errors::internal(E_TEST_FAILURE));
        assert!(end_of_queue_2 == front_of_queue_1, Errors::internal(E_TEST_FAILURE));
        assert!(time_to_start_playing_2 > time_to_start_playing_1, Errors::internal(E_TEST_FAILURE));

        // Submit a vote.
        let vote = Vote { song: Song { song: ASCII::string(b"abc1234") }};
        vote_internal(&account2, addr1, vote);

        // Update the clock by 2 seconds since epoch.
        Timestamp::update_global_time_for_test(20000000000000000);

        // Resolve votes.
        resolve_votes(&account1);

        // Assert that the song we voted for (the only vote) was selected and put
        // at the end of the queue.
        let end_of_queue_3 = Vector::borrow(&borrow_global<JukeboxV8>(addr1).inner.song_queue, NUM_SONGS_IN_QUEUE - 1).song;
        let time_to_start_playing_3 = borrow_global<JukeboxV8>(addr1).inner.time_to_start_playing;

        assert!(end_of_queue_3 == vote.song.song, Errors::internal(E_TEST_FAILURE));
        assert!(time_to_start_playing_3 > time_to_start_playing_2, Errors::internal(E_TEST_FAILURE));
    }

    #[test(core_resources = @CoreResources, account1 = @0x123, account2 = @0x456)]
    public(script) fun test_vote_public(core_resources: signer, account1: signer, account2: signer) acquires JukeboxV8 {
        Timestamp::set_time_has_started_for_testing(&core_resources);

        // Account 1 is where we initialize the jukebox.
        // Account 2 is a participating voter.
        let addr1 = Signer::address_of(&account1);

        // Initialize a jukebox on account1.
        initialize_jukebox(&account1);
        assert!(exists<JukeboxV8>(addr1), Errors::internal(E_TEST_FAILURE));

        // Submit a vote.
        let vote = b"abc1234";
        vote(&account2, addr1, vote);
    }
}
