module Main exposing (..)

import Navigation exposing (Location)
import Html exposing (Html)
import Html.Attributes
import Html.Extra
import Update.Extra as Update
import Update.Extra.Infix exposing (..)
import Window
import Date exposing (Date)
import Task
import Json.Decode as Decode
import Maybe.Extra as Maybe

import Types exposing (..)
import Article
import Article.Decoder
import Article.Encoder
import User.Decoder
import Routing
import View.Home
import View.Article
import View.Archives
import View.Contact
import View.Login
import View.Dashboard
import View.Static.Header
import View.Static.Footer
import View.Static.NotFound
import View.Static.About
import Firebase

myself : String
myself =
  "myself"

main : Program Never Model Msg
main =
  Navigation.program (Navigation << NewLocation)
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ Window.resizes Resizes
    , firebaseSubscriptions model
    ]

firebaseSubscriptions : Model -> Sub Msg
firebaseSubscriptions model =
  Sub.batch
    [ Firebase.requestedPosts GetPosts
    , Firebase.authChanges GetUser
    , Firebase.createdPost AcceptPost
    ]

init : Location -> (Model, Cmd Msg)
init location =
  { location = location
  , route = Routing.parseLocation location
  , articles = Nothing
  , menuOpen = False
  , contactFields =
    { email = ""
    , message = ""
    }
  , loginFields =
    { email = ""
    , password = ""
    }
  , newArticleWriting = NewArticle defaultNewArticleFields
  , user = Nothing
  , date = Nothing
  }
    ! [ getActualTime ]
    :> update (RequestPosts myself)

getActualTime : Cmd Msg
getActualTime =
  Task.perform DateNow Date.now

update : Msg -> Model -> (Model, Cmd Msg)
update msg ({ menuOpen, date } as model) =
  case msg of
    Navigation navigation ->
      handleNavigation navigation model
    HamburgerMenu action ->
      handleHamburgerMenu action model
    Resizes { width } ->
      if width >= 736 then
        model
          |> closeMenu
          |> Update.identity
      else
        model ! []
    DateNow date ->
      model
        |> setDate (Just date)
        |> Update.identity
    ContactForm action ->
      handleContactForm action model
    LoginForm action ->
      handleLoginForm action model
    NewArticleForm action ->
      handleNewArticleForm action model
    GetPosts posts ->
      posts
        |> Decode.decodeValue Article.Decoder.decodePosts
        |> Result.withDefault []
        |> List.map Article.toUnifiedArticle
        |> setArticlesIn model
        |> Update.identity
    GetUser user ->
      user
        |> Decode.decodeValue User.Decoder.decodeUser
        |> Result.toMaybe
        |> setUserIn model
        |> redirectIfLogin
    AcceptPost accepted ->
      let debug = Debug.log "accepted" accepted in
      model ! []
    RequestPosts username ->
      model ! [ Firebase.requestPosts username ]

handleNavigation : SpaNavigation -> Model -> (Model, Cmd Msg)
handleNavigation navigation model =
  case navigation of
    NewLocation location ->
      model
        |> setLocation location
        |> setRoute (Routing.parseLocation location)
        |> Update.identity
    ReloadHomePage ->
      model ! [ Navigation.newUrl "/" ]
    ChangePage url ->
      (closeMenu model) ! [ Navigation.newUrl url ]
    BackPage ->
      model ! [ Navigation.back 1 ]
    ForwardPage ->
      model ! [ Navigation.forward 1 ]

handleHamburgerMenu : MenuAction -> Model -> (Model, Cmd Msg)
handleHamburgerMenu action model =
  case action of
    ToggleMenu ->
      toggleMenu model ! []

handleContactForm : ContactAction -> Model -> (Model, Cmd Msg)
handleContactForm contactAction model =
  case contactAction of
    SendContactMail ->
      model ! [] -- TODO SendGrid integration.
    ContactEmailInput email ->
      model
        |> setEmailContact email
        |> Update.identity
    ContactMessageInput message ->
      model
        |> setMessageContact message
        |> Update.identity

