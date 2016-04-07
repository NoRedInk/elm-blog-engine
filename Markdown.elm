module Markdown (..) where

{-| A library for markdown parsing. This is just an Elm API built on top of the
[marked](https://github.com/chjj/marked) project which focuses on speed.

# Parsing Markdown
@docs toElement, toHtml

# Parsing with Custom Options
@docs Options, defaultOptions, toElementWith, toHtmlWith
-}

import Graphics.Element exposing (Element)
import Html exposing (Html)
import Html.Attributes exposing (attribute, property)
import Json.Encode exposing (string)
import Native.Markdown


--import Native.Highlight


{-| Turn a markdown string into an HTML element, using the `defaultOptions`.

    bodyParagraph : Html
    bodyParagraph =
        Markdown.toHtml """

    # Changing History

    In addition to time travel, Elm Reactor lets you change history...

    """
-}
toHtml : String -> Html
toHtml string =
  Native.Markdown.toHtmlWith defaultOptions string


toDiv : String -> Html
toDiv string =
  let
    inner =
      toString string
        |> Json.Encode.string
  in
    Html.div
      [ property "innerHTML" inner ]
      []


toString : String -> String
toString =
  Native.Markdown.toString
    { defaultOptions | defaultHighlighting = Just "elixir" }


fromFile : String -> Html
fromFile name =
  Native.Markdown.fromFile
    { defaultOptions | defaultHighlighting = Just "elixir" }
    name
    |> toDiv


{-| Turn a markdown string into an HTML element, using the `defaultOptions`.

    intro : Element
    intro =
        Markdown.toElement """

    # Time Travel Made Easy

    Elm Reactor grew out of my internship working on Elm at Prezi this summer...

    """
-}
toElement : String -> Element
toElement string =
  Native.Markdown.toElementWith defaultOptions string


{-| Some parser options so you can tweak things for your particular case.

  * `githubFlavored` &mdash; overall reasonable improvements on the original
    markdown parser as described [here][gfm]. This includes stuff like [fenced
    code blocks][fenced]. There are some odd parts though, such as [tables][]
    and a setting to turn all newlines into newlines in the resulting output,
    so there are settings to turn those on or off based on your preference.

  * `defaultHighlighting` &mdash; a default language to use for code blocks that do
    not have a language tag. So setting this to `Just "elm"` will treat all
    unlabeled code blocks as Elm code. (This relies on [highlight.js][highlight]
    as explained in the README [here](../#code-blocks).)

  * `sanitize` &mdash; this determines if all HTML should be escaped. If you
    are parsing user markdown or user input can somehow reach the markdown
    parser, you should almost certainly turn on sanitation. If it is just you
    writing markdown, turning sanitation off is a nice way to do some HTML
    tricks if it is needed.

  * `smartypants` &mdash; This will automatically upgrade quotes to the
    prettier versions and turn dashes into [em dashes or en dashes][dash]


[gfm]: https://help.github.com/articles/github-flavored-markdown/
[fenced]: https://help.github.com/articles/github-flavored-markdown/#fenced-code-blocks
[tables]: https://help.github.com/articles/github-flavored-markdown/#tables
[highlight]: https://highlightjs.org/
[dash]: http://en.wikipedia.org/wiki/Dash
-}
type alias Options =
  { githubFlavored : Maybe { tables : Bool, breaks : Bool }
  , defaultHighlighting : Maybe String
  , sanitize : Bool
  , smartypants : Bool
  }


{-| The `Options` used by the `toElement` and `toHtml` functions.

    { githubFlavored = Just { tables = False, breaks = False }
    , defaultHighlighting = Nothing
    , sanitize = False
    , smartypants = False
    }
-}
defaultOptions : Options
defaultOptions =
  { githubFlavored = Just { tables = False, breaks = False }
  , defaultHighlighting = Nothing
  , sanitize = False
  , smartypants = False
  }


{-| Maybe you want to parse user input into markdown. To stop them from adding
`<script>` tags, you can use modified parsing options.

    options : Options
    options =
        { defaultOptions | sanitize = True }

    toMarkdown : String -> Html
    toMarkdown userInput =
        Markdown.toHtmlWith options userInput
-}
toHtmlWith : Options -> String -> Html
toHtmlWith =
  Native.Markdown.toHtmlWith


{-| Maybe you want to get prettier quotes with a simple syntax. You can use
modified parsing options.

    options : Options
    options =
        { defaultOptions | smartypants = True }

    toSmartElement : String -> Element
    toSmartElement markdown =
        Markdown.toElementWith options markdown
-}
toElementWith : Options -> String -> Element
toElementWith =
  Native.Markdown.toElementWith
