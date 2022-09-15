
import Array "mo:base/Array";
import Blob       "mo:base/Blob";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Nat32      "mo:base/Nat32";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

import A          "./Account";
import CRC32      "./CRC32";
import Hex        "./Hex";
import SHA224     "./SHA224";
import Types      "./types";
import Prim "mo:⛔";

module {


    // INVOICE UTILS

    type GenerateInvoiceSubaccountArgs = {
        caller : Principal;
        id : Nat;
    };

     public func generateInvoiceSubaccount (args : GenerateInvoiceSubaccountArgs) : Blob {
        let idHash = SHA224.Digest();
        // Length of domain separator
        idHash.write([0x0A]);
        // Domain separator
        idHash.write(Blob.toArray(Text.encodeUtf8("invoice-id")));
        // Counter as Nonce
        let idBytes = A.beBytes(Nat32.fromNat(args.id));
        idHash.write(idBytes);
        // Principal of caller
        idHash.write(Blob.toArray(Principal.toBlob(args.caller)));

        let hashSum = idHash.sum();
        let crc32Bytes = A.beBytes(CRC32.ofArray(hashSum));
        let buf = Buffer.Buffer<Nat8>(32);
        Blob.fromArray(Array.append(crc32Bytes, hashSum));
    };

     public type GetICPAccountIdentifierArgs = {
        principal : Principal;
        subaccount : Types.SubAccount;
    };
    public func getICPAccountIdentifier(args : GetICPAccountIdentifierArgs) : Blob {
        A.accountIdentifier(args.principal, args.subaccount);
    };

    public func isInDetails (details : [(Text, Types.DetailValue)], v : Text) : Bool {
        for( d in details.vals() ) {
            if( d.0 == v ) {
                return true;
            };
        };
        false;
    };

    public func arrayToBuffer<X>(array : [X]) : Buffer.Buffer<X> {
        let buff : Buffer.Buffer<X> = Buffer.Buffer(array.size() + 2);

        for (a in array.vals()) {
            buff.add(a);
        };
        buff;
    };

    public func key(x : Principal) : Trie.Key<Principal> {
        return { key = x; hash = Principal.hash(x) }
    };

    public func keyText(x : Text) : Trie.Key<Text> {
        return { key = x; hash = Text.hash(x) }
    };

    public func isAuthorized(p : Principal, authorized : [Principal]) : Bool {

        if(Principal.isAnonymous(p)) {
            return false;
        };

        for (a in authorized.vals()) {
            if (Principal.equal(a, p)) return true;
        };
        false;
    };

}