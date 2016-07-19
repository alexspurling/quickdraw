module Main exposing (..)

import Canvas exposing (..)
import Color exposing (Color, black, Gradient)
import Collage
import Element
import Html exposing (Html, button, div, text, h1, canvas)
import Html.Attributes exposing (id, height, width, style)
import Html.App as App
import Mouse exposing (Position)

main =
   App.program { init = init, view = view, update = update, subscriptions = subscriptions }

-- MODEL

type alias Model =
  { mousePos : Position
  , mouseDown : Bool }

init : (Model, Cmd Msg)
init = (
  { mousePos = {x = 0, y = 0}
  , mouseDown = False
  },
  loadCanvas ())

-- UPDATE

type Msg = CanvasMouseMoved Position
  | CanvasMouseDown
  | CanvasMouseUp

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    CanvasMouseMoved position ->
      ({ model | mousePos = position }, Cmd.none)
    CanvasMouseDown ->
      ({ model | mouseDown = True }, Cmd.none)
    CanvasMouseUp ->
      ({ model | mouseDown = False }, Cmd.none)


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ canvasMouseMoved CanvasMouseMoved
    , canvasMouseDown (\_ -> CanvasMouseDown)
    , canvasMouseUp (\_ -> CanvasMouseUp)
    ]

-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ div [] [ text ("Model: " ++ (toString model)) ]
    , div [ style [("width", "800px"), ("padding", "0"), ("margin", "auto"), ("display", "block")] ]
      [ h1 [] [ text "Quick Draw" ]
      , canvas [ id "mycanvas", width 800, height 600, style [("border", "1px solid")] ] []
      ]
    ]
