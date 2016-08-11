module Main exposing (..)

import AnimationFrame
import Collage
import Element
import Html exposing (Html, button, div, text, h1, canvas, img)
import Html.Attributes exposing (id, height, width, style, src)
import Html.Events exposing (onClick)
import Html.App as App
import Mouse exposing (Position)
import Time exposing (Time)

import Canvas exposing (..)
import Colours exposing (Colour)
import Drag
import Pencil

main =
   App.program { init = init, view = view, update = update, subscriptions = subscriptions }

-- MODEL

type alias Model =
  { pencil : Pencil.Model
  , mouseDown : Bool
  , curColour : Colour
  , zoom : Int
  , drawMode : Bool
  , selectedDrawMode : Bool
  , drag : Drag.Model
  }

init : (Model, Cmd Msg)
init = (
  { pencil = Pencil.init
  , mouseDown = False
  , curColour = Colours.Black
  , zoom = 0
  , drawMode = True
  , selectedDrawMode = True
  , drag = Drag.init }
  , loadCanvas ())

-- UPDATE

type Msg = CanvasMouseMoved MouseMovedEvent
  | CanvasMouseDown Position
  | CanvasMouseUp
  | ColourSelected Colour
  | Zoom ZoomAmount
  | AnimationFrame Time
  | ToggleDrawMode

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    CanvasMouseMoved event ->
      let
        newPencil = Pencil.update (Pencil.CanvasMouseMoved event) model.pencil
      in
        ({ model | pencil = newPencil, mouseDown = event.mouseDown }, Cmd.none)
    CanvasMouseDown mousePos ->
      ({ model | mouseDown = True, drag = Drag.dragStart model.drag mousePos }, Cmd.none)
    CanvasMouseUp ->
      ({ model | mouseDown = False, drag = Drag.dragStop model.drag }, Cmd.none)
    ColourSelected colour ->
      ({ model | curColour = colour }, Cmd.none)
    Zoom zoom ->
      let
        drawMode = model.selectedDrawMode && (zoom <= 500)
      in
        ({ model | zoom = zoom, drawMode = drawMode }, Cmd.none)
    ToggleDrawMode ->
      let
        selectedDrawMode = not model.selectedDrawMode
      in
        ({ model | drawMode = selectedDrawMode, selectedDrawMode = selectedDrawMode }, Cmd.none)
    AnimationFrame delta ->
      if model.mouseDown then
        if (not model.drawMode) && model.drag.dragging then
          --Adjust cur pos
          (model, moveCanvas (Drag.dragTo model.pencil.curMousePos model.drag))
        else
          let
            lineToDraw = (Pencil.getLine model.pencil (Colours.toHex model.curColour))
            drawLineCmd = drawLine lineToDraw
            newPencil = Pencil.update (Pencil.UpdatePrevPositions lineToDraw.lineMid) model.pencil
          in
            ({ model | pencil = newPencil }, drawLineCmd)
      else
        (model, Cmd.none)


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ canvasMouseMoved CanvasMouseMoved
    , canvasMouseDown CanvasMouseDown
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

drawDragStyle =
  [ ("width", "25px")
  , ("height", "25px")
  , ("position", "absolute")
  , ("left", "20")
  , ("top", "80px")
  , ("cursor", "pointer") ] ++ stopUserSelect

drawDrag drawMode =
  div [ style drawDragStyle, onClick ToggleDrawMode ]
    [ img [ src (if drawMode then "drag.svg" else "pencil.svg"), width 25, height 25 ] [] ]

colourPalette visible selectedDrawMode =
  let
    divstyle =
      if visible then
        [ ("opacity", "1"), ("transition", "opacity 1s") ]
      else
        [ ("opacity", "0"), ("transition", "opacity 1s") ]
  in
    div [ style divstyle ]
      ((List.indexedMap colourPicker Colours.allColours) ++
      [drawDrag selectedDrawMode])

canvasStyle drawMode =
  [ ("cursor", (if drawMode then "crosshair" else "-webkit-grab")) ]
    ++ stopUserSelect

debugDivStyle =
  [("position", "absolute"), ("bottom", "50px")]
    ++ stopUserSelect

debugDiv model =
  div [ id "debug", style debugDivStyle ] [ text ("Model: " ++ (toString model)) ]

view : Model -> Html Msg
view model =
  div [ ]
    [ colourPalette (model.zoom <= 500) model.selectedDrawMode
    , canvas [ id "mycanvas", style (canvasStyle model.drawMode) ] []
    , debugDiv model
    ]
