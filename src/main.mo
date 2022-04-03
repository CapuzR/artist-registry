import Principal "mo:base/Principal";

import Result "mo:base/Result";

import Trie "mo:base/Trie";

import Types "./types";
import Utils "./utils";

actor {

  type Metadata = Types.Metadata;
  type Error = Types.Error;

  stable var artists : Trie.Trie<Principal, Metadata> = Trie.empty();
  stable var registryName : Text = "Artists registry";

  public query func name() : async Text {
    return registryName;
  };

  public query func get(canisterId : Principal) : async ?Metadata {

        Trie.find(
            artists,           //Target Trie
            Utils.key(canisterId),      // Key
            Principal.equal     // Equality Checker
        );
        
  };

  public shared({caller}) func add(principal: Principal, metadata : Metadata) : async Result.Result<(), Error> {

        // Reject AnonymousIdentity
        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let artist: Metadata = metadata;

        let (newArtists, existing) = Trie.put(
            artists,           // Target trie
            Utils.key(caller),      // Key
            Principal.equal,    // Equality checker
            artist
        );

        switch(existing) {
            // If there are no matches, add artist
            case null {
                artists := newArtists;
                #ok(());
            };
            case (? v) {
                #err(#AlreadyExists);
            };
        };
  };

  public shared({caller}) func remove(principal: Principal) : async Result.Result<(), Error> {

      if(principal != caller or Principal.isAnonymous(caller)) {
        return #err(#NotAuthorized);
      };

        let result = Trie.find(
            artists,           // Target trie
            Utils.key(principal),      // Key
            Principal.equal,    // Equality checker
        );

        switch(result) {
            // No matches
            case null {
                #err(#NotFound);
            };
            case (? v) {
                artists := Trie.replace(
                    artists,           // Target trie
                    Utils.key(principal),     // Key
                    Principal.equal,   // Equality checker
                    null
                ).0;
                #ok(());
            };
        };
  };

};
