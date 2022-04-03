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
        if(Principal.toText(caller) == "2vxsx-fae") {
            return #err(#NotAuthorized);
        };

        let artist: Metadata = metadata;

        let (newArtists, existing) = Trie.put(
            artists,           // Target trie
            Utils.key(caller),      // Key
            Principal.equal,    // Equality checker
            artist
        );

        // If there is an original value, do not update
        switch(existing) {
            // If there are no matches, update artists
            case null {
                artists := newArtists;
                #ok(());
            };
            // Matches pattern of type - opt Artist
            case (? v) {
                #err(#AlreadyExists);
            };
        };
  };

  public shared({caller}) func remove(principal: Principal) : async Result.Result<(), Error> {

      if(principal != caller or Principal.toText(caller) == "2vxsx-fae") {
        return #err(#NotAuthorized);
      };

        let result = Trie.find(
            artists,           // Target trie
            Utils.key(principal),      // Key
            Principal.equal,    // Equality checker
        );

        // If there is an original value, do not update
        switch(result) {
            // If there are no matches, update artists
            case null {
                #err(#NotFound);
            };
            // Matches pattern of type - opt Artist
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
