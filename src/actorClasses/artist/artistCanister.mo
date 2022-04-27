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
    stable var registryName : Text = Text.concat(artistMeta.name, "Artist Canister");
    stable var canisterMeta : Metadata = artistMeta;
    stable var assetCanisterIds : [Principal] = [];
    stable var authorized : [Principal] = [owner, artistMeta.principal_id];

    public query({caller}) func authorizedArr () : async Result.Result<[Principal], Error> {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        return #ok(authorized);
    };

    public query func name () : async Text {
        return registryName;
    };

    public query func artistMetadata () : async Metadata {
        return canisterMeta;
    };

    public query func getCanisterId () : async Principal {
        return Principal.fromActor(this);
    };

    public query({caller}) func getAssetCanIds () : async  Result.Result<[Principal], Error>  {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        return #ok(assetCanisterIds);
    };

    public query({caller}) func getCanIds () : async  [Principal]  {

        return [Principal.fromActor(this), assetCanisterIds[0]];
    };

    public shared({caller}) func createAssetCan () : async Result.Result<(Principal, Principal), Error> {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };
        
        if(assetCanisterIds.size() != 0) { return #err(#AlreadyExists); };

        let assetCan = await assetC.Assets(canisterMeta.principal_id);
        let assetCanisterId = await assetCan.getCanisterId();
        assetCanisterIds := Array.append(assetCanisterIds, [assetCanisterId]);

        return #ok((Principal.fromActor(this), assetCanisterId));

    };

    //Art...............................................................................
    public shared({caller}) func createArt (art : ArtUpdate) : async Result.Result<Text, Error> {

        let g = Source.Source();
        let artId = UUID.toText(await g.new());

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };
        
        let newArt : Art = {
            artBasics = art.artBasics;
            createdAt = Time.now();
            thumbnail = Text.concat("http://localhost:8000/", Text.concat(artId, Text.concat(".jpeg?canisterId=", Principal.toText(assetCanisterIds[0]))));
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
                await _storeImage(Text.concat("T", artId), art.thumbAsset);
                #ok(artId);
            };
            case (? v) {
                #err(#AlreadyExists);
            };
        };
    };
    
    public query({caller}) func privReadArtById (id : Text) : async Result.Result<Art, Error> {
        
        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };
        
        let result : ?Art = Trie.find(
            arts,
            Utils.keyText(id),
            Text.equal
        );
        
        switch (result) {
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
                    thumbnail = v.thumbnail;
                };

                arts := Trie.replace(
                    arts,
                    Utils.keyText(artId),
                    Text.equal,
                    ?newArt
                ).0;

                if ( art.updateThumbnail ) {
                    await _deleteImage(Text.concat("T", artId));
                    await _storeImage(Text.concat("T", artId), art.thumbAsset);
                };
                return #ok(());
            };
            // case (#err) { return #err(#FailedToWrite(e)); };
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

//Private
    private func _storeImage (name : Text, asset : Blob) : async () {

        let key = Text.concat(name, ".jpeg");
        
        let aCActor = actor(Principal.toText(assetCanisterIds[0])): actor { 
            store : shared ({
                key : Text;
                content_type : Text;
                content_encoding : Text;
                content : Blob;
                sha256 : ?Blob;
            }) -> async ()
        };
        await aCActor.store({
                key = key;
                content_type = "image/jpeg";
                content_encoding = "identity";
                content = asset;
                sha256 = null;
        });

    };

    private func _deleteImage (name : Text) : async () {

        let key = Text.concat(name, ".jpeg");
        
        let aCActor = actor(Principal.toText(assetCanisterIds[0])): actor { 
            delete_asset : shared ({
                key : Text;
            }) -> async ()
        };
        await aCActor.delete_asset({
                key = key;
        });

    };
}