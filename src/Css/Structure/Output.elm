module Css.Structure.Output exposing (prettyPrint)

import Css.Structure exposing (..)
import String


prettyPrint : Stylesheet -> String
prettyPrint { charset, imports, namespaces, declarations } =
    [ charsetToString charset
    , String.join "\n" (List.map importToString imports)
    , String.join "\n" (List.map namespaceToString namespaces)
    , String.join "\n\n" (List.map prettyPrintDeclaration declarations)
    ]
        |> List.filter (not << String.isEmpty)
        |> String.join "\n\n"


charsetToString : Maybe String -> String
charsetToString charset =
    charset
        |> Maybe.map (\str -> "@charset \"" ++ str ++ "\"")
        |> Maybe.withDefault ""


importToString : ( String, List MediaQuery ) -> String
importToString ( name, mediaQueries ) =
    -- TODO
    "@import \"" ++ name ++ toString mediaQueries ++ "\""


namespaceToString : ( String, String ) -> String
namespaceToString ( prefix, str ) =
    "@namespace "
        ++ prefix
        ++ "\""
        ++ str
        ++ "\""


prettyPrintStyleBlock : String -> StyleBlock -> String
prettyPrintStyleBlock indentLevel (StyleBlock firstSelector otherSelectors properties) =
    let
        selectorStr =
            (firstSelector :: otherSelectors)
                |> List.map selectorToString
                |> String.join ", "
    in
    String.join ""
        [ selectorStr
        , " {\n"
        , indentLevel
        , prettyPrintProperties properties
        , "\n"
        , indentLevel
        , "}"
        ]


prettyPrintDeclaration : Declaration -> String
prettyPrintDeclaration declaration =
    case declaration of
        StyleBlockDeclaration styleBlock ->
            prettyPrintStyleBlock noIndent styleBlock

        MediaRule mediaQueries styleBlocks ->
            let
                blocks =
                    List.map (indent << prettyPrintStyleBlock spaceIndent) styleBlocks
                        |> String.join "\n\n"

                query =
                    List.map mediaQueryToString mediaQueries
                        |> String.join ",\n"

                finalQuery =
                    if String.startsWith "not " query then
                        -- Media queries can start with `only` or they can start
                        -- with `not`, but they can't start with both.
                        -- See https://developer.mozilla.org/en-US/docs/Web/CSS/Media_Queries/Using_media_queries#Pseudo-BNF
                        query
                    else
                        -- Always emit `only` when we don't have `not`,
                        -- because without `only`, older browsers can
                        -- break, and with `only`, they'll ignore this declaration
                        -- instead of breaking.
                        --
                        -- The one downside is emitting extra characters, but if
                        -- every @media is followed by either `not` or `only`,
                        -- they will gzip very well.
                        --
                        -- https://stackoverflow.com/questions/8549529/what-is-the-difference-between-screen-and-only-screen-in-media-queries/14168210#14168210
                        "only " ++ query
            in
            "@media " ++ finalQuery ++ " {\n" ++ blocks ++ "\n}"

        _ ->
            Debug.crash "not yet implemented :x"


mediaQueryToString : MediaQuery -> String
mediaQueryToString mediaQuery =
    case mediaQuery of
        FeatureQuery mediaFeature ->
            mediaFeatureToString mediaFeature

        TypeQuery All ->
            "all"

        TypeQuery Print ->
            "print"

        TypeQuery Screen ->
            "screen"

        TypeQuery Speech ->
            "speech"

        And first second ->
            "(" ++ mediaQueryToString first ++ " and " ++ mediaQueryToString second ++ ")"

        Or first second ->
            "(" ++ mediaQueryToString first ++ " or " ++ mediaQueryToString second ++ ")"

        Not mediaQuery ->
            let
                str =
                    mediaQueryToString mediaQuery
            in
            -- If it already had a "not " prefix, negate it by dropping that prefix.
            if String.startsWith "not " str then
                String.dropLeft 4 str
            else
                "not " ++ str

        CustomQuery str ->
            str


mediaFeatureToString : MediaFeature -> String
mediaFeatureToString mediaFeature =
    case mediaFeature.value of
        Just value ->
            "(" ++ mediaFeature.key ++ ": " ++ value ++ ")"

        Nothing ->
            mediaFeature.key


simpleSelectorSequenceToString : SimpleSelectorSequence -> String
simpleSelectorSequenceToString simpleSelectorSequence =
    case simpleSelectorSequence of
        TypeSelectorSequence (TypeSelector str) repeatableSimpleSelectors ->
            (str :: List.map repeatableSimpleSelectorToString repeatableSimpleSelectors)
                |> String.join ""

        UniversalSelectorSequence repeatableSimpleSelectors ->
            if List.isEmpty repeatableSimpleSelectors then
                "*"
            else
                List.map repeatableSimpleSelectorToString repeatableSimpleSelectors
                    |> String.join ""

        CustomSelector str repeatableSimpleSelectors ->
            (str :: List.map repeatableSimpleSelectorToString repeatableSimpleSelectors)
                |> String.join ""


repeatableSimpleSelectorToString : RepeatableSimpleSelector -> String
repeatableSimpleSelectorToString repeatableSimpleSelector =
    case repeatableSimpleSelector of
        ClassSelector str ->
            "." ++ str

        IdSelector str ->
            "#" ++ str

        PseudoClassSelector str ->
            ":" ++ str


selectorChainToString : ( SelectorCombinator, SimpleSelectorSequence ) -> String
selectorChainToString ( combinator, sequence ) =
    [ combinatorToString combinator
    , simpleSelectorSequenceToString sequence
    ]
        |> String.join " "


pseudoElementToString : PseudoElement -> String
pseudoElementToString (PseudoElement str) =
    "::" ++ str


selectorToString : Selector -> String
selectorToString (Selector simpleSelectorSequence chain pseudoElement) =
    let
        segments =
            [ simpleSelectorSequenceToString simpleSelectorSequence ]
                ++ List.map selectorChainToString chain

        pseudoElementsString =
            String.join "" [ Maybe.withDefault "" (Maybe.map pseudoElementToString pseudoElement) ]
    in
    segments
        |> List.filter (not << String.isEmpty)
        |> String.join " "
        |> flip (++) pseudoElementsString


combinatorToString : SelectorCombinator -> String
combinatorToString combinator =
    case combinator of
        AdjacentSibling ->
            "+"

        GeneralSibling ->
            "~"

        Child ->
            ">"

        Descendant ->
            ""


prettyPrintProperty : Property -> String
prettyPrintProperty { key, value, important } =
    let
        suffix =
            if important then
                " !important;"
            else
                ";"
    in
    key ++ ": " ++ value ++ suffix


{-| Indent the given string with 4 spaces
-}
indent : String -> String
indent str =
    spaceIndent ++ str


spaceIndent : String
spaceIndent =
    "    "


noIndent : String
noIndent =
    ""


prettyPrintProperties : List Property -> String
prettyPrintProperties properties =
    properties
        |> List.map (indent << prettyPrintProperty)
        |> String.join "\n"
