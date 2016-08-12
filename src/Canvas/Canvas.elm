module Canvas.Canvas exposing (..)

import AnimationFrame
import Collage
import Element
import Mouse exposing (Position)
import Time exposing (Time)

import Canvas.Ports exposing (..)
import Canvas.Drag as Drag
import Canvas.Pencil as Pencil
import Canvas.Colours as Colours exposing (Colour)

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
init =
  ( { pencil = Pencil.init
  , mouseDown = False
  , curColour = Colours.Black
  , zoom = 0
  , drawMode = True
  , selectedDrawMode = True
  , drag = Drag.init }
  , loadCanvas () )

-- UPDATE

type Msg = CanvasMouseMoved MouseMovedEvent
  | CanvasMouseDown Position
  | CanvasMouseUp
  | ColourSelected Colour
  | Zoom ZoomAmount
  | AnimationFrame Time
  | ToggleDrawMode

update : Msg -> Model -> (Model, Cmd Msg, Maybe Line)
update msg model =
  case msg of
    AnimationFrame delta ->
      if model.mouseDown then
        if (not model.drawMode) && model.drag.dragging then
          --Adjust cur pos
          (model, moveCanvas (Drag.dragTo model.pencil.curMousePos model.drag), Maybe.Nothing)
        else
          --Or draw line on canvas
          let
            (pencil, lineToDraw, drawLineCmd) = updatePencil model.pencil model.curColour
          in
            ({ model | pencil = pencil }, drawLineCmd, Maybe.Just lineToDraw)
      else
        (model, Cmd.none, Maybe.Nothing)
    _ ->
      (updateRest msg model, Cmd.none, Maybe.Nothing)

updateRest : Msg -> Model -> Model
updateRest msg model =
  case msg of
    CanvasMouseMoved event ->
      let
        newPencil = Pencil.update (Pencil.CanvasMouseMoved event) model.pencil
      in
        { model | pencil = newPencil, mouseDown = event.mouseDown }
    CanvasMouseDown mousePos ->
      { model | mouseDown = True, drag = Drag.dragStart model.drag mousePos }
    CanvasMouseUp ->
      { model | mouseDown = False, drag = Drag.dragStop model.drag }
    ColourSelected colour ->
      { model | curColour = colour }
    Zoom zoom ->
      let
        drawMode = model.selectedDrawMode && (zoom <= 500)
      in
        { model | zoom = zoom, drawMode = drawMode }
    ToggleDrawMode ->
      let
        selectedDrawMode = not model.selectedDrawMode
      in
        { model | drawMode = selectedDrawMode, selectedDrawMode = selectedDrawMode }
    AnimationFrame delta ->
      Debug.crash "Should never get here"

updatePencil : Pencil.Model -> Colour -> (Pencil.Model, Line, Cmd Msg)
updatePencil pencil colour =
  let
    lineToDraw = (Pencil.getLine pencil (Colours.toHex colour))
    drawLineCmd = drawLine lineToDraw
    newPencil = Pencil.update (Pencil.UpdatePrevPositions lineToDraw.lineMid) pencil
  in
    (newPencil, lineToDraw, drawLineCmd)



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

