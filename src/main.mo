import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Trie "mo:base/Trie";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Types "./types";
import Utils "./utils";
import Prim "mo:prim";

import aC "./actorClasses/artist/artistCanister";

actor {

  type Metadata = Types.Metadata;
  type Error = Types.Error;
  type DetailValue = Types.DetailValue;

  stable var artists : Trie.Trie<Principal, Metadata> = Trie.empty();
  stable var registryName : Text = "Artists registry";

  public query func name() : async Text {
    return registryName;
  };

  public query func get(principalId : Principal) : async ?Metadata {
    Trie.find(
        artists,
        Utils.key(principalId),
        Principal.equal
    ); 
  };

  public shared({caller}) func add(metadata : Metadata) : async Result.Result<(), Error> {

    if(Principal.isAnonymous(caller)) {
        return #err(#NotAuthorized);
    };

    let artist : Metadata = metadata;

    let (newArtist, existing) = Trie.put(
        artists,           // Target trie
        Utils.key(caller),      // Key
        Principal.equal,    // Equality checker
        artist
    );

    switch(existing) {
        // If there are no matches, add artist
        case null {
            artists := newArtist;
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

  public shared({caller}) func update(principal: Principal, metadata : Metadata) : async Result.Result<(), Error> {

    if(principal != caller or Principal.isAnonymous(caller)) {
        return #err(#NotAuthorized);
    };

    _update(caller, metadata);
  };

  public query func getCanMemInfo() : async () {

      return ();

    //   Debug.print(debug_show("memory size"));
    //   Debug.print(debug_show(Prim.rts_memory_size()));
    //   Debug.print(debug_show("Stable memory size"));
    //   Debug.print(debug_show(Prim.stableMemorySize()));
    //   Debug.print(debug_show("total_allocation"));
    //   Debug.print(debug_show(Prim.rts_total_allocation()));
    //   Debug.print(debug_show("max live size"));
    //   Debug.print(debug_show(Prim.rts_max_live_size()));
    //   Debug.print(debug_show("heap"));
    //   Debug.print(debug_show(Prim.rts_heap_size()));
  };
  
  public shared({caller}) func createArtistCan() : async Result.Result<(), Error> {

    if(Principal.isAnonymous(caller)) {
        return #err(#NotAuthorized);
    };

    let result = Trie.find(
        artists,
        Utils.key(caller),
        Principal.equal,
    );

    switch(result) {
        case (? v) {

            if(v.principal_id != caller) { return #err(#NotAuthorized); };
            if(Utils.isInDetails(v.details, "canisterId")) { return #err(#AlreadyExists); };

            let artistCan = await aC.ArtistCanister(v);
            let canisterId = await artistCan.getCanisterId();
            let buff : Buffer.Buffer<(Text, DetailValue)> = Utils.arrayToBuffer(v.details);
            buff.add(("canisterId", #Principal(canisterId)));

            let artist: Metadata = {
                thumbnail = v.thumbnail;
                name = v.name;
                frontend = null;
                description = v.description;
                principal_id = v.principal_id;
                details = buff.toArray();
            };
            _update(caller, artist);
        };
        case null {
            return #err(#NotFound);
        };
    };
  };

  private func _update(principal: Principal, artist : Metadata) : Result.Result<(), Error> {

    let result = Trie.find(
        artists,           // Target trie
        Utils.key(principal),     // Key
        Principal.equal           // Equality Checker
    );

    switch(result) {
        
        case null {
            #err(#NotFound);
        };
        case (? v) {
            artists := Trie.replace(
                artists,
                Utils.key(principal),
                Principal.equal,
                ?artist
            ).0;
            #ok(());
        };
    };
  };

};