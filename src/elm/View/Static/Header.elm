module View.Static.Header exposing (..)

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Html.Extra
import Style.Extra as Style
import Types exposing (..)

view : Model -> Html Msg
view ({ menuOpen } as model) =
  Html.div
    [ Html.Attributes.class "navbar" ]
    [ Html.div
      [ Html.Attributes.class "navbar-brand" ]
      [ Html.a
        [ Html.Attributes.class "navbar-brand--link"
        , Html.Attributes.href "/"
        , Html.Extra.onPreventClick
          <| Navigation
          <| ChangePage "/"
        ]
        [ Html.text "Guillaume Hivert" ]
      ]
    , navbarMenu model
    , Html.div
      [ Html.Attributes.class "navbar-menu-button" ]
      [ hamburgerButton model ]
    ]

navbarMenu : Model -> Html Msg
navbarMenu { menuOpen, route, user } =
  Html.div
    [ Html.Attributes.class "navbar-menu"
    , Html.Attributes.style
      [ if menuOpen then ("left", "0") else Style.none ]
    ]
    [ link (route == Home) "Accueil" "/"
    , link (route == About) "À propos" "/about"
    , link (case route of
        Archives ->
          True
        _ ->
          False) "Archives" "/archives"
    , case user of
      Just _ ->
        link (route == Dashboard) "Dashboard" "/dashboard"
      Nothing ->
        link (route == Contact) "Contact" "/contact"
    ]

link : Bool -> String -> String -> Html Msg
link active label url =
  Html.a
    [ Html.Attributes.class <| addActive active [ "navbar-menu--link" ]
    , Html.Extra.onPreventClick
      <| Navigation
      <| ChangePage url
    , Html.Attributes.href url
    ]
    [ Html.text label ]

addActive : Bool -> List String -> String
addActive active classes =
  classes
    |> (++) (if active then [ "is-active" ] else [])
    |> String.join " "

hamburgerButton : Model -> Html Msg
hamburgerButton { menuOpen } =
  Html.button
    [ Html.Attributes.class <|
      addActive menuOpen [ "hamburger", "hamburger--vortex" ]
    , Html.Attributes.type_ "button"
    , Html.Events.onClick <| HamburgerMenu ToggleMenu
    ]
    [ Html.span
      [ Html.Attributes.class "hamburger-box" ]
      [ Html.span
        [ Html.Attributes.class "hamburger-inner" ]
        []
      ]
    ]
