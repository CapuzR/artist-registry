
module {

    public type ArtBasics = {
        thumbnail : Text;
        title: Text;
        description: Text;
        artType: Text;
        tags: [Text];
        details: [(Text, DetailValue)];
    };

    // public type ArtPrivate = {
    //     thumbnail : Text;
    //     title: Text;
    //     description: Text;
    //     artType: Text;
    //     tags: [Text];
    //     details: [(Text, DetailValue)];
    // };

    public type Art = {
        artBasics: ArtBasics;
        createdAt: Int;
    };

    public type ArtUpdate = {
        artBasics: ArtBasics;
    };


//General Types

    public type Metadata = {
        thumbnail : Text;
        name : Text;
        frontend : ?[Text];
        description : Text;
        principal_id : Principal;
        details : [(Text, DetailValue)];
    };

    public type DetailValue = {
        #I64 : Int64;
        #U64 : Nat64;
        #Vec : [DetailValue];
        #Slice : [Nat8];
        #Text : Text;
        #True;
        #False;
        #Float : Float;
        #Principal : Principal;
    };

    public type Error = {
        #AlreadyExists;
        #NotAuthorized;
        #Unauthorized;
        #NotFound;
        #InvalidRequest;
        #AuthorizedPrincipalLimitReached : Nat;
        #Immutable;
        #FailedToWrite : Text;
    };
}