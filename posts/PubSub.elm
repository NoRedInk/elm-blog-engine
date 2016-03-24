module PubSub where

import Helpers
import Model exposing (..)
import Markdown



content =
    Markdown.fromFile "/posts/pubsub.md"

title = "Pub/Sub in 30 Lines of Elixir"

view =
    Helpers.createView authors.jeg2 title content


main = view
