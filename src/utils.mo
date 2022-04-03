
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";

module {

    public func key(x : Principal) : Trie.Key<Principal> {
        return { key = x; hash = Principal.hash(x) }
    };

}