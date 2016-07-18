module Main exposing (..)

import Color exposing (Color, black, Gradient)
import Collage
import Element
import Html exposing (Html, button, div, text, h1, canvas)
import Html.Attributes exposing (height, width, style)
import Html.App as App
import Mouse exposing (Position)


main =
   App.program { init = init, view = view, update = update, subscriptions = subscriptions }

port loadCanvas : Cmd Msg

port canvasMouseEvents : (-> msg) -> Sub msg

-- MODEL

type alias Model =
  { mousePos : Position }

init : (Model, Cmd Msg)
init = ({ mousePos = {x = 0, y = 0} }, Cmd.none)

-- UPDATE

type Msg = MouseMoved Position

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    MouseMoved position ->
      ({ mousePos = position }, Cmd.none)

scaledValues x y model =
  let
    winX = fst model.windowSize
    winY = snd model.windowSize
    newX = x - (winX / 2)
    newY = ((winY / 2)) - y
  in
    (newX, newY)


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  loadCanvas

-- VIEW

path : Collage.Path
path =
  Collage.path [(0,0), (100,100), (200,100), (200,200), (150,250), (100,200), (100,100)]

view : Model -> Html Msg
view model =
  div []
    [ div [] [ text ("Mouse pos: " ++ (toString model.mousePos)) ]
    , div [ style [("width", "800px"), ("padding", "0"), ("margin", "auto"), ("display", "block")] ]
      [ h1 [] [ text "Quick Draw" ]
      , canvas [ width 800, height 600, style [("border", "1px solid")] ] []
      , Element.toHtml (Collage.collage 800 600 [(Collage.traced (Collage.solid black) path)])
      ]
    ]
