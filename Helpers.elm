module Helpers where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.CssHelpers exposing (..)
import Model exposing (..)

body title content =
    article
        [ class "content wrap" ]
        [ h2
                [ class "post-title" ]
                [ text title ]
        , div
                [ class "post text"]
                [ content ]
        ]


head =
    header
        []
        [ stylesheetLink "/style.css"
        , stylesheetLink "http://fonts.googleapis.com/css?family=Gentium+Book+Basic"
        , Html.node "script" [ attribute "src" "/Native/Highlight.js" ] [ ]
        , stylesheetLink "/default.css"
        , a [] [
            img
                [ src "/logo.png"
                , class "logo"
                ]
                []
            ]
        , a [] [
            h1 [] [ text "Tech" ]
            ]
        ]

authorView : Author -> Html
authorView author =
    div
        [ class "content wrap" ]
        [ img [ src author.img ] []
        , br [] []
        , strong [] [ text author.fullName ]
        , br [] []
        , a [ href ("https://twitter.com" ++ author.twitter)] [ text ("@" ++ author.twitter) ]
        , br [] []
        , text "Engineer at "
        , a [ href "http://noredink.com" ] [ text "NoRedInk"]
        ]

createView author title content =
    div
        []
        [ head
        , body title content
        , authorView author
        ]
