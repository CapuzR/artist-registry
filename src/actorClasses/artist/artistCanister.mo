import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Trie "mo:base/Trie";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Types "./types";
import Utils "../../utils";
import Source "mo:uuid/async/SourceV4";
import UUID "mo:uuid/UUID";

import assetC "../asset/assetCanister";

shared({ caller = owner }) actor class ArtistCanister(artistMeta: Types.Metadata) = this {

    type Metadata = Types.Metadata;
    type Error = Types.Error;
    type Art = Types.Art;
    type ArtUpdate = Types.ArtUpdate;

    stable var arts : Trie.Trie<Text, Art> = Trie.empty();
    // stable var assetCanisterRel : Trie.Trie<Text, Principal> = Trie.empty();
    stable var registryName : Text = Text.concat(artistMeta.name, "Artist Canister");
    stable var canisterMeta : Metadata = artistMeta;
    stable var assetCanisterId : [Principal] = [];
    stable var authorized : [Principal] = [owner, artistMeta.principal_id];

    public query({caller}) func authorizedArr() : async [Principal] {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        return authorized;
    };

    public query func name() : async Text {
        return registryName;
    };

    public query func artistMetadata() : async Metadata {
        return canisterMeta;
    };

    public query func getCanisterId() : async Principal {
        return Principal.fromActor(this);
    };

    public query({caller}) func getAssetCanId() : async [Principal] {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        return assetCanisterId;
    };

    public shared({caller}) func createAssetCan() : async Result.Result<(), Error> {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };
        
        if(assetCanisterId.size() != 0) { return #err(#AlreadyExists); };

        let assetCan = await assetC.Assets(owner);
        let canisterId = await assetCan.getCanisterId();
        assetCanisterId := Array.append(assetCanisterId, [canisterId]);

        return #ok(());

    };

    //Art...............................................................................
    public shared({caller}) func createArt(art : ArtUpdate) : async Result.Result<(), Error> {

        let g = Source.Source();
        let artId = UUID.toText(await g.new());

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };
        
        let newArt : Art = {
            artBasics = art.artBasics;
            createdAt = Time.now();
        };

        let (newArts, existing) = Trie.put(
            arts,         
            Utils.keyText(artId), 
            Text.equal,    
            newArt
        );

        switch(existing) {
            case null {
                arts := newArts;
                #ok(());
            };
            case (? v) {
                #err(#AlreadyExists);
            };
        };
    };
    //Este privado debe tener la imagen grande y el thumbnail.
    public query({caller}) func privReadArtById (id : Text) : async Result.Result<Art, Error> {
        
        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };
        
        let result : ?Art = Trie.find(
            arts,
            Utils.keyText(id),
            Text.equal
        );
        
        switch (result){
            case null {
                #err(#NotFound)
            };
            case (? r) {
                #ok(r);
            };
        };
    };
    //Este p'ublico debe tener solo el thumbnail.
    public query({caller}) func readArtById (id : Text) : async Result.Result<Art, Error> {
        
        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };
        
        let result : ?Art = Trie.find(
            arts,
            Utils.keyText(id),
            Text.equal
        );
        
        switch (result){
            case null {
                #err(#NotFound)
            };
            case (? r) {
                #ok(r);
            };
        };
    };

    public shared({caller}) func updateArt (art : ArtUpdate, artId : Text) : async Result.Result<(), Error> {
        
        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            arts,
            Utils.keyText(artId),
            Text.equal 
        );

        switch(result) {
            case null {
                #err(#NotFound)
            };
            case (? v) {
                let newArt : Art = {
                    artBasics = art.artBasics;
                    createdAt = v.createdAt;
                };

                arts := Trie.replace(
                    arts,     
                    Utils.keyText(artId), 
                    Text.equal,  
                    ?newArt
                ).0;
                return #ok(());
            };
            case (#err(e)) { #err(#FailedToWrite(e)); };
        };
    };

    public shared({caller}) func deleteArt (artId : Text) : async Result.Result<(), Error> {
        
        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            arts,
            Utils.keyText(artId),
            Text.equal 
        );

        switch(result) {
            case null {
                #err(#NotFound)
            };
            case (? v) {
                arts := Trie.replace(
                    arts,
                    Utils.keyText(artId),
                    Text.equal,
                    null
                ).0;
                return #ok(());
            };
        };
    };
}