handleLoginForm : LoginAction -> Model -> (Model, Cmd Msg)
handleLoginForm loginAction ({ loginFields, user } as model) =
  case loginAction of
    LoginUser ->
      model ! [ Firebase.signInUser (loginFields.email, loginFields.password) ]
    LogoutUser ->
      case user of
        Just { email } ->
          model
            |> setUser Nothing
            |> Update.identity
            |> Update.addCmd (Firebase.logoutUser email)
            :> handleNavigation (ChangePage "/")
        Nothing ->
          model ! [ Navigation.newUrl "/" ]
    LoginEmailInput email ->
      model
        |> setEmailLogin email
        |> Update.identity
    LoginPasswordInput password ->
      model
        |> setPasswordLogin password
        |> Update.identity

handleNewArticleForm : NewArticleAction -> Model -> (Model, Cmd Msg)
handleNewArticleForm newArticleAction ({ newArticleWriting, date } as model) =
  case newArticleAction of
    NewArticleTitle title ->
      model
        |> setNewArticleTitle title
        |> Update.identity
    NewArticleContent content ->
      model
        |> setNewArticleContent content
        |> Update.identity
    NewArticleSubmit ->
      case newArticleWriting of
        NewArticle { title, content } ->
          case date of
            Nothing ->
              model ! []
            Just date ->
              date
                |> Article.toSubmit title content
                |> Article.Encoder.encodeArticle
                |> (,) myself
                |> Firebase.createPost
                |> List.singleton
                |> (!) model
                :> handleNewArticleForm NewArticleRemove
                :> update (RequestPosts myself)
        SentArticle ->
          model ! []
    NewArticleToggler ->
      model
        |> toggleNewArticleFocus
        |> Update.identity
    NewArticlePreview ->
      model
        |> toggleNewArticlePreview
        |> Update.identity
    NewArticleRemove ->
      { model | newArticleWriting = SentArticle } ! []
    NewArticleWrite ->
      { model | newArticleWriting = NewArticle defaultNewArticleFields } ! []

redirectIfLogin : Model -> (Model, Cmd Msg)
redirectIfLogin ({ user, route } as model) =
  model ! [ selectRedirectPath model ]

selectRedirectPath : Model -> Cmd Msg
selectRedirectPath { user, route } =
  case user of
    Nothing ->
      Cmd.none
    Just _ ->
      case route of
        Login ->
          Navigation.newUrl "/dashboard"
        _ ->
          Cmd.none

view : Model -> Html Msg
view model =
  Html.div []
    [ View.Static.Header.view model
    , Html.div
      [ Html.Attributes.class "body" ]
      [ Html.img
        [ Html.Attributes.class "banner-photo"
        , Html.Attributes.src "/static/img/banner-photo.jpg"
        ] []
      , Html.div
        [ Html.Attributes.class "container" ]
        [ customView model ]
      ]
    , View.Static.Footer.view model
    ]

customView : Model -> Html Msg
customView ({ route, user, articles } as model) =
  case route of
    Home ->
      View.Home.view model
    About ->
      View.Static.About.view model
    Article id ->
      case articles of
        Nothing ->
          Html.img
            [ Html.Attributes.src "/static/img/loading.gif"
            , Html.Attributes.class "spinner"
            ] []
        Just articles ->
          id
            |> Html.Extra.getUuidPart
            |> Maybe.map (flip Article.getArticleById articles)
            |> Maybe.join
            |> Maybe.map View.Article.view
            |> Maybe.withDefault (View.Static.NotFound.view model)
    Archives ->
      View.Archives.view model
    Contact ->
      Html.map ContactForm <| View.Contact.view model
    Dashboard ->
      case user of
        Nothing ->
          View.Static.NotFound.view model
        Just user ->
          View.Dashboard.view model
    Login ->
      Html.map LoginForm <| View.Login.view model
    NotFound ->
      View.Static.NotFound.view model
