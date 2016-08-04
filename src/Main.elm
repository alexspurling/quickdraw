module Main exposing (..)

import AnimationFrame
import Collage
import Element
import Html exposing (Html, button, div, text, h1, canvas)
import Html.Attributes exposing (id, height, width, style)
import Html.Events exposing (onClick)
import Html.App as App
import Mouse exposing (Position)
import Time exposing (Time)

import Canvas exposing (..)
import Colours exposing (Colour)
import Pencil

main =
   App.program { init = init, view = view, update = update, subscriptions = subscriptions }

-- MODEL

type alias Model =
  { pencil : Pencil.Model
  , mouseDown : Bool
  , curColour : Colour
  , zoom : Int }

init : (Model, Cmd Msg)
init = (
  { pencil = Pencil.init
  , mouseDown = False
  , curColour = Colours.Black
  , zoom = 0 }
  , loadCanvas ())

-- UPDATE

type Msg = CanvasMouseMoved MouseMovedEvent
  | CanvasMouseDown
  | CanvasMouseUp
  | ColourSelected Colour
  | Zoom ZoomAmount
  | AnimationFrame Time

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    CanvasMouseMoved event ->
      let
        newPencil = Pencil.update (Pencil.CanvasMouseMoved event) model.pencil
      in
        ({ model | pencil = newPencil, mouseDown = event.mouseDown }, Cmd.none)
    CanvasMouseDown ->
      ({ model | mouseDown = True }, Cmd.none)
    CanvasMouseUp ->
      ({ model | mouseDown = False }, Cmd.none)
    ColourSelected colour ->
      ({ model | curColour = colour }, Cmd.none)
    Zoom zoom ->
      ({ model | zoom = zoom }, Cmd.none)
    AnimationFrame delta ->
      if model.mouseDown then
        let
          lineToDraw = (Pencil.getLine model.pencil (Colours.toHex model.curColour))
          drawLineCmd = drawLine lineToDraw
          newPencil = Pencil.update (Pencil.UpdatePrevPositions lineToDraw.lineMid) model.pencil
        in
          ({model | pencil = newPencil}, drawLineCmd)
      else
        (model, Cmd.none)


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ canvasMouseMoved CanvasMouseMoved
    , canvasMouseDown (\_ -> CanvasMouseDown)
    , canvasMouseUp (\_ -> CanvasMouseUp)
    , canvasZoom Zoom
    , AnimationFrame.diffs AnimationFrame
    ]

-- VIEW

stopUserSelect =
  [ ("-webkit-touch-callout", "none")
  , ("-webkit-user-select", "none")
  , ("-khtml-user-select", "none")
  , ("-moz-user-select", "none")
  , ("-ms-user-select", "none")
  , ("user-select", "none") ]

canvasDivStyle =
  [ ("position", "relative" ) ]

colourStyle index colour =
  let
    left = 20 + (index % 10 * 30)
    top = 20 + (index // 10 * 30)
  in
    [ ("width", "25px")
    , ("height", "25px")
    , ("background-color", colour)
    , ("position", "absolute")
    , ("left", (toString left) ++ "px")
    , ("top", (toString top) ++ "px")
     ]
      ++ stopUserSelect

colourPicker index colour =
  div
  [ style (colourStyle index (Colours.toHex colour))
  , onClick (ColourSelected colour) ] []

colourPalette visible =
  let
    divstyle =
      if visible then
        [ ("opacity", "1"), ("transition", "opacity 1s") ]
      else
        [ ("opacity", "0"), ("transition", "opacity 1s") ]
  in
    div [ style divstyle ]
      (List.indexedMap colourPicker Colours.allColours)

canvasStyle =
  [ ("cursor", "pointer") ]
    ++ stopUserSelect

debugDivStyle =
  [("position", "absolute"), ("bottom", "50px")]
    ++ stopUserSelect

debugDiv model =
  div [ id "debug", style debugDivStyle ] [ text ("Model: " ++ (toString model)) ]

view : Model -> Html Msg
view model =
  div [ ]
    [ colourPalette (model.zoom <= 500)
    , canvas [ id "mycanvas", style canvasStyle ] []
    , debugDiv model
    ]
